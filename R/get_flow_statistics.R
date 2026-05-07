#' Retrieve historical flow statistics for a USGS gage
#'
#' Provides historical context for interpreting camera imagery — "is this
#' flow high or low?" — by returning day-of-year percentile curves or
#' period-of-record summaries.
#'
#' Wraps [dataRetrieval::read_waterdata_stats_por()] (`type = "daily_normals"`)
#' or [dataRetrieval::read_waterdata_stats_daterange()] (`type =
#' "period_summary"`).
#'
#' @param site_id Character. A single NWIS site number (e.g. `"05366800"` or
#'   `"USGS-05366800"`). Exactly one of `site_id` or `cam_id` must be provided.
#' @param cam_id Character. A camera identifier. If supplied, the function
#'   resolves the associated NWIS site ID via [find_cameras()]. Exactly one of
#'   `site_id` or `cam_id` must be provided.
#' @param parameter_code Character. One or more five-digit USGS parameter codes.
#'   Default `"00060"` (discharge, ft³/s).
#' @param type Character. `"daily_normals"` (default) returns day-of-year and
#'   month-of-year percentile/statistic curves, suitable for overlaying on a
#'   time series plot. `"period_summary"` returns calendar-month, calendar-year,
#'   and water-year summaries.
#' @param computation Character vector. One or more of `"percentile"` (default),
#'   `"arithmetic_mean"`, `"minimum"`, `"maximum"`, `"median"`. When `NULL` or
#'   `NA`, all computation types are returned.
#' @param time For `type = "period_summary"` only. A POSIXct, Date, or character
#'   vector of length 1 or 2 (start, end) used to restrict the date range of
#'   the summary. Follows the same semantics as the `time` argument in
#'   [get_site_streamflow()]. `NULL` (default) returns the full period of
#'   record. Ignored when `type = "daily_normals"`.
#'
#' @return A tibble. All types include columns:
#'   \describe{
#'     \item{`site_id`}{Bare NWIS site number.}
#'     \item{`parameter_code`}{Five-digit parameter code.}
#'     \item{`unit_of_measure`}{Units string.}
#'     \item{`computation`}{Statistical method (e.g. `"percentile"`).}
#'     \item{`percentile`}{Integer percentile (e.g. `50L`); `NA` for
#'       non-percentile computations.}
#'     \item{`value`}{Numeric statistic value.}
#'     \item{`sample_count`}{Number of observations used to compute the
#'       statistic.}
#'   }
#'   `type = "daily_normals"` additionally includes:
#'   \describe{
#'     \item{`month_day`}{Character MM-DD representing the day or month of year.}
#'   }
#'   `type = "period_summary"` additionally includes:
#'   \describe{
#'     \item{`interval_type`}{One of `"calendar_month"`, `"calendar_year"`, or
#'       `"water_year"`.}
#'     \item{`start_date`}{Date. Start of the summary interval.}
#'     \item{`end_date`}{Date. End of the summary interval.}
#'   }
#'   Returns a zero-row tibble (with correct column types) when no data are
#'   found. Requires the [dataRetrieval] package.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' # Day-of-year discharge percentile curves (the 10/25/50/75/90th percentiles)
#' get_flow_statistics("05366800")
#'
#' # Annual and monthly discharge summaries
#' get_flow_statistics("05366800", type = "period_summary")
#'
#' # Restrict period_summary to a specific date range
#' get_flow_statistics(
#'   "05366800",
#'   type = "period_summary",
#'   time = c("2010-01-01", "2020-12-31")
#' )
#'
#' # Multiple computation types
#' get_flow_statistics(
#'   "05366800",
#'   computation = c("minimum", "median", "maximum")
#' )
#'
#' # Overlay on a streamflow time series
#' flow  <- get_site_streamflow("05366800", time = "P1Y")
#' stats <- get_flow_statistics("05366800")
#' }
get_flow_statistics <- function(
  site_id = NULL,
  cam_id = NULL,
  parameter_code = "00060",
  type = c("daily_normals", "period_summary"),
  computation = "percentile",
  time = NULL
) {
  .nims_enter()
  on.exit(.nims_exit(), add = TRUE)

  rlang::check_installed(
    c("dataRetrieval", "sf"),
    reason = "to retrieve flow statistics from the USGS Water Data API"
  )

  type <- rlang::arg_match(type)

  ids <- .resolve_site_id(site_id, cam_id)
  site_id <- ids$site_id
  ml_id <- ids$ml_id

  computation_arg <- if (length(computation) == 0L || all(is.na(computation))) {
    NA_character_
  } else {
    computation
  }

  if (type == "daily_normals") {
    raw <- tryCatch(
      .with_usgs_quota(
        dataRetrieval::read_waterdata_stats_por(
          monitoring_location_id = ml_id,
          parameter_code = parameter_code,
          computation_type = computation_arg
        )
      ),
      error = function(e) {
        cli::cli_abort(
          c(
            "Failed to retrieve daily normal statistics for site {.val {site_id}}.",
            "x" = conditionMessage(e)
          )
        )
      }
    )

    if (nrow(raw) == 0L) {
      return(.empty_stats_tibble("daily_normals"))
    }

    raw <- sf::st_drop_geometry(raw)

    month_day <- if ("time_of_year" %in% names(raw)) {
      raw$time_of_year
    } else if (all(c("month_nu", "day_nu") %in% names(raw))) {
      sprintf("%02d-%02d", as.integer(raw$month_nu), as.integer(raw$day_nu))
    } else if ("start_date" %in% names(raw)) {
      format(as.Date(raw$start_date), "%m-%d")
    } else {
      cli::cli_abort(
        "Could not find daily-normal month/day columns in USGS response."
      )
    }

    tibble::tibble(
      site_id = sub("^USGS-", "", raw$monitoring_location_id),
      parameter_code = raw$parameter_code,
      unit_of_measure = raw$unit_of_measure,
      month_day = month_day,
      computation = raw$computation,
      percentile = suppressWarnings(as.integer(raw$percentile)),
      value = raw$value,
      sample_count = suppressWarnings(as.integer(raw$sample_count))
    )
  } else {
    dr_time <- .build_dr_time(time)
    start_date <- if (length(dr_time) == 2L) dr_time[[1L]] else NA_character_
    end_date <- if (length(dr_time) == 2L) {
      dr_time[[2L]]
    } else if (!is.na(dr_time[[1L]])) {
      NA_character_
    } else {
      NA_character_
    }
    if (length(dr_time) == 1L && !is.na(dr_time)) {
      start_date <- dr_time
      end_date <- NA_character_
    }

    raw <- tryCatch(
      .with_usgs_quota(
        dataRetrieval::read_waterdata_stats_daterange(
          monitoring_location_id = ml_id,
          parameter_code = parameter_code,
          computation_type = computation_arg,
          start_date = start_date,
          end_date = end_date
        )
      ),
      error = function(e) {
        cli::cli_abort(
          c(
            "Failed to retrieve period summary statistics for site {.val {site_id}}.",
            "x" = conditionMessage(e)
          )
        )
      }
    )

    if (nrow(raw) == 0L) {
      return(.empty_stats_tibble("period_summary"))
    }

    raw <- sf::st_drop_geometry(raw)

    tibble::tibble(
      site_id = sub("^USGS-", "", raw$monitoring_location_id),
      parameter_code = raw$parameter_code,
      unit_of_measure = raw$unit_of_measure,
      interval_type = raw$interval_type,
      start_date = suppressWarnings(as.Date(raw$start_date)),
      end_date = suppressWarnings(as.Date(raw$end_date)),
      computation = raw$computation,
      percentile = suppressWarnings(as.integer(raw$percentile)),
      value = raw$value,
      sample_count = suppressWarnings(as.integer(raw$sample_count))
    )
  }
}

#' Build empty zero-row tibbles for get_flow_statistics return paths
#' @keywords internal
.empty_stats_tibble <- function(type) {
  base <- tibble::tibble(
    site_id = character(),
    parameter_code = character(),
    unit_of_measure = character(),
    computation = character(),
    percentile = integer(),
    value = numeric(),
    sample_count = integer()
  )
  if (type == "daily_normals") {
    tibble::add_column(base, month_day = character(), .before = "computation")
  } else {
    tibble::add_column(
      base,
      interval_type = character(),
      start_date = as.Date(character()),
      end_date = as.Date(character()),
      .before = "computation"
    )
  }
}
