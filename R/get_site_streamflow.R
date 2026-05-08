#' Retrieve streamflow data for a USGS gage
#'
#' Wraps [dataRetrieval::read_waterdata_continuous()] (instantaneous values)
#' or [dataRetrieval::read_waterdata_daily()] (daily mean values) for the
#' USGS gage associated with a flowcam camera. Returns a clean tibble aligned
#' with flowcam conventions.
#'
#' @param site_id Character. A single NWIS site number (e.g. `"05366800"` or
#'   `"USGS-05366800"`). Exactly one of `site_id` or `cam_id` must be provided.
#' @param cam_id Character. A camera identifier (e.g.
#'   `"WI_Chippewa_River_at_Grand_Ave_at_Eau_Claire"`). If supplied, the
#'   function resolves the associated NWIS site ID via [find_cameras()].
#'   Exactly one of `site_id` or `cam_id` must be provided.
#' @param time POSIXct, Date, or character vector of length 1 or 2. Follows
#'   the same semantics as the `time` argument in [list_images()]: length-1 is
#'   treated as a start bound; length-2 sets start and end, with `NA` for an
#'   open bound. ISO 8601 duration strings such as `"P7D"` (last 7 days) or
#'   `"P1Y"` (last year) are also accepted and forwarded to the API unchanged.
#'   When `NULL`, the API default applies (approximately the last year of data
#'   for continuous; all available data for daily).
#' @param parameter_code Character. One or more five-digit USGS parameter
#'   codes. Default `"00060"` is discharge in cubic feet per second. Other
#'   common codes: `"00010"` (water temperature, \eqn{°C}), `"00065"` (gage
#'   height, ft), `"00095"` (specific conductance, µS/cm). When multiple codes
#'   are supplied, all parameters are returned in a single tibble distinguished
#'   by the `parameter_code` column.
#' @param type Character. `"continuous"` (default) returns instantaneous
#'   (unit-value) observations; `"daily"` returns daily mean values.
#' @param water_year Logical. When `TRUE`, appends a `water_year` integer
#'   column (Oct 1 – Sep 30) to the result using
#'   [dataRetrieval::calcWaterYear()]. Default `FALSE`.
#'
#' @return A tibble with columns:
#'   \describe{
#'     \item{`site_id`}{Bare NWIS site number (without `USGS-` prefix).}
#'     \item{`datetime`}{POSIXct (UTC) for `type = "continuous"`; Date for
#'       `type = "daily"`.}
#'     \item{`value`}{Numeric observation value.}
#'     \item{`unit`}{Units of measure (e.g. `"ft3/s"`).}
#'     \item{`parameter_code`}{Five-digit parameter code.}
#'     \item{`approval_status`}{`"Approved"` or `"Provisional"`.}
#'     \item{`water_year`}{Integer water year (only present when
#'       `water_year = TRUE`).}
#'   }
#'   Returns a zero-row tibble (with correct column types) when no data are
#'   found. Requires the [dataRetrieval] package.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' # Instantaneous discharge for the last 7 days
#' get_site_streamflow("05366800", time = "P7D")
#'
#' # Daily discharge for a calendar year
#' get_site_streamflow(
#'   "05366800",
#'   time = c("2024-01-01", "2024-12-31"),
#'   type = "daily"
#' )
#'
#' # Water temperature from a camera ID
#' get_site_streamflow(
#'   cam_id = "WI_Chippewa_River_at_Grand_Ave_at_Eau_Claire",
#'   parameter_code = "00010"
#' )
#'
#' # Multiple parameters at once
#' get_site_streamflow("05366800", parameter_code = c("00060", "00065"))
#'
#' # Include water year column
#' get_site_streamflow("05366800", time = "P1Y", water_year = TRUE)
#'
#' # Pair with image timestamps
#' images <- list_images("05366800", time = c("2024-10-01", "2024-10-07"),
#'                       raw_item = TRUE)
#' flow   <- get_site_streamflow("05366800",
#'                               time = c("2024-10-01", "2024-10-07"))
#' }
get_site_streamflow <- function(
  site_id = NULL,
  cam_id = NULL,
  time = NULL,
  parameter_code = "00060",
  type = c("continuous", "daily"),
  water_year = FALSE
) {
  .nims_enter()
  on.exit(.nims_exit(), add = TRUE)

  rlang::check_installed(
    "dataRetrieval",
    reason = "to retrieve streamflow data from the USGS Water Data API"
  )

  type <- rlang::arg_match(type)

  ids <- .resolve_site_id(site_id, cam_id)
  site_id <- ids$site_id
  ml_id <- ids$ml_id

  validate_parameter_code(parameter_code)

  dr_time <- .build_dr_time(time)

  raw <- tryCatch(
    .with_usgs_quota(
      if (type == "continuous") {
        dataRetrieval::read_waterdata_continuous(
          monitoring_location_id = ml_id,
          parameter_code = parameter_code,
          time = dr_time
        )
      } else {
        dataRetrieval::read_waterdata_daily(
          monitoring_location_id = ml_id,
          parameter_code = parameter_code,
          statistic_id = "00003",
          time = dr_time,
          skipGeometry = TRUE
        )
      }
    ),
    error = function(e) {
      cli::cli_abort(
        c(
          "Failed to retrieve {type} data for site {.val {site_id}}.",
          "x" = conditionMessage(e)
        )
      )
    }
  )

  empty_datetime <- if (type == "continuous") {
    as.POSIXct(character(), tz = "UTC")
  } else {
    as.Date(character())
  }

  if (nrow(raw) == 0L) {
    cli::cli_inform(
      "No {type} data found for site {.val {site_id}} \\
       with parameter code(s) {.val {parameter_code}}."
    )
    out <- tibble::tibble(
      site_id = character(),
      datetime = empty_datetime,
      value = numeric(),
      unit = character(),
      parameter_code = character(),
      approval_status = character()
    )
    if (water_year) {
      out$water_year <- integer()
    }
    return(out)
  }

  out <- tibble::tibble(
    site_id = sub("^USGS-", "", raw$monitoring_location_id),
    datetime = raw$time,
    value = {
      v <- suppressWarnings(as.numeric(raw$value))
      if (any(is.na(v) & !is.na(raw$value))) {
        cli::cli_warn(
          "Some {.field value} entries could not be coerced to numeric and \\
           were set to {.code NA}."
        )
      }
      v
    },
    unit = raw$unit_of_measure,
    parameter_code = raw$parameter_code,
    approval_status = raw$approval_status
  )

  if (water_year) {
    out$water_year <- dataRetrieval::calcWaterYear(out$datetime)
  }

  out
}
