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
