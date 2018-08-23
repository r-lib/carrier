context("crate")

test_that("crate() supports lambda syntax", {
  expect_equal(crate(~NULL), new_crate(as_function(~NULL)))
})

test_that("crate() requires functions", {
  expect_error(crate(1), "must evaluate to a function")
})

test_that("crate() supports quasiquotation", {
  foo <- "foo"

  fn <- crate(function() toupper(!!foo))
  expect_identical(body(fn), quote(toupper("foo")))
  expect_identical(fn(), "FOO")

  fn <- crate(~toupper(!!foo))
  expect_identical(body(fn), quote(toupper("foo")))
  expect_identical(fn(), "FOO")
})

test_that("can supply data", {
  fn <- crate(~toupper(foo), foo = "foo")
  expect_identical(fn(), "FOO")

  foo <- "foo"
  fn <- crate(~toupper(foo), foo = foo)
  expect_identical(fn(), "FOO")
})

test_that("can supply data before or after function", {
  foo <- "foo"
  fn <- crate(foo = foo, ~toupper(foo))
  expect_identical(fn(), "FOO")
})

test_that("fails if relevant data not supplied", {
  foobar <- "foobar"
  fn <- crate(foo = "foo", ~toupper(foobar))
  expect_error(fn(), "not found")
})

test_that("can supply data in a block", {
  fn <- crate({
    foo <- "foo"
    bar <- "bar"
    ~paste(foo, bar)
  })

  expect_data(fn, "foo", "bar")
})

test_that("external function roundtrips under serialisation", {
  fn <- crate(~toupper(foo), foo = "foo")
  out <- unserialize(serialize(fn, NULL))
  expect_equal(fn_env(fn), fn_env(out))
  expect_identical(fn(), out())
})

test_that("new_crate() requires functions", {
  expect_error(new_crate(1), "must be a function")
  expect_error(new_crate(~foo), "must be a function")
})

test_that("new_crate() creates external objects", {
  expect_is(new_crate(function() NULL), "crate")
})

test_that("arguments are auto-named", {
  foo <- 1L; bar <- 2L
  fn <- crate(~foo + bar, foo, bar)
  expect_data(fn, "foo", "bar")
  expect_identical(fn(), 3L)
})

test_that("sizes are printed with the crate", {
  foo <- "foo"
  bar <- 1:100
  fn <- crate(~NULL, foo = foo, bar = bar)

  bare_fn <- fn
  attributes(bare_fn) <- NULL
  environment(bare_fn) <- global_env()

  bare_size <- format(pryr::object_size(bare_fn))
  bar_size <- format(pryr::object_size(bar))
  foo_size <- format(pryr::object_size(foo))

  output <- "
* function: %s
* `bar`: %s
* `foo`: %s"
  output <- sprintf(output, bare_size, bar_size, foo_size)

  expect_output(print(fn), output, fixed = TRUE)
})
