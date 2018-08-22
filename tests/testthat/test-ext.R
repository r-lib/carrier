context("ext")

test_that("ext() supports lambda syntax", {
  expect_equal(ext(~NULL), new_external(as_function(~NULL)))
})

test_that("ext() requires functions", {
  expect_error(ext(1), "must evaluate to a function")
})

test_that("ext() supports quasiquotation", {
  foo <- "foo"

  fn <- ext(function() toupper(!!foo))
  expect_identical(body(fn), quote(toupper("foo")))
  expect_identical(fn(), "FOO")

  fn <- ext(~toupper(!!foo))
  expect_identical(body(fn), quote(toupper("foo")))
  expect_identical(fn(), "FOO")
})

test_that("can supply data", {
  fn <- ext(~toupper(foo), foo = "foo")
  expect_identical(fn(), "FOO")

  foo <- "foo"
  fn <- ext(~toupper(foo), foo = foo)
  expect_identical(fn(), "FOO")
})

test_that("can supply data before or after function", {
  foo <- "foo"
  fn <- ext(foo = foo, ~toupper(foo))
  expect_identical(fn(), "FOO")
})

test_that("fails if relevant data not supplied", {
  foobar <- "foobar"
  fn <- ext(foo = "foo", ~toupper(foobar))
  expect_error(fn(), "not found")
})

test_that("external function roundtrips under serialisation", {
  fn <- ext(~toupper(foo), foo = "foo")
  out <- unserialize(serialize(fn, NULL))
  expect_equal(fn_env(fn), fn_env(out))
  expect_identical(fn(), out())
})
