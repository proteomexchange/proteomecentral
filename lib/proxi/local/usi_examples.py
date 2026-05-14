#!/usr/bin/env python3

import sys
def eprint(*args, **kwargs): print(*args, file=sys.stderr, **kwargs)

import os
import argparse
import os.path
import re
import json
import ast

#### ProxiDatasets class
class UsiExamples:

    #### Validate the input list of USIs
    def __init__(self):

        self.examples = None

        try:
            with open(os.path.dirname(os.path.abspath(__file__))+"/usi_examples.json") as infile:
                self.examples = json.load(infile)

        except:
            self.examples = [ { 'id': "ERROR", "usi": "ERROR: Unable to read examples registry" } ]


#### If this class is run from the command line, perform a short little test to see if it is working correctly
def main():

    usi_examples = UsiExamples()
    print(json.dumps(usi_examples.examples,sort_keys=True,indent=2))

if __name__ == "__main__": main()
