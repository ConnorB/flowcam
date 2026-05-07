# flowcam 0.1.0.9000

## Testing new features and improvements

* `set_usgs_api_key()` replaces `set_nims_key()`, which is now deprecated.
* New `get_site_streamflow()` retrieves instantaneous or daily discharge (or
  any USGS parameter) for a gage site, making it easy to pair visual camera
  conditions with measured flow data.
* `find_gage_cameras()` now correctly returns `drainage_area` and `altitude`
  columns (the previous names `drain_area_va` and `alt_va` were stale legacy
  column names that caused these fields to silently drop).

## Expanded dataRetrieval integration

* New `get_site_data_availability()` returns the full list of parameter codes
  and periods of record available at a gage — a useful first step before
  calling `get_site_streamflow()`.
* New `get_flow_statistics()` retrieves historical day-of-year percentile
  curves (`type = "daily_normals"`) or annual/monthly period-of-record
  summaries (`type = "period_summary"`), providing context for interpreting
  what a camera is showing relative to historical norms.
* New `get_site_field_measurements()` retrieves manual discharge measurements
  made by USGS hydrographers, which can be compared directly against camera
  imagery taken at the same time.
* New `get_network_cameras()` uses the USGS Network Linked Data Index (NLDI)
  to find cameras on the same stream network, upstream and/or downstream of a
  given site.
* `get_site_streamflow()` now accepts multiple `parameter_code` values in a
  single call; all requested parameters are returned in one tibble.
* `get_site_streamflow()` gains a `water_year` argument: when `TRUE`, a
  `water_year` integer column (Oct 1 – Sep 30) is appended to the result.
* `find_gage_cameras()` gains an `include_availability` argument (default
  `TRUE`) that appends a `data_types` list-column with available time series
  from `get_site_data_availability()`.

# flowcam 0.1.0

## Initial release

* Query USGS NIMS API camera metadata with `find_cameras()` and `find_gage_cameras()`.
* List available images for a camera with `list_images()`.
* Build and retrieve timelapse image URLs with `build_image_url()` and `get_timelapse_url()`.
* Download images to disk with `download_images()`.
* Assemble animated GIFs from downloaded frames with `make_gif()`.
* Assemble MP4 videos from downloaded frames with `make_video()` (requires the `av` package).
* API key management via `set_usgs_api_key()` and the `API_USGS_PAT` environment variable.
