# List image filenames for a NIMS camera

Returns a tibble of image filenames (or raw image metadata) for the
specified camera. Use the filenames with
[`build_image_url()`](https://connorb.github.io/flowcam/reference/build_image_url.md)
to construct full image URLs.

## Usage

``` r
list_images(
  cam_id = NULL,
  limit = 1000L,
  recent = TRUE,
  time = NULL,
  raw_item = FALSE,
  site_id = NULL
)
```

## Arguments

- cam_id:

  Character. Camera identifier. Use
  [`find_cameras()`](https://connorb.github.io/flowcam/reference/find_cameras.md)
  to look up valid IDs. Cannot be used together with `site_id`.

- limit:

  Integer between 1 and 50000. Number of records fetched per API request
  (page size). Default is `1000`. All matching images are returned via
  automatic pagination regardless of this value.

- recent:

  Logical. If `TRUE` (default), return the most recent images first. If
  `FALSE`, return the oldest images first.

- time:

  POSIXct, Date, or character vector of length 1 or 2 used to filter
  images by capture time. A length-1 value is treated as a start (on or
  after). A length-2 vector sets the start and end; use `NA` for an open
  bound (`c("2025-06-01", NA)` = on or after; `c(NA, "2025-06-02")` = on
  or before). Character strings are passed through unchanged; the API
  accepts ISO 8601 (`"2025-12-31T00:00:00"`) and NIMS format
  (`"2025-12-31T00-00-00Z"`).

- raw_item:

  Logical. If `TRUE`, return a tibble with columns `camId`, `filename`,
  `timestamp`, and `fs` (file size in kb). If `FALSE` (default), return
  a single-column tibble of filenames.

- site_id:

  Character. NWIS site number (e.g. `"05366800"` or `"USGS-05366800"`).
  Cannot be used together with `cam_id`. If the site has more than one
  camera, supply `cam_id` directly.

## Value

A tibble. When `raw_item = FALSE`, one column: `filename`. When
`raw_item = TRUE`, four columns: `camId`, `filename`, `timestamp`, `fs`.

## Details

Identify the camera with either `cam_id` or `site_id` — provide exactly
one. `site_id` accepts both bare NWIS numbers (`"05366800"`) and the
`USGS-` prefixed form (`"USGS-05366800"`). When a site has multiple
cameras, specify the desired camera via `cam_id` instead.

## Examples

``` r
if (FALSE) { # \dontrun{
# 10 most recent images by cam_id
list_images("WI_Chippewa_River_at_Grand_Ave_at_Eau_Claire", limit = 10)

# By USGS site ID (bare or prefixed)
list_images(site_id = "05366800", limit = 10)
list_images(site_id = "USGS-05366800", limit = 10)

# Images in a date window
list_images(
  "WI_Chippewa_River_at_Grand_Ave_at_Eau_Claire",
  time = as.POSIXct(c("2025-06-01", "2025-06-02"), tz = "UTC")
)

# Open-ended: on or after June 1
list_images(
  "WI_Chippewa_River_at_Grand_Ave_at_Eau_Claire",
  time = c("2025-06-01", NA)
)

# With metadata
list_images("WI_Chippewa_River_at_Grand_Ave_at_Eau_Claire",
            limit = 5, raw_item = TRUE)
} # }
```
