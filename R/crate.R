#' @import rlang
NULL

#' Crate a function to share with another process
#'
#' @description
#'
#' `crate()` creates functions in a self-contained environment
#' (technically, a child of the base environment). Consequently these
#' functions must be self-contained as well:
#'
#' * They should call package functions with an explicit `::`
#'   namespace.
#'
#' * They should declare any data they depend on.
#'
#' You can declare data by supplying named arguments or by unquoting
#' objects with `!!`.
#'
#' @param .fn A formula or function, unevaluated. Formulas are
#'   converted to purrr-like lambda functions using
#'   [rlang::as_function()].
#' @param ... Named arguments to declare in the environment of `.fn`.
#' @export
#' @examples
#' # You can create functions using the ordinary notation:
#' crate(function(x) stats::var(x))
#'
#' # Or the formula notation:
#' crate(~stats::var(.x))
#'
#' # Declare data by supplying named arguments. You can test you have
#' # declared all necessary data by calling your crated function:
#' na_rm <- TRUE
#' fn <- crate(~stats::var(.x, na.rm = na_rm))
#' try(fn(1:10))
#'
#' fn <- crate(
#'   ~stats::var(.x, na.rm = na_rm),
#'   na_rm = na_rm
#' )
#' fn(1:10)
#'
#' # For small data it is handy to unquote instead. Unquoting inlines
#' # objects inside the function. This is less verbose if your
#' # function depends on many small objects:
#' fn <- crate(~stats::var(.x, na.rm = !!na_rm))
#' fn(1:10)
#'
#' # One downside is that the individual sizes of unquoted objects
#' # won't be shown in the crate printout:
#' fn
crate <- function(.fn, ...) {
  # Evaluate arguments in a child of the caller so the caller context
  # is in scope and new data is created in a separate child
  env <- child_env(caller_env())
  locally(..., .env = env)

  # Quote and evaluate in the local env to avoid capturing execution
  # envs when user passed an unevaluated function or formula
  fn <- eval_bare(enexpr(.fn), env)

  # Isolate the evaluation environment from the search path
  env_poke_parent(env, base_env())

  if (is_formula(fn)) {
    fn <- as_function(fn)
  } else if (!is_function(fn)) {
    abort("`.fn` must evaluate to a function")
  }

  if (!is_reference(fn_env(fn), env)) {
    abort("Can't supply an evaluated function")
  }

  new_crate(fn)
}


new_crate <- function(crate) {
  if (!is_function(crate)) {
    abort("`crate` must be a function")
  }

  # Remove srcrefs because they are no use on the remote and they
  # print `!!` instead of its result
  attr(crate, "srcref") <- NULL

  structure(crate, class = "crate")
}

#' Is an object an external function?
#'
#' @param x An object to test.
#' @export
is_crate <- function(x) {
  inherits(x, "crate")
}

#' @export
print.crate <- function(x, ...) {
  size <- format(pryr::object_size(x), ...)
  cat(sprintf("<crate> %s\n", size))

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
