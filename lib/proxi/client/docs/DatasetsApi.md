# swagger_client.DatasetsApi

All URIs are relative to *http://proteomecentral.proteomexchange.org/api/proxi/v0.1*

Method | HTTP request | Description
------------- | ------------- | -------------
[**get_dataset**](DatasetsApi.md#get_dataset) | **GET** /datasets/{identifier} | Get an specific dataset
[**list_datasets**](DatasetsApi.md#list_datasets) | **GET** /datasets | List of datasets in the respository


# **get_dataset**
> Dataset get_dataset(identifier)

Get an specific dataset

### Example 
```python
import time
import swagger_client
from swagger_client.rest import ApiException
from pprint import pprint

# create an instance of the API class
api_instance = swagger_client.DatasetsApi()
identifier = 'identifier_example' # str | Identifier of the dataset

try: 
    # Get an specific dataset
    api_response = api_instance.get_dataset(identifier)
    pprint(api_response)
except ApiException as e:
    print "Exception when calling DatasetsApi->get_dataset: %s\n" % e
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **identifier** | **str**| Identifier of the dataset | 

### Return type

[**Dataset**](Dataset.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **list_datasets**
> list[Dataset] list_datasets(result_type, page_size=page_size, page_number=page_number, species=species, accession=accession, instrument=instrument, contact=contact, publication=publication, modification=modification, search=search)

List of datasets in the respository

### Example 
```python
import time
import swagger_client
from swagger_client.rest import ApiException
from pprint import pprint

# create an instance of the API class
api_instance = swagger_client.DatasetsApi()
result_type = 'compact' # str | Type of the object to be retrieve Compact or Full dataset (default to compact)
page_size = 100 # int | How many items to return at one time (default 100, max 100) (optional) (default to 100)
page_number = 0 # int | Current page to be shown paged datasets (default page 1) (optional) (default to 0)
species = 'species_example' # str | Filter the list of Datasets by Species, multiple species search can be performed by [human, mouse]. (optional)
accession = 'accession_example' # str | Filter the list of datasets by Dataset accession, multiple accessions search can be performed by [PXD00001, PXD00002] (optional)
instrument = 'instrument_example' # str | Filter the list of datasets by Instrument, multiple instruments search can be performed by [LTQ, QTOF] (optional)
contact = 'contact_example' # str | Filter the list of datasets by Contact information (optional)
publication = 'publication_example' # str | Filter the list of datasets by Publication information, multiple information search can be performed by [nature methods, 27498275] (optional)
modification = 'modification_example' # str | Filter the list of datasets by Modification information. (optional)
search = 'search_example' # str | Search different keywords into all dataset fields, multiple terms search can be performed by [liver, brain] (optional)

try: 
    # List of datasets in the respository
    api_response = api_instance.list_datasets(result_type, page_size=page_size, page_number=page_number, species=species, accession=accession, instrument=instrument, contact=contact, publication=publication, modification=modification, search=search)
    pprint(api_response)
except ApiException as e:
    print "Exception when calling DatasetsApi->list_datasets: %s\n" % e
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **result_type** | **str**| Type of the object to be retrieve Compact or Full dataset | [default to compact]
 **page_size** | **int**| How many items to return at one time (default 100, max 100) | [optional] [default to 100]
 **page_number** | **int**| Current page to be shown paged datasets (default page 1) | [optional] [default to 0]
 **species** | **str**| Filter the list of Datasets by Species, multiple species search can be performed by [human, mouse]. | [optional] 
 **accession** | **str**| Filter the list of datasets by Dataset accession, multiple accessions search can be performed by [PXD00001, PXD00002] | [optional] 
 **instrument** | **str**| Filter the list of datasets by Instrument, multiple instruments search can be performed by [LTQ, QTOF] | [optional] 
 **contact** | **str**| Filter the list of datasets by Contact information | [optional] 
 **publication** | **str**| Filter the list of datasets by Publication information, multiple information search can be performed by [nature methods, 27498275] | [optional] 
 **modification** | **str**| Filter the list of datasets by Modification information. | [optional] 
 **search** | **str**| Search different keywords into all dataset fields, multiple terms search can be performed by [liver, brain] | [optional] 

### Return type

[**list[Dataset]**](Dataset.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

