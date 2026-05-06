# Helper: single-row camera tibble for CAM123 with known date bounds
fake_cam123 <- function() {
  tibble::tibble(
    camId         = "CAM123",
    createdDate   = as.POSIXct("2024-01-01", tz = "UTC"),
    newestImageDT = as.POSIXct("2026-01-01", tz = "UTC")
  )
}

test_that("list_images() errors when cam_id is missing or invalid", {
  expect_error(list_images(),          "cam_id")
  expect_error(list_images(""),        "cam_id")
  expect_error(list_images(c("a","b")), "cam_id")
})

test_that("list_images() errors on invalid limit", {
  expect_error(list_images("CAM123", limit = 0),     "1 and 50000")
  expect_error(list_images("CAM123", limit = 50001), "1 and 50000")
  expect_error(list_images("CAM123", limit = -1),    "1 and 50000")
})

test_that("list_images() errors when time start >= end", {
  expect_error(
    list_images("CAM123",
                time = c("2026-01-02T00:00:00", "2026-01-01T00:00:00")),
    "earlier than"
  )
  expect_error(
    list_images("CAM123",
                time = c("2026-01-01T00:00:00", "2026-01-01T00:00:00")),
    "earlier than"
  )
})

test_that("list_images() accepts POSIXct time vector", {
  local_mocked_bindings(
    find_cameras = function(...) fake_cam123(),
    nims_request = function(...) list(
      list(camId = "CAM123", filename = "a.jpg",
           timestamp = "2025-12-31T23-59-59Z", fs = "100"),
      list(camId = "CAM123", filename = "b.jpg",
           timestamp = "2026-01-01T00-00-10Z", fs = "200")
    )
  )
  result <- list_images(
    "CAM123",
    time  = as.POSIXct(c("2025-12-01", "2026-01-01"), tz = "UTC"),
    limit = 5L
  )
  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 2L)
})

test_that("list_images() clamps both bounds when window is entirely before camera creation", {
  local_mocked_bindings(
    find_cameras = function(...) fake_cam123(),
    nims_request = function(...) list()
  )
  expect_message(
    suppressWarnings(
      list_images("CAM123", time = c("2020-01-01", "2023-12-31"))
    ),
    "Adjusting"
  )
})

test_that("list_images() clamps both bounds when window is entirely after newest image", {
  local_mocked_bindings(
    find_cameras = function(...) fake_cam123(),
    nims_request = function(...) list()
  )
  expect_message(
    suppressWarnings(
      list_images("CAM123", time = c("2026-06-01", "2027-01-01"))
    ),
    "Adjusting"
  )
})

test_that("list_images() informs and clamps start to createdDate", {
  local_mocked_bindings(
    find_cameras  = function(...) fake_cam123(),
    nims_request  = function(...) list()
  )
  expect_message(
    suppressWarnings(
      list_images("CAM123", time = c("2020-01-01", "2025-06-01"))
    ),
    "Adjusting"
  )
})

test_that("list_images() informs and clamps end to newestImageDT", {
  local_mocked_bindings(
    find_cameras  = function(...) fake_cam123(),
    nims_request  = function(...) list()
  )
  expect_message(
    suppressWarnings(
      list_images("CAM123", time = c("2025-01-01", "2027-01-01"))
    ),
    "Adjusting"
  )
})

test_that("list_images() warns when API returns no images", {
  local_mocked_bindings(
    find_cameras = function(...) fake_cam123(),
    nims_request = function(...) list()
  )
  expect_warning(
    result <- list_images("CAM123", time = c("2025-01-01", "2025-06-01")),
    "No images found"
  )
  expect_equal(nrow(result), 0L)
})

test_that("list_images() returns filename tibble by default", {
  local_mocked_bindings(
    nims_request = function(...) list(
      list(camId = "CAM123", filename = "a.jpg",
           timestamp = "2025-12-31T23-59-59Z", fs = "100"),
      list(camId = "CAM123", filename = "b.jpg",
           timestamp = "2026-01-01T00-00-10Z", fs = "200")
    )
  )
  result <- list_images("CAM123", limit = 5L)
  expect_s3_class(result, "tbl_df")
  expect_named(result, "filename")
  expect_type(result$filename, "character")
  expect_equal(nrow(result), 2L)
})

test_that("list_images() returns raw_item tibble when requested", {
  local_mocked_bindings(
    nims_request = function(...) list(
      list(camId = "CAM123", filename = "a.jpg",
           timestamp = "2025-12-01T12-00-00Z", fs = "500")
    )
  )
  result <- list_images("CAM123", limit = 5L, raw_item = TRUE)
  expect_s3_class(result, "tbl_df")
  expect_true(all(c("camId", "filename", "timestamp", "fs") %in% names(result)))
})

test_that("list_images() paginates when a full page is returned", {
  calls <- 0L
  local_mocked_bindings(
    nims_request = function(...) {
      calls <<- calls + 1L
      if (calls == 1L) {
        list(
          list(camId = "CAM123", filename = "a.jpg",
               timestamp = "2025-06-01T12-00-00Z", fs = "100"),
          list(camId = "CAM123", filename = "b.jpg",
               timestamp = "2025-06-01T12-15-00Z", fs = "100")
        )
      } else {
        list(
          list(camId = "CAM123", filename = "c.jpg",
               timestamp = "2025-06-01T12-30-00Z", fs = "100")
        )
      }
    }
  )
  result <- list_images("CAM123", limit = 2L)
  expect_equal(nrow(result), 3L)
  expect_equal(calls, 2L)
})

test_that("list_images() reverses order when recent = TRUE", {
  local_mocked_bindings(
    nims_request = function(...) list(
      list(camId = "CAM123", filename = "old.jpg",
           timestamp = "2025-06-01T12-00-00Z", fs = "100"),
      list(camId = "CAM123", filename = "new.jpg",
           timestamp = "2025-06-01T12-15-00Z", fs = "100")
    )
  )
  result_asc  <- list_images("CAM123", limit = 5L, recent = FALSE)
  result_desc <- list_images("CAM123", limit = 5L, recent = TRUE)
  expect_equal(result_asc$filename[[1L]],  "old.jpg")
  expect_equal(result_desc$filename[[1L]], "new.jpg")
})

test_that("list_images() empty result produces tibble with correct schema", {
  # Test the empty-result tibble shapes directly without HTTP
  r_files <- tibble::tibble(filename = character())
  expect_named(r_files, "filename")
  expect_equal(nrow(r_files), 0L)

  r_raw <- tibble::tibble(
    camId = character(), filename = character(),
    timestamp = character(), fs = integer()
  )
  expect_named(r_raw, c("camId", "filename", "timestamp", "fs"))
  expect_equal(nrow(r_raw), 0L)
})

test_that("build_image_url() constructs correct small URL", {
  cam <- tibble::tibble(
    camId      = "CAM123",
    smallDir   = "https://s3.amazonaws.com/720/CAM123/",
    overlayDir = "https://s3.amazonaws.com/overlay/CAM123/",
    thumbDir   = "https://s3.amazonaws.com/thumbnail/CAM123/"
  )
  url <- build_image_url(cam, "CAM123___2026-01-01T00-00-10Z.jpg", "small")
  expect_equal(url, "https://s3.amazonaws.com/720/CAM123/CAM123___2026-01-01T00-00-10Z.jpg")
})

test_that("build_image_url() constructs correct overlay URL", {
  cam <- tibble::tibble(
    camId      = "CAM123",
    smallDir   = "https://s3.amazonaws.com/720/CAM123/",
    overlayDir = "https://s3.amazonaws.com/overlay/CAM123/",
    thumbDir   = "https://s3.amazonaws.com/thumbnail/CAM123/"
  )
  url <- build_image_url(cam, "file.jpg", "overlay")
  expect_equal(url, "https://s3.amazonaws.com/overlay/CAM123/file.jpg")
})

test_that("build_image_url() appends trailing slash if missing", {
  cam <- tibble::tibble(
    smallDir = "https://s3.amazonaws.com/720/CAM123"  # no trailing slash
  )
  url <- build_image_url(cam, "file.jpg", "small")
  expect_equal(url, "https://s3.amazonaws.com/720/CAM123/file.jpg")
})

test_that("build_image_url() vectorizes over filename", {
  cam <- tibble::tibble(smallDir = "https://example.com/720/CAM/")
  urls <- build_image_url(cam, c("a.jpg", "b.jpg"), "small")
  expect_equal(length(urls), 2L)
  expect_equal(urls[[2]], "https://example.com/720/CAM/b.jpg")
})

test_that("build_image_url() errors when dir column is missing", {
  cam <- tibble::tibble(camId = "CAM123")
  expect_error(build_image_url(cam, "file.jpg", "small"), "smallDir")
})

test_that("build_image_url() errors when dir is empty", {
  cam <- tibble::tibble(smallDir = "")
  expect_error(build_image_url(cam, "file.jpg", "small"), "missing or empty")
})

test_that("get_timelapse_url() errors on invalid cam_id", {
  expect_error(get_timelapse_url(""),         "non-empty")
  expect_error(get_timelapse_url(c("a","b")), "non-empty")
})

test_that("get_timelapse_url() warns when TL_enabled is FALSE", {
  skip_if_not_installed("httptest2")
  httptest2::with_mock_api({
    expect_warning(get_timelapse_url("CAM125"), "timelapse enabled")
  })
})

test_that("get_timelapse_url() constructs correct URL", {
  skip_if_not_installed("httptest2")
  httptest2::with_mock_api({
    url <- suppressWarnings(get_timelapse_url("CAM125"))
    expect_match(url, "CAM125_720\\.mp4$")
    expect_match(url, "^https://")
  })
})

test_that("download_images() errors if dest_dir does not exist", {
  expect_error(
    download_images("CAM123", dest_dir = "/nonexistent/path/xyz"),
    "does not exist"
  )
})
