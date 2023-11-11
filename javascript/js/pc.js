var _api = {};
_api['datasets'] = "/api/proxi/v0.1/datasets";
_api['query'] = {};
var _ordered_facets = ['search','species','keywords','instrument','year'];
var _render_overview = true;

function main() {
    get_datasets(null,null,null);
}


function get_datasets(filter,value,action) {
    var results_node = document.getElementById("results");
    results_node.innerHTML = '';
    results_node.className = '';

    var wait = getAnimatedWaitBar("100px");
    wait.style.marginLeft = "50px";
    wait.style.marginRight = "10px";
    results_node.appendChild(wait);
    results_node.appendChild(document.createTextNode('Loading...'));

    if (value && value.startsWith('fromPCUI:')) {
	var htmlid = value.replace('fromPCUI:','');
	value = document.getElementById(htmlid).value;
    }

    var apiurl = _api.datasets + '?src=PCUI';
    if (filter) {
	for (var q in _api.query) {
	    if (filter == q) {
		if (action == 'set') {
		    if (value)
			apiurl += "&" + filter + '=' + value;
		}
		else if (action == 'add') {
                    apiurl +=  "&" + filter + '=' + value.trim();
		    if (_api.query[q]) {
			for (var v of _api.query[q].split(',')) {
			    if (v.trim() != value.trim())
				apiurl += ',' + v.trim();
			}
		    }
		}
                else if (action == 'remove') {
                    var allvalues = '';
                    var comma = '';
                    for (var v of _api.query[q].split(',')) {
                        if (v != value) {
                            allvalues += comma + v.trim();
                            comma = ',';
			}
                    }
                    if (allvalues)
			apiurl +=  "&" + filter + '=' + allvalues;
                }
	    }
            else if (_api.query[q])
		apiurl += "&" + q + '=' + _api.query[q];

	}
    }

    fetch(apiurl)
        .then(response => {
	    if (response.ok) return response.json();
	    else throw new Error('Unable to fetch data '+apiurl);
	})
        .then(data => {
	    for (var q in data['query']) {
		if (data.query[q])
		    _api['query'][q] = data.query[q];
		else
		    _api['query'][q] = null;
	    }

	    if (data['result_set']['n_rows_returned'] == 0 && data['result_set']['n_available_rows'] > 0) {
		get_datasets("pageNumber","1","set");
		return;
	    }
	    add_filter_controls(data);
	    add_resultset_table(data);
	    if (_render_overview) {
		render_overview_wheels(data);
		_render_overview = false;  // uncomment to run only once
	    }

        })
        .catch(error => {
            results_node.innerHTML = '';
	    results_node.className = "error";
	    results_node.innerHTML = "<br>" + error + "<br><br>";
            console.error(error);
	});

}

function render_overview_wheels(data) {
    var palette = ["#2c99ce", "#384955", "#9BAEBC", "#B68751", "#7E5521", "#f26722", "#55433B", "#BDA79D", "#00B090", "#00785E"];

    for (var thing of ['species','instrument','keywords']) {
	var svg = document.getElementById("svg_"+thing);

	temp = document.getElementById("container_"+thing);
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

	num = 0;
	const radius = 100;
	const circumference = 2 * Math.PI * radius;
	var strokeOffset = circumference / 2;
	for (var item of data.facets[thing]) {
	    var pct = item['count'] / total;
            var link = document.createElementNS("http://www.w3.org/2000/svg", "a");
	    link.setAttribute('href', 'javascript:get_datasets("'+thing+'","'+item['name']+'","add")');

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
            arc.setAttribute('onmouseover', 'showstats("'+thing+'","'+item['count']+'","'+item['name']+'","'+palette[num]+'")');
	    link.appendChild(arc);
	    container.appendChild(link);

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
        container.appendChild(arc);

        var txt = document.createElementNS("http://www.w3.org/2000/svg", "text");
	txt.setAttribute("id", "stats1_"+thing);
        txt.setAttribute('x', 150);
        txt.setAttribute('y', 130);
        txt.setAttribute('text-anchor', 'middle');
        txt.setAttribute('font-size', '14');
	txt.setAttribute('fill', '#fff');
	container.appendChild(txt);

	txt = document.createElementNS("http://www.w3.org/2000/svg", "text");
        txt.setAttribute("id", "stats2_"+thing);
        txt.setAttribute('x', 150);
        txt.setAttribute('y', 145);
        txt.setAttribute('text-anchor', 'middle');
        txt.setAttribute('font-size', '12');
        txt.setAttribute('font-weight', 'bold');
	txt.setAttribute('fill', '#fff');
        container.appendChild(txt);

	svg.appendChild(container);

        if (_render_overview)  // first time
	    showstats(thing,data.facets[thing][0]['count'],data.facets[thing][0]['name'],palette[0]);

    }
}

function showstats(type,amount,value,color) {
    document.getElementById("center_"+type).setAttribute('fill', color);
    document.getElementById("stats1_"+type).innerHTML = amount+" datasets";
    document.getElementById("stats2_"+type).innerHTML = value;
}

// for future use?
function render_overview_bars(data) {
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
	    link.setAttribute('href', 'javascript:get_datasets("'+thing+'","'+item['name']+'","add")');

            var rect = document.createElementNS("http://www.w3.org/2000/svg", "rect");
	    rect.setAttribute('height', 4);
	    rect.setAttribute('x', 5);
            rect.setAttribute('y', 1+num*15);
	    rect.setAttribute('width', 290);
	    rect.setAttribute('fill', '#eee');
	    link.appendChild(rect);

	    rect = document.createElementNS("http://www.w3.org/2000/svg", "rect");
	    rect.setAttribute('height', 4);
	    rect.setAttribute('x', 5);
            rect.setAttribute('y', 1+num*15);
	    rect.setAttribute('width', pct*290);
	    rect.setAttribute('fill', palette[num]);
	    link.appendChild(rect);

	    pct = (100 * pct).toFixed((pct<0.1?1:0));
            var txt = document.createElementNS("http://www.w3.org/2000/svg", "text");
	    txt.setAttribute('x', 10);
	    txt.setAttribute('y', (num+1)*15-1);
	    txt.setAttribute('fill', '#ccc');
	    //txt.appendChild(document.createTextNode(item['name']+" : "+item['count']));
	    txt.appendChild(document.createTextNode(item['name']+" : "+pct+"%"));
	    link.appendChild(txt);

	    container.appendChild(link);

	    if (num++ == 9)
		break;
	}
	svg.appendChild(container);
    }
}

function add_filter_controls(data) {
    var filters_node = document.getElementById("filters");
    filters_node.innerHTML = '';

    var span = document.createElement("h3");
    span.className = "title";
    span.appendChild(document.createTextNode("Filter"));
    filters_node.appendChild(span);

    span = document.createElement("span");
    span.id = "filteredtext";
    filters_node.appendChild(span);
    span = document.createElement("span");
    span.id = "clearfilters";
    filters_node.appendChild(span);
    filters_node.appendChild(document.createElement("br"));
    filters_node.appendChild(document.createElement("br"));

    var numfil = 0;
    for (var facet of _ordered_facets) {
        if (data.query[facet]) {
	    for (var val of data.query[facet].split(',')) {
		span = document.createElement("span");
		span.className = "filtertag x";
		span.setAttribute('onclick', 'get_datasets("'+facet+'","'+val+'","remove");');
		span.title = 'remove "'+val+'" from '+facet+' filter';
		span.appendChild(document.createTextNode(val));
		filters_node.appendChild(span);
		numfil++;
	    }
	}
    }
    filters_node.appendChild(document.createElement("br"));


    span = document.getElementById("filteredtext");
    span.appendChild(document.createTextNode(data['result_set']['n_available_rows']+" dataset"));
    // grammerify
    if (numfil == 0)
	span.appendChild(document.createTextNode("s total"));
    else {
	if (data['result_set']['n_available_rows'] != 1)
	    span.appendChild(document.createTextNode("s pass filter"));
	else
	    span.appendChild(document.createTextNode(" passes filter"));
	if (numfil != 1)
            span.appendChild(document.createTextNode("s"));
    }

    if (numfil > 1) {
	span = document.getElementById("clearfilters");
	span.className = "buttontag";
	span.setAttribute('onclick', 'get_datasets(null,null,null);');
	span.title = "Remove all filters";
	span.appendChild(document.createTextNode("Clear all"));
    }

    if (data['result_set']['n_available_rows'] == 0)
        return;


    var div = document.createElement("div");
    div.className = "dataset-content";
    div.style.wordBreak = "break-word";
    filters_node.appendChild(div);

    span = document.createElement("span");
    span.className = "dataset-secthead";
    span.appendChild(document.createTextNode('Search'));
    div.appendChild(span);
    var i = document.createElement('input');
    i.id = "textsearch";
    i.setAttribute('onkeydown', "submit_on_enter(this);");
    i.style.width = "95%";
    div.appendChild(i);
    span = document.createElement("span");
    span.className = "filtertag";
    span.style.position = "absolute";
    span.title = 'search!';
    span.setAttribute('onclick', 'get_datasets("search","fromPCUI:textsearch","add");');
    span.appendChild(document.createTextNode('\u{1F50E}'));
    div.appendChild(span);

    div.appendChild(document.createElement("br"));
    div.appendChild(document.createElement("br"));

    for (let facet of _ordered_facets) {
	if (facet == 'search')
	    continue;
	var div2 = document.createElement("div");
	div2.id = facet + '_div';
	div2.className = "facetlist";
	div2.style.maxHeight = '200px';

	for (var item of data.facets[facet]) {
	    span = document.createElement("span");
	    span.className = "filterlink";
	    span.setAttribute('onclick', 'get_datasets("'+facet+'","'+item['name']+'","add");');
	    span.appendChild(document.createTextNode(item['name']+" ("+item['count']+")"));
	    div2.appendChild(span);
	}
	div.appendChild(div2);

	span = document.createElement("span");
	span.id = facet + '_head';
	span.className = "dataset-secthead";
	span.style.textTransform = 'capitalize';
	span.appendChild(document.createTextNode('Top '+facet));
	if (div2.scrollHeight > 200) {
            span.className = "dataset-secthead filterlink mas";
            span.setAttribute('onclick', 'mas_o_menos("'+facet+'");');
	    span.title = 'click to see more / fewer';
	}
	div.insertBefore(span, div2);

	div.appendChild(document.createElement("br"));
    }

    span = document.createElement("span");
    span.className = "dataset-secthead filterlink";
    span.setAttribute('onclick', 'get_datasets(null,null,null);');
    span.title = "Remove all filters and page options";
    span.appendChild(document.createTextNode("Reset"));
    div.appendChild(span);
}


function add_resultset_table(data) {
    var results_node = document.getElementById("results");
    results_node.innerHTML = '';

    if (data['result_set']['n_available_rows'] == 0) {
	var h3 = document.createElement("h3");
	h3.className = "buttonfake";
	h3.appendChild(document.createTextNode('No datasets were found matching the filtering criteria'));
	results_node.appendChild(h3);
        return;
    }

    results_node.appendChild(add_page_controls(data));
    results_node.appendChild(document.createElement("br"));
    results_node.appendChild(document.createElement("br"));
    results_node.appendChild(document.createElement("br"));

    var table = document.createElement("table");
    table.className = "pcdatatable coursetext";
    var tr = document.createElement("tr");
    var td;

    for (var f of data['result_set']['datasets_title_list']) {
	td = document.createElement("th");
	td.style.textTransform = 'capitalize';
	td.appendChild(document.createTextNode(f));
	tr.appendChild(td);
    }
    table.appendChild(tr);

    for (var row in data['datasets']) {
	tr = document.createElement("tr");
	var fnum = 0;
	for (var value of data['datasets'][row]) {
	    fnum++;
            td = document.createElement("td");
	    // MEH!
	    if (fnum == 1) {
		span = document.createElement("a");
		span.target = 'pxdetail';
		span.href = "cgi/GetDataset?ID="+value;
		span.appendChild(document.createTextNode(value));
                span.title = 'view full details for this dataset';
		td.appendChild(span);
	    }
            else if (fnum == 4) {
		span = document.createElement("a");
		span.style.fontWeight = "normal";
		span.setAttribute('onclick', 'get_datasets("species","'+value+'","set");');
		span.title = 'filter table by species = '+value;
		span.appendChild(document.createTextNode(value));
		td.appendChild(span);
	    }
            else if (fnum == 5) {
		span = document.createElement("a");
		span.style.fontWeight = "normal";
		span.setAttribute('onclick', 'get_datasets("instrument","'+value+'","set");');
		span.title = 'filter table by instrument = '+value;
		span.appendChild(document.createTextNode(value));
		td.appendChild(span);
	    }
	    else if (fnum == 6)
		td.innerHTML = value;
	    else
		td.appendChild(document.createTextNode(value));
            tr.appendChild(td);
	}
	table.appendChild(tr);
    }

    results_node.appendChild(table);
    results_node.appendChild(document.createElement("br"));
    if (data['result_set']['n_rows_returned'] > 10)
	results_node.appendChild(add_page_controls(data));
    results_node.appendChild(document.createElement("br"));
    results_node.appendChild(document.createElement("br"));

}


function add_page_controls(data) {
    var div = document.createElement("div");
    div.className = 'pagecontrols';
    var span;

    var pages = [1];
    for (let c of [-2,-1, 0, 1, 2]) 
	pages.push(Number(data['result_set']['page_number'])+c);
    pages.push(Number(data['result_set']['n_available_pages']));

    span = document.createElement("h3");
    span.style.marginLeft = "10px";
    span.style.display = "inline";
    span.appendChild(document.createTextNode("Viewing "+data['result_set']['n_rows_returned']+" out of "+data['result_set']['n_available_rows']+" datasets"));
    div.appendChild(span);

    span = document.createElement("h3");
    span.style.marginLeft = "70px";
    span.style.display = "inline";
    span.appendChild(document.createTextNode("Page:"));
    div.appendChild(span);

    var prev = 0;
    for (let p of pages.sort(function (a, b) { return a - b; })) {
	if (p==prev || p<1 || p>data['result_set']['n_available_pages'])
	    continue;

	if (p > prev+1) {
	    for (var c in [1,2,3]) {
		span = document.createElement("span");
		span.style.marginLeft = "10px";
		span.className = "bigdot";
		div.appendChild(span);
	    }
	}

        span = document.createElement("span");
        span.style.marginLeft = "10px";
        span.appendChild(document.createTextNode(p));

	if (p == Number(data['result_set']['page_number'])) {
            span.className = "buttonfake";
	}
	else {
            span.className = "buttonlike";
            span.setAttribute('onclick', 'get_datasets("pageNumber","'+p+'","set");');
            span.title = 'go to page '+p;
	}
        div.appendChild(span);
	prev = p;
    }


    span = document.createElement("h3");
    span.style.marginLeft = "70px";
    span.style.display = "inline";
    span.appendChild(document.createTextNode("View: "));
    div.appendChild(span);

    span = document.createElement('select');
    span.className = "buttonlike";
    span.style.padding = "4px";
    span.setAttribute('onchange', 'get_datasets("pageSize",this.value,"set");');
    for (let c of [10, 25, 50, 100, 500, 1000000]) {
	var opt = document.createElement('option');
	opt.value = c;
        if (c == Number(data['result_set']['page_size']))
	    opt.selected = true;
	opt.innerHTML = (c>100000?'All':c)+" items";
	span.appendChild(opt);
    }
    div.appendChild(span);

    span = document.createElement("h3");
    span.style.marginLeft = "70px";
    span.style.display = "inline";
    span.appendChild(document.createTextNode('Download: '));
    div.appendChild(span);

    var separator = '';
    for (var format of ['tsv','json']) {
	var url = _api.datasets + '?src=pyjamasdown';
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
	    url += "&outputFormat=" + format;
	}

	var span = document.createElement("a");
	span.title = 'download all rows of this resultset in '+format+' format';
	span.href = url;
	span.download = "proteomexchange_datasets."+format
	span.innerHTML = format;

	div.appendChild(document.createTextNode(separator));
	div.appendChild(span);

	separator = ' | ';
    }

    return div;
}


// utilities .................................................................
function submit_on_enter(ele) {
    if (event.key === 'Enter') {
	if (ele.id == 'textsearch')
	    get_datasets("search",ele.value,'add');
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
    wait.className = 'loading_cell';
    if (width)
	wait.style.width = width;
    var waitbar = document.createElement("span");
    waitbar.className = 'loading_bar';
    wait.appendChild(waitbar);
    return wait;
}
