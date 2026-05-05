# flowcam: Access USGS Stream Gage Camera Images via the NIMS API

flowcam wraps the USGS National Imagery Management System (NIMS) API,
providing functions to discover cameras at USGS stream gages, list
available images, build image URLs, and download images to disk.

### Main functions

- [`find_cameras()`](https://connorb.github.io/flowcam/reference/find_cameras.md):
  Query the camera catalog by site or camera ID.

- [`find_gage_cameras()`](https://connorb.github.io/flowcam/reference/find_gage_cameras.md):
  Same, enriched with NWIS site metadata via `dataRetrieval`.

- [`list_images()`](https://connorb.github.io/flowcam/reference/list_images.md):
  List image filenames for a camera, with date filtering.

- [`build_image_url()`](https://connorb.github.io/flowcam/reference/build_image_url.md):
  Construct full S3 image URLs from filenames.

- [`download_images()`](https://connorb.github.io/flowcam/reference/download_images.md):
  Download images to a local directory.

- [`get_timelapse_url()`](https://connorb.github.io/flowcam/reference/get_timelapse_url.md):
  Get the timelapse video URL for a camera.

- [`set_nims_key()`](https://connorb.github.io/flowcam/reference/set_nims_key.md):
  Save your USGS API key to `~/.Renviron`.

### Authentication

An API key is optional but prevents rate limiting. Register at
<https://api.waterdata.usgs.gov/signup/> and store your key with
[`set_nims_key()`](https://connorb.github.io/flowcam/reference/set_nims_key.md).
The key is read from the `API_USGS_PAT` environment variable, the same
variable used by `dataRetrieval`.

## See also

Useful links:

- <https://github.com/ConnorB/flowcam>

- Report bugs at <https://github.com/ConnorB/flowcam/issues>

## Author

**Maintainer**: Connor Brown <ConnorBrown1996@gmail.com>

Authors:

- Connor Brown <ConnorBrown1996@gmail.com>
