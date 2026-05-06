# Download camera images to disk

Lists available images for a camera and downloads them to a local
directory. Images are fetched directly from USGS S3 storage; no API key
is required for the downloads themselves.

## Usage

``` r
download_images(
  cam_id = NULL,
  dest_dir,
  size = "small",
  limit = 1000L,
  time = NULL,
  overwrite = FALSE,
  site_id = NULL
)
```

## Arguments

- cam_id:

  Character. Camera identifier. Use
  [`find_cameras()`](https://connorb.github.io/flowcam/reference/find_cameras.md)
  to look up valid IDs. Cannot be used together with `site_id`.

- dest_dir:

  Character. Path to an existing local directory where images will be
  saved.

- size:

  Image size passed to
  [`build_image_url()`](https://connorb.github.io/flowcam/reference/build_image_url.md).
  One of `"small"` (default), `"overlay"`, or `"thumb"`.

- limit:

  Integer between 1 and 50000. Page size for the internal
  [`list_images()`](https://connorb.github.io/flowcam/reference/list_images.md)
  call. Default is `1000`. All images in the requested time range are
  downloaded via automatic pagination.

- time:

  POSIXct, Date, or character vector of length 1 or 2 used to filter
  images by capture time. A length-1 value is treated as a start (on or
  after). A length-2 vector sets the start and end; use `NA` for an open
  bound. See
  [`list_images()`](https://connorb.github.io/flowcam/reference/list_images.md)
  for full details.

- overwrite:

  Logical. If `FALSE` (default), skip files that already exist in
  `dest_dir` (resume behaviour).

- site_id:

  Character. NWIS site number (e.g. `"05366800"` or `"USGS-05366800"`).
  Cannot be used together with `cam_id`. If the site has more than one
  camera, supply `cam_id` directly.

## Value

A character vector of local file paths, invisibly. Failed downloads are
represented as `NA`.

## Details

Identify the camera with either `cam_id` or `site_id` — provide exactly
one. `site_id` accepts both bare NWIS numbers (`"05366800"`) and the
`USGS-` prefixed form (`"USGS-05366800"`). When a site has multiple
cameras, specify the desired camera via `cam_id` instead.

## Examples

``` r
if (FALSE) { # \dontrun{
# By cam_id
paths <- download_images(
  "WI_Chippewa_River_at_Grand_Ave_at_Eau_Claire",
  dest_dir = tempdir(),
  limit    = 5
)

# By USGS site ID
paths <- download_images(
  site_id  = "USGS-05366800",
  dest_dir = tempdir(),
  limit    = 5
)
} # }
```
