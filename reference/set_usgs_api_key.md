# Store your USGS API key in .Renviron

Writes `API_USGS_PAT` to the user's `~/.Renviron` file and applies it
immediately in the current session. The same variable is used by package
[dataRetrieval](https://rdrr.io/pkg/dataRetrieval/man/dataRetrieval.html),
so one key can be shared across both packages.

## Usage

``` r
set_usgs_api_key(key)
```

## Arguments

- key:

  A single non-empty character string containing your API key.

## Value

`key`, invisibly.

## Details

Register for a free API key at <https://api.waterdata.usgs.gov/signup/>.

## Examples

``` r
if (FALSE) { # \dontrun{
set_usgs_api_key("my_api_key_here")
} # }
```
