expect_data <- function(crate, ...) {
  nms <- env_names(fn_env(crate))
  expect_true(all(nms %in% c(...)))
}
