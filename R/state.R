# Package-level mutable state for rate-limit reporting.
# Using an environment so values can be updated in place without <<-.
.nims_state <- new.env(parent = emptyenv())
.nims_state$remaining <- NULL
.nims_state$depth <- 0L

# Called at the top of every exported function that touches the NIMS API.
.nims_enter <- function() {
  .nims_state$depth <- .nims_state$depth + 1L
}

# Called via on.exit() in every exported function that touches the NIMS API.
# Only the outermost call (depth returning to 0) emits the message.
.nims_exit <- function() {
  .nims_state$depth <- .nims_state$depth - 1L
  if (.nims_state$depth == 0L && !is.null(.nims_state$remaining)) {
    remaining <- .nims_state$remaining
    cli::cli_alert_info("Remaining NIMS requests this hour: {remaining}")
    .nims_state$remaining <- NULL
  }
}

# Wraps a dataRetrieval call, suppresses all its messages, captures the last
# "Remaining requests this hour:" value, and re-emits it via cli_alert_info.
# `expr` is evaluated in the caller's environment via substitute + eval.
.with_usgs_quota <- function(expr) {
  usgs_remaining <- NULL
  result <- withCallingHandlers(
    expr,
    message = function(m) {
      msg <- conditionMessage(m)
      if (grepl("Remaining requests this hour:", msg, fixed = TRUE)) {
        usgs_remaining <<- trimws(
          sub(".*Remaining requests this hour:\\s*", "", msg)
        )
      }
      invokeRestart("muffleMessage")
    }
  )
  if (!is.null(usgs_remaining)) {
    cli::cli_alert_info(
      "Remaining USGS API requests this hour: {usgs_remaining}"
    )
  }
  result
}
