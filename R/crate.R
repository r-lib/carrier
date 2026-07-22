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
#' * A function (closure) supplied as an additional argument is itself crated.
#'   This means that it must be self-contained by supplying all objects required
#'   by it as further additional arguments, if not already supplied. Only
#'   functions directly supplied to `...` are crated, and containers such as
#'   lists are not recursively walked to find functions. Note that if an
#'   existing crate is supplied, this is not re-crated.
#'
#' @param .fn A formula or function. The function may be defined
#'   inside the call to `crate()` or already exist. For an existing
#'   function:
#'
#'   * Plain closures have their enclosing environment replaced with
#'     the crate's evaluation environment, so any data they depend on
#'     must be declared via `...`. This means closures that depend on
#'     captured state, such as those created by function factories
#'     (e.g. the result of [stats::ecdf()]), lose that state and fail
#'     when called. See Examples for how to crate such functions.
#'   * Namespace functions and primitives are wrapped in a thin
#'     closure that delegates to them, leaving their original
#'     environment untouched.
#'   * Existing crates are passed through unchanged.
#'
#'   Formulas are converted to purrr-like lambda functions using
#'   [rlang::as_function()].
#' @param ... Named arguments to declare in the environment of `.fn`.
#'   Declared data is only reachable from plain closures; it is an
#'   error to supply `...` when `.fn` is an existing crate, a
#'   namespace function, or a primitive.
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
#' crate(\(x) stats::var(x))
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
#' # Declare `na_rm` by passing it as a named argument:
#' fn <- crate(~ stats::var(.x, na.rm = na_rm), na_rm = na_rm)
#' fn(1:10)
#'
#' # The size of each declared object is shown in the crate printout:
#' fn
#'
#'
#' # You can also pass an already defined function. Its enclosing
#' # environment is replaced with the crate's evaluation environment,
#' # so any data it depends on must be declared via `...`:
#' fn <- function(x) toupper(x)
#' crate(fn)
#'
#' # For the same reason, existing functions that depend on state
#' # captured in their environment, such as those created by function
#' # factories, lose that state and fail when called:
#' fn <- stats::ecdf(1:10)
#' crated <- crate(fn)
#' try(crated(5))
#'
#' # Instead, construct the function within the crate:
#' crated <- crate(\(x) stats::ecdf(1:10)(x))
#' crated(5)
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

  # Set all non-namespace, non-crate function closures to the local env
  for (name in names(env)) {
    x <- env[[name]]
    if (is_closure(x) && !isNamespace(environment(x)) && !is_crate(x)) {
      environment(x) <- env
      env[[name]] <- zap_srcref(x)
    }
  }

  if (is_formula(fn)) {
    fn <- as_function(fn)
    environment(fn) <- env
  } else if (!is_function(fn)) {
    abort(
      sprintf("`%s` must evaluate to a function", .error_arg),
      call = .error_call
    )
  } else if (is_crate(fn)) {
    # Existing crates pass through unchanged and can't take new data
    if (length(dots)) {
      abort(
        sprintf(
          "Can't pass data via `...` when `%s` is an existing crate.",
          .error_arg
        ),
        call = .error_call
      )
    }
  } else if (is_primitive(fn) || isNamespace(environment(fn))) {
    # Wrap in a thin closure that delegates, leaving the original
    # environment untouched; declared data would be unreachable
    if (length(dots)) {
      what <- if (is_primitive(fn)) "primitive" else "namespaced"
      abort(
        sprintf(
          "Can't declare data via `...` when `%s` is a %s function.",
          .error_arg,
          what
        ),
        call = .error_call
      )
    }
    fn <- wrap_into_crate_env(fn, env, .error_call)
  } else {
    # Plain closures are re-enveloped into the crate environment
    environment(fn) <- env
  }

  # Remove potentially heavy srcrefs (#6)
  fn <- zap_srcref(fn)

  new_crate(fn)
}

wrap_into_crate_env <- function(fn, env, error_call) {
  name <- "..fn.."
  if (env_has(env, name)) {
    abort(
      sprintf("The name `%s` is reserved by `crate()`.", name),
      call = error_call
    )
  }
  env[[name]] <- zap_srcref(fn)
  new_function(
    alist(... = ),
    call(name, quote(...)),
    env = env
  )
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
  nms <- names(env)

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
