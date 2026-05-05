# Download camera images to disk

Lists available images for a camera and downloads them to a local
directory. Images are fetched directly from USGS S3 storage; no API key
is required for the downloads themselves.

## Usage

``` r
download_images(
  cam_id,
  dest_dir,
  size = "small",
  limit = 10L,
  after = NULL,
  before = NULL,
  overwrite = FALSE
)
```

## Arguments

- cam_id:

  Character. Camera identifier. Use
  [`find_cameras()`](https://connorb.github.io/flowcam/reference/find_cameras.md)
  to look up valid IDs.

- dest_dir:

  Character. Path to an existing local directory where images will be
  saved.

- size:

  Image size passed to
  [`build_image_url()`](https://connorb.github.io/flowcam/reference/build_image_url.md).
  One of `"small"` (default), `"overlay"`, or `"thumb"`.

- limit:

  Integer. Maximum number of images to download. Default is `10`.

- after:

  POSIXct, Date, or character. Only download images captured on or after
  this datetime.

- before:

  POSIXct, Date, or character. Only download images captured on or
  before this datetime.

- overwrite:

  Logical. If `FALSE` (default), skip files that already exist in
  `dest_dir` (resume behaviour).

## Value

A character vector of local file paths, invisibly. Failed downloads are
represented as `NA`.

## Examples

``` r
if (FALSE) { # \dontrun{
paths <- download_images(
  "WI_Chippewa_River_at_Grand_Ave_at_Eau_Claire",
  dest_dir = tempdir(),
  limit    = 5
)
} # }
```
