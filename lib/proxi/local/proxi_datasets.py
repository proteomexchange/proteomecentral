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
import pymysql
import socket
import copy
from datetime import datetime, timezone
import timeit

DEBUG = True

#### Import the Swagger client libraries
sys.path.append(os.path.dirname(os.path.abspath(__file__))+"/../client/swagger_client")
from models.dataset import Dataset


#### ProxiDatasets class
class ProxiDatasets:

    #### Constructor
    def __init__(self):
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
            [ 'instrument', 'instrument' ],
            [ 'publication', 'publication' ],
            [ 'lab head', 'labHead' ],
            [ 'announce date', "DATE_FORMAT(submissionDate,'%Y-%m-%d')" ],
            [ 'keywords', 'keywordList' ]
        ]

        self.raw_datasets = None
        got_fresh_datasets = False
        self.status = self.get_raw_datasets_from_rdbms()
        if self.status != 'OK':
            eprint(f"{self.status_response['status']}: {self.status_response['description']}")

            self.load_raw_datasets()
            if self.status != 'OK':
                eprint(f"{self.status_response['status']}: {self.status_response['description']}")
                return
        else:
            got_fresh_datasets = True

        if got_fresh_datasets:
            self.store_raw_datasets()
            if self.status != 'OK':
                eprint(f"{self.status_response['status']}: {self.status_response['description']}")
                return

        self.scrubbed_rows = None
        self.scrubbed_lower_string_rows = None
        self.scrub_data(self.raw_datasets)

        self.default_facets, self.default_row_match_index = self.compute_facets(self.scrubbed_rows)


    #### Destructor
    def __del__(self):
        pass


    #### Destructor
    def __del__(self):
        pass




    #### Get configs
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
    def fetch_dataset_from_PC(self,dataset_identifier):

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

        if status_code == 200:
            try:
                payload = payload.decode('utf-8', 'replace')
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




    #### List datasets
    def list_datasets(self, resultType, pageSize = None, pageNumber = None, species = None, accession = None, instrument = None, contact = None, publication = None, modification = None, search = None, keywords = None, year = None, outputFormat = None):

        DEBUG = True

        if DEBUG:
            t0 = timeit.default_timer()
            eprint(f"({(t0-t0):.4f}): Start list_datasets()")

        #### Set up the response message
        self.status_response = { 'status_code': 500, 'status': 'ERROR', 'error_code': 'UNKNOWN_LD95', 'description': 'An improperly handled error has occurred' }
        query_block = { 'resultType': resultType, 'pageSize': pageSize, 'pageNumber': pageNumber, 'species': species, 'accession': accession, 'instrument': instrument,
                        'contact': contact, 'publication': publication, 'modification': modification, 'search': search, 'keywords': keywords, 'year': year }
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
        handled_constraints = { 'instrument': instrument, 'species': species, 'keywords': keywords, 'year': year, 'search': search }
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
        return(self.status_response['status_code'], message)




    #### Scrub the data of known problems to create a clean dataset to work with
    def scrub_data(self, rows):

        if DEBUG:
            eprint(f"DEBUG: Scrubbing {len(rows)} rows")

        columns_to_scrub = { 'species': 3, 'instrument': 4, 'keywords': 8 }
        scrubbed_rows = []
        scrubbed_lower_string_rows = []

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
                values = values_str.split(',')

                cell_items = {}
                for value in values:
                    value = value.strip()
                    if value == '':
                        continue
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
        return
    



    #### Compute the available facets
    def compute_facets(self, rows):

        facet_data = { 'species': {}, 'instrument': {}, 'keywords': {}, 'year': {} }
        facets_to_extract = { 'species': 3, 'instrument': 4, 'keywords': 8, 'year': 7 }
        useless_keyword_list = [ 'proteomics', 'LC-MS/MS', 'LC-MSMS', 'Biological', 'human','mouse', 'mass spectrometry',
                                 'proteome', 'Arabidopsis', 'Arabidopsis thaliana', 'Biomedical', 'Biomedical;  Human',
                                 'proteomic', 'Yeast' ]
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
                    if value.lower() in useless_keywords:
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
    params = argparser.parse_args()

    # Set verbose mode
    verbose = params.verbose
    if verbose is None:
        verbose = 1

    if verbose > 0:
        timestamp = str(datetime.now().isoformat())
        t0 = timeit.default_timer()
        eprint(f"{timestamp} ({(t0-t0):.4f}): Create ProxiDatasets object")

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
        status_code, message = proxi_datasets.list_datasets('compact', pageSize=2, keywords='TMT', search='prod,christ')

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

    status_code,message = proxi_datasets.fetch_dataset_from_PC(id)
    print('Status='+str(status_code))
    print('Message='+str(message))
    print(proxi_datasets.dataset)

if __name__ == "__main__": main()

