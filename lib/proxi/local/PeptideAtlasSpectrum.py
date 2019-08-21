#!/usr/bin/env python3

from __future__ import print_function
import sys
def eprint(*args, **kwargs):
    print(*args, file=sys.stderr, **kwargs)

import ast
import json

import os
import sys

sys.path.append(os.path.dirname(os.path.abspath(__file__))+"/../client/swagger_client")

from models.spectrum import Spectrum
from models.ontology_term import OntologyTerm

class PeptideAtlasSpectrum:

  #### Constructor
  def __init__(self):
    pass

  #### Destructor
  def __del__(self):
    pass

  #### Define attribute spectrum
  @property
  def spectrum(self) -> str:
    return self._spectrum

  @spectrum.setter
  def spectrum(self, spectrum: str):
    self._spectrum = spectrum


  #### Set the content to an example
  def setToExample(self):

    spectrum = Spectrum()
    spectrum.usi = "mzspec:PXD000561:Adult_Frontalcortex_bRP_Elite_85_f09:scan:17555:VLHPLEGAVVIIFK/2"
    spectrum.id = "238293"
    spectrum.attributes = [
      OntologyTerm("MS:1000744","selected ion m/z","473.1234"),
      OntologyTerm("MS:1000041","charge state","2"),
      OntologyTerm("MS:1000512","filter string","FTMS + p NSI d Full ms2 990.17@hcd28.00 [100.00-3050.00]"),
      OntologyTerm("MS:1009007","scan number","17555"),
      OntologyTerm("MS:1009004","molecular weight","902.1234"),
      OntologyTerm("MS:1000586","contact name","Sarah Bellum","11"),
      OntologyTerm("MS:1000590","contact affiliation","Higglesworth University","11")
    ]

    #spectrum.mzs = [ 147.1130, 567.3138 ]
    #spectrum.intensities = [ 500, 600.45 ]
    #spectrum.interpretations = [ "y1/1.3", "ib(PLEGAV)/0.2" ]

    spectrum.mzs = [ ]
    spectrum.intensities = [ ]
    spectrum.interpretations = [ ]
    fh = open("/net/dblocal/wwwspecial/proteomecentral/devED/lib/proxi/local/zzSpectrum.txt", 'r')
    for line in fh.readlines():
      columns = line.strip("\n").split()
      dummy = columns[0]
      mz = columns[0]
      intensity = columns[1]
      interpretations = columns[2]
      spectrum.mzs.append(mz)
      spectrum.intensities.append(intensity)
      spectrum.interpretations.append(interpretations)
    fh.close()

    self.spectrum = spectrum


  #### Print the contents of the spectrum object
  def show(self):
    print("Spectrum:")
    print(json.dumps(ast.literal_eval(repr(self.spectrum)),sort_keys=True,indent=2))


#### If this class is run from the command line, perform a short little test to see if it is working correctly
def main():

  paSpec = PeptideAtlasSpectrum()
  paSpec.setToExample()
  #paSpec.show()
  print(paSpec.spectrum)

if __name__ == "__main__": main()



