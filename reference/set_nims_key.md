# Store your USGS API key in .Renviron

Writes `API_USGS_PAT` to `~/.Renviron` and applies it immediately in the
current session. The same variable is used by the `dataRetrieval`
package, so one key covers both packages.

## Usage

``` r
set_nims_key(key)
```

## Arguments

- key:

  A single non-empty character string containing your API key.

## Value

`key`, invisibly.

## Details

Register for a free key at <https://api.waterdata.usgs.gov/signup/>.

## Examples

``` r
if (FALSE) { # \dontrun{
set_nims_key("my_api_key_here")
} # }
```
