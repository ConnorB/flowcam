#' Query NIMS cameras and enrich with NWIS site metadata
#'
#' Calls [find_cameras()] for the given NWIS site ID, then joins the result
#' with site metadata from `dataRetrieval::read_waterdata_monitoring_location()`.
#' Optionally appends a `data_types` list-column with the available time series
#' at the site via [get_site_data_availability()].
#' Requires the `dataRetrieval` package.
#'
#' @param site_id Character. A single 8-to-15-digit NWIS site number
#'   (e.g. `"05366800"`).
#' @param include_availability Logical. When `TRUE` (default), a `data_types`
#'   list-column is appended containing a tibble of available time series for
#'   the site (from [get_site_data_availability()]). Set to `FALSE` to skip this
#'   extra API call and return only the camera and site metadata.
#'
#' @return A tibble with all camera columns from [find_cameras()] plus
#'   these site metadata columns when available: `monitoring_location_name`,
#'   `state_name`, `county_name`, `hydrologic_unit_code`, `drainage_area`
#'   (total drainage area in square miles), and `altitude` (elevation in feet
#'   above the stated vertical datum). When `include_availability = TRUE`,
#'   a `data_types` list-column is also included; each element is a tibble
#'   with columns from [get_site_data_availability()].
#'
#' @export
#'
#' @examples
#' \dontrun{
#' # With available time series (default)
#' find_gage_cameras("05366800")
#'
#' # Site metadata only, no data availability call
#' find_gage_cameras("05366800", include_availability = FALSE)
#' }
find_gage_cameras <- function(site_id, include_availability = TRUE) {
  .nims_enter()
  on.exit(.nims_exit(), add = TRUE)

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
    .with_usgs_quota(
      dataRetrieval::read_waterdata_monitoring_location(
        monitoring_location_id = paste0("USGS-", site_id)
      )
    ),
    error = function(e) {
      cli::cli_warn(
        "Could not retrieve NWIS site info for {.val {site_id}}: {conditionMessage(e)}"
      )
      NULL
    }
  )

  if (!is.null(site_info) && nrow(site_info) > 0L) {
    # Strip "USGS-" prefix so the join key matches cameras$nwisId
    site_info[["nwisId"]] <- sub("^USGS-", "", site_info[["monitoring_location_id"]])

    enrich_cols <- intersect(
      c("nwisId", "monitoring_location_name", "state_name",
        "county_name", "hydrologic_unit_code", "drainage_area", "altitude"),
      names(site_info)
    )
    site_subset <- site_info[, enrich_cols, drop = FALSE]

    # Left join: keep all camera rows
    cameras <- tibble::as_tibble(
      merge(cameras, site_subset, by = "nwisId", all.x = TRUE)
    )
  }

  if (include_availability) {
    avail <- tryCatch(
      get_site_data_availability(site_id = site_id),
      error = function(e) {
        cli::cli_warn(
          "Could not retrieve data availability for site {.val {site_id}}: {conditionMessage(e)}"
        )
        NULL
      }
    )
    cameras[["data_types"]] <- list(avail)
  }

  cameras
}
