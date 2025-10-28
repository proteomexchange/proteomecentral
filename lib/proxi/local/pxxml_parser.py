#!/usr/bin/env python3

import sys
import os
import argparse
import os.path
import json
import pymysql
import socket
from datetime import datetime
import timeit
import xml.etree.ElementTree as ET
def eprint(*args, **kwargs): print(*args, file=sys.stderr, **kwargs)

DEBUG = False


#### PXXMLParser class
class PXXMLParser:

    #### Constructor
    def __init__(self):
        self.response_status = {'status_code': 500, 'status': 'ERROR', 'error_code': 'INIT_ERROR', 'description': 'Unhandled error after initialization'}
        self.dataset = {}

    #### Destructor
    def __del__(self):
        pass


    #### Parse a PXXML document by filepath
    def parse_file(self, pxxml_filepath):

        if DEBUG:
            eprint(f"DEBUG: parse_file(): Parsing file {pxxml_filepath}")

        dataset = {}
        self.dataset = dataset

        #### Define the mapping of PXXML elements names to PROXI keys and the whether they contain terms or lists of terms
        pxxml_mapping = {
            #"CvList": {"name": "cvList", "type": "CvList"},
            "DatasetIdentifierList": {"name": "identifiers", "type": "OntologyTermFlattenList"},
            "DatasetOriginList": {"name": "datasetOrigins", "type": "OntologyTermList"},
            "SpeciesList": {"name": "species", "type": "OntologyTermList"},
            "InstrumentList": {"name": "instruments", "type": "OntologyTermFlattenList"},
            "ModificationList": {"name": "modifications", "type": "OntologyTerm"},
            "ContactList": {"name": "contacts", "type": "OntologyTermList"},
            "PublicationList": {"name": "publications", "type": "OntologyTermList"},
            "KeywordList": {"name": "keywords", "type": "OntologyTerm"},
            "FullDatasetLinkList": {"name": "fullDatasetLinks", "type": "OntologyTermFlattenList"},
            "DatasetFileList": {"name": "datasetFiles", "type": "OntologyTermFlattenList"},
        }

        #### Create an empty shell of the Dataset structure
        for element, properties in pxxml_mapping.items():
            dataset[properties['name']] = []

        #### Verify that file exists
        if not os.path.exists(pxxml_filepath):
            self.response_status = {'status_code': 500, 'status': 'ERROR', 'error_code': 'FILE_NOT_FOUND_ERROR', 'description': f"Specified file '{pxxml_filepath}' not found"}
            if DEBUG:
                eprint(f"ERROR: {self.response_status}")
            return

        #### Attempt to parse the XML
        try:
            tree = ET.parse(pxxml_filepath)
            root = tree.getroot()

        except:
            self.response_status = {'status_code': 500, 'status': 'ERROR', 'error_code': 'MALFORMED_XML', 'description': f"XML parsing failed: malformed XML"}
            if DEBUG:
                eprint(f"ERROR: {self.response_status}")
            return


        #### Loop over all children and build the Dataset data structure in memory
        for root_child in root:

            if DEBUG:
                eprint(f"DEBUG: Parse {root_child.tag} {root_child.attrib}")

            #### Special handling for DatasetSummary where two attributes go at the top level
            if root_child.tag == 'DatasetSummary':
                key_name = 'datasetSummary'
                dataset[key_name] = root_child.attrib
                dataset['title'] = dataset[key_name]['title']
                del(dataset[key_name]['title'])
                terms_list = []
                for child in root_child:
                    if DEBUG:
                        eprint(f"DEBUG:   Parse {child.tag} {child.attrib}")
                    if child.tag == 'Description':
                        dataset['description'] = child.text
                    for subchild in child:
                        cv_term = subchild.attrib
                        del(cv_term['cvRef'])
                        terms_list.append(cv_term)
                dataset[key_name]['terms'] = terms_list

            else:
                if root_child.tag not in pxxml_mapping:
                    if DEBUG:
                        eprint(f"DEBUG:   Skipped")
                    continue

                if pxxml_mapping[root_child.tag]['type'] == 'OntologyTerm':
                    key_name = pxxml_mapping[root_child.tag]['name']
                    for child in root_child:
                        if DEBUG:
                            eprint(f"DEBUG:   Parse {child.tag} {child.attrib}")
                        cv_term = child.attrib
                        del(cv_term['cvRef'])
                        dataset[key_name].append(cv_term)

                if pxxml_mapping[root_child.tag]['type'] == 'OntologyTermList':
                    key_name = pxxml_mapping[root_child.tag]['name']
                    for child in root_child:
                        if DEBUG:
                            eprint(f"DEBUG:   Parse {child.tag} {child.attrib}")
                        terms_list = []
                        for subchild in child:
                            if DEBUG:
                                eprint(f"DEBUG:     Parse {subchild.tag} {subchild.attrib}")
                            cv_term = subchild.attrib
                            del(cv_term['cvRef'])
                            terms_list.append(cv_term)
                        dataset[key_name].append( {'terms': terms_list})

                if pxxml_mapping[root_child.tag]['type'] == 'OntologyTermFlattenList':
                    key_name = pxxml_mapping[root_child.tag]['name']
                    for child in root_child:
                        if DEBUG:
                            eprint(f"DEBUG:   Parse {child.tag} {child.attrib}")
                        for subchild in child:
                            if DEBUG:
                                eprint(f"DEBUG:     Parse {subchild.tag} {subchild.attrib}")
                            cv_term = subchild.attrib
                            del(cv_term['cvRef'])
                            dataset[key_name].append(cv_term)

        self.response_status = {'status_code': 200, 'status': 'OK', 'error_code': '', 'description': 'File successfully parsed'}


#### If this class is run from the command line, perform a short little test to see if it is working correctly
def main():

    argparser = argparse.ArgumentParser(description='Class for a PROXI dataset')
    argparser.add_argument('--verbose', action='count', help='If set, print more information about ongoing processing' )
    argparser.add_argument('--file', action='store', default=None, help='PXXML file to read')
    params = argparser.parse_args()

    # Set verbose mode
    verbose = params.verbose
    if verbose is None:
        verbose = 0

    if verbose > 0:
        timestamp = str(datetime.now().isoformat())
        t0 = timeit.default_timer()
        eprint(f"{timestamp} ({(t0-t0):.4f}): Launch and create PXXMLParser object")

    parser = PXXMLParser()

    if params.file is not None:
        parser.parse_file(params.file)
        if verbose > 0:
            timestamp = str(datetime.now().isoformat())
            t1 = timeit.default_timer()
            eprint(f"{timestamp} ({(t1-t0):.4f}): File parsing attempt complete")
        with open('zztest.json', 'w') as outfile:
            json.dump(parser.dataset, outfile, indent=2, sort_keys=True)

    else:
        parser.response_status = {'status_code': 500, 'status': 'ERROR', 'error_code': 'FILE_NOT_PROVIDED', 'description': '--file parameter not provided'}

    eprint("========================================")
    eprint(json.dumps(parser.response_status, indent=2, sort_keys=True))
    #eprint(json.dumps(parser.dataset, indent=2, sort_keys=True))

if __name__ == "__main__": main()