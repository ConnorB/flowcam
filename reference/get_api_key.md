# Retrieve the USGS API key from the environment

Reads `API_USGS_PAT` from the environment. Returns `NULL` (not `""`)
when unset, following the same convention as
[dataRetrieval](https://rdrr.io/pkg/dataRetrieval/man/dataRetrieval.html).

## Usage

``` r
get_api_key()
```

## Value

A single character string, or `NULL` if the variable is unset.
