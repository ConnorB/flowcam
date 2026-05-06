#' Build full image URLs from camera metadata and filenames
#'
#' Combines a camera's base directory with one or more filenames returned by
#' [list_images()] to produce download-ready image URLs.
#'
#' @param camera_row A single-row tibble (or named list) from [find_cameras()].
#'   Must contain the directory column corresponding to `size`.
#' @param filename Character vector of one or more filenames from
#'   [list_images()].
#' @param size Image size. One of:
#'   - `"small"` (default): ~720 px wide (`smallDir`)
#'   - `"overlay"`: full-size overlay image (`overlayDir`)
#'   - `"thumb"`: thumbnail ~200 px tall (`thumbDir`)
#'
#' @return A character vector of full image URLs, one per element of
#'   `filename`.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' cam   <- find_cameras(cam_id = "WI_Chippewa_River_at_Grand_Ave_at_Eau_Claire")
#' imgs  <- list_images(cam$camId[[1]], limit = 5)
#' urls  <- build_image_url(cam, imgs$filename, size = "small")
#' }
build_image_url <- function(
  camera_row,
  filename,
  size = c("small", "overlay", "thumb")
) {
  size <- match.arg(size)

  dir_col <- switch(
    size,
    small = "smallDir",
    overlay = "overlayDir",
    thumb = "thumbDir"
  )

  if (!dir_col %in% names(camera_row)) {
    cli::cli_abort(
      "{.field {dir_col}} not found in {.arg camera_row}. \\
       Did {.fn find_cameras} omit it via {.arg return_fields}?"
    )
  }

  base_dir <- camera_row[[dir_col]]
  if (length(base_dir) > 1L) {
    base_dir <- base_dir[[1L]]
  }
  if (is.null(base_dir) || is.na(base_dir) || !nzchar(base_dir)) {
    cli::cli_abort("{.field {dir_col}} is missing or empty for this camera.")
  }
  if (!endsWith(base_dir, "/")) {
    base_dir <- paste0(base_dir, "/")
  }

  paste0(base_dir, filename)
}
