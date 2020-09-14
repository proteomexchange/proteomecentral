var usi_data = { "PRIDE"           : { "url" : "http://wwwdev.ebi.ac.uk/pride/proxi/archive/v0.1/spectra?resultType=full&usi=" ,
				       "view": "https://www.ebi.ac.uk/pride/archive/spectra?usi=" },
		 "ProteomeCentral" : { "url" : "http://proteomecentral.proteomexchange.org/api/proxi/v0.1/spectra?resultType=full&usi=" },
		 "PeptideAtlas"    : { "url" : "http://www.peptideatlas.org/api/proxi/v0.1/spectra?resultType=full&usi=" ,
				       "view": "https://db.systemsbiology.net/sbeams/cgi/PeptideAtlas/ShowObservedSpectrum?usi=" },
		 "MassIVE"         : { "url" : "http://ccms-internal.ucsd.edu/ProteoSAFe/proxi/v0.1/spectra?resultType=full&usi=" ,
				       "view": "http://massive.ucsd.edu/ProteoSAFe/usi.jsp#{\"usi\":\"" ,
				       "weiv": "\"}" },
		 "jPOST"           : { "url" : "https://repository.jpostdb.org/proxi/spectra?resultType=full&usi=" }
	       };

function check_usi() {
    var usi = document.getElementById("usi_input").value;
    if (usi == "") return;

    render_tables(usi);
    clear_element("spec");
    document.getElementById("usi_stat").classList.add("running");

    var done = 0;
    for (let p in usi_data) {
	var url = usi_data[p].url + usi;

	var rcode = -1;
	fetch(url)
            .then(response => {
		rcode = response.status; // must capture it before json parsing
		// console.log("CODE: "+rcode);
		return response;
            })
            .then(response => response.json())
            .then(alldata => {
		try {
		    done++;
		    if (done == Object.keys(usi_data).length)
			document.getElementById("usi_stat").classList.remove("running");
                    document.getElementById(p+"_code").innerHTML = rcode;
		    document.getElementById(p+"_code").classList.add("code"+rcode);
                    if (rcode != 200) {
			document.getElementById(p+"_msg").innerHTML = alldata.title;
			document.getElementById(p+"_spectrum").innerHTML = "n/a";
			document.getElementById("debug").innerHTML += p + " :: " + alldata.detail + "<br>";
			console.log("[DEBUG] "+p+" said: "+alldata.status+alldata.title);
			return;
                    }
                    document.getElementById(p+"_msg").innerHTML = "OK";

		    var data = alldata[0]; // just consider the first one  FIXME??

		    usi_data[p].usi_data = data;

		    var s = {};
                    s.ms1peaks = null;
                    s.sequence = "";
                    s.charge = 1;
                    s.scanNum = 0;
                    s.precursorMz = 0;
                    s.fileName = p+" spectrum";
                    s.ntermMod = 0;
                    s.ctermMod = 0;
                    s.variableMods = [];
                    s.ms2peaks = [];

		    var has_spectrum = false;
		    var usimods = {};
                    for (var i in data.mzs) {
                        var usipeaks = [Number(data.mzs[i]), Number(data.intensities[i])];
                        s.ms2peaks.push(usipeaks);
			has_spectrum = true;
                    }

		    if (data.attributes) {
			for (var att of data.attributes) {
                            if (att.accession == "MS:1008025") s.scanNum     = att.value;
                            if (att.accession == "MS:1000827") s.precursorMz = att.value;
                            if (att.accession == "MS:1000041") s.charge      = att.value;
                            if (att.accession == "MS:1000888") s.sequence    = att.value;
                            if (att.accession == "MS:1003061") s.fileName    = att.value;
                            if (att.accession == "MS:1009999") usimods = extractUSIMods(att.value);
			}
		    }

		    if (usimods) {
			s.ntermMod = usimods.ntermMod;
			s.ctermMod = usimods.ctermMod;
			s.variableMods = usimods.variableMods;
		    }

		    if (has_spectrum) {
			usi_data[p].lori_data = s;

			var cell = document.getElementById(p+"_spectrum");
			cell.title = "view spectrum";
			cell.setAttribute('onclick', 'renderLorikeet("spec","'+p+'");');
			cell.innerHTML = s.fileName;
		    }
		    else {
			usi_data[p].lori_data = {};
			document.getElementById(p+"_spectrum").innerHTML = "-none!-";
		    }

                    var cell = document.getElementById(p+"_json");
                    cell.title = "view JSON response";
                    cell.setAttribute('onclick', 'viewJSON("spec","'+p+'");');
                    cell.innerHTML = "view";

		} catch(err) {
                    document.getElementById(p+"_code").innerHTML = "--error--";
                    document.getElementById(p+"_msg").innerHTML = err;
                    document.getElementById(p+"_spectrum").innerHTML = "-n/a-";
                    document.getElementById(p+"_json").innerHTML = "-n/a-";
		    document.getElementById("debug").innerHTML += p + " :: " + err + "<br>";
                    console.log(err);
		}
            })
            .catch(error => {
		done++;
		if (done == Object.keys(usi_data).length)
		    document.getElementById("usi_stat").classList.remove("running");
                document.getElementById(p+"_code").classList.add("code500");
                document.getElementById(p+"_code").innerHTML = "--ERROR--";
                document.getElementById(p+"_msg").innerHTML = error;
                document.getElementById(p+"_spectrum").innerHTML = "--n/a--";
                document.getElementById(p+"_json").innerHTML = "--n/a--";
		document.getElementById("debug").innerHTML += p + " :: " + error + "<br>";
		console.log(error);
            });
    }

}


function extractUSIMods(peptidoform) {
    var usi_nterm = 0;
    var usi_cterm = 0;
    var usi_vmods = [];

    // n-term
    var regex = /^\[.+\]-/;
    var match = regex.exec(peptidoform);
    if (match) {
        usi_nterm = Number(match[0].replace(/\[(.+)\]-/, '$1'));
        peptidoform = peptidoform.replace(regex, '');
    }

    // c-term
    regex = /-\[.+\]$/;
    match = regex.exec(peptidoform);
    if (match) {
        usi_cterm = Number(match[0].replace(/-\[(.+)\]/, '$1'));
        peptidoform = peptidoform.replace(regex, '');
    }

    // aa mods
    regex = /[A-Z]\[.+?\]/;
    while (1) {
        match = regex.exec(peptidoform);
        if (match) {
            var usi_varmod  = {};
            usi_varmod.index = match.index+1;
            usi_varmod.modMass = Number(match[0].replace(/.*\[(.+)\]/, '$1'));
            usi_varmod.aminoAcid = match[0].replace(/^(.).*/, '$1');
            usi_vmods.push(usi_varmod);

            peptidoform = peptidoform.replace(regex, usi_varmod.aminoAcid);
        }
        else break;
    }

    var o = {};
    o.ntermMod = usi_nterm;
    o.ctermMod = usi_cterm;
    o.variableMods = usi_vmods;
    return o;
}


function viewJSON(divid,src) {
    clear_element(divid);

    for (var rname in usi_data)
	clear_element(rname+"_current");
    document.getElementById(src+"_current").innerHTML = "&#127859";

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

    for (var rname in usi_data)
	clear_element(rname+"_current");
    document.getElementById(src+"_current").innerHTML = "&#128202;";

    $('#'+divid).specview({"sequence":s.sequence,
                       "scanNum":s.scanNum,
                       "charge":s.charge,
                       "fragmentMassType":s.fragmentMassType,
                       "precursorMassType":s.precursorMassType,
                       "width":650,
                       "height":400,
                       "precursorMz":s.precursorMz,
                       "selWinLow":s.selWinLow,
                       "minDisplayMz":s.minDisplayMz,
                       "maxDisplayMz":s.maxDisplayMz,
                       "selWinHigh":s.selWinHigh,
                       "massError":s.massError,
                       "showMassErrorPlot":s.showMassErrorPlot,
                       "fileName":s.fileName,
                       "showB":s.showB,
                       "showY":s.showY,
                       "ntermMod":s.ntermMod,
                       "ctermMod":s.ctermMod,
                       "variableMods":s.variableMods,
                       "maxNeutralLossCount":s.maxNeutralLossCount,
                       "ms1peaks":s.ms1peaks,
                       "ms1scanLabel":s.ms1scanLabel,
                       "zoomMs1":s.zoomMs1,
                       "precursorPeakClickFn":s.precursorPeakClicked,
                       "peaks2":s.ms2peaks2,
                       "ms2peaks2Label":s.ms2peaks2Label,
                       "peaks":s.ms2peaks});
}


function render_tables(usi) {
    clear_element("main");
    clear_element("debug");

    var table = document.createElement("table");
    table.className = "prox";

    var tr = document.createElement("tr");
    var td = document.createElement("td");
    td.className = "rep";
    td.colSpan = 6;
    td.appendChild(document.createTextNode(usi));
    tr.appendChild(td);
    table.appendChild(tr);

    tr = document.createElement("tr");
    var headings = ['Provider','Response Code','Message','Spectrum','','JSON']
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
	td.id = rname+"_code";
        td.appendChild(document.createTextNode('---'));
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


// misc utils
function clear_element(ele) {
    const node = document.getElementById(ele);
    while (node.firstChild) {
        node.removeChild(node.firstChild);
    }
}
