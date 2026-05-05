# Get the timelapse video URL for a camera

Queries the camera's metadata from NIMS and constructs the URL to its
timelapse video file (720p MP4). Issues a warning if timelapse is not
enabled for the camera.

## Usage

``` r
get_timelapse_url(cam_id)
```

## Arguments

- cam_id:

  Character. Camera identifier.

## Value

A single character string with the full timelapse video URL.

## Examples

``` r
if (FALSE) { # \dontrun{
get_timelapse_url("WI_Chippewa_River_at_Grand_Ave_at_Eau_Claire")
} # }
```
