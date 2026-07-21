# crate() requires named `...` arguments

    Code
      crate(function(x) identity(x), x = 1, y = 2, 3)
    Condition
      Error in `crate()`:
      ! All `...` arguments must be named

# crate() requires functions

    Code
      crate(1)
    Condition
      Error in `crate()`:
      ! `.fn` must evaluate to a function

# new_crate() requires functions

    Code
      new_crate(1)
    Condition
      Error in `new_crate()`:
      ! `crate` must be a function

---

    Code
      new_crate(~foo)
    Condition
      Error in `new_crate()`:
      ! `crate` must be a function

# `...` data errors when it is unreachable from `.fn`

    Code
      crate(fn2, x = 1)
    Condition
      Error in `crate()`:
      ! Can't pass data via `...` when `.fn` is an existing crate.

---

    Code
      crate(stats::var, na_rm = TRUE)
    Condition
      Error in `crate()`:
      ! Can't declare data via `...` when `.fn` is a namespaced function.

---

    Code
      crate(sum, x = 1)
    Condition
      Error in `crate()`:
      ! Can't declare data via `...` when `.fn` is a primitive function.

# `..fn..` is reserved in the crate environment

    Code
      crate({
        ..fn.. <- "x"
        sum
      })
    Condition
      Error in `crate()`:
      ! The name `..fn..` is reserved by `crate()`.

# closures passed via `...` are switched to the local env

    Code
      fn()
    Condition
      Error in `foo_fn()`:
      ! object 'foo' not found

