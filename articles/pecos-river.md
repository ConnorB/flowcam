# Monitoring the Pecos River with flowcam and dataRetrieval

This vignette walks through a practical monitoring workflow using two
USGS stream-gage cameras on the Pecos River in southeastern New Mexico:

| Site | NWIS ID | Description |
|----|----|----|
| Pecos Web Camera near Roswell | 08385630 | Visual monitoring at the Roswell reach |
| Pecos River near Acme | 08386000 | ~45 km downstream; long-term flow record |

The workflow pairs camera images from **flowcam** with streamflow data
from **dataRetrieval** to put the visual record in hydrologic context.

``` r

library(flowcam)
library(dataRetrieval)  # install.packages("dataRetrieval") if needed
```

## Site metadata and camera discovery

[`find_gage_cameras()`](https://connorb.github.io/flowcam/reference/find_gage_cameras.md)
calls
[`find_cameras()`](https://connorb.github.io/flowcam/reference/find_cameras.md)
for a site and then joins in NWIS attributes—drainage area, state,
county, hydrologic unit code—in a single step:

``` r

roswell <- find_gage_cameras("08385630")
roswell
```

The result includes all camera columns from
[`find_cameras()`](https://connorb.github.io/flowcam/reference/find_cameras.md)
plus columns such as `monitoring_location_name`, `state_name`,
`drain_area_va`, and `hydrologic_unit_code` where available.

``` r

acme <- find_gage_cameras("08386000")
acme
```

## Inspecting camera details

Useful fields to check before downloading:

``` r

# When was the most recent image captured?
roswell$newestImageDT

# Is timelapse enabled?
roswell$TL_enabled

# Hydrologic context
roswell[, c("monitoring_location_name", "drain_area_va",
             "hydrologic_unit_code", "state_name")]
```

## Fetching recent images at the Roswell camera

Retrieve the 20 most recent images with metadata so we know the
timestamps:

``` r

cam_id <- roswell$camId[[1]]

recent <- list_images(cam_id, limit = 20, raw_item = TRUE)
recent
```

`timestamp` is in the NIMS `YYYY-MM-DDTHH-MM-SSZ` format and records the
image capture time in UTC. The `fs` column gives file size in kilobytes.

## Pairing images with streamflow

Retrieve mean daily discharge (parameter code `00060`) from the
downstream Acme gage (08386000) over the same period. NWIS data is easy
to pull with
[`dataRetrieval::readNWISdv()`](https://rdrr.io/pkg/dataRetrieval/man/readNWISdv.html):

``` r

# Derive date range from the images we just listed
# timestamps are like "2025-06-15T14-30-00Z"
ts_clean <- gsub("T(\\d{2})-(\\d{2})-(\\d{2})Z$", "T\\1:\\2:\\3Z",
                  recent$timestamp)
image_times <- as.POSIXct(ts_clean, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")

start_date <- format(min(image_times), "%Y-%m-%d")
end_date   <- format(max(image_times), "%Y-%m-%d")

flow <- readNWISdv(
  siteNumbers = "08386000",
  parameterCd = "00060",
  startDate   = start_date,
  endDate     = end_date
)
flow <- renameNWISColumns(flow)
flow
```

## Downloading images around a flow event

Suppose the Acme gage recorded a notable rise. Download images from the
Roswell camera bracketing that period to see whether it was visible
upstream:

``` r

event_start <- as.POSIXct("2025-06-10 00:00:00", tz = "UTC")
event_end   <- as.POSIXct("2025-06-12 23:59:59", tz = "UTC")

dest <- file.path(tempdir(), "pecos_event")
dir.create(dest, showWarnings = FALSE)

paths <- download_images(
  cam_id   = cam_id,
  dest_dir = dest,
  size     = "small",
  after    = event_start,
  before   = event_end,
  limit    = 50
)

# How many images were captured during the event window?
length(paths)
```

Re-running
[`download_images()`](https://connorb.github.io/flowcam/reference/download_images.md)
after a partial download is safe: files already in `dest` are skipped
unless you pass `overwrite = TRUE`.

## Overlay images for gage-reading annotation

The `"overlay"` size embeds a gage-height annotation directly on the
image. These are useful for field verification and training data:

``` r

# Build URLs for the overlay version of the same images
imgs <- list_images(cam_id,
                    after  = event_start,
                    before = event_end,
                    limit  = 5)

overlay_urls <- build_image_url(roswell, imgs$filename, size = "overlay")
overlay_urls
```

## Daily timelapse for the Roswell camera

If timelapse is enabled,
[`get_timelapse_url()`](https://connorb.github.io/flowcam/reference/get_timelapse_url.md)
returns the URL to the current day’s MP4:

``` r

tl_url <- get_timelapse_url(cam_id)
tl_url
```

Open the URL in a browser or use `utils::browseURL(tl_url)` to view it
directly.

## Comparing both sites

The Acme gage (08386000) is ~45 km downstream of the Roswell camera
(08385630). Checking both cameras on the same day makes it possible to
track a flood wave moving through the reach:

``` r

# List the most recent image from each site on the same day
roswell_imgs <- list_images(roswell$camId[[1]], limit = 1, raw_item = TRUE)
acme_imgs    <- list_images(acme$camId[[1]],   limit = 1, raw_item = TRUE)

rbind(
  data.frame(site = "Roswell (08385630)", roswell_imgs),
  data.frame(site = "Acme (08386000)",    acme_imgs)
)
```

## Tips

- **Rate limits**: unauthenticated requests share a pool across all
  users. Call
  [`set_nims_key()`](https://connorb.github.io/flowcam/reference/set_nims_key.md)
  once (see
  [`vignette("getting-started")`](https://connorb.github.io/flowcam/articles/getting-started.md))
  to raise your personal limit.
- **Large downloads**: set `limit` conservatively while exploring;
  images at the `"small"` size are roughly 150–300 KB each. The
  `"thumb"` size is useful when you only need a visual overview.
- **Time zones**: all NIMS timestamps are UTC. The `tz` column in camera
  metadata records the local time zone of the installation if you need
  to convert.
- **Image availability**: `newestImageDT` in the camera metadata gives
  the age of the most recent image—useful for detecting outages before
  you start a download loop.
