# Build a dataRetrieval-compatible time vector from a flowcam time argument

Build a dataRetrieval-compatible time vector from a flowcam time
argument

## Usage

``` r
.build_dr_time(time)
```

## Arguments

- time:

  `NULL`, a POSIXct/Date/character vector of length 1 or 2, or an ISO
  8601 duration string (e.g. `"P7D"`).

## Value

A character vector to pass as the `time` argument to
`read_waterdata_continuous()` or `read_waterdata_daily()`.
