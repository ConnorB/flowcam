#' Assemble camera images into an MP4 video
#'
#' Downloads images for a camera over a specified time range and encodes them
#' into an MP4 video using the `av` package. Provide either `cam_id` or
#' `site_id` to identify the camera, and use `time` to restrict the range.
#'
#' When `dir` is supplied, images are read from that local directory instead of
#' being downloaded. You can still pass `cam_id`/`site_id` to select only files
#' belonging to a particular camera (matched by filename prefix) and `time` to
#' filter by timestamp embedded in the filename — useful when a directory
#' contains images from multiple cameras or a wider date range than needed.
#'
#' @param cam_id Character. Camera identifier. Cannot be used with `site_id`.
#' @param site_id Character. NWIS site number (e.g. `"05366800"` or
#'   `"USGS-05366800"`). Cannot be used with `cam_id`.
#' @param time POSIXct, Date, or character vector of length 1 or 2. Same
#'   semantics as [download_images()]. When `dir` is supplied, timestamps are
#'   parsed from the filenames (NIMS format: `<camId>___<timestamp>.jpg`).
#' @param output Character. File path for the output MP4. Defaults to
#'   `"<cam_id>.mp4"` (or `"<site_id>.mp4"`, or the directory basename) in the
#'   working directory.
#' @param fps Positive number. Frames per second. Any positive value is
#'   accepted. Default is `2`.
#' @param size Image size passed to [download_images()]. One of `"small"`
#'   (default), `"overlay"`, or `"thumb"`. Ignored when `dir` is supplied.
#' @param limit Integer. Page size for the internal [list_images()] call.
#'   Default is `1000`. Ignored when `dir` is supplied.
#' @param dir Character. Path to a local directory of already-downloaded images.
#'   When supplied, downloads are skipped and JPEG/PNG files are read from this
#'   directory. `cam_id`/`site_id` and `time` still apply as filters.
#' @param one_per_day Logical. If `TRUE`, reduce frames to one per calendar day
#'   by selecting the image whose capture time is closest to noon in the
#'   camera's local timezone (from the `tz` field of [find_cameras()]). Default
#'   is `FALSE`.
#'
#' @return The output file path, invisibly.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' # Download and assemble images for a date range
#' make_video("WI_Chippewa_River_at_Grand_Ave_at_Eau_Claire",
#'            time = c("2025-06-01", "2025-06-02"), output = "chippewa.mp4")
#'
#' # One frame per day from a local directory
#' make_video(cam_id = "NM_Pecos_Web_Camera_near_Roswell",
#'            time        = c("2023-08-01", "2023-08-31"),
#'            dir         = "~/Downloads/Pecos",
#'            one_per_day = TRUE,
#'            output      = "pecos_august.mp4")
#' }
make_video <- function(
  cam_id = NULL,
  site_id = NULL,
  time = NULL,
  output = NULL,
  fps = 2,
  size = "small",
  limit = 1000L,
  dir = NULL,
  one_per_day = FALSE
) {
  .nims_enter()
  on.exit(.nims_exit(), add = TRUE)

  if (!requireNamespace("av", quietly = TRUE)) {
    cli::cli_abort(
      "The {.pkg av} package is required. Install it with {.run install.packages('av')}."
    )
  }

  if (!is.numeric(fps) || length(fps) != 1L || is.na(fps) || fps <= 0) {
    cli::cli_abort("{.arg fps} must be a single positive number.")
  }

  cp <- .collect_paths(cam_id, site_id, time, size, limit, dir, one_per_day)
  if (!is.null(cp$tmp_dir)) {
    on.exit(unlink(cp$tmp_dir, recursive = TRUE), add = TRUE)
  }

  paths <- cp$paths
  label <- cp$label
  n <- length(paths)

  if (is.null(output)) {
    output <- paste0(label, ".mp4")
  }

  cli::cli_inform("Encoding {n} frame{?s} at {fps} fps...")

  # H.264 requires even dimensions; scale to nearest even width/height.
  # mod() uses commas which ffmpeg's filtergraph parser treats as separators.
  vfilter <- "scale=trunc(iw/2)*2:trunc(ih/2)*2"

  av::av_encode_video(
    paths,
    output,
    framerate = fps,
    vfilter = vfilter,
    verbose = FALSE
  )

  cli::cli_alert_success("Video written to {.path {output}}.")
  invisible(output)
}
