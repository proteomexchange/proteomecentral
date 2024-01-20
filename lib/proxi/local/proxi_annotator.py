#!/usr/bin/env python3

import sys
import os.path
import json
from datetime import datetime
import traceback
def eprint(*args, **kwargs): print(*args, file=sys.stderr, **kwargs)

test_mode = False

try:
    from proforma_peptidoform import ProformaPeptidoform
except:
    proxi_instance = os.environ.get('PROXI_INSTANCE')
    if proxi_instance:
        sys.path.append(f"/net/dblocal/data/SpectralLibraries/python/{proxi_instance}/SpectralLibraries/lib")
    else:
        if test_mode:
            sys.path.append("C:\local\Repositories\GitHub\SpectralLibraries\lib")
        else:
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
        if test_mode:
            sys.path.append("C:\local\Repositories\GitHub\RunAssessor\lib")
        else:
            print("ERROR: Environment variable PROXI_INSTANCE must be set")
            exit()
    from spectrum_annotator import SpectrumAnnotator
    from spectrum import Spectrum



def update_response(response, status=None, status_code=None, error_code=None, description=None, log_entry=None):
    buffer = ''
    if status is not None:
        response['status']['status'] = status
        buffer += f"- status={status}"
    if status_code is not None:
        response['status']['status_code'] = status_code
        buffer += f"  - status_code={status_code}"
    if error_code is not None:
        response['status']['error_code'] = error_code
        buffer += f"  - error_code={error_code}"
    if description is not None:
        response['status']['description'] = description
        buffer += f"  - description={description}"
    if buffer != '':
        eprint(buffer)
    if log_entry is not None:
        if 'log' not in response['status']:
            response['status']['log'] = []
        datetime_now = str(datetime.now())
        response['status']['log'].append(f"{datetime_now}: {log_entry}")
        eprint(f"{datetime_now}: {log_entry}")


#### ProxiDatasets class
class ProxiAnnotator:

    #### Annotate the input list of spectra
    def annotate(self, input_list, resultType='compact', tolerance=None):
        eprint("======= Received input spectra =========")
        eprint(json.dumps(input_list, indent=2, sort_keys=True))
        eprint("============================")

        response = { 'status': {}, "annotated_spectra": [] }

        if tolerance is None:
            tolerance = 20.0

        if not isinstance(input_list, list):
            update_response(response, status='ERROR', status_code=400, error_code='InputNotList', description='Input payload is not a list',
                            log_entry=f"Tested input payload and it appears not to be the desired list, but rather of type {type(input_list)}")
            return(response, response['status']['status_code'])
        update_response(response, log_entry=f"Received input payload list of {len(input_list)} elements")

        update_response(response, log_entry=f"Starting annotation process with tolerance {tolerance} ppm")
        i_spectrum = 0
        n_spectra = len(input_list)
        n_annotated_spectra = 0
        for spectrum in input_list:
            i_spectrum += 1
            if not isinstance(spectrum, dict):
                update_response(response, log_entry=f"Entry {i_spectrum - 1} is not an object containing a spectrum")
                response['annotated_spectra'].append(None)
                continue
            if 'attributes' not in spectrum or 'mzs' not in spectrum or 'intensities' not in spectrum or spectrum['attributes'] is None or spectrum['mzs'] is None or spectrum['intensities'] is None:
                update_response(response, log_entry=f"Entry {i_spectrum - 1} does not have required (non-null) items 'attributes', 'mzs', 'intensities'")
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
                update_response(response, log_entry=f"Entry {i_spectrum - 1} does not have required attribute MS:1003169 - 'proforma peptidoform sequence'")
                response['annotated_spectra'].append(None)
                continue

            if precursor_charge is None:
                update_response(response, log_entry=f"Entry {i_spectrum - 1} does not have required attribute MS:1000041 - 'charge state'")
                response['annotated_spectra'].append(None)
                continue

            #if precursor_mz is None:
            #    response['log'].append(f"Entry {i_spectrum - 1} does not have required attribute MS:1000827 - 'selected ion m/z'")
            #    response['annotated_spectra'].append(None)
            #    continue

            if peptidoform_string == '':
                update_response(response, log_entry=f"WARNING: The 'proforma peptidoform sequence' for spectrum {i_spectrum - 1} is EMPTY. This is permitted and will result in a 'blind annotation', just labeling peaks that can be inferred in the absence of a know analyte. If this was not the intent, please provide a valid ProForma peptidoform")
                peptidoform = None
            else:
                update_response(response, log_entry=f"Parsing ProForma peptidoform '{peptidoform_string}' for spectrum {i_spectrum - 1}")
                peptidoform = ProformaPeptidoform(peptidoform_string)

            #eprint("======= Interpreted peptidoform string =========")
            #eprint(json.dumps(peptidoform.to_dict(),indent=2))
            #eprint("============================")

            update_response(response, log_entry=f"Annotating spectrum {i_spectrum - 1}")
            try:
                annotated_spectrum = Spectrum()
                annotated_spectrum.fill(mzs=spectrum['mzs'], intensities=spectrum['intensities'], precursor_mz=precursor_mz, charge_state=precursor_charge, usi_string=None)
                annotator = SpectrumAnnotator()
                annotator.annotate(annotated_spectrum, peptidoform=peptidoform, charge=precursor_charge, tolerance=tolerance)
                n_annotated_spectra += 1

            except Exception as error:
                exception_type, exception_value, exception_traceback = sys.exc_info()
                update_response(response, log_entry=f"Attempt to annotate spectrum {i_spectrum - 1} resulted in an error: {error}: {repr(traceback.format_exception(exception_type, exception_value, exception_traceback))}")

            #print(annotated_spectrum.show())
            mzs, intensities, interpretations = annotated_spectrum.get_peaks()
            spectrum['mzs'] = mzs
            spectrum['intensities'] = intensities
            spectrum['interpretations'] = interpretations
            if resultType == 'full':
                spectrum['extended_data'] = {}
                spectrum['extended_data']['metrics'] = annotated_spectrum.metrics
            response['annotated_spectra'].append(spectrum)

        if n_annotated_spectra > 0:
            update_response(response, status='OK', status_code=200, error_code=None, description=f"Successfully annotated {n_annotated_spectra} of {n_spectra} input spectra",
                            log_entry=f"Completed annotation process")
        else:
            update_response(response, status='ERROR', status_code=400, error_code='NoValidSpectra', description=f"Unable to annotate any of the {n_spectra} input spectra",
                            log_entry=f"Completed annotation process")

        return(response, response['status']['status_code'])


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
    response = annotator.annotate(input_list)
    print(f"==== Response with status code {response[1]} =====")
    print(json.dumps(response[0],sort_keys=True,indent=2))
    print(f"===================================")

if __name__ == "__main__": main()
