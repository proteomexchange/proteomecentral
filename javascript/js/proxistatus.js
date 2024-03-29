var proxi_status_url = "https://proteomecentral.proteomexchange.org/cgi/PROXI_status";
var tables_rendered = false;

function main() {
    get_proxi_stream();
}


function get_proxi_stream() {
    var xhr1 = new XMLHttpRequest();
    xhr1.open("get", proxi_status_url, true);
    xhr1.setRequestHeader('Content-Type', 'application/json; charset=UTF-8');
    xhr1.send(null);

    xhr1.onprogress = function(e) {
	var response = xhr1.responseText.split("\n");
	var table_info = response.shift();
	if (!tables_rendered) {
	    render_tables(table_info);
	}

	for (var r in response) {
	  if ( response[r].length > 4 ) {
	    try {
		var rjson = JSON.parse(response[r]);
		var rowid = rjson.provider_name + rjson.endpoint;
		document.getElementById(rowid+"_code").innerHTML = rjson.code;
		document.getElementById(rowid+"_msg").innerHTML = he.encode(rjson.message);

		if (rjson.code == 200 && he.encode(rjson.message) != "OK")
		    rjson.code = -200;
		document.getElementById(rowid+"_code").className = "code"+rjson.code;
		document.getElementById(rowid+"_msg").className = "code"+rjson.code;

		document.getElementById(rowid+"_time").innerHTML = rjson.elapsed;
		document.getElementById(rowid+"_turl").innerHTML = "<a target='proxtest' href='"+rjson.url+"'>"+rjson.display_url+"</a>";
		//document.getElementById("debug").innerHTML += rowid + ", ";
	    }
	    catch(e) {
		document.getElementById("debug").innerHTML += "Found bad JSON: "+e+": ("+response[r]+")<br/>";
	    }
          }
	}

    }

    xhr1.onloadend = function() {
	if ( xhr1.status == 200 ) {
	    document.getElementById("stat").innerHTML = "&nbsp;&nbsp;Done!&nbsp;&nbsp;";
	    document.getElementById("stat").className = "code200";
	}
	else {
	    document.getElementById("main").innerHTML = "<h2>There was an error processing your request. Please try again later.</h2>";
	    document.getElementById("stat").innerHTML = "&nbsp;&nbsp;Error...&nbsp;&nbsp;";
	    document.getElementById("stat").className = "code500";
	}
        document.getElementById("debug").innerHTML += "<br/><a href='"+proxi_status_url+"'>Raw stream</a><br/>";
    };
    return;
}


function render_tables(table_info) {
    var proxi_rows = JSON.parse(table_info);
    var thtml = "<table class='prox'>";
    for (var i in proxi_rows.table_list) {
	var pname = proxi_rows.table_list[i].provider_name;
	thtml += "<tr><td colspan='5'><br/><br/></td></tr>";

	thtml += "<tr><td class='rep' colspan='5'>&nbsp;&nbsp;"+pname+"&nbsp;&nbsp;<a target='proxtest' href='"+proxi_rows.table_list[i].ui+"'>"+proxi_rows.table_list[i].ui+"</a></td></tr>";

//	thtml += "<tr><td class='rep' colspan='5'>&nbsp;&nbsp;"+pname+"</td></tr>";


	thtml += "<tr><th>Endpoint</th><th>Response Code</th><th>Message</th><th>Elapsed Time</th><th>Tested URL</th></tr>";
	for (var r in proxi_rows.table_list[i].row_list) {
	    var rname = proxi_rows.table_list[i].row_list[r];
	    thtml += "<tr class='rowdata'><td>/"+rname+"</td><td id='"+pname+rname+"_code'>---</td><td id='"+pname+rname+"_msg'>---</td><td id='"+pname+rname+"_time'>---</td><td id='"+pname+rname+"_turl'>---</td></tr>";


	}
    }
    thtml += "</table><br/><br/>";
    document.getElementById("main").innerHTML = thtml;
    tables_rendered = true;
}
