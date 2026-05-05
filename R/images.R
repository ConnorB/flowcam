#' List image filenames for a NIMS camera
#'
#' Returns a tibble of image filenames (or raw image metadata) for the
#' specified camera. Use the filenames with [build_image_url()] to construct
#' full image URLs.
#'
#' @param cam_id Character. Camera identifier (required). Use [find_cameras()]
#'   to look up valid IDs.
#' @param limit Integer between 1 and 50000. Maximum number of records to
#'   return. Default is `1000`.
#' @param recent Logical. If `TRUE` (default), return the most recent images
#'   first. If `FALSE`, return the oldest images first.
#' @param after POSIXct, Date, or character. Return only images captured on or
#'   after this datetime. Character strings are passed through unchanged; the
#'   API accepts ISO 8601 (`"2025-12-31T00:00:00"`) and NIMS format
#'   (`"2025-12-31T00-00-00Z"`).
#' @param before POSIXct, Date, or character. Return only images captured on or
#'   before this datetime.
#' @param raw_item Logical. If `TRUE`, return a tibble with columns `camId`,
#'   `filename`, `timestamp`, and `fs` (file size in kb). If `FALSE` (default),
#'   return a single-column tibble of filenames.
#'
#' @return A tibble. When `raw_item = FALSE`, one column: `filename`. When
#'   `raw_item = TRUE`, four columns: `camId`, `filename`, `timestamp`, `fs`.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' # 10 most recent images
#' list_images("WI_Chippewa_River_at_Grand_Ave_at_Eau_Claire", limit = 10)
#'
#' # Images in a date window
#' list_images(
#'   "WI_Chippewa_River_at_Grand_Ave_at_Eau_Claire",
#'   after  = as.POSIXct("2025-06-01", tz = "UTC"),
#'   before = as.POSIXct("2025-06-02", tz = "UTC")
#' )
#'
#' # With metadata
#' list_images("WI_Chippewa_River_at_Grand_Ave_at_Eau_Claire",
#'             limit = 5, raw_item = TRUE)
#' }
list_images <- function(cam_id, limit = 1000L, recent = TRUE,
                        after = NULL, before = NULL, raw_item = FALSE) {
  if (missing(cam_id) || !is.character(cam_id) ||
      length(cam_id) != 1L || !nzchar(cam_id)) {
    cli::cli_abort("{.arg cam_id} must be a single non-empty character string.")
  }
  if (!is.numeric(limit) || length(limit) != 1L ||
      is.na(limit) || limit < 1 || limit > 50000) {
    cli::cli_abort("{.arg limit} must be an integer between 1 and 50000.")
  }
  limit <- as.integer(limit)

  after_str  <- format_datetime(after,  "after")
  before_str <- format_datetime(before, "before")

  if (!is.null(after_str) && !is.null(before_str)) {
    after_t  <- tryCatch(as.POSIXct(after_str,  tz = "UTC"), error = function(e) NULL)
    before_t <- tryCatch(as.POSIXct(before_str, tz = "UTC"), error = function(e) NULL)
    if (!is.null(after_t) && !is.null(before_t) && after_t >= before_t) {
      cli::cli_abort("{.arg after} must be earlier than {.arg before}.")
    }
  }

  result <- nims_request(
    "/listFiles",
    query = list(
      camId   = cam_id,
      limit   = limit,
      recent  = tolower(as.character(recent)),
      after   = after_str,
      before  = before_str,
      rawItem = tolower(as.character(raw_item))
    )
  )

  if (length(result) == 0L) {
    if (raw_item) {
      return(tibble::tibble(
        camId     = character(),
        filename  = character(),
        timestamp = character(),
        fs        = integer()
      ))
    } else {
      return(tibble::tibble(filename = character()))
    }
  }

  if (raw_item) {
    tibble::tibble(
      camId     = vapply(result, function(x) x[["camId"]]     %||% NA_character_, character(1L)),
      filename  = vapply(result, function(x) x[["filename"]]  %||% NA_character_, character(1L)),
      timestamp = vapply(result, function(x) x[["timestamp"]] %||% NA_character_, character(1L)),
      fs        = vapply(result, function(x) {
        v <- x[["fs"]]
        if (is.null(v)) NA_integer_ else as.integer(v)
      }, integer(1L))
    )
  } else {
    tibble::tibble(filename = vapply(result, as.character, character(1L)))
  }
}

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
build_image_url <- function(camera_row, filename,
                            size = c("small", "overlay", "thumb")) {
  size <- match.arg(size)

  dir_col <- switch(size,
    small   = "smallDir",
    overlay = "overlayDir",
    thumb   = "thumbDir"
  )

  if (!dir_col %in% names(camera_row)) {
    cli::cli_abort(
      "{.field {dir_col}} not found in {.arg camera_row}. \\
       Did {.fn find_cameras} omit it via {.arg return_fields}?"
    )
  }

  base_dir <- camera_row[[dir_col]]
  if (length(base_dir) > 1L) base_dir <- base_dir[[1L]]
  if (is.null(base_dir) || is.na(base_dir) || !nzchar(base_dir)) {
    cli::cli_abort("{.field {dir_col}} is missing or empty for this camera.")
  }
  if (!endsWith(base_dir, "/")) base_dir <- paste0(base_dir, "/")

  paste0(base_dir, filename)
}

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
  if (!endsWith(tl_dir, "/")) tl_dir <- paste0(tl_dir, "/")

  paste0(tl_dir, cam_id, "_720.mp4")
}

#' Download camera images to disk
#'
#' Lists available images for a camera and downloads them to a local directory.
#' Images are fetched directly from USGS S3 storage; no API key is required for
#' the downloads themselves.
#'
#' @param cam_id Character. Camera identifier. Use [find_cameras()] to look up
#'   valid IDs.
#' @param dest_dir Character. Path to an existing local directory where images
#'   will be saved.
#' @param size Image size passed to [build_image_url()]. One of `"small"`
#'   (default), `"overlay"`, or `"thumb"`.
#' @param limit Integer. Maximum number of images to download. Default is `10`.
#' @param after POSIXct, Date, or character. Only download images captured on
#'   or after this datetime.
#' @param before POSIXct, Date, or character. Only download images captured on
#'   or before this datetime.
#' @param overwrite Logical. If `FALSE` (default), skip files that already
#'   exist in `dest_dir` (resume behaviour).
#'
#' @return A character vector of local file paths, invisibly. Failed downloads
#'   are represented as `NA`.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' paths <- download_images(
#'   "WI_Chippewa_River_at_Grand_Ave_at_Eau_Claire",
#'   dest_dir = tempdir(),
#'   limit    = 5
#' )
#' }
download_images <- function(cam_id, dest_dir, size = "small",
                            limit = 10L, after = NULL, before = NULL,
                            overwrite = FALSE) {
  size <- match.arg(size, c("small", "overlay", "thumb"))

  if (!is.character(dest_dir) || length(dest_dir) != 1L || !nzchar(dest_dir)) {
    cli::cli_abort("{.arg dest_dir} must be a single non-empty character string.")
  }
  if (!dir.exists(dest_dir)) {
    cli::cli_abort("{.path {dest_dir}} does not exist. Create it first.")
  }

  # Fail fast: verify camera exists and get dir metadata
  cam <- find_cameras(cam_id = cam_id)
  if (nrow(cam) == 0L) {
    cli::cli_abort("No camera found with {.val {cam_id}}.")
  }

  files <- list_images(cam_id, limit = limit, after = after, before = before)

  if (nrow(files) == 0L) {
    cli::cli_inform("No images found for camera {.val {cam_id}} with the given filters.")
    return(invisible(character(0L)))
  }

  filenames  <- files[["filename"]]
  urls       <- build_image_url(cam[1L, ], filenames, size = size)
  dest_paths <- file.path(dest_dir, filenames)

  n <- length(urls)
  downloaded <- character(n)

  cli::cli_progress_bar(
    name   = paste0("Downloading ", n, " image", if (n != 1) "s"),
    total  = n,
    format = "{cli::pb_bar} {cli::pb_current}/{cli::pb_total} | ETA: {cli::pb_eta}"
  )

  for (i in seq_len(n)) {
    dest <- dest_paths[[i]]

    if (file.exists(dest) && !overwrite) {
      downloaded[[i]] <- dest
      cli::cli_progress_update()
      next
    }

    tryCatch({
      raw <- httr2::resp_body_raw(
        httr2::req_perform(httr2::request(urls[[i]]))
      )
      writeBin(raw, dest)
      downloaded[[i]] <- dest
    }, error = function(e) {
      cli::cli_warn("Failed to download {.url {urls[[i]]}}: {conditionMessage(e)}")
      downloaded[[i]] <<- NA_character_
    })

    cli::cli_progress_update()
  }

  cli::cli_progress_done()

  n_ok   <- sum(!is.na(downloaded))
  n_fail <- sum(is.na(downloaded))
  if (n_fail > 0L) {
    cli::cli_inform("Downloaded {n_ok} image{?s} ({n_fail} failed).")
  } else {
    cli::cli_inform("Downloaded {n_ok} image{?s}.")
  }

  invisible(downloaded)
}
