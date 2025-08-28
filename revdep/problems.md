# dynparam

<details>

* Version: 1.0.2
* GitHub: https://github.com/dynverse/dynparam
* Source code: https://github.com/cran/dynparam
* Date/Publication: 2021-01-04 23:30:02 UTC
* Number of recursive dependencies: 55

Run `revdepcheck::revdep_details(, "dynparam")` for more info

</details>

## Newly broken

*   checking examples ... ERROR
    ```
    Running examples in ‘dynparam-Ex.R’ failed
    The error most likely occurred in:
    
    > ### Name: parameter_set
    > ### Title: Parameter set helper functions
    > ### Aliases: parameter_set is_parameter_set as.list.parameter_set
    > ###   as_parameter_set get_defaults sip as_paramhelper
    > 
    > ### ** Examples
    > 
    ...
    $ks
    [1]  3 15
    
    > 
    > sip(parameters, n = 1)
    Loading required namespace: ParamHelpers
    Loading required namespace: lhs
    Error: evaluation nested too deeply: infinite recursion / options(expressions=)?
    Error: evaluation nested too deeply: infinite recursion / options(expressions=)?
    Execution halted
    ```

*   checking tests ...
    ```
      Running ‘testthat.R’
     ERROR
    Running the tests in ‘tests/testthat.R’ failed.
    Complete output:
      > library(testthat)
      > library(dynparam)
      > 
      > test_check("dynparam")
      [ FAIL 4 | WARN 0 | SKIP 0 | PASS 385 ]
      
      Error in paste(rep(char, x), collapse = "") : 
        result would exceed 2^31-1 bytes
      Calls: test_check ... paste0 -> rule -> rule_left -> paste0 -> make_line -> paste
      Execution halted
    ```

