.empty_image_tibble <- function(raw_item) {
  if (raw_item) {
    tibble::tibble(camId = character(), filename = character(),
                   timestamp = character(), fs = integer())
  } else {
    tibble::tibble(filename = character())
  }
}

#' List image filenames for a NIMS camera
#'
#' Returns a tibble of image filenames (or raw image metadata) for the
#' specified camera. Use the filenames with [build_image_url()] to construct
#' full image URLs.
#'
#' Identify the camera with either `cam_id` or `site_id` — provide exactly one.
#' `site_id` accepts both bare NWIS numbers (`"05366800"`) and the `USGS-`
#' prefixed form (`"USGS-05366800"`).  When a site has multiple cameras,
#' specify the desired camera via `cam_id` instead.
#'
#' @param cam_id Character. Camera identifier. Use [find_cameras()] to look up
#'   valid IDs. Cannot be used together with `site_id`.
#' @param limit Integer between 1 and 50000. Number of records fetched per
#'   API request (page size). Default is `1000`. All matching images are
#'   returned via automatic pagination regardless of this value.
#' @param recent Logical. If `TRUE` (default), return the most recent images
#'   first. If `FALSE`, return the oldest images first.
#' @param time POSIXct, Date, or character vector of length 1 or 2 used to
#'   filter images by capture time. A length-1 value is treated as a start
#'   (on or after). A length-2 vector sets the start and end; use `NA` for an
#'   open bound (`c("2025-06-01", NA)` = on or after; `c(NA, "2025-06-02")` =
#'   on or before). Character strings are passed through unchanged; the API
#'   accepts ISO 8601 (`"2025-12-31T00:00:00"`) and NIMS format
#'   (`"2025-12-31T00-00-00Z"`).
#' @param raw_item Logical. If `TRUE`, return a tibble with columns `camId`,
#'   `filename`, `timestamp`, and `fs` (file size in kb). If `FALSE` (default),
#'   return a single-column tibble of filenames.
#' @param site_id Character. NWIS site number (e.g. `"05366800"` or
#'   `"USGS-05366800"`). Cannot be used together with `cam_id`. If the site has
#'   more than one camera, supply `cam_id` directly.
#'
#' @return A tibble. When `raw_item = FALSE`, one column: `filename`. When
#'   `raw_item = TRUE`, four columns: `camId`, `filename`, `timestamp`, `fs`.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' # 10 most recent images by cam_id
#' list_images("WI_Chippewa_River_at_Grand_Ave_at_Eau_Claire", limit = 10)
#'
#' # By USGS site ID (bare or prefixed)
#' list_images(site_id = "05366800", limit = 10)
#' list_images(site_id = "USGS-05366800", limit = 10)
#'
#' # Images in a date window
#' list_images(
#'   "WI_Chippewa_River_at_Grand_Ave_at_Eau_Claire",
#'   time = as.POSIXct(c("2025-06-01", "2025-06-02"), tz = "UTC")
#' )
#'
#' # Open-ended: on or after June 1
#' list_images(
#'   "WI_Chippewa_River_at_Grand_Ave_at_Eau_Claire",
#'   time = c("2025-06-01", NA)
#' )
#'
#' # With metadata
#' list_images("WI_Chippewa_River_at_Grand_Ave_at_Eau_Claire",
#'             limit = 5, raw_item = TRUE)
#' }
list_images <- function(cam_id = NULL, limit = 1000L, recent = TRUE,
                        time = NULL, raw_item = FALSE, site_id = NULL) {
  if (!is.null(cam_id) && !is.null(site_id)) {
    cli::cli_abort("Provide {.arg cam_id} or {.arg site_id}, not both.")
  }

  cam_meta <- NULL

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
    cam_id   <- cams$camId[[1L]]
    cam_meta <- cams[1L, ]
  } else if (!is.character(cam_id) || length(cam_id) != 1L || !nzchar(cam_id)) {
    cli::cli_abort("{.arg cam_id} must be a single non-empty character string.")
  }

  if (!is.numeric(limit) || length(limit) != 1L ||
      is.na(limit) || limit < 1 || limit > 50000) {
    cli::cli_abort("{.arg limit} must be an integer between 1 and 50000.")
  }
  limit <- as.integer(limit)

  time_range <- parse_time_arg(time)

  if (!is.null(time)) {
    if (is.null(cam_meta)) {
      cam_meta <- find_cameras(cam_id = cam_id)
    }
    if (nrow(cam_meta) > 0L) {
      created <- cam_meta[["createdDate"]][[1L]]
      newest  <- cam_meta[["newestImageDT"]][[1L]]

      parse_t <- function(s) {
        if (is.null(s)) return(NULL)
        r <- tryCatch(as.POSIXct(sub("T", " ", s), tz = "UTC"), error = function(e) NULL)
        if (!is.null(r) && !is.na(r)) r else NULL
      }

      after_t  <- parse_t(time_range$after)
      before_t <- parse_t(time_range$before)

      # Clamp start: must be >= createdDate and <= newestImageDT
      if (!is.null(after_t)) {
        if (!is.null(created) && !is.na(created) && after_t < created) {
          cli::cli_inform(
            "Adjusting start from {.val {format(after_t, '%Y-%m-%d')}} to \\
             camera creation date ({.val {format(created, '%Y-%m-%d')}})."
          )
          time_range$after <- format(created, "%Y-%m-%dT%H:%M:%S", tz = "UTC")
        } else if (!is.null(newest) && !is.na(newest) && after_t > newest) {
          cli::cli_inform(
            "Adjusting start from {.val {format(after_t, '%Y-%m-%d')}} to \\
             newest image date ({.val {format(newest, '%Y-%m-%d')}})."
          )
          time_range$after <- format(newest, "%Y-%m-%dT%H:%M:%S", tz = "UTC")
        }
      }

      # Clamp end: must be >= createdDate and <= newestImageDT
      if (!is.null(before_t)) {
        if (!is.null(newest) && !is.na(newest) && before_t > newest) {
          cli::cli_inform(
            "Adjusting end from {.val {format(before_t, '%Y-%m-%d')}} to \\
             newest image date ({.val {format(newest, '%Y-%m-%d')}})."
          )
          time_range$before <- format(newest, "%Y-%m-%dT%H:%M:%S", tz = "UTC")
        } else if (!is.null(created) && !is.na(created) && before_t < created) {
          cli::cli_inform(
            "Adjusting end from {.val {format(before_t, '%Y-%m-%d')}} to \\
             camera creation date ({.val {format(created, '%Y-%m-%d')}})."
          )
          time_range$before <- format(created, "%Y-%m-%dT%H:%M:%S", tz = "UTC")
        }
      }
    }
  }

  # Paginate oldest-first using 'after' as a timestamp cursor.
  # rawItem=TRUE is always requested so we have timestamps to advance the cursor.
  # 'recent' ordering is applied after all pages are collected.
  all_items     <- list()
  current_after <- time_range$after

  repeat {
    page <- nims_request(
      "/listFiles",
      query = list(
        camId   = cam_id,
        limit   = limit,
        recent  = "false",
        after   = current_after,
        before  = time_range$before,
        rawItem = "true"
      )
    )

    if (length(page) == 0L) break
    all_items <- c(all_items, page)
    if (length(page) < limit) break

    last_t <- .parse_nims_ts(page[[length(page)]][["timestamp"]])
    if (is.null(last_t)) {
      cli::cli_warn("Could not advance pagination cursor; results may be incomplete.")
      break
    }
    current_after <- format(last_t + 1, "%Y-%m-%dT%H:%M:%S", tz = "UTC")
  }

  if (length(all_items) == 0L) {
    cli::cli_warn("No images found for camera {.val {cam_id}} with the given filters.")
    return(.empty_image_tibble(raw_item))
  }

  if (recent) all_items <- rev(all_items)

  if (raw_item) {
    tibble::tibble(
      camId     = vapply(all_items, function(x) x[["camId"]]     %||% NA_character_, character(1L)),
      filename  = vapply(all_items, function(x) x[["filename"]]  %||% NA_character_, character(1L)),
      timestamp = vapply(all_items, function(x) x[["timestamp"]] %||% NA_character_, character(1L)),
      fs        = vapply(all_items, function(x) {
        v <- x[["fs"]]; if (is.null(v)) NA_integer_ else as.integer(v)
      }, integer(1L))
    )
  } else {
    tibble::tibble(
      filename = vapply(all_items, function(x) x[["filename"]] %||% NA_character_, character(1L))
    )
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
download_images <- function(cam_id = NULL, dest_dir, size = "small",
                            limit = 1000L, time = NULL,
                            overwrite = FALSE, site_id = NULL) {
  size <- match.arg(size, c("small", "overlay", "thumb"))

  if (!is.null(cam_id) && !is.null(site_id)) {
    cli::cli_abort("Provide {.arg cam_id} or {.arg site_id}, not both.")
  }

  if (!is.character(dest_dir) || length(dest_dir) != 1L || !nzchar(dest_dir)) {
    cli::cli_abort("{.arg dest_dir} must be a single non-empty character string.")
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
