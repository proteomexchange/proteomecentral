Ext.define('Ext.ux.AsyncRowExpander', {
    extend: 'Ext.ux.RowExpander',
    alias: 'plugin.asyncrowexpander',
    /**
* @cfg {String} url
* Default Template to use if not found in cache
*/
    rowBodyTpl: "<p>Default row body</p>",

    /**
* @cfg {Object} url
* Hash of rowBodyTpls for each record.internalId
*/
    rowBodyCache: null,

    /**
* @cfg {Boolean} cacheAjaxTpls
* true to only make an ajax request the first time the row is expanded
* (defaults to false)
*/
    cacheAjaxTpls: false,

    /**
* @cfg {String} url
* The url where the expander will get the row templates
*/
    url: null,

    /**
* @cfg {Object} params
* The params passed to the ajax request. These are merged with
* record.raw so that the server can serve different templates based on the
* record data.
*/
    params: {},

    /**
* @event expandbody
* <b<Fired through the grid's View</b>
* @param {HtmlElement} rowNode The &lt;tr> element which owns the expanded row.
* @param {Ext.data.Model} record The record providing the data.
* @param {HtmlElement} expandRow The &lt;tr> element containing the expanded data.
*/
    /**
* @event collapsebody
* <b<Fired through the grid's View.</b>
* @param {HtmlElement} rowNode The &lt;tr> element which owns the expanded row.
* @param {Ext.data.Model} record The record providing the data.
* @param {HtmlElement} expandRow The &lt;tr> element containing the expanded data.
*/

    constructor: function(config) {
        var me = this;

        Ext.apply(me, config);

        // skip over RowExpander and call AbstractPlugin
        me.superclass.superclass.constructor.call(me, [config]);

        var grid = me.getCmp();

        me.recordsExpanded = {};
        me.rowBodyCache = {};

        // <debug>
        if (!me.url) {
            Ext.Error.raise("The 'url' config is required and is not defined.");
        }
        // </debug>
        me.rowBodyTpl = Ext.create('Ext.XTemplate', me.rowBodyTpl);
            var features = [{
                ftype: 'rowbody',
                columnId: me.getHeaderId(),
                recordsExpanded: me.recordsExpanded,
                rowBodyHiddenCls: me.rowBodyHiddenCls,
                rowCollapsedCls: me.rowCollapsedCls,
                getAdditionalData: me.getRowBodyFeatureData,
                getRowBodyContents: function(internalId, data) {
                    //var tpl = (me.rowBodyCache[internalId]) ? me.rowBodyCache[internalId] : me.rowBodyTpl;
                    //return tpl.applyTemplate(data);
                    return me.rowBodyCache[internalId];
                }
            },{
                ftype: 'rowwrap'
            }];

        if (grid.features) {
            grid.features = features.concat(grid.features);
        } else {
            grid.features = features;
        }
    },

    getRowBodyFeatureData: function(data, idx, record, orig) {
        var o = Ext.grid.feature.RowBody.prototype.getAdditionalData.apply(this, arguments),
            id = this.columnId;
        o.rowBodyColspan = o.rowBodyColspan - 1;
        o.rowBody = this.getRowBodyContents(record.internalId, data);
        o.rowCls = this.recordsExpanded[record.internalId] ? '' : this.rowCollapsedCls;
        o.rowBodyCls = this.recordsExpanded[record.internalId] ? '' : this.rowBodyHiddenCls;
        o[id + '-tdAttr'] = ' valign="top" rowspan="2" ';
        if (orig[id+'-tdAttr']) {
            o[id+'-tdAttr'] += orig[id+'-tdAttr'];
        }
        return o;
    },

    /**
* Expands or collapses the row. Executes an ajax request to retrieve
* the template from the configured url, caching the result.
*
* @todo this should be refactored, along with the collapseRow and expandRow methods.
*
* @param rowIdx
*/
    toggleRow: function(rowIdx) {
        var me = this,
            rowNode = me.view.getNode(rowIdx),
            row = Ext.get(rowNode),
            nextBd = Ext.get(row).down(this.rowBodyTrSelector),
            record = me.view.getRecord(rowNode),
            mask = null;

        me.params.ID= record.get('id');
        if (row.hasCls(me.rowCollapsedCls)) {

            if( (me.rowBodyCache[record.internalId]) && me.cacheAjaxTpls ) {
                me.expandRow(row, nextBd, record, rowNode);
                me.updateLayout();
            } else {

                mask = new Ext.LoadMask(row, {msg: "Loading..."});
                mask.show();

                Ext.Ajax.request({
                    url: me.url,
                    params: Ext.apply(me.params, record.raw),
                    success: function(response) {
                        mask.hide();
                        var obj = Ext.decode( response.responseText ); 
                        me.rowBodyCache[record.internalId] = make_meta_data( obj.QueryResponse.dataset);//Ext.create('Ext.XTemplate', response.responseText);
                        me.expandRow(row, nextBd, record, rowNode);
                        me.view.refreshNode(me.view.getStore().indexOf(record));
                        me.updateLayout();
                    },
                    failure: function(response) {
                        mask.hide();
                    }
                });
            }

        } else {
            me.collapseRow(row, nextBd, record, rowNode);
            me.updateLayout();
        }

    },

    expandRow: function(row, nextBd, record, rowNode) {
        var me = this;
        row.removeCls(me.rowCollapsedCls);
        nextBd.removeCls(me.rowBodyHiddenCls);
        me.recordsExpanded[record.internalId] = true;
        me.view.fireEvent('expandbody', rowNode, record, nextBd.dom);
    },

    collapseRow: function(row, nextBd, record, rowNode) {
        var me = this;
        row.addCls(me.rowCollapsedCls);
        nextBd.addCls(me.rowBodyHiddenCls);
        me.recordsExpanded[record.internalId] = false;
        me.view.fireEvent('collapsebody', rowNode, record, nextBd.dom);
    },

    updateLayout: function() {
        var grid = this.getCmp();

        // If Grid is auto-heighting itself, then perform a component layhout to accommodate the new height
        if (!grid.isFixedHeight()) {
            grid.doComponentLayout();
        }
        this.view.up('gridpanel').invalidateScroller();
    }
});

function make_meta_data (data){
    var details = '<div id="subMeta"><div id="metadata">';
    var record = data;  
    var metadata = new Array("title",
                               "announceDate",
                               "announcementXML",
                               "PXPartner",
                               "DigitalObjectIdentifier",
                               "ReviewLevel",
                               "datasetOrigin",
                               "primarySubmitter",
                               "description",
                               "instrument",
                               "speciesList",
                               "ModificationsList");
    var url = get_cgi_url();
    for(j = 0; j<record.length; j++){
      var data = '';
      data = record[j];
      for (var i=0; i<metadata.length; i++){
        if (metadata[i].match(/announcementXML/i)){
          details += checkIfExists(data[metadata[i]])? "<h3>" +
          ucfirst(metadata[i]) + "</h3><div id='box'><a href=\""+url+"/GetDataset?ID=" + 
          data['id'] +  '&outputMode=XML' + data['test'] + '\">' + 
          data[metadata[i]]+ "</a></div>": '';
        }else{
          details += checkIfExists(data[metadata[i]])? "<h3>" + 
          ucfirst(metadata[i]) + "</h3><div id='box'>"+data[metadata[i]]+"</div>" : '';
        }
     }
   }
   details += '</div></div>';
   return details;
}

function checkIfExists ( v ){
  if( v !== null && v !== undefined && v != '') { return true;}
   return false;
}
function ucfirst (str) {
  // Makes a string's first character uppercase
  var f = str.charAt(0).toUpperCase();
  return f + str.substr(1);
}


function get_cgi_url(){
  var url = document.URL.replace(/cgi.*/, 'cgi');
  return url;

}
