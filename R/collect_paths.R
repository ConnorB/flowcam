# Given a vector of NIMS image paths, return one per local calendar day —
# the path whose embedded timestamp is closest to noon in tz_str.
.select_noon <- function(paths, tz_str) {
  ts_raw <- sub(".*___(.+)\\.[^.]+$", "\\1", basename(paths))
  ts_num <- vapply(
    ts_raw,
    function(t) {
      out <- .parse_nims_ts(t)
      if (is.null(out)) NA_real_ else as.numeric(out)
    },
    numeric(1L)
  )

  valid <- !is.na(ts_num)
  if (!any(valid)) {
    return(paths)
  }

  vpaths <- paths[valid]
  local_dt <- as.POSIXct(ts_num[valid], origin = "1970-01-01", tz = tz_str)
  local_date <- as.Date(local_dt, tz = tz_str)
  local_noon <- as.POSIXct(
    paste0(format(local_date, "%Y-%m-%d"), " 12:00:00"),
    tz = tz_str
  )
  dist <- abs(as.numeric(local_dt) - as.numeric(local_noon))

  best <- tapply(
    seq_along(vpaths),
    local_date,
    function(idx) {
      vpaths[idx[which.min(dist[idx])]]
    },
    simplify = FALSE
  )

  sort(unname(unlist(best)))
}

# Shared path-collection logic for make_gif() and make_video().
# Returns list(paths, label, tmp_dir); tmp_dir is non-NULL when images were
# downloaded to a temp directory — the caller must register on.exit() cleanup.
.collect_paths <- function(
  cam_id,
  site_id,
  time,
  size,
  limit,
  dir,
  one_per_day
) {
  if (!is.null(cam_id) && !is.null(site_id)) {
    cli::cli_abort("Provide {.arg cam_id} or {.arg site_id}, not both.")
  }

  cam_meta <- NULL
  if (!is.null(site_id)) {
    site_id <- normalize_site_id(site_id)
    cams <- find_cameras(site_id = site_id)
    if (nrow(cams) == 0L) {
      cli::cli_abort("No cameras found for site {.val {site_id}}.")
    }
    if (nrow(cams) > 1L) {
      cli::cli_abort(
        c(
          "Site {.val {site_id}} has {nrow(cams)} cameras. Specify {.arg cam_id} directly.",
          i = "Available camera IDs: {.val {cams$camId}}"
        )
      )
    }
    cam_id <- cams$camId[[1L]]
    cam_meta <- cams[1L, ]
  }

  tmp_dir <- NULL

  if (!is.null(dir)) {
    if (!is.character(dir) || length(dir) != 1L || !nzchar(dir)) {
      cli::cli_abort("{.arg dir} must be a single non-empty character string.")
    }
    if (!dir.exists(dir)) {
      cli::cli_abort("{.path {dir}} does not exist.")
    }

    all_paths <- sort(
      list.files(
        dir,
        pattern = "\\.(jpg|jpeg|png)$",
        full.names = TRUE,
        ignore.case = TRUE
      )
    )
    if (length(all_paths) == 0L) {
      cli::cli_abort("No JPEG/PNG images found in {.path {dir}}.")
    }

    if (!is.null(cam_id)) {
      all_paths <- all_paths[startsWith(basename(all_paths), cam_id)]
      if (length(all_paths) == 0L) {
        cli::cli_abort(
          "No files matching camera {.val {cam_id}} found in {.path {dir}}."
        )
      }
    }

    if (!is.null(time)) {
      time_range <- parse_time_arg(time)

      file_ts <- vapply(
        basename(all_paths),
        function(f) {
          ts <- sub(".*___(.+)\\.[^.]+$", "\\1", f)
          out <- .parse_nims_ts(ts)
          if (is.null(out)) NA_real_ else as.numeric(out)
        },
        numeric(1L)
      )

      keep <- !is.na(file_ts)

      if (!is.null(time_range$after)) {
        after_num <- as.numeric(
          as.POSIXct(time_range$after, tz = "UTC", format = "%Y-%m-%dT%H:%M:%S")
        )
        keep <- keep & file_ts >= after_num
      }
      if (!is.null(time_range$before)) {
        before_num <- as.numeric(
          as.POSIXct(
            time_range$before,
            tz = "UTC",
            format = "%Y-%m-%dT%H:%M:%S"
          )
        )
        keep <- keep & file_ts <= before_num
      }

      all_paths <- all_paths[keep]
      if (length(all_paths) == 0L) {
        cli::cli_abort(
          "No images remain after applying the {.arg time} filter."
        )
      }
    }

    paths <- all_paths
    label <- if (!is.null(cam_id)) cam_id else basename(normalizePath(dir))
  } else {
    if (is.null(cam_id)) {
      cli::cli_abort("Provide {.arg cam_id}, {.arg site_id}, or {.arg dir}.")
    }
    label <- cam_id
    tmp_dir <- tempfile("flowcam_")
    dir.create(tmp_dir)

    paths <- download_images(
      cam_id = cam_id,
      dest_dir = tmp_dir,
      size = size,
      limit = limit,
      time = time
    )
    paths <- sort(paths[!is.na(paths)])

    if (length(paths) == 0L) {
      unlink(tmp_dir, recursive = TRUE)
      cli::cli_abort("No images were downloaded.")
    }
  }

  if (one_per_day) {
    tz_str <- NULL
    if (!is.null(cam_meta) && nrow(cam_meta) > 0L) {
      tz_str <- cam_meta[["tz"]][[1L]]
    } else if (!is.null(cam_id)) {
      cam_meta <- find_cameras(cam_id = cam_id)
      if (nrow(cam_meta) > 0L) tz_str <- cam_meta[["tz"]][[1L]]
    } else {
      inferred_id <- sub("___.*$", "", basename(paths[[1L]]))
      tmp_meta <- tryCatch(
        find_cameras(cam_id = inferred_id),
        error = function(e) NULL
      )
      if (!is.null(tmp_meta) && nrow(tmp_meta) > 0L) {
        tz_str <- tmp_meta[["tz"]][[1L]]
      }
    }
    if (is.null(tz_str) || is.na(tz_str) || !nzchar(tz_str)) {
      cli::cli_warn(
        "Could not determine camera timezone; using UTC for noon selection."
      )
      tz_str <- "UTC"
    }
    paths <- .select_noon(paths, tz_str)
    cli::cli_inform(
      "Selected {length(paths)} frame{?s} \\
       (one per day, closest to noon {.val {tz_str}})."
    )
  }

  list(paths = paths, label = label, tmp_dir = tmp_dir)
}
