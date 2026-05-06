test_that("find_cameras() errors when both site_id and cam_id are provided", {
  expect_error(
    find_cameras(site_id = "05366800", cam_id = "CAM123"),
    "not both"
  )
})

test_that("find_cameras() errors when return_fields is not a character vector", {
  expect_error(find_cameras(return_fields = 123), "character vector")
})

test_that("find_cameras() returns a tibble with correct structure", {
  skip_if_not_installed("httptest2")
  httptest2::with_mock_api({
    result <- find_cameras()
    expect_s3_class(result, "tbl_df")
    expect_true("camId" %in% names(result))
  })
})

test_that("find_cameras() collapses return_fields vector to comma string", {
  skip_if_not_installed("httptest2")
  # We test this by intercepting the constructed request
  # (indirectly via mock — the fixture must correspond to the collapsed param)
  httptest2::with_mock_api({
    result <- find_cameras(return_fields = c("camName", "newestImageDT"))
    expect_s3_class(result, "tbl_df")
  })
})

test_that("find_gage_cameras() errors without dataRetrieval installed", {
  skip_if(requireNamespace("dataRetrieval", quietly = TRUE),
          "dataRetrieval is installed; skipping absence test")
  expect_error(find_gage_cameras("05366800"), "dataRetrieval")
})

test_that("find_gage_cameras() validates site_id format", {
  expect_error(find_gage_cameras("not-a-site-id"), "8-15 digits")
  expect_error(find_gage_cameras("1234567"),        "8-15 digits")  # too short
  expect_error(find_gage_cameras(12345678),          "single non-empty")  # not char
})
