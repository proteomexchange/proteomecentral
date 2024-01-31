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
import urllib.parse
import requests

from ms2pip import predict_single


#### A workaround from Joshua to compensate for threading problems with SQLAlchemy and SQLite
cv_cache_path = os.path.dirname(os.path.abspath(__file__))+"/tmp"
from pyteomics import proforma
proforma.obo_cache.enabled = True
proforma.obo_cache.cache_path = cv_cache_path
# Force the database to open, which will in turn download it and cache it if it doesn't already exist in the cache directory
proforma.UnimodModification.resolver.resolve("Phospho")


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
    def fetch_spectra(self,resultType, pageSize = None, pageNumber = None, usi = None, accession = None, msRun = None, fileName = None, scan = None, annotate = False, responseContentType = None):

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

        #### If it is a MS2PIP, route it appropriately
        match = re.search(":MS2PIP",usi)
        if match or ( accession is not None and accession == 'MS2PIP'):
            status_code, message = self.fetch_from_MS2PIP(resultType, pageSize, pageNumber, usi, accession, msRun, fileName, scan, responseContentType)
            return(status_code, message)

        #### If it is a MS2PIP, route it appropriately
        match = re.search(":SEQ2MS",usi)
        if match or ( accession is not None and accession == 'SEQ2MS'):
            status_code, message = self.fetch_from_SEQ2MS(resultType, pageSize, pageNumber, usi, accession, msRun, fileName, scan, responseContentType)
            return(status_code, message)

        #### If it has a PXD, route it appropriately
        match = re.search(":PXD",usi)
        if match:
            status_code, message = self.fetch_from_PeptideAtlas_ShowObservedSpectrum(resultType, pageSize, pageNumber, usi, accession, msRun, fileName, scan, responseContentType)
            #status_code, message = self.fetch_from_MS2PIP(resultType, pageSize, pageNumber, usi, accession, msRun, fileName, scan, responseContentType)
            if annotate is True:
                eprint("INFO: Annotate is TRUE, but not ready to do it yet")
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

        connection = http.client.HTTPSConnection(server, timeout=30)
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
        url_base = '/sbeams/cgi/PeptideAtlas/ShowObservedSpectrum?output_mode=json&USI='

        #### http.client dies if there are spaces in its URLs. Maybe just replace spaces? or go for complete URLencode?
        #usi = re.sub(r' ','+',usi)
        #url = url_base + usi
        url = url_base + urllib.parse.quote_plus(usi)

        connection = http.client.HTTPSConnection(server, timeout=30)
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
                #print(payload)
                status_code = 500
                message = { "status": status_code, "title": "Internal JSON parsing error", "detail": "Unable to parse JSON from internal call", "type": "about:blank" }
                return(status_code, message)

        if status_code == 404 or status_code == 400:
            try:
                error_message = json.loads(payload)
                return(status_code, error_message)

            except Exception as error:
                #print(payload)
                status_code = 500
                message = { "status": status_code, "title": "Internal JSON parsing error", "detail": "Unable to parse JSON from internal call", "type": "about:blank" }
                return(status_code, message)


        return({ "status": status_code, "title": "Unknown error", "detail": payload, "type": "about:blank" }, status_code )


    ############################################################################################
    #### Fetch an individual spectrum from PeptideAtlas's ShowObservedSpectrum system
    def fetch_from_MS2PIP(self,resultType, pageSize = None, pageNumber = None, usi = None, accession = None, msRun = None, fileName = None, scan = None, responseContentType = None):

        if usi is None:
            status_code = 400
            message = { "status": status_code, "title": "USI is required here", "detail": "This endpoint as currently implemented requires a USI string as input", "type": "about:blank" }
            return(status_code, message)

        components = usi.split(':')

        if len(components) < 6:
            status_code = 400
            message = { "status": status_code, "title": "USI is required here", "detail": "This endpoint as currently implemented requires a USI string with a peptidoform component", "type": "about:blank" }
            return(status_code, message)

        peptidoform = components[5]
        model = components[2]
        if msRun is not None and msRun != '':
            model = msRun
        if model not in [ 'HCD', 'HCD2019', 'HCD2021', 'CID', 'iTRAQ', 'iTRAQphospho', 'TMT', 'TTOF5600', 'HCDch2', 'CIDch2', 'Immuno-HCD', 'CID-TMT' ]:
            model = "HCD"

        charge = "2"
        match = re.search(r'/(\d+)$', peptidoform)
        if match:
            charge = match.group(1)

        processing_result = predict_single(peptidoform, model=model)
        predicted_spectrum = processing_result.as_spectra()[0]  # index 0 is the predicted spectrum (observed is None)

        spectrum = Spectrum()
        spectrum.usi = usi
        spectrum.id = "0"
        spectrum.attributes = [
            #OntologyTerm("MS:1000744","selected ion m/z","473.1234"),
            OntologyTerm("MS:1000041","charge state", charge),
            #OntologyTerm("MS:1009007","scan number","17555"),
            OntologyTerm("MS:1000586","contact name","MS2PIP","11"),
            OntologyTerm("MS:1000590","contact affiliation","VIB","11")
        ]

        spectrum.mzs = list(predicted_spectrum.mz)
        for i in range(len(spectrum.mzs)):
            spectrum.mzs[i] = float(spectrum.mzs[i])

        spectrum.intensities = list(predicted_spectrum.intensity)
        max_intensity = 0.0
        for i in range(len(spectrum.intensities)):
            intensity = abs(float(spectrum.intensities[i]))
            if intensity > max_intensity:
                max_intensity = intensity
            spectrum.intensities[i] = intensity
        if max_intensity == 0.0:
            max_intensity = 1.0
        scaling_factor = 10000.0 / max_intensity
        for i in range(len(spectrum.intensities)):
            spectrum.intensities[i] = abs(float(spectrum.intensities[i])) * scaling_factor

        spectrum.interpretations = list(predicted_spectrum.annotations)
        print(spectrum)

        self.spectra = [ spectrum.to_dict() ]
        status_code = 200
        message = { "status": status_code, "title": "Data fetched", "detail": "MS2PIP prediction successful", "type": "about:blank" }
        return(status_code, message)


    ############################################################################################
    #### Fetch an individual spectrum from PeptideAtlas's ShowObservedSpectrum system
    def fetch_from_SEQ2MS(self,resultType, pageSize = None, pageNumber = None, usi = None, accession = None, msRun = None, fileName = None, scan = None, responseContentType = None):

        if usi is None:
            status_code = 400
            message = { "status": status_code, "title": "USI is required here", "detail": "This endpoint as currently implemented requires a USI string as input", "type": "about:blank" }
            return(status_code, message)

        components = usi.split(':')

        if len(components) < 6:
            status_code = 400
            message = { "status": status_code, "title": "USI is required here", "detail": "This endpoint as currently implemented requires a USI string with a peptidoform component", "type": "about:blank" }
            return(status_code, message)

        peptidoform = components[5]
        model = components[2]
        model_paths = { 'original': '/proteomics/dshteynb/data/Seq2MS/pretrained_model'}
        if msRun is not None and msRun != '':
            model = msRun
        if model not in [ 'original' ]:
            model = "original"

        charge = "2"
        match = re.search(r'/(\d+)$', peptidoform)
        if match:
            charge = match.group(1)



        url = f"https://regis-web.systemsbiology.net/tpp-dev/cgi-bin/Seq2MS_json.pl?maxrt=0&model={model_paths[model]}&pep={peptidoform}&z={charge}&mass=500"
        response_content = requests.get(url, headers={'accept': 'application/json'})
        status_code = response_content.status_code
        if status_code != 200:
            print("ERROR returned with status "+str(status_code))
            response_dict = response_content.json()
            print(json.dumps(response_dict, indent=2, sort_keys=True))
            return

        try:
            response_dict = response_content.json()
        except:
            eprint("ERROR: Unable to parse response into json:")
            eprint(response_content.text())
            return

        spectrum = Spectrum()
        spectrum.usi = usi
        spectrum.id = "0"
        spectrum.attributes = [
            #OntologyTerm("MS:1000744","selected ion m/z","473.1234"),
            OntologyTerm("MS:1000041","charge state", charge),
            #OntologyTerm("MS:1009007","scan number","17555"),
            OntologyTerm("MS:1000586","contact name","MS2PIP","11"),
            OntologyTerm("MS:1000590","contact affiliation","VIB","11")
        ]

        spectrum.mzs = list(response_dict['mzs'])
 
        spectrum.intensities = list(response_dict['intensities'])
        eprint(spectrum)

        self.spectra = [ spectrum.to_dict() ]
        status_code = 200
        message = { "status": status_code, "title": "Data fetched", "detail": "MS2SEQ prediction successful", "type": "about:blank" }
        return(status_code, message)



################################################################################################
#### If this class is run from the command line, perform a short little test to see if it is working correctly
def main():

    spectra = ProxiSpectra()
    example = 2

    if example == 0:
        spectra.set_to_example()
        result = [ 200 ]

    elif example == 1:
        resultType = 'compact'
        #result = spectra.fetch_spectra(resultType, usi = 'mzspec:PXD003226:PurifiedHumanCentrosomes_R1:scan:47993:TPEILTVNSIGQLK/2')
        #result = spectra.fetch_spectra(resultType, usi = 'mzspec:PXD003226:PurifiedHumanCentrosomes_R1:scan:47993:TPEILTVNSIGQLK/2')
        result = spectra.fetch_spectra(resultType, usi = 'mzspec:PXL000006:02-14-2019:index:1250')
        #result = spectra.fetch_spectra(resultType, usi = 'mzspec:PXD010154:01283_A02_P013187_S00_N09_R1:scan:30190:ELVISYLPPGM[L-methionine sulfoxide]ASK/2')
        #result = spectra.fetch_spectra(resultType, usi = 'mzspec:PXD010154:01284_E04_P013188_B00_N29_R1.mzML:scan:31291:DQNGTWEM[Oxidation]ESNENFEGYM[Oxidation]K/2')
    
    elif example == 2:
        resultType = 'compact'
        result = spectra.fetch_from_MS2PIP(resultType, usi = 'mzspec:PXD000561:Adult_Frontalcortex_bRP_Elite_85_f09:scan:17555:VLHPLEGAVVIIFK/2')

    if result[0] == 200:
        #print(spectra.spectra)
        print(json.dumps(spectra.spectra,sort_keys=True,indent=2))
    else:
        print(result)

if __name__ == "__main__": main()



