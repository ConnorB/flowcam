# Parse a dataRetrieval-style time argument into after/before strings

Accepts `NULL`, a length-1 value (treated as start), or a length-2
vector where `NA` elements indicate open-ended bounds.

## Usage

``` r
parse_time_arg(time)
```

## Arguments

- time:

  `NULL`, or a POSIXct/Date/character vector of length 1 or 2.

## Value

A named list with elements `after` and `before`, each a character string
or `NULL`.
