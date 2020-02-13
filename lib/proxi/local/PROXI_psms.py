#!/usr/bin/env python3 -u
import sys
def eprint(*args, **kwargs): print(*args, file=sys.stderr, **kwargs)
import os
import argparse
import os.path
import re
import sqlite3
import json
import ast

from response import Response

connection = None


#############################################################################
#### Ontology class
class PROXIPsms(object):


    #########################################################################
    #### Constructor
    def __init__(self):

        self.verbose = 0
        self.connection = sqlite3.connect('psms.sqlite')
        self.response = None


    #### Descructor
    def __del__(self):

        self.connection.close()


    ###############################################################################################################
    def query(self, resultType, pageSize = None, pageNumber = None, usi = None, accession = None, msrun = None, 
        fileName = None, scan = None, passThreshold = None, peptideSequence = None, proteinAccession = None, 
        charge = None, modification = None, peptidoform = None):

        #### Set up the response
        response = Response()
        self.response = response
        response.data['psms'] = []

        #### Evaluate the resultType
        if resultType != 'compact' and resultType != 'full':
            response.error(f"Parameter resultType number be either 'compact' or 'full'", error_code="InvalidResultType")
            return response

        #### Build some constraints
        constraints = ''
        n_constraints = 0
        if usi is not None:
            if "'" in usi:
                usi = re.sub(r"'","''",usi)
            constraints += f" AND usi='{usi}'"
            n_constraints += 1

        if accession is not None:
            if "'" in accession:
                accession = re.sub(r"'","''",accession)
            constraints += f" AND dataset_identifier='{accession}'"
            n_constraints += 1

        if msrun is not None:
            if "'" in msrun:
                msrun = re.sub(r"'","''",msrun)
            constraints += f" AND msrun_name='{msrun}'"
            n_constraints += 1

        if scan is not None:
            constraints += f" AND scan_number='{str(scan)}'"
            n_constraints += 1

        if charge is not None:
            constraints += f" AND charge='{str(charge)}'"
            n_constraints += 1

        if passThreshold is not None:
            if passThreshold is False:
                constraints += f" AND 0==1"

        if peptideSequence is not None:
            if "'" in peptideSequence:
                peptideSequence = re.sub(r"'","''",peptideSequence)
            constraints += f" AND peptide_sequence='{peptideSequence}'"
            n_constraints += 1

        if proteinAccession is not None:
            if "'" in proteinAccession:
                proteinAccession = re.sub(r"'","''",proteinAccession)
            constraints += f" AND protein_identifier='{proteinAccession}'"
            n_constraints += 1

        if peptidoform is not None:
            if "'" in peptidoform:
                peptidoform = re.sub(r"'","''",peptidoform)
            constraints += f" AND peptidoform='{peptidoform}'"
            n_constraints += 1

        if modification is not None:
            response.error(f"The modification parameter is currently not implemented at this endpoint", error_code="ModificationNotImplemented")
            n_constraints += 1
            return response

        #### Put in a check against a query that is ridiculous
        if n_constraints == 1 and charge is not None:
            response.error(f"Cannot fulfill a fetch where the only constraint is the charge state", error_code="InsufficientConstraints")
            return response


        column_names = [ 'dataset_identifier', 'msrun_name', 'scan_number', 'peptide_sequence', 'peptidoform', 'charge', 'protein_identifier', 'usi', 'probability' ]
        psm_keys = [ 'accession', None, None, 'peptideSequence', None, 'charge', 'proteinAccessions', 'usi', 'searchEngineScore' ]

        #### Make sure that some constraints were provided, or error out
        if constraints == '':
            response.error(f"No constraints were provided. Cannot fulfill unconstrained fetch of all PSMs.", error_code="NoConstraintsProvided")
            return response

        #### Build the LIMIT clause
        if pageSize is None:
            if pageNumber is None:
                limits = ''
            else:
                response.error(f"pageNumber with no pageSize is not valid", error_code="Missing pageSize")
                return response
        else:
            if pageNumber is None:
                limits = f"LIMIT {pageSize}"
            else:
                if pageNumber < 1:
                    pageNumber = 1
                startRow = (pageNumber - 1 ) * pageSize
                limits = f"LIMIT {pageSize} OFFSET {startRow}"

        #### Execute the database query and return the results
        response.info(f"Searching for PSMs with constraints {constraints}")
        constraints = f"1==1 {constraints}"
        cursor = self.connection.cursor()
        sql = f"SELECT * FROM psm WHERE {constraints} ORDER BY usi {limits}"
        response.info(f"Executing: {sql}")
        cursor.execute(sql)
        rows = cursor.fetchall()
        response.info(f"Found {len(rows)} PSMs")
        psms = []
        for row in rows:
            #print(row)

            #### If the resultType is compact, then we only encode the USI
            if resultType == 'compact':
                psms.append( { 'usi': row[7], 'peptideSequence': row[3] } )
                continue

            #### Otherwise 
            icol = 0
            psm = {}
            for column_name in column_names:
                value = row[icol]
                if psm_keys[icol] is None:
                    pass
                elif column_name == 'protein_identifier':
                    tmp = { 'proteinAccession': value, 'startPosition': -1, 'endPosition': -1 }
                    psm[psm_keys[icol]] = tmp
                elif column_name == 'probability':
                    pass
                else:
                    psm[psm_keys[icol]] = value
                icol += 1
            psms.append(psm)

        response.data['psms'] = psms
        return response



    ###############################################################################################################
    def build(self):

        dataset_identifiers = self.get_dataset_identifiers()
        iline = 0
        iprocessed = 0
        input_filename = 'PeptideAtlasInput_sorted.PAidentlist'

        eprint(f"INFO: Dropping and re-creating psm table")
        self.connection.execute("DROP TABLE IF EXISTS psm" )
        self.connection.execute("CREATE TABLE psm( dataset_identifier VARCHAR(50), msrun_name VARCHAR(100), scan_number int, peptide_sequence VARCHAR(100), peptidoform VARCHAR(255), " +
            "charge int, protein_identifier VARCHAR(100), usi VARCHAR(255), probability float)" )
        rows = []

        eprint(f"INFO: Reading {input_filename}")
        filesize = os.path.getsize(input_filename)
        bytes_processed = 0
        previous_percent_done = 0
        eprint(f"INFO: Input file is {filesize} bytes")

        with open(input_filename) as infile:
            for line in infile:
                bytes_processed += len(line)
                columns = re.split(r'\t',line.strip())
                iline += 1
                if columns[0] not in dataset_identifiers:
                    continue
                dataset_identifier = dataset_identifiers[columns[0]]

                #### Parse the spectrum name
                msrun_name = ''
                scan_number = -1
                charge = -1
                match = re.match(r'(.+)\.(\d+)\.(\d+)\.(\d+)$',columns[1])
                if match:
                    msrun_name = match.group(1)
                    scan_number = int(match.group(2))
                    charge = int(match.group(4))
                peptide_identifier = columns[2]
                peptide_sequence = columns[3]

                peptidoform = self.convert_peptidoform(columns[5])
                if peptidoform == '':
                    continue
                probability = float(columns[8])
                protein_identifier = columns[10]
                usi = f"mzspec:{dataset_identifier}:{msrun_name}:scan:{scan_number}:{peptidoform}/{charge}"

                #print('\t'.join([dataset_identifier,msrun_name,str(scan_number),peptide_sequence,str(charge),str(probability),peptidoform,protein_identifier]))
                row = [dataset_identifier, msrun_name, scan_number, peptide_sequence, peptidoform, charge, protein_identifier, usi, probability]
                rows.append(row)

                iprocessed += 1
                #### Commit every 10000 rows
                if iprocessed / 10000.0 == int(iprocessed/10000.0):
                    self.connection.executemany("INSERT INTO psm(dataset_identifier, msrun_name, scan_number, peptide_sequence, peptidoform, charge, " +
                        "protein_identifier, usi, probability) values (?,?,?,?,?,?,?,?,?)", rows)
                    self.connection.commit()
                    rows = []

                #### Print progress every 1%
                percent_done = int(bytes_processed / filesize * 100)
                if percent_done > previous_percent_done:
                    eprint(f"{percent_done}%.. ", end='')
                    previous_percent_done = percent_done

        #### Write out last batch
        eprint("done.")
        if len(rows) > 0:
            self.connection.executemany("INSERT INTO psm(dataset_identifier, msrun_name, scan_number, peptide_sequence, peptidoform, charge, " +
                "protein_identifier, usi, probability) values (?,?,?,?,?,?,?,?,?)", rows)
            self.connection.commit()

        #### Create some indexes
        column_names = [ 'dataset_identifier', 'msrun_name', 'scan_number', 'peptide_sequence', 'peptidoform', 'charge', 'protein_identifier', 'usi', 'probability' ]
        for column_name in column_names:
            eprint(f"INFO: Creating INDEX on {column_name}")
            self.connection.execute(f"CREATE INDEX idx_psm_{column_name} ON psm({column_name})")

        #### Print summary
        print(f"{iline} lines read from {input_filename}")
        print(f"{iprocessed} lines processed")

        


    ###############################################################################################################
    def get_dataset_identifiers(self):

        dataset_identifiers = {}
        with open("search_batch_id_to_datasets.tsv") as infile:
            for line in infile:
                columns = re.split(r'\t',line.strip())
                if len(columns) == 1:
                    continue
                match = re.search(r'(PXD\d+)',columns[1])
                if match:
                    dataset_identifiers[columns[0]] = match.group(1)

        #print(dataset_identifiers)
        #print(f"{len(dataset_identifiers)} search_batch_ids mapped")
        return dataset_identifiers


    ###############################################################################################################
    def convert_peptidoform(self,tpp_format_peptidoform):
        peptidoform = tpp_format_peptidoform
        peptidoform = re.sub(r'n\[145\]','[iTRAQ]-',peptidoform)
        peptidoform = re.sub(r'n\[230\]','[TMT6plex]-',peptidoform)
        peptidoform = re.sub(r'n\[305\]','[iTRAQ8plex]-',peptidoform)
        peptidoform = re.sub(r'C\[143\]','C[Pyro-cmC]',peptidoform)
        peptidoform = re.sub(r'C\[160\]','C[Carbamidomethyl]',peptidoform)
        peptidoform = re.sub(r'C\[330\]','C[ICAT_light]',peptidoform)
        peptidoform = re.sub(r'C\[339\]','C[ICAT_heavy]',peptidoform)
        peptidoform = re.sub(r'C\[553\]','C[AB_old_ICATd8]',peptidoform)
        peptidoform = re.sub(r'C\[174\]','C[Propionamide]',peptidoform)
        peptidoform = re.sub(r'C\[177\]','C[Propionamide:2H(3)]',peptidoform)
        peptidoform = re.sub(r'K\[272\]','K[iTRAQ]',peptidoform)
        peptidoform = re.sub(r'K\[357\]','K[TMT6plex]',peptidoform)
        peptidoform = re.sub(r'M\[147\]','M[Hydroxylation]',peptidoform)
        peptidoform = re.sub(r'R\[166\]','R[13C6-15N4]',peptidoform)
        match = re.search(r'([A-Za-z]\[\d+\])',peptidoform)
        if match:
            #print(f"Teach me how to transform {match.group(1)}")
            #sys.exit(1)
            peptidoform = ''
        return peptidoform



#########################################################################
#### A very simple example of using this class
def example_query1():

    psms = PROXIPsms()
    #response = psms.query(resultType='compact', accession='PXD000004', pageSize=3, pageNumber=1)
    #response = psms.query(resultType='full', msrun='R_072209_i010_HCD_A_SCX13')
    #response = psms.query(resultType='full', accession='PXD015901')
    response = psms.query(resultType='full', peptidoform='AAHEEIC[Carbamidomethyl]TTNEGVMYR')
    #response = psms.query(resultType='full', usi='mzspec:PXD005942:PSM1064_IK_181106_h_placenta_Cyto3_step03:scan:4789:AAHEEIC[Carbamidomethyl]TTNEGVMYR/2')
    #response = psms.query(resultType='full', proteinAccession='B7ZLE5')
    #response = psms.query(resultType='full', passThreshold=False)
    #response = psms.query(resultType='full', scan=3351)
    #response = psms.query(resultType='full', charge=2)
    #response = psms.query(resultType='full', charge=2, accession='PXD015901')
    print(response.show(level=Response.DEBUG))
    print(json.dumps(ast.literal_eval(repr(response.data['psms'])),sort_keys=True,indent=2))


#########################################################################
#### If class is run directly
def main():

    #### Parse command line options
    import argparse
    argparser = argparse.ArgumentParser(description='Primary interface to the ARAX system')
    argparser.add_argument('action', type=str, help='Action to take: build or query')
    params = argparser.parse_args()

    if params.action == 'build':
        psms = PROXIPsms()
        psms.build()
    elif params.action == 'query':
        example_query1()


if __name__ == "__main__": main()
