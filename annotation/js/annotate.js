var form_defs_url   = "/cgi/definitions"; // "/devED/cgi/definitions";
var base_api        = "/api/autocomplete/v0.1/";
var field_def_url   = base_api+"autocomplete?word=*&field_name=";
var form_post_url   = base_api+"annotations";
var msruns_post_url = base_api+"msrundata";
var datasets_url    = base_api+"datasets";
var datasetdef_url  = base_api+"annotations?dataset_id=";

var response_json = {};
var field_values  = {};
var special_vars  = {};
var messages   = [];
var field_cnt  = 0;
var change_cnt = 0;
var form_id = "main_form";

function main() {
    get_datasets();
}

function get_datasets() {
    fetch(datasets_url)
	.then(response => response.json())
	.then(data => {
	    var sel = document.getElementById("dataset_menu");
	    clear_element("dataset_menu");

	    var opt = document.createElement("option");
	    opt.value = '';
	    opt.text  = "-- Choose dataset --";
	    sel.appendChild(opt);

	    opt = document.createElement("option");
	    opt.value = '--NEW--';
	    opt.text  = "-- Annotate a NEW dataset --";
	    sel.appendChild(opt);

	    for (var dataset of data) {
		opt = document.createElement("option");
		opt.value = dataset;
		opt.text  = dataset;
		sel.appendChild(opt);
	    }

	    process_querystring(window.location);
	})
	.catch(error => showAlerts(error));
}


function enter_dataset() {
    if (document.getElementById("newDatasetId").value.length > 1) {
	get_form_definitions("--DIRECT INPUT--");
    }
    else {
	get_form_definitions(null);
    }
}


function load_dataset_annotations(dset) {
    dismissBox("newDataset");
    if (dset == "") {
	return;  // ignore
    }
    else if (dset == "--NEW--") {
	document.getElementById("dataset_menu").selectedIndex = 0;
	showPXDInput();
    }
    else {
	fetch(datasetdef_url+dset)
	    .then(response => response.json())
	    .then(data => {
		add_datasets_menu(data);
	    })
	    .catch(error => showAlerts(error));
    }
}


function add_datasets_menu(dsets) {
    var sel = document.getElementById("dataset_menu2");
    clear_element("dataset_menu2");

    var opt = document.createElement("option");
    opt.value = '--';
    opt.text  = "-- Choose annotation --";
    sel.appendChild(opt);

    opt = document.createElement("option");
    opt.value = '--NEW--';
    opt.text  = "-- Create a NEW annotation --";
    sel.appendChild(opt);

    opt = document.createElement("option");
    opt.value = '--UPLOAD--';
    opt.text  = "-- Upload MS Runs Definitions Table --";
    sel.appendChild(opt);

    for (var annot of dsets) {
	opt = document.createElement("option");
	opt.value = annot.id;
	opt.text  = annot.name;
	sel.appendChild(opt);
    }

    if (special_vars["autoload"]) {
	var latest = sel.options[sel.options.length - 1].value;
	sel.value = latest;
	get_form_definitions(latest);
    }
    special_vars["autoload"] = false;
}


function show_upload_form() {
    clear_element("main");

    var pxd = document.getElementById("dataset_menu").value;

    var f = document.createElement("form");
    f.id     = form_id;
    f.method = "post";
    f.action = "javascript:uploadTable();";

    var div = document.createElement("div");
    div.id        = "dataset-primary";
    div.className = "site-content";
    div.style.marginLeft = "50px";
    div.style.maxWidth   = "1500px";

    var h1  = document.createElement("h1");
    var txt = document.createTextNode(pxd);
    h1.className    = "dataset-title";
    h1.id           = "annotation-title";
    h1.style.margin = "0px";
    h1.appendChild(txt);
    div.appendChild(h1);

    var div2 = document.createElement("div");
    div2.className = "dataset-content";

    var h3  = document.createElement("h3");
    txt = document.createTextNode("Please enter/paste tab-delimited values into text area below:");
    h3.appendChild(txt);
    div2.appendChild(h3);

    var i = document.createElement("textarea");
    i.className = "tabinput";
    i.rows = 200;
    i.cols = 150;
    i.id   = "msrun_tabinfo";
    div2.appendChild(i);

    i = document.createElement("input");
    i.id    = "msrun_dataset_id";
    i.type  = "hidden";
    i.value = pxd;
    div2.appendChild(i);

    div.appendChild(div2);

    f.appendChild(div);
    document.getElementById("main").appendChild(f);


    var sub = document.createElement("input");
    sub.id = "upload_button";
    sub.className = "linkback";
    sub.style.marginLeft  = "10px";
    sub.style.marginRight = "10px";
    sub.title  = "Upload!";
    sub.type   = "submit";
    sub.value  = " U P L O A D ";

    sub.addEventListener('click', uploadTable);

    clear_element("status");
    document.getElementById("status").appendChild(sub);
}


function get_form_definitions(annot_id) {
    var xurl = form_defs_url;
    if (annot_id != null) {
	if (annot_id == "--") {
	    return;  // ignore
	}
	else if (annot_id == "--NEW--") {
	    xurl += "?dataset_id=" + document.getElementById("dataset_menu").value;
	    document.getElementById("dataset_menu2").selectedIndex = 0;
	}
	else if (annot_id == "--DIRECT INPUT--") {
	    xurl += "?dataset_id=" + document.getElementById("newDatasetId").value;
	    document.getElementById("dataset_menu2").selectedIndex = 0;
	}
	else if (annot_id == "--UPLOAD--") {
	    show_upload_form();
	    return;
	}
	else {
	    xurl += "?annotation_id=" + annot_id;
	}
    }
    else {
	document.getElementById("dataset_menu").selectedIndex = 0;
	document.getElementById("dataset_menu2").selectedIndex = 0;
    }
    dismissBox("newDataset");
    dismissBox("alertBox");

    clear_element("main");
    var h1  = document.createElement("h1");
    h1.style.marginLeft = "100px";
    h1.className = "current";
    var txt = document.createTextNode("Loading...");
    h1.appendChild(txt);
    document.getElementById("main").appendChild(h1);

    clear_element("status");
    document.getElementById("status").appendChild(document.createTextNode("Load/Create:"));

    var xhr = new XMLHttpRequest();
    xhr.open("get", xurl, true);
    xhr.setRequestHeader('Content-Type', 'application/json; charset=UTF-8');
    xhr.send(null);

    xhr.onloadend = function() {
	messages   = [];
	if (xhr.responseText) {
	    var rjson = JSON.parse(xhr.responseText);
	    capture_messages(rjson);

	    if (xhr.status == 200) {
		process_response(rjson);
	    }
	    else if (rjson.detail) {
		showAlerts(rjson.detail);
	    }
	    else {
		showAlerts("There was an unspecified error. Please try again later.  (Code:"+xhr.status+")");
	    }
	}
	else {
	    showAlerts("There was an error processing your request. Please try again later.  (Code:"+xhr.status+")");
	}

    };
    return;
}

function capture_messages(json_resp) {
    for (var m of json_resp.log) {
	messages.push(m);
    }
    show_messages();
}

function show_messages() {
    clear_element("myMessages");
    var errors = 0;
    for (var msg of messages) {
	if (msg.level == "ERROR") { errors++; }

	var span = document.createElement("span");
	span.className = "msg " + msg.level;

	var txt = document.createTextNode(msg.prefix);
	span.appendChild(txt);

	span.appendChild(document.createElement("br"));

	txt = document.createTextNode(msg.message);
	span.appendChild(txt);

	document.getElementById("myMessages").appendChild(span);
	document.getElementById("num_msgs").innerHTML = messages.length;
    }
    if (errors > 0) {
	showAlerts("There are " + errors + " errors with the data in this annotation record. Please review and correct before submitting.");
    }
}


function process_response(defs_json) {
    add_annotation_form(form_id);

    if (defs_json.dataset_info) {
	for (var fname of Object.keys(defs_json.dataset_info)) {
	    field_values[fname] = defs_json.dataset_info[fname];
	}
    }

    for (var sect of defs_json.sections) {
	add_section(sect, defs_json.section_definitions[sect]["is clonable"]);

	for (var field of defs_json.section_definitions[sect]["data rows"]) {
	    //console.log("field: "+field);
	    var field_atts = defs_json.section_definitions[sect]["row attributes"][field];
	    //console.log("atts : "+JSON.stringify(field_atts));
	    add_field(sect,field,field_atts,null,false);
	}
    }

}

function delete_section(sect) {
    var rows_now = Array.from(document.getElementById(form_id+"_table").rows); // copy by value
    for (var tr of rows_now) {
	var remove = false;
	if (tr.dataset.sect == sect) {
	    delete(response_json[tr.dataset.id]);
	    remove = true;
	}
	else if (tr.dataset.sect == sect+"_header") {
	    remove = true;
	}
	else if (tr.id == sect+"_summarytr") {
	    special_vars["numms"]--;
	    remove = true;
	}

	if (remove) {
	    document.getElementById(form_id+"_table").deleteRow(tr.rowIndex);
	}
    }
    valueChanged(null);
}

function clone_section(sect) {
    var newsect = sect + "___" + field_cnt;
    var newsect_id = add_section(newsect, true);

    var rows_now = Array.from(document.getElementById(form_id+"_table").rows); // copy by value
    for (var tr of rows_now) {
	if (tr.dataset.sect == sect) {
	    var source = document.getElementById(tr.dataset.id);
	    var fobj = {
		"is required" : tr.dataset.req,
		"has curie"   : tr.dataset.cv,
		"autocomplete": tr.dataset.auto,
		"list box"    : tr.dataset.list,
		"data type"   : tr.dataset.type,
		"duplication" : tr.dataset.dup,
		"description" : source.title
	    }

	    var rownum = -1;
	    if (sect.startsWith("condition metadata")) {
		rownum = document.getElementById("msruns_summarytable").rowIndex - 1;
	    }
	    var new_id = add_field(newsect,source.name,fobj,rownum,tr.dataset.rem);

	    document.getElementById(new_id).value = source.value;
	    if (document.getElementById(new_id + "_summary_entry")) {
		document.getElementById(new_id + "_summary_entry").innerHTML = source.value ? source.value : "&nbsp;";
	    }
	    if (tr.dataset.cv == 'true') {
		document.getElementById(new_id+"_CV").value = document.getElementById(tr.dataset.id+"_CV").value;
	    }
	    document.getElementById(new_id+"_COMMENTS").value = document.getElementById(tr.dataset.id+"_COMMENTS").value;
	}
    }

    if (sect.startsWith("condition metadata")) {
	document.getElementById(newsect_id).scrollIntoView();
	window.scrollBy( { behavior: 'smooth', top: -150 } ); // move past page header
    }
    else {
	document.getElementById(newsect_id).scrollIntoView( { behavior: 'smooth'} );
    }
    valueChanged(null);
}

function add_section(sect_name, clonable) {
    if (clonable  == "false") { clonable  = false; }

    var deletable = clonable;

    var num_cols = 6;
    var tr;
    var td;
    var txt;

    // summary for MS Run Data
    if (sect_name.startsWith("MS run metadata")) {

	if (!document.getElementById("msruns_summarytable")) {
	    special_vars["numms"] = 0;

	    // spacer
	    tr = document.createElement("tr");
	    td = document.createElement("td");
	    td.style.padding = "15px";
	    td.colSpan = num_cols;
	    tr.appendChild(td);
	    document.getElementById(form_id+"_table").appendChild(tr);

	    tr = document.createElement("tr");
	    tr.id = "msruns_summarytable";
	    tr.className = "sect";

	    // open/close widget
	    td = document.createElement("td");
	    td.className = "sect_clop";
	    td.title = "Show/Hide section values";
	    td.id = "msms_summary_clop";
	    td.setAttribute('onclick', 'clop_sect(\"msms_summary\");');
	    txt = document.createTextNode('\u2013');
	    td.appendChild(txt);
	    tr.appendChild(td);

	    td = document.createElement("td");
	    td.colSpan = num_cols-1;
	    //td.style.borderBottom = "0px";
	    td.style.fontSize = "20px";

	    txt = document.createTextNode("MS Runs Summary");
	    td.appendChild(txt);
	    tr.appendChild(td);

	    document.getElementById(form_id+"_table").appendChild(tr);
	}

	special_vars["numms"]++;

	tr = document.getElementById(form_id+"_table").insertRow(document.getElementById("msruns_summarytable").rowIndex+special_vars["numms"]);

	tr.id = sect_name + "_summarytr";
	tr.dataset.sect = "msms_summary";
	//tr.className = "sect";

	td = document.createElement("td");
	td.id = sect_name + "_summarytd";
	td.colSpan = num_cols;

	tr.appendChild(td);
    }

    var rownum = -1;
    if (sect_name.startsWith("condition metadata") &&
	document.getElementById("msruns_summarytable")) {
	rownum = document.getElementById("msruns_summarytable").rowIndex - 1;
    }

    // spacer
    tr = document.getElementById(form_id+"_table").insertRow(rownum);
    tr.dataset.sect = sect_name + "_header";
    td = document.createElement("td");
    td.style.padding = "15px";
    td.colSpan = num_cols;
    tr.appendChild(td);

    // text heading
    rownum = tr.rowIndex+1;
    tr = document.getElementById(form_id+"_table").insertRow(rownum);
    tr.dataset.sect = sect_name + "_header";
    tr.className = "sect";

    // open/close widget
    td = document.createElement("td");
    td.rowSpan = 2;
    td.className = "sect_clop";
    td.title = "Show/Hide section values";
    td.id = sect_name + "_clop";
    td.setAttribute('onclick', 'clop_sect(\"'+sect_name+'\");');
    txt = document.createTextNode('\u2013');
    td.appendChild(txt);
    tr.appendChild(td);

    td = document.createElement("td");
    td.colSpan = num_cols-2;
    td.style.borderBottom = "0px";
    td.style.fontSize = "20px";


    var sect_text = sect_name.split("___");
    txt = document.createTextNode(sect_text[0]);
    td.appendChild(txt);

    var span = document.createElement("span");
    span.id = sect_name + "_id";
    span.className = "sect_id";
    td.appendChild(span);

    tr.appendChild(td);

    td = document.createElement("td");
    td.style.borderBottom = "0px";
    td.style.padding = "0px";

    span = document.createElement("span");
    if (clonable) {
	span.className = "tdplus right_btn sect_id";
	span.title = "Clone this section";
	span.setAttribute('onclick', 'clone_section(\"'+sect_name+'\");');

	txt = document.createTextNode("Copy");
	span.appendChild(txt);
    }
    td.appendChild(span);

    span = document.createElement("span");
    if (deletable) {
	span.className = "tdminus right_btn";
	span.title = "Delete this section";
	span.setAttribute('onclick', 'delete_section(\"'+sect_name+'\");');

	txt = document.createTextNode("Delete");
	span.appendChild(txt);
    }
    td.appendChild(span);

    tr.appendChild(td);


    // column headings
    rownum = tr.rowIndex+1;
    tr = document.getElementById(form_id+"_table").insertRow(rownum);
    tr.dataset.sect = sect_name + "_header";
    tr.className = "sect";

    for (var x of ['','Value','CV id','Comments','Definition']) {
	td = document.createElement("th");
	txt = document.createTextNode(x);
	td.appendChild(txt);
	tr.appendChild(td);
    }

    return sect_name + "_id";
}



function add_annotation_form(fid) {
    clear_element("main");

    // clear/reset settings and vars
    response_json = {};
    field_values  = {};
    field_cnt  = 0;
    change_cnt = 0;
    document.getElementById("status").style.backgroundColor = '';

    var f = document.createElement("form");
    f.id     = fid;
    f.method = "post";
    f.action = "javascript:submit();";

    var div = document.createElement("div");
    div.id        = "dataset-primary";
    div.className = "site-content";
    div.style.marginLeft = "50px";
    div.style.maxWidth   = "1500px";

    var h1  = document.createElement("h1");
    var txt = document.createTextNode("Study Annotation");
    h1.className    = "dataset-title";
    h1.id           = "annotation-title";
    h1.style.margin = "0px";
    h1.appendChild(txt);
    div.appendChild(h1);

    var div2 = document.createElement("div");
    div2.className = "dataset-content";

    var tab = document.createElement("table");
    tab.id        = fid+"_table";
    tab.className = "dataset-summary";
    div2.appendChild(tab);
    div.appendChild(div2);

    f.appendChild(div);

    document.getElementById("main").appendChild(f);


    var sub = document.createElement("input");
    sub.id = "save_button";
    sub.className = "linkback";
    sub.style.marginLeft  = "10px";
    sub.style.marginRight = "10px";
    sub.title  = "Save changes!";
    sub.type   = "submit";
    sub.value  = " S A V E ";

//    sub.setAttribute('onclick', 'submit();');
    sub.addEventListener('click', submitAnnotation);

    clear_element("status");
    document.getElementById("status").appendChild(sub);
}

function submit() {
    for (var fv of Object.keys(response_json)) {
	response_json[fv].value   = document.getElementById(fv).value;
	response_json[fv].cv      = document.getElementById(fv+"_CV") ?
	                            document.getElementById(fv+"_CV").value : '';
	response_json[fv].comment = document.getElementById(fv+"_COMMENTS").value;
    }

    // console.log("atts : "+JSON.stringify(response_json, undefined, 2));

    var xhr = new XMLHttpRequest();
    xhr.open("post", form_post_url, true);
    xhr.setRequestHeader('Content-Type', 'application/json; charset=UTF-8');
    xhr.send(JSON.stringify(response_json));  // send the collected data as JSON

    xhr.onloadend = function() {
	if (xhr.responseText) {
	    var rjson = JSON.parse(xhr.responseText);
	    capture_messages(rjson);

            if (xhr.status == 200) {
		alert(rjson.detail);
		change_cnt = 0;
		document.getElementById("save_button").value = "Save";
		document.getElementById("status").style.backgroundColor = "#709525";
		get_datasets();
		document.getElementById("dataset_menu2").selectedIndex = 0;
	    }
	    else {
		clear_element("alertList");
		var alerts = document.getElementById("alertList");
		var txt = document.createTextNode("There are errors with this annotation.");
		alerts.appendChild(txt);
		alerts.appendChild(document.createElement("br"));
		txt = document.createTextNode("Please review the following (highlighted) fields and resubmit.");
		alerts.appendChild(txt);
		alerts.appendChild(document.createElement("br"));

		var ul = document.createElement("ul");
		for (var badfield of rjson.invalid_fields) {
		    var li = document.createElement("li");
		    txt = document.createTextNode(badfield.name + ": " + badfield.code);
		    li.appendChild(txt);
		    ul.appendChild(li);

		    document.getElementById(badfield.field_key).closest("tr").className = "badfield";
		}
		alerts.appendChild(ul);

		showAlerts(null);
	    }
	}
	else {
	    showAlerts("There was an error saving this annotation! Please report or try again later.");
	}

    }
}


function remove_field(field_id,tdobj) {
    delete(response_json[field_id]);
    document.getElementById(form_id+"_table").deleteRow(tdobj.parentNode.rowIndex);
}

function append_field(section,field,has_curie,auto_comp,list_box,data_type,tdobj) {
    var fobj = {
	"is required" : false,
	"has curie"   : has_curie,
	"autocomplete": auto_comp,
	"list box"    : list_box,
	"data type"   : data_type,
	"duplication" : false,
	"description" : '"'
    }

    add_field(section,field,fobj,tdobj.parentNode.rowIndex+1,true);
}

function add_field(section,field,fieldobj,rownum,rem) {
    field_cnt++;
    field_id = "_field_"+field_cnt;

    field = field.split("___")[0];

    var req  = false;
    var cv   = false;
    var auto = false;
    var list = false;
    var dup  = false;
    var rows = 1;
    if (fieldobj["is required"]   == "true") { req  = true; }
    if (fieldobj["has curie"]     == "true") { cv   = true; }
    if (fieldobj["autocomplete"]  == "true") { auto = true; }
    if (fieldobj["list box"]      == "true") { list = true; }
    if (fieldobj["duplication"]   == "true") { dup  = true; }

    if      (rem == "true")  { rem = true;  }
    else if (rem == "false") { rem = false; }

    // capture dataset_info values
    if (field_values[field]) { list = true; }

    var type = fieldobj["data type"];

    if (rownum == null) {
	rownum = -1;
    }
    var tr = document.getElementById(form_id+"_table").insertRow(rownum);
    tr.dataset.id   = field_id;
    tr.dataset.sect = section;
    tr.dataset.req  = req;
    tr.dataset.cv   = cv;
    tr.dataset.auto = auto;
    tr.dataset.list = list;
    tr.dataset.type = type;
    tr.dataset.dup  = dup;
    tr.dataset.rem  = rem;

    // duplicate/remove?
    var td = document.createElement("td");
    var txt = document.createTextNode(" ");
    if (dup) {
	txt = document.createTextNode('+');
	td.className = "tdplus";
	td.title = "Add another row";
	td.setAttribute('onclick', 'append_field(\"'+section+'\",\"'+field+'\",\"'+cv+'\",\"'+auto+'\",\"'+list+'\",\"'+type+'\",this);');
    }
    else if (rem) {
	txt = document.createTextNode('\u2a2f');
	td.className = "tdminus";
	td.title = "Remove row";
	td.setAttribute('onclick', 'remove_field(\"'+field_id+'\",this);');
    }
    td.appendChild(txt);
    tr.appendChild(td);

    // field
    td = document.createElement("td");
    td.className = "field";
    txt = document.createTextNode(field+":");
    td.appendChild(txt);
    tr.appendChild(td);

    var cols = 2;
    var size = 55;
    if (cv) {
	cols = 1;
	size = 30;
    }
    else if (list) {
	size = 50;
    }

    // for single line summary
    if (section.startsWith("MS run metadata")) {
	var span = document.createElement("span");
	span.id = field_id + "_summary_entry";
	span.className = "summary";
	span.title = field;
	span.innerHTML = "&nbsp;";
	document.getElementById(section + "_summarytd").appendChild(span);
    }


    // user input :: value
    td = document.createElement("td");
    td.style.whiteSpace = "nowrap";
    td.colSpan = cols;

    if (type == "textarea") { rows = 4; }
//    if (fieldobj["data type"] == "textarea") { rows = fieldobj["n lines"]; }

    var i;
    if (rows > 1) {
	i = document.createElement("textarea");
	i.rows = rows;
	i.cols = 41;
 	i.className = "expand";
   }
    else {
	i = document.createElement("input");
	i.type = "text";
	i.size = size;
    }

    i.id    = field_id;
    i.name  = field;
    i.title = fieldobj.description;
    i.required = req;
    if (auto) {
	i.autocomplete = "off";
	i.autocapitalize = "off";
	i.spellcheck = false;
	i.autocorrect = "off";
	i.dataset.provide = "typeahead";
	i.className = "nodeInput";
    }
    if (fieldobj.value) {
	i.value = fieldobj.value;
	if (field == "dataset id") {
	    update_title("annotation-title",fieldobj.value);
	    i.readOnly = true;
	    i.title = "id cannot be changed!";
	    i.className = "field";
	    i.size  = 40;
	}
	else if (field == "MS run ordinal" || field == "condition id") {
	    update_title(section + "_id",fieldobj.value);
	}

	if (document.getElementById(field_id + "_summary_entry")) {
	    document.getElementById(field_id + "_summary_entry").innerHTML = fieldobj.value;
	}

    }
    if (req) { i.className += " req"; }

    i.addEventListener('change', valueChanged);
    td.appendChild(i);

    if (list) {
	var sel = document.createElement("select");
	sel.id  = field_id+"_menu";
	sel.className = "minimenu";
	sel.title = "View all values for "+field;
	sel.setAttribute('onchange', 'adjust_value(this,\"'+field_id+'\");');

	var opt = document.createElement("option");
	opt.value = '';
	opt.text  = "\u25bc";
	sel.appendChild(opt);

	td.appendChild(sel);
    }

    tr.appendChild(td);

    // user input :: cv
    td = document.createElement("td");
    if (cv) {
	i = document.createElement("input");
	i.id    = field_id+"_CV";
	i.type  = "text";
	i.name  = field+"_CV";
	i.title = "CV Identifier";
	i.size  = 13;
	i.required = req;
	if (req) { i.className = "req"; }
	if (fieldobj.cv) { i.value = fieldobj.cv; }
	i.addEventListener('change', valueChanged);
	td.appendChild(i);

	tr.appendChild(td);
    }
    else { // meh...
	txt = document.createTextNode("n/a");
	td.className = "infotext";
	td.appendChild(txt);
    }


    // user input :: comments
    td = document.createElement("td");
    i = document.createElement("textarea");
    i.id    = field_id+"_COMMENTS";
    i.name  = field+"_COMMENTS";
    i.title = "Curator comments";
    i.cols  = 25;
    if (fieldobj.comment) { i.value = fieldobj.comment; }
    i.addEventListener('change', valueChanged);
    td.appendChild(i);
    tr.appendChild(td);

    // description
    td = document.createElement("td");
    txt = document.createTextNode(fieldobj.description);
    td.appendChild(txt);
    tr.appendChild(td);

    // must do both of these after the td is added to the DOM
    if (auto) {
	add_typeahead(field_id);
    }
    if (list) {
	retrieve_field_values(field,field_id);
    }

    // invalid field value?
    if (fieldobj["is_invalid"]) {
	tr.className = "badfield";

	tr = document.getElementById(form_id+"_table").insertRow(rownum);
	tr.className = "badfield";

	td = document.createElement("td");
	td.colSpan = 6;
	txt = document.createTextNode(fieldobj.is_invalid);
	td.appendChild(txt);
	tr.appendChild(td);
    }


    response_json[field_id] = {
	"section" : section,
	"name"    : field,
	"value"   : "",
	"cv"      : "",
	"comment" : ""
    };

    return field_id;
}

function submitAnnotation(e) {
    document.getElementById(form_id).submit();
}

function uploadTable(e) {
    response_json = {};
    response_json.dataset_id = document.getElementById("msrun_dataset_id").value;
    response_json.table_content = document.getElementById("msrun_tabinfo").value;

    //alert("atts : "+JSON.stringify(response_json, undefined, 2));


    var xhr = new XMLHttpRequest();
    xhr.open("post", msruns_post_url, true);
    xhr.setRequestHeader('Content-Type', 'application/json; charset=UTF-8');
    xhr.send(JSON.stringify(response_json));  // send the collected data as JSON

    xhr.onloadend = function() {
	if (xhr.responseText) {
	    var rjson = JSON.parse(xhr.responseText);
	    capture_messages(rjson);

            if (xhr.status == 200) {
		alert(rjson.detail);
		document.getElementById("dataset_menu2").selectedIndex = 0;
	    }
	    else {
		clear_element("alertList");
		var alerts = document.getElementById("alertList");
		var txt = document.createTextNode("There are errors with this upload.");
		alerts.appendChild(txt);
		alerts.appendChild(document.createElement("br"));
		txt = document.createTextNode(rjson.detail);
		alerts.appendChild(txt);
		showAlerts(null);
	    }
	}
	else {
	    showAlerts("There was an error with the upload! Please report or try again later.");
	}
    }

}


function valueChanged(e) {
    change_cnt++;
    document.getElementById("save_button").value = "Save "+change_cnt+" changes";

    var col = (change_cnt > 5) ? "#db4314" : "#bfb62f";
    document.getElementById("status").style.backgroundColor = col;

    if (e) {
	if (e.target.name == "dataset id") {
	    update_title("annotation-title",e.target.value);
	}

	if (e.target.name == "condition id"  ||
	    e.target.name == "MS run ordinal" ) {
	    var tr = e.target.closest("tr");
	    update_title(tr.dataset.sect+"_id",e.target.value);
	}

	if (document.getElementById(e.target.id + "_summary_entry")) {
	    document.getElementById(e.target.id + "_summary_entry").innerHTML = e.target.value;
	}
    }
}

function retrieve_field_values(field,htmlid) {
    if (!field_values[field]) {
	get_field_values(field,htmlid);
    }
    else {
	add_vals_menu(field,htmlid);
    }
}

function add_vals_menu(field,htmlid) {
    //console.log("found values: "+field_values[field]);
    var i = document.getElementById(htmlid+"_menu");

    for (var item of field_values[field]) {
	var opt = document.createElement("option");
	if (item.curie) {
	    opt.value = item.name+"--"+item.curie;
	}
	else {
	    opt.value = item.name+"--";
	}
	opt.text  = item.name;
	i.appendChild(opt);
    }

    if (field_values[field] == '') {
	var opt = document.createElement("option");
	opt.value = "--";
	opt.text  = "NO DATA";
	i.appendChild(opt);
    }
}

function get_field_values(field,htmlid) {
    fetch(field_def_url+field)
	.then(response => response.json())
	.then(data => {
	    field_values[field] = data;
	    add_vals_menu(field,htmlid);
	})
//	.catch(error => console.error(error));
	.catch(error => capture_messages( { log: [ { level: 'ERROR', prefix: 'Unable to retrieve values for: '+ field, message: error } ] } ));
}

function adjust_value(selobj, elemid) {
    var vals = selobj.value.split("--");
    document.getElementById(elemid).value = vals[0];
    if (document.getElementById(elemid+"_CV")) {
	document.getElementById(elemid+"_CV").value = vals[1];
    }
    document.getElementById(elemid+"_menu").value = '';

    if (document.getElementById(elemid + "_summary_entry")) {
	document.getElementById(elemid + "_summary_entry").innerHTML = vals[0];
    }
    valueChanged(null);
}

function update_title(elem, text) {
    document.getElementById(elem).innerHTML = text;
}



function process_querystring(url) {
    var params = new URLSearchParams(url.search);

    if (!params.has('dataset_id')) {
	return;
    }

    var dataid = params.get('dataset_id');
    if (document.getElementById("dataset_menu").contains(dataid)) {
	document.getElementById("dataset_menu").value = dataid;
	special_vars["autoload"] = true;
	load_dataset_annotations(dataid);
    }
    else {
	document.getElementById("newDatasetId").value = dataid;
	enter_dataset();
    }

}


function clear_element(ele) {
    const node = document.getElementById(ele);
    while (node.firstChild) {
	node.removeChild(node.firstChild);
    }
}

function clop_sect(sect) {
    if (!special_vars.hasOwnProperty(sect+"_open")) {
	special_vars[sect+"_open"] = 1;
    }

    var disp = "table-row";
    var mipl = "&ndash;";
    if (special_vars[sect+"_open"] == 1) {
	disp = "none";
	mipl = "+";
    }

    for (var tr of Array.from(document.getElementById(form_id+"_table").rows)) {
	if (tr.dataset.sect == sect) {
	    tr.style.display = disp; 
	}
    }
    document.getElementById(sect+"_clop").innerHTML = mipl;

    special_vars[sect+"_open"] = 1 - special_vars[sect+"_open"];
}

function toggleMsgs() {
    var lp = "0px";
    var lt = "504px";
    if (document.getElementById("sidenav").style.left == lp) {
	lp = "-505px";
	lt = "0px";
    }
    document.getElementById("sidenav").style.left = lp;
    document.getElementById("sidenav_toggle").style.left = lt;
}

function dismissBox(box_id) {
    document.getElementById(box_id).style.visibility = "hidden";
    document.getElementById("overlay").style.display = "none";
}

function showAlerts(msg) {
    document.getElementById("alertBox").style.visibility = "visible";
    if (msg != null) {
	document.getElementById("alertList").innerHTML = msg;
    }
}

function showPXDInput() {
    document.getElementById("newDataset").style.visibility = "visible";
    document.getElementById("overlay").style.display = "block";
}


HTMLSelectElement.prototype.contains = function(val) {
    for (var opt of this.options) {
        if (opt.value == val) {
            return true;
        }
    }
    return false;
}
