var _api = {};
var _px_settings = {};

function main(what=null) {
    _api['query'] = {};
    _px_settings['ordered_facets'] = { 'datasets' : ['search','species','year','instrument','keywords','sdrf','files','repository'],
				       'libraries': ['search','species','source','fragmentation_type','keywords','year']
				     };
    // Used to create filter links
    _px_settings['text_to_facet'] = { 'datasets' : { 'species':'species','instrument':'instrument' },
                                      'libraries': { 'Species':'species','Source':'source','Fragmentation Type':'fragmentation_type' }
                                    };

    _px_settings['render_overview'] = true;
    _px_settings['data_mode'] = 'datasets'; // default

    if (what in _px_settings['ordered_facets'])
	_px_settings['data_mode'] = what;

    var f = parse_querystring();

    if (!f) {
	document.getElementById("pagemenu").style.display = '';
	set_pagetitle(null);
	return;
    }
    else {
        if ('pxid' in _api['query']) {
	    if (_api['query']['pxid'].startsWith('PXL'))
		_px_settings['data_mode'] = 'libraries';
	    else if (_api['query']['pxid'].startsWith('PXD'))
		_px_settings['data_mode'] = 'datasets';
	}
        else if ('view' in _api['query'] &&
		 _api['query']['view'] in _px_settings['ordered_facets'])
	    _px_settings['data_mode'] = _api['query']['view'];
    }

    document.getElementById("pagemenu").style.display = 'none';
    document.getElementById("results").style.display = '';
    fetch("./proxi_config.json")
	.then(response => response.json())
	.then(config => {
            if (config.API_URL) {
		_api['datasets'] = config.API_URL +"datasets";
		_api['libraries'] = config.API_URL +"libraries";
	    }
	    else {
		_api['datasets'] = "/api/proxi/v0.1/datasets";
		_api['libraries'] = "/api/proxi/v0.1/libraries";
	    }

	    if ('pxid' in _api['query'])
		get_PXitem(_api['query']['pxid']);
	    else
		get_PXdata(f,null,null);


	    if ('click' in _api['query']) {
		var link_id = "pagelink_"+_api['query']['click'];

		var timeout = setTimeout(function() {
		    if (document.getElementById(link_id))
			document.getElementById(link_id).click();
		}, 200);
	    }

            if (config.SpecialWarning)
                pc_displaySpecialWarning(config.SpecialWarning);
	})
        .catch(error => {
	    console.error(error);
            _api['datasets'] = "/api/proxi/v0.1/datasets";
            _api['libraries'] = "/api/proxi/v0.1/libraries";
	    if ('pxid' in _api['query'])
                get_PXitem(_api['query']['pxid']);
            else
		get_PXdata(f,null,null);
	});
}


function parse_querystring() {
    var had_params = false;
    const searchParams = new URLSearchParams(window.location.search);
    searchParams.forEach((value, key) => {
	_api['query'][key] = value;
	had_params = true;
    });
    return had_params;
}


function set_pagetitle(text=null) {
    var node = document.getElementById("pagetitle");
    if (text == null)
	node.style.display = 'none';
    else {
	node.style.display = '';
	node.innerHTML = text;
    }
}


function get_PXitem(pxid) {
    var call = _px_settings['data_mode'];
    set_pagetitle(' View ProteomeXchange Data Details');

    var barwidth = document.getElementById('toppagecontrolbar') ? document.getElementById('toppagecontrolbar').clientWidth : "1063px";

    document.getElementById("overview").style.display = 'none';
    document.getElementById("filters").style.display = 'none';

    var results_node = document.getElementById("results");
    results_node.innerHTML = '';
    results_node.className = '';

    var wait = getAnimatedWaitBar(barwidth);
    wait.style.padding = 0;
    var span = document.createElement("h3");
    span.style.position = "relative";
    span.style.top = "-8px";
    span.style.display = "inline";
    span.append("Loading...");
    wait.append(span);
    results_node.append(wait);

    var apiurl = _api[call] + '/' + pxid + '?src=PCUI&resultType=full';
    fetch(apiurl)
        .then(response => {
            if (response.ok) return response.json();
            else throw new Error('Unable to fetch item data '+apiurl);
        })
        .then(data => {
	    document.title = "ProteomeXchange Dataset: " + pxid;
            results_node.innerHTML = '';
	    if (call == 'datasets')
		PXdataset_details(data,false);
	    else
		PXlibrary_details(data,false);
        })
        .catch(error => {
            document.title = "ProteomeCentral ERROR with PX dataset: " + pxid;
            results_node.innerHTML = '';
            results_node.className = "error";
            results_node.innerHTML = "<br>" + error + "<br><br>";
            console.error(error);
	});

}


function get_PXdata(filter,value,action=null) {
    var call = _px_settings['data_mode'];
    if (value && value.startsWith('fromPCUI:'))
	value = document.getElementById(value.replace('fromPCUI:','')).value;
    if (filter == 'search' && value.length < 3)
	return;

    set_pagetitle(' Browse ProteomeXchange '+call);
    document.title = 'Browse ProteomeXchange '+call;

    var barwidth = document.getElementById('toppagecontrolbar') ? document.getElementById('toppagecontrolbar').clientWidth : "1063px";

    var results_node = document.getElementById("results");
    results_node.innerHTML = '';
    results_node.className = '';

    var wait = getAnimatedWaitBar(barwidth);
    wait.style.padding = 0;
    var span = document.createElement("h3");
    span.style.position = "relative";
    span.style.top = "-8px";
    span.style.display = "inline";
    span.append("Loading...");
    wait.append(span);
    results_node.append(wait);


    var apiurl = _api[call] + '?src=PCUI&resultType=resultset';
    if (filter) {
	for (var q in _api.query) {
	    if (filter == q) {
		if (action == 'set') {
		    if (value)
			apiurl += "&" + filter + '=' + encodeURIComponent(value);
		}
		else if (action == 'add') {
                    apiurl +=  "&" + filter + '=' + encodeURIComponent(value.trim());
		    if (_api.query[q]) {
			for (var v of _api.query[q].split(',')) {
			    if (v.trim() != value.trim())
				apiurl += ',' + encodeURIComponent(v.trim());
			}
		    }
		}
                else if (action == 'remove') {
                    var allvalues = '';
                    var comma = '';
                    for (var v of _api.query[q].split(',')) {
                        if (v != value) {
                            allvalues += comma + encodeURIComponent(v.trim());
                            comma = ',';
			}
                    }
                    if (allvalues)
			apiurl +=  "&" + filter + '=' + allvalues;
                }
	    }
            else if (_api.query[q])
		apiurl += "&" + q + '=' + encodeURIComponent(_api.query[q]);

	}
    }

    fetch(apiurl)
        .then(response => {
	    if (response.ok) return response.json();
	    else throw new Error('Unable to fetch data '+apiurl);
	})
        .then(data => {
	    var newurl = window.location.href.split('?')[0];
	    newurl += "?view=" + _px_settings['data_mode'];
	    for (var q in data['query']) {
		if (data.query[q]) {
		    _api['query'][q] = data.query[q];
		    if (q == 'resultType')
			continue;
		    if (q == 'pageNumber' && data.query[q] == 1)
			continue;
		    if (q == 'pageSize' && data.query[q] == 100)
			continue;

		    newurl += "&" + q + '=' + data.query[q];
		}
		else
		    _api['query'][q] = null;
	    }

	    if (data['result_set']['n_rows_returned'] == 0 && data['result_set']['n_available_rows'] > 0) {
		get_PXdata("pageNumber","1","set");
		return;
	    }
	    add_filter_controls(data);
	    add_resultset_table(data);
	    if (_px_settings['render_overview']) {
		render_overview_wheels(data);
		//_px_settings['render_overview'] = false;  // uncomment to run only once
	    }
	    window.history.pushState({ html: document.documentElement.outerHTML }, 'ProteomeCentral '+call+' query', encodeURI(newurl));

        })
        .catch(error => {
            document.title = "ProteomeCentral ERROR";
            results_node.innerHTML = '';
	    results_node.className = "error";
	    results_node.innerHTML = "<br>" + error + "<br><br>";
            console.error(error);
	});

}

function render_overview_wheels(data) {
    var palette = ["#2c99ce", "#384955", "#9BAEBC", "#B68751", "#7E5521", "#f26722", "#55433B", "#BDA79D", "#00B090", "#00785E"];

    var what = _px_settings['data_mode'];

    var panel = 0;
    document.getElementById("overview").style.display = '';
    for (var thing of ['species','instrument','keywords','year']) {
	panel++;
	if (thing == 'instrument' && what =='libraries')
	    thing = 'fragmentation_type';

	var svg = document.getElementById("datasvg_"+panel);

	var temp = document.getElementById("container_"+thing);
	if (temp)
	    temp.remove();

	let container = document.createElementNS("http://www.w3.org/2000/svg", "g");
	container.setAttribute("id", "container_"+thing);
        container.setAttribute("style", "font-size:10px");

	var num = 0;
	var total = 0;
	for (var item of data.facets[thing]) {
	    total += item['count'];
            if (num++ == 9)
                break;
	}

	if (total == 0) {
            var txt = document.createElementNS("http://www.w3.org/2000/svg", "text");
            txt.setAttribute('x', 150);
            txt.setAttribute('y', 80);
            txt.setAttribute('text-anchor', 'middle');
            txt.setAttribute('font-size', '32');
            txt.setAttribute('fill', '#aaa');
	    txt.innerHTML = "No Data";
            container.append(txt);
            svg.append(container);
	    continue;
	}

	num = 0;
	const radius = 100;
	const circumference = 2 * Math.PI * radius;
	var strokeOffset = circumference / 2;
	for (var item of data.facets[thing]) {
	    var pct = item['count'] / total;
            var link = document.createElementNS("http://www.w3.org/2000/svg", "a");
	    link.setAttribute('href', 'javascript:get_PXdata("'+thing+'","'+item['name']+'","add")');

            var arc = document.createElementNS("http://www.w3.org/2000/svg", "circle");
	    const strokeDasharray = pct * circumference / 2;
	    arc.setAttribute('r', radius);
	    arc.setAttribute('cx', 150);
            arc.setAttribute('cy', 150);
	    arc.setAttribute('stroke', palette[num]);
	    arc.setAttribute('stroke-width', 80);
	    arc.setAttribute('stroke-dasharray', [strokeDasharray,circumference - strokeDasharray]);
	    arc.setAttribute('stroke-dashoffset', strokeOffset);
	    arc.setAttribute('fill', 'transparent');
            arc.setAttribute('onmouseover', 'showstats("'+thing+'","'+item['count']+'","'+data['result_set']['n_available_rows']+'","'+item['name']+'","'+palette[num]+'")');
	    link.append(arc);
	    container.append(link);

	    strokeOffset -= strokeDasharray;
	    if (num++ == 9)
		break;
	}

        var arc = document.createElementNS("http://www.w3.org/2000/svg", "circle");
	arc.setAttribute("id", "center_"+thing);
        arc.setAttribute('r', radius);
        arc.setAttribute('cx', 150);
        arc.setAttribute('cy', 150);
        arc.setAttribute('stroke', 'red');
        arc.setAttribute('stroke-width', 80);
        arc.setAttribute('stroke-dasharray', [0,circumference]);
        arc.setAttribute('fill', 'transparent');
        container.append(arc);

        var txt = document.createElementNS("http://www.w3.org/2000/svg", "text");
	txt.setAttribute("id", "stats1_"+thing);
        txt.setAttribute('x', 150);
        txt.setAttribute('y', 130);
        txt.setAttribute('text-anchor', 'middle');
        txt.setAttribute('font-size', '14');
	txt.setAttribute('fill', '#fff');
	container.append(txt);

	txt = document.createElementNS("http://www.w3.org/2000/svg", "text");
        txt.setAttribute("id", "stats2_"+thing);
        txt.setAttribute('x', 150);
        txt.setAttribute('y', 145);
        txt.setAttribute('text-anchor', 'middle');
        txt.setAttribute('font-size', '12');
        txt.setAttribute('font-weight', 'bold');
	txt.setAttribute('fill', '#fff');
        container.append(txt);

	document.getElementById("databoxtitle_"+panel).innerHTML = (thing=='year'?"Latest ":"Top ")+num+" "+thing+(thing.endsWith('s')?"":"s");

	svg.append(container);

        if (_px_settings['render_overview'])  // first time
	    showstats(thing,data.facets[thing][0]['count'],data['result_set']['n_available_rows'],data.facets[thing][0]['name'],palette[0]);

    }
}

function showstats(type,amount,nrows,value,color) {
    var pct = amount/nrows;
    pct = (100 * pct).toFixed((pct<0.1?1:0));

    document.getElementById("center_"+type).setAttribute('fill', color);
    document.getElementById("stats1_"+type).innerHTML = amount+" datasets ("+pct+"%)";
    document.getElementById("stats2_"+type).innerHTML = value;
}


// for future use?
function UNUSED_render_overview_bars(data) {
    var palette = ["#e60049", "#0bb4ff", "#50e991", "#e6d800", "#9b19f5", "#ffa300", "#dc0ab4", "#b3d4ff", "#00bfa0", "#000000"];
    var blue_to_yellow = ["#115f9a", "#1984c5", "#22a7f0", "#48b5c4", "#76c68f", "#a6d75b", "#c9e52f", "#d0ee11", "#d0f400"];

    for (var thing of ['species','instrument','keywords','year']) {
	var svg = document.getElementById("svg_"+thing);

	temp = document.getElementById("container_"+thing);
	if (temp)
	    temp.remove();

	let container = document.createElementNS("http://www.w3.org/2000/svg", "g");
	container.setAttribute("id", "container_"+thing);
        container.setAttribute("style", "font-size:10px");

	var num = 0;
	for (var item of data.facets[thing]) {
	    var pct = item['count'] / data['result_set']['n_available_rows'];
            var link = document.createElementNS("http://www.w3.org/2000/svg", "a");
	    link.setAttribute('href', 'javascript:get_PXdata("'+thing+'","'+item['name']+'","add")');

            var rect = document.createElementNS("http://www.w3.org/2000/svg", "rect");
	    rect.setAttribute('height', 4);
	    rect.setAttribute('x', 5);
            rect.setAttribute('y', 1+num*15);
	    rect.setAttribute('width', 290);
	    rect.setAttribute('fill', '#eee');
	    link.append(rect);

	    rect = document.createElementNS("http://www.w3.org/2000/svg", "rect");
	    rect.setAttribute('height', 4);
	    rect.setAttribute('x', 5);
            rect.setAttribute('y', 1+num*15);
	    rect.setAttribute('width', pct*290);
	    rect.setAttribute('fill', palette[num]);
	    link.append(rect);

	    pct = (100 * pct).toFixed((pct<0.1?1:0));
            var txt = document.createElementNS("http://www.w3.org/2000/svg", "text");
	    txt.setAttribute('x', 10);
	    txt.setAttribute('y', (num+1)*15-1);
	    txt.setAttribute('fill', '#ccc');
	    //txt.append(item['name']+" : "+item['count']);
	    txt.append(item['name']+" : "+pct+"%");
	    link.append(txt);

	    container.append(link);

	    if (num++ == 9)
		break;
	}
	svg.append(container);
    }
}

function add_filter_controls(data) {
    var filters_node = document.getElementById("filters");
    filters_node.style.display = '';
    filters_node.innerHTML = '';

    var span = document.createElement("h3");
    span.className = "title";
    span.append("Filter");
    filters_node.append(span);

    span = document.createElement("span");
    span.id = "filteredtext";
    filters_node.append(span);
    span = document.createElement("span");
    span.id = "clearfilters";
    filters_node.append(span);
    filters_node.append(document.createElement("br"));
    filters_node.append(document.createElement("br"));

    var numfil = 0;
    for (var facet of _px_settings['ordered_facets'][_px_settings['data_mode']]) {
        if (data.query[facet]) {
	    for (var val of data.query[facet].split(',')) {
		span = document.createElement("span");
		span.className = "filtertag x";
		span.setAttribute('onclick', 'get_PXdata("'+facet+'","'+val+'","remove");');
		span.title = 'remove "'+val+'" from '+facet+' filter';
		span.append(val);
		filters_node.append(span);
		numfil++;
	    }
	}
    }
    filters_node.append(document.createElement("br"));


    span = document.getElementById("filteredtext");
    span.append(data['result_set']['n_available_rows']+" dataset");
    // grammerify
    if (numfil == 0)
	span.append("s total");
    else {
	if (data['result_set']['n_available_rows'] != 1)
	    span.append("s pass filter");
	else
	    span.append(" passes filter");
	if (numfil != 1)
            span.append("s");
    }

    if (numfil > 1) {
	span = document.getElementById("clearfilters");
	span.className = "buttontag";
	span.setAttribute('onclick', 'get_PXdata(null,null,null);');
	span.title = "Remove all filters";
	span.append("Clear all");
    }

    if (data['result_set']['n_available_rows'] == 0)
        return;


    var div = document.createElement("div");
    div.className = "dataset-content";
    div.style.wordBreak = "break-word";
    filters_node.append(div);

    span = document.createElement("span");
    span.className = "dataset-secthead";
    span.append('Search');
    div.append(span);
    var i = document.createElement('input');
    i.id = "textsearch";
    i.title = "term must be at least 3 characters in length";
    i.setAttribute('onkeydown', "submit_on_enter(this);");
    i.style.width = "95%";
    div.append(i);
    span = document.createElement("span");
    span.className = "buttonlike";
    span.style.padding = "2px 5px";
    span.style.position = "absolute";
    span.title = 'search!';
    span.setAttribute('onclick', 'get_PXdata("search","fromPCUI:textsearch","add");');
    span.append('\u{1F50E}\u{FE0E}');
    div.append(span);

    div.append(document.createElement("br"));
    div.append(document.createElement("br"));

    for (let facet of _px_settings['ordered_facets'][_px_settings['data_mode']]) {
	if (facet == 'search')
	    continue;
	var div2 = document.createElement("div");
	div2.id = facet + '_div';
	div2.className = "facetlist";
	div2.style.maxHeight = '200px';

	for (var item of data.facets[facet]) {
	    span = document.createElement("span");
	    span.className = "filterlink";
	    span.setAttribute('onclick', 'get_PXdata("'+facet+'","'+item['name']+'","add");');
	    span.append(item['name']+" ("+item['count']+")");
	    div2.append(span);
	}
	div.append(div2);

	span = document.createElement("span");
	span.id = facet + '_head';
	span.className = "dataset-secthead";
	span.style.textTransform = 'capitalize';

	var adj = 'Top ';
	if (facet == "year")
	    adj = 'Announce ';
	else if (facet == "files")
	    adj = 'Number of ';
	else if (facet == "repository")
	    adj = '';
	else if (facet == "sdrf") {
	    adj = '';
            span.style.textTransform = 'uppercase';
	}

	span.append(adj+facet.replace("_"," "));
	if (div2.scrollHeight > 200) {
            span.className = "dataset-secthead filterlink mas";
            span.setAttribute('onclick', 'mas_o_menos("'+facet+'");');
	    span.title = 'click to see more / fewer';
	}
	div.insertBefore(span, div2);

	div.append(document.createElement("br"));
    }

    span = document.createElement("span");
    span.className = "dataset-secthead filterlink";
    span.setAttribute('onclick', 'get_PXdata(null,null,null);');
    span.title = "Remove all filters and page options";
    span.append("Reset");
    div.append(span);
}


function add_resultset_table(data) {
    var results_node = document.getElementById("results");
    results_node.innerHTML = '';

    if (data['result_set']['n_available_rows'] == 0) {
	var h3 = document.createElement("h3");
	h3.className = "buttonfake";
	h3.append('No datasets were found matching the filtering criteria');
	results_node.append(h3);
        return;
    }

    results_node.append(add_page_controls(data,'toppagecontrolbar'));
    results_node.append(document.createElement("br"));
    results_node.append(document.createElement("br"));
    results_node.append(document.createElement("br"));

    var table = document.createElement("table");
    table.className = "pcdatatable coursetext";
    var tr = document.createElement("tr");
    tr.className = "stickyrow";
    var td;

    var what = _px_settings['data_mode'];
    for (var f of data['result_set'][what+'_title_list']) {
	td = document.createElement("th");
	td.style.textTransform = 'capitalize';
	td.append(f);
	tr.append(td);
    }
    table.append(tr);

    for (let row in data[what]) {
	tr = document.createElement("tr");
	var fnum = 0;
	var pxid = null;

	for (var value of data[what][row]) {
	    var f = data['result_set'][what+'_title_list'][fnum++];

            td = document.createElement("td");

            var span = document.createElement("span");
	    if (f.endsWith('dentifier')) {
                span = document.createElement("a");
                //span.onclick = function() { PXdataset_details(data[what][row],true); };
                //span.title = 'quick view';
		span.href = "?pxid="+value;
                span.title = 'view full details for this dataset';
		pxid = value;
	    }
            else if (f.endsWith('date')) {
                td.style.whiteSpace = 'nowrap';
	    }
	    else if (f in _px_settings['text_to_facet'][_px_settings['data_mode']]) {
		var ff =  _px_settings['text_to_facet'][_px_settings['data_mode']][f];

		td.style.textAlign = 'center';
		span = document.createElement("a");
		span.style.fontWeight = "normal";
		span.setAttribute('onclick', 'get_PXdata("'+ff+'","'+value+'","set");');
		span.title = 'filter table by '+f+' = '+value;
	    }
	    else if (f == 'SDRF' && value) {
		if (pxid) {
                    span = document.createElement("a");
                    span.href = "?click=sdrf&pxid="+pxid;
		}
		span.className = "buttonfake";
		//td.className = "current";
                //span.title = 'view SDRF info and details for this dataset';
		span.title = value;
		value = f;
	    }

	    if (f == 'publications')
		td.innerHTML = value;
	    else {
		span.innerHTML = highlight(value);
		td.append(span);
	    }

            tr.append(td);
	}
	table.append(tr);
    }

    results_node.append(table);
    results_node.append(document.createElement("br"));
    if (data['result_set']['n_rows_returned'] > 10)
	results_node.append(add_page_controls(data,null));
    results_node.append(document.createElement("br"));
    results_node.append(document.createElement("br"));

}


function highlight(string) {
    if (_api.query['search'] && string) {
	for (var val of _api.query['search'].split(',')) {
	    var reg = new RegExp('('+val+')', 'gi');
	    string = string.replace(reg,'<span title="matches search term: '+val+'" class="highlight">$1</span>');
	}
    }
    return string;
}


function add_page_controls(data,htmlid) {
    var div = document.createElement("div");
    div.className = 'pagecontrols';
    if (htmlid)
	div.id = htmlid;
    var span;

    var pages = [1];
    for (let c of [-2,-1, 0, 1, 2]) 
	pages.push(Number(data['result_set']['page_number'])+c);
    pages.push(Number(data['result_set']['n_available_pages']));

    span = document.createElement("h3");
    span.style.display = "inline";
    span.append("Viewing "+data['result_set']['n_rows_returned']+" out of "+data['result_set']['n_available_rows']+" records"); // update to [what]?
    div.append(span);

    span = document.createElement("h3");
    span.style.marginLeft = "70px";
    span.style.display = "inline";
    span.append("Page:");
    div.append(span);

    var prev = 0;
    for (let p of pages.sort(function (a, b) { return a - b; })) {
	if (p==prev || p<1 || p>data['result_set']['n_available_pages'])
	    continue;

	if (p > prev+1) {
	    for (var c in [1,2,3]) {
		span = document.createElement("span");
		span.style.marginLeft = "10px";
		span.className = "bigdot";
		div.append(span);
	    }
	}

        span = document.createElement("span");
        span.style.marginLeft = "10px";
        span.append(p);

	if (p == Number(data['result_set']['page_number'])) {
            span.className = "buttonfake";
	}
	else {
            span.className = "buttonlike";
            span.setAttribute('onclick', 'get_PXdata("pageNumber","'+p+'","set");');
            span.title = 'go to page '+p;
	}
        div.append(span);
	prev = p;
    }


    span = document.createElement("h3");
    span.style.marginLeft = "70px";
    span.style.display = "inline";
    span.append("View: ");
    div.append(span);

    span = document.createElement('select');
    span.className = "buttonlike";
    span.style.padding = "4px";
    span.setAttribute('onchange', 'get_PXdata("pageSize",this.value,"set");');
    for (let c of [10, 25, 50, 100, 500, 1000000]) {
	var opt = document.createElement('option');
	opt.value = c;
        if (c == Number(data['result_set']['page_size']))
	    opt.selected = true;
	opt.innerHTML = (c>100000?'All':c)+" items";
	span.append(opt);
    }
    div.append(span);

    span = document.createElement("h3");
    span.style.marginLeft = "70px";
    span.style.display = "inline";
    span.append('Download: ');
    div.append(span);

    var separator = '';
    for (var format of ['tsv','json']) {
	var url = _api.datasets + '?src=PCUIdownload&outputFormat=' + format;
	for (var q in _api.query) {
	    value = _api.query[q];
            if (q =='pageNumber')
		value = 1;
            else if (q =='pageSize')
		value = 1000000;
            else if (q =='outputFormat')
		value = null;

	    if (value)
		url += "&" + q + '=' + value;
	}

	var span = document.createElement("a");
	span.title = 'download all rows of this resultset in '+format+' format';
	span.href = url;
	span.download = "proteomexchange_datasets."+format
	span.innerHTML = format;

	div.append(separator);
	div.append(span);

	separator = ' | ';
    }

    return div;
}

function get_PXdeets_div(preview=false) {
    var div;
    if (document.getElementById('data-details'))
        div = document.getElementById('data-details');
    else {
        div = document.createElement("div");
        div.id = 'data-details';
        if (preview) {
            div.className = 'data-popup';
            div.style.overflow = 'auto';
        }
        else {
            div.className = 'data-full';
            document.getElementById("results").style.width = '1000px';
            document.getElementById("results").style.margin = '0px auto';
        }
        document.getElementById("results").append(div);
    }
    div.innerHTML = '';

    if (!preview) {
        var ele = document.createElement("a");
	ele.className = 'linkback';
        ele.href = "?view="+_px_settings['data_mode'];
        ele.append("\u{2B9D} Full "+_px_settings['data_mode']+" listing");
	document.getElementById("results").insertBefore(ele, div);
    }

    return div;
}


function PXdataset_details(itemdata,preview=false) {
    var div = get_PXdeets_div(preview);

    var accession = '--n/a--';
    var version = null;

    if (itemdata['datasetHistory'].length > 0) {
	for (let his of itemdata['datasetHistory']) {
            if (his["isReturnedVersion"]) {
		itemdata['__current__datasetHistory'] = his;
		break;
	    }
	}
	accession = itemdata['__current__datasetHistory']['datasetIdentifier'];
	version = itemdata['__current__datasetHistory']['revisionNumber'];
    }
    else {
	for (var thing of itemdata['identifiers']) {
	    if (thing.accession == 'MS:1001919')
		accession = thing.value;
	    if (thing.accession == 'MS:1001921')
		version = thing.value;
	}
    }

    var span = document.createElement(preview?"h3":"h1");
    span.className = 'dataset-title';
    span.style.margin = '0';
    if (preview)
        span.append("Dataset Overview: ");
    span.append(accession);
    if (version)
	span.append(" v"+version);
    div.append(span);

    span = document.createElement("div");
    span.className = 'dataset-content';
    div.append(span);

    if (preview) {
        var ele = document.createElement("a");
        ele.style.float = 'right';
        ele.target = 'pxdetail';
        ele.href = "?pxid="+itemdata['id_name'];
        ele.title = 'view full details for this library';
        ele.append('View full details');
        span.append(ele);
        span.append(document.createElement("br"));
    }

    var esqueleto = {
        'Dataset Summary' : [
	    '|Title|{title}',
	    '|Description|{description}',
	    '|Hosting Repository|{datasetSummary/hostingRepository}',
	    '|Announce Date|{datasetSummary/announceDate}',
	    '|Announcement XML|{__current__datasetHistory/announcementXML}',
            '||{identifiers}',
            '||{datasetSummary/terms}',
	    '|Dataset Origin|{datasetOrigins}',
            '|Primary Submitter|{__current__datasetHistory/primarySubmitter}',
	    '|Species List|{species}',
	    '|Modification List|{modifications}',
	    '|Instrument List|{instruments}'
	],
	'Dataset History' : [
            '||{datasetHistory}[Revision%revisionNumber,Datetime%identifierDate%submissionDate%revisionDate,Status%status,ChangeLog Entry%changeLogEntry]'
	],
	'Publication List' : [  // more here....todo
	    '||{publications}'
	],
	'Keyword List' : [
	    '||{keywords}'
	],
	'Contact List' : [
	    '||{contacts}'
	],
	'Full Dataset Link List' : [
	    '||{fullDatasetLinks}'
	],
	'SDRF (Sample and Datafile Relationship Format)' : [
	    '|Data URL|{sdrf_metadata/submitted_sdrf_data_url}',
	    '|UI URL|{sdrf_metadata/submitted_sdrf_ui_url}',
	    '|Ext. Data URL|{sdrf_metadata/external_sdrf_data_url}',
	    '|Ext. UI URL|{sdrf_metadata/external_sdrf_ui_url}',
	    '|N Samples|{sdrf_metadata/sdrf_data/n_samples}',
	    '|N Files|{sdrf_metadata/sdrf_data/n_files}',
	    '|N Rows|{sdrf_metadata/sdrf_data/n_rows}'
	],
	'Full Dataset File List' : [
	    '||{datasetFiles}'
	]
    };


    for (var head in esqueleto) {
        var ele = document.createElement("div");
        ele.className = 'dataset-secthead';
        ele.append(head);
        span.append(ele);

        var table = document.createElement("table");
        table.className = 'dataset-summary coursetext';
        table.style.width = '100%';

        for (var row of esqueleto[head]) {
            var [format, name, lookup] = row.split("|");

	    var [path1, path2, path3] = lookup.substring( lookup.indexOf( '{' ) + 1, lookup.indexOf( '}' ) ).split('/');
	    var value = itemdata[path1];
	    if (path2 && value)
		value = value[path2];
	    if (path3 && value)
		value = value[path3];

            var fields = lookup.substring( lookup.indexOf( '[' ) + 1, lookup.indexOf( ']' ) ).split(',');

            if (!format)
                format = 'td';

            if (typeof value === 'string' || typeof value === 'number') {
		var tr = document.createElement("tr");
		var td = document.createElement(format);
		td.className = 'datafieldname'; // CSS trickery
                var bold = document.createElement("strong");
                bold.append(name);
                td.append(bold);
                tr.append(td);

                td = document.createElement(format);
                if (name.startsWith('Announcement XML')) {
                    var link = document.createElement("a");
                    link.target = "_xml";
                    link.href  = "/cgi/GetDataset?outputMode=XML&test=no&ID="+accession;
		    if (itemdata['__current__datasetHistory']['reanalysisNumber'])
			link.href += "." + itemdata['__current__datasetHistory']['reanalysisNumber'];
		    link.href += "-" + itemdata['__current__datasetHistory']['revisionNumber'];
                    link.append(value);
                    td.append(link);
		}
                else if (typeof value === 'string' && value.startsWith('http')) {
                    var link = document.createElement("a");
                    link.target = "_pxlink";
                    link.href = value;
                    link.append(value);
                    td.append(link);
                }
		else
		    td.append(value);

                if (name == "N Rows") {  // meh
                    var link = document.createElement("a");
		    link.id = "pagelink_sdrf";
		    link.onclick = function() { render_PXtable(itemdata['sdrf_metadata']['sdrf_data']['titles'],itemdata['sdrf_metadata']['sdrf_data']['rows'], accession); toggle_box("table-details"); };
		    link.append(' [ view ]');
		    link.title = 'view full SDRF data table (pop-up)';
		    td.append(link);
		}

		tr.append(td);

		table.append(tr);
            }
            else if (Array.isArray(value)) {
                if (name) {
                    var tr = document.createElement("tr");
                    var td = document.createElement(format);
                    td.className = 'datafieldname'; // CSS trickery
                    var bold = document.createElement("strong");
                    bold.append(name);
                    td.append(bold);
                    tr.append(td);

		    td = document.createElement(format);
		    var br = false;
                    for (var arrit of value) {
			if (br)
			    td.append(document.createElement("br"));

			if ('terms' in arrit) {
			    var space = '';
			    for (var term of arrit['terms']) {
				td.append(space);
				if (term['value'])
				    td.append(term['value']);
				else
				    td.append(term['name']);
				space = '; ';
				br = true;
			    }
			}
			else if (arrit['value'])
                            td.append(arrit['value']);
			else
                            td.append(arrit['name']);
                        br = true;
		    }
                    tr.append(td);
                    table.append(tr);
		}

		else if (fields.length > 1) {
                    var tr = document.createElement("tr");
                    for (var field of fields) {
			var td = document.createElement("th");
			td.append(field.split("%")[0]);
			tr.append(td);
		    }
                    table.append(tr);

                    for (var arrit of value) {
			tr = document.createElement("tr");
			if (arrit["isReturnedVersion"])
                            tr.className = 'dataset-currentrev';

			for (var field of fields) {
                            var td = document.createElement(format);

			    var val = arrit[field];
			    if (val == null) {
				for (var alt of field.split("%")) {
				    if (arrit[alt] != null) {
					val = arrit[alt];
					if (alt.includes('Date'))
					    val = val.replace("T"," ").replace("Z"," ");
				    }
				}
			    }
			    if (val != null) {
				td.append(val);
			    }
                            tr.append(td);
			}
			table.append(tr);
		    }
		}

		// special handling
                else if (head == 'Contact List') {
                    for (var arrit of value) {
			var tr = document.createElement("tr");
			var td = document.createElement(format);
			td.className = 'datafieldname'; // CSS trickery
			var bold = document.createElement("strong");
			td.append(bold);
			tr.append(td);

			td = document.createElement(format);
			var br = false;
                        for (var term of arrit['terms']) {
                            if (term['value']) {
				if (br)
				    td.append(document.createElement("br"));

                                td.append(term['value']);
				br = true;
			    }
                            else
                                bold.append(term['name']);
                        }

			tr.append(td);
			table.append(tr);
                    }
		}

                else if (head == 'Publication List') {
                    for (var arrit of value) {
                        var tr = document.createElement("tr");
                        var td = document.createElement(format);

                        var br = false;
			var link = null;
                        for (var term of arrit['terms']) {
                            if (br)
                                td.append(document.createElement("br"));

                            if (term['accession'] == 'MS:1000879') {
				var link = document.createElement("a");
				link.target = 'pubmed';
				link.href = 'https://pubmed.ncbi.nlm.nih.gov/' + term['value'];
				link.append(' [ pubmed ]');
			    }
                            else if (term['accession'] == 'MS:1001922') {
				var link = document.createElement("a");
				link.target = 'doi';
				link.href = 'https://dx.doi.org/' + term['value'];
				link.append(' [ DOI: '+term['value']+' ]');
			    }
                            else if (term['value']) {
                                td.append(term['value']);
                                br = true;
                            }
                            else
                                td.append(term['name']);
                        }
			if (link)
                            td.append(link);

                        tr.append(td);
                        table.append(tr);
                    }

		}

		else {
		    for (var arrit of value) {
                        if (arrit['accession'] == 'MS:1001919' ||
			    arrit['accession'] == 'MS:1001921')
			    continue;

			var tr = document.createElement("tr");
			var td = document.createElement(format);
			td.className = 'datafieldname'; // CSS trickery
			var bold = document.createElement("strong");
			if (arrit['value'] && arrit['name'])
			    bold.append(arrit['name'].replace("ProteomeXchange","PX").replace("URI",""));
			else {
			    var fieldname = '------ dataset property';
			    if (['MS:1002854','MS:1002855','PRIDE:0000414'].includes(arrit['accession']))
				fieldname = 'Review Level';
			    else if (['MS:1002857','MS:1002856','PRIDE:0000417'].includes(arrit['accession']))
				fieldname = 'Repository Support';
			    bold.append(fieldname);
			}
			td.append(bold);
			tr.append(td);

			td = document.createElement(format);
			td.style.width = '100%';
			if (arrit['value']) {
			    if (arrit['value'].startsWith('http') || arrit['value'].startsWith('ftp://')) {
				var url = arrit['value'];
				if (arrit['value'].includes('pride.ebi'))
				    url = url.replace('ftp://','https://');
				var link = document.createElement("a");
				link.target = "_download";
				link.href = url;
				link.append(arrit['value']);
				td.append(link);
			    }
                            else if (arrit['accession'] == 'MS:1001922') {
                                var link = document.createElement("a");
                                link.target = 'doi';
                                link.href = 'https://dx.doi.org/' + arrit['value'];
                                link.append(arrit['value']);
				td.append(link);
                            }
			    else
				td.append(arrit['value']);
			}
			else
			    td.append(arrit['name']);
			tr.append(td);
			table.append(tr);
		    }
		}
	    }
	}

        span.append(table);

	if (head == 'Full Dataset File List') {
	    ele.append(" ("+itemdata['datasetFiles'].length+" files)");
	    if (table.scrollHeight > 200) {
		table.id = "data-files-list_div";
		table.style.display = 'block';
		table.style.overflow = 'hidden';
		table.style.maxHeight = '200px';
		ele.id = "data-files-list_head";
		ele.className += " filterlink mas";
		ele.style.cursor = 'pointer';
		ele.title = "Click to view / hide all";
		ele.setAttribute('onclick', 'mas_o_menos("data-files-list");');
	    }
	}

	span.append(document.createElement("br"));
    }
}

function UNUSED_PXdataset_details() {
    span.append(document.createElement("br"));
    span.append(document.createElement("br"));
    span.append(document.createElement("br"));

    /////////
    var skeleton = {
        'identifiers' : [
            '|MS:1001919|',
            '|MS:1001922|',
            '|MS:1001921|',
            '|MS:1002487|',
            '|MS:1002632|',
            '|MS:1002836|',
            '|MS:1002872|'
        ],
        'contacts' : [
	    'th|MS:1002332|MS:1000586',
	    'th|MS:1002037|MS:1000586',
	    '|MS:1000590|',
	    '|MS:1000589|'
	],
        'modifications' : [
	    '|accession|name'
	],
        'species' : [
	    '|MS:1001467|',
	    '|MS:1001468|',
	    '|MS:1001469|'
	],
        'instruments' : [
            '|accession|name'
        ],
        'keywords' : [
	    '|MS:1001925|',
	    '|MS:1001926|',
	    '|MS:1002340|'
	],
        'publications' : [
	    '|PRIDE:0000400|',
	    '|PRIDE:0000412|',
	    '|MS:1000879|',
	    '|MS:1001922|',
	    '|MS:1002853|',
	    '|MS:1002866|',
	    '|MS:1002858|' // fix this...?
	],
        'fullDatasetLinks' : [
	    '|MS:1001930|',
	    '|MS:1002031|',
	    '|MS:1002032|',
	    '|MS:1002420|',
	    '|MS:1002488|',
	    '|MS:1002633|',
	    '|MS:1002837|',
	    '|MS:1002852|',
	    '|MS:1002873|'
	],
        'datasetFiles' : [
	    '|MS:1002845|',
	    '|MS:1002846|',
	    '|MS:1002848|',
	    '|MS:1002849|',
	    '|MS:1002850|',
	    '|MS:1002851|'
	]

    };

    for (var head in itemdata) {
	if (itemdata[head] == null)
	    continue;
        else if (Array.isArray(itemdata[head]) && itemdata[head].length < 1)
	    continue;

        var ele = document.createElement("div");
        ele.className = 'dataset-secthead';
        ele.append(head.replace('dataset',''));
        span.append(ele);

        var table = document.createElement("table");
        table.className = 'dataset-summary coursetext';
        table.style.width = '100%';

        if (typeof itemdata[head] === 'string') {
            var tr = document.createElement("tr");
            var td = document.createElement("td");

            if (itemdata[head])
                td.append(itemdata[head]);
            else
                td.append('--n/a--');
            tr.append(td);

            table.append(tr);
            //seen[skeleton[head]] = true;
        }
	else if (Array.isArray(itemdata[head])) {
            for (var arrit of itemdata[head]) {
		var terms = {};

		if ('terms' in arrit) {
		    for (var term of arrit['terms'])
			terms[term['accession']] = term;
		}
		else if ('accession' in arrit) {
                    terms[arrit['accession']] = arrit;
		}

		// //////////////////
		if (head in skeleton) {
		    for (var row of skeleton[head]) {
                        var tr = document.createElement("tr");

			var [format, name, value] = row.split("|");
			if (!format)
			    format = 'td';

			var nom = name;
			var val = null;
			if (terms[name])
			    nom = terms[name]['name'];
			else if (name.includes(":"))
			    continue;
			else {
			    console.log(head);
			    nom = terms[Object.keys(terms)[0]][name];
			    val = terms[Object.keys(terms)[0]][value];
			    name = Object.keys(terms)[0];
			}

			var td = document.createElement(format);
			td.className = 'datafieldname'; // CSS trickery
			var bold = document.createElement("strong");
			bold.append(nom);
			td.append(bold);
			tr.append(td);

			if (!val) {
                            if (value && terms[value])
				val = terms[value]['value'];
                            else if (terms[name] && terms[name]['value'])
				val = terms[name]['value'];
			    else
				val = "???";
			}

			td = document.createElement(format);
                        td.append(val);
                        tr.append(td);
			table.append(tr);

			delete terms[name];
                        if (value && terms[value])
                            delete terms[value];
		    }
		}

		// leftovers...
                for (var term in terms) {
		    var tr = document.createElement("tr");
		    tr.className = 'highlight';
		    var td = document.createElement("td");
                    td.className = 'datafieldname'; // CSS trickery
                    td.append('---'+term);
		    tr.append(td);
		    td = document.createElement("td");
                    td.append(JSON.stringify(terms[term]));
		    tr.append(td);
		    table.append(tr);
		}

	    }



	}
        else {
	    // /////////////////
	    continue;


            for (var fname in skeleton[head]) {
                var tr = document.createElement("tr");
                var td = document.createElement("td");
                if (skeleton[head][fname].endsWith('_full_name'))
                    td = document.createElement("th");
                td.className = 'datafieldname'; // CSS trickery
                var bold = document.createElement("strong");
                bold.append(fname);
                td.append(bold);
                tr.append(td);

                if (skeleton[head][fname].endsWith('_full_name'))
                    td = document.createElement("th");
                else
                    td = document.createElement("td");
                if(itemdata[skeleton[head][fname]])
                    td.append(itemdata[skeleton[head][fname]]);
                else
                    td.append('--n/a--');
                tr.append(td);

                table.append(tr);
                seen[skeleton[head][fname]] = true;
            }
        }

        span.append(table);
    }


    div.append(span);

}


function PXlibrary_details(itemdata,preview=false) {
    var div = get_PXdeets_div(preview);

    var span = document.createElement(preview?"h3":"h1");
    span.className = 'dataset-title';
    span.style.margin = '0';
    if (preview)
	span.append("Library Overview: ");
    span.append(itemdata['id_name']);
    div.append(span);

    span = document.createElement("div");
    span.className = 'dataset-content';

    if (preview) {
        var ele = document.createElement("a");
	ele.style.float = 'right';
	ele.target = 'pxdetail';
        ele.href = "?pxid="+itemdata['id_name'];
	ele.title = 'view full details for this library';
	ele.append('View full details');
        span.append(ele);
        span.append(document.createElement("br"));
    }

    var skeleton = {};
    if (preview)
	skeleton = {
	    'Summary' : {
		'Title': 'title',
		'Description': 'description',
		'Species': 'species',
		'Source': 'source',
		'Number of Entries': 'n_entries',
		'Mass Modifications': 'mass_modifications',
		'Instruments': 'instruments',
		'Fragmentation Type': 'fragmentation_type',
		'Version': 'version_tag'
	    },
	    'Keyword List': 'keywords'
	};
    else
	skeleton = {
	    'Summary' : {
		'Title': 'title',
		'Description': 'description',
		'Species': 'species',
		'Source': 'source',
		'Number of Entries': 'n_entries',
		'Mass Modifications': 'mass_modifications',
		'Instruments': 'instruments',
		'Fragmentation Type': 'fragmentation_type',
		'Version': 'version_tag',
		'Documentation URL': 'documentation_url'
	    },
	    'Keyword List': 'keywords',
            'Contact List' : {
                'Lab Head': 'lab_head_full_name',
                'Affiliation': 'lab_head_affiliation',
                'Email': 'lab_head_email',
                'Submitter': 'submitter_full_name',
                'Submitter Affiliation': 'submitter_affiliation',
                'Submitter Email': 'submitter_email'
	    },
            'Library Details' : {
                'Release Date': 'release_date',
		'Publication': 'publication',
		'Intended Sample Type': 'intended_sample_type',
		'Intended Workflow': 'intended_workflow',
		'Library Type': 'library_type',
		'Library Building Protocol': 'library_building_protocol',
		'Library Building Software': 'library_building_software',
		'Provenance': 'provenance_information',
		'QC Score': 'QC_score',
		'QC Report URL': 'QC_report_url',
		'Converted to mzSpecLib': 'converted_to_mzSpecLib',
		'Metadata Quality Score': 'metadata_quality_score'
            },
            'File Details' : {
		'Local Filename': 'local_filename',
		'Local md5 Checksum': 'local_md5_checksum',
		'Original Filename': 'original_filename',
		'Original md5 Checksum': 'original_md5_checksum',
		'Source URL': 'source_url'
            },
            'Record Info' : {
		'Library Record id': 'library_record_id',
		'Record Created': 'record_created_datetime',
		'Record Automation Updated': 'record_automation_updated_datetime',
		'Record Human Updated': 'record_human_updated_datetime',
		'Changelog Comments': 'changelog_comments',
		'Status': 'status'
	    }
	};

    var seen = {'id_name' : true};
    for (var head in skeleton) {
	var ele = document.createElement("div");
	ele.className = 'dataset-secthead';
	ele.append(head);
	span.append(ele);

	var table = document.createElement("table");
	table.className = 'dataset-summary coursetext';
	table.style.width = '100%';

	if( typeof skeleton[head] === 'string' ) {
            var tr = document.createElement("tr");
            var td = document.createElement("td");

            if(itemdata[skeleton[head]])
                td.append(itemdata[skeleton[head]]);
            else
                td.append('--n/a--');
            tr.append(td);

            table.append(tr);
	    seen[skeleton[head]] = true;
	}
	else {
	    for (var fname in skeleton[head]) {
		var tr = document.createElement("tr");
		var td = document.createElement("td");
		if (skeleton[head][fname].endsWith('_full_name'))
		    td = document.createElement("th");
                td.className = 'datafieldname'; // CSS trickery
		var bold = document.createElement("strong");
		bold.append(fname);
		td.append(bold);
		tr.append(td);

		if (skeleton[head][fname].endsWith('_full_name'))
		    td = document.createElement("th");
		else
		    td = document.createElement("td");
		if(itemdata[skeleton[head][fname]])
		    td.append(itemdata[skeleton[head][fname]]);
		else
		    td.append('--n/a--');
		tr.append(td);

		table.append(tr);
		seen[skeleton[head][fname]] = true;
	    }
	}

        span.append(table);
    }

    var notseen = [];
    for (var fname in itemdata)
	if (!(fname in seen))
            notseen.push(fname);

    if (!preview && notseen.length > 0) {
        var ele = document.createElement("div");
        ele.className = 'dataset-secthead';
        ele.append('Other Info');
        span.append(ele);

	var table = document.createElement("table");
	table.className = 'dataset-summary coursetext';
        table.style.width = '100%';

        for (var fname of notseen) {
	    var tr = document.createElement("tr");
	    var td = document.createElement("td");
            td.className = 'datafieldname'; // CSS trickery
	    var bold = document.createElement("strong");
	    bold.append(fname);
            td.append(bold);
            tr.append(td);

	    td = document.createElement("td");
            td.append(itemdata[fname]);
	    tr.append(td);

	    table.append(tr);
	}
	span.append(table);
    }


    if (preview) {
	span.append(document.createElement("br"));

	table = document.createElement("a");
	table.style.float= 'right';
	table.className = 'dataset-title';
	table.setAttribute('onclick', 'toggle_box("data-details");');
	table.append("Dismiss");
	span.append(table);
    }

    div.append(span);

    //if (preview)
    toggle_box('data-details',true);
    // ////tpp_dragElement('data-details');
}


function render_PXtable(headings,rowdata,what=null) {
    var div;
    if (document.getElementById('table-details'))
        div = document.getElementById('table-details');
    else {
        div = document.createElement("div");
        div.id = 'table-details';
        div.className = 'data-popup';
        div.style.overflow = 'auto';
        document.getElementById("results").append(div);
    }
    div.innerHTML = '';

    var span = document.createElement("h3");
    span.className = 'dataset-title';
    span.style.margin = '0';
    span.style.position = 'sticky';
    span.style.left = '0';
    span.style.top = '0';
    span.append("SDRF Info");
    if (what)
	span.append(": [ "+what+" ]");

    var span2 = document.createElement("span");
    span2.className = 'filterlink';
    span2.style.float= 'right';
    span.title = 'dismiss';
    span2.setAttribute('onclick', 'toggle_box("table-details");');
    span2.append(" \u{2716} ");
    span.append(span2);

    div.append(span);

    var table = document.createElement("table");
    table.className = 'dataset-summary coursetext';
    table.style.width = '100%';

    var tr = document.createElement("tr");
    tr.className = 'stickyrow';
    for (var head of headings) {
        var td = document.createElement('th');
        td.style.top = span.scrollHeight + 'px';
        td.append(head.replace('[',' ['));
        tr.append(td);
    }
    table.append(tr);

    for (var row of rowdata) {
	tr = document.createElement("tr");
	for (var cell of row) {
            var td = document.createElement('td');
            td.style.whiteSpace = 'nowrap';
            td.append(cell);
            tr.append(td);
	}
	table.append(tr);
    }

    div.append(table);

    return div;
}


// utilities .................................................................
function submit_on_enter(ele) {
    if (event.key === 'Enter') {
	if (ele.id == 'textsearch')
	    get_PXdata("search",ele.value,'add');
	else
	    console.log("element id not recognized...");
    }
}

function mas_o_menos(name) {
    var what = document.getElementById(name+"_div");
    if (what.style.maxHeight == '200px') {
	what.style.maxHeight = what.scrollHeight +'px';
	document.getElementById(name+"_head").classList.replace("mas", "menos");
    }
    else {
	what.style.maxHeight = '200px';
        document.getElementById(name+"_head").classList.replace("menos", "mas");
    }
}

function getAnimatedWaitBar(width) {
    var wait = document.createElement("span");
    wait.className = 'pagecontrols loading_cell';
    if (width)
	wait.style.width = width;
    var waitbar = document.createElement("span");
    waitbar.className = 'loading_bar';
    wait.append(waitbar);
    return wait;
}

window.onpopstate = function(e){
    if(e.state)
	document.documentElement.innerHTML = e.state.html;
};


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
