# Spectrum

## Properties
Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**usi** | **str** | Universal Spectrum Identifier | 
**accession** | **str** | Local identifier specific to the provider | [optional] 
**status** | **str** | Status of the Spectrum | 
**mzs** | **list[float]** | Array of m/z values | [optional] 
**intensities** | **list[float]** | Array of intensity values corresponding to mzs | [optional] 
**interpretations** | **list[str]** | Array of coded interpretation strings of the peaks, corresponding to mzs | [optional] 
**attributes** | [**list[OntologyTerm]**](OntologyTerm.md) | List of ontology terms providing attributes of the spectrum | [optional] 

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)


