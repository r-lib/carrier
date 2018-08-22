#' @import rlang
NULL

new_external <- function(ext) {
  if (!is_function(ext)) {
    abort("`ext` must be a function")
  }
  structure(ext, class = "external")
}


#' Is an object an external function?
#'
#' @param x An object to test.
#' @export
is_external <- function(x) {
  inherits(x, "external")
}
