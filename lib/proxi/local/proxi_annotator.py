#!/usr/bin/env python3

import sys
import os.path
import json
import copy
def eprint(*args, **kwargs): print(*args, file=sys.stderr, **kwargs)

try:
    from proforma_peptidoform import ProformaPeptidoform
except:
    proxi_instance = os.environ.get('PROXI_INSTANCE')
    if proxi_instance:
        sys.path.append(f"/net/dblocal/data/SpectralLibraries/python/{proxi_instance}/SpectralLibraries/lib")
    else:
        #sys.path.append("C:\local\Repositories\GitHub\SpectralLibraries\lib")
        print("ERROR: Environment variable PROXI_INSTANCE must be set")
        exit()
    from proforma_peptidoform import ProformaPeptidoform


try:
    from spectrum_annotator import SpectrumAnnotator
    from spectrum import Spectrum
except:
    proxi_instance = os.environ.get('PROXI_INSTANCE')
    if proxi_instance:
        sys.path.append(f"/proteomics/sw/python/apps/RunAssessor/lib")
    else:
        #sys.path.append("C:\local\Repositories\GitHub\RunAssessor\lib")
        print("ERROR: Environment variable PROXI_INSTANCE must be set")
        exit()
    from spectrum_annotator import SpectrumAnnotator
    from spectrum import Spectrum


#### ProxiDatasets class
class ProxiAnnotator:

    #### Annotate the input list of spectra
    def annotate(self, input_list):
        #eprint("======= Received input spectra =========")
        #eprint(json.dumps(input_list, indent=2, sort_keys=True))
        #eprint("============================")

        response = {
            "annotated_spectra": [],
            "status": {
                "description": "Unknown error",
                "error_code": 'Unknown',
                "status": "ERROR",
                "status_code": 200,
                "log": []
                }
            }

        if not isinstance(input_list,list):
            response['status'] = {
                "description": "Input payload is not a list",
                "error_code": 'InputNotList',
                "status": "ERROR",
                "status_code": 400,
                "log": [ "Tested input payload and it appears to be type {type(input_list)}" ]
                }

        i_spectrum = 0
        for spectrum in input_list:
            i_spectrum += 1
            if not isinstance(spectrum, dict):
                response['log'].append(f"Entry {i_spectrum - 1} is not an object containing a spectrum")
                response['annotated_spectra'].append(None)
                continue
            if 'attributes' not in spectrum or 'mzs' not in spectrum or 'intensities' not in spectrum or spectrum['attributes'] is None or spectrum['mzs'] is None or spectrum['intensities'] is None:
                response['log'].append(f"Entry {i_spectrum - 1} does not have required (non-null) items 'attributes', 'mzs', 'intensities'")
                response['annotated_spectra'].append(None)
                continue

            peptidoform_string = None
            precursor_charge = None
            precursor_mz = None
            for attribute in spectrum['attributes']:
                if attribute['name'] == 'proforma peptidoform sequence' or attribute['accession'] == 'MS:1003169':
                    peptidoform_string = attribute['value']
                if attribute['name'] == 'charge state' or attribute['accession'] == 'MS:1000041':
                    precursor_charge = int(attribute['value'])
                if attribute['name'] == 'selected ion m/z' or attribute['accession'] == 'MS:1000827':
                    precursor_mz = float(attribute['value'])

            if peptidoform_string is None:
                response['log'].append(f"Entry {i_spectrum - 1} does not have required attribute MS:1003169 - 'proforma peptidoform sequence'")
                response['annotated_spectra'].append(None)
                continue

            if precursor_charge is None:
                response['log'].append(f"Entry {i_spectrum - 1} does not have required attribute MS:1000041 - 'charge state'")
                response['annotated_spectra'].append(None)
                continue

            #if precursor_mz is None:
            #    response['log'].append(f"Entry {i_spectrum - 1} does not have required attribute MS:1000827 - 'selected ion m/z'")
            #    response['annotated_spectra'].append(None)
            #    continue

            peptidoform = ProformaPeptidoform(peptidoform_string)
            #eprint("======= Interpreted peptidoform string =========")
            #eprint(json.dumps(peptidoform.to_dict(),indent=2))
            #eprint("============================")

            annotated_spectrum = Spectrum()
            annotated_spectrum.fill(mzs=spectrum['mzs'], intensities=spectrum['intensities'], precursor_mz=precursor_mz, charge_state=precursor_charge, usi_string=None)
            annotator = SpectrumAnnotator()
            annotator.annotate(annotated_spectrum, peptidoform=peptidoform, charge=precursor_charge)

            #print(annotated_spectrum.show())
            mzs, intensities, interpretations = annotated_spectrum.get_peaks()
            spectrum['mzs'] = mzs
            spectrum['intensities'] = intensities
            spectrum['interpretations'] = interpretations
            response['annotated_spectra'].append(spectrum)

        response['status'] = {
            "description": f"Attempted to annotate {i_spectrum} input spectra",
            "error_code": None,
            "status": "OK",
            "status_code": 200,
            "log": response['status']['log']
            }

        status_code = 200
        return(response, status_code)


#### If this class is run from the command line, perform a short little test to see if it is working correctly
def main():

    input_list = [
        {
            "attributes": [
            {
                "accession": "MS:1000827",
                "name": "selected ion m/z",
                "value": "767.9700"
            },
            {
                "accession": "MS:1000041",
                "name": "charge state",
                "value": "2"
            },
            {
                "accession": "MS:1003169",
                "name": "proforma peptidoform sequence",
                "value": "VLHPLEGAVVIIFK"
            }
            ],
            "intensities": [
            39316.4648,
            319.6931,
            1509.0269,
            104.0572,
            260.096,
            118.672,
            110.9478,
            101.2496,
            101.259,
            6359.8389
            ],
            "mzs": [
            110.0712,
            111.0682,
            111.0745,
            111.2657,
            112.087,
            115.0866,
            116.4979,
            118.0746,
            118.2988,
            120.0808
            ]
        }
    ]

    annotator = ProxiAnnotator()
    response = annotator.annotate( input_list )
    print(f"==== Response with status code {response[1]} =====")
    print(json.dumps(response[0],sort_keys=True,indent=2))
    print(f"===================================")

if __name__ == "__main__": main()
