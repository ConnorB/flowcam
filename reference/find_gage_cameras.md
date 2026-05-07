# Query NIMS cameras and enrich with NWIS site metadata

Calls
[`find_cameras()`](https://connorb.github.io/flowcam/reference/find_cameras.md)
for the given NWIS site ID, then joins the result with site metadata
from
[`dataRetrieval::read_waterdata_monitoring_location()`](https://rdrr.io/pkg/dataRetrieval/man/read_waterdata_monitoring_location.html).
Requires the `dataRetrieval` package.

## Usage

``` r
find_gage_cameras(site_id)
```

## Arguments

- site_id:

  Character. A single 8-to-15-digit NWIS site number (e.g.
  `"05366800"`).

## Value

A tibble with all camera columns from
[`find_cameras()`](https://connorb.github.io/flowcam/reference/find_cameras.md)
plus these site metadata columns when available:
`monitoring_location_name`, `state_name`, `county_name`,
`hydrologic_unit_code`, `drainage_area` (total drainage area in square
miles), and `altitude` (elevation in feet above the stated vertical
datum).

## Examples

``` r
if (FALSE) { # \dontrun{
find_gage_cameras("05366800")
} # }
```
