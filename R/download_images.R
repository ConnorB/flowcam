#' Download camera images to disk
#'
#' Lists available images for a camera and downloads them to a local directory.
#' Images are fetched directly from USGS S3 storage; no API key is required for
#' the downloads themselves.
#'
#' Identify the camera with either `cam_id` or `site_id` — provide exactly one.
#' `site_id` accepts both bare NWIS numbers (`"05366800"`) and the `USGS-`
#' prefixed form (`"USGS-05366800"`).  When a site has multiple cameras,
#' specify the desired camera via `cam_id` instead.
#'
#' @param cam_id Character. Camera identifier. Use [find_cameras()] to look up
#'   valid IDs. Cannot be used together with `site_id`.
#' @param dest_dir Character. Path to an existing local directory where images
#'   will be saved.
#' @param size Image size passed to [build_image_url()]. One of `"small"`
#'   (default), `"overlay"`, or `"thumb"`.
#' @param limit Integer between 1 and 50000. Page size for the internal
#'   [list_images()] call. Default is `1000`. All images in the requested
#'   time range are downloaded via automatic pagination.
#' @param time POSIXct, Date, or character vector of length 1 or 2 used to
#'   filter images by capture time. A length-1 value is treated as a start
#'   (on or after). A length-2 vector sets the start and end; use `NA` for an
#'   open bound. See [list_images()] for full details.
#' @param overwrite Logical. If `FALSE` (default), skip files that already
#'   exist in `dest_dir` (resume behaviour).
#' @param site_id Character. NWIS site number (e.g. `"05366800"` or
#'   `"USGS-05366800"`). Cannot be used together with `cam_id`. If the site has
#'   more than one camera, supply `cam_id` directly.
#'
#' @return A character vector of local file paths, invisibly. Failed downloads
#'   are represented as `NA`.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' # By cam_id
#' paths <- download_images(
#'   "WI_Chippewa_River_at_Grand_Ave_at_Eau_Claire",
#'   dest_dir = tempdir(),
#'   limit    = 5
#' )
#'
#' # By USGS site ID
#' paths <- download_images(
#'   site_id  = "USGS-05366800",
#'   dest_dir = tempdir(),
#'   limit    = 5
#' )
#' }
download_images <- function(
  cam_id = NULL,
  dest_dir,
  size = "small",
  limit = 1000L,
  time = NULL,
  overwrite = FALSE,
  site_id = NULL
) {
  size <- match.arg(size, c("small", "overlay", "thumb"))

  if (!is.null(cam_id) && !is.null(site_id)) {
    cli::cli_abort("Provide {.arg cam_id} or {.arg site_id}, not both.")
  }

  if (!is.character(dest_dir) || length(dest_dir) != 1L || !nzchar(dest_dir)) {
    cli::cli_abort(
      "{.arg dest_dir} must be a single non-empty character string."
    )
  }
  if (!dir.exists(dest_dir)) {
    cli::cli_abort("{.path {dest_dir}} does not exist. Create it first.")
  }

  # Resolve cam_id from site_id when needed, then verify camera exists
  if (is.null(cam_id)) {
    if (is.null(site_id)) {
      cli::cli_abort("Provide either {.arg cam_id} or {.arg site_id}.")
    }
    site_id <- normalize_site_id(site_id)
    cams <- find_cameras(site_id = site_id)
    if (nrow(cams) == 0L) {
      cli::cli_abort("No cameras found for site {.val {site_id}}.")
    }
    if (nrow(cams) > 1L) {
      cli::cli_abort(
        c(
          "Site {.val {site_id}} has {nrow(cams)} cameras. Specify {.arg cam_id} directly.",
          i = "Available camera IDs: {.val {cams$camId}}"
        )
      )
    }
    cam_id <- cams$camId[[1L]]
  }

  # Fail fast: verify camera exists and get dir metadata
  cam <- find_cameras(cam_id = cam_id)
  if (nrow(cam) == 0L) {
    cli::cli_abort("No camera found with {.val {cam_id}}.")
  }

  files <- list_images(cam_id, limit = limit, time = time)

  if (nrow(files) == 0L) {
    return(invisible(character(0L)))
  }

  filenames <- files[["filename"]]
  urls <- build_image_url(cam[1L, ], filenames, size = size)
  dest_paths <- file.path(dest_dir, filenames)

  n <- length(urls)
  downloaded <- character(n)

  cli::cli_progress_bar(
    name = paste0("Downloading ", n, " image", if (n != 1) "s"),
    total = n,
    format = "{cli::pb_bar} {cli::pb_current}/{cli::pb_total} | ETA: {cli::pb_eta}"
  )

  for (i in seq_len(n)) {
    dest <- dest_paths[[i]]

    if (file.exists(dest) && !overwrite) {
      downloaded[[i]] <- dest
      cli::cli_progress_update()
      next
    }

    tryCatch(
      {
        raw <- httr2::resp_body_raw(
          httr2::req_perform(httr2::request(urls[[i]]))
        )
        writeBin(raw, dest)
        downloaded[[i]] <- dest
      },
      error = function(e) {
        cli::cli_warn(
          "Failed to download {.url {urls[[i]]}}: {conditionMessage(e)}"
        )
        downloaded[[i]] <<- NA_character_
      }
    )

    cli::cli_progress_update()
  }

  cli::cli_progress_done()

  n_ok <- sum(!is.na(downloaded))
  n_fail <- sum(is.na(downloaded))
  if (n_fail > 0L) {
    cli::cli_inform("Downloaded {n_ok} image{?s} ({n_fail} failed).")
  } else {
    cli::cli_inform("Downloaded {n_ok} image{?s}.")
  }

  invisible(downloaded)
}
