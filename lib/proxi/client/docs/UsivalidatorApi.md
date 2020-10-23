# swagger_client.UsivalidatorApi

All URIs are relative to *http://proteomecentral.proteomexchange.org/api/proxi/v0.1*

Method | HTTP request | Description
------------- | ------------- | -------------
[**usi_validator**](UsivalidatorApi.md#usi_validator) | **POST** /usi_validator | Validate an input list of USI strings


# **usi_validator**
> object usi_validator(body)

Validate an input list of USI strings

An endpoint to validate a POSTed JSON list of USIs

### Example 
```python
import time
import swagger_client
from swagger_client.rest import ApiException
from pprint import pprint

# create an instance of the API class
api_instance = swagger_client.UsivalidatorApi()
body = [swagger_client.list[str]()] # list[str] | JSON list of USIs

try: 
    # Validate an input list of USI strings
    api_response = api_instance.usi_validator(body)
    pprint(api_response)
except ApiException as e:
    print "Exception when calling UsivalidatorApi->usi_validator: %s\n" % e
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **body** | **list[str]**| JSON list of USIs | 

### Return type

**object**

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

