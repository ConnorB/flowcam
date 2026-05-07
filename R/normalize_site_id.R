#' Normalise a USGS/NWIS site ID
#'
#' Accepts the bare numeric form (`"05366800"`) or the `USGS-` prefixed form
#' (`"USGS-05366800"`) and returns the plain 8-to-15-digit string expected by
#' the NIMS API.
#'
#' @param site_id A single character string.
#' @param arg_name Argument name used in error messages.
#'
#' @return A plain numeric site ID string.
#' @keywords internal
normalize_site_id <- function(site_id, arg_name = "site_id") {
  if (!is.character(site_id) || length(site_id) != 1L || !nzchar(site_id)) {
    cli::cli_abort(
      "{.arg {arg_name}} must be a single non-empty character string."
    )
  }
  site_id <- sub("^USGS-", "", site_id, ignore.case = TRUE)
  if (!grepl("^\\d{8,15}$", site_id)) {
    cli::cli_abort(
      c(
        "{.arg {arg_name}} must be a NWIS site number (8-15 digits).",
        i = "Accepted formats: {.val 05366800} or {.val USGS-05366800}."
      )
    )
  }
  site_id
}

#' Resolve a site_id/cam_id pair to a normalised site ID and ml_id
#'
#' Accepts exactly one of `site_id` or `cam_id`, validates it, and returns a
#' named list with the bare NWIS site number and the `USGS-`-prefixed monitoring
#' location ID required by the Water Data API.
#'
#' @param site_id Character or `NULL`.
#' @param cam_id Character or `NULL`.
#'
#' @return A named list: `list(site_id = <chr>, ml_id = <chr>)`.
#' @keywords internal
.resolve_site_id <- function(site_id, cam_id) {
  if (!is.null(site_id) && !is.null(cam_id)) {
    cli::cli_abort("Provide {.arg site_id} or {.arg cam_id}, not both.")
  }
  if (is.null(site_id) && is.null(cam_id)) {
    cli::cli_abort("Provide either {.arg site_id} or {.arg cam_id}.")
  }
  if (!is.null(cam_id)) {
    cam_info <- find_cameras(cam_id = cam_id)
    if (nrow(cam_info) == 0L || is.na(cam_info$nwisId[[1L]])) {
      cli::cli_abort(
        "Camera {.val {cam_id}} does not have an associated NWIS site ID."
      )
    }
    site_id <- cam_info$nwisId[[1L]]
  }
  site_id <- normalize_site_id(site_id)
  list(site_id = site_id, ml_id = paste0("USGS-", site_id))
}
