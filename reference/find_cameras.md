# Query NIMS cameras

Returns a tibble of camera metadata from the USGS National Imagery
Management System (NIMS). With no arguments, all cameras are returned.
Filter by a NWIS site ID or a specific camera ID.

## Usage

``` r
find_cameras(site_id = NULL, cam_id = NULL, return_fields = NULL)
```

## Arguments

- site_id:

  Character. NWIS site number (e.g. `"05366800"`). Cannot be used
  together with `cam_id`.

- cam_id:

  Character. Camera identifier (e.g.
  `"WI_Chippewa_River_at_Grand_Ave_at_Eau_Claire"`). Cannot be used
  together with `site_id`.

- return_fields:

  Character vector of camera fields to include in the response (e.g.
  `c("camName", "newestImageDT")`). `camId` is always returned
  regardless of this setting. When `NULL` (the default), all fields are
  returned.

## Value

A tibble with one row per camera. Columns depend on `return_fields`.
`lat` and `lng` are returned as numeric. Datetime columns are POSIXct
(UTC). The `ingest` column is a list-column containing each camera's
ingestion configuration.

## Examples

``` r
if (FALSE) { # \dontrun{
# All cameras
find_cameras()

# Cameras at a specific gage
find_cameras(site_id = "05366800")

# A specific camera
find_cameras(cam_id = "WI_Chippewa_River_at_Grand_Ave_at_Eau_Claire")

# Only selected fields
find_cameras(return_fields = c("camName", "newestImageDT"))
} # }
```
