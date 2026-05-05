# Perform a request against the NIMS API

Internal helper. Builds an httr2 request with the appropriate base URL,
User-Agent, optional API key header, and query parameters, then performs
the request and parses the JSON response body.

## Usage

``` r
nims_request(endpoint, query = list())
```

## Arguments

- endpoint:

  Character string, e.g. `"/cameras"` or `"/listFiles"`.

- query:

  Named list of query parameters. `NULL` values are dropped.

## Value

A parsed R object (list or vector) from the JSON response.
