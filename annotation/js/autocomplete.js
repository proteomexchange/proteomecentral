//var max_suggs;
//var fetchResults;
//var fetchQuery;
//var fetchResultsCallback;

/*window.onerror = function(msg, url, lineNo, columnNo, error){
  alert("onerror fired");
}*/

//$( document ).ready( function(){
//function add_typeahead() {
//    $('.nodeInput').typeahead({

function add_typeahead(element_id) {
    $('#'+element_id).typeahead({
	fitToElement: false,
	items: 15,
	highlighter: function (item){
	    var items = item.split('==');

	    var parts = items[0].split('#');
	    var html = '';
	    for (i = 0; i < parts.length; i++){
		if (i % 2 == 0){
		    html += parts[i];
		} else {
		    html += '<strong><font color="blue">' + parts[i] + '</font></strong>';
		}
	    }

	    html += '<span class="infotext right">' + items[1] + '</span>';

	    return html;
	},
	sorter: function (items) {
	    // already sorted by query
	    return items;
	},
	updater: function (item) {
	    //console.log("updater: ");
	    //console.log($('.nodeInput').val());

	    var items = item.split('==');

	    $('#'+element_id+"_CV").val(items[1]);

	    var tmp = $('#'+element_id).val().split(",");
	    tmp = tmp.slice(0,tmp.length-1).join(", ");
	    var parts = items[0].split('#');
	    var text = "";
	    if (tmp.length > 0){
		text += tmp + ", ";
	    }
	    text += parts.join("");

	    return text;
	},
	matcher: function (item){
	    //console.log("matcher");
	    return true;
	},
	name: 'stuff',
	display: 'value',
	source: function(query, callback) {
	    //console.log("'"+query+"'");
	    //console.log($('.nodeInput').innerWidth());
	    //console.log(query.split(","));
	    query = query.split(",");
	    //var first_part = query.slice(0,query.length-1).join(", ");
	    //console.log(first_part);

	    $('#'+element_id+"_CV").val(''); // clear it in case blank or there is no match

	    query = query[query.length-1].trim();
	    if (query.length == 0){
		return;
	    }
	    var hit = false;
	    var fname = $('#'+element_id).attr("name");

	    var URIquery = encodeURIComponent(query);

	    $.ajax({
		url: "/api/autocomplete/v0.1/autocomplete?word="+URIquery+"&limit=15&field_name="+fname,
		cache: false,
		dataType:"jsonp",
		success: function (response) {
		    var results = [];
		    $.each(response, function(i, item){
			var lowerItem = item.name.toLowerCase();
			var lowerQuery = query.trim().toLowerCase();
			if (lowerQuery[lowerQuery.length-1] == '?'){
			    lowerQuery = lowerQuery.substring(0,lowerQuery.length-1);
			}
			var idx = lowerItem.indexOf(lowerQuery);
			var tmp = "";
			var lastIdx = 0;
			//can change this later to a more efficient version with split()
			while (idx > -1){
			    tmp += item.name.substring(lastIdx,idx);
			    tmp += "#";
			    lastIdx = idx;
			    idx += lowerQuery.length;
			    tmp += item.name.substring(lastIdx,idx);
			    tmp += "#";
			    lastIdx = idx;
			    idx = lowerItem.indexOf(lowerQuery,idx);
			}
			tmp += item.name.substring(lastIdx);

			tmp += "==";
			tmp += item.curie;
//			tmp += " ("+item.curie+")";


			results.push(tmp);
		    });
		    if(callback){
			callback(results);
		    }
		}
	    });
	}
    });
}
//});
