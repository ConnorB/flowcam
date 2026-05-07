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
#' @param parameter_code Character. Five-digit USGS parameter code. Default
#'   `"00060"` is discharge in cubic feet per second. Other common codes:
#'   `"00010"` (water temperature, \eqn{°C}), `"00065"` (gage height, ft),
#'   `"00095"` (specific conductance, µS/cm).
#' @param type Character. `"continuous"` (default) returns instantaneous
#'   (unit-value) observations; `"daily"` returns daily mean values.
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
  type = c("continuous", "daily")
) {
  .nims_enter()
  on.exit(.nims_exit(), add = TRUE)

  rlang::check_installed(
    "dataRetrieval",
    reason = "to retrieve streamflow data from the USGS Water Data API"
  )

  type <- rlang::arg_match(type)

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
  ml_id <- paste0("USGS-", site_id)

  if (
    !is.character(parameter_code) ||
      length(parameter_code) != 1L ||
      !grepl("^\\d{5}$", parameter_code)
  ) {
    cli::cli_abort(
      "{.arg parameter_code} must be a 5-digit character string (e.g. {.val 00060})."
    )
  }

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

  if (nrow(raw) == 0L) {
    cli::cli_inform(
      "No {type} data found for site {.val {site_id}} \\
       with parameter code {.val {parameter_code}}."
    )
    datetime_col <- if (type == "continuous") {
      as.POSIXct(character(), tz = "UTC")
    } else {
      as.Date(character())
    }
    return(tibble::tibble(
      site_id = character(),
      datetime = datetime_col,
      value = numeric(),
      unit = character(),
      parameter_code = character(),
      approval_status = character()
    ))
  }

  tibble::tibble(
    site_id = sub("^USGS-", "", raw$monitoring_location_id),
    datetime = raw$time,
    value = suppressWarnings(as.numeric(raw$value)),
    unit = raw$unit_of_measure,
    parameter_code = raw$parameter_code,
    approval_status = raw$approval_status
  )
}

#' Build a dataRetrieval-compatible time vector from a flowcam time argument
#'
#' @param time `NULL`, a POSIXct/Date/character vector of length 1 or 2, or an
#'   ISO 8601 duration string (e.g. `"P7D"`).
#' @return A character vector to pass as the `time` argument to
#'   `read_waterdata_continuous()` or `read_waterdata_daily()`.
#' @keywords internal
.build_dr_time <- function(time) {
  if (is.null(time)) {
    return(NA_character_)
  }
  # ISO 8601 duration — pass through unchanged
  if (is.character(time) && length(time) == 1L && grepl("^[Pp]", time)) {
    return(time)
  }
  # Validate and normalise via parse_time_arg, then reconstruct for dataRetrieval
  tr <- parse_time_arg(time)
  if (is.null(tr$after) && is.null(tr$before)) {
    return(NA_character_)
  }
  if (is.null(tr$after)) {
    return(c(NA_character_, tr$before))
  }
  if (is.null(tr$before)) {
    return(tr$after)
  }
  c(tr$after, tr$before)
}
