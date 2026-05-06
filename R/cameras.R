#' Query NIMS cameras
#'
#' Returns a tibble of camera metadata from the USGS National Imagery
#' Management System (NIMS). With no arguments, all cameras are returned.
#' Filter by a NWIS site ID or a specific camera ID.
#'
#' @param site_id Character. NWIS site number (e.g. `"05366800"`). Cannot be
#'   used together with `cam_id`.
#' @param cam_id Character. Camera identifier (e.g.
#'   `"WI_Chippewa_River_at_Grand_Ave_at_Eau_Claire"`). Cannot be used together
#'   with `site_id`.
#' @param return_fields Character vector of camera fields to include in the
#'   response (e.g. `c("camName", "newestImageDT")`). `camId` is always
#'   returned regardless of this setting. When `NULL` (the default), all fields
#'   are returned.
#'
#' @return A tibble with one row per camera. Columns depend on `return_fields`.
#'   `lat` and `lng` are returned as numeric. Datetime columns are POSIXct
#'   (UTC). The `ingest` column is a list-column containing each camera's
#'   ingestion configuration.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' # All cameras
#' find_cameras()
#'
#' # Cameras at a specific gage
#' find_cameras(site_id = "05366800")
#'
#' # A specific camera
#' find_cameras(cam_id = "WI_Chippewa_River_at_Grand_Ave_at_Eau_Claire")
#'
#' # Only selected fields
#' find_cameras(return_fields = c("camName", "newestImageDT"))
#' }
find_cameras <- function(site_id = NULL, cam_id = NULL, return_fields = NULL) {
  if (!is.null(site_id) && !is.null(cam_id)) {
    cli::cli_abort("Provide {.arg site_id} or {.arg cam_id}, not both.")
  }
  if (!is.null(site_id)) {
    site_id <- normalize_site_id(site_id)
  }
  if (!is.null(return_fields)) {
    if (!is.character(return_fields)) {
      cli::cli_abort("{.arg return_fields} must be a character vector.")
    }
    return_fields <- paste(return_fields, collapse = ",")
  }

  result <- nims_request(
    "/cameras",
    query = list(
      siteId       = site_id,
      camId        = cam_id,
      returnFields = return_fields
    )
  )

  parse_cameras(result)
}

#' Parse a list of camera objects into a tibble
#'
#' @param result List returned by `nims_request("/cameras")`.
#' @return A tibble.
#' @keywords internal
parse_cameras <- function(result) {
  if (length(result) == 0L) {
    return(tibble::tibble())
  }

  datetime_cols <- c(
    "createdDate", "modifiedDate", "newestImageDT",
    "TL_lastGeneratedDT", "TL_lastImageUsedDT"
  )

  rows <- lapply(result, function(cam) {
    ingest <- cam[["ingest"]]
    cam[["ingest"]] <- NULL

    # Convert NULLs to NA so as_tibble doesn't choke
    cam <- lapply(cam, function(v) if (is.null(v)) NA else v)

    row <- tibble::as_tibble(cam)

    # Coerce lat/lng from string to numeric
    for (col in c("lat", "lng")) {
      if (col %in% names(row)) {
        row[[col]] <- suppressWarnings(as.numeric(row[[col]]))
      }
    }

    # Coerce datetime strings to POSIXct UTC
    for (col in datetime_cols) {
      if (col %in% names(row) && !is.na(row[[col]])) {
        row[[col]] <- as.POSIXct(row[[col]], format = "%Y-%m-%dT%H:%M:%OSZ", tz = "UTC")
      }
    }

    row[["ingest"]] <- list(ingest)
    row
  })

  # Cameras may have different fields when returnFields is used or optional
  # fields are absent. Pad missing columns with NAs before binding.
  all_cols <- unique(unlist(lapply(rows, names)))
  rows <- lapply(rows, function(row) {
    missing <- setdiff(all_cols, names(row))
    for (col in missing) row[[col]] <- NA
    row[all_cols]
  })

  do.call(rbind, rows)
}

#' Query NIMS cameras and enrich with NWIS site metadata
#'
#' Calls [find_cameras()] for the given NWIS site ID, then joins the result
#' with site metadata from `dataRetrieval::read_waterdata_monitoring_location()`.
#' Requires the `dataRetrieval` package.
#'
#' @param site_id Character. A single 8-to-15-digit NWIS site number
#'   (e.g. `"05366800"`).
#'
#' @return A tibble with all camera columns from [find_cameras()] plus
#'   additional site metadata columns from `dataRetrieval` where available.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' find_gage_cameras("05366800")
#' }
find_gage_cameras <- function(site_id) {
  rlang::check_installed(
    "dataRetrieval",
    reason = "to enrich camera records with NWIS site metadata"
  )

  site_id <- normalize_site_id(site_id)

  cameras <- find_cameras(site_id = site_id)

  if (nrow(cameras) == 0L) {
    cli::cli_warn("No cameras found for site {.val {site_id}}.")
    return(cameras)
  }

  site_info <- tryCatch(
    dataRetrieval::read_waterdata_monitoring_location(
      monitoring_location_id = paste0("USGS-", site_id)
    ),
    error = function(e) {
      cli::cli_warn(
        "Could not retrieve NWIS site info for {.val {site_id}}: {conditionMessage(e)}"
      )
      NULL
    }
  )

  if (is.null(site_info) || nrow(site_info) == 0L) {
    return(cameras)
  }

  # Strip "USGS-" prefix so the join key matches cameras$nwisId
  site_info[["nwisId"]] <- sub("^USGS-", "", site_info[["monitoring_location_id"]])

  enrich_cols <- intersect(
    c("nwisId", "monitoring_location_name", "state_name",
      "county_name", "hydrologic_unit_code", "drain_area_va", "alt_va"),
    names(site_info)
  )
  site_subset <- site_info[, enrich_cols, drop = FALSE]

  # Left join: keep all camera rows
  merged <- merge(cameras, site_subset, by = "nwisId", all.x = TRUE)
  tibble::as_tibble(merged)
}
