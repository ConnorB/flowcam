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
#'   these site metadata columns when available: `monitoring_location_name`,
#'   `state_name`, `county_name`, `hydrologic_unit_code`, `drainage_area`
#'   (total drainage area in square miles), and `altitude` (elevation in feet
#'   above the stated vertical datum).
#'
#' @export
#'
#' @examples
#' \dontrun{
#' find_gage_cameras("05366800")
#' }
find_gage_cameras <- function(site_id) {
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

  if (is.null(site_info) || nrow(site_info) == 0L) {
    return(cameras)
  }

  # Strip "USGS-" prefix so the join key matches cameras$nwisId
  site_info[["nwisId"]] <- sub("^USGS-", "", site_info[["monitoring_location_id"]])

  enrich_cols <- intersect(
    c("nwisId", "monitoring_location_name", "state_name",
      "county_name", "hydrologic_unit_code", "drainage_area", "altitude"),
    names(site_info)
  )
  site_subset <- site_info[, enrich_cols, drop = FALSE]

  # Left join: keep all camera rows
  merged <- merge(cameras, site_subset, by = "nwisId", all.x = TRUE)
  tibble::as_tibble(merged)
}
