
expect_data <- function(crate, ...) {
  nms <- env_names(fn_env(crate))
  nms <- nms[nms != "library"]
  expect_true(all(nms %in% c(...)))
}
