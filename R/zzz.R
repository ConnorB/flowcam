#' flowcam: Access USGS Stream Gage Camera Images via the NIMS API
#'
#' @description
#' flowcam wraps the USGS National Imagery Management System (NIMS) API,
#' providing functions to discover cameras at USGS stream gages, list
#' available images, build image URLs, and download images to disk.
#'
#' ## Main functions
#'
#' - [find_cameras()]: Query the camera catalog by site or camera ID.
#' - [find_gage_cameras()]: Same, enriched with NWIS site metadata via
#'   `dataRetrieval`.
#' - [list_images()]: List image filenames for a camera, with date filtering.
#' - [build_image_url()]: Construct full S3 image URLs from filenames.
#' - [download_images()]: Download images to a local directory.
#' - [get_timelapse_url()]: Get the timelapse video URL for a camera.
#' - [set_nims_key()]: Save your USGS API key to `~/.Renviron`.
#'
#' ## Authentication
#'
#' An API key is optional but prevents rate limiting. Register at
#' <https://api.waterdata.usgs.gov/signup/> and store your key with
#' [set_nims_key()]. The key is read from the `API_USGS_PAT` environment
#' variable, the same variable used by `dataRetrieval`.
#'
#' @keywords internal
"_PACKAGE"
