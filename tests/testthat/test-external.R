context("external")

test_that("new_external() requires functions", {
  expect_error(new_external(1), "must be a function")
  expect_error(new_external(~foo), "must be a function")
})

test_that("new_external() creates external objects", {
  expect_is(new_external(function() NULL), "external")
})
