#' @import rlang
NULL

#' Crate a function to share with another process
#'
#' @description
#'
#' `crate()` creates functions in a self-contained environment
#' (technically, a child of the base environment). This has two
#' advantages:
#'
#' * They can easily be executed in another process.
#'
#' * Their effects are reproducible. You can run them locally with the
#'   same results as on a different process.
#'
#' Creating self-contained functions requires some care, see section
#' below.
#'
#'
#' @section Creating self-contained functions:
#'
#' * They should call package functions with an explicit `::`
#'   namespace. This includes packages in the default search path with
#'   the exception of the base package. For instance `var()` from the
#'   stats package must be called with its namespace prefix:
#'   `stats::var(x)`.
#'
#' * They should declare any data they depend on. You can declare data
#'   by supplying additional arguments or by unquoting objects with `!!`.
#'
#' @param .fn A fresh formula or function. "Fresh" here means that
#'   they should be declared in the call to `crate()`. See examples if
#'   you need to crate a function that is already defined. Formulas
#'   are converted to purrr-like lambda functions using
#'   [rlang::as_function()].
#' @param ... Named arguments to declare in the environment of `.fn`.
#' @param .parent_env The default of `baseenv()` ensures that the evaluation
#'   environment of the crate is isolated from the search path. Specifying
#'   another environment such as the global environment allows this condition to
#'   be relaxed (but at the expense of no longer being able to rely on a local
#'   run giving the same results as one in a different process).
#' @inheritParams rlang::args_error_context
#'
#' @export
#' @examples
#' # You can create functions using the ordinary notation:
#' crate(function(x) stats::var(x))
#'
#' # Or the formula notation:
#' crate(~ stats::var(.x))
#'
#' # Declare data by supplying named arguments. You can test you have
#' # declared all necessary data by calling your crated function:
#' na_rm <- TRUE
#' fn <- crate(~ stats::var(.x, na.rm = na_rm))
#' try(fn(1:10))
#'
#' # For small data it is handy to unquote instead. Unquoting inlines
#' # objects inside the function. This is less verbose if your
#' # function depends on many small objects:
#' fn <- crate(~ stats::var(.x, na.rm = !!na_rm))
#' fn(1:10)
#'
#' # One downside is that the individual sizes of unquoted objects
#' # won't be shown in the crate printout:
#' fn
#'
#'
#' # The function or formula you pass to crate() should defined inside
#' # the crate() call, i.e. you can't pass an already defined
#' # function:
#' fn <- function(x) toupper(x)
#' try(crate(fn))
#'
#' # If you really need to crate an existing function, you can
#' # explicitly set its environment to the crate environment with the
#' # set_env() function from rlang:
#' crate(rlang::set_env(fn))
crate <- function(
  .fn,
  ...,
  .parent_env = baseenv(),
  .error_arg = ".fn",
  .error_call = environment()
) {
  # Evaluate arguments in a child of the caller so the caller context
  # is in scope and new data is created in a separate child
  env <- child_env(caller_env())
  dots <- exprs(...)
  if (!all(nzchar(names2(dots)))) {
    abort("All `...` arguments must be named")
  }
  locally(!!!dots, .env = env)

  # Quote and evaluate in the local env to avoid capturing execution
  # envs when user passed an unevaluated function or formula
  fn <- eval_bare(enexpr(.fn), env)

  # Isolate the evaluation environment from the search path if
  # .parent_env = baseenv()
  env_poke_parent(env, .parent_env)

  # Check and set global_env() function closures to the local env
  for (name in names(env)) {
    x <- env[[name]]
    if (is_closure(x) && identical(environment(x), global_env())) {
      environment(env[[name]]) <- env
    }
  }

  if (is_formula(fn)) {
    fn <- as_function(fn)
  } else if (!is_function(fn)) {
    abort(
      sprintf("`%s` must evaluate to a function", .error_arg),
      call = .error_call
    )
  }

  if (!is_reference(get_env(fn), env)) {
    abort(
      "The function must be defined inside this call",
      call = .error_call
    )
  }

  # Remove potentially heavy srcrefs (#6)
  fn <- zap_srcref(fn)

  new_crate(fn)
}


new_crate <- function(crate) {
  if (!is_function(crate)) {
    abort("`crate` must be a function")
  }

  structure(crate, class = "crate")
}

#' Is an object a crate?
#'
#' @param x An object to test.
#' @export
is_crate <- function(x) {
  inherits(x, "crate")
}

# Unexported until the `bytes` class is moved to lobstr (and probably
# becomes `lobstr_bytes`)
crate_sizes <- function(crate) {
  bare_fn <- unclass(crate)
  environment(bare_fn) <- global_env()

  bare_size <- lobstr::obj_size(bare_fn)

  env <- fn_env(crate)
  nms <- ls(env)

  n <- length(nms) + 1
  out <- new_list(n, c("function", nms))
  out[[1]] <- bare_size

  index <- seq2(2, n)
  get_size <- function(nm) lobstr::obj_size(env[[nm]])
  out[index] <- lapply(nms, get_size)

  # Sort data by decreasing size but keep function first
  order <- order(as.numeric(out[-1]), decreasing = TRUE)
  out <- out[c(1, order + 1)]

  out
}


#' @export
print.crate <- function(x, ...) {
  sizes <- crate_sizes(x)

  total_size <- format_bytes(lobstr::obj_size(x), ...)
  cat(sprintf("<crate> %s\n", total_size))

  fn_size <- format_bytes(sizes[[1]], ...)
  cat(sprintf("* function: %s\n", fn_size))

  nms <- names(sizes)
  for (i in seq2_along(2, sizes)) {
    nm <- nms[[i]]
    size <- format_bytes(sizes[[i]], ...)
    cat(sprintf("* `%s`: %s\n", nm, size))
  }

  # Print function without the environment tag
  bare_fn <- unclass(x)
  environment(bare_fn) <- global_env()
  print(bare_fn, ...)

  invisible(x)
}

format_bytes <- function(x) {
  format(as_bytes(unclass(x)))
}
