# build_image_url() errors on multi-row tibble

    Code
      build_image_url(cam, "file.jpg", "small")
    Condition
      Error in `build_image_url()`:
      ! `camera_row` must be a single-row tibble, not 2 rows.

