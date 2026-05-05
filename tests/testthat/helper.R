# Shared test fixtures

camera_list <- list(
  list(
    camId          = "CAM123",
    nwisId         = "01234567",
    camName        = "Little River South Bank",
    camDesc        = "Camera at Little River South Bank gaging station",
    lat            = "44.966024",
    lng            = "-87.91303",
    stateAbrv      = "WI",
    tz             = "US/Central",
    defaultPCode   = "00065",
    createdDate    = "2024-01-01T00:00:00.000Z",
    modifiedDate   = "2025-01-01T00:00:00.000Z",
    newestImageDT  = "2026-01-01T00:00:00.000Z",
    TL_enabled     = TRUE,
    TL_lastGeneratedDT  = "2026-01-01T01:00:00.000Z",
    TL_lastImageUsedDT  = "2026-01-01T00:00:00.000Z",
    hideCam        = FALSE,
    overlayDir     = "https://usgs-nims-images.s3.amazonaws.com/overlay/CAM123/",
    thumbDir       = "https://usgs-nims-images.s3.amazonaws.com/thumbnail/CAM123/",
    smallDir       = "https://usgs-nims-images.s3.amazonaws.com/720/CAM123/",
    tlDir          = "https://usgs-nims-images.s3.amazonaws.com/timelapse/CAM123/",
    ingest         = list(period = "247", intr = 60L, hourlyStart = TRUE),
    locus          = "aws"
  ),
  list(
    camId          = "CAM125",
    nwisId         = "12345678",
    camName        = "Great River",
    lat            = "40.714886",
    lng            = "-73.157632",
    stateAbrv      = "NY",
    tz             = "US/Eastern",
    defaultPCode   = "00060",
    TL_enabled     = FALSE,
    overlayDir     = "https://usgs-nims-images.s3.amazonaws.com/overlay/CAM125/",
    thumbDir       = "https://usgs-nims-images.s3.amazonaws.com/thumbnail/CAM125/",
    smallDir       = "https://usgs-nims-images.s3.amazonaws.com/720/CAM125/",
    tlDir          = "https://usgs-nims-images.s3.amazonaws.com/timelapse/CAM125/",
    ingest         = list(period = "start-end", intr = 60L, periodStart = "05:00", periodEnd = "21:00"),
    locus          = "aws"
  )
)

filenames_list <- list(
  "CAM123___2025-12-31T23-59-59Z.jpg",
  "CAM123___2026-01-01T00-00-10Z.jpg"
)

raw_items_list <- list(
  list(
    camId     = "CAM123",
    filename  = "CAM123___2025-12-31T23-59-59Z.jpg",
    timestamp = "2025-12-31T23-59-59Z",
    fs        = "500000"
  )
)
