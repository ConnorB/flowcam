#' Find cameras on the same stream network
#'
#' Uses the USGS Network Linked Data Index (NLDI) to navigate upstream and/or
#' downstream from a gage site, then returns all flowcam cameras found along
#' the network within a specified distance.
#'
#' Useful for anticipating flood wave arrival, comparing conditions across a
#' watershed, or discovering monitoring locations on the same river system.
#'
#' Wraps [dataRetrieval::findNLDI()].
#'
#' @param site_id Character. A single NWIS site number (e.g. `"05366800"` or
#'   `"USGS-05366800"`). Exactly one of `site_id` or `cam_id` must be provided.
#' @param cam_id Character. A camera identifier. If supplied, the function
#'   resolves the associated NWIS site ID via [find_cameras()]. Exactly one of
#'   `site_id` or `cam_id` must be provided.
#' @param direction Character. Navigation direction(s): `"upstream"` (upstream
#'   tributary), `"downstream"` (downstream mainstem), or `"both"`. Default
#'   `"upstream"`.
#' @param distance_km Numeric. How far (in kilometres) to navigate along the
#'   stream network from the origin site. Default `100`.
#'
#' @return A tibble with one row per camera (including the origin site) and
#'   columns:
#'   \describe{
#'     \item{`site_id`}{Bare NWIS site number.}
#'     \item{`cam_id`}{Camera identifier.}
#'     \item{`cam_name`}{Human-readable camera name.}
#'     \item{`direction`}{`"origin"`, `"upstream"`, or `"downstream"`.}
#'     \item{`lat`}{Latitude (decimal degrees, WGS84).}
#'     \item{`lng`}{Longitude (decimal degrees, WGS84).}
#'   }
#'   Returns a zero-row tibble when no networked cameras are found (including
#'   the origin site if it has no camera). Requires the [dataRetrieval] package.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' # Cameras upstream of a site (within 100 km)
#' get_network_cameras("05366800")
#'
#' # Cameras both upstream and downstream (150 km)
#' get_network_cameras("05366800", direction = "both", distance_km = 150)
#'
#' # Via camera ID
#' get_network_cameras(
#'   cam_id = "WI_Chippewa_River_at_Grand_Ave_at_Eau_Claire",
#'   direction = "downstream"
#' )
#' }
get_network_cameras <- function(
  site_id     = NULL,
  cam_id      = NULL,
  direction   = c("upstream", "downstream", "both"),
  distance_km = 100
) {
  .nims_enter()
  on.exit(.nims_exit(), add = TRUE)

  rlang::check_installed(
    "dataRetrieval",
    reason = "to navigate stream networks via the USGS NLDI"
  )

  direction <- rlang::arg_match(direction)

  ids     <- .resolve_site_id(site_id, cam_id)
  site_id <- ids$site_id

  nav_codes <- switch(
    direction,
    upstream   = "UT",
    downstream = "DM",
    both       = c("UT", "DM")
  )

  nldi_result <- tryCatch(
    dataRetrieval::findNLDI(
      nwis        = site_id,
      nav         = nav_codes,
      find        = "nwis",
      distance_km = distance_km,
      warn        = FALSE
    ),
    error = function(e) {
      cli::cli_abort(
        c(
          "NLDI network navigation failed for site {.val {site_id}}.",
          "x" = conditionMessage(e)
        )
      )
    }
  )

  # Extract NWIS site IDs from each navigation result.
  # findNLDI returns a named list; navigation results have keys like "UT_nwissite"
  # or "DM_nwissite". The "origin" key contains the starting feature.
  dir_map <- c(UT = "upstream", DM = "downstream")

  discovered <- lapply(names(nldi_result), function(nm) {
    df <- nldi_result[[nm]]
    if (is.null(df) || nrow(df) == 0L) return(NULL)

    if (nm == "origin") {
      site_ids  <- sub("^USGS-", "", df$identifier)
      direction <- rep("origin", length(site_ids))
    } else {
      # Key format: "<NAVCODE>_nwissite"
      nav_code  <- sub("_.*$", "", nm)
      dir_label <- dir_map[nav_code]
      if (is.na(dir_label)) return(NULL)
      site_ids  <- sub("^USGS-", "", df$identifier)
      direction <- rep(dir_label, length(site_ids))
    }
    data.frame(site_id = site_ids, direction = direction,
               stringsAsFactors = FALSE)
  })

  all_sites <- unique(do.call(rbind, Filter(Negate(is.null), discovered)))

  if (nrow(all_sites) == 0L) {
    return(.empty_network_tibble())
  }

  # Fetch all cameras once and filter to discovered sites
  all_cams <- find_cameras()

  if (nrow(all_cams) == 0L) {
    return(.empty_network_tibble())
  }

  matched <- merge(
    all_sites,
    all_cams[, c("nwisId", "camId", "camName", "lat", "lng")],
    by.x = "site_id",
    by.y = "nwisId",
    all.x = FALSE
  )

  if (nrow(matched) == 0L) {
    return(.empty_network_tibble())
  }

  tibble::tibble(
    site_id   = matched$site_id,
    cam_id    = matched$camId,
    cam_name  = matched$camName,
    direction = matched$direction,
    lat       = matched$lat,
    lng       = matched$lng
  )
}

#' @keywords internal
.empty_network_tibble <- function() {
  tibble::tibble(
    site_id   = character(),
    cam_id    = character(),
    cam_name  = character(),
    direction = character(),
    lat       = numeric(),
    lng       = numeric()
  )
}
