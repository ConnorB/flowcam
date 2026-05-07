#' Retrieve manual field measurements for a USGS gage
#'
#' Returns the record of in-person discharge measurements made by USGS
#' hydrographers at a gage site. These manual measurements are the "ground
#' truth" used to build stage-discharge rating curves, and they provide direct
#' visual correlates to camera imagery taken at the same location and time.
#'
#' Wraps [dataRetrieval::read_waterdata_field_measurements()].
#'
#' @param site_id Character. A single NWIS site number (e.g. `"05366800"` or
#'   `"USGS-05366800"`). Exactly one of `site_id` or `cam_id` must be provided.
#' @param cam_id Character. A camera identifier. If supplied, the function
#'   resolves the associated NWIS site ID via [find_cameras()]. Exactly one of
#'   `site_id` or `cam_id` must be provided.
#' @param time POSIXct, Date, or character vector of length 1 or 2 specifying
#'   the time window. Follows the same semantics as [get_site_streamflow()].
#'   `NULL` (default) returns all available measurements.
#' @param parameter_code Character. One or more five-digit USGS parameter codes.
#'   Default `"00060"` (discharge, ft³/s). `NULL` returns measurements for all
#'   parameters.
#'
#' @return A tibble with columns:
#'   \describe{
#'     \item{`site_id`}{Bare NWIS site number.}
#'     \item{`datetime`}{POSIXct (UTC) of the measurement.}
#'     \item{`value`}{Numeric measured value.}
#'     \item{`unit`}{Units of measure (e.g. `"ft3/s"`).}
#'     \item{`parameter_code`}{Five-digit parameter code.}
#'     \item{`approval_status`}{`"Approved"` or `"Provisional"`.}
#'     \item{`measurement_rated`}{Quality rating of the measurement:
#'       `"Excellent"` (≤2% error), `"Good"` (≤5%), `"Fair"` (≤8%),
#'       or `"Poor"` (>8%).}
#'     \item{`control_condition`}{Description of channel control conditions
#'       during the measurement.}
#'   }
#'   Returns a zero-row tibble (with correct column types) when no measurements
#'   are found. Compatible with [get_site_streamflow()] output via
#'   `dplyr::bind_rows()` on the shared columns. Requires the [dataRetrieval]
#'   package.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' # All discharge measurements at a site
#' get_site_field_measurements("05366800")
#'
#' # Measurements during a specific period
#' get_site_field_measurements(
#'   "05366800",
#'   time = c("2020-01-01", "2024-12-31")
#' )
#'
#' # Via camera ID
#' get_site_field_measurements(
#'   cam_id = "WI_Chippewa_River_at_Grand_Ave_at_Eau_Claire"
#' )
#'
#' # Compare field measurements against continuous sensor record
#' field <- get_site_field_measurements("05366800", time = "P2Y")
#' sensor <- get_site_streamflow("05366800", time = "P2Y")
#' }
get_site_field_measurements <- function(
  site_id        = NULL,
  cam_id         = NULL,
  time           = NULL,
  parameter_code = "00060"
) {
  .nims_enter()
  on.exit(.nims_exit(), add = TRUE)

  rlang::check_installed(
    "dataRetrieval",
    reason = "to retrieve field measurements from the USGS Water Data API"
  )

  ids     <- .resolve_site_id(site_id, cam_id)
  site_id <- ids$site_id
  ml_id   <- ids$ml_id

  pcode_arg <- if (is.null(parameter_code)) NA_character_ else parameter_code
  dr_time   <- .build_dr_time(time)

  raw <- tryCatch(
    .with_usgs_quota(
      dataRetrieval::read_waterdata_field_measurements(
        monitoring_location_id = ml_id,
        parameter_code         = pcode_arg,
        time                   = dr_time,
        skipGeometry           = TRUE
      )
    ),
    error = function(e) {
      cli::cli_abort(
        c(
          "Failed to retrieve field measurements for site {.val {site_id}}.",
          "x" = conditionMessage(e)
        )
      )
    }
  )

  if (nrow(raw) == 0L) {
    return(tibble::tibble(
      site_id           = character(),
      datetime          = as.POSIXct(character(), tz = "UTC"),
      value             = numeric(),
      unit              = character(),
      parameter_code    = character(),
      approval_status   = character(),
      measurement_rated = character(),
      control_condition = character()
    ))
  }

  tibble::tibble(
    site_id           = sub("^USGS-", "", raw$monitoring_location_id),
    datetime          = raw$time,
    value             = suppressWarnings(as.numeric(raw$value)),
    unit              = raw$unit_of_measure,
    parameter_code    = raw$parameter_code,
    approval_status   = raw$approval_status,
    measurement_rated = raw$measurement_rated,
    control_condition = raw$control_condition
  )
}
