# Normalise a USGS/NWIS site ID

Accepts the bare numeric form (`"05366800"`) or the `USGS-` prefixed
form (`"USGS-05366800"`) and returns the plain 8-to-15-digit string
expected by the NIMS API.

## Usage

``` r
normalize_site_id(site_id, arg_name = "site_id")
```

## Arguments

- site_id:

  A single character string.

- arg_name:

  Argument name used in error messages.

## Value

A plain numeric site ID string.
