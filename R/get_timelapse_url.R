#' Get the timelapse video URL for a camera
#'
#' Queries the camera's metadata from NIMS and constructs the URL to its
#' timelapse video file (720p MP4). Issues a warning if timelapse is not
#' enabled for the camera.
#'
#' @param cam_id Character. Camera identifier.
#'
#' @return A single character string with the full timelapse video URL.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' get_timelapse_url("WI_Chippewa_River_at_Grand_Ave_at_Eau_Claire")
#' }
get_timelapse_url <- function(cam_id) {
  if (!is.character(cam_id) || length(cam_id) != 1L || !nzchar(cam_id)) {
    cli::cli_abort("{.arg cam_id} must be a single non-empty character string.")
  }

  cam <- find_cameras(cam_id = cam_id)

  if (nrow(cam) == 0L) {
    cli::cli_abort("No camera found with {.val {cam_id}}.")
  }

  tl_enabled <- cam[["TL_enabled"]][[1L]]
  if (!isTRUE(tl_enabled)) {
    cli::cli_warn("Camera {.val {cam_id}} does not have timelapse enabled.")
  }

  tl_dir <- cam[["tlDir"]][[1L]]
  if (is.null(tl_dir) || is.na(tl_dir) || !nzchar(tl_dir)) {
    cli::cli_abort("{.field tlDir} is missing for camera {.val {cam_id}}.")
  }
  if (!endsWith(tl_dir, "/")) {
    tl_dir <- paste0(tl_dir, "/")
  }

  paste0(tl_dir, cam_id, "_720.mp4")
}
