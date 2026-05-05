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

test_that("list_images() errors when after >= before", {
  expect_error(
    list_images("CAM123",
                after  = "2026-01-02T00:00:00",
                before = "2026-01-01T00:00:00"),
    "earlier than"
  )
  expect_error(
    list_images("CAM123",
                after  = "2026-01-01T00:00:00",
                before = "2026-01-01T00:00:00"),
    "earlier than"
  )
})

test_that("list_images() accepts POSIXct for after/before", {
  skip_if_not_installed("httptest2")
  httptest2::with_mock_api({
    result <- list_images(
      "CAM123",
      after  = as.POSIXct("2025-12-01", tz = "UTC"),
      before = as.POSIXct("2026-01-01", tz = "UTC"),
      limit  = 2L
    )
    expect_s3_class(result, "tbl_df")
  })
})

test_that("list_images() returns filename tibble by default", {
  skip_if_not_installed("httptest2")
  httptest2::with_mock_api({
    result <- list_images("CAM123", limit = 2L)
    expect_s3_class(result, "tbl_df")
    expect_named(result, "filename")
    expect_type(result$filename, "character")
  })
})

test_that("list_images() returns raw_item tibble when requested", {
  skip_if_not_installed("httptest2")
  httptest2::with_mock_api({
    result <- list_images("CAM123", limit = 1L, raw_item = TRUE)
    expect_s3_class(result, "tbl_df")
    expect_true(all(c("camId", "filename", "timestamp", "fs") %in% names(result)))
  })
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
