# Build full image URLs from camera metadata and filenames

Combines a camera's base directory with one or more filenames returned
by
[`list_images()`](https://connorb.github.io/flowcam/reference/list_images.md)
to produce download-ready image URLs.

## Usage

``` r
build_image_url(camera_row, filename, size = c("small", "overlay", "thumb"))
```

## Arguments

- camera_row:

  A single-row tibble (or named list) from
  [`find_cameras()`](https://connorb.github.io/flowcam/reference/find_cameras.md).
  Must contain the directory column corresponding to `size`.

- filename:

  Character vector of one or more filenames from
  [`list_images()`](https://connorb.github.io/flowcam/reference/list_images.md).

- size:

  Image size. One of:

  - `"small"` (default): ~720 px wide (`smallDir`)

  - `"overlay"`: full-size overlay image (`overlayDir`)

  - `"thumb"`: thumbnail ~200 px tall (`thumbDir`)

## Value

A character vector of full image URLs, one per element of `filename`.

## Examples

``` r
if (FALSE) { # \dontrun{
cam   <- find_cameras(cam_id = "WI_Chippewa_River_at_Grand_Ave_at_Eau_Claire")
imgs  <- list_images(cam$camId[[1]], limit = 5)
urls  <- build_image_url(cam, imgs$filename, size = "small")
} # }
```
