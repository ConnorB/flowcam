# Normalise a USGS/NWIS site ID to the bare numeric form.
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

# Validate one or more five-digit USGS parameter codes.
validate_parameter_code <- function(parameter_code) {
  if (is.null(parameter_code)) {
    return(invisible(NULL))
  }
  if (length(parameter_code) == 1L && is.na(parameter_code)) {
    return(invisible(parameter_code))
  }
  if (
    !is.character(parameter_code) ||
      length(parameter_code) < 1L ||
      !all(grepl("^\\d{5}$", parameter_code))
  ) {
    cli::cli_abort(
      "{.arg parameter_code} must be one or more 5-digit character strings \\
       (e.g. {.val 00060}), or {.code NULL} to return all parameters."
    )
  }
  invisible(parameter_code)
}

# Resolve a site or camera ID to bare and USGS-prefixed site IDs.
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
