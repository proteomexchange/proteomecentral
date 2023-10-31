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


    #### List datasets
    def list_datasets(self, resultType, pageSize = None, pageNumber = None, species = None, accession = None, instrument = None, contact = None, publication = None, modification = None, search = None, keywords = None, year = None):

        #### Set up the response message
        status_block = { 'status_code': 500, 'status': 'ERROR', 'error_code': 'UNKNOWN_LD95', 'description': 'An improperly handled error has occurred' }
        query_block = { 'resultType': resultType, 'pageSize': pageSize, 'pageNumber': pageNumber, 'species': species, 'accession': accession, 'instrument': instrument,
                        'contact': contact, 'publication': publication, 'modification': modification, 'search': search, 'keywords': keywords, 'year': year }
        result_set_block = { 'page_size': 0, 'page_number': 0, 'n_rows_returned': 0, 'n_available_rows': 0 }
        message = { 'status': status_block, 'query': query_block, 'result_set': result_set_block, 'facets': {} }

        if pageSize is None or pageSize < 1 or pageSize > 10000000:
            pageSize = 100
        if pageNumber is None or pageNumber < 1 or pageNumber > 10000000:
            pageNumber = 1
        limit_clause = f"LIMIT {pageSize} OFFSET {(pageNumber-1) * pageSize}"
        order_by_clause = "ORDER BY submissionDate DESC"
        table_name = 'dataset'
        column_data = [
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
        column_sql_list = []
        column_title_list = []
        for column in column_data:
            column_title_list.append(column[0])
            column_sql_list.append(column[1])
        column_clause = ", ".join(column_sql_list)

        where_clause = "WHERE status = 'announced'"

        #constraints = { 'instrument': instrument, 'species': species,  }
        #for constraint,value in constraints.items():
        #    if value is None or str(value) == '':
        #        continue
        #    value = value.replace("'","")
        #    value = value.replace('"','')
        #    if value[0] == '~':
        #        where_clause += f" AND {constraint} LIKE '%{value[1:]}%'"
        #    else:
        #        where_clause += f" AND {constraint} = '{value}'"

        try:
            session = pymysql.connect(host="mimas", user="proteomecentral", password="xx", database="ProteomeCentral")
        except:
            status_block = { 'status_code': 500, 'status': 'ERROR', 'error_code': 'FATALERROR', 'description': 'Unable to connect to back-end database' }
            message['status'] = status_block
            return(status_block['status_code'], message)

        try:
            cursor = session.cursor()
            cursor.execute(f"SELECT {column_clause} FROM {table_name} {where_clause} {order_by_clause}")
            rows = cursor.fetchall()
            cursor.close()
        except:
            status_block = { 'status_code': 400, 'status': 'ERROR', 'error_code': 'INPUTERROR', 'description': 'Improper constraints caused query error' }
            message['status'] = status_block
            return(status_block['status_code'], message)

        new_rows = []
        for row in rows:
            new_rows.append(list(row))
        rows = new_rows

        match_count = len(rows)
        facets, row_match_index = self.compute_facets(rows, column_data)

        irow = 0
        new_rows = []
        constraints = { 'instrument': instrument, 'species': species, 'keywords': keywords, 'year': year }
        for row in rows:
            keep = True
            for constraint,value in constraints.items():
                if value is None or str(value) == '':
                    continue
                value = value.replace("'","")
                value = value.replace('"','')
                if value not in row_match_index[constraint] or irow not in row_match_index[constraint][value]:
                    keep = False
            if keep:
                new_rows.append(row)
            irow += 1
        rows = new_rows

        match_count = len(rows)
        facets, row_match_index = self.compute_facets(rows, column_data)

        #### Filter for the page size and page that the client requested
        datasets = []
        irow = 1
        start_row = (pageNumber - 1) * pageSize + 1
        n_rows = 0
        for row in rows:
            if irow >= start_row and n_rows < pageSize:
                datasets.append(row)
                n_rows += 1
            irow += 1

        #### Compute the number of available pages
        n_available_pages = match_count * 1.0 / pageSize
        if int(n_available_pages) == n_available_pages:
            n_available_pages = int(n_available_pages)
        else:
            n_available_pages = int(n_available_pages) +1

        message['datasets'] = datasets
        message['result_set'] = { 'page_size': pageSize, 'page_number': pageNumber, 'n_rows_returned': n_rows,
                                  'n_available_rows': match_count, 'n_available_pages': n_available_pages,
                                  'datasets_title_list': column_title_list }
        message['facets'] = facets

        status_block = { 'status_code': 200, 'status': 'OK', 'error_code': None, 'description': f"Sent {n_rows} datasets" }
        message['status'] = status_block
        return(status_block['status_code'], message)


    #### Compute the available facets
    def compute_facets(self, rows, column_data):

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
                if facet_name == 'keywords':
                    values_str = values_str.replace('submitter keyword:','')
                    values_str = values_str.replace('curator keyword:','')
                if facet_name == 'instrument model:':
                    values_str = values_str.replace('instrument model:','')
                if facet_name == 'year':
                    values_str = values_str[0:4]
                values_str = values_str.replace("'",'')
                values_str = values_str.replace(';',',')
                values = values_str.split(',')
                suffix = ''
                if len(values) > 1 and facet_name != 'keywords':
                    #suffix = '+'
                    suffix = ''

                cell_items = {}
                for value in values:
                    value = value.strip() + suffix
                    #value = value.strip(';') + suffix
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

    proxi_datasets = ProxiDatasets()

    #### Flag for listing all datasets
    if params.list is not None:
        status_code, message = proxi_datasets.list_datasets('compact', pageSize=2)
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

