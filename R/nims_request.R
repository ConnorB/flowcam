NIMS_BASE_URL <- "https://api.waterdata.usgs.gov/nims/v0"

#' Perform a request against the NIMS API
#'
#' Internal helper. Builds an httr2 request with the appropriate base URL,
#' User-Agent, optional API key header, and query parameters, then performs
#' the request and parses the JSON response body.
#'
#' @param endpoint Character string, e.g. `"/cameras"` or `"/listFiles"`.
#' @param query Named list of query parameters. `NULL` values are dropped.
#'
#' @return A parsed R object (list or vector) from the JSON response.
#' @keywords internal
nims_request <- function(endpoint, query = list()) {
  url <- paste0(NIMS_BASE_URL, endpoint)

  ua <- paste0(
    "httr2/",
    utils::packageVersion("httr2"),
    " flowcam/",
    utils::packageVersion("flowcam"),
    " (https://connorb.github.io/flowcam/)"
  )

  req <- httr2::request(url)
  req <- httr2::req_user_agent(req, ua)

  key <- get_api_key()
  if (!is.null(key)) {
    req <- httr2::req_headers_redacted(req, `X-Api-Key` = key)
  }

  query <- query[!vapply(query, is.null, logical(1L))]
  if (length(query) > 0L) {
    req <- do.call(httr2::req_url_query, c(list(req), query))
  }

  req <- httr2::req_error(req, body = function(resp) {
    ct <- httr2::resp_content_type(resp)
    if (grepl("json", ct, fixed = TRUE)) {
      msg <- httr2::resp_body_json(resp)[["message"]]
    } else {
      body <- httr2::resp_body_string(resp)
      msg <- if (grepl("API_KEY_MISSING", body, fixed = TRUE)) {
        "API key missing. Register at <https://api.waterdata.usgs.gov/signup/> then call set_nims_key()."
      } else if (grepl("OVER_RATE_LIMIT", body, fixed = TRUE)) {
        "Rate limit exceeded. Call set_nims_key() to use an API key, or wait before retrying."
      } else {
        paste("HTTP", httr2::resp_status(resp), httr2::resp_status_desc(resp))
      }
    }
    msg
  })

  req <- httr2::req_timeout(req, seconds = 60)

  resp <- httr2::req_perform(req)
  httr2::resp_body_json(resp, simplifyVector = FALSE)
}
