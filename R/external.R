#' @import rlang
NULL

new_external <- function(ext) {
  if (!is_function(ext)) {
    abort("`ext` must be a function")
  }

  # Remove srcrefs because they are no use on the remote and they
  # print `!!` instead of its result
  attr(ext, "srcref") <- NULL

  structure(ext, class = "external")
}


#' Is an object an external function?
#'
#' @param x An object to test.
#' @export
is_external <- function(x) {
  inherits(x, "external")
}

#' @export
print.external <- function(x, ...) {
  size <- format(pryr::object_size(x), ...)
  cat(sprintf("<external> %s\n", size))

  env <- fn_env(x)
  nms <- ls(env)
  for (nm in nms) {
    size <- format(pryr::object_size(env[[nm]]), ...)
    cat(sprintf("* `%s`: %s\n", nm, size))
  }

  # Print without environment tag
  fn <- unclass(x)
  environment(fn) <- global_env()
  print(unclass(fn), ...)

  invisible(x)
}

# From pryr
format.bytes <- function(x, digits = 3, ...) {
  power <- min(floor(log(abs(x), 1000)), 4)
  if (power < 1) {
    unit <- "B"
  } else {
    unit <- c("kB", "MB", "GB", "TB")[[power]]
    x <- x / (1000 ^ power)
  }

  x <- signif(x, digits = digits)
  fmt <- format(unclass(x), big.mark = ",", scientific = FALSE)
  paste(fmt, unit)
}
