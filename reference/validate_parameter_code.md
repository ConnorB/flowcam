# Validate a parameter_code argument

`NULL` or a single `NA` means "no filter" (all parameters). Otherwise,
all values must be exactly 5-digit character strings.

## Usage

``` r
validate_parameter_code(parameter_code)
```

## Arguments

- parameter_code:

  The value to validate.

## Value

`parameter_code`, invisibly.
