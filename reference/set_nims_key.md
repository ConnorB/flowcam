# Store your USGS API key in .Renviron

**\[deprecated\]**

`set_nims_key()` has been renamed to
[`set_usgs_api_key()`](https://connorb.github.io/flowcam/reference/set_usgs_api_key.md)
for clarity. Please update your code.

## Usage

``` r
set_nims_key(key)
```

## Arguments

- key:

  A single non-empty character string containing your API key.

## Value

`key`, invisibly.

## Examples

``` r
if (FALSE) { # \dontrun{
# Deprecated: use set_usgs_api_key() instead
set_nims_key("my_api_key_here")
} # }
```
