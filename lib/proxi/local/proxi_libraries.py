#!/usr/bin/env python3

import sys
import os
import argparse
import os.path
import re
import json
import ast
from datetime import datetime, timezone
import timeit
import socket
def eprint(*args, **kwargs): print(*args, file=sys.stderr, **kwargs)

DEBUG = True

BASE = '/net/dblocal/data/SpectralLibraries/python/devED/SpectralLibraries'

if socket.gethostname() == 'WALDORF':
    BASE = 'C:\local\Repositories\GitHub\SpectralLibraries'
    sys.path.append("C:\local\Repositories\GitHub\SpectralLibraries\lib")

from SpectrumLibraryCollection import SpectrumLibraryCollection


#### ProxiDatasets class
class ProxiLibraries:

    #### Constructor
    def __init__(self):
        self.status = 'OK'
        self.status_response = { 'status_code': 500, 'status': 'ERROR', 'error_code': 'UNKNOWN_PL25', 'description': 'An improperly handled error has occurred' }

        self.column_data = [
            [ 'Library Identifier', 'id_name' ],
            [ 'Version Tag', "version_tag" ],
            [ 'Title', 'title' ],
            [ 'Source', 'source' ],
            [ 'Species', 'species' ],
            [ 'Fragmentation Type', 'fragmentation_type' ],
            [ 'Lab Head', 'lab_head_full_name' ],
            [ 'Release Date', 'release_date' ],
            [ 'N Spectra', 'n_entries' ],
            [ 'Keywords', 'keywords' ]
        ]

        self.raw_libraries = None
        self.scrubbed_rows = None
        self.scrubbed_lower_string_rows = None
        self.default_facets = None
        self.default_row_match_index = None
        self.last_refresh_timestamp = None

        collection_dir = BASE + '/spectralLibraries'
        self.spectrum_library_collection = SpectrumLibraryCollection(collection_dir + "/SpectrumLibraryCollection.sqlite")

        self.library = None

        self.refresh_data()



    #### Destructor
    def __del__(self):
        pass



    #### Set the content to an example
    def get_library(self, identifier=None, version_tag=None):

        if identifier is None or not isinstance(identifier, str):
            return(404, { "status": 404, "title": "identifier not specified", "detail": f"PXL identifier not specified or invalid", "type": "about:blank" }, {} )

        found_row = None
        n_matching_rows = 0

        i_row = 0
        for row in self.scrubbed_rows:
            if row['id_name'] == identifier:
                if version_tag is not None:
                    if row['version_tag'] == version_tag:
                        found_row = i_row
                        n_matching_rows += 1
                else:
                    found_row = i_row
                    n_matching_rows += 1
            i_row += 1

        if n_matching_rows == 0:
            return(404, { "status": 404, "title": "Library not found", "detail": f"Library not found with specified identifier and version_tag", "type": "about:blank" }, {} )

        if n_matching_rows > 1:
            return(404, { "status": 404, "title": "Multiple matching libraries", "detail": f"Multiple libraries with that identifier. Please specify a version_tag", "type": "about:blank" }, {} )

        return(200, { "status": 200 }, self.scrubbed_rows[found_row] )



    #### Print the contents of the library object
    def show(self):
        print("Library:")
        print(json.dumps(ast.literal_eval(repr(self.library)),sort_keys=True,indent=2))



    #### Refresh the in-memory libraries if they are sufficiently stale
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

        if DEBUG:
            timestamp = str(datetime.now().isoformat())
            t0 = timeit.default_timer()
            eprint(f"{timestamp} (------) INFO: Refreshing data")

        #### Get a fresh set of libraries from the RDBMS
        got_fresh_data = False
        self.status = self.get_raw_libraries_from_rdbms()

        #### If this didn't work, then try to load our previous cache
        if self.status != 'OK':
            eprint(f"{self.status_response['status']}: {self.status_response['description']}")

            self.load_raw_libraries()
            if self.status != 'OK':
                eprint(f"{self.status_response['status']}: {self.status_response['description']}")
                return
        else:
            got_fresh_data = True

        #### If we just got new results from the RDBMS, then store a copy in case we need it later
        if got_fresh_data:
            self.store_raw_libraries()
            if self.status != 'OK':
                eprint(f"{self.status_response['status']}: {self.status_response['description']}")
                return

        #### Scrub the data
        self.scrubbed_rows = None
        self.scrubbed_lower_string_rows = None
        self.scrub_data(self.raw_libraries)

        #### Compute and store the default set of facet data
        self.default_facets, self.default_row_match_index = self.compute_facets(self.scrubbed_rows)

        current_timestamp = datetime.now().timestamp()
        if DEBUG:
            timestamp = str(datetime.now().isoformat())
            t1 = timeit.default_timer()
            eprint(f"{timestamp} ({(t1-t0):.4f}) INFO: Data refreshed. Storing new last_refresh_timestamp {current_timestamp}")

        self.last_refresh_timestamp = current_timestamp



    #### Get the raw list of datasets from the RDBMS
    def get_raw_libraries_from_rdbms(self):

        if DEBUG:
            timestamp = str(datetime.now().isoformat())
            t0 = timeit.default_timer()
            eprint(f"{timestamp} (------) INFO: Getting raw libraries data from RDBMS")
        collection_dir = BASE + '/spectralLibraries'
        spectrum_library_collection = SpectrumLibraryCollection(collection_dir + "/SpectrumLibraryCollection.sqlite")
        rows = spectrum_library_collection.get_libraries()

        new_rows = []
        for row in rows:
            row_dict = row.__dict__
            del(row_dict['_sa_instance_state'])
            row_dict['record_created_datetime'] = str(row_dict['record_created_datetime'])
            row_dict['record_human_updated_datetime'] = str(row_dict['record_human_updated_datetime'])
            row_dict['record_automation_updated_datetime'] = str(row_dict['record_automation_updated_datetime'])
            new_rows.append(row_dict)
        self.raw_libraries = new_rows

        if DEBUG:
            timestamp = str(datetime.now().isoformat())
            t1 = timeit.default_timer()
            eprint(f"{timestamp} ({(t1-t0):.4f}) INFO: Got {len(rows)} libraries from RDBMS")
 
        self.status = 'OK'
        return self.status

        #for library in libraries:
        #    row = { 'id': library.library_record_id, 'id_name': library.id_name, 'version': str(library.version), 'original_name': library.original_name }
        #    libraries_list.append(row)

 

    #### Store raw datasets as obtained from RDBMS
    def store_raw_libraries(self):

        if self.raw_libraries is None:
            eprint(f"ERROR: [datasets.store_raw_libraries]: No raw libraries are available")
            return 'OK'

        raw_libraries_filepath = os.path.dirname(os.path.abspath(__file__)) + "/libraries_raw_libraries.json"

        if DEBUG:
            timestamp = str(datetime.now().isoformat())
            t0 = timeit.default_timer()
            eprint(f"{timestamp} (------) INFO: Storing raw libraries to '{raw_libraries_filepath}'")

        #try:
        if True:
            with open(raw_libraries_filepath, 'w') as outfile:
                json.dump(self.raw_libraries, outfile)
        #except:
        else:
            eprint(f"ERROR: [libraries.store_raw_libraries]: Unable to write raw_libraries to file")
            return 'OK'

        if DEBUG:
            timestamp = str(datetime.now().isoformat())
            t1 = timeit.default_timer()
            eprint(f"{timestamp} ({(t1-t0):.4f}) INFO: Stored raw libraries to '{raw_libraries_filepath}'")

        self.status = 'OK'
        return self.status



    #### Store raw libraries as obtained from RDBMS
    def load_raw_libraries(self):

        raw_libraries_filepath = os.path.dirname(os.path.abspath(__file__)) + "/libraries_raw_libraries.json"
        if not os.path.exists(raw_libraries_filepath):
            eprint(f"ERROR: [datasets.load_raw_libraries]: No raw libraries file '{raw_libraries_filepath}'")
            self.status_response = { 'status_code': 500, 'status': 'ERROR', 'error_code': 'FATALERROR', 'description': 'Missing raw libraries file' }
            return self.status_response['status']

        if DEBUG:
            timestamp = str(datetime.now().isoformat())
            eprint(f"{timestamp}: DEBUG: Loading raw datasets from '{raw_libraries_filepath}'")
            t0 = timeit.default_timer()
        try:
            with open(raw_libraries_filepath,) as infile:
                self.raw_datasets = json.load(infile)
        except:
            self.status_response = { 'status_code': 500, 'status': 'ERROR', 'error_code': 'FATALERROR', 'description': 'Unable to load raw libraries from file' }
            return self.status_response['status']

        if DEBUG:
            timestamp = str(datetime.now().isoformat())
            t1 = timeit.default_timer()
            eprint(f"{timestamp}: DEBUG: Loaded raw datasets in {(t1-t0):.4f} seconds")

        self.status = 'OK'
        return self.status



    #### List datasets
    def list_libraries(self, resultType, pageSize = None, pageNumber = None, outputFormat = None,
                       species = None, accession = None, fragmentation_type = None, lab_head_full_name = None,
                       search = None, keywords = None, year = None, source = None):

        DEBUG = True

        if DEBUG:
            timestamp = str(datetime.now().isoformat())
            t0 = timeit.default_timer()
            eprint(f"{timestamp} (------) INFO: Start list_libraries()")

        #### Set up the response message
        self.status_response = { 'status_code': 500, 'status': 'ERROR', 'error_code': 'UNKNOWN_LL275', 'description': 'An improperly handled error has occurred' }
        query_block = { 'resultType': resultType, 'pageSize': pageSize, 'pageNumber': pageNumber, 'species': species, 'accession': accession, 'fragmentation_type': fragmentation_type,
                        'lab_head_full_name': lab_head_full_name, 'search': search, 'keywords': keywords, 'year': year, 'source': source }
        result_set_block = { 'page_size': 0, 'page_number': 0, 'n_rows_returned': 0, 'n_available_rows': 0 }
        message = { 'status': self.status_response, 'query': query_block, 'result_set': result_set_block, 'facets': {} }

        if pageSize is None or pageSize < 1 or pageSize > 10000000:
            pageSize = 100
        if pageNumber is None or pageNumber < 1 or pageNumber > 10000000:
            pageNumber = 1

        #### Prepare column information
        column_data = self.column_data
        column_title_list = []
        column_key_list = []
        for column in column_data:
            column_title_list.append(column[0])
            column_key_list.append(column[1])

        #### Check the constraints for validity
        handled_constraints = { 'fragmentation_type': fragmentation_type, 'species': species, 'keywords': keywords, 'year': year, 'source': source, 'search': search, 'accession': accession }
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
            timestamp = str(datetime.now().isoformat())
            t1 = timeit.default_timer()
            eprint(f"{timestamp} ({(t1-t0):.4f}) INFO: Setup complete")
            t0 = t1

        #### Use the cached scrubbed rows as the starter
        rows = self.scrubbed_rows

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
                    if constraint == 'search':
                        for item in value:
                            if item.lower() not in self.scrubbed_lower_string_rows[irow]:
                                keep = False
                                break
                    else:
                        for item in value:
                            if item not in row_match_index[constraint] or irow not in row_match_index[constraint][item]:
                                keep = False
                                break

                if keep:
                    new_rows.append(row)
                irow += 1
            rows = new_rows

            #### Recompute the facets on the filtered rows
            facets, row_match_index = self.compute_facets(rows)

        if DEBUG:
            timestamp = str(datetime.now().isoformat())
            t1 = timeit.default_timer()
            eprint(f"{timestamp} ({(t1-t0):.4f}) INFO: facets and row_match_index obtained")
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
            timestamp = str(datetime.now().isoformat())
            t1 = timeit.default_timer()
            eprint(f"{timestamp} ({(t1-t0):.4f}) INFO: Filtered rows")
            t0 = t1

        #### Compute the number of available pages
        n_available_pages = match_count * 1.0 / pageSize
        if int(n_available_pages) == n_available_pages:
            n_available_pages = int(n_available_pages)
        else:
            n_available_pages = int(n_available_pages) +1

        #### For resultType=resultset, transform to a list of lists of just the most interesting attributes
        if resultType == 'resultset':
            libraries_title_list = []
            for column in self.column_data:
                libraries_title_list.append(rows[column[0]])
            resultset_row_list = []
            for rows in new_rows:
                row = []
                for column in self.column_data:
                    row.append(rows[column[1]])
                resultset_row_list.append(row)
            message['libraries'] = resultset_row_list
            message['result_set'] = { 'page_size': pageSize, 'page_number': pageNumber, 'n_rows_returned': n_rows,
                                    'n_available_rows': match_count, 'n_available_pages': n_available_pages,
                                    'libraries_title_list': libraries_title_list }

        else:
            message['libraries'] = new_rows
            message['result_set'] = { 'page_size': pageSize, 'page_number': pageNumber, 'n_rows_returned': n_rows,
                                    'n_available_rows': match_count, 'n_available_pages': n_available_pages,
                                    'column_title_list': column_title_list, 'column_key_list': column_key_list }

        message['facets'] = facets

        if DEBUG:
            timestamp = str(datetime.now().isoformat())
            t1 = timeit.default_timer()
            eprint(f"{timestamp} ({(t1-t0):.4f}) INFO: Done")
            t0 = t1

        self.status_response = { 'status_code': 200, 'status': 'OK', 'error_code': None, 'description': f"Sent {n_rows} libraries" }
        message['status'] = self.status_response

        mimetype = 'application/json'
        if outputFormat is not None and outputFormat.lower() == 'tsv':
            mimetype = 'text/tab-separated-values'
            message = message['libraries']
        return(self.status_response['status_code'], message, mimetype)







    #### Scrub the data of known problems to create a clean set of rows to work with
    def scrub_data(self, rows):

        if DEBUG:
            timestamp = str(datetime.now().isoformat())
            t0 = timeit.default_timer()
            eprint(f"{timestamp} (------) INFO: Scrubbing {len(rows)} rows")

        if DEBUG:
            timestamp = str(datetime.now().isoformat())
            t1 = timeit.default_timer()
            eprint(f"{timestamp} (------) INFO: Libraries currently do not need scrubbing")

        # No scrubbing is needed at this time
        self.scrubbed_rows = rows

        # But do create lower_string_rows
        self.scrubbed_lower_string_rows = []
        irow = 0
        for row in rows:
            lower_string = ''
            for key, value in row.items():
                if not key.endswith('datetime') and value is not None:
                    lower_string += str(value).lower() + ' '
            self.scrubbed_lower_string_rows.append(lower_string)

        if DEBUG:
            timestamp = str(datetime.now().isoformat())
            t1 = timeit.default_timer()
            eprint(f"{timestamp} ({(t1-t0):.4f}) INFO: Data scrubbing complete")

        return


    #### Compute the available facets
    def compute_facets(self, rows):

        facet_data = { 'species': {}, 'source': {}, 'fragmentation_type': {}, 'keywords': {}, 'year': {}, 'lab_head_full_name': {} }
        facets_to_extract = { 'species': 0, 'source': 0, 'fragmentation_type': 0, 'keywords': 0, 'year': 0, 'lab_head_full_name': 0 }
        useless_keyword_list = [ 'dummy' ]

        useless_keywords = {}
        for word in useless_keyword_list:
            useless_keywords[word.lower()] = True

        row_match_index = {}
        for facet_name in facet_data:
            row_match_index[facet_name] = {}
        row_match_index['accession'] = {}

        #### Compute species facet information
        irow = 0
        for row in rows:
            for facet_name, icolumn in facets_to_extract.items():

                # When rows are lists
                #values_str = row[icolumn]

                # When rows are dicts, and special workaround for year
                if facet_name == 'year':
                    values_str = row['release_date'][0:4]
                    #### Store the accession in a special index component
                    row_match_index['accession'][row['id_name']] = { irow: True }
                else:
                    values_str = row[facet_name]
 
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
                    #row[icolumn] = ", ".join(sorted(list(cell_items.keys())))
                    row[facet_name] = ", ".join(sorted(list(cell_items.keys())))
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

    argparser = argparse.ArgumentParser(description='Class for a PROXI library')
    argparser.add_argument('--verbose', action='count', help='If set, print more information about ongoing processing' )
    argparser.add_argument('--id', action='store', default=None, help='PXL identifier to access')
    argparser.add_argument('--list', action='count', help='If set, list libraries' )
    params = argparser.parse_args()

    # Set verbose mode
    verbose = params.verbose
    if verbose is None:
        verbose = 1

    if verbose > 0:
        timestamp = str(datetime.now().isoformat())
        t0 = timeit.default_timer()
        eprint(f"{timestamp} (------) INFO: Creating ProxiLibraries object")

    proxi_libraries = ProxiLibraries()
    if proxi_libraries.status != 'OK':
        eprint("ERROR: Failed to initialize")
        return

    if verbose > 0:
        timestamp = str(datetime.now().isoformat())
        t1 = timeit.default_timer()
        eprint(f"{timestamp} ({(t1-t0):.4f}) INFO: Created ProxiLibraries object")

    #### Flag for listing all libraries
    if params.list is not None:
        if verbose > 0:
            timestamp = str(datetime.now().isoformat())
            t1 = timeit.default_timer()
            eprint(f"{timestamp} ({(t1-t0):.4f}): Call list_datasets()")
            t0 = t1
        #status_code, message, mimetype = proxi_libraries.list_libraries('compact', pageSize=10, keywords='hair') # works
        #status_code, message, mimetype = proxi_libraries.list_libraries('compact', pageSize=10, accession='PXL000010') # works
        #status_code, message, mimetype = proxi_libraries.list_libraries('compact', pageSize=10, fragmentation_type='ion trap') # works
        #status_code, message, mimetype = proxi_libraries.list_libraries('compact', pageSize=10, fragmentation_type='ETD') # works
        #status_code, message, mimetype = proxi_libraries.list_libraries('compact', pageSize=2, source='NIST') # works
        status_code, message, mimetype = proxi_libraries.list_libraries('compact', pageSize=10, search='skin') # works

        if verbose > 0:
            timestamp = str(datetime.now().isoformat())
            t1 = timeit.default_timer()
            eprint(f"{timestamp} ({(t1-t0):.4f}) INFO: list_libraries() is done")
            t0 = t1

        eprint(f"{timestamp}: INFO: {len(message['libraries'])} libraries returned")

        if verbose > 1:
            #message['libraries'] = 'suppressed'
            print(json.dumps(message, indent=2, sort_keys=True))
        return

    id = 'PXL000002'
    if params.id is not None and params.id != '':
        id = params.id

    status_code, message, library = proxi_libraries.get_library(id)
    print('Status='+str(status_code))
    print('Message='+str(message))
    print(json.dumps(library, indent=2, sort_keys=True))


if __name__ == "__main__": main()
