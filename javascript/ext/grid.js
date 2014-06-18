Ext.require([
    'Ext.grid.*',
    'Ext.data.*',
    'Ext.util.*',
    'Ext.state.*'
]);

var itemsPerPage = 10;
var fields = [
      { name: 'id'},
      { name: 'Title' },
      { name: 'AnnouncementDate' },
      { name: 'PSubmitter' },
      { name: 'LabHead' },
      { name: 'Publication' },
      { name: 'Repository'},
      { name: 'Instrument' },
      { name: 'Species' },
      { name: 'IdentifierDate'},
      { name: 'RevisionDate'},
      { name: 'Status' },
      { name: 'modificationList'},
   ];
var columns = new Array ([
          {
            header: 'Dataset ID', 
            dataIndex: 'id',
            tooptip: 'id',
            renderer: id_renderer, 
          },
          {
            header: 'Title', 
            dataIndex: 'Title',
            flex: 1, 
          },
          {
            header: 'Repository', 
            dataIndex: 'Repository', 
          },
          {
            header: 'Species', 
            dataIndex: 'Species', 
          },
          {
            header: 'Instrument',
            dataIndex: 'Instrument',
          },
          {
            header: 'Publication', 
            dataIndex: 'Publication', 
          },
          {
            header: 'Primary Submitter', 
            dataIndex: 'PSubmitter',
          },
          {
            header: 'Lab Head',
            dataIndex: 'LabHead',
          },
          {
            header: 'Announcement Date', 
            dataIndex: 'AnnouncementDate' ,
            width: 110
          }
]);
var params = get_url_parameter();
if ( params.detailLevel != null && params.detailLevel.match(/extended/i)){
  columns.push([
				{
					header: 'Status', 
					dataIndex: 'Status', 
				},
				{
					header: 'Revision Date',
					dataIndex: 'RevisionDate',
				},
				{
					header: 'Identifier Date',
					dataIndex: 'IdentifierDate' ,
				}
			]);
}


Ext.define('Dataset', {
    extend: 'Ext.data.Model',
    fields: fields,
});

var url = get_cgi_url(); 
var store = Ext.create('Ext.data.Store', {
	 model: 'Dataset',
   pageSize: itemsPerPage,
   isSortable: true,
   remoteSort: true,
	 proxy: {
			type: 'ajax',
			api: {
					read: url+ '/Query.cgi',
			},
			reader: {
					type: 'json',
					successProperty: 'success',
					root: 'QueryResponse.dataset',
					totalProperty: 'QueryResponse.counts.dataset',
					messageProperty: 'message'
			},
			writer: {
					type: 'json',
					writeAllFields: false,
					root: 'QueryResponse.dataset'
			},
			listeners: {
					exception: function(proxy, response, operation){
							Ext.MessageBox.show({
									title: 'REMOTE EXCEPTION',
									msg: operation.getError(),
									icon: Ext.MessageBox.ERROR,
									buttons: Ext.Msg.OK
							});
					}
					 
			}
		},
	  firstLoad: true,
	  reader: new Ext.data.JsonReader({
				  id: "id" ,
			  root: 'QueryResponse.dataset',
			fields: fields
		}),
		listeners: {
				'beforeload': function(store, options) {
						var params = get_url_parameter();
						store.proxy.extraParams.detailLevel=params.detailLevel;
            var filterparams = get_filterstr();
            store.proxy.extraParams.filterstr= filterparams[1];
            store.proxy.extraParams.action = filterparams[0];
				},
				write: function(store, operation){
						var record = operation.records[0],
								name = Ext.String.capitalize(operation.action),
								verb;

						if (name == 'Destroy') {
								verb = 'Destroyed';
						} else {
								verb = name + 'd';
						}
						Ext.example.msg(name, Ext.String.format("{0} user: {1}", verb, record.getId()));

				}
		}
});



var grid; 
Ext.onReady(function(){
   Ext.QuickTips.init();
    //var rowEditing = Ext.create('Ext.grid.plugin.RowEditing');
    grid = new Ext.grid.Panel({
        renderTo:  document.getElementById('center'),
        fitToFrame: true,
        height: 378,
        width: '98%',
        viewConfig:{
					forceFit: true,
					scrollOffset: 15
				},
        remoteSort: true,
        autoWidth: true,
        plugins: [{  
                     ptype: 'asyncrowexpander',
										 url: 'Query.cgi',
                     cacheAjaxTpls: true,
        }],
        store: store,
        columns: columns,
        bbar: Ext.create('Ext.PagingToolbar', {
                  store: store,
                 params: params,
            displayInfo: true,
                loading: false,
             displayMsg: 'Displaying topics {0} - {1} of {2}',
               emptyMsg: "No topics to display",
              listeners: {
                afterrender: function(){
                   // disable refresh button
									 var a = Ext.query("button[data-qtip=Refresh]"); 
										for(var x=0;x < a.length;x++)
										{
												a[x].style.display="none";
										}
                }
              }
        }),
				selModel:null ,
				listeners:{
					//render: common.highlightLink,
					cellclick:cellClickHandler,
				},
				loadMask: { msg: 'Loading...' },
				collapsible: false,
				monitorResize: true,
				iconCls: 'icon-grid',
				border: true,
				autoExpandColumn: 3,
        viewConfig: {
            autoScroll: true,
            stripeRows: true
        }

    });

		Ext.EventManager.onWindowResize(function(w, h){
				grid.doComponentLayout();
		});
    var params = get_url_parameter();
    params.start = 0;
    params.limit = itemsPerPage;
    store.load({
      params: params,
    });

   // if text input field value is not empty show the "X" button
   if ($.trim($("#field").val()) != "") {
     $("#x").fadeIn();
   } 
   $("#field").keyup(function() {
        $("#x").fadeIn();
        if ($.trim($("#field").val()) == "") {
            $("#x").fadeOut();
        }
    });
    // on click of "X", delete input field value and hide "X"
    $("#x").click(function() {
        $("#field").val("");
        $(this).hide();
    });
    $("#clear").click(function clearTextBox(){
			var list = document.getElementsByTagName("input");
			for (var i=0; i<list.length; i++){
				 if(list[i].type == 'text'){
						list[i].value = '';
				 }
			}
      document.getElementById("error").innerHTML = '';
		});

    var myQueryEvent = function(e){
      /*alert (e.keycode + " " + e.button);
      if ( (e.keycode!= 13|| e.which !=13) && (e.button != 0)){
        return;
      } */
      var params = get_url_parameter();
      params.start = 0;
      params.limit = itemsPerPage;
     
      var filterparams = get_filterstr(); 
      params.action = filterparams[0];
      params.filterstr = filterparams[1]; 
      store.load({
        params: params,
      });
      store.loadPage(1); 

   };

   $('#searchbtn').click(myQueryEvent);
    //$('#field').keypress(myQueryEvent);
  
 
   $("#x").click(myQueryEvent);
   $("#clear").click(myQueryEvent);
   $("#basic_search").click(myQueryEvent);
   $("#advanced_search").click(myQueryEvent);
   $('#advsearchbtn').click(myQueryEvent); 

   $('#field').on('keyup', function(e) {
      if (e.which == 13) {
				var params = get_url_parameter();
				params.start = 0;
				params.limit = itemsPerPage;
				params.filterstr =  $('#field').val();
				params.action = 'search';
				store.load({
					params: params,
				});
        store.loadPage(1);
     }
   });

  /*  var border = Ext.getCmp( 'layout' );
	if(border){
		border.doLayout();
		border.syncSize();
	}else{
		grid.setWidth(grid.container.parent().getWidth());
	}*/

});
function get_filterstr(){
  var filterstr = '' ; 
  var action = 'search';
  for (var i = 1; i<= 4; i++){
    var sel_id = 'sel_col' + i;
    var cond_id = 'sel_con' + i;
    var id = 'sel' + i; 
		if($("#"+id).val() != ''){
			action = "advsearch";
			filterstr += "[" + $("select#"+sel_id).val() +  "+" + $("select#"+cond_id).val()
									 + "+" +  $("#" + id).val() + "]";
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
  // transforming the GET parameters into a dictionnary
  var params = Ext.urlDecode(getParams[getParams.length - 1]);
  return params;
}
function get_cgi_url(){
  var url = document.URL.replace(/cgi.*/, 'cgi');
  return url;
  
}

Ext.EventManager.onWindowResize( function(){
	var border = Ext.getCmp( 'layout' );
	if(border){ grid.setWidth(grid.container.parent().getWidth());}
	grid.getView().refresh();
});


//expand row template 
/*function meta_detail_tpl (){
	var details = '<div id="subMeta"><div id="metadata">'; 
  var i = 11;
  for (i; i < fields[0].length; i++ ){
     if (details != ''){
        details += '<h3 style="border:none;">' + columns[0][i]["name"] + "</h3><div id='box'>{" + columns[0][i]["name"] +'}</div>';
     }else{
        details = '<h3 style="border:none;">' +  columns[0][i]["name"] + "</h3><div id='box'>{" + columns[0][i]["name"] +'}</div>';
    }
  }
  details += '</div></div>'
  return details;
}
*/


function cellClickHandler(grid, rowIndex, columnIndex, e){
	//e.stopEvent();
  if ( rowIndex == null){
    return;
  }
  var par = rowIndex.parentNode;
  if ( par != null ){
		rowIndex = par.rowIndex;
		var record = grid.getStore().getAt(rowIndex);  // Get the Record
		var fieldName = grid.getHeaderAtIndex(columnIndex).dataIndex;
		if(fieldName && columnIndex != 0 ){
			//dataset_expander.toggleRow();
		}
  }
}



function id_renderer (value,  metadata, record, rowIndex, columnIndex, store){
  /*var tip = value;
  if( tip){
    metadata.tdAttr = ' data-qtip="' + tip + '"';
 }*/
  var test='';
  if (params.test ){
    test = '&test=' + params.test ;
  }

  var html = '<a href="' + url + '/GetDataset?ID=' + value + test + '">' + value +'</a>';
  return html;
}

function calcGridHeight(){
	var p = Ext.getCmp('center');
 	if(p){
		return p.getSize().height - 0;
	}else{
		return 675 - 25;
	}
}

function ucfirst (str) {
	// Makes a string's first character uppercase
	var f = str.charAt(0).toUpperCase();
	return f + str.substr(1);
}

 
