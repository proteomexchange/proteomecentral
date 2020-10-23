# swagger_client.SpectraApi

All URIs are relative to *http://proteomecentral.proteomexchange.org/api/proxi/v0.1*

Method | HTTP request | Description
------------- | ------------- | -------------
[**get_ps_ms**](SpectraApi.md#get_ps_ms) | **GET** /psms | Get a collection of peptide spectrum matches
[**get_spectra**](SpectraApi.md#get_spectra) | **GET** /spectra | Get a collection of spectra


# **get_ps_ms**
> list[Psm] get_ps_ms(result_type, page_size=page_size, page_number=page_number, usi=usi, accession=accession, msrun=msrun, file_name=file_name, scan=scan, pass_threshold=pass_threshold, peptide_sequence=peptide_sequence, protein_accession=protein_accession, charge=charge, modification=modification, peptidoform=peptidoform)

Get a collection of peptide spectrum matches

Get specific Peptide Spectrum Matches (PSMs) if they are present in the database and have been identified by a previous experiment in the resource.

### Example 
```python
import time
import swagger_client
from swagger_client.rest import ApiException
from pprint import pprint

# create an instance of the API class
api_instance = swagger_client.SpectraApi()
result_type = 'compact' # str | Type of the object to be retrieved Compact or Full dataset (default to compact)
page_size = 100 # int | How many items to return at one time (default 100, max 100) (optional) (default to 100)
page_number = 0 # int | Current page to be shown paged psms (default page 1) (optional) (default to 0)
usi = 'usi_example' # str | Universal Spectrum Identifier (USI) (optional)
accession = 'accession_example' # str | Dataset accession (optional)
msrun = 'msrun_example' # str | MsRun containing the spetra (optional)
file_name = 'file_name_example' # str | FileName containing the spectra (optional)
scan = 'scan_example' # str | Scan to be search (optional)
pass_threshold = true # bool | the PSM pass the thorsholds of the repository (e.g. FDR thresholds) (optional)
peptide_sequence = 'peptide_sequence_example' # str | peptideSequence allows to retrieve all the PSMs for an specific Peptide Sequence including modified and un-modified previous. (optional)
protein_accession = 'protein_accession_example' # str | Protein Accession for the identified peptide (optional)
charge = 56 # int | charge state for the PSM (optional)
modification = 'modification_example' # str | modification found in the peptide. For example, to query all peptides that are oxidated. (optional)
peptidoform = 'peptidoform_example' # str | Peptidform specific including PTM localizations, it will only retrieve the specific PSMs. (optional)

try: 
    # Get a collection of peptide spectrum matches
    api_response = api_instance.get_ps_ms(result_type, page_size=page_size, page_number=page_number, usi=usi, accession=accession, msrun=msrun, file_name=file_name, scan=scan, pass_threshold=pass_threshold, peptide_sequence=peptide_sequence, protein_accession=protein_accession, charge=charge, modification=modification, peptidoform=peptidoform)
    pprint(api_response)
except ApiException as e:
    print "Exception when calling SpectraApi->get_ps_ms: %s\n" % e
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **result_type** | **str**| Type of the object to be retrieved Compact or Full dataset | [default to compact]
 **page_size** | **int**| How many items to return at one time (default 100, max 100) | [optional] [default to 100]
 **page_number** | **int**| Current page to be shown paged psms (default page 1) | [optional] [default to 0]
 **usi** | **str**| Universal Spectrum Identifier (USI) | [optional] 
 **accession** | **str**| Dataset accession | [optional] 
 **msrun** | **str**| MsRun containing the spetra | [optional] 
 **file_name** | **str**| FileName containing the spectra | [optional] 
 **scan** | **str**| Scan to be search | [optional] 
 **pass_threshold** | **bool**| the PSM pass the thorsholds of the repository (e.g. FDR thresholds) | [optional] 
 **peptide_sequence** | **str**| peptideSequence allows to retrieve all the PSMs for an specific Peptide Sequence including modified and un-modified previous. | [optional] 
 **protein_accession** | **str**| Protein Accession for the identified peptide | [optional] 
 **charge** | **int**| charge state for the PSM | [optional] 
 **modification** | **str**| modification found in the peptide. For example, to query all peptides that are oxidated. | [optional] 
 **peptidoform** | **str**| Peptidform specific including PTM localizations, it will only retrieve the specific PSMs. | [optional] 

### Return type

[**list[Psm]**](Psm.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **get_spectra**
> list[Spectrum] get_spectra(result_type, page_size=page_size, page_number=page_number, usi=usi, accession=accession, ms_run=ms_run, file_name=file_name, scan=scan)

Get a collection of spectra

This endpoint returns a collection of spectra for a given query including a usi.

### Example 
```python
import time
import swagger_client
from swagger_client.rest import ApiException
from pprint import pprint

# create an instance of the API class
api_instance = swagger_client.SpectraApi()
result_type = 'compact' # str | Type of the object to be retrieved Compact or Full dataset (default to compact)
page_size = 100 # int | How many items to return at one time (default 100, max 100) (optional) (default to 100)
page_number = 0 # int | Current page to be shown paged datasets (default page 1) (optional) (default to 0)
usi = 'usi_example' # str | Universal Spectrum Identifier (USI) (optional)
accession = 'accession_example' # str | Dataset accession (optional)
ms_run = 'ms_run_example' # str | MsRun containing the spectra (optional)
file_name = 'file_name_example' # str | FileName containing the spectra (optional)
scan = 'scan_example' # str | Scan to be searched (optional)

try: 
    # Get a collection of spectra
    api_response = api_instance.get_spectra(result_type, page_size=page_size, page_number=page_number, usi=usi, accession=accession, ms_run=ms_run, file_name=file_name, scan=scan)
    pprint(api_response)
except ApiException as e:
    print "Exception when calling SpectraApi->get_spectra: %s\n" % e
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **result_type** | **str**| Type of the object to be retrieved Compact or Full dataset | [default to compact]
 **page_size** | **int**| How many items to return at one time (default 100, max 100) | [optional] [default to 100]
 **page_number** | **int**| Current page to be shown paged datasets (default page 1) | [optional] [default to 0]
 **usi** | **str**| Universal Spectrum Identifier (USI) | [optional] 
 **accession** | **str**| Dataset accession | [optional] 
 **ms_run** | **str**| MsRun containing the spectra | [optional] 
 **file_name** | **str**| FileName containing the spectra | [optional] 
 **scan** | **str**| Scan to be searched | [optional] 

### Return type

[**list[Spectrum]**](Spectrum.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

