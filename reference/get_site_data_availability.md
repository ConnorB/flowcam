# Discover available time series at a USGS gage

Returns metadata about every time series recorded at a site — parameter
codes, units, and period of record — so you know exactly which codes to
pass to
[`get_site_streamflow()`](https://connorb.github.io/flowcam/reference/get_site_streamflow.md).

## Usage

``` r
get_site_data_availability(
  site_id = NULL,
  cam_id = NULL,
  parameter_code = NA_character_
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

  Character. One or more five-digit USGS parameter codes to filter
  results (e.g. `"00060"` for discharge). Default `NA` returns all
  available parameters.

## Value

A tibble with columns:

- `site_id`:

  Bare NWIS site number (without `USGS-` prefix).

- `parameter_code`:

  Five-digit parameter code.

- `parameter_name`:

  Human-readable parameter name.

- `unit_of_measure`:

  Units string (e.g. `"ft3/s"`).

- `begin_utc`:

  POSIXct (UTC). Earliest observation in this time series.

- `end_utc`:

  POSIXct (UTC). Most recent observation.

- `statistic_id`:

  Five-digit statistic code (e.g. `"00003"` for mean).

- `time_series_id`:

  Unique identifier for this time series.

Rows are sorted by `parameter_code`. Returns a zero-row tibble when no
time series are found. Requires the
[dataRetrieval](https://rdrr.io/pkg/dataRetrieval/man/dataRetrieval.html)
package.

## Details

Wraps
[`dataRetrieval::read_waterdata_ts_meta()`](https://rdrr.io/pkg/dataRetrieval/man/read_waterdata_ts_meta.html).

## Examples

``` r
if (FALSE) { # \dontrun{
# All parameters at a site
get_site_data_availability("05366800")

# Discharge only
get_site_data_availability("05366800", parameter_code = "00060")

# Via camera ID
get_site_data_availability(
  cam_id = "WI_Chippewa_River_at_Grand_Ave_at_Eau_Claire"
)

# Chain with get_site_streamflow():
avail <- get_site_data_availability("05366800")
flow  <- get_site_streamflow("05366800",
                             parameter_code = avail$parameter_code[1])
} # }
```
