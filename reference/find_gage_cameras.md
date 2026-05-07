# Query NIMS cameras and enrich with NWIS site metadata

Calls
[`find_cameras()`](https://connorb.github.io/flowcam/reference/find_cameras.md)
for the given NWIS site ID, then joins the result with site metadata
from
[`dataRetrieval::read_waterdata_monitoring_location()`](https://rdrr.io/pkg/dataRetrieval/man/read_waterdata_monitoring_location.html).
Optionally appends a `data_types` list-column with the available time
series at the site via
[`get_site_data_availability()`](https://connorb.github.io/flowcam/reference/get_site_data_availability.md).
Requires the `dataRetrieval` package.

## Usage

``` r
find_gage_cameras(site_id, include_availability = TRUE)
```

## Arguments

- site_id:

  Character. A single 8-to-15-digit NWIS site number (e.g.
  `"05366800"`).

- include_availability:

  Logical. When `TRUE` (default), a `data_types` list-column is appended
  containing a tibble of available time series for the site (from
  [`get_site_data_availability()`](https://connorb.github.io/flowcam/reference/get_site_data_availability.md)).
  Set to `FALSE` to skip this extra API call and return only the camera
  and site metadata.

## Value

A tibble with all camera columns from
[`find_cameras()`](https://connorb.github.io/flowcam/reference/find_cameras.md)
plus these site metadata columns when available:
`monitoring_location_name`, `state_name`, `county_name`,
`hydrologic_unit_code`, `drainage_area` (total drainage area in square
miles), and `altitude` (elevation in feet above the stated vertical
datum). When `include_availability = TRUE`, a `data_types` list-column
is also included; each element is a tibble with columns from
[`get_site_data_availability()`](https://connorb.github.io/flowcam/reference/get_site_data_availability.md).

## Examples

``` r
if (FALSE) { # \dontrun{
# With available time series (default)
find_gage_cameras("05366800")

# Site metadata only, no data availability call
find_gage_cameras("05366800", include_availability = FALSE)
} # }
```
