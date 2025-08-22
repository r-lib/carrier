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

# function must be defined in the crate environment

    Code
      crate(fn)
    Condition
      Error in `crate()`:
      ! The function must be defined inside this call

# closures are set to the local env for functions in `...`

    Code
      fn2()
    Condition
      Error in `do_it()`:
      ! object 'foo' not found

