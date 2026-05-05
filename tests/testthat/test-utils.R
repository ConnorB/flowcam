test_that("get_api_key() returns NULL when env var is unset", {
  withr::with_envvar(c(API_USGS_PAT = ""), {
    expect_null(flowcam:::get_api_key())
  })
})

test_that("get_api_key() returns key when env var is set", {
  withr::with_envvar(c(API_USGS_PAT = "test_key_abc"), {
    expect_equal(flowcam:::get_api_key(), "test_key_abc")
  })
})

test_that("format_datetime() returns NULL for NULL input", {
  expect_null(flowcam:::format_datetime(NULL))
})

test_that("format_datetime() passes through character strings unchanged", {
  expect_equal(flowcam:::format_datetime("2026-01-01T00:00:00"), "2026-01-01T00:00:00")
  expect_equal(flowcam:::format_datetime("2025-12-31T00-00-00Z"), "2025-12-31T00-00-00Z")
})

test_that("format_datetime() converts POSIXct to ISO 8601 UTC string", {
  dt <- as.POSIXct("2026-01-01 00:00:00", tz = "UTC")
  result <- flowcam:::format_datetime(dt)
  expect_equal(result, "2026-01-01T00:00:00")
})

test_that("format_datetime() converts POSIXct from non-UTC timezone to UTC", {
  # Chicago is UTC-6 in winter; noon Chicago = 18:00 UTC
  dt <- as.POSIXct("2026-01-01 12:00:00", tz = "America/Chicago")
  result <- flowcam:::format_datetime(dt)
  expect_equal(result, "2026-01-01T18:00:00")
})

test_that("format_datetime() converts Date to midnight UTC ISO 8601", {
  result <- flowcam:::format_datetime(as.Date("2026-03-15"))
  expect_equal(result, "2026-03-15T00:00:00")
})

test_that("format_datetime() errors on invalid types", {
  expect_error(flowcam:::format_datetime(42), "POSIXct")
  expect_error(flowcam:::format_datetime(list("a")), "POSIXct")
})

test_that("parse_cameras() returns empty tibble for empty list", {
  result <- flowcam:::parse_cameras(list())
  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 0L)
})

test_that("parse_cameras() coerces lat/lng to numeric", {
  result <- flowcam:::parse_cameras(camera_list)
  expect_type(result$lat, "double")
  expect_type(result$lng, "double")
  expect_equal(result$lat[[1]], 44.966024)
  expect_equal(result$lng[[1]], -87.91303)
})

test_that("parse_cameras() stores ingest as a list-column", {
  result <- flowcam:::parse_cameras(camera_list)
  expect_true("ingest" %in% names(result))
  expect_type(result$ingest, "list")
  expect_equal(result$ingest[[1]][["period"]], "247")
})

test_that("parse_cameras() returns correct number of rows", {
  result <- flowcam:::parse_cameras(camera_list)
  expect_equal(nrow(result), 2L)
})
