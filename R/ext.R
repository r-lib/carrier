#' Create an external function
#'
#' @description
#'
#' `ext()` creates functions in a child of the base environment. These
#' functions must be self-contained:
#'
#' * They should call package functions with an explicit `::`
#'   namespace.
#'
#' * They should import data they depend on.
#'
#' You can import data in two ways: by supplying named arguments or by
#' unquoting objects with `!!`.
#'
#' @param .fn An unevaluated function or formula. Formulas are
#'   converted to purrr-like lambda functions using
#'   [rlang::as_function()].
#' @param ... Named arguments to import in the environment of `.fn`.
#' @export
#' @examples
#' # Create external functions using the ordinary notation:
#' ext(function(x) stats::var(x))
#'
#' # Or the formula notation:
#' ext(~stats::var(.x))
#'
#' # Import data by supplying named arguments. You can test you have
#' # imported all necessary data by calling your external function:
#' na_rm <- TRUE
#' fn <- ext(~stats::var(.x, na.rm = na_rm), na_rm = na_rm)
#' fn(1:10)
#'
#' # For small data it is handy to unquote instead. Unquoting inlines
#' # objects inside the function:
#' fn <- ext(~stats::var(.x, na.rm = !!na_rm))
#' fn(1:10)
ext <- function(.fn, ...) {
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

  new_external(fn)
}
