# Parse a NIMS timestamp string into POSIXct

Handles both the NIMS wire format (`"2022-09-12T19-30-10Z"`, dashes in
the time component) and standard ISO 8601 (`"2022-09-12T19:30:10Z"`).

## Usage

``` r
.parse_nims_ts(ts)
```

## Arguments

- ts:

  A single character string, or `NULL`.

## Value

A POSIXct value (UTC), or `NULL` if `ts` is `NULL`, empty, or
unparseable.
