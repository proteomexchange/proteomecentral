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
    from universal_spectrum_identifier import UniversalSpectrumIdentifier
    from spectrum import Spectrum
    from spectrum_annotator import SpectrumAnnotator
    #from spectrum_sequencer import SpectrumSequencer
except:
    proxi_instance = os.environ.get('PROXI_INSTANCE')
    if proxi_instance:
        sys.path.append(f"/proteomics/sw/python/apps/quetzal-annotator/quetzal-annotator")
    else:
        if test_mode:
            sys.path.append("C:\local\Repositories\GitHub\quetzal-annotator\quetzal-annotator")
        else:
            print("ERROR: Environment variable PROXI_INSTANCE must be set")
            exit()
    from proforma_peptidoform import ProformaPeptidoform
    from universal_spectrum_identifier import UniversalSpectrumIdentifier
    from spectrum import Spectrum
    from spectrum_annotator import SpectrumAnnotator
    #from spectrum_sequencer import SpectrumSequencer



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
            create_peak_network = False

            #### Check if there's a usi provided, and if so, extract some default information from that
            if 'usi' in spectrum and spectrum['usi'] is not None and spectrum['usi'] != '':
                usi = UniversalSpectrumIdentifier()
                usi.parse(spectrum['usi'])
                precursor_charge = usi.charge
                if usi.peptidoform is not None:
                    peptidoform_string = usi.peptidoform['peptidoform_string']
                else:
                    peptidoform_string = ''

            #### Loop over attributes, extracting information from that
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

            if precursor_mz is None:
                update_response(response, log_entry=f"Entry {i_spectrum - 1} does not have the desirable attribute MS:1000827 - 'selected ion m/z' but will continue anyway without it")

            if peptidoform_string == '':
                update_response(response, log_entry=f"WARNING: The 'proforma peptidoform sequence' for spectrum {i_spectrum - 1} is EMPTY. This is permitted and will result in a 'blind annotation', just labeling peaks that can be inferred in the absence of a known analyte. If this was not the intent, please provide a valid ProForma peptidoform")
                peptidoform = None
            else:
                update_response(response, log_entry=f"Parsing ProForma peptidoform '{peptidoform_string}' for spectrum {i_spectrum - 1}")
                peptidoform = ProformaPeptidoform(peptidoform_string)

            #eprint("======= Interpreted peptidoform string =========")
            #eprint(json.dumps(peptidoform.to_dict(),indent=2))
            #eprint("============================")

            update_response(response, log_entry=f"Processing spectrum {i_spectrum - 1}")
            try:
                annotated_spectrum = Spectrum()
                interpretations = None
                if 'interpretations' in spectrum:
                    interpretations = spectrum['interpretations']
                annotated_spectrum.fill(mzs=spectrum['mzs'], intensities=spectrum['intensities'], interpretations=interpretations, precursor_mz=precursor_mz, charge_state=precursor_charge, usi_string=None, attributes=spectrum['attributes'])
                user_parameters = {}
                if 'extended_data' in spectrum and isinstance(spectrum['extended_data'],dict):
                    eprint("INFO-150: found extended_data in spectrum")
                    annotated_spectrum.extended_data = spectrum['extended_data']
                    if 'user_parameters' in annotated_spectrum.extended_data and isinstance(annotated_spectrum.extended_data['user_parameters'],dict):
                        user_parameters = annotated_spectrum.extended_data['user_parameters']
                    try:
                        create_peak_network = user_parameters['create_peak_network']
                    except:
                        create_peak_network = False

                annotator = SpectrumAnnotator()
                if 'skip_annotation' in user_parameters and user_parameters['skip_annotation']:
                    update_response(response, log_entry=f"- Skipping annotation by request")
                else:
                    update_response(response, log_entry=f"- Executing annotator on spectrum")
                    annotator.annotate(annotated_spectrum, peptidoforms=[peptidoform], charges=[precursor_charge], tolerance=tolerance)

                if ( 'create_svg' in user_parameters and user_parameters['create_svg'] ) or ( 'create_pdf' in user_parameters and user_parameters['create_pdf'] ):
                    update_response(response, log_entry=f"- Generating spectrum plot")
                    print(annotated_spectrum.extended_data)
                    annotator.plot(annotated_spectrum, peptidoform=peptidoform, charge=precursor_charge)

                if create_peak_network:
                    sequencing_parameters = {
                        'fragmentation_type': 'HCD',
                        'tolerance': 10.0,
                        'precursor_mz': precursor_mz,
                        'precursor_charge': precursor_charge,
                        'labels': []
                    }
                    #sequencer = SpectrumSequencer()
                    #sequencer.create_peak_network(annotated_spectrum, sequencing_parameters=sequencing_parameters)


                n_annotated_spectra += 1

            except Exception as error:
                exception_type, exception_value, exception_traceback = sys.exc_info()
                update_response(response, log_entry=f"- Attempt to annotate spectrum {i_spectrum - 1} resulted in an error: {error}: {repr(traceback.format_exception(exception_type, exception_value, exception_traceback))}")

            #print(annotated_spectrum.show())
            mzs, intensities, interpretations = annotated_spectrum.get_peaks()
            spectrum['mzs'] = mzs
            spectrum['intensities'] = intensities
            spectrum['interpretations'] = interpretations
            if resultType == 'full':
                if 'extended_data' not in spectrum or not isinstance(spectrum['extended_data'], dict):
                    spectrum['extended_data'] = {}
                if 'svg' in annotated_spectrum.extended_data:
                    spectrum['extended_data']['svg'] = annotated_spectrum.extended_data['svg']
                spectrum['extended_data']['metrics'] = annotated_spectrum.metrics
                if create_peak_network:
                    spectrum['extended_data']['network'] = annotated_spectrum.network
            response['annotated_spectra'].append(spectrum)

        if n_annotated_spectra > 0:
            update_response(response, status='OK', status_code=200, error_code=None, description=f"Successfully annotated {n_annotated_spectra} of {n_spectra} input spectra",
                            log_entry=f"Completed annotation process")
        else:
            update_response(response, status='ERROR', status_code=400, error_code='NoValidSpectra', description=f"Unable to annotate any of the {n_spectra} input spectra",
                            log_entry=f"Completed annotation process")

        #eprint("======= Annotated result =========")
        #eprint(json.dumps(response, indent=2, sort_keys=True))
        #eprint("============================")

        return(response, response['status']['status_code'])


#### If this class is run from the command line, perform a short little test to see if it is working correctly
def main():

    input_list = [
        {
            "attributes": [
                {
                "accession": "MS:1008025",
                "name": "scan number",
                "value": 19343
                },
                {
                "accession": "MS:1000827",
                "name": "isolation window target m/z",
                "value": 401.2628
                },
                {
                "accession": "MS:1000041",
                "name": "charge state",
                "value": 2
                },
                {
                "accession": "MS:1003061",
                "name": "spectrum name",
                "value": "LLSILSR/2"
                },
                {
                "accession": "MS:1003169",
                "name": "proforma peptidoform sequence",
                "value": "LLSILSR"
                }
            ],
            "intensities": [
                25679.1973,
                32007.0879,
                27618.2852,
                56783.7109,
                30913.8457,
                25987.8301,
                31703.4883,
                142053.4688,
                176166.5469,
                28250.5781,
                28694.4512,
                30808.9004,
                909449.6875,
                69067.8516,
                32153.8398,
                214112.3906,
                47653.3086,
                38805.7852,
                63561.7812,
                60056.1641,
                74805.0234,
                233378.7031,
                31245.2598,
                66539.4375,
                174329.375,
                30949.7793,
                186827.3594,
                2128354.0,
                119101.2656,
                83573.9922,
                86702.4844,
                37098.1367,
                478844.0938
            ],
            "mzs": [
                104.0084,
                108.1924,
                118.5454,
                129.1007,
                150.2932,
                155.4323,
                156.7006,
                173.128,
                175.1188,
                175.4851,
                180.3093,
                196.4062,
                199.1802,
                201.1224,
                210.8365,
                227.175,
                257.1603,
                296.1951,
                314.2058,
                323.9073,
                358.2076,
                375.2346,
                383.2175,
                401.2125,
                401.2846,
                450.4062,
                488.3182,
                575.3502,
                576.3517,
                585.3349,
                670.4265,
                678.9627,
                688.4347
            ],
            "interpretations": [    
                "?",                  
                "?",                  
                "?",                  
                "yow!"
                "?",                  
                "?",                  
                "?",                  
                "m2:3-CO/-2.6ppm",    
                "y1/-0.9ppm",         
                "?",                  
                "?",                  
                "?",                  
                "a2/-1.5ppm",         
                "m2:3/-4.8ppm",       
                "?",                  
                "b2/-1.8ppm",         
                "0@b2{KQ}/-2.0ppm",   
                "b3-H2O/-6.0ppm",     
                "b3/-5.2ppm",         
                "?",                  
                "y3-NH3/-2.5ppm",     
                "y3/-1.2ppm",         
                "?",                  
                "2@p/0.0ppm",         
                "3@p/0.0ppm",         
                "?",                  
                "y4/-1.9ppm",         
                "y5/-1.6ppm",         
                "y5+i/-3.2ppm",       
                "?",                  
                "y6-H2O/2.8ppm",      
                "?",                  
                "y6/-0.7ppm"          
            ],                      
            "extended_data": {
                "user_parameters": {
                    "create_svg": True,
                    "create_pdf": False,
                    "xmin": 300,
                    "xmax": 600,
                    "ymax": 2.0,
                    "skip_annotation": True
                }
            }
        }
    ]

    annotator = ProxiAnnotator()
    response = annotator.annotate(input_list)
    print(f"==== Response with status code {response[1]} =====")
    print(json.dumps(response[0],sort_keys=True,indent=2))
    print(f"===================================")

if __name__ == "__main__": main()
