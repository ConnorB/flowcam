# Find cameras on the same stream network

Uses the USGS Network Linked Data Index (NLDI) to navigate upstream
and/or downstream from a gage site, then returns all flowcam cameras
found along the network within a specified distance.

## Usage

``` r
get_network_cameras(
  site_id = NULL,
  cam_id = NULL,
  direction = c("upstream", "downstream", "both"),
  distance_km = 100
)
```

## Arguments

- site_id:

  Character. A single NWIS site number (e.g. `"05366800"` or
  `"USGS-05366800"`). Exactly one of `site_id` or `cam_id` must be
  provided.

- cam_id:

  Character. A camera identifier. If supplied, the function resolves the
  associated NWIS site ID via
  [`find_cameras()`](https://connorb.github.io/flowcam/reference/find_cameras.md).
  Exactly one of `site_id` or `cam_id` must be provided.

- direction:

  Character. Navigation direction(s): `"upstream"` (upstream tributary),
  `"downstream"` (downstream mainstem), or `"both"`. Default
  `"upstream"`.

- distance_km:

  Numeric. How far (in kilometres) to navigate along the stream network
  from the origin site. Default `100`.

## Value

A tibble with one row per camera (including the origin site) and
columns:

- `site_id`:

  Bare NWIS site number.

- `cam_id`:

  Camera identifier.

- `cam_name`:

  Human-readable camera name.

- `direction`:

  `"origin"`, `"upstream"`, or `"downstream"`.

- `lat`:

  Latitude (decimal degrees, WGS84).

- `lng`:

  Longitude (decimal degrees, WGS84).

Returns a zero-row tibble when no networked cameras are found (including
the origin site if it has no camera). Requires the
[dataRetrieval](https://rdrr.io/pkg/dataRetrieval/man/dataRetrieval.html)
package.

## Details

Useful for anticipating flood wave arrival, comparing conditions across
a watershed, or discovering monitoring locations on the same river
system.

Wraps
[`dataRetrieval::findNLDI()`](https://rdrr.io/pkg/dataRetrieval/man/findNLDI.html).

## Examples

``` r
if (FALSE) { # \dontrun{
# Cameras upstream of a site (within 100 km)
get_network_cameras("05366800")

# Cameras both upstream and downstream (150 km)
get_network_cameras("05366800", direction = "both", distance_km = 150)

# Via camera ID
get_network_cameras(
  cam_id = "WI_Chippewa_River_at_Grand_Ave_at_Eau_Claire",
  direction = "downstream"
)
} # }
```
