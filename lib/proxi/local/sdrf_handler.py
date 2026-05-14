#!/usr/bin/env python3

import sys
import os
import argparse
import os.path
import json
import pandas as pd
import numpy
import re
import pandas
def eprint(*args, **kwargs): print(*args, file=sys.stderr, **kwargs)


####################################################################################################
#### SDRF handler class for reading, writing, and merging SDRFs
class SDRFHandler:


    ####################################################################################################
    #### Constructor
    def __init__(self, filepath=None, verbose=None):

        self.filepath = filepath
        self.filename = self.extract_filename(filepath)
        self.filetype = { 'extension': None, 'type': None, 'delimiter': None }

        self.sdrf_data = None
        self.column_properties = None
        self.n_rows = None
        self.n_samples = None
        self.n_assays = None
        self.n_files = None

        self.ui_url = None
        self.data_url = None
        self.problems = { 
            'errors': { 'count': 0, 'codes': {}, 'list': [] },
            'warnings': { 'count': 0, 'codes': {}, 'list': [] }
        }
 
        #### Check if a verbose was provided and if not, set to default
        if verbose is None:
            verbose = 0
        self.verbose = verbose



    ####################################################################################################
    #### Extract the file name portion from a full path
    def extract_filename(self, filepath):

        if filepath is None:
            return

        if not isinstance(filepath, str):
            eprint(f"ERROR: SDRFData.extract_filename: filepath must be a string")
            return

        match = re.match(r'.*/(.+)?$', filepath)
        if match:
            filename = match.group(1)

        else:
            filename = filepath

        self.filename = filename
        return filename



    ####################################################################################################
    #### Try to infer some things about the file based on the name
    def infer_filetype(self):

        filename = self.filename
        filetype = { 'extension': None, 'type': None, 'delimiter': None }

        if filename.casefold().endswith('tsv'.casefold()):
            filetype = { 'extension': filename[-3:], 'type': 'tsv', 'delimiter': "\t" }
        elif filename.casefold().endswith('txt'.casefold()):
            filetype = { 'extension': filename[-3:], 'type': 'tsv', 'delimiter': "\t" }
        elif filename.casefold().endswith('sdrf'.casefold()):
            filetype = { 'extension': filename[-4:], 'type': 'tsv', 'delimiter': "\t" }
        elif filename.casefold().endswith('csv'.casefold()):
            filetype = { 'extension': filename[-3:], 'type': 'csv', 'delimiter': "," }
            self.log_problem('ERROR', 'CSVNotValid', 0, 0, f"SDRF must be tab-separated, not comma-separated")
        elif filename.casefold().endswith('xls'.casefold()):
            filetype = { 'extension': filename[-3:], 'type': 'xls', 'delimiter': None }
            self.log_problem('ERROR', 'XLSNotValid', 0, 0, f"SDRF must be tab-separated, not Excel xls format")
        elif filename.casefold().endswith('xlsx'.casefold()):
            filetype = { 'extension': filename[-4:], 'type': 'xls', 'delimiter': None }
            self.log_problem('ERROR', 'XLSXNotValid', 0, 0, f"SDRF must be tab-separated, not Excel xlsx format")
        else:
            eprint(f"WARNING: SDRFData.infer_filetype: Unable to guess the formatting based on filename. Guessing TSV")
            filetype = { 'extension': '', 'type': 'tsv', 'delimiter': "\t" }

        self.filetype = filetype
        return filetype



    ####################################################################################################
    #### Read an SDRF file
    def read(self, filepath=None):

        if filepath is not None:
            self.filepath = filepath
            self.filename = self.extract_filename(filepath)
        else:
            filepath = self.filepath

        if filepath is None:
            eprint(f"ERROR: SDRFData.read: No available filepath to read")
            return

        filetype = self.infer_filetype()

        if filetype['delimiter'] is not None:
            with open(filepath, encoding='utf-8-sig', errors='ignore') as infile:
                first_line = True
                sdrf_data = { 'titles': None, 'rows': [] }
                for line in infile:
                    if len(line.strip()) < 2:
                        continue
                    if first_line:
                        sdrf_data['titles'] = line.strip().split(filetype['delimiter'])
                        first_line = False
                        continue
                    columns = line.strip().split(filetype['delimiter'])
                    #### Add empty values at the end if the row has fewer columns of data than the titles
                    while len(columns) < len(sdrf_data['titles']):
                        columns.append('')
                    sdrf_data['rows'].append(columns)

        elif filetype['type'] == 'xls':
            source_sdrf_data = pandas.read_excel(filepath)
            sdrf_data = { 'titles': list(source_sdrf_data), 'rows': [] }
            for index, row in source_sdrf_data.iterrows():
                rowdata = row.tolist()
                #### Deal with NaN values, which cause problems
                newrowdata = []
                icolumn = 1
                for value in rowdata:
                    if isinstance(value, float) and numpy.isnan(value):
                        value = 'NaN'
                        self.log_problem('ERROR', 'NaNValue', index + 1, icolumn, f"Value cannot be NaN")
                    newrowdata.append(value)
                    icolumn += 1
                sdrf_data['rows'].append(newrowdata)

        else:
            eprint(f"WARNING: Don't know how to read file '{filepath}'")
            return

        self.sdrf_data = sdrf_data

        self.check_and_fix_headers()
        self.compute_stats()



    ####################################################################################################
    #### Check and potentially fix the header values
    def check_and_fix_headers(self):

        sdrf_data = self.sdrf_data
        if sdrf_data is None:
            eprint(f"ERROR: SDRFData.check_and_fix_headers: No available data to process")
            return

        required_columns = {
            'source name': None,
            'assay name': None,
            'comment[fraction identifier]': None,
            'comment[label]': None,
            'comment[data file]': None,
        }

        recommended_columns = {
            'technology type': None,
            'characteristics[organism]': None,
            'characteristics[organism part]': None,
            'comment[technical replicate]': None,
            'comment[biological replicate]': None,
            'comment[file uri]': None,
            'comment[modification parameters]': None,
            'comment[cleavage agent details]': None,
            'comment[instrument]': None,
        }

        titles = sdrf_data['titles']
        new_titles = []
        icolumn = 0
        for title in titles:
            if title != title.lower():
                self.log_problem('WARNING', 'TitleNotLowerCase', 0, icolumn, f"Column header '{title}' SHOULD be lower case")
            new_titles.append(title.lower())
            if icolumn == 0 and title.lower() != 'source name':
                self.log_problem('ERROR', 'Column0NotSourceName', 0, icolumn, f"The first column title MUST be 'source name'")
            if title.strip() == '':
                self.log_problem('ERROR', 'EmptyColumnTitle', 0, icolumn, f"Column {icolumn+1} title is empty")
            icolumn += 1
        sdrf_data['titles'] = new_titles

        icolumn = 0
        for title in new_titles:
            if title in required_columns:
                required_columns[title] = icolumn
            if title in recommended_columns:
                recommended_columns[title] = icolumn
            icolumn += 1

        for title, icolumn in required_columns.items():
            if icolumn is None:
                self.log_problem('ERROR', 'MissingRequiredColumn', 0, 0, f"Column {title} is missing")
        for title, icolumn in recommended_columns.items():
            if icolumn is None:
                self.log_problem('WARNING', 'MissingRecommendedColumn', 0, 0, f"Column {title} is missing")



    ####################################################################################################
    #### Check and potentially fix the header values
    def compute_stats(self):

        sdrf_data = self.sdrf_data
        if sdrf_data is None:
            eprint(f"ERROR: SDRFData.check_and_fix_headers: No available data to process")
            return

        columns_of_interest = [ 'source name', 'assay name', 'comment[data file]', 'comment[file uri]' ]
        column_indexes = {}
        column_unique_values = {}

        for column in columns_of_interest:
            column_indexes[column] = None
            column_unique_values[column] = {}

        titles = sdrf_data['titles']
        column_properties = []
        icolumn = 0
        for title in titles:
            if title in column_indexes:
                column_indexes[title] = icolumn
            column_properties.append( { 'is_empty': True } )
            icolumn += 1

        for row in sdrf_data['rows']:
            for title in columns_of_interest:
                if column_indexes[title] is not None:
                    icolumn = column_indexes[title]
                    column_unique_values[title][row[icolumn]] = True

        #### Record which columns are completely empty (i.e. no values in the column)
        for row in sdrf_data['rows']:
            icolumn = 0
            for title in titles:
                if row[icolumn] is not None and row[icolumn] != '':
                    column_properties[icolumn]['is_empty'] = False
                icolumn += 1
        self.column_properties = column_properties

        self.n_rows = len(sdrf_data['rows'])
        if self.n_rows == 0:
            self.log_problem('ERROR', 'ZeroRows', 0, 0, f"SDRF file has no data rows")

        self.n_samples = len(column_unique_values['source name'])
        if self.n_samples == 0:
            self.log_problem('ERROR', 'ZeroSamples', 0, 0, f"SDRF file has no samples information in 'source name'")

        self.n_assays = len(column_unique_values['assay name'])
        if self.n_assays == 0:
            self.log_problem('ERROR', 'ZeroAssays', 0, 0, f"SDRF file has no assay information for 'assay name'")

        self.n_files = len(column_unique_values['comment[data file]'])
        if len(column_unique_values['comment[file uri]']) > self.n_files:
            self.n_files = len(column_unique_values['comment[file uri]'])
            self.log_problem('ERROR', 'MissingFileNames', 0, column_indexes['comment[data file]'], f"Data for file names is missing (no data for 'comment[data file]')")
        if self.n_files == 0:
            self.log_problem('ERROR', 'MissingFileData', 0, 0, f"Neither data file nor file uri is present")



    ####################################################################################################
    #### Merge the provided SDRF object into the current SDRF object
    def merge(self, merge_sdrf, tag_with_decisions=None, prefer_main_columns=None):

        merge_empty_columns = False
        preserve_main_source_name = True

        if self.sdrf_data is None:
            eprint(f"ERROR: SDRFData.merge: No available data to process")
            return

        if merge_sdrf is None:
            eprint(f"ERROR: SDRFData.merge: Provided sdrf to merge is null. Cannot continue")
            return

        if self.n_files != merge_sdrf.n_files:
            self.log_problem('ERROR', 'DifferingNFiles', 0, 0, f"Primary SDRF has {self.n_files} files and SDRF to merge has {merge_sdrf.n_files} files. Cannot merge such differing SDRFs")
            return

        if self.n_rows != merge_sdrf.n_rows:
            self.log_problem('ERROR', 'DifferingNRows', 0, 0, f"Primary SDRF has {self.n_rows} files and SDRF to merge has {merge_sdrf.n_rows} files. Cannot merge such differing SDRFs")
            return

        if prefer_main_columns is None or prefer_main_columns == '':
            prefer_main_columns = []
        else:
            prefer_main_columns = prefer_main_columns.split(',')

        #### Set up a data structure to capture information about how to merge
        merge_data = { 'match_data': {}, 'columns': [] }

        #### Define primary columns that could be used for merging
        columns_of_interest = [ 'source name', 'assay name', 'comment[data file]', 'comment[file uri]' ]
        for title in columns_of_interest:
            if title not in merge_data['match_data']:
                merge_data['match_data'][title] = { 'main_icolumn': None, 'main_values': {}, 'merge_icolumn': None, 'merge_values': {} }

        #### Scan for and record these merge reference columns
        icolumn = 0
        for title in self.sdrf_data['titles']:
            if title in merge_data['match_data']:
                merge_data['match_data'][title]['main_icolumn'] = icolumn
            icolumn += 1

        icolumn = 0
        for title in merge_sdrf.sdrf_data['titles']:
            if title in merge_data['match_data']:
                merge_data['match_data'][title]['merge_icolumn'] = icolumn
            icolumn += 1

        #### Collate the row-level values for the target SDRF
        for row in self.sdrf_data['rows']:
            for title in columns_of_interest:
                icolumn = merge_data['match_data'][title]['main_icolumn']
                #print(f"title={title} main_icolumn={merge_data['match_data'][title]['main_icolumn']}")
                if icolumn is not None:
                    value = row[icolumn]
                    if value not in merge_data['match_data'][title]['main_values']:
                        merge_data['match_data'][title]['main_values'][value] = 0
                    merge_data['match_data'][title]['main_values'][value] += 1
                merge_data['match_data'][title]['main_n_values'] = len(merge_data['match_data'][title]['main_values'])

        #### Collate the row-level values for the SDRF to merge in
        for row in merge_sdrf.sdrf_data['rows']:
            for title in columns_of_interest:
                icolumn = merge_data['match_data'][title]['merge_icolumn']
                #print(f"title={title} merge_icolumn={merge_data['match_data'][title]['merge_icolumn']}")
                if icolumn is not None:
                    value = row[icolumn]
                    if value not in merge_data['match_data'][title]['merge_values']:
                        merge_data['match_data'][title]['merge_values'][value] = 0
                    merge_data['match_data'][title]['merge_values'][value] += 1
                merge_data['match_data'][title]['merge_n_values'] = len(merge_data['match_data'][title]['merge_values'])

        #### Set up the columns from the main SDRF
        icolumn = 0
        for title in self.sdrf_data['titles']:
            iexisting_column = 0
            found_column = False
            for existing_column in merge_data['columns']:
                if title == existing_column['title']:
                    merge_data['columns'][iexisting_column]['main_icolumn'].append(icolumn)
                    found_column = True
                iexisting_column += 1

            if found_column is False:
                merge_data['columns'].append( { 'title': title, 'main_icolumn': [icolumn], 'merge_icolumn': [] } )

            icolumn += 1

        #### Mix in the columns from the merge SDRF
        icolumn = 0
        for title in merge_sdrf.sdrf_data['titles']:
            iexisting_column = 0
            found_column = False
            for existing_column in merge_data['columns']:
                if title == existing_column['title']:
                    if 'merge_icolumn' in merge_data['columns'][iexisting_column]:
                        merge_data['columns'][iexisting_column]['merge_icolumn'].append(icolumn)
                    else:
                        merge_data['columns'][iexisting_column]['merge_icolumn'] = [icolumn]
                    found_column = True
                iexisting_column += 1

            if found_column is False and merge_empty_columns is True:
                merge_data['columns'].append( { 'title': title, 'merge_icolumn': [icolumn], 'main_icolumn': [] } )

            icolumn += 1


        #### Consider if we have when it takes for a data file level merge
        title = 'comment[data file]'
        potential_suffixes = [ '.raw', '.RAW', '', '.mzML', '.mzml', '.d', '.D', '.Raw', '.wiff', '.WIFF', '.mzXML', '.mzxml' ]
        previously_found_suffix = None
        merge_data['match_data'][title]['merge_leftover_values'] = merge_data['match_data'][title]['merge_values'].copy()
        merge_data['match_data'][title]['main_leftover_values'] = merge_data['match_data'][title]['main_values'].copy()
        merge_data['match_data'][title]['adjusted_merge_values'] = []

        for value in merge_data['match_data'][title]['merge_values']:
            #eprint(f"--Matching {value}")
            if value in merge_data['match_data'][title]['main_values']:
                del(merge_data['match_data'][title]['merge_leftover_values'][value])
            else:
                #### Try to match without filename suffixes
                match = re.match(r'(.+)\.(.+)?', value)
                if match:
                    value_root = match.group(1)
                    suffix = match.group(2)
                    #eprint(f"      (decomposed to '{value_root}' and '{suffix}')")
                    if previously_found_suffix is not None:
                        #eprint(f"  - Trying {value_root + previously_found_suffix}")
                        if value_root + previously_found_suffix in merge_data['match_data'][title]['main_values']:
                            #eprint(f"    + Found {value_root + previously_found_suffix}")
                            del(merge_data['match_data'][title]['merge_leftover_values'][value])
                            value = value_root + previously_found_suffix
                    else:
                        for potential_suffix in potential_suffixes:
                            #eprint(f"  - Trying {value_root + potential_suffix}")
                            if value_root + potential_suffix in merge_data['match_data'][title]['main_values']:
                                #eprint(f"    + Found {value_root + potential_suffix}")
                                del(merge_data['match_data'][title]['merge_leftover_values'][value])
                                previously_found_suffix = potential_suffix
                                value = value_root + potential_suffix
                                break
            merge_data['match_data'][title]['adjusted_merge_values'].append(value)

        previously_found_suffix = None
        for value in merge_data['match_data'][title]['main_values']:
            if value in merge_data['match_data'][title]['merge_values']:
                del(merge_data['match_data'][title]['main_leftover_values'][value])
            else:
                #### Try to match without filename suffixes
                match = re.match(r'(.+)(\.+)?', value)
                if match:
                    value_root = match.group(1)
                    suffix = match.group(2)
                    if previously_found_suffix is not None:
                        if value_root + previously_found_suffix in merge_data['match_data'][title]['merge_values']:
                            del(merge_data['match_data'][title]['main_leftover_values'][value])
                    else:
                        for potential_suffix in potential_suffixes:
                            if value_root + potential_suffix in merge_data['match_data'][title]['merge_values']:
                                del(merge_data['match_data'][title]['main_leftover_values'][value])
                                previously_found_suffix = potential_suffix
                                break

        if len(merge_data['match_data'][title]['merge_leftover_values']) == len(merge_data['match_data'][title]['merge_values']):
            self.log_problem('ERROR', 'MismatchedDataFiles', 0, 0, f"There appears to be no correlation between the values in '{title}' between the two files. Cannot merge")
            return

        if len(merge_data['match_data'][title]['merge_values']) != merge_sdrf.n_rows:
            self.log_problem('ERROR', 'UnableToMerge', 0, 0, f"The current merge strategy requires that the merge file have one row per 'comment[data file]' in the merge SDRF. This is not the case, so cannot proceed for now.")
            return

        #### Index the merge rows
        irow = 0
        join_row_keys = {}
        join_title = 'comment[data file]'
        icolumn = merge_data['match_data'][join_title]['merge_icolumn']
        for row in merge_sdrf.sdrf_data['rows']:
            #### Rewrite the merge column value in the merge data to match the main value for the merge column
            row[icolumn] = merge_data['match_data'][title]['adjusted_merge_values'][irow]
            value = row[icolumn]
            #value = merge_data['match_data'][title]['adjusted_merge_values'][irow]
            #eprint(f"%%%%  {irow}: {value}")
            join_row_keys[value] = irow
            irow += 1

        #### Create the final column title list for the merged result
        merged_data = { 'titles': [], 'rows': [] }
        for merged_column in merge_data['columns']:
            title = merged_column['title']
            if len(merged_column['main_icolumn']) == 1:
                merged_data['titles'].append(title)
            elif len(merged_column['main_icolumn']) == 0 and len(merged_column['merge_icolumn']) == 1:
                merged_data['titles'].append(title)
            elif len(merged_column['main_icolumn']) > 1:
                for icolumn in merged_column['main_icolumn']:
                    merged_data['titles'].append(title)
            elif len(merged_column['merge_icolumn']) > 1:
                for icolumn in merged_column['merge_icolumn']:
                    merged_data['titles'].append(title)
            else:
                eprint(f"ERROR: Unable to find a matching pattern in the number of columns for column label '{title}'")
                exit()

        #### Loop over all the rows and merge in the information
        irow = 0
        for row in self.sdrf_data['rows']:
            icolumn = 0
            new_row = []

            join_value = row[ merge_data['match_data'][join_title]['main_icolumn'] ]
            join_irow = join_row_keys[join_value]
            join_row = merge_sdrf.sdrf_data['rows'][join_irow]

            for merged_column in merge_data['columns']:
                title = merged_column['title']
                store_value = True
                if len(merged_column['main_icolumn']) == 1 and len(merged_column['merge_icolumn']) == 0:
                    value = row[merged_column['main_icolumn'][0]]
                    if tag_with_decisions:
                        value += "_onlyMain"
                elif len(merged_column['main_icolumn']) == 0 and len(merged_column['merge_icolumn']) == 1:
                    value = join_row[merged_column['merge_icolumn'][0]]
                    if tag_with_decisions:
                        value += "_onlyMerge"
                elif len(merged_column['main_icolumn']) == 1 and len(merged_column['merge_icolumn']) == 1:
                    main_value = row[merged_column['main_icolumn'][0]]
                    merge_value = join_row[merged_column['merge_icolumn'][0]]
                    if main_value == merge_value:
                        value = main_value
                        if tag_with_decisions:
                            value += "_same"
                    elif main_value == '' and merge_value > '':
                        value = merge_value
                        if tag_with_decisions:
                            value += "_mergeNonempty"
                    elif main_value > '' and merge_value == '':
                        value = main_value
                        if tag_with_decisions:
                            value += "_mainNonempty"
                    elif main_value == '' and merge_value == '':
                        value = main_value
                    else:
                        if title in prefer_main_columns:
                            value = main_value
                            if tag_with_decisions:
                                value += "_UserRequestKeepMain"
                            self.log_problem('WARNING', 'UserRequestKeepMain', irow + 1, icolumn + 1, f"For column '{title}', values in main ({main_value}) and merge ({merge_value}) differ. By user request, keeps the main.")
                        elif title == 'source name' and preserve_main_source_name:
                            value = main_value
                            if tag_with_decisions:
                                value += "_SpecialRuleKeepMain"
                            self.log_problem('WARNING', 'SpecialRuleKeepMain', irow + 1, icolumn + 1, f"For column '{title}', values in main ({main_value}) and merge ({merge_value}) differ. A special rule always keeps the main.")
                        else:
                            value = merge_value
                            if tag_with_decisions:
                                value += "_preferMergeOverMain"
                            self.log_problem('WARNING', 'MergeValueOverridesMain', irow + 1, icolumn + 1, f"For column '{title}', values in main ({main_value}) and merge ({merge_value}) differ. Value from merge ({merge_value}) supercedes.")
                elif len(merged_column['main_icolumn']) > 1:
                    for imulti_column in merged_column['main_icolumn']:
                        value = row[merged_column['merge_icolumn'][0]]
                        if tag_with_decisions:
                            value += '_multi'
                        new_row.append(value)
                    store_value = False
                else:
                    eprint(f"Ack. need to figure out what to do with {title} and {merged_column['main_icolumn']}")
                    exit()
                if store_value:
                    new_row.append(value)
                icolumn += 1
            merged_data['rows'].append(new_row)
            irow += 1

        self.sdrf_data = merged_data
        self.compute_stats()

        #print(json.dumps(merge_data, indent=2, sort_keys=True))
        return 'OK'



    ####################################################################################################
    #### Log a problem with the SDRF file
    def log_problem(self, status, code, line, column, message):

        category = 'UNKNOWN'
        if status == 'WARNING':
            category = 'warnings'
        elif status == 'ERROR':
            category = 'errors'
        else:
            eprint(f"FATAL ERROR: Unrecognized event status '{status}'")
            eprint(sys.exc_info())
            sys.exit()

        #### Record the event
        full_message = f"{status}: [{code}]: {message} at line {line}, column {column}"
        self.problems[category]['count'] += 1
        self.problems[category]['list'].append(full_message)
        if code not in self.problems[category]['codes']:
            self.problems[category]['codes'][code] = 1
        else:
            self.problems[category]['codes'][code] += 1

        if self.verbose >= 1:
            eprint(full_message)



    ####################################################################################################
    #### Write the SDRF file
    def write(self, filename):

        if self.sdrf_data is None:
            eprint(f"ERROR: SDRFData.write: No data matrix content to write to '{filename}'")
            return

        if self.verbose >= 1:
            eprint(f"INFO: Writing SDRF file '{filename}'")

        with open(filename, 'w') as outfile:
            title_list = [str(value) for value in self.sdrf_data['titles']]
            print("\t".join(title_list), file=outfile)
            for row in self.sdrf_data['rows']:
                value_list = [str(value) for value in row]
                print("\t".join(value_list), file=outfile)



####################################################################################################
#### Main function for command-line usage
def main():

    import requests
    import requests_cache
    requests_cache.install_cache('sdrf_files_requests_cache.sqlite')

    #### Parse command line arguments
    argparser = argparse.ArgumentParser(description='Handler for SDRF files')
    argparser.add_argument('--url', action='store', help='URL of an SDRF file to download and read/validate')
    argparser.add_argument('--filepath', action='store', help='File path of an SDRF file to read/validate')
    argparser.add_argument('--merge_url', action='store', help='URL of an SDRF file to download, read/validate, and merge into the main SDRF (from --url or --filepath)')
    argparser.add_argument('--merge_filepath', action='store', help='File path of an SDRF file to read/validate and merge into the main SDRF (from --url or --filepath)')
    argparser.add_argument('--output_filepath', action='store', help='File path to which to write the resulting SDRF')
    argparser.add_argument('--tag_with_decisions', action='count', help='If set during a merge operation, all values are appended with a decision tag to indicate how that value came about from the decision making. This would not be used in production, but can be useful to debugging or assessing how to set parameters.')
    argparser.add_argument('--show_result', action='count', help='Show the JSON output of the reading or merging process (with the actual table dumped to an auxiliary TSV file)')
    argparser.add_argument('--prefer_main_columns', action='store', help='Comma separated list of columns for which the main file values should be preferred over the merge values')
    argparser.add_argument('--verbose', action='count' )
    params = argparser.parse_args()

    #### Create metadata handler object and read or create the metadata structure
    sdrf = SDRFHandler(verbose=params.verbose)
    sdrf_cache_path = "sdrf_files"

    if params.url is None and params.filepath is None:
        eprint(f"ERROR: Either --url or --filepath must be provided. Use --help for more info")
        return

    if params.url is not None:
        sdrf.data_url = params.url
        sdrf.ui_url = params.url

        response = requests.get(params.url)
        if response.status_code != 200:
            eprint(f"ERROR: Failed to download {params.url}. Status code: {response.status_code}")
            return
        if not os.path.exists(sdrf_cache_path):
            os.mkdir(sdrf_cache_path)

        filename = sdrf.extract_filename(params.url)
        filepath = f"{sdrf_cache_path}/{filename}"
        with open(filepath, 'wb') as outfile:
            outfile.write(response.content)

    if params.filepath is not None:
        filepath = params.filepath
        if not os.path.exists(filepath):
            eprint(f"ERROR: Specified filepath '{filepath}' does not exist")
            return

    #### Read the input SDRF and perform some light validation on it
    sdrf.read(filepath)

    #### If there are no merge operations requested, then just show results if requested and return
    if params.merge_url is None and params.merge_filepath is None:
        if params.show_result:
            tmp = sdrf.__dict__.copy()
            tmp['sdrf_data'] = "SDRF data structure truncated for display simplicity. See sdrf_handler_show_result.sdrf.tsv for contents"
            del(tmp['verbose'])
            print(json.dumps(tmp, indent=2, sort_keys=True))
            sdrf.write('sdrf_handler_show_result.sdrf.tsv')
        return


    #### Create a second SDRF object for the file to merge into the first (main) one
    merge_sdrf = SDRFHandler(verbose=params.verbose)

    #### If there's a merge_url specified, fetch it and store it locally
    if params.merge_url is not None:
        merge_sdrf.data_url = params.merge_url
        merge_sdrf.ui_url = params.merge_url

        response = requests.get(params.merge_url)
        if response.status_code != 200:
            eprint(f"ERROR: Failed to download {params.merge_url}. Status code: {response.status_code}")
            return

        merge_filename = sdrf.extract_filename(params.merge_url)
        merge_filepath = f"{sdrf_cache_path}/{merge_filename}"
        if merge_filepath == filepath:
            merge_filepath += '_to_merge'
        with open(merge_filepath, 'wb') as outfile:
            outfile.write(response.content)

    #### If there a merge filepath specified, ensure that it exists
    if params.merge_filepath is not None:
        merge_filepath = params.merge_filepath
        if not os.path.exists(merge_filepath):
            eprint(f"ERROR: Specified merge_filepath '{merge_filepath}' does not exist")
            return

    #### Read the second SDRF that will be merged into the first
    merge_sdrf.read(merge_filepath)

    #### Perform the merge of the merge_sdrf into the main one, passing user params to guide merging
    sdrf.merge(merge_sdrf, tag_with_decisions=params.tag_with_decisions, prefer_main_columns=params.prefer_main_columns)

    #### If requested, write out the result
    if params.output_filepath:
        sdrf.write(params.output_filepath)

    #### If the user requested to see the result of reading and merging
    if params.show_result:
        tmp = sdrf.__dict__.copy()
        tmp['sdrf_data'] = "SDRF data structure truncated for display simplicity. See sdrf_handler_show_result.sdrf.tsv for contents"
        del(tmp['verbose'])
        print(json.dumps(tmp, indent=2, sort_keys=True))
        sdrf.write('sdrf_handler_show_result.sdrf.tsv')



if __name__ == "__main__": main()
