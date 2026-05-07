# Changelog

## flowcam 0.1.0.9000

### Testing new features and improvements

- [`set_usgs_api_key()`](https://connorb.github.io/flowcam/reference/set_usgs_api_key.md)
  replaces
  [`set_nims_key()`](https://connorb.github.io/flowcam/reference/set_nims_key.md),
  which is now deprecated.
- New
  [`get_site_streamflow()`](https://connorb.github.io/flowcam/reference/get_site_streamflow.md)
  retrieves instantaneous or daily discharge (or any USGS parameter) for
  a gage site, making it easy to pair visual camera conditions with
  measured flow data.
- [`find_gage_cameras()`](https://connorb.github.io/flowcam/reference/find_gage_cameras.md)
  now correctly returns `drainage_area` and `altitude` columns (the
  previous names `drain_area_va` and `alt_va` were stale legacy column
  names that caused these fields to silently drop).

### Expanded dataRetrieval integration

- New
  [`get_site_data_availability()`](https://connorb.github.io/flowcam/reference/get_site_data_availability.md)
  returns the full list of parameter codes and periods of record
  available at a gage — a useful first step before calling
  [`get_site_streamflow()`](https://connorb.github.io/flowcam/reference/get_site_streamflow.md).
- New
  [`get_flow_statistics()`](https://connorb.github.io/flowcam/reference/get_flow_statistics.md)
  retrieves historical day-of-year percentile curves
  (`type = "daily_normals"`) or annual/monthly period-of-record
  summaries (`type = "period_summary"`), providing context for
  interpreting what a camera is showing relative to historical norms.
- New
  [`get_site_field_measurements()`](https://connorb.github.io/flowcam/reference/get_site_field_measurements.md)
  retrieves manual discharge measurements made by USGS hydrographers,
  which can be compared directly against camera imagery taken at the
  same time.
- New
  [`get_network_cameras()`](https://connorb.github.io/flowcam/reference/get_network_cameras.md)
  uses the USGS Network Linked Data Index (NLDI) to find cameras on the
  same stream network, upstream and/or downstream of a given site.
- [`get_site_streamflow()`](https://connorb.github.io/flowcam/reference/get_site_streamflow.md)
  now accepts multiple `parameter_code` values in a single call; all
  requested parameters are returned in one tibble.
- [`get_site_streamflow()`](https://connorb.github.io/flowcam/reference/get_site_streamflow.md)
  gains a `water_year` argument: when `TRUE`, a `water_year` integer
  column (Oct 1 – Sep 30) is appended to the result.
- [`find_gage_cameras()`](https://connorb.github.io/flowcam/reference/find_gage_cameras.md)
  gains an `include_availability` argument (default `TRUE`) that appends
  a `data_types` list-column with available time series from
  [`get_site_data_availability()`](https://connorb.github.io/flowcam/reference/get_site_data_availability.md).

## flowcam 0.1.0

### Initial release

- Query USGS NIMS API camera metadata with
  [`find_cameras()`](https://connorb.github.io/flowcam/reference/find_cameras.md)
  and
  [`find_gage_cameras()`](https://connorb.github.io/flowcam/reference/find_gage_cameras.md).
- List available images for a camera with
  [`list_images()`](https://connorb.github.io/flowcam/reference/list_images.md).
- Build and retrieve timelapse image URLs with
  [`build_image_url()`](https://connorb.github.io/flowcam/reference/build_image_url.md)
  and
  [`get_timelapse_url()`](https://connorb.github.io/flowcam/reference/get_timelapse_url.md).
- Download images to disk with
  [`download_images()`](https://connorb.github.io/flowcam/reference/download_images.md).
- Assemble animated GIFs from downloaded frames with
  [`make_gif()`](https://connorb.github.io/flowcam/reference/make_gif.md).
- Assemble MP4 videos from downloaded frames with
  [`make_video()`](https://connorb.github.io/flowcam/reference/make_video.md)
  (requires the `av` package).
- API key management via
  [`set_usgs_api_key()`](https://connorb.github.io/flowcam/reference/set_usgs_api_key.md)
  and the `API_USGS_PAT` environment variable.
