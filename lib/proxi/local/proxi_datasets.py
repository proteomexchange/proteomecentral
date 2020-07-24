#!/usr/bin/env python3

#### Define eprint() to print to stderr
from __future__ import print_function
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
import http.client


#### Import the Swagger client libraries
sys.path.append(os.path.dirname(os.path.abspath(__file__))+"/../client/swagger_client")
from models.dataset import Dataset


#### ProxiDatasets class
class ProxiDatasets:

    #### Constructor
    def __init__(self):
        pass


    #### Destructor
    def __del__(self):
        pass


    #### Set the content to an example
    def fetch_dataset_from_PC(self,dataset_identifier):

        server = 'proteomecentral.proteomexchange.org'
        url_base = '/cgi/GetDataset?outputMode=json&ID='
        url = url_base + dataset_identifier
        self.dataset = None

        connection = http.client.HTTPConnection(server, 80, timeout=10)
        connection.request("GET", url)
        http_response = connection.getresponse()
        status_code = http_response.status
        message = http_response.reason
        payload = http_response.read()
        connection.close()

        if status_code == 200:
            try:
                self.dataset = json.loads(payload)
                message = { "status": status_code }
            except Exception as error:
                status_code = 500
                message = { "status": status_code, "title": "Internal JSON parsing error", "detail": "Unable to parse JSON from internal call", "type": "about:blank" }
            return(status_code, message)

        if status_code == 404:
            title = 'Dataset not available'
            detail = 'Specified dataset is not available for unknown reason'
            payload = str(payload, 'utf-8', 'ignore')
            lines = payload.split("\n")
            for line in lines:
                if line == '': continue
                key,value = line.split('=')
                if key == 'code':
                    title = value
                    if value == '1002': title = 'Dataset not yet assigned'
                    if value == '1003': title = 'Dataset not yet released'
                if key == 'message':
                    detail = value
            message = { "status": status_code, "title": title, "detail": detail, "type": "about:blank" }
            self.dataset = None
            return(status_code, message)

        return(status_code, { "status": status_code, "title": "Unknown error", "detail": payload, "type": "about:blank" } )


    #### Print the contents of the dataset object
    def show(self):
        print("Dataset:")
        print(json.dumps(ast.literal_eval(repr(self.dataset)),sort_keys=True,indent=2))


#### If this class is run from the command line, perform a short little test to see if it is working correctly
def main():

    dataset = ProxiDatasets()
    #status_code,message = dataset.fetch_dataset_from_PC('PXD911825')
    #status_code,message = dataset.fetch_dataset_from_PC('PXD011820')
    status_code,message = dataset.fetch_dataset_from_PC('PXD011825')
    print('Status='+str(status_code))
    print('Message='+str(message))
    print(dataset.dataset)

if __name__ == "__main__": main()
