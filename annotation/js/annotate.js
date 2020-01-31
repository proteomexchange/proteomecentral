var form_defs_url = "../cgi/definitions";
var data_defs_url = form_defs_url + "?annotation_id=";
var field_def_url = "/api/autocomplete/v0.1/autocomplete?word=*&field_name=";
var form_post_url = "/api/autocomplete/v0.1/annotations";
var datasets_url  = "/api/autocomplete/v0.1/datasets";
var datasetdef_url= "/api/autocomplete/v0.1/annotations?dataset_id=";
var response_json = {};
var field_values  = {};
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

	    for (dataset of data) {
		opt = document.createElement("option");
		opt.value = dataset;
		opt.text  = dataset;
		sel.appendChild(opt);
	    }

	})
	.catch(error => console.error(error));
}

// unused...
function get_datasets_old() {
    var xhr = new XMLHttpRequest();
    xhr.open("get", datasets_url, true);
    xhr.setRequestHeader('Content-Type', 'application/json; charset=UTF-8');
    xhr.send(null);

    xhr.onloadend = function() {
	if ( xhr.status == 200 ) {
	    add_top_form(JSON.parse(xhr.responseText));
	    //add_typeahead();
	}
	else {
	    document.getElementById("main").innerHTML = "<h2>There was an error retrieving available datasets. Please report or try again later.</h2>";
	}

    };
    return;
}

// unused...
function add_top_form(datasets_json) {
    var div = document.createElement("div");
    div.id        = "dataset-primary";
    div.className = "site-content";
    div.style.marginLeft = "50px";
    div.style.maxWidth   = "1500px";

    var h1  = document.createElement("h1");
    var txt = document.createTextNode("Choose Action");
    h1.className    = "dataset-title";
    h1.style.margin = "0px";
    h1.appendChild(txt);
    div.appendChild(h1);

    var div2 = document.createElement("div");
    div2.className = "dataset-content";

    var tab = document.createElement("table");
    tab.id        = "top_table";
    tab.className = "dataset-summary";

    var tr = document.createElement("tr");

    var td = document.createElement("td");
    txt = document.createTextNode('Annotate a new dataset');
    td.appendChild(txt);
    tr.appendChild(td);

    td = document.createElement("td");

    var sub = document.createElement("input");
    sub.className = "linkback";
    sub.style.marginLeft = "150px";
    sub.type  = "submit";
    sub.value = "New Annotation";
    sub.setAttribute('onclick', 'get_form_definitions(null);');
    td.appendChild(sub);
    tr.appendChild(td);

    tab.appendChild(tr);


    tr = document.createElement("tr");

    td = document.createElement("td");
    txt = document.createTextNode('Load/Edit existing dataset');
    td.appendChild(txt);
    tr.appendChild(td);

    td = document.createElement("td");

    var sel = document.createElement("select");
    sel.id  = "dataset_menu";
    sel.className = "linkback";
    sel.style.marginLeft = "150px";
    sel.title = "Choose dataset to view/edit";
    sel.setAttribute('onchange', 'load_dataset(this.value);');

    var opt = document.createElement("option");
    opt.value = '';
    opt.text  = "-- Choose dataset --";
    sel.appendChild(opt);

    for (dataset of datasets_json) {
	opt = document.createElement("option");
	opt.value = dataset;
	opt.text  = dataset;
	sel.appendChild(opt);
    }

    td.appendChild(sel);

    sel = document.createElement("select");
    sel.id  = "dataset_menu2";
    sel.className = "linkback";
    sel.style.marginLeft = "30px";
    sel.title = "Choose annotation to view/edit";
    sel.setAttribute('onchange', 'get_form_definitions(this.value);');

    opt = document.createElement("option");
    opt.value = '';
    opt.text  = "-- No annotations selected --";
    sel.appendChild(opt);

    td.appendChild(sel);


    tr.appendChild(td);

    tab.appendChild(tr);


    div2.appendChild(tab);
    div.appendChild(div2);

    document.getElementById("main").appendChild(div);
}


function load_dataset(dset) {
    fetch(datasetdef_url+dset)
	.then(response => response.json())
	.then(data => {
	    add_datasets_menu(data);
	})
	.catch(error => console.error(error));
}


function add_datasets_menu(dsets) {
    var sel = document.getElementById("dataset_menu2");
    clear_element("dataset_menu2");

    var opt = document.createElement("option");
    opt.value = '';
    opt.text  = "-- Choose annotation --";
    sel.appendChild(opt);

    for (annot of dsets) {
	opt = document.createElement("option");
	opt.value = annot.id;
	opt.text  = annot.name;
	sel.appendChild(opt);
    }
}

function get_form_definitions(annot_id) {
    var xurl = form_defs_url;
    if (annot_id != null) {
	xurl = data_defs_url + annot_id;
    }
    else {
	document.getElementById("dataset_menu").selectedIndex = 0;
	document.getElementById("dataset_menu2").selectedIndex = 0;
    }

    var xhr = new XMLHttpRequest();
    xhr.open("get", xurl, true);
    xhr.setRequestHeader('Content-Type', 'application/json; charset=UTF-8');
    xhr.send(null);

    xhr.onloadend = function() {
	if ( xhr.status == 200 ) {
	    process_response(JSON.parse(xhr.responseText));
	    //add_typeahead();
	}
	else {
	    document.getElementById("main").innerHTML = "<h2>There was an error processing your request. Please try again later.</h2>";
	}

    };
    return;
}

function process_response(defs_json) {
    add_annotation_form(form_id);

    for (sect of defs_json.sections) {
	//console.log("here: "+sect+" clone?"+defs_json.section_definitions[sect]["is clonable"]);
	add_section(sect, defs_json.section_definitions[sect]["is clonable"], false);

	for (field of defs_json.section_definitions[sect]["data rows"]) {
	    //console.log("field: "+field);
	    var field_atts = defs_json.section_definitions[sect]["row attributes"][field];
	    //console.log("atts : "+JSON.stringify(field_atts));
	    add_field(sect,field,field_atts,null,false);
	}
    }

}

function delete_section(sect) {
    var rows_now = Array.from(document.getElementById(form_id+"_table").rows); // copy by value
    for (tr of rows_now) {
	if (tr.dataset.sect == sect) {
	    delete(response_json[tr.dataset.id]);
	    document.getElementById(form_id+"_table").deleteRow(tr.rowIndex);
	}
	else if (tr.dataset.sect == sect+"_header") {
	    document.getElementById(form_id+"_table").deleteRow(tr.rowIndex);
	}
    }
}

function clone_section(sect) {
    var newsect = sect + "___" + field_cnt;
    add_section(newsect, true, true);

    var rows_now = Array.from(document.getElementById(form_id+"_table").rows); // copy by value
    for (tr of rows_now) {
	if (tr.dataset.sect == sect) {
	    var source = document.getElementById(tr.dataset.id);
	    var fobj = {
		"is required" : tr.dataset.req,
		"has curie"   : tr.dataset.cv,
		"autocomplete": tr.dataset.auto,
		"list box"    : tr.dataset.list,
		"duplication" : tr.dataset.dup,
		"description" : source.title
	    }
	    var new_id = add_field(newsect,source.name,fobj,null,tr.dataset.rem);

	    document.getElementById(new_id).value = source.value;
	    if (tr.dataset.cv == 'true') {
		document.getElementById(new_id+"_CV").value = document.getElementById(tr.dataset.id+"_CV").value;
	    }
	    document.getElementById(new_id+"_COMMENTS").value = document.getElementById(tr.dataset.id+"_COMMENTS").value;
	}
    }
    window.scrollBy(0,10000);
}

function add_section(sect_name, clonable, deletable) {
    if (clonable == "false") {
	clonable = false;
    }
    if (deletable == "false") {
	deletable = false;
    }

    var num_cols = 6;

    var tr = document.createElement("tr");
    tr.dataset.sect = sect_name + "_header";
    var td = document.createElement("td");
    td.style.padding = "15px";
    td.colSpan = num_cols;

    tr.appendChild(td);
    document.getElementById(form_id+"_table").appendChild(tr);

    tr = document.createElement("tr");
    tr.dataset.sect = sect_name + "_header";
    tr.className = "sect";
    td = document.createElement("td");
    td.colSpan = num_cols-1;
    td.style.borderBottom = "0px";
    td.style.fontSize = "20px";

    var sect_text = sect_name.split("___");

    txt = document.createTextNode(sect_text[0]);
    td.appendChild(txt);
    tr.appendChild(td);

    td = document.createElement("td");
    td.style.borderBottom = "0px";
    td.style.padding = "0px";

    var span = document.createElement("span");
    if (clonable) {
	span.className = "tdplus right_btn";
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
    document.getElementById(form_id+"_table").appendChild(tr);

    tr = document.createElement("tr");
    tr.dataset.sect = sect_name + "_header";
    tr.className = "sect";

    for (x of ['','','Value','CV id','Comments','Definition']) {
	td = document.createElement("th");
	txt = document.createTextNode(x);
	td.appendChild(txt);
	tr.appendChild(td);
    }

    document.getElementById(form_id+"_table").appendChild(tr);
}



function add_annotation_form(fid) {
    clear_element("main");
    change_cnt = 0;

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
    sub.style.marginLeft = "10px";
    sub.style.marginRight = "10px";
    sub.title  = "Save changes!";
    sub.type  = "submit";
    sub.value = " S A V E ";

    sub.setAttribute('onclick', 'submit();');

//    sub.addEventListener('click', document.getElementById(form_id).submit() );

    clear_element("status");
    document.getElementById("status").appendChild(sub);
    document.getElementById("status").style.backgroundColor = "#709525";
}

function submit() {
    for (var fv of Object.keys(response_json)) {
	response_json[fv].value   = document.getElementById(fv).value;
	response_json[fv].cv      = document.getElementById(fv+"_CV") ?
	    document.getElementById(fv+"_CV").value : '';
	response_json[fv].comment = document.getElementById(fv+"_COMMENTS").value;
    }

    console.log("atts : "+JSON.stringify(response_json, undefined, 2));

    var xhr = new XMLHttpRequest();
    xhr.open("post", form_post_url, true);
    xhr.setRequestHeader('Content-Type', 'application/json; charset=UTF-8');
    xhr.send(JSON.stringify(response_json));  // send the collected data as JSON

    xhr.onloadend = function() {
        if ( xhr.status == 200 ) {
	    alert("SUBMITTED....");
	    change_cnt = 0;
	    document.getElementById("save_button").value = "Save";
	}
    }
}



function remove_field(field_id,tdobj) {
    delete(response_json[field_id]);
    document.getElementById(form_id+"_table").deleteRow(tdobj.parentNode.rowIndex);
}

function append_field(section,field,has_curie,auto_comp,list_box,tdobj) {
    var fobj = {
	"is required" : false,
	"has curie"   : has_curie,
	"autocomplete": auto_comp,
	"list box"    : list_box,
	"duplication" : false,
	"description" : '"'
    }

    add_field(section,field,fobj,tdobj.parentNode.rowIndex+1,true);
}

function add_field(section,field,fieldobj,rownum,rem) {
    field_cnt++;
    field_id = "_field_"+field_cnt;

    var req  = false;
    var cv   = false;
    var auto = false;
    var list = false;
    var dup  = false;
    if (fieldobj["is required"] == "true") {
	req  = true;
    }
    if (fieldobj["has curie"] == "true") {
	cv   = true;
    }
    if (fieldobj["autocomplete"] == "true") {
	auto = true;
    }
    if (fieldobj["list box"] == "true") {
	list = true;
    }
    if (fieldobj["duplication"] == "true") {
	dup  = true;
    }
    if (rem == "true") {
	rem  = true;
    }
    else if (rem == "false") {
	rem = false;
    }

    if (rownum == null) {
	rownum = document.getElementById(form_id+"_table").rows.length;
    }
//    var tr = document.createElement("tr");
    var tr = document.getElementById(form_id+"_table").insertRow(rownum);
    tr.dataset.id   = field_id;
    tr.dataset.sect = section;
    tr.dataset.req  = req;
    tr.dataset.cv   = cv;
    tr.dataset.auto = auto;
    tr.dataset.list = list;
    tr.dataset.dup  = dup;
    tr.dataset.rem  = rem;

    // duplicate?
    var td = document.createElement("td");
    var txt = document.createTextNode(" ");
    if (dup) {
	txt = document.createTextNode('+');
	td.className = "tdplus";
	td.title = "Add another row";
	td.setAttribute('onclick', 'append_field(\"'+section+'\",\"'+field+'\",\"'+cv+'\",\"'+auto+'\",\"'+list+'\",this);');
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

    // user input :: value
    td = document.createElement("td");
    td.style.whiteSpace = "nowrap";

    var i = document.createElement("input");
    i.type  = "text";
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
    if (fieldobj.value) { i.value = fieldobj.value; }
    i.addEventListener('change', valueChanged);
    td.appendChild(i);

    //if (field == 'acquisition type') {
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
	i.required = req;
	if (fieldobj.cv) { i.value = fieldobj.cv; }
	i.addEventListener('change', valueChanged);
	td.appendChild(i);
    }
    else {
	txt = document.createTextNode("n/a");
	td.className = "infotext";
	td.appendChild(txt);
    }
    tr.appendChild(td);

    // user input :: comments
    td = document.createElement("td");
    i = document.createElement("input");
    i.id    = field_id+"_COMMENTS";
    i.type  = "text";
    i.name  = field+"_COMMENTS";
    i.title = "Curator comments";
    if (fieldobj.comment) { i.value = fieldobj.comment; }
    i.addEventListener('change', valueChanged);
    td.appendChild(i);
    tr.appendChild(td);

    // description
    td = document.createElement("td");
    txt = document.createTextNode(fieldobj.description);
    td.appendChild(txt);
    tr.appendChild(td);

    //document.getElementById(form_id+"_table").appendChild(tr);

    // must do both of these after the td is added to the DOM
    if (auto) {
	add_typeahead(field_id);
    }
    if (list) {
	retrieve_field_values(field,field_id);
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


function valueChanged(e) {
    change_cnt++;
    document.getElementById("save_button").value = "Save "+change_cnt+" changes";
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

    for (item of field_values[field]) {
	var opt = document.createElement("option");
	opt.value = item.name+"--"+item.curie;
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
	.catch(error => console.error(error));
}

function adjust_value(selobj, elemid) {
    var vals = selobj.value.split("--");
    document.getElementById(elemid).value = vals[0];
    document.getElementById(elemid+"_CV").value = vals[1];
    document.getElementById(elemid+"_menu").value = '';
}


function clear_element(ele) {
    const node = document.getElementById(ele);
    while (node.firstChild) {
	node.removeChild(node.firstChild);
    }
}
