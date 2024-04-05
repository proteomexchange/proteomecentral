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

Write more






