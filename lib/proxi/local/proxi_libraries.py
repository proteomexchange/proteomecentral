#!/usr/bin/env python3

#### Define eprint() to print to stderr
import sys
def eprint(*args, **kwargs):
    print(*args, file=sys.stderr, **kwargs)

#### Import some standard libraries
import os
import argparse
import os.path
import re
import json
import ast

BASE = '/net/dblocal/data/SpectralLibraries/python/devED/SpectralLibraries'
sys.path.append(BASE + '/lib')
from SpectrumLibraryCollection import SpectrumLibraryCollection


#### ProxiDatasets class
class ProxiLibraries:

    #### Constructor
    def __init__(self):
        libraries_list = None


    #### Destructor
    def __del__(self):
        pass


    #### Set the content to an example
    def get_libraries(self):
        
        collection_dir = BASE + '/spectralLibraries'
        spectrum_library_collection = SpectrumLibraryCollection(collection_dir + "/SpectrumLibraryCollection.sqlite")
        libraries = spectrum_library_collection.get_libraries()
        libraries_list = []
        for library in libraries:
            row = { 'id': library.library_record_id, 'id_name': library.id_name, 'version': str(library.version), 'original_name': library.original_name }
            libraries_list.append(row)

        self.libraries_list = libraries_list

        status_code = 200
        message = { "status": status_code, "title": "Success", "detail": "List of libraries returned", "type": "about:blank" }
        message = libraries_list
        return(message, status_code)


    #### Print the contents of the dataset object
    def show(self):
        print("Dataset:")
        print(json.dumps(ast.literal_eval(repr(self.dataset)),sort_keys=True,indent=2))


#### If this class is run from the command line, perform a short little test to see if it is working correctly
def main():

    libraries = ProxiLibraries()
    status_code,message = libraries.get_libraries()
    print('Status='+str(status_code))
    print('Message='+str(message))
    print(libraries.libraries_list)

if __name__ == "__main__": main()
