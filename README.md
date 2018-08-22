
<!-- README.md is generated from README.Rmd. Please edit that file -->
external
========

The external package provides tools to package up functions so they can be sent to remote R sessions or to different processes. They make it easy to control what data should be packaged with the function and what size your crated function is.

Currently external only provides a strict function constructor that forces you to be explicit about the functions and the data your function depends on. In the future it will also provide tools to figure it out automatically.

Creating explicit crated functions
----------------------------------

`crate()` is a function constructor that forces you to be explicit about which data should be packaged with the function. You can create functions using the standard R syntax:

``` r
crate(function(x) mean(x, na.rm = TRUE))
#> <crate> 1.12 kB
#> function (x) 
#> mean(x, na.rm = TRUE)
```

Or with a purrr-like lambda syntax:

``` r
crate(~mean(.x, na.rm = TRUE))
#> <crate> 1.57 kB
#> function (..., .x = ..1, .y = ..2, . = ..1) 
#> mean(.x, na.rm = TRUE)
```

The crated function prints with its total size in the header so you know how much data you will send to remotes.

### Explicit namespaces

`crate()` requires you to be explicit about all dependencies of your function. Except for base functions, you have to call functions with their namespace prefix. You can test your function locally to make sure you've been explicit enough. In the following example we forgot to specify that `var()` comes from the stats namespace:

``` r
fn <- crate(~var(.x))
fn(1:10)
#> Error in var(.x): could not find function "var"
```

So let's add the namespace prefix:

``` r
fn <- crate(~stats::var(.x))
fn(1:10)
#> [1] 9.166667
```

### Explicit data

If your function depends on global data, you need to import it to make it available to your crated function. Here we forgot to import `na_rm`:

``` r
na_rm <- TRUE

fn <- crate(function(x) stats::var(x, na.rm = na_rm))
fn(1:10)
#> Error in stats::var(x, na.rm = na_rm): object 'na_rm' not found
```

You can import objects by passing them as named arguments to `crate()`:

``` r
fn <- crate(function(x) stats::var(x, na.rm = na_rm), na_rm = na_rm)
fn(1:10)
#> [1] 9.166667
```

Note how the size of each imported object is displayed when you print the crated function:

``` r
fn
#> <crate> 1.51 kB
#> * `na_rm`: 56 B
#> function (x) 
#> stats::var(x, na.rm = na_rm)
```

Another way of importing data is to unquote objects with `!!`. This is because unquoting inlines objects in function calls:

``` r
crate(function(x) stats::var(x, na.rm = !!na_rm))
#> <crate> 1.4 kB
#> function (x) 
#> stats::var(x, na.rm = TRUE)
```

Finally, you can also assign objects in a block just before defining your function:

``` r
crate({
  data <- mtcars
  offset <- 10

  function() {
    data$cyl + offset
  }
})
#> <crate> 16.6 kB
#> * `data`: 7.21 kB
#> * `offset`: 56 B
#> function () 
#> {
#>     data$cyl + offset
#> }
```
