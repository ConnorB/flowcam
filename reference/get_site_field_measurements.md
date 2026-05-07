# Retrieve manual field measurements for a USGS gage

Returns the record of in-person discharge measurements made by USGS
hydrographers at a gage site. These manual measurements are the "ground
truth" used to build stage-discharge rating curves, and they provide
direct visual correlates to camera imagery taken at the same location
and time.

## Usage

``` r
get_site_field_measurements(
  site_id = NULL,
  cam_id = NULL,
  time = NULL,
  parameter_code = "00060"
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

- time:

  POSIXct, Date, or character vector of length 1 or 2 specifying the
  time window. Follows the same semantics as
  [`get_site_streamflow()`](https://connorb.github.io/flowcam/reference/get_site_streamflow.md).
  `NULL` (default) returns all available measurements.

- parameter_code:

  Character. One or more five-digit USGS parameter codes. Default
  `"00060"` (discharge, ft³/s). `NULL` returns measurements for all
  parameters.

## Value

A tibble with columns:

- `site_id`:

  Bare NWIS site number.

- `datetime`:

  POSIXct (UTC) of the measurement.

- `value`:

  Numeric measured value.

- `unit`:

  Units of measure (e.g. `"ft3/s"`).

- `parameter_code`:

  Five-digit parameter code.

- `approval_status`:

  `"Approved"` or `"Provisional"`.

- `measurement_rated`:

  Quality rating of the measurement: `"Excellent"` (≤2% error), `"Good"`
  (≤5%), `"Fair"` (≤8%), or `"Poor"` (\>8%).

- `control_condition`:

  Description of channel control conditions during the measurement.

Returns a zero-row tibble (with correct column types) when no
measurements are found. Compatible with
[`get_site_streamflow()`](https://connorb.github.io/flowcam/reference/get_site_streamflow.md)
output via `dplyr::bind_rows()` on the shared columns. Requires the
[dataRetrieval](https://rdrr.io/pkg/dataRetrieval/man/dataRetrieval.html)
package.

## Details

Wraps
[`dataRetrieval::read_waterdata_field_measurements()`](https://rdrr.io/pkg/dataRetrieval/man/read_waterdata_field_measurements.html).

## Examples

``` r
if (FALSE) { # \dontrun{
# All discharge measurements at a site
get_site_field_measurements("05366800")

# Measurements during a specific period
get_site_field_measurements(
  "05366800",
  time = c("2020-01-01", "2024-12-31")
)

# Via camera ID
get_site_field_measurements(
  cam_id = "WI_Chippewa_River_at_Grand_Ave_at_Eau_Claire"
)

# Compare field measurements against continuous sensor record
field <- get_site_field_measurements("05366800", time = "P2Y")
sensor <- get_site_streamflow("05366800", time = "P2Y")
} # }
```
