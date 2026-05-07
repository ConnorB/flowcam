# flowcam 0.1.0

## Initial release

* Query USGS NIMS API camera metadata with `find_cameras()` and `find_gage_cameras()`.
* List available images for a camera with `list_images()`.
* Build and retrieve timelapse image URLs with `build_image_url()` and `get_timelapse_url()`.
* Download images to disk with `download_images()`.
* Assemble animated GIFs from downloaded frames with `make_gif()`.
* Assemble MP4 videos from downloaded frames with `make_video()` (requires the `av` package).
* API key management via `set_nims_key()` and the `API_USGS_PAT` environment variable.
