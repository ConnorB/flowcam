# Retrieve historical flow statistics for a USGS gage

Provides historical context for interpreting camera imagery — "is this
flow high or low?" — by returning day-of-year percentile curves or
period-of-record summaries.

## Usage

``` r
get_flow_statistics(
  site_id = NULL,
  cam_id = NULL,
  parameter_code = "00060",
  type = c("daily_normals", "period_summary"),
  computation = "percentile",
  time = NULL
)
```

## Arguments

- site_id:

  Character. A single NWIS site number (e.g. `"05366800"` or
  `"USGS-05366800"`). Exactly one of `site_id` or `cam_id` must be
  provided.

- cam_id:

  Character. A camera identifier. If supplied, the function resolves the
  associated NWIS site ID via
  [`find_cameras()`](https://connorb.github.io/flowcam/reference/find_cameras.md).
  Exactly one of `site_id` or `cam_id` must be provided.

- parameter_code:

  Character. One or more five-digit USGS parameter codes. Default
  `"00060"` (discharge, ft³/s).

- type:

  Character. `"daily_normals"` (default) returns day-of-year and
  month-of-year percentile/statistic curves, suitable for overlaying on
  a time series plot. `"period_summary"` returns calendar-month,
  calendar-year, and water-year summaries.

- computation:

  Character vector. One or more of `"percentile"` (default),
  `"arithmetic_mean"`, `"minimum"`, `"maximum"`, `"median"`. When `NULL`
  or `NA`, all computation types are returned.

- time:

  For `type = "period_summary"` only. A POSIXct, Date, or character
  vector of length 1 or 2 (start, end) used to restrict the date range
  of the summary. Follows the same semantics as the `time` argument in
  [`get_site_streamflow()`](https://connorb.github.io/flowcam/reference/get_site_streamflow.md).
  `NULL` (default) returns the full period of record. Ignored when
  `type = "daily_normals"`.

## Value

A tibble. All types include columns:

- `site_id`:

  Bare NWIS site number.

- `parameter_code`:

  Five-digit parameter code.

- `unit_of_measure`:

  Units string.

- `computation`:

  Statistical method (e.g. `"percentile"`).

- `percentile`:

  Integer percentile (e.g. `50L`); `NA` for non-percentile computations.

- `value`:

  Numeric statistic value.

- `sample_count`:

  Number of observations used to compute the statistic.

`type = "daily_normals"` additionally includes:

- `month_day`:

  Character MM-DD representing the day or month of year.

`type = "period_summary"` additionally includes:

- `interval_type`:

  One of `"calendar_month"`, `"calendar_year"`, or `"water_year"`.

- `start_date`:

  Date. Start of the summary interval.

- `end_date`:

  Date. End of the summary interval.

Returns a zero-row tibble (with correct column types) when no data are
found. Requires the
[dataRetrieval](https://rdrr.io/pkg/dataRetrieval/man/dataRetrieval.html)
package.

## Details

Wraps
[`dataRetrieval::read_waterdata_stats_por()`](https://rdrr.io/pkg/dataRetrieval/man/read_waterdata_stats.html)
(`type = "daily_normals"`) or
[`dataRetrieval::read_waterdata_stats_daterange()`](https://rdrr.io/pkg/dataRetrieval/man/read_waterdata_stats.html)
(`type = "period_summary"`).

## Examples

``` r
if (FALSE) { # \dontrun{
# Day-of-year discharge percentile curves (the 10/25/50/75/90th percentiles)
get_flow_statistics("05366800")

# Annual and monthly discharge summaries
get_flow_statistics("05366800", type = "period_summary")

# Restrict period_summary to a specific date range
get_flow_statistics(
  "05366800",
  type = "period_summary",
  time = c("2010-01-01", "2020-12-31")
)

# Multiple computation types
get_flow_statistics(
  "05366800",
  computation = c("minimum", "median", "maximum")
)

# Overlay on a streamflow time series
flow  <- get_site_streamflow("05366800", time = "P1Y")
stats <- get_flow_statistics("05366800")
} # }
```
