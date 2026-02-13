var _api = {};
_api['base_url'] = "/api/proxi/v0.1/";

var _done = 0;
var _dispec = null;

var _ion_list = ['a','b','c','x','y','z','I','prec','rep','int',"?",'other'];
var _totint;
var _totints;
var _coreints;
var _mzs = [];

var usi_data = {
    "iProX"           : { "url" : "https://www.iprox.cn/proxi/spectra?resultType=full&usi=" },
    "jPOST"           : { "url" : "https://repository.jpostdb.org/proxi/spectra?resultType=full&usi=" },
    "MassIVE"         : { "url" : "https://massive.ucsd.edu/ProteoSAFe/proxi/v0.1/spectra?resultType=full&usi=" ,
			  "view": "https://massive.ucsd.edu/ProteoSAFe/usi.jsp#{\"usi\":\"INSERT_USI_HERE\"}" },
    "PeptideAtlas"    : { "url" : "https://peptideatlas.org/api/proxi/v0.1/spectra?resultType=full&usi=" ,
			  "view": "https://db.systemsbiology.net/sbeams/cgi/PeptideAtlas/ShowObservedSpectrum?usi=INSERT_USI_HERE" },
    "PRIDE"           : { "url" : "https://www.ebi.ac.uk/pride/proxi/archive/v0.1/spectra?resultType=full&usi=" ,
			  "view": "https://www.ebi.ac.uk/pride/archive/spectra?usi=INSERT_USI_HERE" },
    "ProteomeCentral" : { "url" : _api['base_url'] + "spectra?resultType=full&usi=" },
    "MS2PIP"          : { "url" : _api['base_url'] + "spectra?resultType=full&accession=MS2PIP&msRun=INSERT_MODELNAME_HERE&usi=",
                          "view": "https://compomics.github.io/projects/ms2pip" },
    "KOINA"           : { "url" : "https://koina.wilhelmlab.org/v2/models/INSERT_MODELNAME_HERE/infer",
                          "view": "https://koina.wilhelmlab.org/" }
};

// override for quick testing:
if (0) {
    usi_data = {
	"PeptideAtlas" : { "url" : "https://peptideatlas.org/api/proxi/v0.1/spectra?resultType=full&usi=" ,
			   "view": "https://db.systemsbiology.net/sbeams/cgi/PeptideAtlas/ShowObservedSpectrum?usi=INSERT_USI_HERE" }
    };
}

var isobaric_unimods = [ "UNIMOD:214", "UNIMOD:532", "UNIMOD:533", "UNIMOD:730", "UNIMOD:731", "UNIMOD:737", "UNIMOD:738", "UNIMOD:739", "UNIMOD:889", "UNIMOD:984", "UNIMOD:985", "UNIMOD:1341", "UNIMOD:1342", "UNIMOD:2015", "UNIMOD:2016", "UNIMOD:2017", "UNIMOD:2050" ];

var _peptidoforms = null;

function init() {
    fetch("./proxi_config.json")
        .then(response => response.json())
        .then(config => {
            if (config.API_URL) {
		_api['validate'] = config.API_URL +"usi_validator";
		_api['examples'] = config.API_URL +"usi_examples";
		_api['annotate'] = config.API_URL +"annotate";
		for (var src of ["ProteomeCentral", "MS2PIP"])
		    if (usi_data[src])
			usi_data[src].url = usi_data[src].url.replace(_api['base_url'], config.API_URL);
	    }
	    init2();
            if (config.SpecialWarning)
                pc_displaySpecialWarning(config.SpecialWarning);
        })
        .catch(error => {
            _api['validate'] = _api['base_url'] + "usi_validator";
            _api['examples'] = _api['base_url'] + "usi_examples";
            _api['annotate'] = _api['base_url'] + "annotate";
            init2();
        });
}

function init2() {
    tpp_dragElement(document.getElementById("quickplot"));
    list_recent_usis(10);

    const params = new URLSearchParams(window.location.search);
    if (params.has('usi')) {
	document.getElementById("usi_input").value = params.get('usi');
	check_usi();
    }
    //retrieve_example_usis();
}

function stripSpaces() {
    document.getElementById("usi_input").value = document.getElementById("usi_input").value.replace(/\s+/g, "").trim();
    testUSI();
}


function testUSI() {
    clear_element("main");

    var usi = document.getElementById("usi_input").value.trim();
    if (usi == "") return;

    if (/\s/.test(usi)) {
        var txt = document.createElement("h2");
	txt.className = "invalid";
	txt.style.marginBottom = "0";
        txt.append("WARNING");
        document.getElementById("main").append(txt);

        txt = document.createElement("h4");
	txt.className = "invalid";
	txt.style.marginTop = "0";
        txt.append("There is a [space] character in your USI! This might possibly be appropriate if the MS Run file name has a space in it, but usually this is the result of a copy-paste problem of a USI that was line wrapped in a document or email.");
	txt.append(document.createElement("br"));
        txt.append("Click [strip spaces] above to remove all spaces from your USI.");
        document.getElementById("main").append(txt);
    }

}


async function validate_usi(carryon) {
    document.getElementById("usi_input").value = document.getElementById("usi_input").value.trim();
    var usi = document.getElementById("usi_input").value;
    if (usi == "") return;

    clear_element("main");
    clear_element("spec");
    clear_element("annot");
    toggle_box("quickplot",false,true);
    for (var p in usi_data)
	usi_data[p].lori_data = null;

    var response = await fetch(_api['validate'], {
	method: 'post',
	headers: {
	    'Accept': 'application/json',
	    'Content-Type': 'application/json'
	},
	body: "["+JSON.stringify(usi)+"]" 
    });
    var data = await response.json();

    if (data.error_code != "OK") {
	document.getElementById("main").innerHTML += "<h1 class='rep title'>API error :: " + data.error_message + "</h1>";
	return false;
    }

    if (data.validation_results[usi]["is_valid"] == true) {
        if (data.validation_results[usi]["peptidoforms"] &&
	    data.validation_results[usi]["peptidoforms"].length > 0) {
	    _peptidoforms = JSON.parse(JSON.stringify(data.validation_results[usi]["peptidoforms"])); // cheap dirty clone
	}


	if (carryon) {
	    if (data.validation_results[usi]["collection_type"] == 'placeholder') {
                displayMsg("spec","WARNING: The USI you have entered uses the placeholder collection identifier of USI000000. This means that the creator of the USI used this placeholder instead of a public collection identifier such as PXD012345. In order for the USI resolution to work, you will need to find the correct dataset/collection identifier for the dataset you wish to access, and replace the USI000000 with the correct collection identifier.");
		return false;
	    }
	    return true;
	}

	var txt = document.createElement("h2");

	txt.className = "valid";
	txt.style.marginBottom = "0";
	txt.append("VALID SYNTAX");
	document.getElementById("main").append(txt);

	txt = document.createElement("h4");
        txt.className = "valid";
	txt.style.marginTop = "0";
	txt.append("The syntax of this USI is valid, although it may not be resolvable at any resource");
	document.getElementById("main").append(txt);
    }
    else {
        var txt = document.createElement("h2");
	txt.className = "invalid";
	txt.style.marginBottom = "0";
        txt.append("INVALID");
        document.getElementById("main").append(txt);

        txt = document.createElement("h4");
	txt.className = "invalid";
	txt.style.marginTop = "0";
        txt.append(data.validation_results[usi]["error_message"]);
        document.getElementById("main").append(txt);
    }

    var txt = document.createElement("span");
    txt.className = "smgr";
    txt.style.cursor = "pointer";
    txt.append("[ show / hide details ]");
    txt.setAttribute('onclick', 'shta("usideets");');

    document.getElementById("main").append(txt);

    var table = document.createElement("table");
    table.id = "usideets";
    table.className = "prox";
    table.style.display = "none";

    var tr = document.createElement("tr");
    var td = document.createElement("td");
    td.className = "rep";
    td.colSpan = 2;
    td.append(usi);
    tr.append(td);
    table.append(tr);

    add_spec_data(table, '', data.validation_results[usi]);

    tr = document.createElement("tr");
    td = document.createElement("td");
    td.className = "rep";
    td.colSpan = 2;
    td.append('JSON response');
    tr.append(td);
    table.append(tr);

    tr = document.createElement("tr");
    td = document.createElement("td");
    td.colSpan = 2;
    td.style.fontFamily = 'monospace';
    td.style.whiteSpace = 'pre';
    td.append(JSON.stringify(data.validation_results[usi],null,2));
    tr.append(td);
    table.append(tr);

    show_validation_code(table,usi);

    document.getElementById("spec").append(table);

    return false;
}

// assumes:
// - [residues] ordered by position in sequence: Nterm,1,2,3,...n,Cterm
// - modification_curie is of type UNIMOD
function get_curie_peptidoform(pform_object) {
    if (!pform_object.residues)
	return null;

    var pstring = "";
    for (var res of pform_object.residues) {

	if (res.base_residue) {
	    if (res.base_residue == 'cterm')
		pstring += '-';
	    else if (res.base_residue != 'nterm')
		pstring += res.base_residue;
	}
	else
            pstring += res.residue_string;

	if (res.modification_curie)
            pstring += '['+res.modification_curie+']';

        if (res.base_residue && res.base_residue == 'nterm')
            pstring += '-';
    }

    return pstring;
}


function show_validation_code(table,usi) {
    var tr = document.createElement("tr");
    var td = document.createElement("td");
    td.className = "rep";
    td.colSpan = 2;
    td.append('Linux curl snippet');
    tr.append(td);
    table.append(tr);
    tr = document.createElement("tr");
    td = document.createElement("td");
    td.colSpan = 2;
    td.style.fontFamily = 'monospace';
    td.style.whiteSpace = 'pre';
    td.append("curl -X POST -H \"Content-Type: application/json\" https://proteomecentral.proteomexchange.org/api/proxi/v0.1/usi_validator -d '[ \""+usi+"\" ]'");
    tr.append(td);
    table.append(tr);

    tr = document.createElement("tr");
    td = document.createElement("td");
    td.className = "rep";
    td.colSpan = 2;
    td.append('Windows curl snippet');
    tr.append(td);
    table.append(tr);
    tr = document.createElement("tr");
    td = document.createElement("td");
    td.colSpan = 2;
    td.style.fontFamily = 'monospace';
    td.style.whiteSpace = 'pre';
    td.append("curl -X POST -H \"Content-Type: application/json\" https://proteomecentral.proteomexchange.org/api/proxi/v0.1/usi_validator -d \"[ \\\""+usi+"\\\" ]\"");
    tr.append(td);
    table.append(tr);

    tr = document.createElement("tr");
    td = document.createElement("td");
    td.className = "rep";
    td.colSpan = 2;
    td.append('Python snippet');
    tr.append(td);
    table.append(tr);
    tr = document.createElement("tr");
    td = document.createElement("td");
    td.colSpan = 2;
    td.style.fontFamily = 'monospace';
    td.style.whiteSpace = 'pre';
    td.append("import json\nimport requests\n\nusis = [ \""+usi+"\", \"not a USI\" ]\nendpoint_url = \"https://proteomecentral.proteomexchange.org/api/proxi/v0.1/usi_validator\"\nresponse_content = requests.post(endpoint_url, json=usis, headers={'accept': 'application/json'})\nresult = response_content.json()\nprint(json.dumps(result, indent=2))\nfor usi in usis:\n  print(result['validation_results'][usi]['is_valid'],\"\\t\",usi)\n");
    tr.append(td);
    table.append(tr);
}

function add_spec_data(table,label,vdata) {
    for (var f in vdata) {
	if (typeof vdata[f] === 'object') {
	    add_spec_data(table, label+' { '+f+' } ', vdata[f]);
	    continue;
	}
	if (f.startsWith("_"))
	    continue;

        var tr = document.createElement("tr");
        var td = document.createElement("th");
        td.append(label+f);
        tr.append(td);

        td = document.createElement("td");
        td.append(vdata[f]);
        tr.append(td);
        table.append(tr);
    }

}


async function check_usi() {
    document.getElementById("usi_input").value = document.getElementById("usi_input").value.trim();
    var usi = document.getElementById("usi_input").value;
    if (usi == "") return;

    _peptidoforms = null;
    var valid = await validate_usi(true);
    if (!valid) return;

    render_tables(usi);
    clear_element("spec");
    clear_element("annot");
    toggle_box("quickplot",false,true);
    document.getElementById("usi_stat").classList.add("running");

    _done = 0;
    _dispec = null;
    get_usi_from(null);
}

async function fetch_spectrum(who, usi) {
    var url = usi_data[who].url;
    // for MS2PIP and KOINA
    if (document.getElementById(who+"_model"))
        url = url.replace('INSERT_MODELNAME_HERE', document.getElementById(who+"_model").value);

    if (who == 'KOINA') {
	var request = { "id":  "0", "inputs": [] };
	var input = {"name": "peptide_sequences", "shape": [1,1], "datatype": "BYTES", "data": [get_curie_peptidoform(_peptidoforms[0])]};
	request.inputs.push(input);
	input ={"name": "precursor_charges", "shape": [1,1], "datatype": "INT32", "data": [_peptidoforms[0].charge]};
	request.inputs.push(input);

	if (document.getElementById(who+"_model_ce")) {
	    var ce = parseFloat(0+document.getElementById(who+"_model_ce").value.trim());
            input ={"name": "collision_energies", "shape": [1,1], "datatype": "FP32", "data": [ce]};
	    document.getElementById(who+"_model_ce").value = ce;
            request.inputs.push(input);
	}
        if (document.getElementById(who+"_model_frag")) {
            input ={"name": "fragmentation_types", "shape": [1,1], "datatype": "BYTES", "data": [document.getElementById(who+"_model_frag").value]};
            request.inputs.push(input);
        }
        if (document.getElementById(who+"_model_instr")) {
            input ={"name": "instrument_types", "shape": [1,1], "datatype": "BYTES", "data": [document.getElementById(who+"_model_instr").value]};
            request.inputs.push(input);
        }

	var savedResponse; // keep original to pass back after modifying

	return fetch(url, {
            method: 'post',
            headers: {
		'Accept': 'application/json',
		'Content-Type': 'application/json'
            },
            body: JSON.stringify(request)
	})
	    .then(response => {
		if (!response.ok)
		    throw new Error(`HTTP error! status: ${response.status}`);
		savedResponse = response.clone();
		return response.json();
	    })
            .then(koina_data => {
		if (koina_data.error)
                    throw "Server Error :: " + koina_data.error;
		else if (!koina_data.outputs)
                    throw "No 'outputs' element in response!";

		try {
		    var specdata = {};
		    specdata.attributes = [];
		    for (var field of ['model_name', 'model_version']) {
			var att = {};
			att.name = field;
			att.accession = '---';
			att.value = koina_data[field];
			specdata.attributes.push(att);
		    }

		    for (var out of koina_data.outputs) {
			if (out.name == 'mz')
			    specdata.mzs = out.data;
			if (out.name == 'intensities')
			    specdata.intensities = out.data;
		    }

		    if (document.getElementById("KOINA_model_submit"))
			pc_addCheckBox(document.getElementById("KOINA_model_submit"),true);

		    return new Response(JSON.stringify([specdata]), {
			status: savedResponse.status,
			statusText: savedResponse.statusText,
			headers: savedResponse.headers // Use original headers
		    });

		}
		catch (e) {
                    throw "error: "+e;
		}
            })
            .catch(error => {
		var reply = {};
		reply.detail = "Error with KOINA ::"+error;
		reply.status = 400;
		reply.title = "Error calling KOINA";
		reply.type = "about:blank";
		return reply;
	    });

    }
    else {
	url += encodeURIComponent(usi);
	var ccell = document.getElementById(who+"_msg");
	ccell.title = "view raw response from API";
	ccell.setAttribute('onclick', 'window.open("'+url+'");');
	ccell.style.cursor = "pointer";
	return fetch(url);
    }
}

function get_usi_from(where=null) {
    if (!where) {
	where = Object.keys(usi_data);
	var i = where.indexOf("MS2PIP");
	if (i > -1)
	    where.splice(i, 1);
	i = where.indexOf("KOINA");
        if (i > -1)
            where.splice(i, 1);
    }

    const usi = document.getElementById("usi_input").value;
    for (let p of where) {
	var rcode = -1;
	fetch_spectrum(p, usi)
            .then(response => {
                //console.log(p+" RESPONSE: "+response);
		rcode = response.status; // must capture it before json parsing
		//console.log(p+" CODE: "+rcode);
		try   { return response.json(); }
		catch { return response; }
	    })
            .then(alldata => {
		if (p == "ProteomeCentral") {
		    get_usi_from(["MS2PIP"]);
		    get_usi_from(["KOINA"]);
		}
		try {
		    _done++;
		    if (_done == Object.keys(usi_data).length) {
			document.getElementById("usi_stat").classList.remove("running");
			if (!_dispec)
			    displayMsg("spec","USI not found at the requested repositories!");
		    }
                    var cell = document.getElementById(p+"_msg");
                    cell.title += " (Code:"+rcode+")";
		    cell.classList.add("code"+rcode);

                    if (rcode != 200) {
			cell.innerHTML = alldata.title;
			document.getElementById(p+"_spectrum").innerHTML = "n/a";
			console.log("[DEBUG] "+p+" said: "+alldata.status+"/"+alldata.title+"//"+alldata.detail);

			document.getElementById(p+"_atts").innerHTML = "-";
			document.getElementById(p+"_json").innerHTML = "-";
			document.getElementById(p+"_reannot").innerHTML = "";
			return;
                    }
                    cell.innerHTML = "OK";

		    var data = alldata[0]; // just consider the first one  FIXME??

		    usi_data[p].usi_data = data;

                    cell = document.getElementById(p+"_atts");
                    cell.className = "smgr";
		    if (data && data.attributes) {
			cell.title = "view attributes for this spectrum";
			cell.setAttribute('onclick', 'viewAtts("spec","'+p+'");');
			cell.innerHTML = "[ VIEW ]";
		    }
		    else
			cell.innerHTML = "";

                    cell = document.getElementById(p+"_json");
                    cell.className = "smgr";
		    cell.title = "view JSON response";
		    cell.setAttribute('onclick', 'viewJSON("spec","'+p+'");');
                    cell.innerHTML = "[ JSON ]";

                    cell = document.getElementById(p+"_reannot");
                    cell.className = "smgr";
		    if (p != "MS2PIP" && p != "KOINA" && data) {
			cell.title = "Re-annotate peaks using data from this response";
			cell.setAttribute('onclick', 'reannotate_peaks("'+p+'");');
			cell.innerHTML = "[ A ]";
		    }
		    else
                        cell.innerHTML = "";

		    var s = {};
                    s.scanNum = 0;
                    s.precursorMz = 0;
                    s.fileName = p+" spectrum";
		    s.mzError = 20;
		    s.mzUnits = 'ppm';
		    s.showA = [1,0,0];
		    s.peakDetect = false;
                    s.ms2peaks = [];
		    s.pforms = [];

		    var has_spectrum = false;
		    var maxMz = 1999.0;

		    if (!data || !data.mzs || !data.intensities)
			throw "Incomplete spectrum data!";

		    if (!isSorted(data.mzs)) {
			console.log(p+" data NOT sorted :: attempting to sort...");
			var sorted = sortLinkedArrays(data.mzs,data.intensities);
			data.mzs = sorted[0];
			data.intensities = sorted[1];
			console.log(p+" data re-sorted OK");
		    }

                    for (var i in data.mzs) {
                        var usipeaks = [Number(data.mzs[i]), Number(data.intensities[i])];
			if (usipeaks[0] < 0)
			    usipeaks[0] = 0;
			if (usipeaks[1] < 0)
			    usipeaks[1] = 0;
                        s.ms2peaks.push(usipeaks);
			if (Number(data.mzs[i]) > maxMz) maxMz = Number(data.mzs[i]);
			has_spectrum = true;
                    }
		    s.minDisplayMz = 0.01;
                    s.maxDisplayMz = maxMz+1.0;

		    if (_peptidoforms) {
			for (var pi in _peptidoforms) {
			    s.pforms[pi] = {};
			    s.pforms[pi].peptidoform = _peptidoforms[pi].peptidoform_string;
			    s.pforms[pi].sequence = _peptidoforms[pi].peptide_sequence;
			    s.pforms[pi].fileName = _peptidoforms[pi].peptidoform_string;
			    s.pforms[pi].charge   = _peptidoforms[pi].charge;
			    s.pforms[pi].ntermMod = 0;
			    s.pforms[pi].ctermMod = 0;
			    s.pforms[pi].reporterIons = false;
			    s.pforms[pi].variableMods = [];
			    s.pforms[pi].labileModSum = 0;
			    s.pforms[pi].maxNeutralLossCount = 1;

			    for (var mod in _peptidoforms[pi]["terminal_modifications"]) {
				if (_peptidoforms[pi]["terminal_modifications"][mod].labile_delta_mass &&
				    _peptidoforms[pi]["terminal_modifications"][mod].labile_delta_mass > 0) {
				    s.pforms[pi].labileModSum += _peptidoforms[pi]["terminal_modifications"][mod].labile_delta_mass;
				    continue;
				}

				if (_peptidoforms[pi]["terminal_modifications"][mod].base_residue == "nterm") {
				    s.pforms[pi].ntermMod = _peptidoforms[pi]["terminal_modifications"][mod].delta_mass;
				    if (isobaric_unimods.includes(_peptidoforms[pi]["terminal_modifications"][mod].modification_curie))
					s.pforms[pi].reporterIons = true;
				}
				else if (_peptidoforms[pi]["terminal_modifications"][mod].base_residue == "cterm")
				    s.pforms[pi].ctermMod = _peptidoforms[pi]["terminal_modifications"][mod].delta_mass;
				else
				    console.warn("[WARN] Invalid mod terminus; ignoring...");
			    }
			    for (var mod in _peptidoforms[pi]["residue_modifications"]) {
				if (_peptidoforms[pi]["residue_modifications"][mod].labile_delta_mass &&
				    _peptidoforms[pi]["residue_modifications"][mod].labile_delta_mass > 0) {
				    s.pforms[pi].labileModSum += _peptidoforms[pi]["residue_modifications"][mod].labile_delta_mass;
				    continue;
				}

				var varmod  = {};
				varmod.index     = _peptidoforms[pi]["residue_modifications"][mod].index;
				varmod.modMass   = _peptidoforms[pi]["residue_modifications"][mod].delta_mass;
				varmod.aminoAcid = _peptidoforms[pi]["residue_modifications"][mod].base_residue;
				if (Math.abs(varmod.modMass-79.966331) < 0.01) {  //Phos
				    varmod.losses = [];
				    var loss = {};
				    loss.monoLossMass = 97.976896;
				    loss.avgLossMass  = 97.9952;
				    loss.formula      = 'H3PO4';
				    loss.label        = 'p';
				    varmod.losses.push(loss);
                                    loss = {};
                                    loss.monoLossMass = 79.966331;
                                    loss.avgLossMass  = 79.9799;
                                    loss.formula      = 'HPO3';
                                    varmod.losses.push(loss);
				    s.pforms[pi].maxNeutralLossCount++;
				}
				else if (varmod.aminoAcid == "M" && (Math.abs(varmod.modMass-15.9949) < 0.01)) {  //Ox
				    varmod.losses = [];
				    var loss = {};
				    loss.monoLossMass = 63.998285;
				    loss.avgLossMass  = 64.11;
				    loss.formula      = 'CH3SOH';
				    varmod.losses.push(loss);
				    s.pforms[pi].maxNeutralLossCount++;
				}
				else if ((varmod.aminoAcid == "S" || varmod.aminoAcid == "T") && (Math.abs(varmod.modMass-27.9949) < 0.01)) {  //Formyl
				    varmod.losses = [];
				    var loss = {};
				    loss.monoLossMass = 27.9949;
				    loss.avgLossMass  = 28.0101;
				    loss.formula      = 'CO';
				    varmod.losses.push(loss);
				    s.pforms[pi].maxNeutralLossCount++;
				}

				s.pforms[pi].variableMods.push(varmod);
			    }
                            for (var mod in _peptidoforms[pi]["unlocalized_mass_modifications"]) {
				s.pforms[pi].labileModSum += _peptidoforms[pi]["unlocalized_mass_modifications"][mod].delta_mass;
			    }
			}
		    } // if (_peptidoforms)

		    if (data && data.attributes && data.attributes.length>0) {
			for (var att of data.attributes) {
			    if (att.accession == "MS:1000744") s.precursorMz = att.value;  // preferred
			    if (att.accession == "MS:1000827" && s.precursorMz == 0) s.precursorMz = att.value;

                            if (att.accession == "MS:1008025") s.scanNum     = att.value;
                            if (att.accession == "MS:1000041") s.charge      = att.value;
                            if (att.accession == "MS:1000888") s.sequence    = att.value;
                            if (att.accession == "MS:1003061") s.fileName    = att.value;
                            if (att.accession == "MS:10000512" &&
				att.value.startsWith("ITMS")) {
				s.mzError = 0.6;
				s.mzUnits = 'Th';
				s.showA = [0,0,0];
				s.peakDetect = true;
			    }
			}
		    }
		    if (p == "MS2PIP" || p == "KOINA")
			s.fileName = "PREDICTED SPECTRUM FOR: "+s.fileName;

		    if (has_spectrum) {
			pc_addRecentItem("USI",usi);
			list_recent_usis(10);

			usi_data[p].lori_data = s;

			var cell = document.getElementById(p+"_spectrum");
			cell.style.fontWeight = "bold";
			cell.innerHTML = "";

			if (usi_data[p].lori_data.pforms.length > 0) {
			    for(var pf in usi_data[p].lori_data.pforms) {
				var link = document.createElement("span");
				link.style.padding = "5px";
				link.title = "view matched spectrum";

				link.setAttribute('onclick', 'renderLorikeet("spec",'+pf+',"'+p+'");');
				link.innerHTML = usi_data[p].lori_data.pforms[pf].peptidoform;
				cell.append(link);
			    }
			}
			else {
			    cell.title = "view uninterpreted spectrum";
			    cell.setAttribute('onclick', 'renderLorikeet("spec",null,"'+p+'");');
			    cell.innerHTML = s.fileName;
			}

			if(!_dispec && !s.fileName.startsWith("PREDICTED")) {
			    _dispec = p;
			    renderLorikeet("spec",usi_data[p].lori_data.pforms[0]?0:null,p);
			    annotate_peaks(data,usi_data[p].lori_data.pforms[0].peptidoform);
			}
			else if (_dispec == '---refresh---') {
                            _dispec = p;
                            renderLorikeet("spec",0,p);
			}
			else {
                            var curr = document.getElementById(p+"_current");
			    curr.title = "view as butterfly (mirror) spectrum";
			    curr.setAttribute('onclick', 'renderLorikeet("spec",0,"'+_dispec+'","'+p+'");');
			    curr.style.cursor = "pointer";
			    curr.innerHTML = "&#8853;";
			}
		    }
		    else {
			usi_data[p].lori_data = {};
			document.getElementById(p+"_spectrum").innerHTML = "-none!-";
		    }

		} catch(err) {
                    document.getElementById(p+"_msg").innerHTML = err;
                    document.getElementById(p+"_msg").classList.add("code400");
                    document.getElementById(p+"_spectrum").innerHTML = "-n/a-";
                    console.error(err);
		}
            })
            .catch(error => {
		_done++;
		if (_done == Object.keys(usi_data).length) {
		    document.getElementById("usi_stat").classList.remove("running");
                    if (!_dispec)
                        displayMsg("spec","USI not found at any of the repositories!");
		}

		if (rcode != -1)
                    document.getElementById(p+"_msg").classList.add("code"+rcode);
		else
                    document.getElementById(p+"_msg").classList.add("code500");

                document.getElementById(p+"_msg").innerHTML = error;
                document.getElementById(p+"_spectrum").innerHTML = "--n/a--";
                document.getElementById(p+"_atts").innerHTML = "--n/a--";
                document.getElementById(p+"_json").innerHTML = "--n/a--";
                document.getElementById(p+"_reannot").innerHTML = "";
                document.getElementById(p+"_modelparams").innerHTML = "";
		console.error(error);
            });
    }

}


function isSorted(arr) {
    for(var i = 0 ; i < arr.length - 1 ; i++)
	if (arr[i] > arr[i+1])
	    return false;
    return true;
}

function sortLinkedArrays(arr1,arr2) {
    var hoa = {};
    for (var i in arr1)
	hoa[arr1[i]] = arr2[i];

    arr1.sort(function(a, b){return a - b});

    arr2 = [];
    for (var i in arr1)
	arr2.push(Number(hoa[arr1[i]])); // also get rid of pesky strings

    for (var i in arr1)
        arr1[i] = Number(arr1[i]); // get rid of pesky strings

    return [arr1, arr2];
}


function shta(tid) {
    if (document.getElementById(tid).style.display == "none")
	document.getElementById(tid).style.display = "table";
    else
	document.getElementById(tid).style.display = "none";
}

function displayMsg(divid,msg) {
    clear_element(divid);
    var txt = document.createElement("h2");
    txt.className = "invalid";
    txt.style.marginBottom = "0";
    txt.append(msg);
    document.getElementById(divid).append(txt);
}

function viewAtts(divid,src) {
    clear_element(divid);

    for (var rname in usi_data) {
        clear_element(rname+"_current");
        document.getElementById(rname+"_current").title = "";
        document.getElementById(rname+"_current").setAttribute('onclick', '');
        document.getElementById(rname+"_current").style.cursor = "initial";
    }
    document.getElementById(src+"_current").innerHTML = "&#128220";
    document.getElementById(src+"_current").title = "The attributes for this spectrum are currently being displayed below";

    var atts = document.createElement("div");
    atts.className = "json";
    atts.style.whiteSpace = "initial";

    var title = document.createElement("h1");
    title.className = "rep title";
    title.innerHTML = "Spectrum attributes from " + src;
    atts.append(title);

    if (usi_data[src].usi_data.attributes) {
	var table = document.createElement("table");
	table.className = "prox annot";

	var tr = document.createElement("tr");
	tr = document.createElement("tr");
	for (var field of ["name", "accession", "value"]) {
            td = document.createElement("th");
            td.append(field);
            tr.append(td);
	}
	table.append(tr);

	for (var att of usi_data[src].usi_data.attributes) {
            tr = document.createElement("tr");

            for (var field of ["name", "accession", "value"]) {
		td = document.createElement("td");
		if (field != "value")
		    td.style.whiteSpace = "pre";
		if (att[field])
		    td.append(att[field]);
		else {
		    td.className = "code404";
		    td.append('-- null --');
		}
		tr.append(td);
	    }
            table.append(tr);
	}
	atts.append(table);
    }
    else {
	atts.innerHTML += src+" did not provide any attributes for this spectrum.";
    }

    document.getElementById(divid).append(atts);
}

function viewJSON(divid,src) {
    clear_element(divid);

    for (var rname in usi_data) {
	clear_element(rname+"_current");
        document.getElementById(rname+"_current").title = "";
        document.getElementById(rname+"_current").setAttribute('onclick', '');
        document.getElementById(rname+"_current").style.cursor = "initial";
    }
    document.getElementById(src+"_current").innerHTML = "&#127859";
    document.getElementById(src+"_current").title = "This JSON response is currently being displayed below";

    var jcode = document.createElement("div");
    jcode.className = "json";

    var title = document.createElement("h1");
    title.className = "rep title";
    title.innerHTML = src + " JSON response";
    jcode.append(title);

    jcode.innerHTML += JSON.stringify(usi_data[src].usi_data,null,2);

    document.getElementById(divid).append(jcode);
}


function renderLorikeet(divid,pfidx,src,src2=null) {
    if (src == 'null') // ugh
	src = src2;
    if (src2 && src2 == src)
	src2 = null;

    var s = usi_data[src].lori_data;
    clear_element(divid);

    for (var rname in usi_data) {
	clear_element(rname+"_current");
	var ele = document.getElementById(rname+"_current");
	if (usi_data[rname].lori_data) {
	    ele.title = "view as butterfly (mirror) spectrum";
            ele.setAttribute('onclick', 'renderLorikeet("spec",'+pfidx+',"'+src+'","'+rname+'");');
	    ele.innerHTML = "&#8853;";
	    ele.style.cursor = "pointer";
	}
	else
            ele.title = "";
    }
    if (src2) {
	document.getElementById(src2+"_current").innerHTML = "&#129419;";
	document.getElementById(src2+"_current").title = "This spectrum is currently being displayed in butterfly (mirror) format below";
    }
    document.getElementById(src+"_current").innerHTML = "&#128202;";
    document.getElementById(src+"_current").title = "This spectrum/PSM is currently being displayed below";


    $('#'+divid).specview({"sequence":pfidx!=null ? s.pforms[pfidx].sequence : '',
			   "scanNum":s.scanNum,
			   "charge":pfidx!=null ? s.pforms[pfidx].charge : s.charge ? s.charge : 1,
			   "width":650,
			   "height":400,
			   "precursorMz":s.precursorMz,
			   "minDisplayMz":s.minDisplayMz,
			   "maxDisplayMz":s.maxDisplayMz,
			   "massError":s.mzError,
			   "massErrorUnit":s.mzUnits,
			   "showMassErrorPlot":true,
			   "fileName":s.fileName,
			   "showA":s.showA,
			   "showB":[1,1,0],
			   "showY":[1,1,0],
			   "peakDetect":s.peakDetect,
			   "ntermMod":pfidx!=null ? s.pforms[pfidx].ntermMod : 0,
			   "ctermMod":pfidx!=null ? s.pforms[pfidx].ctermMod : 0,
			   "variableMods":pfidx!=null ? s.pforms[pfidx].variableMods : [],
			   "labileModSum":pfidx!=null ? s.pforms[pfidx].labileModSum : 0,
			   "maxNeutralLossCount":pfidx!=null ? s.pforms[pfidx].maxNeutralLossCount : 1,
			   "labelReporters":pfidx!=null ? s.pforms[pfidx].reporterIons : false,
			   "peaks":s.ms2peaks,
			   "ms2peaks2Label": (src2 ? src2 : null),
			   "peaks2": (src2 ? usi_data[src2].lori_data.ms2peaks : null)
			  });

    const title = document.createElement("h1");
    title.style.marginLeft = "280px";
    title.style.display = "inline";
    if (src == "MS2PIP" || src == "KOINA") {
	title.className = "title invalid";
	title.innerHTML = "PREDICTED spectrum from "+src;
    }
    else {
	title.className = "title valid";
	title.innerHTML = "Observed spectrum from "+src;
    }
    const sdiv = document.getElementById(divid);
    sdiv.insertBefore(title, sdiv.children[0]);
}


function render_tables(usi) {
    clear_element("main");

    var txt = document.createElement("span");
    txt.className = "smgr";
    txt.style.cursor = "pointer";
    txt.append("[ show / hide details ]");
    txt.setAttribute('onclick', 'shta("usideets");');

    document.getElementById("main").append(txt);

    var table = document.createElement("table");
    table.id = "usideets";
    table.className = "prox";
    //table.style.display = "none";

    var tr = document.createElement("tr");
    var td = document.createElement("td");
    td.className = "rep";
    td.colSpan = 99;
    td.append(usi);
    tr.append(td);
    table.append(tr);

    tr = document.createElement("tr");
    var headings = ['Provider','Response','Spectrum / PSM (click to view)','','Attributes','Dev Info','','Model + Params']
    for (var heading of headings) {
        td = document.createElement("th");
        td.append(heading);
        tr.append(td);
    }
    table.append(tr);

    var models = {
	"MS2PIP" : [ 'HCD', 'HCD2019', 'HCD2021', 'CID', 'iTRAQ', 'iTRAQphospho',
		     'TMT', 'TTOF5600', 'HCDch2', 'CIDch2', 'Immuno-HCD', 'CID-TMT' ],
	"KOINA" : [ 'AlphaPeptDeep_ms2_generic', 'Altimeter_2024_intensities',
		    'Prosit_2019_intensity', 'Prosit_2020_intensity_CID',
		    'Prosit_2020_intensity_HCD', 'Prosit_2020_intensity_TMT',
		    'Prosit_2023_intensity_timsTOF', 'Prosit_2024_intensity_PTMs_gl',
		    'Prosit_2024_intensity_cit', 'Prosit_2025_intensity_22PTM',
		    'Prosit_2025_intensity_40PTM', 'Prosit_2025_intensity_MultiFrag',
		    'Prosit_2025_intensity_lac', 'UniSpec',
		    'ms2pip_CID_TMT', 'ms2pip_HCD2021', 'ms2pip_Immuno_HCD', 'ms2pip_TTOF5600',
		    'ms2pip_iTRAQphospho', 'ms2pip_timsTOF2023', 'ms2pip_timsTOF2024']
    };

    for (var rname in usi_data) {
	tr = document.createElement("tr");
	tr.className = "rowdata";

        td = document.createElement("td");

	if (usi_data[rname].view) {
	    var link = document.createElement("a");
	    link.href = usi_data[rname].view.replace("INSERT_USI_HERE", usi);
	    if (link.href == usi_data[rname].view)
		link.title = "Visit "+rname;
	    else
		link.title = "View in "+rname;
	    link.target = rname+"_spec";
            link.append(rname);
            td.append(link);

	}
	else
            td.append(rname);

        tr.append(td);

        td = document.createElement("td");
        td.id = rname+"_msg";
        td.append('---');
        tr.append(td);

        td = document.createElement("td");
        td.id = rname+"_spectrum";
        td.append('---');
        tr.append(td);

        td = document.createElement("td");
        td.id = rname+"_current";
        tr.append(td);

        td = document.createElement("td");
        td.id = rname+"_atts";
        tr.append(td);

        td = document.createElement("td");
        td.id = rname+"_json";
        tr.append(td);

        td = document.createElement("td");
        td.id = rname+"_reannot";
        tr.append(td);

        td = document.createElement("td");
        td.id = rname+"_modelparams";

        if (rname in models) {
            var sel = document.createElement('select');
            sel.id = rname + "_model";
            // sel.style.marginLeft = "10px";
            sel.title = "Select prediction model";
            sel.setAttribute('onchange', 'rerun_model("'+rname+'");');

            for (var model of models[rname]) {
                var opt = document.createElement('option');
                opt.value = model;
                opt.innerText = model;
		if (model == 'ms2pip_HCD2021')
		    opt.selected = true;
                sel.append(opt);
            }
            td.append(sel);
        }

        tr.append(td);

	table.append(tr);
    }

    document.getElementById("main").append(table);
    document.getElementById("main").append(document.createElement("br"));
    document.getElementById("main").append(document.createElement("br"));
}

function rerun_model(provider) {
    if (provider == 'MS2PIP')
	return reload('MS2PIP');

    if (document.getElementById(provider+"_model_submit"))
        document.getElementById(provider+"_model_submit").remove();
    var needbutton = false;

    var goreload = true;
    var model = document.getElementById(provider+"_model").value;

    if (['Prosit_2019_intensity', 'Altimeter_2024_intensities',
	 'Prosit_2020_intensity_HCD', 'Prosit_2023_intensity_timsTOF',
	 'Prosit_2020_intensity_TMT', 'Prosit_2024_intensity_PTMs_gl',
	 'Prosit_2024_intensity_cit', 'Prosit_2025_intensity_22PTM',
	 'Prosit_2025_intensity_lac', 'Prosit_2025_intensity_40PTM',
	 'UniSpec', 'AlphaPeptDeep_ms2_generic'].includes(model)) {
	needbutton = true;

	if (!document.getElementById(provider+"_model_ce_container")) {
	    goreload = false;
	    var span = document.createElement("span");
	    span.id = provider+"_model_ce_container";
            span.style.paddingLeft = "5px";
	    span.title = "enter collision energy for model";
	    span.append("CE:");

            var input = document.createElement("input");
	    input.id = provider+"_model_ce";
	    input.size = '3';
	    input.value = '25';
            span.append(input);

	    document.getElementById(provider+"_modelparams").append(span);
	}
    }
    else if (document.getElementById(provider+"_model_ce_container"))
	document.getElementById(provider+"_model_ce_container").remove();

    if (['Prosit_2020_intensity_TMT', 'Prosit_2024_intensity_PTMs_gl',
         'Prosit_2024_intensity_cit', 'Prosit_2025_intensity_22PTM',
         'Prosit_2025_intensity_lac', 'Prosit_2025_intensity_40PTM',
	 'Prosit_2025_intensity_MultiFrag'].includes(model) ) {
	needbutton = true;

	var fragtype = model=='Prosit_2025_intensity_MultiFrag' ? 'multi':'simple';
	if (!document.getElementById(provider+"_model_frag") ||
	    document.getElementById(provider+"_model_frag").dataset.fragtype != fragtype) {
	    goreload = false;

	    if (document.getElementById(provider+"_model_frag"))
		document.getElementById(provider+"_model_frag").remove();

	    var sel = document.createElement('select');
	    sel.id = provider+"_model_frag";
	    sel.style.marginLeft = "10px";
	    sel.title = "Select fragmentation method for model";
            sel.dataset.fragtype = fragtype;

	    var frags = fragtype == 'simple' ?
		['HCD','CID'] :
		['HCD','ECD','EID','UVPD','ETciD'];

	    for (var frag of frags) {
                var opt = document.createElement('option');
                opt.value = frag;
                opt.innerText = frag;
                sel.append(opt);
	    }
	    document.getElementById(provider+"_modelparams").append(sel);
	}
    }
    else if (document.getElementById(provider+"_model_frag"))
        document.getElementById(provider+"_model_frag").remove();

    var models_with_instruments = {
	'Prosit_2025_intensity_lac' : ['eclipse','astral','lumos'],
	'UniSpec' : ['QE','QEHFX','LUMOS','ELITE','VELOS','NONE'],
	'AlphaPeptDeep_ms2_generic': ['QE','LUMOS','TIMSTOF','SCIEXTOF']
    };
    if (model in models_with_instruments) {
	needbutton = true;

	var instr_input;
        if (document.getElementById("model_instr_container"))
	    instr_input = document.getElementById("model_instr_container");
	else {
	    instr_input = document.createElement("span");
	    instr_input.id = 'model_instr_container';
	    document.getElementById(provider+"_modelparams").append(instr_input);
	}

        if (!document.getElementById(provider+"_model_instr") ||
	    document.getElementById(provider+"_model_instr").dataset.model != model) {
            goreload = false;
	    instr_input.innerHTML = '';

            var sel = document.createElement('select');
            sel.id = provider+"_model_instr";
            sel.style.marginLeft = "10px";
            sel.title = "Select instrument (type) for model";
	    sel.dataset.model = model;

            for (var instr of models_with_instruments[model]) {
                var opt = document.createElement('option');
                opt.value = instr;
                opt.innerText = instr;
                sel.append(opt);
            }

	    instr_input.append(sel);
	}
    }
    else if (document.getElementById("model_instr_container"))
	document.getElementById("model_instr_container").remove();

    if (needbutton) {
        var input = document.createElement('button');
	input.id = provider+"_model_submit";
	input.style.marginLeft = "10px";
	input.append('Go');
	input.onclick = function () { reload(provider); };
        document.getElementById(provider+"_modelparams").append(input);
    }
    else {
	var span = document.createElement("span");
	span.id = provider+"_model_submit";
	document.getElementById(provider+"_modelparams").append(span);
    }

    if (goreload)
	reload(provider);
}


function reload(provider) {
    for (var thing of ["_msg","_spectrum","_atts","_json","_reannot"]) {
	document.getElementById(provider+thing).innerText = '-- --';
	document.getElementById(provider+thing).className = '';
    }
    document.getElementById(provider+'_msg').innerText = '-- processing request --';

    _dispec = '---refresh---';
    _done--;
    document.getElementById("usi_stat").classList.add("running");
    get_usi_from([provider]);
}


function list_recent_usis(max) {
    var usis = pc_getRecentItems("USI",max);
    if (usis.length < 1)
        return;

    var span = document.getElementById("recentusis_span");
    span.innerHTML = '';
    span.className = '';

    var list = document.createElement("ol");
    list.style.paddingInlineStart = '10px';
    span.append(list);
    for (var dausi of usis) {
        var item = document.createElement("li");
        var link = document.createElement("a");
        link.setAttribute('onclick', 'pick_box_example(this)');
        link.title = 'click to open';
        link.append(dausi);
        item.append(link);
        item.append(document.createElement("hr"));
        list.append(item);
    }
}


function pick_box_example(anchor) {
    document.getElementById('usi_input').value=anchor.innerHTML;
    document.getElementById('usi_desc').innerHTML = '';
    toggle_box('NBTexamples',false,true);
    toggle_box('RecentUSIs',false,true);
    check_usi();
}

function toggle_box(box,open=false,close=false) {
    var elebox = document.getElementById(box);
    if ((elebox.style.visibility == "visible" && !open) || close) {
        elebox.style.visibility = "hidden";
        elebox.style.opacity = "0";
        if (document.getElementById(box+"_button"))
            document.getElementById(box+"_button").classList.remove("on");
    }
    else {
	elebox.style.visibility = "visible";
	elebox.style.opacity = "1";
        if (document.getElementById(box+"_button"))
            document.getElementById(box+"_button").classList.add("on");

	if ((elebox.offsetLeft + elebox.offsetWidth) < 200)
	    elebox.style.left = '10px';
	if ((elebox.offsetTop + elebox.offsetHeight) < 200)
	    elebox.style.top = '10px';
    }
}

function update_usi_input(sel) {
    document.getElementById('usi_input').value=sel.value;
    if (sel.options[sel.selectedIndex].dataset.desc)
	document.getElementById('usi_desc').innerHTML = sel.options[sel.selectedIndex].dataset.desc;
    else
	document.getElementById('usi_desc').innerHTML = '';

    sel.value='';
}

// not used at the moment...
function retrieve_example_usis() {
    fetch(_api['examples'])
        .then(response => response.json())
        .then(data => {
            try {
		var examples = document.getElementById("example_usis");
		var i = 1; // do not replace menu-like header (in position 0)
		for (var eg of data) {
		    var opt = document.createElement("option");
		    opt.value = eg.usi;
		    opt.text  = eg.usi;
		    opt.title = eg.id + " : " + eg.description;
		    opt.dataset.desc = eg.id + " : " + eg.html_description;
		    examples.options[i++] = opt;
		}
	    }
	    catch {} // ignore errors; leave html examples
	});
}


// misc utils
function clear_element(ele) {
    const node = document.getElementById(ele);
    while (node.firstChild) {
        node.removeChild(node.firstChild);
    }
}


function reannotate_peaks(who) {
    annotate_peaks(usi_data[who].usi_data,usi_data[who].lori_data.pforms[0].peptidoform);
}

function annotate_peaks(spec_data,pform) {
    if (!spec_data["attributes"])
	spec_data["attributes"] = [];

    var url = _api['annotate'];
    var mztol = null;
    var addMS1003169 = true;
    for (var att of spec_data['attributes']) {
        if (att.accession == "MS:10000512" &&
            att.value.startsWith("ITMS")) {
	    url += "?tolerance=500";
	    mztol = '500ppm';
	}
        if (att.accession == "MS:1003169")
	    addMS1003169 = false;
    }
    if (addMS1003169) {
	var att = {};
	att.accession = 'MS:1003169';
	att.name = 'proforma peptidoform sequence';
	att.value = pform;
	spec_data["attributes"].push(att);
    }

    fetch(url, {
        method: 'post',
        headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json'
        },
        body: JSON.stringify([spec_data])
    })
        .then(response => response.json())
        .then(annot_data => {
	    var annot_table = annotation_table(annot_data,mztol,pform);
	    clear_element("annot");
	    document.getElementById("annot").append(annot_table);
	});
}

function annotation_table(annot_data,mztol,pform) {
    var table = document.createElement("table");
    table.className = "annot prox";

    var tr = document.createElement("tr");
    var td = document.createElement("td");
    td.colSpan = '12';
    td.className = "rep";
    td.append("Peak Annotations for: "+pform);
    tr.append(td);

    td = document.createElement("td");
    td.colSpan = '2';
    td.className = "rep";
    td.style.fontSize = 'revert';
    td.setAttribute('onclick', 'show_mass_defect()');
    td.innerHTML = "&#128200; Mass Defect";
    td.title = "View Mass Defect plot";
    tr.append(td);

    td = document.createElement("td");
    td.colSpan = '2';
    td.className = "rep";
    td.style.fontSize = 'revert';
    td.setAttribute('onclick', 'show_ion_stats()');
    td.innerHTML = "&#128202; Ion Stats";
    td.title = "View Ion Contribution histogram plot";
    tr.append(td);

    table.append(tr);

    tr = document.createElement("tr");
    tr.style.position = 'sticky';
    tr.style.top = '0';
    tr.style.zIndex = '5';
    mztol = mztol ?  " [mztol="+mztol+"]" : '';
    for (var col of ["m/z", "intensity", "norm", "interpretation(s)"+mztol].concat(_ion_list)) {
        td = document.createElement("th");
	td.append(col);
        tr.append(td);
    }
    table.append(tr);

    var maxint = 1;
    for (var pint of annot_data['annotated_spectra'][0]['intensities'])
	if (pint > maxint)
	    maxint = pint;

    _totint = 0;
    _totints = [0,0,0,0,0,0,0,0,0,0,0,0];
    _coreints = [0,0,0,0,0,0,0,0,0,0,0,0];
    _mzs = annot_data['annotated_spectra'][0]['mzs'];

    for (var idx in annot_data['annotated_spectra'][0]['mzs']) {
	tr = document.createElement("tr");
	for (var col of ["mzs", "intensities", "interpretations"]) {
	    td = document.createElement("td");
	    var val = annot_data['annotated_spectra'][0][col][idx];
	    if (col == "interpretations")
		td.append(val);
	    else {
		td.className = "number";
		var f = col == "intensities" ? 1 : 4;
		td.append(Number(val).toFixed(f));
		if (col == "intensities") {
		    tr.append(td);
		    td = document.createElement("td");
		    td.className = "number";
		    td.style.borderRight = "1px solid rgb(187, 221, 187)";
		    td.append(Number(100*val/maxint).toFixed(1));
		    td.style.background = "linear-gradient(to left, rgb(187, 221, 187), rgb(187, 221, 187) "+(100*val/maxint)+"%, rgba(255, 255, 255, 0) "+(100*val/maxint)+"%)";
		}
	    }
	    tr.append(td);
	}

	// only consider the first one
	var what = annot_data['annotated_spectra'][0]["interpretations"][idx].split('/')[0];
	var mion = what.match(/[+-]/) ? false : true;
	var chrg = '';
	if (what.indexOf('^',-1) >= 0)
	    for (var c=0; c<Number(what.substr(-1,1)); c++)
		chrg += "+";

	var where = 999;
	var inum = what.match(/^.\d+/);

	if (what.startsWith("0@")) {
	    where = _ion_list.indexOf('other');
            what = 'other';
	}
	else if (what.startsWith("?")) {
            where = _ion_list.indexOf('?');
            what = inum ? inum : '?';
	}
	else if (what.startsWith("p") ||
		 what.includes("@p")) {
            where = _ion_list.indexOf('prec');
	    what = 'p'+chrg;;
	}
	else if (what.startsWith("I")) {
            where = _ion_list.indexOf('I');
	    what = what.substring(1,2);
	}
        else if (what.startsWith("r")) {
            where = _ion_list.indexOf('rep');
            what = what.substring(2,5);
        }
        else if (what.startsWith("m")) {
            where = _ion_list.indexOf('int');
            what = 'm';
        }
        else if (what.startsWith("a")) {
            where = _ion_list.indexOf('a');
            what = inum+chrg;
        }
        else if (what.startsWith("b")) {
            where = _ion_list.indexOf('b');
            what = inum+chrg;
        }
        else if (what.startsWith("c")) {
            where = _ion_list.indexOf('c');
            what = inum+chrg;
        }
        else if (what.startsWith("x")) {
            where = _ion_list.indexOf('x');
            what = inum+chrg;
        }
        else if (what.startsWith("y")) {
            where = _ion_list.indexOf('y');
            what = inum+chrg;
        }
        else if (what.startsWith("z")) {
            where = _ion_list.indexOf('z');
            what = inum+chrg;
        }
	else {
            where = _ion_list.indexOf('other');
	    what = "!!! "+what;
	}

	for (var aaa in _ion_list) {
            td = document.createElement("td");
	    if (aaa == where) {
		td.className = 'annot_col'+aaa;
		if (!mion)
		    td.style.filter = "brightness(65%)";
		else
                    _coreints[aaa] += annot_data['annotated_spectra'][0]['intensities'][idx];
		td.innerHTML = what;

		_totints[aaa] += annot_data['annotated_spectra'][0]['intensities'][idx];
		_totint += annot_data['annotated_spectra'][0]['intensities'][idx];

	    }
            tr.append(td);
	}

	table.append(tr);
    }


    tr = document.createElement("tr");
    for (var col of ["", "", "", ""].concat(_ion_list)) {
        td = document.createElement("th");
        td.append(col);
        tr.append(td);
    }
    table.append(tr);

    tr = document.createElement("tr");
    td = document.createElement("th");
    td.colSpan = '4';
    td.style.textAlign = 'right';
    td.append("Share of Total Ion Current:");
    tr.append(td);

    for (var aaa in _ion_list) {
	td = document.createElement("th");
	td.append((100*_totints[aaa]/_totint).toFixed(1)+"%");
	tr.append(td);
    }
    table.append(tr);

    return table;
}


function show_ion_stats() {
    clear_element("quickplot_canvas");
    document.getElementById("quickplot_title").innerHTML = "Ion Stats";

    var canvas = document.getElementById("quickplot_canvas");
    canvas.height = 250;
    canvas.width = 510;

    const ctx = canvas.getContext("2d");
    ctx.strokeStyle = "#ccc";
    ctx.lineWidth = 1;
    ctx.beginPath();
    for (var pct=0; pct<=100; pct+=10) {
        ctx.moveTo(0, 20+2*pct);
        ctx.lineTo(480, 20+2*pct);
        ctx.fillText((100-pct)+"%", 485, 20+2*pct);
    }
    ctx.stroke();

    for (var aaa in _ion_list) {
	var x = 5+40*aaa;
	var h = 200*_totints[aaa]/_totint;
	ctx.fillStyle = '#2c99ce';
	ctx.fillRect(x,  220-h, 30, h);

	h = 200*_coreints[aaa]/_totint;
	ctx.fillStyle = '#047';
	ctx.fillRect(x,  220-h, 30, h);

	ctx.fillStyle = '#000';
	ctx.font = "16px Consola";
	ctx.textAlign = "center";
	ctx.fillText(_ion_list[aaa], x+15, 240);
    }

    toggle_box("quickplot",true);
}

function show_mass_defect() {
    clear_element("quickplot_canvas");
    document.getElementById("quickplot_title").innerHTML = "Mass Defect";

    var minmz = 1000;
    var maxmz = 0;
    for (var mz of _mzs) {
	if (mz < minmz )
	    minmz = mz;
        if (mz > maxmz )
            maxmz = mz;
    }
    var w = Number((maxmz-minmz+1).toFixed(0));

    var canvas = document.getElementById("quickplot_canvas");
    canvas.height = 650;
    canvas.width = w+40;

    const ctx = canvas.getContext("2d");
    ctx.strokeStyle = "#ccc";
    ctx.lineWidth = 1;
    ctx.beginPath();
    for (var p=0; p<=10; p++) {
        ctx.moveTo(0, 10+p*60);
        ctx.lineTo(w, 10+p*60);
        ctx.fillText(((10-p)/10).toFixed(1), w+3, 15+p*60);
    }
    ctx.stroke();
    ctx.beginPath();
    ctx.strokeStyle = "#666";
    ctx.moveTo(0, 610);
    ctx.lineTo(w, 610);
    ctx.stroke();

    ctx.fillStyle = '#000';
    ctx.textAlign = "center";
    ctx.beginPath();
    for (var p=0; p<=2400; p+=100) {
	if (p>minmz && p<maxmz) {
	    ctx.moveTo(p-minmz, 610);
	    ctx.lineTo(p-minmz, 615);
            ctx.fillText(p, p-minmz, 625);
	}
    }
    ctx.stroke();

    ctx.font = "14px Consola";
    ctx.fillText('m/z', w/2, 645);

    ctx.save();
    ctx.translate( canvas.width - 1, 0 );
    ctx.rotate(270 * Math.PI / 180);
    ctx.fillText('m/z - int (m/z)', -(canvas.height/2).toFixed(0), -5);
    ctx.restore();

    ctx.strokeStyle = "rgba(0,64,120,0.6)";
    for (var mz of _mzs) {
	var md = mz - Math.floor(mz);

	ctx.beginPath();
	ctx.arc(mz-minmz, 610-md*600, 2, 0, 2 * Math.PI);
	ctx.stroke();
    }

    toggle_box("quickplot",true);
}
