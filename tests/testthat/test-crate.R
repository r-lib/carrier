test_that("crate() supports lambda syntax", {
  expect_equal(
    crate(~NULL),
    new_crate(as_function(~NULL, env = current_env())),
    ignore_function_env = TRUE
  )
})

test_that("crate() requires named `...` arguments", {
  expect_snapshot(
    error = TRUE,
    crate(function(x) identity(x), x = 1, y = 2, 3),
  )
  expect_no_error(crate(function(x) identity(x), x = 1, y = 2))
  expect_no_error(crate(function(x) identity(x)))
})

test_that("crate() requires functions", {
  expect_snapshot(error = TRUE, crate(1))
})

test_that("crate() supports quasiquotation", {
  foo <- "foo"

  fn <- crate(function() toupper(!!foo))
  expect_identical(body(fn), quote(toupper("foo")))
  expect_identical(fn(), "FOO")

  fn <- crate(~ toupper(!!foo))
  expect_identical(body(fn), quote(toupper("foo")))
  expect_identical(fn(), "FOO")
})

test_that("can supply data", {
  fn <- crate(~ toupper(foo), foo = "foo")
  expect_identical(fn(), "FOO")

  foo <- "foo"
  fn <- crate(~ toupper(foo), foo = foo)
  expect_identical(fn(), "FOO")
})

test_that("can supply data before or after function", {
  foo <- "foo"
  fn <- crate(foo = foo, ~ toupper(foo))
  expect_identical(fn(), "FOO")
})

test_that("fails if relevant data not supplied", {
  foobar <- "foobar"
  fn <- crate(foo = "foo", ~ toupper(foobar))
  expect_error(fn(), "not found")
})

test_that("can supply data in a block", {
  fn <- crate({
    foo <- "foo"
    bar <- "bar"
    ~ paste(foo, bar)
  })

  expect_data(fn, "foo", "bar")
})

test_that("crated function roundtrips under serialisation", {
  fn <- crate(~ toupper(foo), foo = "foo")
  out <- unserialize(serialize(fn, NULL))
  expect_equal(as.list(fn_env(fn)), as.list(fn_env(out)))
  expect_equal(fn(), out())
})

test_that("new_crate() requires functions", {
  expect_snapshot(error = TRUE, new_crate(1))
  expect_snapshot(error = TRUE, new_crate(~foo))
})

test_that("new_crate() crates", {
  expect_s3_class(new_crate(function() NULL), "crate")
})

test_that("sizes are printed with the crate", {
  foo <- "foo"
  bar <- 1:100
  fn <- crate(~NULL, foo = foo, bar = bar)

  bare_fn <- fn
  attributes(bare_fn) <- NULL
  environment(bare_fn) <- global_env()

  bare_size <- format_bytes(lobstr::obj_size(bare_fn))
  bar_size <- format_bytes(lobstr::obj_size(bar))
  foo_size <- format_bytes(lobstr::obj_size(foo))

  output <- "
* function: %s
* `bar`: %s
* `foo`: %s"
  output <- sprintf(output, bare_size, bar_size, foo_size)

  expect_output(print(fn), output, fixed = TRUE)
})

test_that("empty crates are printed correctly", {
  fn <- crate(~NULL)

  bare_fn <- fn
  attributes(bare_fn) <- NULL
  environment(bare_fn) <- global_env()

  bare_size <- format_bytes(lobstr::obj_size(bare_fn))

  output <- "
* function: %s
function"
  output <- sprintf(output, bare_size)

  expect_output(print(fn), output, fixed = TRUE)
})

test_that("crate() accepts existing functions", {
  fn <- function() NULL
  expect_s3_class(crate(fn), "crate")
  expect_s3_class(crate(set_env(fn)), "crate")
})

test_that("existing functions are re-environed to the crate env", {
  outer <- "outer"
  helper <- function() outer
  fn <- crate(helper, outer = outer)
  expect_identical(fn(), "outer")
  expect_true("outer" %in% env_names(fn_env(fn)))
})

test_that("data captured in an existing function's env is dropped", {
  fn <- local({
    captured <- "lost"
    function() captured
  })
  out <- crate(fn)
  expect_error(out(), "captured")
})

test_that("an existing crate passed as `.fn` keeps its env", {
  inner <- crate(function() data, data = "inner")
  out <- crate(inner)
  expect_identical(out(), "inner")
})

test_that("existing formulas are re-environed to the crate env", {
  f <- ~ toupper(x)
  fn <- crate(f, x = "a")
  expect_identical(fn(), "A")
  expect_identical(env_parent(fn_env(fn)), baseenv())
})

test_that("an existing namespace function passed as `.fn` is wrapped", {
  out <- crate(format_bytes)
  expect_identical(out(123), format_bytes(123))
  expect_identical(env_parent(fn_env(out)), baseenv())
  expect_true("..fn.." %in% env_names(fn_env(out)))
})

test_that("a primitive passed as `.fn` is wrapped without warning", {
  expect_no_warning(out <- crate(sum))
  expect_identical(out(1:10), 55L)
  expect_identical(env_parent(fn_env(out)), baseenv())
  expect_true("..fn.." %in% env_names(fn_env(out)))
})

test_that("wrapped functions pass named arguments through", {
  fn <- crate(stats::var)
  x <- c(1:10, NA)
  expect_identical(fn(x = x, na.rm = TRUE), stats::var(x, na.rm = TRUE))
})

test_that("wrapped crates roundtrip under serialisation", {
  fn <- crate(format_bytes)
  out <- unserialize(serialize(fn, NULL))
  expect_identical(out(123), fn(123))
})

test_that("`..fn..` is shown in the printout of wrapped crates", {
  fn <- crate(stats::var)
  expect_output(print(fn), "`..fn..`:", fixed = TRUE)
})

test_that("dot-prefixed data is shown in the printout", {
  fn <- crate(~.n, .n = 1)
  expect_output(print(fn), "`.n`:", fixed = TRUE)
})

test_that("`...` data errors when it is unreachable from `.fn`", {
  fn2 <- crate(function() NULL)
  expect_snapshot(error = TRUE, crate(fn2, x = 1))
  expect_snapshot(error = TRUE, crate(stats::var, na_rm = TRUE))
  expect_snapshot(error = TRUE, crate(sum, x = 1))
})

test_that("`..fn..` is reserved in the crate environment", {
  expect_snapshot(
    error = TRUE,
    crate({
      ..fn.. <- "x"
      sum
    })
  )
})

test_that("helper functions can be passed via `...`", {
  really_do_it <- function() "foo"
  do_it <- function(x) really_do_it()
  environment(really_do_it) <- environment(do_it) <- globalenv()
  fn <- crate(function(x) do_it(x), do_it = do_it, really_do_it = really_do_it)
  expect_equal(fn(), "foo")
})

test_that("closures passed via `...` are switched to the local env", {
  fn <- function() {
    foo <- "bar"
    foo_fn <- function(x) foo
    do_fn <- crate(function(x) foo_fn(x), foo_fn = foo_fn)
    do_fn()
  }
  expect_snapshot(error = TRUE, fn())
})

test_that("`...` objects are not checked recursively for closures", {
  # Same as above test but wraps the function in a list. We intentionally do
  # not attempt to check for functions recursively in containers such as lists.
  fn <- function() {
    foo <- "bar"
    foo_list <- list(fn = function(x) foo)
    do_fn <- crate(function(x) foo_list$fn(x), foo_list = foo_list)
    do_fn()
  }
  expect_equal(fn(), "bar")
})

test_that("closures passed via `...` are not switched for package functions", {
  fn <- crate(function(x) format_bytes(x), format_bytes = format_bytes)
  expect_identical(fn(123), format_bytes(123))
})

test_that("crates passed to `...` are not re-crated", {
  fn2 <- crate(function(x) format_bytes(x), format_bytes = format_bytes)
  fn <- crate(function(x) fn2(x), fn2 = fn2)
  expect_identical(fn(123), format_bytes(123))
})
