from __future__ import print_function
import sys
def eprint(*args, **kwargs):
    print(*args, file=sys.stderr, **kwargs)

import os
import sys
import ast
import copy
import flask

sys.path.append(os.path.dirname(os.path.abspath(__file__))+"/../../local")
sys.path.append(os.path.dirname(os.path.abspath(__file__))+"/../../client/swagger_client")

from models.error import Error
from models.spectrum import Spectrum

from proxi_spectra import ProxiSpectra
from proxi_datasets import ProxiDatasets
from proxi_libraries import ProxiLibraries
from usi_validator import UsiValidator
from usi_examples import UsiExamples
from proxi_annotator import ProxiAnnotator
#from proxi_comparator import ProxiComparator

master_datasets = ProxiDatasets(refresh_datasets=True)

def tsv_generator(list_of_lists):
    headerline = [ 'identifier', 'title', 'repository', 'species', 'instrument', 'publication', 'lab_head', 'announce_date', 'keywords' ]
    yield("\t".join(headerline) + "\n")
    for row in list_of_lists:
        yield("\t".join(row) + "\n")


def get_dataset(identifier) -> str:
    status_code, message, dataset = master_datasets.get_dataset(identifier)
    if status_code == 200:
        return(dataset)
    else:
        return(message, status_code)


def list_datasets(resultType, pageSize = None, pageNumber = None, species = None, accession = None, instrument = None, contact = None, publication = None, modification = None, search = None, keywords = None, year = None, repository = None, sdrf = None, files = None, outputFormat = None) -> str:

    master_datasets.refresh_data_if_stale()

    datasets = copy.deepcopy(master_datasets)
    status_code, message, mimetype = datasets.list_datasets(resultType, pageSize, pageNumber, species, accession, instrument, contact, publication, modification, search, keywords, year, repository, sdrf, files, outputFormat)

    if outputFormat is not None and outputFormat.lower() == 'tsv':
        
        flask_response = flask.Response(response=tsv_generator(message), status=status_code, mimetype=mimetype)
        flask_response.headers['Content-Disposition'] = 'attachment; filename=proteomexchange_search.tsv'
        return(flask_response)
    else:
        return(message, status_code)


def get_library(identifier) -> str:
    libraries = ProxiLibraries()
    status_code, message, library = libraries.get_library(identifier)
    if status_code == 200:
        return(library)
    else:
        return(message, status_code)


def get_libraries(resultType, pageSize = None, pageNumber = None, species = None, accession = None, fragmentation_type = None, lab_head_full_name = None, search = None, keywords = None, year = None, source = None, outputFormat = None) -> str:

    libraries = ProxiLibraries()
    status_code, message, mimetype = libraries.list_libraries(resultType, pageSize=pageSize, pageNumber=pageNumber, species=species, accession=accession, fragmentation_type=fragmentation_type, lab_head_full_name=lab_head_full_name, search=search, keywords=keywords, year=year, source=source, outputFormat=outputFormat)

    if outputFormat is not None and outputFormat.lower() == 'tsv':
        flask_response = flask.Response(response=tsv_generator(message), status=status_code, mimetype=mimetype)
        flask_response.headers['Content-Disposition'] = 'attachment; filename=ProteomeCentral_Libraries_search.tsv'
        return(flask_response)
    else:
        return(message, status_code)


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
    return(usi_examples.examples, 200)

def annotator(body, resultType='compact', tolerance=None) -> str:
    annotator = ProxiAnnotator()
    return annotator.annotate(body, resultType=resultType, tolerance=tolerance)

def comparator(body, resultType='compact', tolerance=None) -> str:
    return( { "status": 501, "title": "Endpoint not implemented", "detail": "Although this is an officially defined PROXI endpoint, it has not yet been implemented at this server", "type": "about:blank" }, 501 )
    #comparator = ProxiComparator()
    #return comparator.compare(body, resultType=resultType, tolerance=tolerance)


