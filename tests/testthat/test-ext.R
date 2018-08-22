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
