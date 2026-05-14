var _api = {};
_api['base_url'] = "/api/proxi/v0.1/";

var _backbone_ions = ['a','b','c','x','y','z'];
var _ion_list = _backbone_ions.concat(['I','prec','rep','int','mol',"?",'other']);
var _ion_colors = {};
var _settings = {}
var _spectrum = {};
var _peptidoforms = [];
var _chartdata = null;
var _maxint;
var _totint;
var _totints;
var _coreints;
var _mzs = [];

function init() {
    // Allow window to listen for a postMessage
    window.addEventListener("message", (e) => {
        if (!e.data.source || e.data.source != "QUETZAL Annotation request")
	    return;

        var spectrum = e.data.spectrum || null;
        if (spectrum) {
	    user_msg("<b>Received spectrum</b> from: "+e.origin, 200);
	    user_log(null,"Received spectrum via POST from: "+e.origin, 'run');
            import_posted_spectrum(spectrum);

	    var response = {};
            response.source = "QUETZAL Annotation response";
	    if (e.data.spectrum_id)
		response.spectrum_id = e.data.spectrum_id;
	    response.status = true;

	    window.opener.postMessage(response,"*");
        }
	else {
            user_msg("<b>Empty spectrum</b> from: "+e.origin, 500, false);
            user_log(null,"Empty spectrum from: "+e.origin, 'error');
	}
    });
    window.addEventListener('beforeunload', (e) => {
        var response = {};
        response.source = "QUETZAL Window closed";
        window.opener.postMessage(response,"*");
    });

    history.replaceState({}, "", document.location.href);
    window.addEventListener("popstate", (event) => {
	if (event.state) {
	    reset_forms();
	    init3();
	}
    });

    _api['auth'] = "https://www.ebi.ac.uk/pride/private/ws/archive/v2/getAAPTokenWeb";

    fetch("./proxi_config.json")
	.then(response => response.json())
	.then(config => {
            if (config.API_URL) {
		_api['spectra'] = config.API_URL +"spectra";
		_api['annotate'] = config.API_URL +"annotate";
		_api['validate'] = config.API_URL +"usi_validator";
	    }
	    init2();
            if (config.SpecialWarning)
		user_msg(config.SpecialWarning,404,false);
	})
	.catch(error => {
	    _api['spectra'] = _api['base_url'] + "spectra";
	    _api['annotate'] = _api['base_url'] + "annotate";
	    _api['validate'] = _api['base_url'] + "usi_validator";
	    init2();
	});
}

function init2() {
    _settings['default_title'] = document.title;
    _settings['usi_url'] = _api['spectra'] + '?resultType=full&usi=';
    _settings['mztolerance'] = 10;
    _settings['auth'] = null;
    // always PPM.... _settings['mztolerance_units'] = 'ppm';

    for (var setting in _settings) {
	if (document.getElementById(setting+"_setting"))
	    document.getElementById(setting+"_setting").value = _settings[setting];
	if (document.getElementById(setting+"_setting_button"))
	    document.getElementById(setting+"_setting_button").disabled = true;
    }

    // missing?  '_': 'tab:gray'
    _ion_colors['a'] = "#2ca02c"; // tab:green
    _ion_colors['b'] = "#1f77b4"; // tab:blue
    _ion_colors['c'] = "#FF8C00"; // dark orange
    _ion_colors['x'] = "#4B0082"; // indigo
    _ion_colors['y'] = "#d62728"; // tab:red
    _ion_colors['z'] = "#008B8B"; // dark cyan
    _ion_colors['I'] = "#ff7f0e"; // tab:orange
    _ion_colors['prec'] = "#e377c2"; // tab:pink
    _ion_colors['rep'] = "#9467bd"; // tab:purple
    _ion_colors['int'] = "#8c564b"; // tab:brown
    _ion_colors['mol'] = "#9467bd"; // tab:purple
    _ion_colors['?'] = "#7f7f7f"; // tab:gray
    _ion_colors['other'] = "#7f7f7f"; // tab:gray

    Chart.register(ChartDataLabels);
    for (var popup of ['quickplot','mzPAFhelp', 'ProFormaHelp', 'FeedbackHelp', 'ExploreHelp','inputPeaksHelp'])
	tpp_dragElement(document.getElementById(popup));

    for (var ioncolor in _ion_colors) {
	if (document.getElementById("helpquide_"+ioncolor)) {
	    document.getElementById("helpquide_"+ioncolor).style.color = 'white';
	    document.getElementById("helpquide_"+ioncolor).style.background = _ion_colors[ioncolor];
	    document.getElementById("helpquide_"+ioncolor).style.padding = '5px';
	}
    }

    list_recent_usis(10);
    init3();
}

function init3() {
    show_input('import_menu');

    const params = new URLSearchParams(window.location.search);
    if (params.has('usi')) {
	document.getElementById("usi_input").value = params.get('usi');
	if (params.has('provider')) {
	    var button = document.getElementById("usiprovider_input");
            button.value = params.get('provider');
            set_usi_url(button);
	}
        if (params.has('fragmentation'))
	    document.getElementById("dissociation_type_input").value = params.get('fragmentation');
	validate_usi(document.getElementById("usi_button"),true);
    }
}

function reset_forms(exclude='NONE_OF_THE_ABOVE') {
    for (var what of ['usi','dta','pform','charge','precmz','xmin','xmax','ymax','mask_isolation_width','minimum_labeling_percent'])
	if (what != exclude)
	    document.getElementById(what+"_input").value = '';
    document.getElementById("peakmztol_input").value = '10';

    _spectrum = {};
    _peptidoforms = [];

    clear_element("ion_div");
    clear_element("annot_div");
    clear_element("useralerts");
    toggle_box("quickplot",false,true);
    toggle_box("usercredentials",false,true);
    toggle_box("USIexamples",false,true);
    toggle_box("RecentUSIs",false,true);
    toggle_box("ExploreHelp",false,true);
    toggle_box("viewspectrum_toolbar",false,true);

    if (_chartdata)
        _chartdata.destroy();

    document.getElementById("resetzoom_button").classList.remove('blue');
    document.getElementById("spectrum_preview").innerHTML = '<br><br>Press the Preview button above to generate image.<br><br>';
    document.getElementById("annotation_form").innerHTML = '<p>Please load annotated spectrum data to see annotation form.</p>';
    document.title = _settings['default_title'];

    history.replaceState({}, "", "//"+ window.location.hostname + window.location.pathname);
}


function deauth_user(button) {
    button.classList.remove('blue');

    if (!_settings['auth'])
	return;

    _settings['auth'] = null;

    document.getElementById("user_input").value = '';
    document.getElementById("pwd_input").value = '';
    document.getElementById("usercredentials_button").innerHTML = "Enter Access Credentials";

    user_log(null, "Auth token destroyed");
    user_msg("You have been logged out of PRIDE",200);
    addCheckBox(button,true);
}

function auth_user(button) {
    button.classList.remove('blue');

    var user = document.getElementById("user_input").value.trim();
    var pwd = document.getElementById("pwd_input").value.trim();

    document.getElementById("user_input").value = user;
    document.getElementById("pwd_input").value = pwd;

    if (user == "" || pwd == "")
        return user_msg("Enter a username and password to gain access to restricted data in PRIDE",404);;

    user_log(null, "Authenticating user: "+user,'run');
    stuff_is_running(button,true);

    var creds = { "Credentials": { "username": user, "password": pwd } }
    fetch(_api['auth'], {
        method: 'post',
        headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json'
        },
        body: JSON.stringify(creds)
    })
        .then(response => {
	    if (response.ok)
		return response.text();

            return response.text().then(text => {
		throw text+" ("+response.status+")";
            })
	})
        .then(data => {
	    _settings['auth'] = data;
	    user_log(null, "Auth token acquired");
            user_msg(user+" authenticated successfully",200);
	    stuff_is_running(button,false);
	    addCheckBox(button,true);

            document.getElementById("usercredentials_button").innerHTML = "Logged in as: "+user;
	    document.getElementById("logout_button").classList.add('blue');
        })
	.catch(error => {
            stuff_is_running(button,false);
            user_log(null,"ERROR authenticating user::",'error');
            user_log(null,error);
            console.error(error);
            user_msg("ERROR authenticating user: "+error,500,false);
        });
}



function set_usi_url(button) {
    var where = _api['spectra'];
    toggle_box("usercredentials",false,true);
    document.getElementById("usercredentials_button").style.visibility = "hidden";

    switch (button.value) {
    case "iProX":
        where = "https://www.iprox.cn/proxi/spectra";
	break;
    case "jPOST":
        where = "https://repository.jpostdb.org/proxi/spectra";
	break;
    case "MassIVE":
        where = "https://massive.ucsd.edu/ProteoSAFe/proxi/v0.1/spectra";
        break;
    case "PeptideAtlas":
	where = "https://peptideatlas.org/api/proxi/v0.1/spectra";
        break;
    case "PRIDE":
        where = "https://www.ebi.ac.uk/pride/proxi/archive/v0.1/spectra";
        break;
    case "PRIDE_private":
        where = "https://www.ebi.ac.uk/pride/ws/usi/v1/spectrum?resultType=FULL&usi=";

	button = document.getElementById("usercredentials_button");
	button.style.visibility = "";
        if (!_settings['auth']) {
	    user_msg("Please enter your PRIDE credentials to view access-restricted data.",404,false);
	    toggle_box("usercredentials",true);
	}
        break;
    case "ProteomeCentral":
	where = _api['spectra'];
        break;
    default:
	button.value = "ProteomeCentral";
    }

    if (!where.includes('resultType'))
	where += '?resultType=full&usi=';
    _settings['usi_url'] = where;

    addCheckBox(button,true);
}


function validate_usi(button,alsofetch) {
    var usi = document.getElementById("usi_input").value.trim();

    if (alsofetch) {
	reset_forms('usi');
    }
    else {
	usi = "mzspec:PXD000000:test:scan:1";
        var plus = ':';
        for (var pi in _peptidoforms) {
            usi += plus + _peptidoforms[pi].peptidoform_string;
            usi += '/' + _peptidoforms[pi].charge;
            plus = "+";
        }
    }

    if (usi == "")
	return user_msg("Unable to load spectrum.  Please specify a valid USI.",404,false);

    user_log(null, "Validating USI: "+usi,'run');
    stuff_is_running(button,true);

    if (!usi.startsWith("mzspec:"))
	usi = "mzspec:" + usi;
    if (alsofetch)
	document.getElementById("usi_input").value = usi;


    fetch(_api['validate'], {
        method: 'post',
        headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json'
        },
        body: "["+JSON.stringify(usi)+"]"
    })
        .then(response => response.json())
        .then(data => {
	    if (data.error_code != "OK") {
                user_log(null, "Error: "+data.error_message);
                return user_msg("Error: "+data.error_message,500,false);
	    }

	    if (data.validation_results[usi]["is_valid"] == true) {
		if (data.validation_results[usi]["peptidoforms"] &&
		    data.validation_results[usi]["peptidoforms"].length > 0) {
		    _peptidoforms = JSON.parse(JSON.stringify(data.validation_results[usi]["peptidoforms"])); // cheap dirty clone

		    var pforms = document.getElementById("pform_input");
		    var charges = document.getElementById("charge_input");
		    pforms.value = '';
		    charges.value = '';
		    var plus = '';
		    for (var pi in _peptidoforms) {
			pforms.value += plus + _peptidoforms[pi].peptidoform_string;
			charges.value += plus + _peptidoforms[pi].charge;
			plus = "+";
		    }
		    if (document.getElementById("precmz_input").value == '')
			document.getElementById("precmz_input").value = _peptidoforms[0].ion_mz;

		    _spectrum['name'] = pforms.value;

		}
		if (alsofetch)
		    fetch_usi(usi,usi.replace(":"+data.validation_results[usi]["interpretation"],':TESTPEPTIDE/2'),button);
		else {
		    process_spectrum_data();
		    stuff_is_running(button,false);
		}
	    }
	    else {
		stuff_is_running(button,false);
		user_log(null, "USI Validation Error",'error');
		user_log(null, data.validation_results[usi]["error_message"]);
		user_msg("USI Validation Error: "+data.validation_results[usi]["error_message"],500,false);
	    }
	})
	.catch(error => {
	    stuff_is_running(button,false);
            user_log(null,"ERROR validating the USI::",'error');
            user_log(null,error);
            console.error(error);
            user_msg("ERROR validating the USI: "+error,500,false);
	});
}


function fetch_usi(full,usi,button) {
    user_log(null, "Fetching USI: "+usi,'run');
    user_log(null, "...from: "+_settings['usi_url']);

    stuff_is_running(button,true);

    const myHeaders = new Headers();
    myHeaders.append("Accept", "application/json");
    if (document.getElementById("usercredentials_button").style.visibility != "hidden") {
	if (!_settings['auth']) {
            stuff_is_running(button,false);
            toggle_box("usercredentials",true);
            return user_msg("Please enter your PRIDE credentials to view access-restricted data, and resubmit.",404,false);
	}
	else
	    myHeaders.append('Authorization', 'Bearer '+_settings['auth']);
    }

    var rcode = -1;
    fetch(_settings["usi_url"]+encodeURIComponent(usi), {
        method: 'get',
        headers: myHeaders
    })
	.then(response => {
	    rcode = response.status; // must capture it before json parsing
	    return response.json();
	})
	.then(rdata => {
	    if (rcode != 200) {
		stuff_is_running(button,false);
		if (rdata.title) {
		    user_log(null, "Error: "+rdata.title,'error');
		    user_log(null, "Trace: "+rdata.detail);
		    console.log("["+rdata.status+"] "+rdata.title+" :: "+rdata.detail);
                    return user_msg(rdata.detail?rdata.detail:rdata.title,500,false);
		}
                else if (rdata.error) {
                    user_log(null, "Error: "+rdata.error,'error');
                    return user_msg(rdata.error,500,false);
		}
		else {
                    user_log(null, "Error in: "+rdata,'error');
                    return user_msg("There was an error...",500,false);
		}
	    }

	    // not so "Proud"...
	    if (!rdata.mzs && rdata.masses) {
		user_log(null,"Non-PROXI spectrum format detected; attempting to convert data...","warn");
		var fixpride = {};
		fixpride.mzs = rdata.masses;
		fixpride.intensities = rdata.intensities;
		fixpride.attributes = rdata.properties;
		rdata = [];
		rdata[0] = fixpride;
	    }

            document.title = "Quetzal ["+full+"]";
            history.replaceState({ usi: full },document.title, "//"+ window.location.hostname + window.location.pathname + '?usi='+encodeURIComponent(full)+"&provider="+document.getElementById("usiprovider_input").value);

	    pc_addRecentItem("USI",full);
            list_recent_usis(10);

	    user_msg("Successfully loaded spectrum "+usi,200);
	    user_log(null,"Successfully loaded spectrum with "+rdata[0].mzs.length+" peaks");
	    user_log(null,"---- Attributes ----");
	    if (rdata[0].attributes) {
		for (var a of rdata[0].attributes) {
		    user_log(null," "+a.name+": "+a.value);
		    var name = null;
		    if (a.accession == 'MS:1000041')
			name = 'charge';
		    else if (a.accession == 'MS:1000744')
			name = 'mz';
		    else if (a.accession == "MS:1000827" && !rdata['mz'])
			name = 'mz';
		    else if (a.accession == 'MS:1003061')
			name = 'name';

		    if (name)
			rdata[name] = a.value;
		}
	    }
	    else {
		user_msg("No spectrum attributes found! Some features may not work properly",404,false);
		user_log(null,"NO attributes found! Some features may not work properly",'warn');
	    }
	    user_log(null,"--------------------");
	    rdata['origin'] = full;
	    rdata[0]['usi'] = full;

	    rdata[0]['interpretations'] = [];
	    for (var i in rdata[0].mzs)
		rdata[0]['interpretations'].push('');

	    if (!rdata['name']) {
		if (_spectrum['name'])
		    rdata['name'] = _spectrum['name'];
		else
		    rdata['name'] = full;
	    }

	    _spectrum = rdata;
	    process_spectrum_data();

	    stuff_is_running(button,false);
	})
	.catch(error => {
	    stuff_is_running(button,false);
	    user_log(null,"ERROR fetching the USI::",'error');
	    user_log(null,error);
	    console.error(error);
            user_msg("ERROR fetching the USI: "+error,500,false);
	});

}

function allowDrop(event) {
    event.preventDefault();
    event.target.classList.add("drophere");
}
function stopDrop(event) {
    event.preventDefault();
    event.target.classList.remove("drophere");
}
function dropFile(event) {
    stopDrop(event);

    if (!event.dataTransfer.files)
	return false;

    var file = event.dataTransfer.files[0];
    reader = new FileReader();
    reader.onload = function(ev) {
        event.target.value = ev.target.result;
    };
    reader.readAsText(file);
}



function import_posted_spectrum(spectrum) {
    // console.log(JSON.stringify(spectrum,null,2));

    stuff_is_running(null,true);
    reset_forms();

    var dta = document.getElementById("dta_input");
    dta.value = "";

    if (spectrum.peptidoform)
	dta.value += "PEPTIDOFORMS "+ spectrum.peptidoform + "\n";
    if (spectrum.charge)
	dta.value += "CHARGES "+ spectrum.charge + "\n";
    if (spectrum.precmz)
	dta.value += "PRECURSORMZ "+ spectrum.precmz + "\n";

    if (spectrum.mzs && spectrum.intensities)
	for (var i in spectrum.mzs)
	    dta.value += spectrum.mzs[i] + "  " + spectrum.intensities[i] + "\n";
    else if (spectrum.peaks)
	for (var peak of spectrum.peaks)
	    dta.value += peak[0] + "  " + peak[1] + "\n";

    import_dta(null);
}


function import_dta(button) {
    var dta = document.getElementById("dta_input").value.trim();
    if (dta == "")
	return user_msg("Unable to load spectrum.  Please specify a valid peak list.",404,true);

    stuff_is_running(button,true);
    reset_forms('dta');

    var rdata = {};
    var mzs = [];
    var ints = [];
    var annots = [];
    _maxint = 0;
    for (var line of dta.split("\n")) {
	line = line.replace(":",' ');
	var pair = line.trim().split(/\s+/);
	var skip = false;

        if (pair[0] == "PEPTIDOFORMS" || pair[0] == "Peptide")
	    document.getElementById("pform_input").value = pair[1];
        else if (pair[0] == "CHARGES" || pair[0] == "Charge") {
            document.getElementById("charge_input").value = Number(pair[1]);
	    rdata['charge'] = Number(pair[1]);
	}
        else if (pair[0] == "PRECURSORMZ" || pair[0] == "m/z") {
            document.getElementById("precmz_input").value = Number(pair[1]);
	    rdata['mz'] = Number(pair[1]);
	}

	for (var p in [0,1])
	    if (isNaN(pair[p]))
		skip = true;
	if (skip) continue;

	if (pair[1]) {
	    mzs.push(Number(pair[0]));
	    ints.push(Number(pair[1]));

            if (Number(pair[1]) > _maxint)
                _maxint = Number(pair[1]);

	    if (pair[2])
		annots.push(pair[2]);
	    else
		annots.push('');
	}
    }
    rdata[0] = {};
    rdata[0]['mzs'] = mzs;
    rdata[0]['intensities'] = ints;
    rdata[0]['interpretations'] = annots;

    rdata['max_intensity'] = _maxint;
    rdata['name'] = "NO_MATCH";
    rdata['origin'] = "Peak List import";

    if (rdata[0].mzs.length < 1) {
	user_log(null, "Unable to import spectrum: NO peaks found!",'error');
	user_log(null, "  Please double-check input data.");
	stuff_is_running(button,false);
        return user_msg("Unable to import spectrum: <b>no peaks found</b>! Please double-check input data.",500,false);
    }

    user_msg("Successfully loaded spectrum with "+rdata[0].mzs.length+" peaks",200);
    user_log(null,"Successfully imported spectrum with "+rdata[0].mzs.length+" peaks",'run');
    user_log(null,"  M/Z:"+rdata["mz"]+"  Charge:"+rdata["charge"]);

    _spectrum = rdata;

    show_input('explore_menu');

    update_spectrum(button);
}


function update_spectrum(button,clear_annots=false) {
    if (button)
	button.classList.remove('blue');

    if (!_spectrum[0] || !_spectrum[0].mzs || !_spectrum[0].intensities)
        return user_msg("Unable to update spectrum data.  No spectrum has been loaded.",500,true);

    stuff_is_running(button,true);

    var pforms = document.getElementById("pform_input").value.trim();
    var charges = document.getElementById("charge_input").value.trim();
    document.getElementById("pform_input").value = pforms;
    document.getElementById("charge_input").value = charges;

    _peptidoforms = [];
    if (pforms == "") {
	user_msg("No peptidoform present; will annotate in sequence-free mode.  Use the Edit form to add one.",404,false);
        user_log(null, "No peptidoform present; will call annotator in sequence-free mode.",'warn');
    }
    else if (charges == "") {
        user_msg("No charge present; cannot use peptidoform to annotate without a charge. Use the Edit form if this is an error.",404,false);
        user_log(null, "No charge present; cannot use peptidoform to annotate without a charge; will call annotator in sequence-free mode.",'warn');
    }
    else {
	var zs = charges.split("+");
	var seqs = zs.length > 1 ? pforms.split("+") : [pforms];

	for (var i in zs) {
	    _peptidoforms[i] = {};
	    _peptidoforms[i].peptidoform_string = seqs[i];
	    _peptidoforms[i].peptide_sequence = seqs[i];  // validate_usi fixes this later...
	    _peptidoforms[i].charge = zs[i];
	}
    }

    if (clear_annots)
	_spectrum[0]['interpretations'] = [];

    validate_usi(button,false);
    if (button)
	addCheckBox(button,true);
}


function show_spectrum() {
    show_input('explore_menu');

    var chart = {};
    chart['type'] = 'scatter';
    chart['options'] = {};
    chart['options']['aspectRatio'] = 2.5;
    chart['options']['animation'] = true;
    chart['options']['spanGaps'] = true;
    //chart['options']['responsive'] = false;

    chart['options']['elements'] = {};
    chart['options']['elements']['line'] = {'borderWidth':1};
    chart['options']['elements']['point'] = {'hitRadius':5, 'radius':0};

    chart['options']['scales'] = {};
    chart['options']['scales']['x'] = {};
    //chart['options']['scales']['x']['min'] = 0;
    chart['options']['scales']['x']['title'] = {};
    chart['options']['scales']['x']['title']['display'] = true;
    chart['options']['scales']['x']['title']['text'] = 'm/z';
    chart['options']['scales']['x']['grid'] = {};
    chart['options']['scales']['x']['grid']['display'] = false;
    chart['options']['scales']['x']['border'] = {};
    chart['options']['scales']['x']['border']['color'] = '#999';
    chart['options']['scales']['x']['border']['z'] = 3;

    chart['options']['scales']['y'] = {};
    chart['options']['scales']['y']['position'] ='right';
    chart['options']['scales']['y']['min'] = 0;
    chart['options']['scales']['y']['grid'] = {};
    chart['options']['scales']['y']['grid']['display'] = false;
    chart['options']['scales']['y']['ticks'] = {};
    chart['options']['scales']['y']['ticks']['callback'] = (val) => (val.toExponential());
    // 0-1 relative scale
    chart['options']['scales']['y2'] = {};
    chart['options']['scales']['y2']['display'] = false;
    chart['options']['scales']['y2']['position'] ='left';
    chart['options']['scales']['y2']['min'] = 0;
    chart['options']['scales']['y2']['grid'] = {};
    chart['options']['scales']['y2']['grid']['display'] = true;
    chart['options']['scales']['y2']['ticks'] = {};
    chart['options']['scales']['y2']['ticks']['callback'] = (val) => (100*val/_maxint).toFixed(1)+"%";

    chart['options']['plugins'] = {};
    chart['options']['plugins']['tooltip'] = {'enabled':false};
//    chart['options']['plugins']['decimation'] = {'enabled':true};
    chart['options']['plugins']['legend'] = {'display':false};
    chart['options']['plugins']['title'] = {};
    chart['options']['plugins']['title']['display'] = true;
    chart['options']['plugins']['title']['text'] = _spectrum['origin'];
    chart['options']['plugins']['title']['color'] = '#2c99ce';
    chart['options']['plugins']['title']['padding'] = 0;

    var subt = _spectrum['name'];
    if (subt.includes("/"))
	subt = subt.replace("/",' ') + "+";
    chart['options']['plugins']['subtitle'] = {};
    chart['options']['plugins']['subtitle']['display'] = true;
    chart['options']['plugins']['subtitle']['text'] = subt;
    chart['options']['plugins']['subtitle']['color'] = '#000';
    chart['options']['plugins']['subtitle']['padding'] = {'bottom':50};

    // inline plugin to display m/z and massdiff
    chart['plugins'] = [{}];
    chart['plugins'][0]['afterDraw'] = function(chart, args, options) {
	chart.ctx.fillStyle = '#2c99ce';
	if (_spectrum['mz'])
	    chart.ctx.fillText("Exp.m/z: "+_spectrum['mz'],0,10);

	chart.ctx.fillStyle = '#000';
	if (_peptidoforms[0] && _peptidoforms[0].ion_mz) {
	    var txt = "m/z: "+_peptidoforms[0].ion_mz.toFixed(4);
	    if (_spectrum['mz'])
		txt += " ("+(1000000/_peptidoforms[0].ion_mz*(Number(_spectrum['mz'])-_peptidoforms[0].ion_mz)).toFixed(1)+" ppm)";
	    chart.ctx.fillText(txt,24,23);
	}
    };

    chart['options']['plugins']['zoom'] = {};
    chart['options']['plugins']['zoom']['pan'] = {};
    chart['options']['plugins']['zoom']['pan']['enabled'] = true;
    chart['options']['plugins']['zoom']['pan']['mode'] = 'x';
    chart['options']['plugins']['zoom']['pan']['modifierKey'] = 'ctrl';
    chart['options']['plugins']['zoom']['pan']['threshold'] = 0.2;
    chart['options']['plugins']['zoom']['pan']['scaleMode'] = 'y';
    chart['options']['plugins']['zoom']['zoom'] = {};
    chart['options']['plugins']['zoom']['zoom']['mode'] = 'x';
    chart['options']['plugins']['zoom']['zoom']['wheel'] = {};
    chart['options']['plugins']['zoom']['zoom']['wheel']['enabled'] = true;
    chart['options']['plugins']['zoom']['zoom']['wheel']['speed'] = 0.1;
    chart['options']['plugins']['zoom']['zoom']['drag'] = {};
    chart['options']['plugins']['zoom']['zoom']['drag']['enabled'] = true;
    chart['options']['plugins']['zoom']['zoom']['drag']['backgroundColor'] = 'rgba(44,153,206,0.3)';
    chart['options']['plugins']['zoom']['zoom']['drag']['borderColor'] = 'rgba(44,153,206,1)';
    chart['options']['plugins']['zoom']['zoom']['drag']['borderWidth'] = 1;
    chart['options']['plugins']['zoom']['limits'] = {};
    //chart['options']['plugins']['zoom']['limits']['x'] = {'min': data['mzmin'], 'max': data['mzmax']};
    chart['options']['plugins']['zoom']['limits']['x'] = {};
    chart['options']['plugins']['zoom']['limits']['x']['min'] = 'original';
    chart['options']['plugins']['zoom']['limits']['x']['max'] = 'original';
    chart['options']['plugins']['zoom']['limits']['y'] = {'min':0, 'max':'original'};
    chart['options']['plugins']['zoom']['zoom']['onZoomComplete'] = function ({ chart }) {
	if (chart.getZoomLevel() == 1.0)
            document.getElementById("resetzoom_button").classList.remove('blue');
	else
            document.getElementById("resetzoom_button").classList.add('blue');
    }

    chart['options']['plugins']['datalabels'] = {};
    chart['options']['plugins']['datalabels']['rotation'] = '270';
    chart['options']['plugins']['datalabels']['display'] = 'auto';
    chart['options']['plugins']['datalabels']['align'] = 'end';
    chart['options']['plugins']['datalabels']['anchor'] = 'end';
    chart['options']['plugins']['datalabels']['clip'] = true;
    chart['options']['plugins']['datalabels']['formatter'] = function(value, context) {
	let datalabel = null;
        if (value.ion && value.ion !== null)
	    datalabel = value.ion;
        return datalabel;
    };
    chart['options']['plugins']['datalabels']['color'] = function(context) {
        return context.dataset.borderColor;
    };

    chart['data'] = {};
    chart['data']['datasets'] = [];

    var all_datasets = {};

    for (var idx in _spectrum[0]['mzs']) {
	const {series, point, datapoints} = get_datapoints(idx,scale=1.0);
	if (!all_datasets[series]) {
            all_datasets['label'+series] = {};
            all_datasets['label'+series]['label'] = 'label: '+series;
            all_datasets['label'+series]['type'] = 'scatter';
            all_datasets['label'+series]['yAxisID'] = 'y2';
	    all_datasets['label'+series]['pointRadius'] = 1;
            all_datasets['label'+series]['backgroundColor'] = _ion_colors[series];
            all_datasets['label'+series]['borderColor'] = _ion_colors[series];
            all_datasets['label'+series]['data'] = [];

	    all_datasets[series] = {};
	    all_datasets[series]['label'] = series;
	    all_datasets[series]['type'] = 'scatter';
	    all_datasets[series]['showLine'] = true;
	    all_datasets[series]['backgroundColor'] = _ion_colors[series];
	    all_datasets[series]['borderColor'] = _ion_colors[series];
	    all_datasets[series]['data'] = [];
	}
	all_datasets[series]['data'].push(...datapoints);
	all_datasets['label'+series]['data'].push(point);
    }

    for (var set in all_datasets)
	chart['data']['datasets'].push(all_datasets[set]);


    if (_chartdata)
        _chartdata.destroy();
    _chartdata = new Chart("viewspectrum_canvas", chart);

    toggle_box("viewspectrum_toolbar",true);
}

function get_datapoints(index,scale=1.0) {
    var series = 'n/a';
    if (_spectrum[0]['_ion_series'][index])
	series = _spectrum[0]['_ion_series'][index];

    var point = {'x':_spectrum[0]['mzs'][index], 'y':scale*_spectrum[0]['intensities'][index], 'ion':_spectrum[0]['interpretations'][index].split('/')[0]};

    var points = [];
    points.push({'x':_spectrum[0]['mzs'][index], 'y':0});
    points.push(point);
    points.push({'x':_spectrum[0]['mzs'][index], 'y':0});

    return {
	series: series,
	point: point,
	datapoints: points
    };
}


function add_datapoint(index,scale=1.0) {
    var color = '#999';
    if (_spectrum[0]['_ion_series'][index])
	color = _ion_colors[_spectrum[0]['_ion_series'][index]];

    var datapoint = {};
    datapoint['showLine'] = true;
    datapoint['parsing'] = false;
    datapoint['pointRadius'] = 0;
    datapoint['borderColor'] = color;
    datapoint['pointBackgroundColor'] = datapoint['borderColor'];
    datapoint['data'] = [];
    datapoint['data'].push({'x':_spectrum[0]['mzs'][index], 'y':scale*_spectrum[0]['intensities'][index]});
    datapoint['data'].push({'x':_spectrum[0]['mzs'][index], 'y':0});
    datapoint['label'] = _spectrum[0]['interpretations'][index].split('/')[0];

    return datapoint;
}


function chart_ctrl(what) {
    if (!_chartdata)
        return;

    if (what == 'reset') {
	_chartdata.resetZoom();
	document.getElementById("resetzoom_button").classList.remove('blue');
    }

    else if (what.startsWith('zoom')) {
        var scale = 1.4;
	if (what.startsWith('zoomout'))
            scale = 1/scale;
        _chartdata.zoom(scale);

	if (_chartdata.getZoomLevel() == 1.0)
            document.getElementById("resetzoom_button").classList.remove('blue');
	else
            document.getElementById("resetzoom_button").classList.add('blue');
    }

    else if (what.startsWith('pan')) {
        var deltax = 150;
        if (what.startsWith('panright'))
            deltax = -deltax;
        if (what.endsWith('fast'))
            deltax = 5*deltax;
        _chartdata.pan({'x':deltax,'y':0});
    }

    else if (what == 'labels') {
	button = document.getElementById("togglelabels_button");

	if (button.classList.contains('blue')) {
	    _chartdata['options']['plugins']['datalabels']['display'] = 'auto';
            button.classList.remove('blue');
	}
	else {
	    _chartdata['options']['plugins']['datalabels']['display'] = false;
            button.classList.add('blue');
	}
	_chartdata.update();
    }

    else if (what.startsWith('zpmode')) {
        button = document.getElementById("toggle"+what+"_button");

        if (button.classList.contains('blue'))
            button.classList.remove('blue');
        else
            button.classList.add('blue');

	var axes = '';
	for (var axis of ['x','y']) {
            if (document.getElementById("togglezpmode"+axis+"_button").classList.contains('blue'))
		axes += axis;
	}

	_chartdata['options']['plugins']['zoom']['pan']['mode'] = axes;
	_chartdata['options']['plugins']['zoom']['zoom']['mode'] = axes;
    }

}


function user_msg(what,code=400,remove=true) {
    var div = document.createElement("div");
    div.className = 'code'+code;
    div.innerHTML = what;

    var span = document.createElement("span");
    span.className = 'bigx';
    span.title = "dismiss this message";
    span.innerHTML = "&times;"
    span.onclick= function(){div.remove();};
    div.append(span);

    document.getElementById("useralerts").append(div);

    if (remove) {
        setTimeout(function() { div.style.opacity = "0"; }, 3000 );
	setTimeout(function() { div.remove(); }, 3500 );
    }
    return null;
}


function add_to_user_log(logarr) {
    for (var log of logarr)
        user_log(null, log);
}

function user_log(where,what,msg_type='',cr=true,clear=false) {
    if (!where)
	where = document.getElementById("command_output");
    if (!where.className) {
	where.className = "cmdout";
	where.style.marginTop = '-65px';
	clear = true;
    }

    if (clear)
	where.innerHTML = "";

    if (msg_type == 'run')
	where.innerHTML += "\n&#128640; ";
    else if (msg_type == 'warn')
	where.innerHTML += "&#128679; ";
    else if (msg_type == 'error')
	where.innerHTML += "&#128721; ";
    where.innerHTML += what;
    if (cr)
	where.innerHTML += "\n";

    where.scrollTop = where.scrollHeight;
}


function show_input(who) {
    if (typeof who === 'string')
	who = document.getElementById(who);

    for (var input of ['import_menu', 'edit_menu', 'explore_menu','export_menu','about_menu','viewlog_menu']) {
	if (who.id == input) {
	    document.getElementById(who.id.replace("_menu","")+"_div").classList.replace("hideit", "specinput");
	    who.classList.add("current");
	}
	else {
	    document.getElementById(input.replace("_menu","")+"_div").className = "hideit";
	    document.getElementById(input).classList.remove("current");
	}
    }
}


function process_spectrum_data() {
    var data = _spectrum[0]; // just consider the first one  FIXME??

    if (!data || !data.mzs || !data.intensities)
        throw "Incomplete spectrum data!";

    if (!isSorted(data.mzs)) {
        console.log("Peak data NOT sorted :: attempting to sort...");
        var sorted = sortLinkedArrays(data.mzs,data.intensities,data.interpretations);
        data.mzs = sorted[0];
        data.intensities = sorted[1];
        data.interpretations = sorted[2];
        console.log("...data re-sorted OK");
    }

    var precmz = null;
    var charge = null;
    var isotar = null;
    var isolow = null;
    var isoupp = null;
    if (data && data.attributes && data.attributes.length>0) {
        for (var att of data.attributes) {
            if (att.accession == "MS:1000041") charge= att.value;

            if (att.accession == "MS:1000744") precmz = att.value;  // preferred
            if (att.accession == "MS:1000827") {
		isotar = att.value;
		if (!precmz)
		    precmz = att.value;
	    }

            if (att.accession == "MS:1000828") isolow = att.value;
            if (att.accession == "MS:1000829") isoupp = att.value;
	}
    }
    if (precmz)
	document.getElementById("precmz_input").value = precmz;
    if (charge && document.getElementById("charge_input").value == '')
	document.getElementById("charge_input").value = charge;
    if (isotar)
        document.getElementById("isotarget_input").value = isotar;
    if (isolow)
        document.getElementById("isolower_input").value = isolow;
    if (isotar)
        document.getElementById("isoupper_input").value = isoupp;

    var has_annots = false;
    for (var annot of data.interpretations)
	has_annots ||= annot?true:false;

    if (has_annots)
        add_annotation_form();
    else
        annotate_peaks(null);

}

// unused...
function prepare_lorikeet_data() {
    var data = _spectrum[0]; // just consider the first one  FIXME??

    var s = {};
    s.scanNum = 0;
    s.precursorMz = _spectrum['mz'] ? _spectrum['mz'] : 0;
    s.fileName = " spectrum";
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

    for (var i in data.mzs) {
        var usipeaks = [Number(data.mzs[i]), Number(data.intensities[i])];
        s.ms2peaks.push(usipeaks);
        if (Number(data.mzs[i]) > maxMz) maxMz = Number(data.mzs[i]);
        has_spectrum = true;
    }
    s.minDisplayMz = 0.01;
    s.maxDisplayMz = maxMz+1.0;

    if (_peptidoforms) {
	var isobaric_unimods = [ "UNIMOD:214", "UNIMOD:532", "UNIMOD:533", "UNIMOD:730", "UNIMOD:731", "UNIMOD:737", "UNIMOD:738", "UNIMOD:739", "UNIMOD:889", "UNIMOD:984", "UNIMOD:985", "UNIMOD:1341", "UNIMOD:1342", "UNIMOD:2015", "UNIMOD:2016", "UNIMOD:2017", "UNIMOD:2050" ];

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

    if (has_spectrum) {
	_spectrum.lori_data = s;
	renderLorikeet("explore_div",s.pforms[0]?0:null);

	add_annotation_form();
	// annotate_peaks();
    }
    else {
	_spectrum.lori_data = {};
    }

}
// end unused Lorikeet code


function isSorted(arr) {
    for(var i=0; i<arr.length-1; i++)
	if (arr[i] > arr[i+1])
	    return false;
    return true;
}

function sortLinkedArrays(arr1,arr2,arr3) {
    var hoa2 = {};
    var hoa3 = {};
    for (var i in arr1) {
	hoa2[arr1[i]] = arr2[i];
	hoa3[arr1[i]] = arr3[i];
    }

    arr1.sort(function(a, b){return a - b});

    arr2 = [];
    arr3 = [];
    for (var i in arr1) {
	arr2.push(Number(hoa2[arr1[i]])); // also get rid of pesky strings
	arr3.push(hoa3[arr1[i]]);
    }
    for (var i in arr1)
	arr1[i] = Number(arr1[i]); // get rid of pesky strings

    return [arr1, arr2, arr3];
}

// not used:
function renderLorikeet(divid,pfidx) {
    var s = _spectrum.lori_data;
    clear_element(divid);

    $('#'+divid).specview({
	"sequence":pfidx!=null ? s.pforms[pfidx].sequence : '',
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
    });

}


function download(button,format='tsv') {
    if (!_spectrum[0] || !_spectrum[0].mzs || !_spectrum[0].intensities)
        return user_msg("Unable to download.  No spectrum has been loaded.",404,true);

    user_log(null, "Sending "+format+" data...",'run');

    var tsv = null;

    for (var idx in _spectrum[0]['mzs']) {
	tsv += _spectrum[0]['mzs'][idx];
	tsv += "\t" + _spectrum[0]['intensities'][idx];
	if (_spectrum[0]['interpretations'][idx])
	    tsv += "\t" + _spectrum[0]['interpretations'][idx];
	tsv += "\n";
    }

    if (tsv) {
        var pforms = '';
        var charges = '';
        var plus = '';
        for (var pi in _peptidoforms) {
            pforms += plus + _peptidoforms[pi].peptidoform_string;
            charges += plus + _peptidoforms[pi].charge;
            plus = "+";
        }
	if (pforms)
	    tsv = "PEPTIDOFORMS\t"+pforms+"\n"+"CHARGES\t"+charges+"\n"+tsv;
	if (_spectrum['mz'])
	    tsv = "PRECURSORMZ\t"+_spectrum['mz']+"\n"+tsv;


        var filename =  _peptidoforms[0] ? _peptidoforms[0].peptidoform_string : 'quetzal_peakdata';

	var downloadLink = document.createElement("a");
        downloadLink.download = filename + '.' + format;
	downloadLink.href = "data:text/tab-separated-values," + encodeURIComponent(tsv);
	downloadLink.click();

	addCheckBox(button,true);
    }
    else {
	user_msg("No spectrum data available!",500,false);
	user_log(null, "No spectrum data available!",'error');
        show_input('viewlog_menu');
    }
}


function generate_figure(button,format,download=false) {
    if (!_spectrum[0] || !_spectrum[0].mzs || !_spectrum[0].intensities)
        return user_msg("Unable to generate "+format+" figure.  No spectrum has been loaded.",404,true);

    user_log(null, "Generating "+format+" figure...",'run');

    // check if empty annotations....TODO
    // verify format

    review_spectrum_attributes();

    _spectrum[0]['extended_data'] = {};

    var user_parameters = {};
    user_parameters.skip_annotation = true;

    user_parameters.create_svg = false;
    user_parameters.create_pdf = false;
    user_parameters["create_"+format] = true;

    for (var field of ["xmin", "xmax", "ymax", "mask_isolation_width", "minimum_labeling_percent"]) {
	var val = document.getElementById(field+"_input").value.trim();
	if (val != "")
	    user_parameters[field] = Number(val);
	document.getElementById(field+"_input").value = val;
    }
    user_parameters["dissociation_type"] = document.getElementById("dissociation_type_input").value;
    user_parameters["isobaric_labeling_mode"] = document.getElementById("isobaric_labeling_mode_input").value;

    for (var field of ["show_sequence", "show_b_and_y_flags", "show_coverage_table", "show_precursor_mzs",
		       "label_neutral_losses", "label_internal_fragments", "label_unknown_peaks", "show_mass_deltas", "show_usi"]) {
	if (document.getElementById(field+"_input").checked)
            user_parameters[field] = true;
	else
            user_parameters[field] = false;
    }

    stuff_is_running(button,true);
    if (!download)
        document.getElementById("spectrum_preview").innerHTML = '';

    _spectrum[0]['extended_data']['user_parameters'] = user_parameters;

    var mztol = Number(document.getElementById("peakmztol_input").value.trim());
    var url = _api['annotate']+"?tolerance="+mztol;
    fetch(url, {
        method: 'post',
        headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json'
        },
        body: JSON.stringify([_spectrum[0]])
    })
        .then(response => response.json())
        .then(annot_data => {
	    stuff_is_running(button,false);
	    _spectrum[0]['extended_data'] = null;
	    add_to_user_log(annot_data.status.log);
	    if (annot_data.status.status == "ERROR")
		throw annot_data.status.error_code + " :: " + annot_data.status.description;

	    var file_data = annot_data['annotated_spectra'][0]['extended_data'];

	    if (download) {
		var filename = _peptidoforms[0] ? _peptidoforms[0].peptidoform_string : 'quetzal_spectrum';

		var downloadLink = document.createElement('a');
		downloadLink.target = '_blank';
		downloadLink.download = filename + '.' + format;

		if (format == 'pdf') {
		    // avoid ISO8859-1 foolery...
		    var blob = new Blob([Uint8Array.from(file_data['pdf'], c => c.charCodeAt(0))], { type: 'application/pdf' });
		    var URL = window.URL || window.webkitURL;
		    var downloadUrl = URL.createObjectURL(blob);
		    downloadLink.href = downloadUrl;
		    downloadLink.click();
		    URL.revokeObjectURL(downloadUrl);
		}
		else {
		    downloadLink.href = "data:image/svg+xml;charset=utf-8,"+encodeURIComponent(file_data['svg']);
		    downloadLink.click();
		}
	    }
	    else {
		var img = document.createElement('img');
		img.src = "data:image/svg+xml;charset=utf-8,"+encodeURIComponent(file_data['svg']);
		document.getElementById("spectrum_preview").append(img);
		document.getElementById("spectrum_preview").append(document.createElement("br"));
		var legend = document.createElement("p");
		legend.style.margin = '0px 30px';
		legend.style.textAlign = 'justify';
                legend.append(file_data['figure_legend']);
		img.onload = function () { legend.style.width = img.offsetWidth+'px'; }
                document.getElementById("spectrum_preview").append(legend);
		document.getElementById("spectrum_preview").append(document.createElement("br"));
	    }

        })
	.catch(error => {
	    stuff_is_running(button,false);
            user_log(null,"ERROR annotating:",'error');
            user_log(null,error);
	    console.error(error);
            user_msg("ERROR annotating: "+error,500,false);
        });
}


function toggle_box(box,open=false,close=false) {
    var elebox = document.getElementById(box);
    if ((elebox.style.visibility == "visible" && !open) || close) {
	elebox.style.visibility = "hidden";
	elebox.style.opacity = "0";
	if (document.getElementById(box+"_button"))
	    document.getElementById(box+"_button").classList.remove("on");
	if (document.getElementById(box+"_toolbarbutton"))
	    document.getElementById(box+"_toolbarbutton").classList.remove("blue");
    }
    else {
	elebox.style.visibility = "visible";
	elebox.style.opacity = "1";
	if (document.getElementById(box+"_button"))
	    document.getElementById(box+"_button").classList.add("on");
        if (document.getElementById(box+"_toolbarbutton"))
            document.getElementById(box+"_toolbarbutton").classList.add("blue");

	if ((elebox.offsetLeft + elebox.offsetWidth) < 200)
	    elebox.style.left = '10px';
	if ((elebox.offsetTop + elebox.offsetHeight) < 200)
	    elebox.style.top = '10px';
    }
}


// for use with "examples" and "recents" pop-ups
function pick_box_example(anchor) {
    document.getElementById('usi_input').value = anchor.innerHTML;
    var button = document.getElementById("usiprovider_input");
    if (button.value != "ProteomeCentral") {
	button.value = "ProteomeCentral";
	set_usi_url(button);
    }
    validate_usi(document.getElementById("usi_button"),true);
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


function user_annotations(button) {
    button.classList.remove('blue');

    if (!_spectrum[0] || !_spectrum[0].mzs || !_spectrum[0].intensities)
        return user_msg("Unable to save annotations.  No spectrum has been loaded.",500,true);

    addCheckBox(button,true);

    user_log(null, "Updating annotations via user input...",'run');
    var comments = 0;
    for (var idx in _spectrum[0]['interpretations']) {
	_spectrum[0]['interpretations'][idx] = document.getElementById("peak_annotation_"+idx).value;
	if (_spectrum[0]['interpretations'][idx].includes('Comment:')) {
	    document.getElementById("peak_annotation_"+idx).style.background = '#ec1';
	    comments++;
	}
	else
	    document.getElementById("peak_annotation_"+idx).style.background = '';

	if (document.getElementById("peak_annotation_ppm_"+idx).value)
	    _spectrum[0]['interpretations'][idx] += '/'+document.getElementById("peak_annotation_ppm_"+idx).value;
    }

    if (comments > 0) {
	user_log(null, "Sending spectrum with "+comments+" user-annotated peaks for review...",'run');

	review_spectrum_attributes();
	_spectrum[0]['extended_data'] = {};
	var user_parameters = {};
	user_parameters.skip_annotation = true;
	user_parameters["dissociation_type"] = document.getElementById("dissociation_type_input").value;
	user_parameters["isobaric_labeling_mode"] = document.getElementById("isobaric_labeling_mode_input").value;
	_spectrum[0]['extended_data']['user_parameters'] = user_parameters;

	var url = _api['annotate']+"?tolerance="+Number(document.getElementById("peakmztol_input").value.trim());
	fetch(url, {
            method: 'post',
            headers: {
		'Accept': 'application/json',
		'Content-Type': 'application/json'
            },
            body: JSON.stringify([_spectrum[0]])
	})
            .then(response => response.json())
            .then(status_data => {
		_spectrum[0]['extended_data'] = null;
		add_to_user_log(status_data.status.log);
		if (status_data.status.status == "ERROR")
                    throw status_data.status.error_code + " :: " + status_data.status.description;
		user_msg("Detected user comments on "+comments+" peak annotations. This spectrum has been sent for review by the Quetzal team. Thank you for your feedback!",404,false);
		add_annotation_table();
            })
            .catch(error => {
		user_log(null,"ERROR sending:",'error');
		user_log(null,error);
		console.error(error);
		user_msg("ERROR sending: "+error,500,false);
            });
    }
    else {
	add_annotation_table();
    }
}


function review_spectrum_attributes() {
    user_log(null, " (verifying attributes...)");

    var spec_data = _spectrum[0];
    var pform = _peptidoforms[0] ? _peptidoforms[0].peptidoform_string : '';
    var charge = _peptidoforms[0] ? _peptidoforms[0].charge : 1;
    var precmz =  _spectrum['mz'] ? _spectrum['mz'] : null;

    if (!spec_data["attributes"])
        spec_data["attributes"] = [];

    var addMS1003169 = true;
    var addMS1000041 = true;
    var addMS1000827 = precmz ? true:false;
    for (var att of spec_data['attributes']) {
	if (att.accession == "MS:1003169") {
            att.value = pform;
            addMS1003169 = false;
        }
        else if (att.accession == "MS:1000041") {
            att.value = charge;
            addMS1000041 = false;
        }
        else if (att.accession == "MS:1000827" && precmz) {
            att.value = precmz;
            addMS1000827 = false;
        }
	else if (!att.value)
	    att.value = "n/a";
    }

    if (addMS1003169) {
	var att = {};
	att.accession = 'MS:1003169';
	att.name = 'proforma peptidoform sequence';
	att.value = pform;
	spec_data["attributes"].push(att);
    }
    if (addMS1000041) {
        var att = {};
        att.accession = 'MS:1000041';
        att.name = 'charge state';
        att.value = charge;
        spec_data["attributes"].push(att);
    }
    if (addMS1000827) {
        var att = {};
        att.accession = 'MS:1000827';
        att.name = 'isolation window target m/z';
        att.value = precmz;
        spec_data["attributes"].push(att);
    }

}


function annotate_peaks(button,wasauto=true) {
    if (button)
	button.classList.remove('blue');

    if (!_spectrum[0] || !_spectrum[0].mzs || !_spectrum[0].intensities)
        return user_msg("Unable to annotate.  No spectrum has been loaded.",500,true);

    user_log(null, "Calling annotator service...",'run');
    stuff_is_running(button,true);

    review_spectrum_attributes();

    _spectrum[0]['extended_data'] = {};
    _spectrum[0]['extended_data']['user_parameters'] = {};
    if (!wasauto) {
	_spectrum[0]['extended_data']['user_parameters']["dissociation_type"] = document.getElementById("dissociation_type_input").value;
	_spectrum[0]['extended_data']['user_parameters']["isobaric_labeling_mode"] = document.getElementById("isobaric_labeling_mode_input").value;
    }

    var pform = _peptidoforms[0] ? _peptidoforms[0].peptidoform_string : '';

    var url = _api['annotate']+"?resultType=full&tolerance=";
    var mztol = Number(document.getElementById("peakmztol_input").value.trim());
    for (var att of _spectrum[0]['attributes']) {
	if (att.accession == "MS:10000512" &&
	    att.value.startsWith("ITMS")) {
	    user_log(null, "(Low-res m/z detected (ITMS))");
	    if (wasauto)
		mztol = 500;
	    else if (mztol<300)
		user_msg("Warning: MS/MS spectrum appears to be of low resolution. You may want to increase the peak match tolerance and re-run the annotator.",404);
	}
    }

    if (isNaN(mztol) || mztol<1) {
	user_log(null,"(Warning: invalid peak match tolerance ["+mztol+"]. Setting to 10ppm)",'warn');
	user_msg("Warning: invalid peak match tolerance ("+mztol+"). Setting to 10ppm.",404);
	mztol = 10;
    }
    else
        user_log(null,"(Using peak match tolerance of "+mztol+"ppm)");

    document.getElementById("peakmztol_input").value = mztol;
    url += mztol;

    fetch(url, {
	method: 'post',
	headers: {
	    'Accept': 'application/json',
	    'Content-Type': 'application/json'
	},
	body: JSON.stringify([_spectrum[0]])
    })
	.then(response => response.json())
	.then(annot_data => {
            _spectrum[0]['extended_data'] = null;
            add_to_user_log(annot_data.status.log);
            if (annot_data.status.status == "ERROR")
                throw annot_data.status.error_code + " :: " + annot_data.status.description;

	    _spectrum[0]['interpretations'] = annot_data['annotated_spectra'][0]['interpretations'];
	    // in case some peaks have gone "missing"...
	    _spectrum[0]['mzs'] = annot_data['annotated_spectra'][0]['mzs'];
	    _spectrum[0]['intensities'] = annot_data['annotated_spectra'][0]['intensities'];

	    if (annot_data['annotated_spectra'][0]['extended_data']['inferred_attributes']) {
		if (annot_data['annotated_spectra'][0]['extended_data']['inferred_attributes']['used dissociation type']) {
		    var frag = annot_data['annotated_spectra'][0]['extended_data']['inferred_attributes']['used dissociation type'];
		    if (frag != document.getElementById("dissociation_type_input").value)
			user_msg("Peaks annotated using dissociation type = "+frag,404);
		    document.getElementById("dissociation_type_input").value = frag;
		    user_log(null, "Peaks annotated using dissociation type = "+frag);
		    _spectrum[0]['_ions_annotated'] = frag;
		}

                if (annot_data['annotated_spectra'][0]['extended_data']['inferred_attributes']['used isobaric labeling mode']) {
                    var label = annot_data['annotated_spectra'][0]['extended_data']['inferred_attributes']['used isobaric labeling mode'];
                    if (label != document.getElementById("isobaric_labeling_mode_input").value)
                        user_msg("Peaks annotated using isobaric labeling mode = "+label,404);
                    document.getElementById("isobaric_labeling_mode_input").value = label;
                    user_log(null, "Peaks annotated using isobaric labeling mode = "+label);
                }

	    }

	    add_annotation_form(mztol);
	    stuff_is_running(button,false);
        })
        .catch(error => {
	    stuff_is_running(button,false);
            user_log(null,"ERROR annotating:",'error');
            user_log(null,error);
	    console.error(error);
            user_msg("ERROR annotating: "+error,500,false);
	});
}


function extract_ion_series() {
    if (!_spectrum[0]['interpretations'])
	return;

    _spectrum[0]['_ion_series'] = [];
    _spectrum[0]['_ion_table'] = {};

    for (var annot of _spectrum[0]['interpretations']) {
        var what = annot.split('/')[0];

	var mion = what.match(/[+-]/) ? false : true;
	var inum = what.match(/^.\d+/);
	var chrg = 1;
	if (what.indexOf('^',-1) >= 0)
	    chrg = Number(what.substr(-1,1));

	var ion = 'other';
        if (what.startsWith("0@"))
            ion = 'other';
        else if (what.startsWith("?"))
            ion = '?';
        else if (what.startsWith("p") || what.includes("@p"))
	    ion = 'prec';
        else if (what.startsWith("I"))
            ion = 'I';
        else if (what.startsWith("r"))
	    ion = 'rep';
        else if (what.startsWith("m"))
	    ion = 'int';
        else if (what.startsWith("f"))
	    ion = 'mol';
        else if (what.startsWith("a"))
	    ion = 'a';
        else if (what.startsWith("b"))
	    ion = 'b';
        else if (what.startsWith("c"))
	    ion = 'c';
        else if (what.startsWith("x"))
            ion = 'x';
        else if (what.startsWith("y"))
            ion = 'y';
        else if (what.startsWith("z"))
            ion = 'z';

	_spectrum[0]['_ion_series'].push(ion);

	for (var series of _backbone_ions) {
	    if (ion == series) {
		var seriesion = "+"+chrg+inum;
		if (mion)
		    _spectrum[0]['_ion_table'][seriesion] = true;
		else if (!_spectrum[0]['_ion_table'][seriesion])
		    _spectrum[0]['_ion_table'][seriesion] = false;
	    }
	}
    }

    show_spectrum();

    if (_peptidoforms[0])
	add_ion_table();
}


function add_annotation_form(mztol=null) {
    add_annotation_table(mztol);

    var annot_form = document.getElementById("annotation_form");
    annot_form.innerHTML = '';

    for (var idx in _spectrum[0]['mzs']) {
        for (var col of ["mzs", "intensities", "interpretations"]) {
            var span = document.createElement("span");

            var val = _spectrum[0][col][idx];
            if (col == "interpretations") {
                var input = document.createElement("input");
                input.id = "peak_annotation_"+idx;
                input.size = 40;
                input.value = val.split('/')[0];
		input.setAttribute('oninput', "document.getElementById('save_input').classList.add('blue')");
                annot_form.append(input);

		input = document.createElement("input");
                input.id = "peak_annotation_ppm_"+idx;
                input.size = 10;
		input.setAttribute('oninput', "document.getElementById('save_input').classList.add('blue')");
                annot_form.append(input);
                if (val.includes('/'))
                    input.value = val.split('/')[1];

		span.className = "buttonlike";
		span.title = "Clear annotation values for this row";
		span.setAttribute('onclick', "document.getElementById('peak_annotation_"+idx+"').value='';document.getElementById('peak_annotation_ppm_"+idx+"').value='';document.getElementById('save_input').classList.add('blue')");
		span.innerHTML = "&times;"
            }
            else {
                span.append(val);
	    }

            annot_form.append(span);
	}
    }
}


function add_ion_table() {
    var table = document.createElement("table");
    table.id = "detected_ion_table";
    table.className = "annot prox";

    var tr = document.createElement("tr");
    var td = document.createElement("td");
    td.colSpan = '99';
    td.className = "rep";
    td.append('Ion Series');
    if (_spectrum[0]['_ions_annotated'])
	td.append(' ('+_spectrum[0]['_ions_annotated']+')');
    tr.append(td);
    table.append(tr);

    table.append(get_peptide_row());

    for (var series of _backbone_ions) {
	var first = true;
	for (var chg of [1,2,3,4,5]) {
	    var show = false;
	    tr = document.createElement("tr");

            td = document.createElement("td");
	    if (first) {
		tr.style.borderTop = '2px solid black';
		td.style.color = 'white';
		td.style.background = 'black';
		td.append(series);
	    }
	    else
		td.className = "rep";
            tr.append(td);

            td = document.createElement("td");
            td.className = "rep";
	    td.append("("+chg+"+)");
	    tr.append(td);

	    for (var i in _peptidoforms[0].peptide_sequence) {
		var pos = 'abc'.includes(series) ? Number(i)+1 : Number(_peptidoforms[0].peptide_sequence.length) - i;

		td = document.createElement("td");
		td.append(pos);
		td.style.color = 'white';

                //var seriesion = "+"+chg+series+('abc'.includes(series) ? nterm:cterm);
                var seriesion = "+"+chg+series+pos;
                if (_spectrum[0]['_ion_table'][seriesion]) {
		    td.style.background = _ion_colors[series];
		    show = true;
		    first = false;
		}
                else if (_spectrum[0]['_ion_table'][seriesion] === false) {
                    td.style.background = _ion_colors[series];
                    td.style.filter = "brightness(65%)";
		    show = true;
		    first = false;
		}
		tr.append(td);
            }
	    if (show)
		table.append(tr);
        }
    }

    table.append(get_peptide_row());

    clear_element("ion_div");
    document.getElementById("ion_div").append(table);
}

function get_peptide_row() {
    var tr = document.createElement("tr");
    var td = document.createElement("th");
    tr.append(td);


    td = document.createElement("th");
    if (_peptidoforms[0].terminal_modifications && _peptidoforms[0]['terminal_modifications']['nterm']) {
	td.append('n');
        td.style.background = '#ec1';
	td.style.textAlign = 'right';
        var mod = _peptidoforms[0]['terminal_modifications']['nterm'];
        td.title = mod.residue_string;
        td.title += " ("+mod.delta_mass+")";
    }
    tr.append(td);

    for (var idx in _peptidoforms[0].peptide_sequence) {
        td = document.createElement("th");
        td.append(_peptidoforms[0].peptide_sequence[idx]);

        if (_peptidoforms[0].residue_modifications && _peptidoforms[0]['residue_modifications'][Number(idx)+1]) {
            td.style.background = '#ec1';
            var mod = _peptidoforms[0]['residue_modifications'][Number(idx)+1];
            td.title = mod.residue_string;
            if (mod.delta_mass > 0.0)
                td.title += " ("+mod.delta_mass+")";
            else if (mod.labile_delta_mass > 0.0)
                td.title += " (labile:"+mod.labile_delta_mass+")";
        }

        tr.append(td);
    }

    return tr;
}


function add_annotation_table(mztol=null) {
    extract_ion_series();

    var annot_data = _spectrum[0];
    var pform = _peptidoforms[0] ? _peptidoforms[0].peptidoform_string : 'n/a';

    var table = document.createElement("table");
    table.id = "full_annotation_table";
    table.className = "annot prox";

    var tr = document.createElement("tr");
    var td = document.createElement("td");
    td.colSpan = '13';
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
    tr.style.top = '87px';
    tr.style.zIndex = '5';
    mztol = mztol ?  " [mztol="+mztol+"ppm]" : '';
    for (var col of ["m/z", "intensity", "norm", "interpretation"+mztol].concat(_ion_list)) {
	td = document.createElement("th");
	td.append(col);
	tr.append(td);
    }
    table.append(tr);

    _maxint = 1;
    for (var pint of annot_data['intensities'])
	if (pint > _maxint)
	    _maxint = pint;

    _totint = 0;
    _totints = [0,0,0,0,0,0,0,0,0,0,0,0,0];
    _coreints = [0,0,0,0,0,0,0,0,0,0,0,0,0];
    _mzs = annot_data['mzs'];

    for (var idx in annot_data['mzs']) {
	tr = document.createElement("tr");
	for (var col of ["mzs", "intensities", "interpretations"]) {
	    td = document.createElement("td");

	    var val = annot_data[col][idx];
	    if (col == "interpretations") {
		td.append(val);
	    }
	    else {
		td.className = "number";
		var f = col == "intensities" ? 1 : 4;
		td.append(Number(val).toFixed(f));
		if (col == "intensities") {
		    tr.append(td);
		    td = document.createElement("td");
		    td.className = "number";
		    td.style.borderRight = "1px solid rgb(187, 221, 187)";
		    td.append(Number(100*val/_maxint).toFixed(1));
		    td.style.background = "linear-gradient(to left, rgb(187, 221, 187), rgb(187, 221, 187) "+(100*val/_maxint)+"%, rgba(255, 255, 255, 0) "+(100*val/_maxint)+"%)";
		}
	    }
	    tr.append(td);
	}

	// only consider the first one
	var what = annot_data['interpretations'][idx].split('/')[0];
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
        else if (what.startsWith("f")) {
            where = _ion_list.indexOf('mol');
            what = what.substring(2, what.length-1);
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
		//td.className = 'annot_col'+aaa;
                td.style.color = 'white';
                td.style.background = _ion_colors[_ion_list[aaa]];

		if (!mion)
		    td.style.filter = "brightness(65%)";
		else
		    _coreints[aaa] += annot_data['intensities'][idx];
		td.innerHTML = what;

		_totints[aaa] += annot_data['intensities'][idx];
		_totint += annot_data['intensities'][idx];

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

    clear_element("annot_div");
    document.getElementById("annot_div").append(table);

    if (_chartdata && _maxint > 0) {
	_chartdata['options']['scales']['y2']['display'] = true;
        _chartdata.update();
    }
}


function show_ion_stats() {
    clear_element("quickplot_canvas");
    document.getElementById("quickplot_title").innerHTML = "Ion Stats";

    var canvas = document.getElementById("quickplot_canvas");
    canvas.height = 250;
    canvas.width = 550;

    const ctx = canvas.getContext("2d");
    ctx.fillStyle = '#eee';
    ctx.fillRect(400, 20, 120, 200);

    ctx.strokeStyle = "#ccc";
    ctx.fillStyle = '#aaa';
    ctx.lineWidth = 1;
    ctx.beginPath();
    for (var pct=0; pct<=100; pct+=10) {
	ctx.moveTo(0, 20+2*pct);
	ctx.lineTo(520, 20+2*pct);
	ctx.fillText((100-pct)+"%", 525, 22+2*pct);
    }
    ctx.stroke();

    var ismine = [0,0];
    for (var aaa in _ion_list) {
        ismine[aaa>9?1:0] += _totints[aaa];

	var x = 5+40*aaa;
	var h = 200*_totints[aaa]/_totint;

        ctx.fillStyle = _ion_colors[_ion_list[aaa]];
	ctx.fillRect(x, 220-h, 30, h);

	var h2 = 200*_coreints[aaa]/_totint;
	ctx.fillStyle = '#000';
	ctx.globalAlpha = 0.35;
	ctx.fillRect(x, 220-h, 30, h-h2);

        ctx.globalAlpha = 1;
	ctx.fillStyle = '#000';
	ctx.font = "16px Consola";
	ctx.textAlign = "center";
	ctx.fillText(_ion_list[aaa], x+15, 240);
    }
    ctx.fillStyle = '#666';
    ctx.font = "24px Consola";
    ctx.fillText(Number(100*ismine[0]/_totint).toFixed(1)+"%", 205, 38);
    ctx.fillText(Number(100*ismine[1]/_totint).toFixed(1)+"%", 465, 38);

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


// misc utils
function clear_element(ele) {
    if (!document.getElementById(ele))
	return;
    const node = document.getElementById(ele);
    while (node.firstChild) {
	node.removeChild(node.firstChild);
    }
}

function addCheckBox(ele,remove=true) {
    var check = document.createElement("span");
    check.className = 'alert';
    check.innerHTML = '&check;';
    check.style.position = 'absolute';
    ele.parentNode.insertBefore(check, ele.nextSibling);

    if (remove)
	var timeout = setTimeout(function() { check.remove(); }, 1500 );
}

function stuff_is_running(button=null,isit=true) {
    if (isit)
	document.getElementById("pagebanner").classList.add('crawl');
    else
	document.getElementById("pagebanner").classList.remove('crawl');

    if (button)
	button.disabled = isit ? true : '';
}


///////////////////////////////////////////////////////////////////////// unused:
function generateRandomId() {
    const characters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    let randomId = '';

    for (let i = 0; i < 32; i++) {
	const randomIndex = Math.floor(Math.random() * characters.length);
	randomId += characters.charAt(randomIndex);
    }

    return randomId;
}

function enter_setting(ele) {
    if (event.key === 'Enter')
	update_setting(ele.id,null);
    else
	update_save_button(ele);
}

function chart_controls() {
    var div = document.createElement("div");
    div.className = "ms2chart_controls";

    var span = document.createElement("span");
    span.className = 'buttonlike';
    span.title = "Reset Zoom and axes to intial settings";
    span.onclick= function(){reset_x();};
    span.innerHTML = '&#8634;';
    div.append(span);

    return div;
}

function update_setting(key,value) {
    key = key.replace("_setting",'');
    if (value)
	document.getElementById(key+"_setting").value = value;

    if (key == 'mztolerance') {
	var tol = Number(document.getElementById(key+"_setting").value.trim());
	if (isNaN(tol))
	    tol = '20';
	_settings[key] = tol;
	_settings[key+"_units"] = document.getElementById(key+"_units_setting").value;
	document.getElementById(key+"_setting").value = _settings[key];
    }
    else {
	_settings[key] = document.getElementById(key+"_setting").value.trim();
	document.getElementById(key+"_setting").value = _settings[key];
    }

    addCheckBox(document.getElementById(key+"_setting_button"),true);
    var timeout = setTimeout(function() { document.getElementById(key+"_setting_button").disabled = true; } , 1500 );
}

function update_save_button(ele,bid=null) {
    var key = ele.id.replace("_setting",'');
    if (!bid)
	bid = key+"_setting_button";

    var currval = _settings[key];
    if (currval == ele.value)
	document.getElementById(bid).disabled = true;
    else
	document.getElementById(bid).disabled = false;
}


function displayMsg(divid,msg) {
    clear_element(divid);
    var txt = document.createElement("h2");
    txt.className = "invalid";
    txt.style.marginBottom = "0";
    txt.append(msg);
    document.getElementById(divid).append(txt);
}

