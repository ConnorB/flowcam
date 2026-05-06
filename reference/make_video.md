# Assemble camera images into an MP4 video

Downloads images for a camera over a specified time range and encodes
them into an MP4 video using the `av` package. Provide either `cam_id`
or `site_id` to identify the camera, and use `time` to restrict the
range.

## Usage

``` r
make_video(
  cam_id = NULL,
  site_id = NULL,
  time = NULL,
  output = NULL,
  fps = 2,
  size = "small",
  limit = 1000L,
  dir = NULL,
  one_per_day = FALSE
)
```

## Arguments

- cam_id:

  Character. Camera identifier. Cannot be used with `site_id`.

- site_id:

  Character. NWIS site number (e.g. `"05366800"` or `"USGS-05366800"`).
  Cannot be used with `cam_id`.

- time:

  POSIXct, Date, or character vector of length 1 or 2. Same semantics as
  [`download_images()`](https://connorb.github.io/flowcam/reference/download_images.md).
  When `dir` is supplied, timestamps are parsed from the filenames (NIMS
  format: `<camId>___<timestamp>.jpg`).

- output:

  Character. File path for the output MP4. Defaults to `"<cam_id>.mp4"`
  (or `"<site_id>.mp4"`, or the directory basename) in the working
  directory.

- fps:

  Positive number. Frames per second. Any positive value is accepted.
  Default is `2`.

- size:

  Image size passed to
  [`download_images()`](https://connorb.github.io/flowcam/reference/download_images.md).
  One of `"small"` (default), `"overlay"`, or `"thumb"`. Ignored when
  `dir` is supplied.

- limit:

  Integer. Page size for the internal
  [`list_images()`](https://connorb.github.io/flowcam/reference/list_images.md)
  call. Default is `1000`. Ignored when `dir` is supplied.

- dir:

  Character. Path to a local directory of already-downloaded images.
  When supplied, downloads are skipped and JPEG/PNG files are read from
  this directory. `cam_id`/`site_id` and `time` still apply as filters.

- one_per_day:

  Logical. If `TRUE`, reduce frames to one per calendar day by selecting
  the image whose capture time is closest to noon in the camera's local
  timezone (from the `tz` field of
  [`find_cameras()`](https://connorb.github.io/flowcam/reference/find_cameras.md)).
  Default is `FALSE`.

## Value

The output file path, invisibly.

## Details

When `dir` is supplied, images are read from that local directory
instead of being downloaded. You can still pass `cam_id`/`site_id` to
select only files belonging to a particular camera (matched by filename
prefix) and `time` to filter by timestamp embedded in the filename —
useful when a directory contains images from multiple cameras or a wider
date range than needed.

## Examples

``` r
if (FALSE) { # \dontrun{
# Download and assemble images for a date range
make_video("WI_Chippewa_River_at_Grand_Ave_at_Eau_Claire",
           time = c("2025-06-01", "2025-06-02"), output = "chippewa.mp4")

# One frame per day from a local directory
make_video(cam_id = "NM_Pecos_Web_Camera_near_Roswell",
           time        = c("2023-08-01", "2023-08-31"),
           dir         = "~/Downloads/Pecos",
           one_per_day = TRUE,
           output      = "pecos_august.mp4")
} # }
```
