/*
  Javascript widget(s) modified from originals, courtesy of EBI Omics discovery index at http://www.ebi.ac.uk/Tools/omicsdi/#/


*/

function draw_word_cloud( json_url, div_name, svg_width, svg_height ) {

//alert( json_url );
//alert( div_name );

  var req=new XMLHttpRequest(); // a new request

  req.open("GET",json_url,false);
  req.send(null);
  var data = JSON.parse( req.responseText );

  var title = data['title'];

  var terms = {};

  var fieldList = [];

  var fill = d3.scale.category20b();

  var body = d3.select("#" + div_name );

  if ( typeof(svg_width) === 'undefined' ) {
    var div_width_px = body.style("width") || '400px';
    svg_width = div_width_px.substr(0, div_width_px.length - 2);
    svg_width = svg_width * 0.9;
  } else if ( svg_width == 0 ) {
    svg_width = 400;
  }

  if ( typeof(svg_height) === 'undefined' ) {
    var div_height_px = body.style("height") || '400px';
    svg_height = div_width_px.substr(0, div_height_px.length - 2);
    svg_height = svg_height * 0.9;
  } else if ( svg_height == 0 ) {
    svg_height = 400;
  }

  svg_width_px = svg_width + "px";
  svg_height_px = svg_height + "px";

//  alert( "Height x width is " + svg_height_px + " x " + svg_width_px );

  body.selectAll("svg").remove();
  var svg = body.append("svg")
      .attr("width", svg_width_px)
      .attr("height", svg_height_px)
      .attr("class", "wordcloud");

  body.selectAll("div").remove();
/*  var wcspacediv = body.append('div');
  wcspacediv
    .attr( "float", "bottom" )
    .attr("height", "100px")
    .attr("id", "wcspacediv")
    .attr("opacity", "0.1");

 document.getElementById( "wcspacediv" ).innerHTML = "<br><br>";
*/
 var wordcloud_tooltip = body.append("div")
 wordcloud_tooltip
    .attr( "float", "bottom" )
    .attr( "align", "center" )
    .attr( "id", "wordcloud_tooltip" )
    .attr("class", "tooltip")
    .style("opacity", 0);

 document.getElementById( "wordcloud_tooltip" ).innerHTML = "<br>";


  var formdiv = body.append('div');
  formdiv
      .attr("class", "center")
//      .attr("float", "bottom")
      .attr("position", "absolute")
      .attr("border", "dashed")
      .attr("bottom", "0")
//      .attr("width", div_width_px)
  ;

//  var radio_form = formdiv.append('form');
  var radio_form = formdiv.append('form');

  var form_name =  div_name + "_form";

  radio_form
      .attr("id", form_name)
//      .append('input')
//      .attr('type', 'radio')
//      .attr('name', form_name)
//      .attr('value', 'description')
//      .attr('id', 'description')
//      .text('description');

  var series = data['series'];
  var initial_series;

  for ( var idx in series ) {
    var dataset = series[idx];
    if ( typeof(initial_series) === 'undefined' ) {
      initial_series = dataset['name'];
    }

    terms[dataset['name']] = dataset['data'];
    fieldList[idx] = dataset['name'];

    radio_form
      .append('label')
      .text(dataset['name'])
      .attr('for', dataset['name'])
    radio_form
      .append('input')
      .attr('type', 'radio')
      .attr('name', form_name + '_radio' )
      .attr('value', dataset['name'])
      .attr('id', form_name)
      .text(dataset['name']);
  }

  d3.select("#" + form_name).select('input[value="' + initial_series + '"]').property('checked', true);

  d3.select("#" + form_name).selectAll('input').on('change', change);


  var browsertype = '';
  if( navigator.userAgent.toLowerCase().indexOf('firefox') > -1 ){
    browsertype = 'firefox';
  }
  if( navigator.userAgent.toLowerCase().indexOf('chrome') > -1 ){
    browsertype = 'chrome';
  }

  var field = "";
  change();

  function change() {

      field = this.value || initial_series;
      var hotwordss = terms[field];
      var maxfrequent = getmax(hotwordss);
      svg.selectAll(".cloud").remove();
//      d3.layout.cloud().size([425, 320])
      d3.layout.cloud().size([svg_width, svg_height])
          .words(hotwordss)
          .padding(1)
          .rotate(0)
          .font("Impact")
          .text(function (d) {
              return d.label;
          }) // THE SOLUTION
          .fontSize(function (d) {
            var size = d.frequent/maxfrequent * 24;
            if ( size < 14 ) {
              return 14;
            } else {
              return size;
            }
          })
          .on("end", draw)
          .start();
  }


  function draw(words) {
      var maxfrequent = getmax(words);


      var y_trans = 130;
      if( navigator.userAgent.toLowerCase().indexOf('chrome') > -1 ){
//        y_trans += 10;
      }
      svg.append("g")
          .attr("class", "cloud")
          .attr("transform", "translate(110," + y_trans + ")")
          .selectAll("text")
          .data(words)
          .enter().append("text")
          .style("font-size", function (d) {
            var size = d.frequent/maxfrequent * 24;
            if ( size < 14 ) {
              size = 14;
            }
            var pxsize = size + "px";
            return pxsize;
          } )
          .style("font-family", "Impact")
          .style("fill", function (d, i) {
              return fill(i);
          })
          .attr("text-anchor", "middle")
          .attr("transform", function (d) {
              return "translate(" + [d.x, d.y] + ")rotate(" + d.rotate + ")";
          })
          .text(function (d) {
              return d.label;
          })
          .attr("class", "hotword")
          .on("click", function (d, i) {

              wordcloud_tooltip.transition()
                  .duration(500)
                  .style("opacity", 0);

              var advmode = 'Title';
              if ( field == 'Keywords' ) {
                advmode = 'Keywords'
              }
              $("#field").val('');
              $("#sel_col1").val(advmode);
              $("#sel1").val(d.label);
//             FIXME
//               plot_onclick( d.label );
//               $("#field").val(d.label);
//               $("#sel1").val('');
               myQueryEvent();
          })

          .on("mousemove", function (d, i) {
              var mouse_coords = d3.mouse(
                  wordcloud_tooltip.node().parentElement);

              wordcloud_tooltip.transition()
                  .duration(200)
                  .style("opacity", .9);

             // alert( "freq is " + d.frequent );
             // alert( "freq sqrd " + d.frequent*d.frequent );
             // alert( "freq rounded " + Math.round(d.frequent*d.frequent) );

              var sqred = Math.round(d.frequent* d.frequent);

              wordcloud_tooltip.html("<strong>" + sqred + "</strong> datasets"  )
                  .style("left", (mouse_coords[0] + 40) + "px")
                  .style("top", (mouse_coords[1]- 40) + "px")
                  .style("height", "20px")
                  .style("width", sqred.toString().length * 10 + 20 + "px");
          })
          .on("mouseout", function (d, i) {
              wordcloud_tooltip.transition()
                  .duration(500)
                  .style("opacity", 0);
          })
          ;
  }


  function getmax(arr) {
      if (arr == null) return null;
      var max = 0;
      for (var i = 0; i < arr.length; i++)
          if (arr[i].frequent > max) {
              max = arr[i].frequent;
          }
      return max;
  }

  function outputerrorinfo() {
      d3.select("#hotwords").append("p").attr("class", "error-info")
          .html("Sorry, accessing the word cloud web service has temporarily failed.");
  }


}
