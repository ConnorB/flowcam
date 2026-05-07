# Resolve a site_id/cam_id pair to a normalised site ID and ml_id

Accepts exactly one of `site_id` or `cam_id`, validates it, and returns
a named list with the bare NWIS site number and the `USGS-`-prefixed
monitoring location ID required by the Water Data API.

## Usage

``` r
.resolve_site_id(site_id, cam_id)
```

## Arguments

- site_id:

  Character or `NULL`.

- cam_id:

  Character or `NULL`.

## Value

A named list: `list(site_id = <chr>, ml_id = <chr>)`.
