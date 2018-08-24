
<!-- README.md is generated from README.Rmd. Please edit that file -->

# external

The external package provides tools to package up functions so they can
be sent to remote R sessions or to different processes, and tools to
test your crates locally. They make it easy to control what data should
be packaged with the function and what size your crated function is.

Currently external only provides a strict function constructor that
forces you to be explicit about the functions and the data your function
depends on. In the future it will also provide tools to figure it out
automatically.

## Creating explicit crated functions

`crate()` is a function constructor that forces you to be explicit about
which data should be packaged with the function. You can create
functions using the standard R syntax:

``` r
crate(function(x) mean(x, na.rm = TRUE))
#> <crate> 7 kB
#> * function: 6.55 kB
#> function(x) mean(x, na.rm = TRUE)
```

Or with a purrr-like lambda syntax:

``` r
crate(~mean(.x, na.rm = TRUE))
#> <crate> 1.57 kB
#> * function: 1.01 kB
#> function (..., .x = ..1, .y = ..2, . = ..1) 
#> mean(.x, na.rm = TRUE)
```

The crated function prints with its total size in the header so you know
how much data you will send to remotes. The size of the bare function
without any data is also printed in the first bullet, and if you add
objects to the crate their size is printed in decreasing order.

### Explicit namespaces

`crate()` requires you to be explicit about all dependencies of your
function. Except for base functions, you have to call functions with
their namespace prefix. You can test your function locally to make sure
you’ve been explicit enough. In the following example we forgot to
specify that `var()` comes from the stats namespace:

``` r
fn <- crate(~var(.x))
fn(1:10)
#> Error in var(.x): could not find function "var"
```

So let’s add the namespace prefix:

``` r
fn <- crate(~stats::var(.x))
fn(1:10)
#> [1] 9.166667
```

### Explicit data

If your function depends on global data, you need to declare it to make
it available to your crated function. Here we forgot to declare `na_rm`:

``` r
na_rm <- TRUE

fn <- crate(function(x) stats::var(x, na.rm = na_rm))
fn(1:10)
#> Error in stats::var(x, na.rm = na_rm): object 'na_rm' not found
```

There are two techniques for packaging data into your crate.

#### Passing data as arguments

You can declare objects by passing them as named arguments to `crate()`:

``` r
fn <- crate(
  function(x) stats::var(x, na.rm = na_rm),
  na_rm = na_rm
)
fn(1:10)
#> [1] 9.166667
```

Note how the size of each imported object is displayed when you print
the crated function:

``` r
fn
#> <crate> 9.31 kB
#> * function: 8.75 kB
#> * `na_rm`: 56 B
#> function(x) stats::var(x, na.rm = na_rm)
```

The arguments are automatically named after themselves to make it easier
to import objects with the same name:

``` r
crate(function(x) stats::var(x, na.rm = na_rm), na_rm)
#> <crate> 7.82 kB
#> * function: 7.26 kB
#> * `na_rm`: 56 B
#> function(x) stats::var(x, na.rm = na_rm)
```

However you need to be careful with complex expressions: those should
always be named. Can you spot the difference between these two crates?

``` r
crate(function(x) stats::var(x, na.rm = na_rm), !na_rm)
#> <crate> 9.7 kB
#> * function: 9.09 kB
#> * `!na_rm`: 56 B
#> function(x) stats::var(x, na.rm = na_rm)

crate(function(x) stats::var(x, na.rm = na_rm), na_rm = !na_rm)
#> <crate> 9.65 kB
#> * function: 9.09 kB
#> * `na_rm`: 56 B
#> function(x) stats::var(x, na.rm = na_rm)
```

#### Unquoting data in the function

Another way of packaging data is to unquote objects with `!!`. This
works because unquoting inlines objects in function calls. Unquoting can
be less verbose if you have many small objects to import inside the
function.

``` r
crate(function(x) stats::var(x, na.rm = !!na_rm))
#> <crate> 7.86 kB
#> * function: 7.42 kB
#> function(x) stats::var(x, na.rm = !!na_rm)
```

However be careful not to unquote large objects because:

  - The sizes of unquoted objects are not detailed when you print the
    crate.
  - Inlined data can cause noisy output.

Let’s unquote a data frame to see the noise caused by inlining:

``` r
# Subset a few rows so the call is not too noisy
data <- mtcars[1:5, ]

# Inline data in call by unquoting
fn <- crate(~stats::lm(.x, data = !!data))
```

This crate will print with noisy inlined data:

``` r
fn
#> <crate> 4.65 kB
#> * function: 4.14 kB
#> function (..., .x = ..1, .y = ..2, . = ..1) 
#> stats::lm(.x, data = list(mpg = c(21, 21, 22.8, 21.4, 18.7), 
#>     cyl = c(6, 6, 4, 6, 8), disp = c(160, 160, 108, 258, 360), 
#>     hp = c(110, 110, 93, 110, 175), drat = c(3.9, 3.9, 3.85, 
#>     3.08, 3.15), wt = c(2.62, 2.875, 2.32, 3.215, 3.44), qsec = c(16.46, 
#>     17.02, 18.61, 19.44, 17.02), vs = c(0, 0, 1, 1, 0), am = c(1, 
#>     1, 1, 0, 0), gear = c(4, 4, 4, 3, 3), carb = c(4, 4, 1, 1, 
#>     2)))
```

Same for the function call recorded by `lm()`:

``` r
fn(disp ~ drat)
#> 
#> Call:
#> stats::lm(formula = .x, data = structure(list(mpg = c(21, 21, 
#> 22.8, 21.4, 18.7), cyl = c(6, 6, 4, 6, 8), disp = c(160, 160, 
#> 108, 258, 360), hp = c(110, 110, 93, 110, 175), drat = c(3.9, 
#> 3.9, 3.85, 3.08, 3.15), wt = c(2.62, 2.875, 2.32, 3.215, 3.44
#> ), qsec = c(16.46, 17.02, 18.61, 19.44, 17.02), vs = c(0, 0, 
#> 1, 1, 0), am = c(1, 1, 1, 0, 0), gear = c(4, 4, 4, 3, 3), carb = c(4, 
#> 4, 1, 1, 2)), row.names = c("Mazda RX4", "Mazda RX4 Wag", "Datsun 710", 
#> "Hornet 4 Drive", "Hornet Sportabout"), class = "data.frame"))
#> 
#> Coefficients:
#> (Intercept)         drat  
#>       952.3       -207.8
```
