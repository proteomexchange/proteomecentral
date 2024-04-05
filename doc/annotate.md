# PROXI /annotate endpoint at ProteomeCentral

## Overview
ProteomeCentral hosts an API endpoint for a Quetzal peptide MS2 spectrum annotator based on the PROXI API.
The Quetzal annotator is still in development with an initial release expected in late 2024.

## Endpoint
The primary Quetzal endpoint is via a POST to the PROXI /annotate endpoint at the ProteomeCentral PROXI API service:

```
POST https://proteomecentral.proteomexchange.org/api/proxi/v0.1/annotate?param1=value1&param2=value2
```

## URL Parameters

The endpoint accepts several URL parameters:

- *resultType*: The *resultType* parameter may be `compact` or `full`, following PROXI conventions
    - `compact`: Returns a list of plain PROXI `spectrum` objects
    - `full`: Returns substantial extra information in an `extended_data` component

- *tolerance*: The *tolerance* parameter directs the annotator to use a maximum tolerance as specified (always in ppm)
  This parameter maybe extended in the future to allow specification of either ppm or m/z units

## Input Payload

The Input payload (submitted via POST) must be a JSON list of PROXI spectrum objects to annotate. A single spectrum
must be specified as a list of one item.

```
[
  {
    "attributes": [
      {
        "accession": "MS:1000827",
        "name": "selected ion m/z",
        "value": 401.2628
      },
      {
        "accession": "MS:1000041",
        "name": "charge state",
        "value": 2
      },
      {
        "accession": "MS:1003169",
        "name": "proforma peptidoform sequence",
        "value": "LLSILSR"
      }
    ],
    "extended_data": {}
    },
    "intensities": [
      25679.1973,
      32007.0879,
      27618.2852,
      56783.7109,
      30913.8457,
      25987.8301,
      31703.4883,
      142053.4688,
      176166.5469,
      28250.5781,
      28694.4512,
      30808.9004,
      909449.6875,
      69067.8516,
      32153.8398,
      214112.3906,
      47653.3086,
      38805.7852,
      63561.7812,
      60056.1641,
      74805.0234,
      233378.7031,
      31245.2598,
      66539.4375,
      174329.375,
      30949.7793,
      186827.3594,
      2128354,
      119101.2656,
      83573.9922,
      86702.4844,
      37098.1367,
      478844.0938
    ],
    "mzs": [
      104.0084,
      108.1924,
      118.5454,
      129.1007,
      150.2932,
      155.4323,
      156.7006,
      173.128,
      175.1188,
      175.4851,
      180.3093,
      196.4062,
      199.1802,
      201.1224,
      210.8365,
      227.175,
      257.1603,
      296.1951,
      314.2058,
      323.9073,
      358.2076,
      375.2346,
      383.2175,
      401.2125,
      401.2846,
      450.4062,
      488.3182,
      575.3502,
      576.3517,
      585.3349,
      670.4265,
      678.9627,
      688.4347
    ],
    "status": "READABLE",
    "usi": "mzspec:PXD005336:Varlitinib_01410_A01_P014203_B00_A00_R1:scan:19343:LLSILSR/2"
  }
]
```

Each PROXI spectrum object in the list may have the following properties:

- *attributes*: A list of CV terms using the PSI-MS controlled vocabulary. There may be as many attributes as desired.
  The following are recognized by the annotator
    - `proforma peptidoform sequence` (MS:1003169): A peptidoform string following the ProForma 2.0 specification
      (e.g. `LLSILSR` or `[TMTpro]-DALSSVQE[Cation:Fe[III]]SQVAQQ[Deamidated]AR`). If this information is not provided,
      the annotator will annotate the spectrum in an ID-free mode, labeling known low-mass ions, precursor-related ions (if provided)
      and isotopes.
    - `charge state` (MS:1000041): The charge state of the analyte that produced the spectrum, usually instrument-provided. The charge state
      information must be provided, either via this term, or via the spectrum `usi` property, or annotation will terminate.
    - `selected ion m/z` (MS:1000827): The observed precursor m/z should be provided, but is not required

- *mzs*: A list of floats expressing the m/z values of the fragmentation spectrum. The code may fail if not in increasing order, not sure.

- *intensities*: A list of floats expressing the intensity values of the fragmentation spectrum, corresponding to the `mzs`

- *status*: This PROXI properties is technically required, but is ignored

- *usi*: An optional specification of the USI of the spectrum being provided for annotation. This is not required, but the service will use
  the `usi` information to obtain the peptideoform and charge if not provided as formal `attributes` (`attributes` take precedence).

- *extended_data*: An optional object for the user to provide additional information to guide output and annotation of the spectrum. The
  contents of `extended_data` is described below in a seprate section.

## Input extended_data

The `extended_data` property may to specified as input for each spectrum object. Information in this object is used to guide the desired output
and guide annotation of the spectrum. Example:

```
"extended_data": {
          "user_parameters": {
                    "create_svg": True,
                    "create_pdf": True,
                    "xmin": 300,
                    "xmax": 600,
                    "yfactor": 2.0
          }
}
```

Currently, only properties inside the `user_parameters` property are checked. Properties inside the `user_parameters` may be as follows:

- *xmin*: Specify an exact X-axis (m/z) minimum value

- *xmax*: Specify an exact X-axis (m/z) maximum value

- *yfactor*: Stretch the Y-axis scaling by this factor. By default the Y-axis is shown as 0 to 1 (1 is the maximum peak height). To change
  the scale such that the tallest peak extends beyond the top of the plot (to gain more insight into the smaller peaks, use a yfactor
  greater than 1.0 (e.g. 2.0). If more room at the top of the plot is desired (for annotation strings or other labels, use a yfactor like 0.8)

- *create_svg*: Create an SVG (scalable vector graphics) object and return it via the output `extended_data`

- *create_pdf*: Create a PDF (portable document format) object and return it via the output `extended_data`

## Output

The output of the /annotate endpoint is a JSON object that contains the annotated spectra and other information. Example:

```
{
  "annotated_spectra": [
    {
      "attributes": [
        {
          "accession": "MS:1008025",
          "name": "scan number",
          "value": "19343"
        },
        {
          "accession": "MS:1000827",
          "name": "selected ion m/z",
          "value": "401.2628"
        },
        {
          "accession": "MS:1003169",
          "name": "proforma peptidoform sequence",
          "value": "LLSILSR"
        }
      ],
      "extended_data": {
        "svg": "<?xml version=\"1.0\" encoding=\"utf-8\" standalone=\"no\"?>\n<!DOCTYPE svg PUBLIC \"-//W3C//DTD SVG 1.1//EN\"\n  \"http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd\">\n<svg xmlns:xlink=\"http://www.w3.org/1999/xlink\" width=\"576pt\" height=\"432pt\" ....... <rect x=\"45.16\" y=\"356.04\" width=\"517.88\" height=\"65.36\"/>\n  </clipPath>\n </defs>\n</svg>\n",
        "user_parameters": {
          "create_svg": true,
          "xmax": 600,
          "xmin": 300,
          "yfactor": 2.0
        }
      },
      "intensities": [
        25679.1973,
        32007.0879,
        27618.2852,
        56783.7109,
        30913.8457,
        25987.8301,
        31703.4883,
        142053.4688,
        176166.5469,
        28250.5781,
        28694.4512,
        30808.9004,
        909449.6875,
        69067.8516,
        32153.8398,
        214112.3906,
        47653.3086,
        38805.7852,
        63561.7812,
        60056.1641,
        74805.0234,
        233378.7031,
        31245.2598,
        66539.4375,
        174329.375,
        30949.7793,
        186827.3594,
        2128354.0,
        119101.2656,
        83573.9922,
        86702.4844,
        37098.1367,
        478844.0938
      ],
      "interpretations": [
        "?",
        "?",
        "?",
        "0@y1{K}-H2O/-11.9ppm",
        "?",
        "?",
        "?",
        "m2:3-CO/-2.6ppm",
        "y1/-0.9ppm",
        "?",
        "?",
        "?",
        "a2/-1.5ppm",
        "m2:3/-4.8ppm",
        "?",
        "b2/-1.8ppm",
        "0@b2{KQ}/-2.0ppm",
        "b3-H2O/-6.0ppm",
        "b3/-5.2ppm",
        "?",
        "y3-NH3/-2.5ppm",
        "y3/-1.2ppm",
        "?",
        "2@p/0.0ppm",
        "3@p/0.0ppm",
        "?",
        "y4/-1.9ppm",
        "y5/-1.6ppm",
        "y5+i/-3.2ppm",
        "?",
        "y6-H2O/2.8ppm",
        "?",
        "y6/-0.7ppm"
      ],
      "mzs": [
        104.0084,
        108.1924,
        118.5454,
        129.1007,
        150.2932,
        155.4323,
        156.7006,
        173.128,
        175.1188,
        175.4851,
        180.3093,
        196.4062,
        199.1802,
        201.1224,
        210.8365,
        227.175,
        257.1603,
        296.1951,
        314.2058,
        323.9073,
        358.2076,
        375.2346,
        383.2175,
        401.2125,
        401.2846,
        450.4062,
        488.3182,
        575.3502,
        576.3517,
        585.3349,
        670.4265,
        678.9627,
        688.4347
      ],
      "usi": "mzspec:PXD005336:Varlitinib_01410_A01_P014203_B00_A00_R1:scan:19343:LLSILSR/2"
    }
  ],
  "status": {
    "description": "Successfully annotated 1 of 1 input spectra",
    "log": [
      "2024-04-04 19:02:52.684329: Received input payload list of 1 elements",
      "2024-04-04 19:02:52.684346: Starting annotation process with tolerance 20.0 ppm",
      "2024-04-04 19:02:52.684442: Parsing ProForma peptidoform 'LLSILSR' for spectrum 0",
      "2024-04-04 19:02:52.684463: Annotating spectrum 0",
      "2024-04-04 19:02:53.191490: Completed annotation process"
    ],
    "status": "OK",
    "status_code": 200
  }
}
```

Response object parameters are:

- *annotated_spectra*: A list of PROXI spectrum objects corresponding to the input spectrum objects

- *status*: An object of information about how the API call went. The `status` object contains properties:
  - *status*: `OK` if the call and processing successed (although there may have been problems with individual spectra)
     or `ERROR` if something when wrong with the attempt to annotate spectra
  - *status_code*: An HTTP status code, usually 200
  - *description*: A one-liner message about how things went
  - *log*: A list of strings providing feedback on how annotation when on each of the provided spectra

The PROXI Spectrum objects inside the `annotated_spectra` list will have the same `mzs`, `intensities`, and `attributes` as
the input Spectrum objects, with the addition of the `annotations` property, which contains the list of annotations that
correspond to each of the `mzs` values.

## Output extended_data

Each output spectrum may also have an `extended_data` property (not part of the official PROXI Spectrum schema) next to
`mzs` and `annotations`. It currently can contain:

- *svg*: A stringified SVG object with the SVG of the annotated spectrum

- *pdf*: A stringified PDF object with the SVG of the annotated spectrum

- *user_parameters*: A simple return of the input `user_parameters`











