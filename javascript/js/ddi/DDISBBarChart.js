/*
  Javascript widget(s) modified from originals, courtesy of EBI Omics discovery index at http://www.ebi.ac.uk/Tools/omicsdi/#/


*/

function draw_bar_chart( json_url, div_name, svg_width, svg_height ) {

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












var barcharts_years_omics_types = function () {
    queue()
        .defer(d3.json, web_service_url + 'statistics/omicsByYear') // geojson points
        .await(draw_chart_omicstype_annual); // function that uses files

    function draw_chart_omicstype_annual(error, annual_data) {
        if (error) {
            retry_limit_time--;
            if (retry_limit_time <= 0) {
                output_error_info('barchart_omicstype_annual');
                return;
            }

            output_getting_info('barchart_omicstype_annual');
            barcharts_years_omics_types();
        }
        else {
            remove_getting_info('barchart_omicstype_annual');
            var body = d3.select('#barchart_omicstype_annual');
        var div_width_px = body.style("width");
        var div_width = parseInt(div_width_px.substr(0, div_width_px.length - 2));
            //var div_width = 420;
            var margin = {top: 20, right: 20, bottom: 20, left: 60},
                width = div_width - margin.left - margin.right,
                height = 290 - margin.top - margin.bottom;
            var x0 = d3.scale.ordinal()
                .rangeRoundBands([0, width], .1);

            var x1 = d3.scale.ordinal();

            var y = d3.scale.linear()
                .range([height, 0]);

            var color = d3.scale.category10();

            var xAxis = d3.svg.axis()
                .scale(x0)
                .orient("bottom");

            var yAxis = d3.svg.axis()
                .scale(y)
                .orient("left")
                .tickFormat(d3.format(".2s"));

            d3.select("#barchart_omicstype_annual").selectAll("svg").remove();
            var svg = d3.select("#barchart_omicstype_annual").append("svg")
                .attr("width", width + margin.left + margin.right)
                .attr("height", height + margin.top + margin.bottom)
                .append("g")
                .attr("transform", "translate(" + margin.left + "," + margin.top + ")");


            var omics_types = d3.keys(annual_data[0]).filter(function (key) {
                return key !== "year";
            });


            data = annual_data;
            data.forEach(function (d) {
                d.omics = omics_types.map(function (name) {
                    if (name !== "year") return {name: name, value: +d[name], year: d["year"]};
                });
            });

            x0.domain(data.map(function (d) {
                return d.year;
            }));

            x1.domain(omics_types).rangeRoundBands([0, x0.rangeBand()]);
            y.domain([0, d3.max(data, function (d) {
                return d3.max(d.omics, function (d) {
                    return d.value;
                });
            })]);

            var tooltip = d3.select('body').append("div")
                .attr("class", "tooltip")
                .style("opacity", 0);

            svg.append("g")
                .attr("class", "x axis")
                .attr("transform", "translate(0," + height + ")")
                .call(xAxis);

            svg.append("g")
                .attr("class", "y axis")
                .call(yAxis)
                .append("text")
                .attr("transform", "rotate(-90)")
                .attr("y", 6)
                .attr("dy", "-3.9em")
                .attr("dx", "-4.9em")
                .style("text-anchor", "end")
                .text("Datasets No.");

            var year = svg.selectAll(".year")
                .data(data)
                .enter().append("g")
                .attr("class", "g")
                .attr("transform", function (d) {
                    return "translate(" + x0(d.year) + ",0)";
                });

            year.selectAll("rect")
                .data(function (d) {
                    return d.omics;
                })
                .enter().append("rect")
                .attr("width", x1.rangeBand() * 0.8)
                .attr("x", function (d) {
                    return x1(d.name);
                })
                .attr("y", function (d) {
                    return y(d.value);
                })
                .attr("height", function (d) {
                    return height - y(d.value);
                })
                .style("fill", function (d) {
                    return color(d.name);
                })
                .attr("class", "bar")
                .on("click", function (d) {
                    tooltip.transition()
                        .duration(500)
                        .style("opacity", 0);
                    location.href = "#/search?q=*:* AND omics_type:\"" + d.name + "\" AND publication_date:\"" + d.year + "\"";
                })
                .on("mouseover", function (d) {
                    var current_g_x = parseInt(d3.transform(d3.select(this.parentNode).attr("transform")).translate[0]);
                    var current_rect_x = parseInt(d3.select(this).attr("x"));
//                    console.log(parseInt(d3.select(this).attr("y")));
                    tooltip.transition()
                        .duration(200)
                        .style("opacity", .9);
                    tooltip.html( d.value + " datasets" )
                        .style("left", (1095 + current_g_x + current_rect_x) + "px")
                        .style("top", (parseInt(d3.select(this).attr("y"))+635) + "px")
                        .style("height",  "20px")
                        .style("width", d.value.toString().length * 5 + 80 + "px");
                })
                .on("mouseout", function (d) {
                    tooltip.transition()
                        .duration(500)
                        .style("opacity", 0);
                });
            ;


            d3.select('.x.axis')
                .selectAll('.tick')
                .attr("class", "hotword")
                .on('click', clickMe);

            var legend = svg.selectAll(".legend")
                .data(omics_types.slice().reverse())
                .enter().append("g")
                .attr("class", "legend")
                .attr("transform", function (d, i) {
                    return "translate(0," + i * 20 + ")";
                })
                .on("click", function (d) {
                    location.href = "#/search?q=*:* AND omics_type:\"" + d + "\"";
                });

            legend.append("rect")
                .attr("x", width - 18)
                .attr("width", 18)
                .attr("height", 18)
                .style("fill", color);

            legend.append("text")
                .attr("x", width - 24)
                .attr("y", 9)
                .attr("dy", ".35em")
                .style("text-anchor", "end")
                .text(function (d) {
                    return d;
                });
        }

    }

    function clickMe(d) {
        location.href = "#/search?q=*:* AND publication_date:\"" + d + "\"";
    };


}































//  alert( "Height x width is " + svg_height_px + " x " + svg_width_px );

  body.selectAll("svg").remove();
  var svg = body.append("svg")
      .attr("width", svg_width_px)
      .attr("height", svg_height_px)
      .attr("class", "wordcloud");

  body.selectAll("div").remove();
  var spacediv = body.append('div');
  spacediv 
    .attr( "float", "bottom" )
    .attr("height", "100px")
    .attr("id", "spacediv");

 document.getElementById( "spacediv" ).innerHTML = "<br><br>";

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
      .attr("float", "bottom")
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

  d3.select("#" + form_name).select('input[value=' + initial_series + ']').property('checked', true);

  d3.select("#" + form_name).selectAll('input').on('change', change);



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
            return d.frequent / maxfrequent * 50;
          })
          .on("end", draw)
          .start();
  }


  function draw(words) {
      var maxfrequent = getmax(words);
      svg.append("g")
          .attr("class", "cloud")
          .attr("transform", "translate(200,180)")
          .selectAll("text")
          .data(words)
          .enter().append("text")
          .style("font-size", function (d) {
              if(field=="PeptideAtlas")return d.frequent / maxfrequent * 20 +"px";
              return d.frequent / maxfrequent * 40 + "px";
          })
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
              // alert("you have clicked"+d.label);

              wordcloud_tooltip.transition()
                  .duration(500)
                  .style("opacity", 0);

              //location.href = "#/search?q=" + "\""+ d.label + "\"";
          })

          .on("mousemove", function (d, i) {
              var mouse_coords = d3.mouse(
                  wordcloud_tooltip.node().parentElement);

              wordcloud_tooltip.transition()
                  .duration(200)
                  .style("opacity", .9);

              d.frequent = Math.round( d.frequent * d.frequent );

              wordcloud_tooltip.html("<strong>" + d.frequent + "</strong> datasets"  )
                  .style("left", (mouse_coords[0] + screen.width/11) + "px")
                  .style("top", (mouse_coords[1]-30) + "px")
                  .style("height", "20px")
                  .style("width", d.frequent.toString().length * 10 + 70 + "px");
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
          .html("Sorry, accessing to the word cloud web service was temporally failed.");
  }


}
