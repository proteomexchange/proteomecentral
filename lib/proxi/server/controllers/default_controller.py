from __future__ import print_function
import sys
def eprint(*args, **kwargs):
    print(*args, file=sys.stderr, **kwargs)

import os
import sys
import ast

sys.path.append(os.path.dirname(os.path.abspath(__file__))+"/../../local")
sys.path.append(os.path.dirname(os.path.abspath(__file__))+"/../../client/swagger_client")

from models.error import Error
from models.spectrum import Spectrum

from proxi_spectra import ProxiSpectra
from proxi_datasets import ProxiDatasets
from proxi_libraries import ProxiLibraries
from usi_validator import UsiValidator
from usi_examples import UsiExamples


def get_dataset(identifier) -> str:
    datasets = ProxiDatasets()
    status_code,message = datasets.fetch_dataset_from_PC(identifier)
    if status_code == 200:
        return(ast.literal_eval(repr(datasets.dataset)))
    else:
        return(message,status_code)


def list_datasets(resultType, pageSize = None, pageNumber = None, species = None, accession = None, instrument = None, contact = None, publication = None, modification = None, search = None, keywords = None, year = None) -> str:
    #return( { "status": 501, "title": "Endpoint not implemented", "detail": "Although this is an officially defined PROXI endpoint, it has not yet been implemented at this server", "type": "about:blank" }, 501 )
    datasets = ProxiDatasets()
    status_code,message = datasets.list_datasets(resultType, pageSize, pageNumber, species, accession, instrument, contact, publication, modification, search, keywords, year)
    return(message,status_code)


def get_libraries(pageSize = None, pageNumber = None, resultType = None) -> str:
    libraries = ProxiLibraries()
    status_code,message = libraries.get_libraries()
    if status_code == 200:
        return(ast.literal_eval(repr(libraries.libraries_list)))
    else:
        return(message,status_code)


def get_peptides(resultType, pageSize = None, pageNumber = None, passThreshold = None, peptideSequence = None, proteinAccession = None, modification = None, peptidoform = None) -> str:
    return( { "status": 501, "title": "Endpoint not implemented", "detail": "Although this is an officially defined PROXI endpoint, it has not yet been implemented at this server", "type": "about:blank" }, 501 )

def get_proteins(resultType, pageSize = None, pageNumber = None, passThreshold = None, proteinAccession = None, modification = None) -> str:
    return( { "status": 501, "title": "Endpoint not implemented", "detail": "Although this is an officially defined PROXI endpoint, it has not yet been implemented at this server", "type": "about:blank" }, 501 )

def get_ps_ms(resultType, pageSize = None, pageNumber = None, usi = None, accession = None, msrun = None, fileName = None, scan = None, passThreshold = None, peptideSequence = None, proteinAccession = None, charge = None, modification = None, peptidoform = None) -> str:
    return( { "status": 501, "title": "Endpoint not implemented", "detail": "Although this is an officially defined PROXI endpoint, it has not yet been implemented at this server", "type": "about:blank" }, 501 )

def get_spectra(resultType, pageSize = None, pageNumber = None, usi = None, accession = None, msRun = None, fileName = None, scan = None, annotate = False, responseContentType = None) -> str:
    spectra = ProxiSpectra()
    result = spectra.fetch_spectra(resultType, pageSize = pageSize, pageNumber = pageNumber, usi = usi, accession = accession, msRun = msRun, fileName = fileName, scan = scan, annotate = annotate, responseContentType = responseContentType)
    if result[0] == 200:
        return(ast.literal_eval(repr(spectra.spectra)), 200)
    else:
        return(result[1], result[0])

def usi_validator(body) -> str:
    usi_validator = UsiValidator()
    return usi_validator.validate(body)

def usi_examples() -> str:
    usi_examples = UsiExamples()
    return(usi_examples.examples,200)


