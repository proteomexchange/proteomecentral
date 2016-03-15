$(document).ready(function(){

  $("div.pager select").val("Default Value");

	$('#searchbtn').click(function() {
     myQueryEvent() 
  });
	//$('#field').keypress(myQueryEvent);
	$("#basic_search").click(function() {
    clearTextBox(); 
    myQueryEvent()
  });
	$("#advanced_search").click(function() {
     clearTextBox();
     myQueryEvent()
  });

	$('#advsearchbtn').click(function() {
     myQueryEvent()
  });


	// if text input field value is not empty show the "X" button
	if ($.trim($("#field").val()) != "") {
	 $("#x").fadeIn();
	}
	/*$("#field").keyup(function() {
      myQueryEvent();
	});*/

  $("#field").keyup( function(e) {
			$("#x").fadeIn();
			if ($.trim($("#field").val()) == "") {
					$("#x").fadeOut();
			}
      if (e.which == 13) {
        myQueryEvent();
      };
   });

	// on click of "X", delete input field value and hide "X"
	$("#x").click(function() {
			$("#field").val("");
			$(this).hide();
       myQueryEvent();
	});
	$("#clear").click(function(){
    clearTextBox();
    myQueryEvent();
	});


})

function clearTextBox(){
	var list = document.getElementsByTagName("input");
	for (var i=0; i<list.length; i++){
		 if(list[i].type == 'text'){
				list[i].value = '';
		 }
	}
}

function myQueryEvent(){
	var url = get_cgi_url();
  var urlparams = get_url_parameter();
  //params.start = 0;
  //params.limit = itemsPerPage;
	var filterparams = get_filterstr(); 
	//params.action = filterparams[0];
	//params.filterstr = filterparams[1];
  if ( urlparams != ''){
    urlparams = urlparams + '&action=' + filterparams[0] + '&filterstr=' + filterparams[1]  ;  
  }else{
    urlparams = 'action=' + filterparams[0] + '&filterstr=' + filterparams[1] 
  }

  url = url+ '/GetDataset';
	$.ajax({
			url: url, 
			type: "GET",
		  data: urlparams, 
      dataType: 'html',
      error: function(XMLHttpRequest, textStatus, errorThrown) { 
      }, // error 
      success:function(msg) {
        $("#result").html(msg);
				$(function() {
					$("#datatable")
						.tablesorter({widthFixed: true, widgets: ['zebra']})
						.tablesorterPager({container: $("#pager")});
				});
      }
	});
} 

function get_filterstr(){
  var filterstr = '' ; 
  var action = 'search';
  for (var i = 1; i<= 4; i++){
    var sel_id = 'sel_col' + i;
    var cond_id = 'sel_con' + i;
    var id = 'sel' + i; 
		if($("#"+id).val() != ''){
			action = "advsearch";
			filterstr += "[" + $("select#"+sel_id).val() +  "|" + $("select#"+cond_id).val()
									 + "|" +  $("#" + id).val() + "]";
		}
    if ( $("#"+id).val() != '' && $("select#"+sel_id).val().match(/date/i)){
      var result = checkDateFormat($("#"+id).val());
      if (result == 1){
         document.getElementById("error").innerHTML = "Please use format YYYY-MM-DD/YYYY-MM/YYYY for date";
         return ['', ''];
      }else{
         document.getElementById("error").innerHTML = '';
      }
    }

  }
  if ( filterstr == ''){
    filterstr = $('#field').val();
  }
  return [action , filterstr];
}


function checkDateFormat(val){
  val = val.replace(/\s/g, "");
	if (! (val.match(/^\d{4}-\d{2}-\d{2}$/) || 
         val.match(/^\d{4}-\d{2}$/) || 
         val.match(/^\d{4}$/))){
		return 1;
	}else{
    return 0;
  }
}

function get_url_parameter (){
  // separating the GET parameters from the current URL
  var getParams = document.URL.split("?");
  /*var params = [], hash;
  //var params = Ext.urlDecode(getParams[getParams.length - 1]);
	for(var i = 1; i < getParams.length; i++)
	{
		hash = getParams[i].split('=');
		//params.push(hash[0]);
		//params[hash[0]] = hash[1];
    params += hash[0] + ": " + hash[1] + ",";
	}*/
  if (getParams.length > 1){
    return getParams[1];
  }else{
    return '';
  }
}
function get_cgi_url(){
  var url = document.URL.replace(/cgi.*/, 'cgi');
  return url;
}

function ucfirst (str) {
	// Makes a string's first character uppercase
	var f = str.charAt(0).toUpperCase();
	return f + str.substr(1);
}

