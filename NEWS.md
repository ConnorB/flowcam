# flowcam 0.1.0.9000

## Testing new features and improvements

* `set_usgs_api_key()` replaces `set_nims_key()`, which is now deprecated.
* New `get_site_streamflow()` retrieves instantaneous or daily discharge (or
  any USGS parameter) for a gage site, making it easy to pair visual camera
  conditions with measured flow data.
* `find_gage_cameras()` now correctly returns `drainage_area` and `altitude`
  columns (the previous names `drain_area_va` and `alt_va` were stale legacy
  column names that caused these fields to silently drop).

# flowcam 0.1.0

## Initial release

* Query USGS NIMS API camera metadata with `find_cameras()` and `find_gage_cameras()`.
* List available images for a camera with `list_images()`.
* Build and retrieve timelapse image URLs with `build_image_url()` and `get_timelapse_url()`.
* Download images to disk with `download_images()`.
* Assemble animated GIFs from downloaded frames with `make_gif()`.
* Assemble MP4 videos from downloaded frames with `make_video()` (requires the `av` package).
* API key management via `set_usgs_api_key()` and the `API_USGS_PAT` environment variable.
