# carrier (development version)

## New features

* `crate()` received argument `.compile`, which is `TRUE`
  by default.

# carrier 0.3.0

## Breaking changes

This release modifies the behaviour of functions crated via `...`, i.e. in cases like:

```r
foo <- function(x) x + 1

crate(\(x) foo(x), foo = foo)
```

Functions passed through `...`, such as `foo` in this example, are now
automatically _crated_ in the same environment as the main crate. This behaviour
change may break your code in some cases but has two important benefits that we
thought were worth it:

1. In the global environment, it allows helper functions to depend on other
   helper functions defined globally. Take for instance:

   ```r
   foo <- function(x) bar(x)
   bar <- function(x) x + 1

   crate(\(x) foo(x), foo = foo, bar = bar)
   ```

   Before this change, both `foo` and `bar` would inherit from the global
   environment, before and after being sent to a remote context. While the local
   context has both `foo` and `bar` defined in the global environment, this
   would not be the case remotely, and `foo` would not be able to resolve `bar`.

   Now that we recrate all `...` closures withing the main crate environment,
   they are able to see each other.

2. In a local environment (e.g. in a function or within `local()`), the chain of
   closure environments used to be included in the crate up to the global
   environment. This meant the problem descibed in (1) didn't apply in local
   environments, but the flip side is that it was also easy to inadvertently
   capture large objects defined in these environments:

   ```r
   local({
      large_object <- rnorm(1e8)
      parameter <- 1
      foo <- function(x) x + parameter

      crate(\(x) foo(x), foo = foo)
   })
   ```

   In this example, `large_object`  would be included in the crate alongside
   `foo`, causing performance issues when sending the crate to a remote context.
   This is no longer possible now that `foo` is automatically crated. Any
   relevant object must be explicitly crated, in one of these ways:

   ```r
   local({
      parameter <- 1
      foo <- function(x) x + parameter

      crate(\(x) foo(x), foo = foo, parameter = parameter)
   })

   # Or equivalently
   local({
      parameter <- 1
      foo <- crate(\(x) x + parameter, parameter = parameter)

      crate(\(x) foo(x), foo = foo)
   })
   ```


# carrier 0.2.0

* `crate()` gains a `.parent_env` argument. The default is `baseenv()` in order
  to isolate the crate from the global search path. You can now set it to
  another environment. For instance, set it to `globalenv()` to make your crate
  inherit from the search path. Note that, as the global environment is
  serialized by name rather than by value, the crate is still isolated from
  objects in the global environment (#16).

* `crate()` now requires all `...` arguments to be named instead of silently
  dropping unnamed arguments (#15).

* `crate()` gains `.error_arg` and `.error_call` arguments to allow for better
  error messages when calling `crate()` from other functions (#14).

# carrier 0.1.1

* Crated functions no longer carry source references (#6).

* Fixed issue that prevented crate sizes to be printed in
  human-readable format (r-lib/lobstr#60).


# carrier 0.1.0

Initial release. The package currently only contains a single method
for creating crates that requires users to be explicit about what data
to pack in the crate. A future release will provide a method to figure
out automatically what objects the crate depends on (with inevitable
false positives and negatives).
