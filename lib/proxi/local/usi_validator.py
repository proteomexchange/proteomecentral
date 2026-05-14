#!/usr/bin/env python3

import sys
def eprint(*args, **kwargs): print(*args, file=sys.stderr, **kwargs)

import os
import argparse
import os.path
import re
import json
import ast

try:
    from universal_spectrum_identifier_validator import UniversalSpectrumIdentifierValidator
except:
    proxi_instance = os.environ['PROXI_INSTANCE']
    if not proxi_instance:
        print("ERROR: Environment variable PROXI_INSTANCE must be set")
        exit()
    sys.path.append(f"/net/dblocal/data/SpectralLibraries/python/{proxi_instance}/SpectralLibraries/lib")
    from universal_spectrum_identifier_validator import UniversalSpectrumIdentifierValidator


#### ProxiDatasets class
class UsiValidator:

    #### Validate the input list of USIs
    def validate(self, input_list):

        validator = UniversalSpectrumIdentifierValidator(input_list)        
        status_code = 200
        return(validator.response, status_code)


#### If this class is run from the command line, perform a short little test to see if it is working correctly
def main():

    usi_validator = UsiValidator()
    response = usi_validator.validate( [ 'mzspec:PXD001234:Dilution1:4:scan:10951' ] )
    print(json.dumps(response,sort_keys=True,indent=2))

if __name__ == "__main__": main()
