# swagger_client.LibrariesApi

All URIs are relative to *http://proteomecentral.proteomexchange.org/api/broker/proxi/v0.1*

Method | HTTP request | Description
------------- | ------------- | -------------
[**get_libraries**](LibrariesApi.md#get_libraries) | **GET** /libraries | Get a collection of spectral libraries


# **get_libraries**
> list[object] get_libraries(page_size=page_size, page_number=page_number, result_type=result_type)

Get a collection of spectral libraries

An endpoint to retrieve the list of registered spectral libraries

### Example 
```python
import time
import swagger_client
from swagger_client.rest import ApiException
from pprint import pprint

# create an instance of the API class
api_instance = swagger_client.LibrariesApi()
page_size = 100 # int | How many items to return at one time (default 100, max 100) (optional) (default to 100)
page_number = 0 # int | Current page to be shown paged peptides (default page 1) (optional) (default to 0)
result_type = 'compact' # str | Type of the object to be retrieve Compact or Full dataset (optional) (default to compact)

try: 
    # Get a collection of spectral libraries
    api_response = api_instance.get_libraries(page_size=page_size, page_number=page_number, result_type=result_type)
    pprint(api_response)
except ApiException as e:
    print "Exception when calling LibrariesApi->get_libraries: %s\n" % e
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **page_size** | **int**| How many items to return at one time (default 100, max 100) | [optional] [default to 100]
 **page_number** | **int**| Current page to be shown paged peptides (default page 1) | [optional] [default to 0]
 **result_type** | **str**| Type of the object to be retrieve Compact or Full dataset | [optional] [default to compact]

### Return type

**list[object]**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

