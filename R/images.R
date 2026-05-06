.empty_image_tibble <- function(raw_item) {
  if (raw_item) {
    tibble::tibble(
      camId = character(),
      filename = character(),
      timestamp = character(),
      fs = integer()
    )
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
list_images <- function(
  cam_id = NULL,
  limit = 1000L,
  recent = TRUE,
  time = NULL,
  raw_item = FALSE,
  site_id = NULL
) {
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
    cam_id <- cams$camId[[1L]]
    cam_meta <- cams[1L, ]
  } else if (!is.character(cam_id) || length(cam_id) != 1L || !nzchar(cam_id)) {
    cli::cli_abort("{.arg cam_id} must be a single non-empty character string.")
  }

  if (
    !is.numeric(limit) ||
      length(limit) != 1L ||
      is.na(limit) ||
      limit < 1 ||
      limit > 50000
  ) {
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
      newest <- cam_meta[["newestImageDT"]][[1L]]

      parse_t <- function(s) {
        if (is.null(s)) {
          return(NULL)
        }
        r <- tryCatch(
          as.POSIXct(sub("T", " ", s), tz = "UTC"),
          error = function(e) NULL
        )
        if (!is.null(r) && !is.na(r)) r else NULL
      }

      after_t <- parse_t(time_range$after)
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
  all_items <- list()
  current_after <- time_range$after

  repeat {
    page <- nims_request(
      "/listFiles",
      query = list(
        camId = cam_id,
        limit = limit,
        recent = "false",
        after = current_after,
        before = time_range$before,
        rawItem = "true"
      )
    )

    if (length(page) == 0L) {
      break
    }
    all_items <- c(all_items, page)
    if (length(page) < limit) {
      break
    }

    last_t <- .parse_nims_ts(page[[length(page)]][["timestamp"]])
    if (is.null(last_t)) {
      cli::cli_warn(
        "Could not advance pagination cursor; results may be incomplete."
      )
      break
    }
    current_after <- format(last_t + 1, "%Y-%m-%dT%H:%M:%S", tz = "UTC")
  }

  if (length(all_items) == 0L) {
    cli::cli_warn(
      "No images found for camera {.val {cam_id}} with the given filters."
    )
    return(.empty_image_tibble(raw_item))
  }

  if (recent) {
    all_items <- rev(all_items)
  }

  if (raw_item) {
    tibble::tibble(
      camId = vapply(
        all_items,
        function(x) x[["camId"]] %||% NA_character_,
        character(1L)
      ),
      filename = vapply(
        all_items,
        function(x) x[["filename"]] %||% NA_character_,
        character(1L)
      ),
      timestamp = vapply(
        all_items,
        function(x) x[["timestamp"]] %||% NA_character_,
        character(1L)
      ),
      fs = vapply(
        all_items,
        function(x) {
          v <- x[["fs"]]
          if (is.null(v)) NA_integer_ else as.integer(v)
        },
        integer(1L)
      )
    )
  } else {
    tibble::tibble(
      filename = vapply(
        all_items,
        function(x) x[["filename"]] %||% NA_character_,
        character(1L)
      )
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

# Given a vector of NIMS image paths, return one per local calendar day —
# the path whose embedded timestamp is closest to noon in tz_str.
.select_noon <- function(paths, tz_str) {
  ts_raw <- sub(".*___(.+)\\.[^.]+$", "\\1", basename(paths))
  ts_num <- vapply(
    ts_raw,
    function(t) {
      out <- .parse_nims_ts(t)
      if (is.null(out)) NA_real_ else as.numeric(out)
    },
    numeric(1L)
  )

  valid <- !is.na(ts_num)
  if (!any(valid)) {
    return(paths)
  }

  vpaths <- paths[valid]
  local_dt <- as.POSIXct(ts_num[valid], origin = "1970-01-01", tz = tz_str)
  local_date <- as.Date(local_dt, tz = tz_str)
  local_noon <- as.POSIXct(
    paste0(format(local_date, "%Y-%m-%d"), " 12:00:00"),
    tz = tz_str
  )
  dist <- abs(as.numeric(local_dt) - as.numeric(local_noon))

  best <- tapply(
    seq_along(vpaths),
    local_date,
    function(idx) {
      vpaths[idx[which.min(dist[idx])]]
    },
    simplify = FALSE
  )

  sort(unname(unlist(best)))
}

# Shared path-collection logic for make_gif() and make_video().
# Returns list(paths, label, tmp_dir); tmp_dir is non-NULL when images were
# downloaded to a temp directory — the caller must register on.exit() cleanup.
.collect_paths <- function(
  cam_id,
  site_id,
  time,
  size,
  limit,
  dir,
  one_per_day
) {
  if (!is.null(cam_id) && !is.null(site_id)) {
    cli::cli_abort("Provide {.arg cam_id} or {.arg site_id}, not both.")
  }

  cam_meta <- NULL
  if (!is.null(site_id)) {
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
    cam_meta <- cams[1L, ]
  }

  tmp_dir <- NULL

  if (!is.null(dir)) {
    if (!is.character(dir) || length(dir) != 1L || !nzchar(dir)) {
      cli::cli_abort("{.arg dir} must be a single non-empty character string.")
    }
    if (!dir.exists(dir)) {
      cli::cli_abort("{.path {dir}} does not exist.")
    }

    all_paths <- sort(
      list.files(
        dir,
        pattern = "\\.(jpg|jpeg|png)$",
        full.names = TRUE,
        ignore.case = TRUE
      )
    )
    if (length(all_paths) == 0L) {
      cli::cli_abort("No JPEG/PNG images found in {.path {dir}}.")
    }

    if (!is.null(cam_id)) {
      all_paths <- all_paths[startsWith(basename(all_paths), cam_id)]
      if (length(all_paths) == 0L) {
        cli::cli_abort(
          "No files matching camera {.val {cam_id}} found in {.path {dir}}."
        )
      }
    }

    if (!is.null(time)) {
      time_range <- parse_time_arg(time)

      file_ts <- vapply(
        basename(all_paths),
        function(f) {
          ts <- sub(".*___(.+)\\.[^.]+$", "\\1", f)
          out <- .parse_nims_ts(ts)
          if (is.null(out)) NA_real_ else as.numeric(out)
        },
        numeric(1L)
      )

      keep <- !is.na(file_ts)

      if (!is.null(time_range$after)) {
        after_num <- as.numeric(
          as.POSIXct(time_range$after, tz = "UTC", format = "%Y-%m-%dT%H:%M:%S")
        )
        keep <- keep & file_ts >= after_num
      }
      if (!is.null(time_range$before)) {
        before_num <- as.numeric(
          as.POSIXct(
            time_range$before,
            tz = "UTC",
            format = "%Y-%m-%dT%H:%M:%S"
          )
        )
        keep <- keep & file_ts <= before_num
      }

      all_paths <- all_paths[keep]
      if (length(all_paths) == 0L) {
        cli::cli_abort(
          "No images remain after applying the {.arg time} filter."
        )
      }
    }

    paths <- all_paths
    label <- if (!is.null(cam_id)) cam_id else basename(normalizePath(dir))
  } else {
    if (is.null(cam_id)) {
      cli::cli_abort("Provide {.arg cam_id}, {.arg site_id}, or {.arg dir}.")
    }
    label <- cam_id
    tmp_dir <- tempfile("flowcam_")
    dir.create(tmp_dir)

    paths <- download_images(
      cam_id = cam_id,
      dest_dir = tmp_dir,
      size = size,
      limit = limit,
      time = time
    )
    paths <- sort(paths[!is.na(paths)])

    if (length(paths) == 0L) {
      unlink(tmp_dir, recursive = TRUE)
      cli::cli_abort("No images were downloaded.")
    }
  }

  if (one_per_day) {
    tz_str <- NULL
    if (!is.null(cam_meta) && nrow(cam_meta) > 0L) {
      tz_str <- cam_meta[["tz"]][[1L]]
    } else if (!is.null(cam_id)) {
      cam_meta <- find_cameras(cam_id = cam_id)
      if (nrow(cam_meta) > 0L) tz_str <- cam_meta[["tz"]][[1L]]
    } else {
      inferred_id <- sub("___.*$", "", basename(paths[[1L]]))
      tmp_meta <- tryCatch(
        find_cameras(cam_id = inferred_id),
        error = function(e) NULL
      )
      if (!is.null(tmp_meta) && nrow(tmp_meta) > 0L) {
        tz_str <- tmp_meta[["tz"]][[1L]]
      }
    }
    if (is.null(tz_str) || is.na(tz_str) || !nzchar(tz_str)) {
      cli::cli_warn(
        "Could not determine camera timezone; using UTC for noon selection."
      )
      tz_str <- "UTC"
    }
    paths <- .select_noon(paths, tz_str)
    cli::cli_inform(
      "Selected {length(paths)} frame{?s} \\
       (one per day, closest to noon {.val {tz_str}})."
    )
  }

  list(paths = paths, label = label, tmp_dir = tmp_dir)
}

#' Assemble camera images into an animated GIF
#'
#' Downloads images for a camera over a specified time range and assembles them
#' into an animated GIF using the `gifski` package. Provide either `cam_id` or
#' `site_id` to identify the camera, and use `time` to restrict the range.
#'
#' When `dir` is supplied, images are read from that local directory instead of
#' being downloaded. You can still pass `cam_id`/`site_id` to select only files
#' belonging to a particular camera (matched by filename prefix) and `time` to
#' filter by timestamp embedded in the filename — useful when a directory
#' contains images from multiple cameras or a wider date range than needed.
#'
#' JPEG frames are converted to PNG in a temporary directory before encoding
#' because `gifski` only accepts PNG input. The `jpeg` and `png` packages are
#' required when any frames are JPEG.
#'
#' @param cam_id Character. Camera identifier. Cannot be used with `site_id`.
#' @param site_id Character. NWIS site number (e.g. `"05366800"` or
#'   `"USGS-05366800"`). Cannot be used with `cam_id`.
#' @param time POSIXct, Date, or character vector of length 1 or 2. Same
#'   semantics as [download_images()]. When `dir` is supplied, timestamps are
#'   parsed from the filenames (NIMS format: `<camId>___<timestamp>.jpg`).
#' @param output Character. File path for the output GIF. Defaults to
#'   `"<cam_id>.gif"` (or `"<site_id>.gif"`, or the directory basename) in the
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
#' make_gif("WI_Chippewa_River_at_Grand_Ave_at_Eau_Claire",
#'          time = c("2025-06-01", "2025-06-02"), output = "chippewa.gif")
#'
#' # One frame per day from a local directory
#' make_gif(cam_id = "NM_Pecos_Web_Camera_near_Roswell",
#'          time        = c("2023-08-01", "2023-08-31"),
#'          dir         = "~/Downloads/Pecos",
#'          one_per_day = TRUE,
#'          output      = "pecos_august.gif")
#' }
make_gif <- function(
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
  if (!requireNamespace("gifski", quietly = TRUE)) {
    cli::cli_abort(
      "The {.pkg gifski} package is required. Install it with {.run install.packages('gifski')}."
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
    output <- paste0(label, ".gif")
  }

  # gifski only accepts PNG; convert any JPEG frames to a temp directory.
  jpeg_idx <- grepl("\\.(jpg|jpeg)$", paths, ignore.case = TRUE)
  if (any(jpeg_idx)) {
    if (
      !requireNamespace("jpeg", quietly = TRUE) ||
        !requireNamespace("png", quietly = TRUE)
    ) {
      cli::cli_abort(
        c(
          "JPEG-to-PNG conversion requires the {.pkg jpeg} and {.pkg png} packages.",
          i = "Install them with {.run install.packages(c('jpeg', 'png'))}."
        )
      )
    }
    png_tmp <- tempfile("flowcam_png_")
    dir.create(png_tmp)
    on.exit(unlink(png_tmp, recursive = TRUE), add = TRUE)

    for (i in which(jpeg_idx)) {
      out_path <- file.path(
        png_tmp,
        paste0(tools::file_path_sans_ext(basename(paths[i])), ".png")
      )
      png::writePNG(jpeg::readJPEG(paths[i]), out_path)
      paths[i] <- out_path
    }
  }

  # Preserve original frame dimensions.
  first_dim <- dim(png::readPNG(paths[[1L]]))

  cli::cli_inform("Assembling {n} frame{?s} at {fps} fps...")

  gifski::gifski(
    paths,
    gif_file = output,
    width = first_dim[2L],
    height = first_dim[1L],
    delay = 1 / fps,
    progress = FALSE
  )

  cli::cli_alert_success("GIF written to {.path {output}}.")
  invisible(output)
}

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

  av::av_encode_video(paths, output, framerate = fps, verbose = FALSE)

  cli::cli_alert_success("Video written to {.path {output}}.")
  invisible(output)
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
