#!/usr/bin/env python3

import sys
import os
import argparse
import os.path
import json
import ast
import http.client
import pymysql
from pymysql.cursors import DictCursor
import socket
from datetime import datetime, timezone
import timeit
import re
def eprint(*args, **kwargs): print(*args, file=sys.stderr, **kwargs)

from pxxml_parser import PXXMLParser

DEBUG = True

#### Import the Swagger client libraries
sys.path.append(os.path.dirname(os.path.abspath(__file__))+"/../client/swagger_client")
from models.dataset import Dataset


#### ProxiDatasets class
class ProxiDatasets:

    #### Constructor
    def __init__(self, refresh_datasets=False):
        self.status = 'OK'
        self.status_response = { 'status_code': 500, 'status': 'ERROR', 'error_code': 'UNKNOWN_LD95', 'description': 'An improperly handled error has occurred' }
        self.config = self.get_config()
        if self.status != 'OK':
            return

        self.column_data = [
            [ 'dataset identifier', 'datasetIdentifier' ],
            [ 'title', 'title' ],
            [ 'repository', 'PXPartner' ],
            [ 'species', 'species' ],
            [ 'SDRF', 'sdrfData' ],
            [ 'files', 'files' ],
            [ 'instrument', 'instrument' ],
            [ 'publication', 'publication' ],
            [ 'lab head', 'labHead' ],
            [ 'announce date', "DATE_FORMAT(submissionDate,'%Y-%m-%d')" ],
            [ 'keywords', 'keywordList' ]
        ]

        self.raw_datasets = None
        self.scrubbed_rows = None
        self.scrubbed_lower_string_rows = None
        self.default_facets = None
        self.default_row_match_index = None
        self.last_refresh_timestamp = None

        self.dataset_history = None

        self.extended_data = None

        if refresh_datasets:
            self.refresh_data()



    #### Destructor
    def __del__(self):
        pass



    #### Get configuration information
    def get_config(self):
        config = {}
        config_file = os.path.dirname(os.path.abspath(__file__)) + "/../../conf/system.conf"
        if DEBUG:
            timestamp = str(datetime.now().isoformat())
            eprint(f"{timestamp}: DEBUG: Loading configs from '{config_file}'")

        try:
            with open (config_file) as infile:
                for line in infile:
                    line = line.strip()
                    if len(line) == 0 or line[0] == '#':
                        continue
                    key, value = line.split('=',1)
                    key = key.strip()
                    value = value.strip()
                    config[key] = value
        except:
            self.status_response = { 'status_code': 500, 'status': 'ERROR', 'error_code': 'FATALERROR', 'description': 'Unable to connect to back-end database' }
            eprint(f"ERROR: Unable to open {config_file}")
            self.status = 'ERROR'
            return

        self.status = 'OK'
        return config



    #### Set the content to an example
    def fetch_dataset_from_PC(self, dataset_identifier):

        server = 'proteomecentral.proteomexchange.org'
        url_base = '/cgi/GetDataset?outputMode=json&ID='
        url = url_base + dataset_identifier
        self.dataset = None

        connection = http.client.HTTPSConnection(server, timeout=10)
        connection.request("GET", url)
        http_response = connection.getresponse()
        status_code = http_response.status
        message = http_response.reason
        payload = http_response.read()
        connection.close()
        dataset = None

        if status_code == 200:
            try:
                payload = payload.decode('utf-8', 'replace')
                if DEBUG:
                    eprint(f"Received payload of {len(payload)} bytes")
                dataset = json.loads(payload)
                message = { "status": status_code }
            except Exception as error:
                status_code = 500
                message = { "status": status_code, "title": "Internal JSON parsing error", "detail": "Unable to parse JSON from internal call", "type": "about:blank" }
            return status_code, message, dataset

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
            return(status_code, message, dataset)

        return(status_code, { "status": status_code, "title": "Unknown error", "detail": payload, "type": "about:blank" }, dataset )



    #### Decompose the identifier into its part if any
    def decompose_dataset_identifier(self, dataset_identifier):
        result = { "dataset_identifier": dataset_identifier, "stripped_dataset_identifier": None, "reanalysisNumber": None, "revisionNumber": None }
        match = re.search(r'\.(\d+)', dataset_identifier)
        if match:
            result['reanalysisNumber'] = int(match.group(1))
            dataset_identifier = dataset_identifier.replace(f".{match.group(1)}", "")
        match = re.search(r'\-(\d+)', dataset_identifier)
        if match:
            result['revisionNumber'] = int(match.group(1))
            dataset_identifier = dataset_identifier.replace(f"-{match.group(1)}", "")
        result['stripped_dataset_identifier'] = dataset_identifier
        return result



    #### Get the dataset metadata from the local system
    def get_dataset(self, dataset_identifier):

        decomposed_dataset_identifier = self.decompose_dataset_identifier(dataset_identifier)

        self.dataset = {}
        result = self.get_dataset_history_from_rdbms(decomposed_dataset_identifier['stripped_dataset_identifier'])
        if result != 'OK':
            return(self.status_response['status_code'], self.status_response, self.dataset)

        announcement_xml = None
        for row in self.dataset_history:
            is_correct_reanalysis_number = False
            is_correct_revision_number = False
            if decomposed_dataset_identifier['reanalysisNumber'] is not None:
                if decomposed_dataset_identifier['reanalysisNumber'] == row['reanalysisNumber']:
                    is_correct_reanalysis_number = True
            else:
                is_correct_reanalysis_number = True
            if decomposed_dataset_identifier['revisionNumber'] is not None:
                if decomposed_dataset_identifier['revisionNumber'] == row['revisionNumber']:
                    is_correct_revision_number = True
            else:
                is_correct_revision_number = True
            if is_correct_reanalysis_number is True and is_correct_revision_number is True:
                announcement_xml = row['announcementXML']

        if announcement_xml is None:
            self.status_response = { 'status_code': 404, 'status': 'ERROR', 'error_code': 'VersionNotFound', 'description': 'Unable to find the specified reanalysis or revision number for this dataset' }
            return(self.status_response['status_code'], self.status_response, self.dataset)

        #eprint(f"announcement_xml={announcement_xml}")

        announcement_xml = f"/local/wwwspecial/proteomecentral/var/submissions/{announcement_xml}"
        parser = PXXMLParser()
        result = parser.parse_file(announcement_xml)
        self.status_response = parser.response_status
        self.dataset = parser.dataset
        self.dataset['datasetHistory'] = self.dataset_history

        #### Get SDRF information if available
        self.dataset['sdrf_metadata'] = self.get_sdrf_metdata(decomposed_dataset_identifier['stripped_dataset_identifier'])

        return(self.status_response['status_code'], self.status_response, self.dataset)



    #### Get the dataset history from the MySQL server
    def get_dataset_history_from_rdbms(self, dataset_identifier):

        if socket.gethostname() != 'mimas.systemsbiology.net':
            self.status_response = { 'status_code': 500, 'status': 'ERROR', 'error_code': 'FATALERROR', 'description': 'Unable to connect to back-end database' }
            return self.status_response['status']

        table_name = "datasetHistory"
        if False:
            table_name += '_test'

        sql = f"SELECT dataset_id,datasetIdentifier,revisionNumber,reanalysisNumber,isLatestRevision,PXPartner,status,primarySubmitter,title,species,instrument," \
              f"publication,keywordList,announcementXML,identifierDate,submissionDate,revisionDate,changeLogEntry " \
              f"FROM {table_name} " \
              f"WHERE datasetIdentifier = '{dataset_identifier}' " \
              f"ORDER BY reanalysisNumber,revisionNumber,revisionDate"

        if DEBUG:
            timestamp = str(datetime.now().isoformat())
            eprint(f"{timestamp}: DEBUG: Connecting to MySQL RDBMS on {self.config['DB_serverName']}")
        try:
            session = pymysql.connect(host=self.config['DB_serverName'],
                                      user=self.config['DB_userName'],
                                      password=self.config['DB_password'],
                                      database=self.config['DB_databaseName'])
        except:
            self.status_response = { 'status_code': 500, 'status': 'ERROR', 'error_code': 'FATALERROR', 'description': 'Unable to connect to back-end database' }
            return self.status_response['status']

        if DEBUG:
            timestamp = str(datetime.now().isoformat())
            eprint(f"{timestamp}: DEBUG: Fetching history for {dataset_identifier} from RDBMS")

        try:
            cursor = session.cursor(DictCursor)
            cursor.execute(sql)
            rows = cursor.fetchall()
            cursor.close()
        except:
            self.status_response = { 'status_code': 500, 'status': 'ERROR', 'error_code': 'FATALERROR', 'description': 'Unable to get dataset history from back-end database' }
            return self.status_response['status']

        if DEBUG:
            timestamp = str(datetime.now().isoformat())
            eprint(f"{timestamp} DEBUG: Fetched {len(rows)} rows of history for {dataset_identifier}")

        self.dataset_history = rows

        if len(rows) == 0:
            self.status_response = { 'status_code': 404, 'status': 'ERROR', 'error_code': 'NoSuchIdentifier', 'description': f"Identifier {dataset_identifier} has not yet been reserved for use by any repository" }
            return self.status_response['status']

        if len(rows) == 1:
            try:
                repository = rows[0]['PXPartner']
            except:
                repository = '?'
            self.status_response = { 'status_code': 404, 'status': 'ERROR', 'error_code': 'DatasetNotYetReleased', 'description': f"Dataset {dataset_identifier} has not yet been released by {repository}", 'repository': repository }
            return self.status_response['status']

        self.status_response = { 'status_code': 200, 'status': 'OK', 'error_code': 'OK', 'description': f"{len(rows)} of history data for {dataset_identifier} fetched" }
        return self.status_response['status']



    #### Get SDRF metadata
    def get_sdrf_metdata(self, dataset_identifier):

        extern_sdrfs_dir = '/net/dblocal/wwwspecial/proteomecentral/extern/proteomics-metadata-standard/annotated-projects'

        sdrf_metadata = { 'external_sdrf_ui_url': None, 'external_sdrf_data_url': None, 'submitted_sdrf_ui_url': False, 'submitted_sdrf_data_url': False, 'sdrf_data': None }

        extern_sdrf_path = f"{extern_sdrfs_dir}/{dataset_identifier}/{dataset_identifier}.sdrf.tsv"
        if not os.path.exists(extern_sdrf_path):
            return

        with open(extern_sdrf_path) as infile:
            files = {}
            samples = {}
            file_icolumn = None
            first_line = True
            sdrf_data = { 'titles': None, 'rows': [] }
            for line in infile:
                if first_line:
                    sdrf_data['titles'] = line.strip().split("\t")
                    first_line = False
                    icolumn = 0
                    for title in sdrf_data['titles']:
                        if title == 'comment[data file]':
                            file_icolumn = icolumn
                            break
                        icolumn += 1
                    continue
                columns = line.strip().split("\t")
                sdrf_data['rows'].append(columns)

                if file_icolumn is not None:
                    files[columns[file_icolumn]] = True
                samples[columns[0]] = True

            sdrf_data['n_rows'] = len(sdrf_data['rows'])
            sdrf_data['n_samples'] = len(samples)
            sdrf_data['n_files'] = len(files)

        sdrf_metadata['sdrf_data'] = sdrf_data
        sdrf_metadata['external_sdrf_ui_url'] = f"https://github.com/bigbio/proteomics-sample-metadata/blob/master/annotated-projects/{dataset_identifier}/{dataset_identifier}.sdrf.tsv"
        sdrf_metadata['external_sdrf_data_url'] = f"https://raw.githubusercontent.com/bigbio/proteomics-sample-metadata/refs/heads/master/annotated-projects/{dataset_identifier}/{dataset_identifier}.sdrf.tsv"
        return sdrf_metadata



    #### Print the contents of the dataset object
    def show(self):
        print("Dataset:")
        print(json.dumps(ast.literal_eval(repr(self.dataset)),sort_keys=True,indent=2))



    #### Refresh the in-memory datasets if they are sufficiently stale
    def refresh_data_if_stale(self):

        refresh_interval = 600
        current_timestamp = datetime.now().timestamp()
        if DEBUG:
            eprint(f"INFO: {int(current_timestamp - self.last_refresh_timestamp)} seconds since last refresh")
        if current_timestamp - self.last_refresh_timestamp > refresh_interval:
            eprint(f"INFO: After more than {refresh_interval} seconds, it is time to refresh the data from the RDBMS")
            self.refresh_data()



    #### Refresh the in-memory datasets
    def refresh_data(self):

        #### Get a fresh set of datasets from the RDBMS
        got_fresh_datasets = False
        self.status = self.get_raw_datasets_from_rdbms()

        #### If this didn't work, then try to load our previous cache
        if self.status != 'OK':
            eprint(f"{self.status_response['status']}: {self.status_response['description']}")

            self.load_raw_datasets()
            if self.status != 'OK':
                eprint(f"{self.status_response['status']}: {self.status_response['description']}")
                return
        else:
            got_fresh_datasets = True

        #### If we just got new results from the RDBMS, then store a copy in case we need it later
        if got_fresh_datasets:
            self.store_raw_datasets()
            if self.status != 'OK':
                eprint(f"{self.status_response['status']}: {self.status_response['description']}")
                return

        #### Scrub the data
        self.load_extended_data()
        self.scrubbed_rows = None
        self.scrubbed_lower_string_rows = None
        self.scrub_data(self.raw_datasets)

        #### Compute and store the default set of facet data
        self.default_facets, self.default_row_match_index = self.compute_facets(self.scrubbed_rows)

        current_timestamp = datetime.now().timestamp()
        eprint(f"INFO: Storing new last_refresh_timestamp {current_timestamp}")
        self.last_refresh_timestamp = current_timestamp



    #### Get the raw list of datasets from the MySQL server
    def get_raw_datasets_from_rdbms(self):

        if socket.gethostname() == 'WALDORF':
            self.status_response = { 'status_code': 500, 'status': 'ERROR', 'error_code': 'FATALERROR', 'description': 'Unable to connect to back-end database' }
            return self.status_response['status']

        table_name = 'dataset'
        column_data = self.column_data

        column_sql_list = []
        column_title_list = []
        for column in column_data:
            column_title_list.append(column[0])
            column_sql_list.append(column[1])
        column_clause = ", ".join(column_sql_list)

        where_clause = "WHERE status = 'announced'"
        order_by_clause = "ORDER BY submissionDate DESC"

        if DEBUG:
            timestamp = str(datetime.now().isoformat())
            eprint(f"{timestamp}: DEBUG: Connecting to MySQL RDBMS on {self.config['DB_serverName']}")
        try:
            session = pymysql.connect(host=self.config['DB_serverName'],
                                      user=self.config['DB_userName'],
                                      password=self.config['DB_password'],
                                      database=self.config['DB_databaseName'])
        except:
            self.status_response = { 'status_code': 500, 'status': 'ERROR', 'error_code': 'FATALERROR', 'description': 'Unable to connect to back-end database' }
            return self.status_response['status']

        if DEBUG:
            timestamp = str(datetime.now().isoformat())
            eprint(f"{timestamp}: DEBUG: Fetching all announced datasets from RDBMS")
        try:
            cursor = session.cursor()
            cursor.execute(f"SELECT {column_clause} FROM {table_name} {where_clause} {order_by_clause}")
            rows = cursor.fetchall()
            cursor.close()
        except:
            self.status_response = { 'status_code': 500, 'status': 'ERROR', 'error_code': 'FATALERROR', 'description': 'Unable to get datasets from back-end database' }
            return self.status_response['status']

        new_rows = []
        for row in rows:
            new_rows.append(list(row))
        self.raw_datasets = new_rows

        self.status = 'OK'
        return self.status



    #### Store raw datasets as obtained from RDBMS
    def store_raw_datasets(self):
        if self.raw_datasets is None:
            eprint(f"ERROR: [datasets.store_raw_datasets]: No raw datasets are available")
            return 'OK'
        raw_datasets_filepath = os.path.dirname(os.path.abspath(__file__)) + "/datasets_raw_datasets.json"
        if DEBUG:
            timestamp = str(datetime.now().isoformat())
            eprint(f"{timestamp}: DEBUG: Storing raw datasets to '{raw_datasets_filepath}'")
        try:
            with open(raw_datasets_filepath, 'w') as outfile:
                json.dump(self.raw_datasets, outfile)
        except:
            eprint(f"ERROR: [datasets.store_raw_datasets]: Unable to write raw_datasets to file")
            return 'OK'

        self.status = 'OK'
        return self.status



    #### Store raw datasets as obtained from RDBMS
    def load_raw_datasets(self):

        raw_datasets_filepath = os.path.dirname(os.path.abspath(__file__)) + "/datasets_raw_datasets.json"
        if not os.path.exists(raw_datasets_filepath):
            eprint(f"ERROR: [datasets.load_raw_datasets]: No raw datasets file '{raw_datasets_filepath}'")
            self.status_response = { 'status_code': 500, 'status': 'ERROR', 'error_code': 'FATALERROR', 'description': 'Missing raw datasets file' }
            return self.status_response['status']

        if DEBUG:
            timestamp = str(datetime.now().isoformat())
            eprint(f"{timestamp}: DEBUG: Loading raw datasets from '{raw_datasets_filepath}'")
            t0 = timeit.default_timer()
        try:
            with open(raw_datasets_filepath,) as infile:
                self.raw_datasets = json.load(infile)
        except:
            self.status_response = { 'status_code': 500, 'status': 'ERROR', 'error_code': 'FATALERROR', 'description': 'Unable to load raw datasets from file' }
            return self.status_response['status']

        if DEBUG:
            timestamp = str(datetime.now().isoformat())
            t1 = timeit.default_timer()
            eprint(f"{timestamp}: DEBUG: Loaded raw datasets in {(t1-t0):.4f} seconds")

        self.status = 'OK'
        return self.status


    #### Rebuild the extended data cache
    def rebuild_extended_data_cache(self):

        DEBUG = True

        if DEBUG:
            t0 = timeit.default_timer()
            eprint(f"({(t0-t0):.4f}): Start rebuild_extended_data_cache()")

        #### Use the cached scrubbed rows as the starter
        rows = self.scrubbed_rows
        extended_data = {}

        irow = 0
        for row in rows:
            identifier = row[0]
            print(f"irow={irow}  identifier={identifier}")

            status_code, message, dataset = self.get_dataset(identifier)
            counts = self.compute_n_msruns(dataset)
            extended_data[identifier] = counts

            dataset['sdrf_metadata'] = self.get_sdrf_metdata(identifier)
            if dataset['sdrf_metadata'] is not None and 'sdrf_data' in dataset['sdrf_metadata']:
                if 'n_samples' in dataset['sdrf_metadata']:
                    extended_data[identifier]['sdrf_stats'] = f"{dataset['sdrf_metadata']['n_samples']} samples / {dataset['sdrf_metadata']['n_files']} files / {dataset['sdrf_metadata']['n_rows']} rows"

            print(f"    extended_data={extended_data[identifier]}")
            irow += 1
            #if irow > 100:
            #    break

        if DEBUG:
            t1 = timeit.default_timer()
            eprint(f"({(t1-t0):.4f}): Computed extended data metrics for {irow-1} datasets")

        self.extended_data = extended_data
        self.store_extended_data()



    #### Store raw datasets as obtained from RDBMS
    def store_extended_data(self):
        if self.extended_data is None:
            eprint(f"ERROR: [datasets.store_extended_data]: No extended_data available")
            return 'OK'
        extended_data_filepath = os.path.dirname(os.path.abspath(__file__)) + "/datasets_extended_data.json"
        if DEBUG:
            timestamp = str(datetime.now().isoformat())
            eprint(f"{timestamp}: DEBUG: Storing extended_data to '{extended_data_filepath}'")
        try:
            with open(extended_data_filepath, 'w') as outfile:
                json.dump(self.extended_data, outfile)
        except:
            eprint(f"ERROR: [datasets.store_extended_data]: Unable to write extended_data to file")
            return 'OK'

        self.status = 'OK'
        return self.status



    #### Inject the extended data
    def inject_extended_data(self, rows):

        if self.extended_data is None:
            return rows

        new_rows = []

        for row in rows:
            new_row = []
            icolumn = 0
            identifier = row[0]
            while icolumn < 9:
                if icolumn == 4:
                    if self.extended_data is not None and identifier in self.extended_data:
                        new_row.append(self.extended_data[identifier]['sdrf_stats'])
                        new_row.append(self.extended_data[identifier]['file_stats'])
                    else:
                        new_row.extend([None,None])
                new_row.append(row[icolumn])
                icolumn += 1
            new_rows.append(new_row)

        return new_rows


    #### Store raw datasets as obtained from RDBMS
    def load_extended_data(self):

        extended_data_filepath = os.path.dirname(os.path.abspath(__file__)) + "/datasets_extended_data.json"
        if not os.path.exists(extended_data_filepath):
            eprint(f"ERROR: [datasets.load_extended_data]: No raw datasets file '{extended_data_filepath}'")
            self.status_response = { 'status_code': 500, 'status': 'ERROR', 'error_code': 'FATALERROR', 'description': 'Missing extended_data file' }
            return self.status_response['status']

        if DEBUG:
            timestamp = str(datetime.now().isoformat())
            eprint(f"{timestamp}: DEBUG: Loading extended_data from '{extended_data_filepath}'")
            t0 = timeit.default_timer()
        try:
            with open(extended_data_filepath,) as infile:
                self.extended_data = json.load(infile)
        except:
            self.status_response = { 'status_code': 500, 'status': 'ERROR', 'error_code': 'FATALERROR', 'description': 'Unable to load extended_data from file' }
            return self.status_response['status']

        if DEBUG:
            timestamp = str(datetime.now().isoformat())
            t1 = timeit.default_timer()
            eprint(f"{timestamp}: DEBUG: Loaded extended_data in {(t1-t0):.4f} seconds")

        self.status = 'OK'
        return self.status



    #### Compute the number of files and MS runs for a dataset
    def compute_n_msruns(self, dataset):

        counts = { 'n_files': None, 'n_ms_runs': None, 'file_stats': None, 'n_sdrf_samples': None, 'sdrf_stats': None }
        if dataset is not None and 'datasetFiles' in dataset and dataset['datasetFiles'] is not None:
            for file in dataset['datasetFiles']:
                if 'accession' in file and file['accession'] == 'MS:1002846' or file['name'] == 'Associated raw file URI':
                    if counts['n_ms_runs'] is None:
                        counts['n_ms_runs'] = 0
                    counts['n_ms_runs'] += 1
                if counts['n_files'] is None:
                    counts['n_files'] = 0
                counts['n_files'] += 1
        if counts['n_files'] is not None:
            n_ms_runs = counts['n_ms_runs']
            if n_ms_runs is None:
                n_ms_runs = 0
            counts['file_stats'] = f"{n_ms_runs}/{counts['n_files']}"
        return counts


    #### List datasets
    def list_datasets(self, resultType, pageSize = None, pageNumber = None, species = None, accession = None, instrument = None, contact = None, publication = None, modification = None, search = None, keywords = None, year = None, repository = None, outputFormat = None):

        DEBUG = False

        if DEBUG:
            t0 = timeit.default_timer()
            eprint(f"({(t0-t0):.4f}): Start list_datasets()")

        #### Set up the response message
        self.status_response = { 'status_code': 500, 'status': 'ERROR', 'error_code': 'UNKNOWN_LD95', 'description': 'An improperly handled error has occurred' }
        query_block = { 'resultType': resultType, 'pageSize': pageSize, 'pageNumber': pageNumber, 'species': species, 'accession': accession, 'instrument': instrument,
                        'contact': contact, 'publication': publication, 'modification': modification, 'search': search, 'keywords': keywords, 'year': year, 'repository': repository }
        result_set_block = { 'page_size': 0, 'page_number': 0, 'n_rows_returned': 0, 'n_available_rows': 0 }
        message = { 'status': self.status_response, 'query': query_block, 'result_set': result_set_block, 'facets': {} }

        if pageSize is None or pageSize < 1 or pageSize > 10000000:
            pageSize = 100
        if pageNumber is None or pageNumber < 1 or pageNumber > 10000000:
            pageNumber = 1

        #### Prepare column information
        column_data = self.column_data
        column_title_list = []
        for column in column_data:
            column_title_list.append(column[0])

        #### Check the constraints for validity
        handled_constraints = { 'instrument': instrument, 'species': species, 'keywords': keywords, 'year': year, 'repository': repository, 'search': search }
        validated_constraints = {}
        for constraint, value in handled_constraints.items():
            if value is None or str(value).strip() == '':
                continue
            value = value.replace("'","")
            value = value.replace('"','')
            if value.strip() == '':
                continue
            values = value.split(',')
            if len(values) > 1:
                new_values = []
                for value in values:
                    value = value.strip()
                    new_values.append(value)
                value = new_values

            validated_constraints[constraint] = value

        if DEBUG:
            t1 = timeit.default_timer()
            eprint(f"({(t1-t0):.4f}): Setup complete")
            t0 = t1

        #### Use the cached scrubbed rows as the starter
        rows = self.scrubbed_rows

        if DEBUG:
            t1 = timeit.default_timer()
            eprint(f"({(t1-t0):.4f}): rows copied")
            t0 = t1

        #### If there are no usable constraints, they just use the cached facets and row_match_index data, no need to do it again
        if len(validated_constraints) == 0:
            facets = self.default_facets
            row_match_index = self.default_row_match_index
        else:
            facets, row_match_index = self.compute_facets(rows)

            #### Apply the supplied constraints
            irow = 0
            new_rows = []
            for row in rows:
                keep = True
                for constraint, value in validated_constraints.items():
                    if not keep:
                        break
                    if isinstance(value, str):
                        value = [ value ]
                    if constraint != 'search':
                        for item in value:
                            if item not in row_match_index[constraint] or irow not in row_match_index[constraint][item]:
                                keep = False
                                break

                    else:
                        for item in value:
                            if item == 'PRIDEbug':
                                if 'pubmed/0' not in row[5] and 'PXD0' not in row[5] and 'dx.doi.org/http' not in row[5]:
                                    keep = False
                                    break
                            else:
                                if item.lower() not in self.scrubbed_lower_string_rows[irow]:
                                    keep = False
                                    break

                if keep:
                    new_rows.append(row)
                irow += 1
            rows = new_rows

            #### Recompute the facets on the filtered rows
            facets, row_match_index = self.compute_facets(rows)

        if DEBUG:
            t1 = timeit.default_timer()
            eprint(f"({(t1-t0):.4f}): facets and row_match_index obtained")
            t0 = t1

        #### Filter for the page size and page that the client requested
        #### FIXME This could be more efficient. don't loop over all rows
        match_count = len(rows)
        new_rows = []
        irow = 1
        start_row = (pageNumber - 1) * pageSize + 1
        n_rows = 0
        for row in rows:
            if irow >= start_row and n_rows < pageSize:
                new_rows.append(row)
                n_rows += 1
            irow += 1

        if DEBUG:
            t1 = timeit.default_timer()
            eprint(f"({(t1-t0):.4f}): Filtered rows")
            t0 = t1

        #### Compute the number of available pages
        n_available_pages = match_count * 1.0 / pageSize
        if int(n_available_pages) == n_available_pages:
            n_available_pages = int(n_available_pages)
        else:
            n_available_pages = int(n_available_pages) +1

        message['datasets'] = new_rows
        message['result_set'] = { 'page_size': pageSize, 'page_number': pageNumber, 'n_rows_returned': n_rows,
                                  'n_available_rows': match_count, 'n_available_pages': n_available_pages,
                                  'datasets_title_list': column_title_list }
        message['facets'] = facets

        if DEBUG:
            t1 = timeit.default_timer()
            eprint(f"({(t1-t0):.4f}): Done")
            t0 = t1

        self.status_response = { 'status_code': 200, 'status': 'OK', 'error_code': None, 'description': f"Sent {n_rows} datasets" }
        message['status'] = self.status_response

        mimetype = 'application/json'
        if outputFormat is not None and outputFormat.lower() == 'tsv':
            mimetype = 'text/tab-separated-values'
            message = message['datasets']
        return(self.status_response['status_code'], message, mimetype)



    #### Scrub the data of known problems to create a clean dataset to work with
    def scrub_data(self, rows):

        if DEBUG:
            eprint(f"DEBUG: Scrubbing {len(rows)} rows")

        columns_to_scrub = { 'species': 3, 'instrument': 4, 'keywords': 8 }
        scrubbed_rows = []
        scrubbed_lower_string_rows = []
        corrections = { 'species':
            { 'human': 'Homo sapiens',
              'saccharomyces cerevisiae': 'Saccharomyces cerevisiae (Bakers yeast)',
              'arabidopsis thaliana': 'Arabidopsis thaliana (Mouse-ear cress)',
              'drosophila melanogaster': 'Drosophila melanogaster (Fruit fly)',
              'sus scrofa': 'Sus scrofa domesticus (domestic pig)',
              'sus scrofa domesticus': 'Sus scrofa domesticus (domestic pig)',
              'mus <mouse genus>': 'Mus musculus',
              'mus <genus>': 'Mus musculus',
            },
            'instrument':
            { 'qexactive plus (thermo)': 'Q Exactive Plus',
              'q-exactive': 'Q Exactive',
              'q-exactive plus': 'Q Exactive Plus',
              'q-exactive hf': 'Q Exactive HF',
              'qexactive': 'Q Exactive',
            }
        }

        #### Iterate through all rows and scrub the known problems
        irow = 0
        for row in rows:
            scrubbed_row = row.copy()

            #### Replace Nones with empty strings
            for i in range(len(scrubbed_row)):
                if scrubbed_row[i] is None:
                    scrubbed_row[i] = ''

            for column_name, icolumn in columns_to_scrub.items():

                values_str = scrubbed_row[icolumn]
                if column_name == 'keywords':
                    values_str = values_str.replace('submitter keyword:','')
                    values_str = values_str.replace('curator keyword:','')
                if column_name == 'instrument':
                    values_str = values_str.replace('instrument model:','')
                values_str = values_str.replace("'",'')
                values_str = values_str.replace(';',',')
                values_str = values_str.replace(', genus',' genus')
                values = values_str.split(',')

                cell_items = {}
                for value in values:
                    value = value.strip()
                    if value == '':
                        continue

                    #### Apply corrections
                    value_lower = value.lower()
                    if column_name in corrections and value_lower in corrections[column_name]:
                        value = corrections[column_name][value_lower]
                        #eprint(f"-- Correct {value_lower} to {corrections[column_name][value_lower]}")

                    cell_items[value] = True

                scrubbed_row[icolumn] = ", ".join(sorted(list(cell_items.keys())))

            scrubbed_rows.append(scrubbed_row)
            lower_string_row = "\t".join(scrubbed_row).lower()
            scrubbed_lower_string_rows.append(lower_string_row)
            irow += 1

        if DEBUG:
            eprint(f"DEBUG: Scrubbed {irow} rows")
        self.scrubbed_rows = scrubbed_rows
        self.scrubbed_lower_string_rows = scrubbed_lower_string_rows

        self.scrubbed_rows = self.inject_extended_data(scrubbed_rows)

        return
    


    #### Compute the available facets
    def compute_facets(self, rows):

        facet_data = { 'species': {}, 'instrument': {}, 'keywords': {}, 'year': {}, 'repository': {} }
        facets_to_extract = { 'repository': 2, 'species': 3, 'instrument': 4, 'keywords': 8, 'year': 7, }
        if len(rows[0]) == 11:
            facets_to_extract = { 'repository': 2, 'species': 3, 'instrument': 6, 'keywords': 10, 'year': 9, }
        useless_keyword_list = [ 'proteomics', 'LC-MS/MS', 'LC-MSMS', 'Biological', 'human','mouse', 'mass spectrometry',
                                 'proteome', 'Arabidopsis', 'Arabidopsis thaliana', 'Biomedical', 'Biomedical;  Human',
                                 'proteomic', 'Yeast', 'Technical' ]

        useless_keywords = {}
        for word in useless_keyword_list:
            useless_keywords[word.lower()] = True

        row_match_index = {}
        for facet_name in facet_data:
            row_match_index[facet_name] = {}

        #### Compute species facet information
        irow = 0
        for row in rows:
            for facet_name, icolumn in facets_to_extract.items():

                values_str = row[icolumn]
                if facet_name == 'year':
                    values_str = values_str[0:4]
 
                values = values_str.split(',')

                cell_items = {}
                for value in values:
                    value = value.strip()
                    if value == '':
                        continue
                    if facet_name == 'keywords' and value.lower() in useless_keywords:
                        continue
                    if value not in facet_data[facet_name]:
                        facet_data[facet_name][value] = 0
                    facet_data[facet_name][value] += 1
                    if value not in row_match_index[facet_name]:
                        row_match_index[facet_name][value] = {}
                    row_match_index[facet_name][value][irow] = True
                    cell_items[value] = True
                if facet_name != 'year':
                    row[icolumn] = ", ".join(sorted(list(cell_items.keys())))
            irow += 1

        for category in facets_to_extract.keys():
            new_values_list = []
            for key,value in facet_data[category].items():
                new_values_list.append( [key,value] )
            if category == 'year':
                new_values_list.sort(key=lambda x: x[0], reverse=True)
            else:
                new_values_list.sort(key=lambda x: x[1], reverse=True)
            new_values = []
            #new_values = {}
            counter = 0
            for item in new_values_list:
                new_values.append( { 'name': item[0], 'count': item[1] } )
                #new_values[item[0]] = item[1]
                counter += 1
                if counter >= 100:
                    break
            facet_data[category] = new_values

        return(facet_data, row_match_index)



#### If this class is run from the command line, perform a short little test to see if it is working correctly
def main():

    argparser = argparse.ArgumentParser(description='Class for a PROXI dataset')
    argparser.add_argument('--verbose', action='count', help='If set, print more information about ongoing processing' )
    argparser.add_argument('--id', action='store', default=None, help='PXD identifier to access')
    argparser.add_argument('--list', action='count', help='If set, list datasets' )
    argparser.add_argument('--initialize_extended_data', action='count', help='If set, (re)initialize the extended data like number of files and SDRF information' )
    params = argparser.parse_args()

    # Set verbose mode
    verbose = params.verbose
    if verbose is None:
        verbose = 1

    if verbose > 0:
        timestamp = str(datetime.now().isoformat())
        t0 = timeit.default_timer()
        eprint(f"{timestamp} ({(t0-t0):.4f}): Create ProxiDatasets object")

    #### Mechanism to rebuild the extended data cache for files and SDRF info
    if params.initialize_extended_data is not None:
        proxi_datasets = ProxiDatasets(refresh_datasets=True)
        if proxi_datasets.status != 'OK':
            eprint("ERROR: Failed to initialize")
            return
        proxi_datasets.rebuild_extended_data_cache()
        return

    proxi_datasets = ProxiDatasets()
    if proxi_datasets.status != 'OK':
        eprint("ERROR: Failed to initialize")
        return

    #### Flag for listing all datasets
    if params.list is not None:
        if verbose > 0:
            timestamp = str(datetime.now().isoformat())
            t1 = timeit.default_timer()
            eprint(f"{timestamp} ({(t1-t0):.4f}): Call list_datasets()")
            t0 = t1
        status_code, message, mimetype = proxi_datasets.list_datasets('compact', pageSize=2, keywords='TMT', search='prod,christ')

        if verbose > 0:
            timestamp = str(datetime.now().isoformat())
            t1 = timeit.default_timer()
            eprint(f"{timestamp} ({(t1-t0):.4f}): list_datasets() is done")
            t0 = t1

        eprint(f"{timestamp}: INFO: {len(message['datasets'])} datasets returned")

        if verbose > 1:
            print(json.dumps(message, indent=2))
        return

    id = 'PXD011825'
    if params.id is not None and params.id != '':
        id = params.id

    #status_code, message, dataset = proxi_datasets.fetch_dataset_from_PC(id)
    status_code, message, dataset = proxi_datasets.get_dataset(id)
    print('Status='+str(status_code))
    print('Message='+str(message))
    print(dataset)


if __name__ == "__main__": main()
