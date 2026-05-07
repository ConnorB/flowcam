#' Discover available time series at a USGS gage
#'
#' Returns metadata about every time series recorded at a site — parameter
#' codes, units, and period of record — so you know exactly which codes to
#' pass to [get_site_streamflow()].
#'
#' Wraps [dataRetrieval::read_waterdata_ts_meta()].
#'
#' @param site_id Character. A single NWIS site number (e.g. `"05366800"` or
#'   `"USGS-05366800"`). Exactly one of `site_id` or `cam_id` must be provided.
#' @param cam_id Character. A camera identifier. If supplied, the function
#'   resolves the associated NWIS site ID via [find_cameras()]. Exactly one of
#'   `site_id` or `cam_id` must be provided.
#' @param parameter_code Character. One or more five-digit USGS parameter codes
#'   to filter results (e.g. `"00060"` for discharge). Default `NA` returns all
#'   available parameters.
#'
#' @return A tibble with columns:
#'   \describe{
#'     \item{`site_id`}{Bare NWIS site number (without `USGS-` prefix).}
#'     \item{`parameter_code`}{Five-digit parameter code.}
#'     \item{`parameter_name`}{Human-readable parameter name.}
#'     \item{`unit_of_measure`}{Units string (e.g. `"ft3/s"`).}
#'     \item{`begin_utc`}{POSIXct (UTC). Earliest observation in this time series.}
#'     \item{`end_utc`}{POSIXct (UTC). Most recent observation.}
#'     \item{`statistic_id`}{Five-digit statistic code (e.g. `"00003"` for mean).}
#'     \item{`time_series_id`}{Unique identifier for this time series.}
#'   }
#'   Rows are sorted by `parameter_code`. Returns a zero-row tibble when no
#'   time series are found. Requires the [dataRetrieval] package.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' # All parameters at a site
#' get_site_data_availability("05366800")
#'
#' # Discharge only
#' get_site_data_availability("05366800", parameter_code = "00060")
#'
#' # Via camera ID
#' get_site_data_availability(
#'   cam_id = "WI_Chippewa_River_at_Grand_Ave_at_Eau_Claire"
#' )
#'
#' # Chain with get_site_streamflow():
#' avail <- get_site_data_availability("05366800")
#' flow  <- get_site_streamflow("05366800",
#'                              parameter_code = avail$parameter_code[1])
#' }
get_site_data_availability <- function(
  site_id        = NULL,
  cam_id         = NULL,
  parameter_code = NA_character_
) {
  .nims_enter()
  on.exit(.nims_exit(), add = TRUE)

  rlang::check_installed(
    "dataRetrieval",
    reason = "to retrieve time series metadata from the USGS Water Data API"
  )

  ids     <- .resolve_site_id(site_id, cam_id)
  site_id <- ids$site_id
  ml_id   <- ids$ml_id

  raw <- tryCatch(
    .with_usgs_quota(
      dataRetrieval::read_waterdata_ts_meta(
        monitoring_location_id = ml_id,
        parameter_code         = parameter_code,
        properties             = c(
          "monitoring_location_id",
          "parameter_code",
          "parameter_name",
          "unit_of_measure",
          "begin_utc",
          "end_utc",
          "statistic_id",
          "time_series_id"
        ),
        skipGeometry = TRUE
      )
    ),
    error = function(e) {
      cli::cli_abort(
        c(
          "Failed to retrieve time series metadata for site {.val {site_id}}.",
          "x" = conditionMessage(e)
        )
      )
    }
  )

  if (nrow(raw) == 0L) {
    return(tibble::tibble(
      site_id        = character(),
      parameter_code = character(),
      parameter_name = character(),
      unit_of_measure = character(),
      begin_utc      = as.POSIXct(character(), tz = "UTC"),
      end_utc        = as.POSIXct(character(), tz = "UTC"),
      statistic_id   = character(),
      time_series_id = character()
    ))
  }

  out <- tibble::tibble(
    site_id         = sub("^USGS-", "", raw$monitoring_location_id),
    parameter_code  = raw$parameter_code,
    parameter_name  = raw$parameter_name,
    unit_of_measure = raw$unit_of_measure,
    begin_utc       = raw$begin_utc,
    end_utc         = raw$end_utc,
    statistic_id    = raw$statistic_id,
    time_series_id  = raw$time_series_id
  )

  out[order(out$parameter_code), ]
}
