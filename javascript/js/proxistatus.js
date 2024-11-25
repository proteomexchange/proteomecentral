var proxi_status_url = "cgi/PROXI_status";
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
	if (!tables_rendered)
	    render_tables(table_info);

	for (var r in response) {
	  if ( response[r].length > 4 ) {
	    try {
		var rjson = JSON.parse(response[r]);
		var rowid = rjson.provider_name + rjson.endpoint;
		document.getElementById(rowid+"_code").innerHTML = rjson.code;
		document.getElementById(rowid+"_msg").innerHTML = rjson.message;

		if (rjson.code == 200 && rjson.message != "OK")
		    rjson.code = -200;
		document.getElementById(rowid+"_code").className = "code"+rjson.code;
		document.getElementById(rowid+"_msg").className = "code"+rjson.code;

		document.getElementById(rowid+"_time").innerHTML = rjson.elapsed;
		document.getElementById(rowid+"_time").className = rjson.elapsed < 1.0 ? 'code200' : rjson.elapsed < 3.0 ? 'code404' : rjson.elapsed < 5.0 ? 'code-200' : 'code500';

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
	var stat = document.getElementById("stat");
	if ( xhr1.status == 200 ) {
	    stat.innerHTML = "Done!";
	    stat.className = "code200";
	}
	else {
	    document.getElementById("main").innerHTML = "<h2>There was an error processing your request. Please try again later.</h2>";
	    stat.innerHTML = "Error...";
	    stat.className = "code500";
	}
        document.getElementById("debug").innerHTML += "<br/><a href='"+proxi_status_url+"'>Raw stream</a><br/>";
    };
    return;
}

function render_tables(table_info) {
    var proxi_rows = JSON.parse(table_info);

    var table = document.createElement("table");
    table.className = "prox";

    for (let row of proxi_rows.table_list) {
	var tr = document.createElement("tr");
	var td = document.createElement("td");
	td.colSpan='5';
	td.append(document.createElement("br"));
	td.append(document.createElement("br"));
	tr.append(td);
	table.append(tr);

        var pname = row.provider_name;

	tr = document.createElement("tr");
        td = document.createElement("td");
	td.className = "rep";
	td.style.paddingLeft = '25px';
        td.colSpan='5';
	td.append(pname);

	var link = document.createElement("a");
	link.target = 'proxtest';
	link.href = row.ui;
	link.append(row.ui);
        td.append(link);
        tr.append(td);
        table.append(tr);

        tr = document.createElement("tr");
	for (var head of ['Endpoint', 'Response Code', 'Message', 'Elapsed Time', 'Tested URL']) {
            td = document.createElement("th");
	    td.append(head);
            tr.append(td);
	}
        table.append(tr);


	for (var rname of row.row_list) {
            tr = document.createElement("tr");
            tr.className = "rowdata";

            td = document.createElement("td");
            td.append('/'+rname);
            tr.append(td);

            for (var field of ['_code', '_msg', '_time', '_turl']) {
		td = document.createElement("td");
		td.id = pname+rname+field;
		if (field == '_time')
		    td.style.textAlign = 'right';
		td.append("~~~");
		tr.append(td);
	    }
            table.append(tr);
	}
    }

    document.getElementById("main").innerHTML = '';
    document.getElementById("main").append(table);
    document.getElementById("main").append(document.createElement("br"));
    document.getElementById("main").append(document.createElement("br"));

    tables_rendered = true;
}
