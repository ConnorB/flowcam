# Retrieve streamflow data for a USGS gage

Wraps
[`dataRetrieval::read_waterdata_continuous()`](https://rdrr.io/pkg/dataRetrieval/man/read_waterdata_continuous.html)
(instantaneous values) or
[`dataRetrieval::read_waterdata_daily()`](https://rdrr.io/pkg/dataRetrieval/man/read_waterdata_daily.html)
(daily mean values) for the USGS gage associated with a flowcam camera.
Returns a clean tibble aligned with flowcam conventions.

## Usage

``` r
get_site_streamflow(
  site_id = NULL,
  cam_id = NULL,
  time = NULL,
  parameter_code = "00060",
  type = c("continuous", "daily")
)
```

## Arguments

- site_id:

  Character. A single NWIS site number (e.g. `"05366800"` or
  `"USGS-05366800"`). Exactly one of `site_id` or `cam_id` must be
  provided.

- cam_id:

  Character. A camera identifier (e.g.
  `"WI_Chippewa_River_at_Grand_Ave_at_Eau_Claire"`). If supplied, the
  function resolves the associated NWIS site ID via
  [`find_cameras()`](https://connorb.github.io/flowcam/reference/find_cameras.md).
  Exactly one of `site_id` or `cam_id` must be provided.

- time:

  POSIXct, Date, or character vector of length 1 or 2. Follows the same
  semantics as the `time` argument in
  [`list_images()`](https://connorb.github.io/flowcam/reference/list_images.md):
  length-1 is treated as a start bound; length-2 sets start and end,
  with `NA` for an open bound. ISO 8601 duration strings such as `"P7D"`
  (last 7 days) or `"P1Y"` (last year) are also accepted and forwarded
  to the API unchanged. When `NULL`, the API default applies
  (approximately the last year of data for continuous; all available
  data for daily).

- parameter_code:

  Character. Five-digit USGS parameter code. Default `"00060"` is
  discharge in cubic feet per second. Other common codes: `"00010"`
  (water temperature, \\°C\\), `"00065"` (gage height, ft), `"00095"`
  (specific conductance, µS/cm).

- type:

  Character. `"continuous"` (default) returns instantaneous (unit-value)
  observations; `"daily"` returns daily mean values.

## Value

A tibble with columns:

- `site_id`:

  Bare NWIS site number (without `USGS-` prefix).

- `datetime`:

  POSIXct (UTC) for `type = "continuous"`; Date for `type = "daily"`.

- `value`:

  Numeric observation value.

- `unit`:

  Units of measure (e.g. `"ft3/s"`).

- `parameter_code`:

  Five-digit parameter code.

- `approval_status`:

  `"Approved"` or `"Provisional"`.

Returns a zero-row tibble (with correct column types) when no data are
found. Requires the
[dataRetrieval](https://rdrr.io/pkg/dataRetrieval/man/dataRetrieval.html)
package.

## Examples

``` r
if (FALSE) { # \dontrun{
# Instantaneous discharge for the last 7 days
get_site_streamflow("05366800", time = "P7D")

# Daily discharge for a calendar year
get_site_streamflow(
  "05366800",
  time = c("2024-01-01", "2024-12-31"),
  type = "daily"
)

# Water temperature from a camera ID
get_site_streamflow(
  cam_id = "WI_Chippewa_River_at_Grand_Ave_at_Eau_Claire",
  parameter_code = "00010"
)

# Pair with image timestamps
images <- list_images("05366800", time = c("2024-10-01", "2024-10-07"),
                      raw_item = TRUE)
flow   <- get_site_streamflow("05366800",
                              time = c("2024-10-01", "2024-10-07"))
} # }
```
