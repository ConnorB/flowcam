# Format a date/time value for NIMS API query parameters

Accepts a POSIXct, POSIXlt, Date, or character string and returns a
character string in ISO 8601 format (`YYYY-MM-DDTHH:MM:SS`). Character
strings are passed through unchanged; the API accepts both ISO 8601 and
NIMS-standard date strings.

## Usage

``` r
format_datetime(dt, arg_name = deparse(substitute(dt)))
```

## Arguments

- dt:

  A POSIXct, POSIXlt, Date, or character string, or `NULL`.

- arg_name:

  Name of the calling argument (for error messages).

## Value

A character string, or `NULL` if `dt` is `NULL`.
