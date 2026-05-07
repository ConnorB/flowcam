# flowcam: Download and Animate USGS Stream-Gage Camera Images

A tidy interface to the U.S. Geological Survey (USGS) National Imagery
Management System (NIMS) API
(<https://api.waterdata.usgs.gov/docs/nims/overview/>), which stores and
serves images collected by stream-gage cameras at monitoring locations
across the United States. Provides functions to discover cameras by NWIS
site number or camera ID, list and filter available images by date and
time, download images at multiple resolutions, and assemble downloaded
frames into animated GIFs or MP4 videos. Integrates with the
'dataRetrieval' package (<https://doi-usgs.github.io/dataRetrieval/>) to
enrich camera records with watershed metadata (drainage area, hydrologic
unit code, state, county) and to retrieve co-located streamflow, stage,
or water-quality time series — enabling direct comparison of visual
stream conditions with measured observations. API authentication uses
the 'API_USGS_PAT' environment variable shared with 'dataRetrieval', so
a single key covers both packages.

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

- [`set_usgs_api_key()`](https://connorb.github.io/flowcam/reference/set_usgs_api_key.md):
  Save your USGS API key to `~/.Renviron`.

### Authentication

An API key is optional but prevents rate limiting. Register at
<https://api.waterdata.usgs.gov/signup/> and store your key with
[`set_usgs_api_key()`](https://connorb.github.io/flowcam/reference/set_usgs_api_key.md).
The key is read from the `API_USGS_PAT` environment variable, the same
variable used by `dataRetrieval`.

## See also

Useful links:

- <https://connorb.github.io/flowcam/>

- <https://github.com/ConnorB/flowcam>

- <https://connorb.r-universe.dev/flowcam>

- Report bugs at <https://github.com/ConnorB/flowcam/issues>

## Author

**Maintainer**: Connor Brown <ConnorBrown1996@gmail.com>
([ORCID](https://orcid.org/0000-0002-9680-8930))

Authors:

- Connor Brown <ConnorBrown1996@gmail.com>
  ([ORCID](https://orcid.org/0000-0002-9680-8930))
