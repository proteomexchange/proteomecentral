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
from requests.auth import HTTPBasicAuth

from ms2pip import predict_single

test_mode = False

try:
    from proforma_peptidoform import ProformaPeptidoform
    from universal_spectrum_identifier import UniversalSpectrumIdentifier
    from SpectrumLibraryCollection import SpectrumLibraryCollection
    from SpectrumLibrary import SpectrumLibrary
    from LibrarySpectrum import LibrarySpectrum
except:
    proxi_instance = os.environ.get('PROXI_INSTANCE')
    if proxi_instance:
        sys.path.append(f"/net/dblocal/data/SpectralLibraries/python/{proxi_instance}/SpectralLibraries/lib")
    else:
        if test_mode:
            sys.path.append("C:\local\Repositories\GitHub\SpectralLibraries\lib")
        else:
            print("ERROR: Environment variable PROXI_INSTANCE must be set")
            exit()
    from proforma_peptidoform import ProformaPeptidoform
    from universal_spectrum_identifier import UniversalSpectrumIdentifier
    from SpectrumLibraryCollection import SpectrumLibraryCollection
    from SpectrumLibrary import SpectrumLibrary
    from LibrarySpectrum import LibrarySpectrum


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
            #status_code, message = self.fetch_from_local_spectra_cgi(resultType, pageSize, pageNumber, usi, accession, msRun, fileName, scan, responseContentType)
            status_code, message = self.fetch_from_local_libraries(resultType, pageSize, pageNumber, usi, accession, msRun, fileName, scan, responseContentType)
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
    #### Fetch a spectrum with a USI with a PXL using local library code
    def fetch_from_local_libraries(self,resultType, pageSize = None, pageNumber = None, usi = None, accession = None, msRun = None, fileName = None, scan = None, responseContentType = None):

        if usi is None:
            status_code = 501
            message = { "status": status_code, "title": "USI is required here", "detail": "This endpoint as currently implemented requires a USI string as input", "type": "about:blank" }
            return(status_code, message)

        usi = UniversalSpectrumIdentifier(usi)
        index_number = usi.index

        basedir = "/net/dblocal/data/SpectralLibraries/python/devED/SpectralLibraries"
        spec_lib_collection = SpectrumLibraryCollection(basedir + "/spectralLibraries/SpectrumLibraryCollection.sqlite")
        library = spec_lib_collection.get_library(identifier=usi.collection_identifier, version_tag=usi.ms_run_name)

        library_file = basedir + "/spectralLibraries/" + library.original_filename
        if not os.path.isfile(library_file):
            status_code = 500
            message = { "status": status_code, "title": "Library file not found", "detail": "File '{library_file}' not found or not a file", "type": "about:blank" }
            return(status_code, message)

        spectrum_library = SpectrumLibrary()
        spectrum_library.filename = library_file

        spectrum_buffer = spectrum_library.get_spectrum(spectrum_index_number=index_number)
        spectrum = LibrarySpectrum()
        spectrum.parse(spectrum_buffer, spectrum_index=index_number)
        json_buffer = spectrum.write(format='json')

        spectrum = json.loads(json_buffer)
        self.spectra = [ spectrum ]
        status_code = 200
        message = self.spectra
        return(status_code, message)


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

        usi_string = usi
        usi = UniversalSpectrumIdentifier(usi_string)
 
        if usi.interpretation is None or usi.interpretation == '':
            status_code = 400
            message = { "status": status_code, "title": "USI is required here", "detail": "This endpoint as currently implemented requires a USI string with a peptidoform component", "type": "about:blank" }
            return(status_code, message)

        model = usi.collection_identifier
        if msRun is not None and msRun != '':
            model = msRun
        if model not in [ 'HCD', 'HCD2019', 'HCD2021', 'CID', 'iTRAQ', 'iTRAQphospho', 'TMT', 'TTOF5600', 'HCDch2', 'CIDch2', 'Immuno-HCD', 'CID-TMT' ]:
            model = "HCD"

        charge = "2"
        if usi.charge is not None:
            charge = str(usi.charge)

        spectrum = Spectrum()
        spectrum.usi = usi_string
        spectrum.id = "0"
        spectrum.attributes = [
            #OntologyTerm("MS:1000744","selected ion m/z","473.1234"),
            OntologyTerm("MS:1000041","charge state", charge),
            #OntologyTerm("MS:1009007","scan number","17555"),
            OntologyTerm("MS:1000586","contact name","MS2PIP","11"),
            OntologyTerm("MS:1000590","contact affiliation","VIB","11")
        ]
        spectrum.mzs = []
        spectrum.intensities = []
        spectrum.interpretations = []

        for peptidoform in usi.peptidoforms:
            peptidoform_string = peptidoform['peptidoform_string']
            charge = peptidoform['charge']

            processing_result = predict_single(f"{peptidoform_string}/{charge}", model=model)
            predicted_spectrum = processing_result.as_spectra()[0]  # index 0 is the predicted spectrum (observed is None)

            for i in range(len(predicted_spectrum.mz)):
                spectrum.mzs.append(float(predicted_spectrum.mz[i]))

            max_intensity = 0.0
            intensities = []
            for i in range(len(predicted_spectrum.intensity)):
                intensity = abs(float(predicted_spectrum.intensity[i]))
                if intensity > max_intensity:
                    max_intensity = intensity
                intensities.append(intensity)
            if max_intensity == 0.0:
                max_intensity = 1.0
            scaling_factor = 10000.0 / max_intensity
            for i in range(len(intensities)):
                spectrum.intensities.append(abs(float(intensities[i])) * scaling_factor)

            spectrum.interpretations.extend(list(predicted_spectrum.annotations))
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

        usi_obj = UniversalSpectrumIdentifier()
        usi_obj.parse(usi)

        if usi_obj.peptidoform_string is None or usi_obj.peptidoform_string == '':
            status_code = 400
            message = { "status": status_code, "title": "USI is required here", "detail": "This endpoint as currently implemented requires a USI string with a peptidoform component", "type": "about:blank" }
            return(status_code, message)

        peptidoform = usi_obj.peptidoform_string
        model = usi_obj.collection_identifier
        model_paths = { 'pretrained': '/proteomics/dshteynb/data/Seq2MS/pretrained_model',
                        'retrained': '/proteomics/dshteynb/data/Seq2MS/retrained_model'}
        if msRun is not None and msRun != '':
            model = msRun
        if model not in [ 'pretrained', 'retrained' ]:
            model = "retrained"

        charge = usi_obj.charge

        url = f"https://regis-web.systemsbiology.net/tpp-dev/cgi-bin/Seq2MS_json.pl?maxrt=0&model={model_paths[model]}&pep={peptidoform}&z={charge}&mass=2000"
        eprint(f"INFO: Sending to: {url}")
        with open(os.path.dirname(os.path.abspath(__file__))+'/auth.txt') as infile:
            for line in infile:
                line = line.strip()
                regis_username, regis_password = line.split("\t")
        credentials = HTTPBasicAuth(regis_username, regis_password)
        response_content = requests.get(url, headers={'accept': 'application/json'}, auth=credentials)
        status_code = response_content.status_code
        eprint(f"INFO: Returned status code={status_code}")
        if status_code != 200:
            eprint("ERROR returned with status "+str(status_code))
            eprint(response_content.text)
            status_code = 400
            message = { "status": status_code, "title": "Unable to predict", "detail": "MS2SEQ was not able to predict a spectrum", "type": "about:blank" }
            return(status_code, message)

        try:
            response_dict = response_content.json()
        except:
            eprint("ERROR: Unable to parse response into json:")
            eprint(response_content.text)
            status_code = 400
            message = { "status": status_code, "title": "Unable to predict", "detail": "MS2SEQ was not able to predict a spectrum", "type": "about:blank" }
            return(status_code, message)

        spectrum = Spectrum()
        spectrum.usi = usi
        spectrum.id = "0"
        spectrum.attributes = [
            #OntologyTerm("MS:1000744","selected ion m/z","473.1234"),
            OntologyTerm("MS:1000041","charge state", charge),
            #OntologyTerm("MS:1009007","scan number","17555"),
            OntologyTerm("MS:1000586","contact name","SEQ2MS","11"),
            OntologyTerm("MS:1000590","contact affiliation","ISB","11")
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



