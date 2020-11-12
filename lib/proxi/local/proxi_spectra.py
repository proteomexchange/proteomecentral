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
import timeit
import re
import json
import ast
import http.client

#### Import the Swagger client libraries
sys.path.append(os.path.dirname(os.path.abspath(__file__))+"/../client/swagger_client")
from models.spectrum import Spectrum
from models.ontology_term import OntologyTerm


class ProxiSpectra:

    #### Constructor
    def __init__(self):
        pass

    #### Destructor
    def __del__(self):
        pass

    #### Define attribute spectrum
    @property
    def spectrum(self) -> str:
        return self._spectrum

    @spectrum.setter
    def spectrum(self, spectrum: str):
        self._spectrum = spectrum


    ############################################################################################
    #### Set the content to a dummy example
    def set_to_example(self):

        spectrum = Spectrum()
        spectrum.usi = "mzspec:PXD000561:Adult_Frontalcortex_bRP_Elite_85_f09:scan:17555:VLHPLEGAVVIIFK/2"
        spectrum.id = "238293"
        spectrum.attributes = [
            OntologyTerm("MS:1000744","selected ion m/z","473.1234"),
            OntologyTerm("MS:1000041","charge state","2"),
            OntologyTerm("MS:1000512","filter string","FTMS + p NSI d Full ms2 990.17@hcd28.00 [100.00-3050.00]"),
            OntologyTerm("MS:1009007","scan number","17555"),
            OntologyTerm("MS:1009004","molecular weight","902.1234"),
            OntologyTerm("MS:1000586","contact name","Sarah Bellum","11"),
            OntologyTerm("MS:1000590","contact affiliation","Higglesworth University","11")
        ]

        #spectrum.mzs = [ 147.1130, 567.3138 ]
        #spectrum.intensities = [ 500, 600.45 ]
        #spectrum.interpretations = [ "y1/1.3", "ib(PLEGAV)/0.2" ]

        spectrum.mzs = [ ]
        spectrum.intensities = [ ]
        spectrum.interpretations = [ ]
        fh = open("/net/dblocal/wwwspecial/proteomecentral/devED/lib/proxi/local/zzSpectrum.txt", 'r')
        for line in fh.readlines():
            columns = line.strip("\n").split()
            dummy = columns[0]
            mz = columns[0]
            intensity = columns[1]
            interpretations = columns[2]
            spectrum.mzs.append(mz)
            spectrum.intensities.append(intensity)
            spectrum.interpretations.append(interpretations)
        fh.close()

        self.spectra = [ spectrum ]


    ############################################################################################
    #### Print the contents of the spectrum object
    def show(self):
        print("Spectrum:")
        print(json.dumps(ast.literal_eval(repr(self.spectrum)),sort_keys=True,indent=2))


    ############################################################################################
    #### Top level method to fetch spectra based on the input provided
    def fetch_spectra(self,resultType, pageSize = None, pageNumber = None, usi = None, accession = None, msRun = None, fileName = None, scan = None, responseContentType = None):

        #### At present, only USI-based queries are supported
        if usi is None:
            status_code = 501
            message = { "status": status_code, "title": "USI is required here", "detail": "This endpoint as currently implemented requires a USI string as input", "type": "about:blank" }
            return(status_code, message)

        #### So far, the USI must contain a PXL or a PXD. If it has a PXL, route it appropriately
        match = re.search(":PXL",usi)
        if match:
            status_code, message = self.fetch_from_local_spectra_cgi(resultType, pageSize, pageNumber, usi, accession, msRun, fileName, scan, responseContentType)
            return(status_code, message)

        #### If it has a PXD, route it appropriately
        match = re.search(":PXD",usi)
        if match:
            status_code, message = self.fetch_from_PeptideAtlas_ShowObservedSpectrum(resultType, pageSize, pageNumber, usi, accession, msRun, fileName, scan, responseContentType)
            return(status_code, message)

        #### Or otherwise this USI doesn't seem to have an identifier we can deal with
        status_code = 404
        message = { "status": status_code, "title": "Unsupported collection prefix", "detail": "This endpoint currently only supports USIs with a PXL or PXD collection identifier", "type": "about:blank" }
        return(status_code, message)


    ############################################################################################
    #### Fetch a PXL spectrum from ProteomeCentral's cgi/spectra system for now at least
    def fetch_from_local_spectra_cgi(self,resultType, pageSize = None, pageNumber = None, usi = None, accession = None, msRun = None, fileName = None, scan = None, responseContentType = None):

        if usi is None:
            status_code = 501
            message = { "status": status_code, "title": "USI is required here", "detail": "This endpoint as currently implemented requires a USI string as input", "type": "about:blank" }
            return(status_code, message)

        server = 'proteomecentral.proteomexchange.org'
        url_base = '/cgi/spectra?output_format=json&usi='
        url = url_base + usi

        connection = http.client.HTTPConnection(server, 80, timeout=30)
        connection.request("GET", url)
        http_response = connection.getresponse()
        status_code = http_response.status
        message = http_response.reason
        payload = http_response.read()
        connection.close()

        if status_code == 200:
            try:
                spectrum = json.loads(payload)
                self.spectra = [ spectrum ]
                return(status_code, message)

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
            self.spectra = None
            return(status_code, message)

        return(status_code, { "status": status_code, "title": "Unknown error", "detail": payload, "type": "about:blank" } )


    ############################################################################################
    #### Fetch an individual spectrum from PeptideAtlas's ShowObservedSpectrum system
    def fetch_from_PeptideAtlas_ShowObservedSpectrum(self,resultType, pageSize = None, pageNumber = None, usi = None, accession = None, msRun = None, fileName = None, scan = None, responseContentType = None):

        if usi is None:
            status_code = 501
            message = { "status": status_code, "title": "USI is required here", "detail": "This endpoint as currently implemented requires a USI string as input", "type": "about:blank" }
            return(status_code, message)

        server = 'db.systemsbiology.net'
        url_base = '/dev2/sbeams/cgi/PeptideAtlas/ShowObservedSpectrum?output_mode=json&USI='
        url = url_base + usi

        connection = http.client.HTTPConnection(server, 80, timeout=30)
        connection.request("GET", url)
        http_response = connection.getresponse()
        status_code = http_response.status
        message = http_response.reason
        payload = http_response.read()
        connection.close()

        if status_code == 200:
            try:
                spectrum = json.loads(payload)
                self.spectra = [ spectrum ]
                return(status_code, message)

            except Exception as error:
                status_code = 500
                message = { "status": status_code, "title": "Internal JSON parsing error", "detail": "Unable to parse JSON from internal call", "type": "about:blank" }
                return(status_code, message)

        if status_code == 404:
            try:
                error_message = json.loads(payload)
                return(status_code, error_message)

            except Exception as error:
                status_code = 500
                message = { "status": status_code, "title": "Internal JSON parsing error", "detail": "Unable to parse JSON from internal call", "type": "about:blank" }
                return(status_code, message)


        return({ "status": status_code, "title": "Unknown error", "detail": payload, "type": "about:blank" }, status_code )


################################################################################################
#### If this class is run from the command line, perform a short little test to see if it is working correctly
def main():

  spectra = ProxiSpectra()
  #spectra.set_to_example()
  resultType = 'compact'
  #result = spectra.fetch_spectra(resultType, usi = 'mzspec:PXD003226:PurifiedHumanCentrosomes_R1:scan:47993:TPEILTVNSIGQLK/2')
  #result = spectra.fetch_spectra(resultType, usi = 'mzspec:PXD003226:PurifiedHumanCentrosomes_R1:scan:47993:TPEILTVNSIGQLK/2')
  result = spectra.fetch_spectra(resultType, usi = 'mzspec:PXL000006:02-14-2019:index:1250')
  if result[0] == 200:
      print(spectra.spectra)
  else:
      print(result)

if __name__ == "__main__": main()



