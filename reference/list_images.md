# List image filenames for a NIMS camera

Returns a tibble of image filenames (or raw image metadata) for the
specified camera. Use the filenames with
[`build_image_url()`](https://connorb.github.io/flowcam/reference/build_image_url.md)
to construct full image URLs.

## Usage

``` r
list_images(
  cam_id,
  limit = 1000L,
  recent = TRUE,
  after = NULL,
  before = NULL,
  raw_item = FALSE
)
```

## Arguments

- cam_id:

  Character. Camera identifier (required). Use
  [`find_cameras()`](https://connorb.github.io/flowcam/reference/find_cameras.md)
  to look up valid IDs.

- limit:

  Integer between 1 and 50000. Maximum number of records to return.
  Default is `1000`.

- recent:

  Logical. If `TRUE` (default), return the most recent images first. If
  `FALSE`, return the oldest images first.

- after:

  POSIXct, Date, or character. Return only images captured on or after
  this datetime. Character strings are passed through unchanged; the API
  accepts ISO 8601 (`"2025-12-31T00:00:00"`) and NIMS format
  (`"2025-12-31T00-00-00Z"`).

- before:

  POSIXct, Date, or character. Return only images captured on or before
  this datetime.

- raw_item:

  Logical. If `TRUE`, return a tibble with columns `camId`, `filename`,
  `timestamp`, and `fs` (file size in kb). If `FALSE` (default), return
  a single-column tibble of filenames.

## Value

A tibble. When `raw_item = FALSE`, one column: `filename`. When
`raw_item = TRUE`, four columns: `camId`, `filename`, `timestamp`, `fs`.

## Examples

``` r
if (FALSE) { # \dontrun{
# 10 most recent images
list_images("WI_Chippewa_River_at_Grand_Ave_at_Eau_Claire", limit = 10)

# Images in a date window
list_images(
  "WI_Chippewa_River_at_Grand_Ave_at_Eau_Claire",
  after  = as.POSIXct("2025-06-01", tz = "UTC"),
  before = as.POSIXct("2025-06-02", tz = "UTC")
)

# With metadata
list_images("WI_Chippewa_River_at_Grand_Ave_at_Eau_Claire",
            limit = 5, raw_item = TRUE)
} # }
```
