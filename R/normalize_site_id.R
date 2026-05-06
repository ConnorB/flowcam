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
