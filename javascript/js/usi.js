var api_url = '../api/proxi/v0.1/';

var validate_url = api_url + 'usi_validator';
var examples_url = api_url + 'usi_examples';

var usi_data = {
    "jPOST"           : { "url" : "https://repository.jpostdb.org/proxi/spectra?resultType=full&usi=" },
    "MassIVE"         : { "url" : "http://massive.ucsd.edu/ProteoSAFe/proxi/v0.1/spectra?resultType=full&usi=" ,
			  "view": "http://massive.ucsd.edu/ProteoSAFe/usi.jsp#{\"usi\":\"" ,
			  "weiv": "\"}" },
    "PeptideAtlas"    : { "url" : "http://www.peptideatlas.org/api/proxi/v0.1/spectra?resultType=full&usi=" ,
			  "view": "https://db.systemsbiology.net/sbeams/cgi/PeptideAtlas/ShowObservedSpectrum?usi=" },
    "PRIDE"           : { "url" : "https://www.ebi.ac.uk/pride/proxi/archive/v0.1/spectra?resultType=full&usi=" ,
			  "view": "https://www.ebi.ac.uk/pride/archive/spectra?usi=" },
    "ProteomeCentral" : { "url" : "http://proteomecentral.proteomexchange.org/api/proxi/v0.1/spectra?resultType=full&usi=" }
};

var isobaric_unimods = [ "UNIMOD:214", "UNIMOD:532", "UNIMOD:533", "UNIMOD:730", "UNIMOD:731", "UNIMOD:737", "UNIMOD:738", "UNIMOD:739", "UNIMOD:889", "UNIMOD:984", "UNIMOD:985", "UNIMOD:1341", "UNIMOD:1342", "UNIMOD:2015", "UNIMOD:2016", "UNIMOD:2017" ];

var _peptidoform = null;

function init() {
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
        txt.appendChild(document.createTextNode("WARNING"));
        document.getElementById("main").appendChild(txt);

        txt = document.createElement("h4");
	txt.className = "invalid";
	txt.style.marginTop = "0";
        txt.appendChild(document.createTextNode("There is a [space] character in your USI! This might possibly be appropriate if the MS Run file name has a space in it, but usually this is the result of a copy-paste problem of a USI that was line wrapped in a document or email."));
	txt.appendChild(document.createElement("br"));
        txt.appendChild(document.createTextNode("Click [strip spaces] above to remove all spaces from your USI."));
        document.getElementById("main").appendChild(txt);
    }

}


async function validate_usi(carryon) {
    document.getElementById("usi_input").value = document.getElementById("usi_input").value.trim();
    var usi = document.getElementById("usi_input").value;
    if (usi == "") return;

    clear_element("main");
    clear_element("spec");

    var response = await fetch(validate_url, {
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
	if (data.validation_results[usi]["peptidoform"]) {
	    _peptidoform = JSON.parse(JSON.stringify(data.validation_results[usi]["peptidoform"])); // cheap dirty clone
	    _peptidoform._f = data.validation_results[usi]["interpretation"] || '';
	    _peptidoform._z = data.validation_results[usi]["charge"] || 0;
	    _peptidoform._s = data.validation_results[usi]["index"] || 0;
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
	txt.appendChild(document.createTextNode("VALID SYNTAX"));
	document.getElementById("main").appendChild(txt);

	txt = document.createElement("h4");
        txt.className = "valid";
	txt.style.marginTop = "0";
	txt.appendChild(document.createTextNode("The syntax of this USI is valid, although it may not be resolvable at any resource"));
	document.getElementById("main").appendChild(txt);
    }
    else {
        var txt = document.createElement("h2");
	txt.className = "invalid";
	txt.style.marginBottom = "0";
        txt.appendChild(document.createTextNode("INVALID"));
        document.getElementById("main").appendChild(txt);

        txt = document.createElement("h4");
	txt.className = "invalid";
	txt.style.marginTop = "0";
        txt.appendChild(document.createTextNode(data.validation_results[usi]["error_message"]));
        document.getElementById("main").appendChild(txt);
    }

    var txt = document.createElement("span");
    txt.className = "smgr";
    txt.style.cursor = "pointer";
    txt.appendChild(document.createTextNode("[ show / hide details ]"));
    txt.setAttribute('onclick', 'shta("usideets");');

    document.getElementById("main").appendChild(txt);

    var table = document.createElement("table");
    table.id = "usideets";
    table.className = "prox";
    table.style.display = "none";

    var tr = document.createElement("tr");
    var td = document.createElement("td");
    td.className = "rep";
    td.colSpan = 2;
    td.appendChild(document.createTextNode(usi));
    tr.appendChild(td);
    table.appendChild(tr);

    add_spec_data(table, '', data.validation_results[usi]);

    tr = document.createElement("tr");
    td = document.createElement("td");
    td.className = "rep";
    td.colSpan = 2;
    td.appendChild(document.createTextNode('JSON response'));
    tr.appendChild(td);
    table.appendChild(tr);

    tr = document.createElement("tr");
    td = document.createElement("td");
    td.colSpan = 2;
    td.style.fontFamily = 'monospace';
    td.style.whiteSpace = 'pre';
    td.appendChild(document.createTextNode(JSON.stringify(data.validation_results[usi],null,2)));
    tr.appendChild(td);
    table.appendChild(tr);

    show_validation_code(table,usi);

    document.getElementById("spec").appendChild(table);

    return false;
}

function show_validation_code(table,usi) {
    var tr = document.createElement("tr");
    var td = document.createElement("td");
    td.className = "rep";
    td.colSpan = 2;
    td.appendChild(document.createTextNode('Linux curl snippet'));
    tr.appendChild(td);
    table.appendChild(tr);
    tr = document.createElement("tr");
    td = document.createElement("td");
    td.colSpan = 2;
    td.style.fontFamily = 'monospace';
    td.style.whiteSpace = 'pre';
    td.appendChild(document.createTextNode("curl -X POST -H \"Content-Type: application/json\" http://proteomecentral.proteomexchange.org/api/proxi/v0.1/usi_validator -d '[ \""+usi+"\" ]'"));
    tr.appendChild(td);
    table.appendChild(tr);

    tr = document.createElement("tr");
    td = document.createElement("td");
    td.className = "rep";
    td.colSpan = 2;
    td.appendChild(document.createTextNode('Windows curl snippet'));
    tr.appendChild(td);
    table.appendChild(tr);
    tr = document.createElement("tr");
    td = document.createElement("td");
    td.colSpan = 2;
    td.style.fontFamily = 'monospace';
    td.style.whiteSpace = 'pre';
    td.appendChild(document.createTextNode("curl -X POST -H \"Content-Type: application/json\" http://proteomecentral.proteomexchange.org/api/proxi/v0.1/usi_validator -d \"[ \\\""+usi+"\\\" ]\""));
    tr.appendChild(td);
    table.appendChild(tr);

    tr = document.createElement("tr");
    td = document.createElement("td");
    td.className = "rep";
    td.colSpan = 2;
    td.appendChild(document.createTextNode('Python snippet'));
    tr.appendChild(td);
    table.appendChild(tr);
    tr = document.createElement("tr");
    td = document.createElement("td");
    td.colSpan = 2;
    td.style.fontFamily = 'monospace';
    td.style.whiteSpace = 'pre';
    td.appendChild(document.createTextNode("import json\nimport requests\n\nusis = [ \""+usi+"\", \"not a USI\" ]\nendpoint_url = \"http://proteomecentral.proteomexchange.org/api/proxi/v0.1/usi_validator\"\nresponse_content = requests.post(endpoint_url, json=usis, headers={'accept': 'application/json'})\nresult = response_content.json()\nprint(json.dumps(result, indent=2))\nfor usi in usis:\n  print(result['validation_results'][usi]['is_valid'],\"\\t\",usi)\n"));
    tr.appendChild(td);
    table.appendChild(tr);
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
        td.appendChild(document.createTextNode(label+f));
        tr.appendChild(td);

        td = document.createElement("td");
        td.appendChild(document.createTextNode(vdata[f]));
        tr.appendChild(td);
        table.appendChild(tr);
    }

}


async function check_usi() {
    document.getElementById("usi_input").value = document.getElementById("usi_input").value.trim();
    var usi = document.getElementById("usi_input").value;
    if (usi == "") return;

    _peptidoform = null;
    var valid = await validate_usi(true);
    if (!valid) return;

    render_tables(usi);
    clear_element("spec");
    document.getElementById("usi_stat").classList.add("running");

    var done = 0;
    var dispec = false;
    for (let p in usi_data) {
	var url = usi_data[p].url + encodeURIComponent(usi);

        var ccell = document.getElementById(p+"_msg");
        ccell.title = "view raw response from API";
        ccell.setAttribute('onclick', 'window.open("'+url+'");');
        ccell.style.cursor = "pointer";

	var rcode = -1;
	fetch(url)
            .then(response => {
                //console.log(p+" RESPONSE: "+response);
		rcode = response.status; // must capture it before json parsing
		//console.log(p+" CODE: "+rcode);
		return response;
            })
            .then(response => response.json())
            .then(alldata => {
		try {
		    done++;
		    if (done == Object.keys(usi_data).length) {
			document.getElementById("usi_stat").classList.remove("running");
			if (!dispec)
			    displayMsg("spec","USI not found at any of the repositories!");
		    }
                    var cell = document.getElementById(p+"_msg");
                    cell.title += " (Code:"+rcode+")";
		    cell.classList.add("code"+rcode);

                    if (rcode != 200) {
			cell.innerHTML = alldata.title;
			document.getElementById(p+"_spectrum").innerHTML = "n/a";
			console.log("[DEBUG] "+p+" said: "+alldata.status+"/"+alldata.title+"//"+alldata.detail);
			return;
                    }
                    cell.innerHTML = "OK";

		    var data = alldata[0]; // just consider the first one  FIXME??

		    usi_data[p].usi_data = data;

                    cell = document.getElementById(p+"_json");
                    cell.className = "smgr";
                    cell.title = "view JSON response";
                    cell.setAttribute('onclick', 'viewJSON("spec","'+p+'");');
                    cell.innerHTML = "[ JSON ]";

		    var s = {};
                    s.sequence = "";
                    s.charge = 1;
                    s.scanNum = 0;
                    s.precursorMz = 0;
                    s.fileName = p+" spectrum";
                    s.ntermMod = 0;
                    s.ctermMod = 0;
		    s.reporterIons = false;
                    s.variableMods = [];
		    s.labileModSum = 0;
		    s.maxNeutralLossCount = 1;
                    s.ms2peaks = [];

		    var has_spectrum = false;
		    var maxMz = 1999.0;

		    if (!data || !data.mzs || !data.intensities)
			throw "Incomplete spectrum data!";

		    if (!isSorted(data.mzs)) {
			console.log(p+" data NOT sorted :: attempting to sort...");
			var sorted = sortLinkedArrays(data.mzs,data.intensities);
			data.mzs = sorted[0];
			data.intensities = sorted[1];
		    }

                    for (var i in data.mzs) {
                        var usipeaks = [Number(data.mzs[i]), Number(data.intensities[i])];
                        s.ms2peaks.push(usipeaks);
			if (Number(data.mzs[i]) > maxMz) maxMz = Number(data.mzs[i]);
			has_spectrum = true;
                    }
		    s.minDisplayMz = 0.01;
                    s.maxDisplayMz = maxMz+1.0;

		    if (_peptidoform) {
			s.sequence = _peptidoform.peptide_sequence;
			s.fileName = _peptidoform._f;
			s.charge   = _peptidoform._z;
			s.scanNum  = _peptidoform._s;
			for (var mod in _peptidoform["terminal_modifications"]) {
			    if (_peptidoform["terminal_modifications"][mod].base_residue == "nterm") {
				s.ntermMod = _peptidoform["terminal_modifications"][mod].delta_mass;
				if (isobaric_unimods.includes(_peptidoform["terminal_modifications"][mod].modification_curie))
				    s.reporterIons = true;
			    }
			    else if (_peptidoform["terminal_modifications"][mod].base_residue == "cterm")
				s.ctermMod = _peptidoform["terminal_modifications"][mod].delta_mass;
			    else
				console.warn("[WARN] Invalid mod terminus; ignoring...");
			}
			for (var mod in _peptidoform["residue_modifications"]) {
			    var varmod  = {};
			    varmod.index     = _peptidoform["residue_modifications"][mod].index;
			    varmod.modMass   = _peptidoform["residue_modifications"][mod].delta_mass;
			    varmod.aminoAcid = _peptidoform["residue_modifications"][mod].base_residue;
			    if (varmod.aminoAcid == "M" && (varmod.modMass-15.9949 < 0.01)) {  //Ox
				var loss = {};
				loss.monoLossMass = 63.998285;
				loss.avgLossMass  = 64.11;
				loss.formula      = 'CH3SOH';
				varmod.losses = [];
				varmod.losses.push(loss);
				s.maxNeutralLossCount++;
			    }
                            else if ((varmod.aminoAcid == "S" || varmod.aminoAcid == "T") && (varmod.modMass-27.9949 < 0.01)) {  //Formyl
				var loss = {};
				loss.monoLossMass = 27.9949;
				loss.avgLossMass  = 28.0101;
				loss.formula      = 'CO';
				varmod.losses = [];
				varmod.losses.push(loss);
				s.maxNeutralLossCount++;
			    }

			    s.variableMods.push(varmod);
			}
                        for (var mod in _peptidoform["unlocalized_mass_modifications"]) {
			    s.labileModSum += _peptidoform["unlocalized_mass_modifications"][mod].delta_mass;
			}
		    }

		    if (data.attributes) {
			for (var att of data.attributes) {
                            if (att.accession == "MS:1008025") s.scanNum     = att.value;
                            if (att.accession == "MS:1000827") s.precursorMz = att.value;
                            if (att.accession == "MS:1000041") s.charge      = att.value;
                            if (att.accession == "MS:1000888") s.sequence    = att.value;
                            if (att.accession == "MS:1003061") s.fileName    = att.value;
			}
		    }


		    if (has_spectrum) {
			usi_data[p].lori_data = s;

			var cell = document.getElementById(p+"_spectrum");
			cell.title = "view spectrum";
			cell.style.fontWeight = "bold";
			cell.setAttribute('onclick', 'renderLorikeet("spec","'+p+'");');
			cell.innerHTML = s.fileName;

			if(!dispec) {
			    dispec = true;
			    renderLorikeet("spec",p);
			}
		    }
		    else {
			usi_data[p].lori_data = {};
			document.getElementById(p+"_spectrum").innerHTML = "-none!-";
		    }

		} catch(err) {
                    document.getElementById(p+"_msg").innerHTML = err;
                    document.getElementById(p+"_spectrum").innerHTML = "-n/a-";
                    console.error(err);
		}
            })
            .catch(error => {
		done++;
		if (done == Object.keys(usi_data).length) {
		    document.getElementById("usi_stat").classList.remove("running");
                    if (!dispec)
                        displayMsg("spec","USI not found at any of the repositories!");
		}

		if (rcode != -1)
                    document.getElementById(p+"_msg").classList.add("code"+rcode);
		else
                    document.getElementById(p+"_msg").classList.add("code500");

                document.getElementById(p+"_msg").innerHTML = error;
                document.getElementById(p+"_spectrum").innerHTML = "--n/a--";
                document.getElementById(p+"_json").innerHTML = "--n/a--";
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
	arr2.push(hoa[arr1[i]]);

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
    txt.appendChild(document.createTextNode(msg));
    document.getElementById(divid).appendChild(txt);
}

function viewJSON(divid,src) {
    clear_element(divid);

    for (var rname in usi_data) {
	clear_element(rname+"_current");
        document.getElementById(rname+"_current").title = "";
    }
    document.getElementById(src+"_current").innerHTML = "&#127859";
    document.getElementById(src+"_current").title = "This JSON response is currently being displayed below";

    var jcode = document.createElement("div");
    jcode.className = "json";

    var title = document.createElement("h1");
    title.className = "rep title";
    title.innerHTML = src + " JSON response";
    jcode.appendChild(title);

    jcode.innerHTML +=  JSON.stringify(usi_data[src].usi_data,null,2);

    document.getElementById(divid).appendChild(jcode);
}


function renderLorikeet(divid,src) {
    var s = usi_data[src].lori_data;
    clear_element(divid);

    for (var rname in usi_data) {
	clear_element(rname+"_current");
	document.getElementById(rname+"_current").title = "";
    }
    document.getElementById(src+"_current").innerHTML = "&#128202;";
    document.getElementById(src+"_current").title = "This spectrum/PSM is currently being displayed below";

    $('#'+divid).specview({"sequence":s.sequence,
			   "scanNum":s.scanNum,
			   "charge":s.charge,
			   "width":650,
			   "height":400,
			   "precursorMz":s.precursorMz,
			   "minDisplayMz":s.minDisplayMz,
			   "maxDisplayMz":s.maxDisplayMz,
			   "massError":20,
			   "massErrorUnit":'ppm',
			   "showMassErrorPlot":true,
			   "fileName":s.fileName,
			   "showA":[1,0,0],
			   "showB":[1,1,0],
			   "showY":[1,1,0],
			   "peakDetect":false,
			   "ntermMod":s.ntermMod,
			   "ctermMod":s.ctermMod,
			   "variableMods":s.variableMods,
			   "labileModSum":s.labileModSum,
			   "maxNeutralLossCount":s.maxNeutralLossCount,
			   "labelReporters":s.reporterIons,
			   "peaks":s.ms2peaks});
}


function render_tables(usi) {
    clear_element("main");

    var txt = document.createElement("span");
    txt.className = "smgr";
    txt.style.cursor = "pointer";
    txt.appendChild(document.createTextNode("[ show / hide details ]"));
    txt.setAttribute('onclick', 'shta("usideets");');

    document.getElementById("main").appendChild(txt);

    var table = document.createElement("table");
    table.id = "usideets";
    table.className = "prox";
    //table.style.display = "none";

    var tr = document.createElement("tr");
    var td = document.createElement("td");
    td.className = "rep";
    td.colSpan = 5;
    td.appendChild(document.createTextNode(usi));
    tr.appendChild(td);
    table.appendChild(tr);

    tr = document.createElement("tr");
    var headings = ['Provider','Response','Spectrum / PSM (click to view)','','Dev Info']
    for (var heading of headings) {
        td = document.createElement("th");
        td.appendChild(document.createTextNode(heading));
        tr.appendChild(td);
    }
    table.appendChild(tr);

    for (var rname in usi_data) {
	tr = document.createElement("tr");
	tr.className = "rowdata";

        td = document.createElement("td");

	if (usi_data[rname].view) {
	    var link = document.createElement("a");
	    link.href = usi_data[rname].view + usi;
            if (usi_data[rname].weiv)
		link.href += usi_data[rname].weiv;
	    link.title = "View in "+rname;
	    link.target = rname+"_spec";
            link.appendChild(document.createTextNode(rname));
            td.appendChild(link);
	}
	else
            td.appendChild(document.createTextNode(rname));

        tr.appendChild(td);

        td = document.createElement("td");
        td.id = rname+"_msg";
        td.appendChild(document.createTextNode('---'));
        tr.appendChild(td);

        td = document.createElement("td");
        td.id = rname+"_spectrum";
        td.appendChild(document.createTextNode('---'));
        tr.appendChild(td);

        td = document.createElement("td");
        td.id = rname+"_current";
        tr.appendChild(td);

        td = document.createElement("td");
        td.id = rname+"_json";
        tr.appendChild(td);

	table.appendChild(tr);
    }

    document.getElementById("main").appendChild(table);
    document.getElementById("main").appendChild(document.createElement("br"));
    document.getElementById("main").appendChild(document.createElement("br"));
}

function pick_box_example(anchor) {
    document.getElementById('usi_input').value=anchor.innerHTML;
    document.getElementById('usi_desc').innerHTML = '';
    toggle_box('NBTexamples');
    check_usi();
}

function toggle_box(box) {
    if (document.getElementById(box).style.visibility == "visible") {
        document.getElementById(box).style.visibility = "hidden";
        document.getElementById(box).style.opacity = "0";
        if (document.getElementById(box+"_button"))
            document.getElementById(box+"_button").classList.remove("on");
    }
    else {
	document.getElementById(box).style.visibility = "visible";
	document.getElementById(box).style.opacity = "1";
        if (document.getElementById(box+"_button"))
            document.getElementById(box+"_button").classList.add("on");
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
    fetch(examples_url)
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
