
# Remove after rlang 0.3.0 is released
locally <- function(..., .env = env(caller_env())) {
  dots <- exprs(...)
  nms <- names(dots)
  out <- NULL

  for (i in seq_along(dots)) {
    out <- eval_bare(dots[[i]], .env)

    nm <- nms[[i]]
    if (nm != "") {
      .env[[nm]] <- out
    }
  }

  out
}
