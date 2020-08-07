# swagger_client.MoleculesApi

All URIs are relative to *http://proteomecentral.proteomexchange.org/api/broker/proxi/v0.1*

Method | HTTP request | Description
------------- | ------------- | -------------
[**get_peptides**](MoleculesApi.md#get_peptides) | **GET** /peptidoforms | Get a collection of peptidoforms
[**get_proteins**](MoleculesApi.md#get_proteins) | **GET** /proteins | Get a collection of proteins


# **get_peptides**
> list[Peptidoform] get_peptides(result_type, page_size=page_size, page_number=page_number, pass_threshold=pass_threshold, peptide_sequence=peptide_sequence, protein_accession=protein_accession, modification=modification, peptidoform=peptidoform)

Get a collection of peptidoforms

The peptidoforms entry point returns global peptidoform statistics across an entire resource. Each peptidoform contains a summary of the statistics of the peptidoform across the entire resource.

### Example 
```python
import time
import swagger_client
from swagger_client.rest import ApiException
from pprint import pprint

# create an instance of the API class
api_instance = swagger_client.MoleculesApi()
result_type = 'compact' # str | Type of the object to be retrieved Compact or Full dataset (default to compact)
page_size = 100 # int | How many items to return at one time (default 100, max 100) (optional) (default to 100)
page_number = 0 # int | Current page of peptide results to be shown (default 1) (optional) (default to 0)
pass_threshold = true # bool | the PSM must pass the thresholds of the repository (e.g. FDR thresholds) (optional)
peptide_sequence = 'peptide_sequence_example' # str | peptideSequence allows to retrieve all the PSMs for an specific Peptide Sequence including modified and un-modified previous. (optional)
protein_accession = 'protein_accession_example' # str | Protein Acession for the identified peptide (optional)
modification = 'modification_example' # str | modification that found in the peptide. For example, to query all peptides that are oxidated. (optional)
peptidoform = 'peptidoform_example' # str | Peptidoform specific including PTM localizations, it will only retrieve the specific PSMs. (optional)

try: 
    # Get a collection of peptidoforms
    api_response = api_instance.get_peptides(result_type, page_size=page_size, page_number=page_number, pass_threshold=pass_threshold, peptide_sequence=peptide_sequence, protein_accession=protein_accession, modification=modification, peptidoform=peptidoform)
    pprint(api_response)
except ApiException as e:
    print "Exception when calling MoleculesApi->get_peptides: %s\n" % e
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **result_type** | **str**| Type of the object to be retrieved Compact or Full dataset | [default to compact]
 **page_size** | **int**| How many items to return at one time (default 100, max 100) | [optional] [default to 100]
 **page_number** | **int**| Current page of peptide results to be shown (default 1) | [optional] [default to 0]
 **pass_threshold** | **bool**| the PSM must pass the thresholds of the repository (e.g. FDR thresholds) | [optional] 
 **peptide_sequence** | **str**| peptideSequence allows to retrieve all the PSMs for an specific Peptide Sequence including modified and un-modified previous. | [optional] 
 **protein_accession** | **str**| Protein Acession for the identified peptide | [optional] 
 **modification** | **str**| modification that found in the peptide. For example, to query all peptides that are oxidated. | [optional] 
 **peptidoform** | **str**| Peptidoform specific including PTM localizations, it will only retrieve the specific PSMs. | [optional] 

### Return type

[**list[Peptidoform]**](Peptidoform.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **get_proteins**
> list[Protein] get_proteins(result_type, page_size=page_size, page_number=page_number, pass_threshold=pass_threshold, protein_accession=protein_accession, modification=modification)

Get a collection of proteins

The protein entrey point returns protein statistics across an entire resource.

### Example 
```python
import time
import swagger_client
from swagger_client.rest import ApiException
from pprint import pprint

# create an instance of the API class
api_instance = swagger_client.MoleculesApi()
result_type = 'compact' # str | Type of the object to be retrieve Compact or Full dataset (default to compact)
page_size = 100 # int | How many items to return at one time (default 100, max 100) (optional) (default to 100)
page_number = 0 # int | Current page to be shown paged peptides (default page 1) (optional) (default to 0)
pass_threshold = true # bool | the PSM pass the thorsholds of the repository (e.g. FDR thresholds) (optional)
protein_accession = 'protein_accession_example' # str | Protein Acession for the identified peptide (optional)
modification = 'modification_example' # str | Modifications found in the peptide. For example, to query all peptides that are oxidated. (optional)

try: 
    # Get a collection of proteins
    api_response = api_instance.get_proteins(result_type, page_size=page_size, page_number=page_number, pass_threshold=pass_threshold, protein_accession=protein_accession, modification=modification)
    pprint(api_response)
except ApiException as e:
    print "Exception when calling MoleculesApi->get_proteins: %s\n" % e
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **result_type** | **str**| Type of the object to be retrieve Compact or Full dataset | [default to compact]
 **page_size** | **int**| How many items to return at one time (default 100, max 100) | [optional] [default to 100]
 **page_number** | **int**| Current page to be shown paged peptides (default page 1) | [optional] [default to 0]
 **pass_threshold** | **bool**| the PSM pass the thorsholds of the repository (e.g. FDR thresholds) | [optional] 
 **protein_accession** | **str**| Protein Acession for the identified peptide | [optional] 
 **modification** | **str**| Modifications found in the peptide. For example, to query all peptides that are oxidated. | [optional] 

### Return type

[**list[Protein]**](Protein.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

