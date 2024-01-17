#!/usr/bin/env python3

import sys
def eprint(*args, **kwargs): print(*args, file=sys.stderr, **kwargs)

import os
import argparse
import os.path
import timeit
import re
import json
import ast
import http.client
from urllib.request import urlopen
import time
from multiprocessing.pool import ThreadPool

#### Import the Swagger client libraries
sys.path.append(os.path.dirname(os.path.abspath(__file__))+"/../client/swagger_client")
from models.spectrum import Spectrum
from models.ontology_term import OntologyTerm


class ProxiSpectra:

    #### Constructor
    def __init__(self):
        self.spectra = None


    ############################################################################################
    #### Top level method to fetch spectra based on the input provided
    def fetch_spectra(self, resultType, pageSize = None, pageNumber = None, usi = None, accession = None, msRun = None, fileName = None, scan = None, responseContentType = None):

        endpoint = 'spectra'

        #### At present, only USI-based queries are supported
        if usi is None:
            status_code = 501
            message = { "status": status_code, "title": "USI is required here", "detail": "This endpoint as currently implemented requires a USI string as input", "type": "about:blank" }
            return(status_code, message)

        #### Define the available PROXI servers
        proxi_provider_names = [ 'ProteomeCentral','PeptideAtlas','PRIDE','MassIVE','jPOST' ]

        #### Define the available endpoint base urls
        proxi_provider_urls = {
        'ProteomeCentral': 'http://proteomecentral.proteomexchange.org/api/proxi/v0.1',
        'PeptideAtlas': 'http://www.peptideatlas.org/api/proxi/v0.1',
        #'PRIDE': 'http://wwwdev.ebi.ac.uk/pride/proxi/archive/v0.1',
        #'MassIVE': 'http://ccms-internal.ucsd.edu/ProteoSAFe/proxi/v0.1',
        #'jPOST': 'https://repository.jpostdb.org/proxi',
        #'Timeout': 'http://time.u.washington.edu/api/proxi/v0.1',
        #'BadURL': 'http://www.peptideatlas.org/api/poodle/v0.1',
        }

        #### Loop over all the definitions building URLs
        endpoint_list = []
        for provider in proxi_provider_names:
            if provider in proxi_provider_urls:
                    suffix = f"?usi={usi}"
                    url = f'{proxi_provider_urls[provider]}/{endpoint}{suffix}'
                    display_url = f'/{endpoint}{suffix}'
                    endpoint_data = {
                        'provider_name': provider,
                        'endpoint': endpoint,
                        'url': url,
                        'display_url': display_url
                    }
                    endpoint_list.append(endpoint_data)

        #### Loop over the endpoint_list, fetching data from each, using threaded pool
        n_threads = 10
        response = { }
        self.spectra = []

        results = ThreadPool(n_threads).imap_unordered(fetch_url, endpoint_list)
        for endpoint, code, content, message, elapsed in results:
            endpoint['code'] = code
            endpoint['message'] = str(message)
            endpoint['elapsed'] = elapsed

            try:
                received_spectra = json.loads(content)
                endpoint['spectra'] = received_spectra
            except Exception as error:
                endpoint['spectra'] = []
                endpoint['code'] += 1000
                endpoint['message'] += "ERROR: Unable to parse response"

            if isinstance(received_spectra, list):
                for spectrum in received_spectra:
                    spectrum['proxi_provider_name'] = endpoint['provider_name']
                self.spectra.extend(received_spectra)
            else:
                endpoint['code'] += 2000
                endpoint['message'] += "ERROR: response content is not a list"
                eprint("ERROR: response content is not a list")

            #print(json.dumps(endpoint,sort_keys=True), flush=True)
            #print(content)
            #print()

        return 200




############################################################################################
#### General function fetch_url
def fetch_url(endpoint):
    url = endpoint['url']
    if 'delay' in endpoint:
        if int(endpoint['delay']) > 0:
            time.sleep(int(endpoint['delay']))

    timeout = 30
    if 'timeout' in endpoint:
        timeout = endpoint['timeout']

    start = time.time()

    #### Try to fetch the content from specified URL with a maximum timeout
    try:
        response = urlopen(url,timeout=30)
        return endpoint, response.getcode(), response.read(), 'OK', "{:.3f}".format(time.time() - start)

    #### If it failed, then report the error
    except Exception as error:
        error_code = -1
        match = re.match('HTTP Error (\d+)',str(error))
        if match:
            error_code = match.group(1)
        else:
            match = re.search('timed out',str(error))
            error_code = 598
        return endpoint, error_code, None, error, "{:.3f}".format(time.time() - start)


################################################################################################
#### If this class is run from the command line, perform a short little test to see if it is working correctly
def main():

    spectra = ProxiSpectra()
    resultType = 'compact'

    result = spectra.fetch_spectra(resultType=resultType, usi='mzspec:PXD003226:PurifiedHumanCentrosomes_R1:scan:47993:TPEILTVNSIGQLK/2')
    if result == 200:
        for spectrum in spectra.spectra:
            print(f"Received spectrum with {len(spectrum['mzs'])} peaks from {spectrum['proxi_provider_name']}")
    else:
        print(result)

if __name__ == "__main__": main()



