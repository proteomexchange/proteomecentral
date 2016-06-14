
var pie_charts_repos_omics = function () {


    // Get repository JSON
//    var url='http://wwwdev.ebi.ac.uk/Tools/ddi/ws/statistics/';
    var url='http://proteomecentral.proteomexchange.org/devDC/cgi/GetJSON';
    var req=new XMLHttpRequest(); // a new request

    var domain_url = url + '?mode=species';
//    var domain_url = url + '?mode=domains';
    req.open("GET",domain_url,false);
    req.send(null);
    var domains = JSON.parse( req.responseText );

    var omics_url = url + '?mode=instruments'  // geojson points
//    var omics_url = url + '?mode=omics'  // geojson points
    req.open("GET",omics_url,false);
    req.send(null);
    var omics = JSON.parse( req.responseText );

    draw_chart_repos_omics( false, domains, omics );

    function draw_chart_repos_omics(error, domains, omicstype) {



        if (error) {
            retry_limit_time--;
            if (retry_limit_time <= 0) {
                output_error_info('chart_repos_omics');
                return;
            }
            output_getting_info('chart_repos_omics');
            pie_charts_repos_omics();
        }
        else {
            remove_getting_info('chart_repos_omics');
            var repos = transformdomains(domains);
            omicstype.shift();
            var unavailableomics = omicstype.pop();

            var total_omics = gettotal(omicstype);
            var total_repos = gettotal(repos);

            omicstype = omicstype.sort(function (a, b) {
                return parseInt(a.value) - parseInt(b.value);
            });
            repos = repos.sort(function (a, b) {
                return parseInt(a.value) - parseInt(b.value);
            });


            /*
             * prepare the treemap data
             */
            var proteomics_list = "pride,peptideatlas,peptide_atlas,massive,PRIDE,PeptideAtlas,MassIVE";
            var metabolomics_list = "MetaboLights Dataset,MetaboLights,metabolights,metabolights_dataset,MetabolomicsWorkbench, Metabolomics Workbench, Metabolome Workbench";
            var genomics_list = "ega,EGA";

            var proteomics_child, metabolomics_child, genomics_child;
            var treemap_data = {
                "name": "Omics",
                "children": [
                    {
                        "name": "Proteomics",
                        "children": []
                    },
                    {
                        "name": "Genomics",
                        "children": []
                    },
                    {
                        "name": "Metabolomics",
                        "children": []
                    }
                ]
            };

            for (var i = 0; i < repos.length; i++) {
                if (proteomics_list.indexOf(repos[i].name) > -1) {
                    proteomics_child = {"name": repos[i].name, "size": repos[i].value};
                    treemap_data.children[0].children.push(proteomics_child);
                    continue;
                }
                if (genomics_list.indexOf(repos[i].name) > -1) {
                    genomics_child = {"name": repos[i].name, "size": repos[i].value};
                    treemap_data.children[1].children.push(genomics_child);
                    continue;
                }
                if (metabolomics_list.indexOf(repos[i].name) > -1) {
                    metabolomics_child = {"name": repos[i].name, "size": repos[i].value};
                    treemap_data.children[2].children.push(metabolomics_child);
                    continue;
                }
            }

            var piechartname = 'chart_repos_omics';
            var body = d3.select("#" + piechartname);

            var div_width_px = body.style("width");
            var div_width = div_width_px.substr(0, div_width_px.length - 2);
            //var div_width = 420;
            var width = div_width,
                height = 300,
                radius = Math.min(width, height) / 2;


            body.attr("position", "relative");
            d3.select("#" + piechartname).selectAll("svg").remove();
            var svg = d3.select("#" + piechartname)
                .append("svg")
                .attr("style", "height:" + height)
                .attr("style", "width:" + width)
                .attr("class", "piesvg")
                .append("g");

            svg.append("g")
                .attr("class", "slices");
            svg.append("circle")
                .attr("id", "insidecycle")
                .attr("style", "stroke:none");
            body.selectAll("div").remove();


/*            var spacediv = body.append('div');
             spacediv 
             .attr( "float", "bottom" )
             .attr("id", "spacediv")
             .attr("opacity", "0.1");

            document.getElementById( "spacediv" ).innerHTML = "<p>";
*/


            var formdiv = body.append('div');
            formdiv
                .attr("class", "center") ;

            var radio_form = formdiv.append('form');

            radio_form
                .attr("id", piechartname + "_form")
                .attr("class", "center")
                .attr("style", "margin-bottom:8px; ")
                .append('input')
                .attr('type', 'radio')
                .attr('name', 'dataset')
                .attr('value', 'Repos')
                .attr('id', 'Repos')
                .text('Repos');
            radio_form
                .append('label')
                .text('Species')
                .attr('for', 'Repos')
                .append('span')
                .append('span')
            ;

            radio_form
                .append('input')
                .attr('type', 'radio')
                .attr('name', 'dataset')
                .attr('value', 'Omics')
                .attr('id', 'Omics_radio')
                .text('Omics');
            radio_form
                .append('label')
                .text('Instruments')
                .attr('for', 'Omics_radio')
                .append('span')
                .append('span')
            ;

            d3.select("#" + piechartname + "_form").select('input[value=Repos]').property('checked', true)

            d3.select("#" + piechartname + "_form").selectAll('input')
                .on('change', change);


            var pie = d3.layout.pie()
                .sort(null)
                .value(function (d) {
                    return d.value;
                });

            var arc = d3.svg.arc()
                .outerRadius(radius * 0.95)
                .innerRadius(radius * 0.6);

            svg.select("#insidecycle")
                .attr("r", radius * 0.6)
                .style("fill", "white")
                .attr("cx", 0)
                .attr("cy", 0);

            var text_name = svg.append('text')
                .attr('x', 0)
                .attr('y', 0)
                .attr('text-anchor', 'middle')
                .attr('alignment-baseline', 'middle')
                .attr('font-size', '10px')
                .attr('fill', 'white');

            var text_value = svg.append('text')
                .attr('x', 0)
                .attr('y', 0 + radius * 0.2)
                .attr('text-anchor', 'middle')
                .attr('alignment-baseline', 'middle')
                .attr('font-size', '10px')
                .attr('fill', 'white');

            var text_total = svg.append('text')
                .attr('x', radius * 0.65)
                .attr('y', radius * -0.75)
                .attr('text-anchor', 'left')
                .attr('alignment-baseline', 'middle')
                .attr('fill', 'black');

            var text_unavail = svg.append('text')
                .attr('x', radius * 0.65)
                .attr('y', radius * -0.85)
                .attr('text-anchor', 'left')
                .attr('alignment-baseline', 'middle')
                .attr('fill', 'black');


            svg.attr("transform", "translate(" + width / 2.0 + "," + height / 1.8 + ")");

            var key = function (d) {
                return d.data.name;
            };


            var color = d3.scale.category20();
            var treemap_color = {"Proteomics": "#2CA02C", "Metabolomics": "#FF7F0E", "Genomics": "#1f77b4"};

            /*
             * draw the treemap
             var margin = {top: 40, right: 10, bottom: 10, left: 10};
             treemap_width = width - margin.left - margin.right;
             treemap_height = height - margin.top - margin.bottom;
             var treemap = d3.layout.treemap()
             .size([treemap_width, treemap_height])
             .sticky(true)
             .value(function(d) { return d.size; });
             var treemap_tooltip = d3.select('body').append("div")
             .attr("class", "tooltip")
             .style("opacity", 0);

             */

            change();


            function draw_treemap() {
                var treemap_url_pre = '#/search?q=*:* AND repository:"';
                var treemap_div = body.append("div")
                    .attr("id", "treemap_div")
                    .style("position", "absolute")
                    .style("width", (treemap_width + margin.left + margin.right - 40 ) + "px")
                    .style("height", (treemap_height + margin.top + margin.bottom) + "px")
                    .style("margin-left", (margin.left) + "px")
                    .style("top", margin.top + "px");

                var treemap_node = treemap_div.datum(treemap_data).selectAll(".treemap_node")
                    .data(treemap.nodes)
                    .enter().append("div")
                    .attr("class", "treemap_node")
                    .call(position)
                    .style("background", function (d) {
                        return d.children ? treemap_color[d.name] : null;
                    })
                    .text(function (d) {
                        return d.children ? null : d.name;
                    })
                    .on("click", function (d, i) {
                        $("#field").val(d.label);
                        myQueryEvent();

                        location.href = treemap_url_pre + d.name + '"';

                        if (d.name == "MetaboLights Dataset")
                            location.href = treemap_url_pre + "MetaboLights" + '"';
                        if (d.name == "Metabolome Workbench")
                            location.href = treemap_url_pre + "MetabolomicsWorkbench" + '"';
                    })
                    .on("mousemove", function (d, i) {
                        treemap_tooltip.transition()
                            .duration(200)
                            .style("opacity", .9);

                        var mouse_coords = d3.mouse(
                            treemap_tooltip.node().parentElement);

                        treemap_tooltip.html("<strong>" + d.name + ": <br>" + d.value + "</strong> datasets" )
                            .style("left", (mouse_coords[0] + screen.width/11) + "px")
                            .style("top", (mouse_coords[1] - 30) + "px")
                            .style("width", d.name.length * 5 + d.value.toString().length * 5 + 80 + "px");
                    })
                    .on("mouseout", function (d, i) {
                        treemap_tooltip.transition()
                            .duration(500)
                            .style("opacity", 0);
                    })
            }

            function position() {
                this.style("left", function (d) {
                    return d.x + "px";
                })
                    .style("top", function (d) {
                        return d.y + "px";
                    })
                    .style("width", function (d) {
                        return Math.max(0, d.dx - 1) + "px";
                    })
                    .style("height", function (d) {
                        return Math.max(0, d.dy - 1) + "px";
                    });
            }
        }
        function transformdomains(arr) {

            var newarry = [];
            for (var i = 0; i < arr.length; i++) {
                newarry.push({
                    "name": arr[i]["domain"]["name"],
                    "value": arr[i]["domain"]["value"]
                });
            }
            return newarry;
        };

        function gettotal(arr) {
            var sum = 0;
            for (var i = 0; i < arr.length; i++)
                sum += parseInt(arr[i].value);
            return sum;
        };

        function change() {
            var value = this.value || 'Repos';
            var data;
            var url_pre;
            if (value == 'Omics') {
                data = omicstype;
                text_total.text("Total:" + total_omics);
//                text_unavail.text("Unavailable:" + unavailableomics.value);
                url_pre = '#/search?q=*:* AND omics_type:"';
                // text_total.text("Total:"+total_omics);
                svg.attr("visibility", null);
//                d3.select("#treemap_div").remove();
            }
            if (value == 'Repos') {
                data = repos;
                text_total.text("Total:" + total_repos);
//                text_unavail.text("");
                url_pre = '#/search?q=*:* AND repository:"';
                // text_total.text("Total:"+total_repos);
                svg.attr("visibility", null);
//                d3.select("#treemap_div").remove();
            }
            /*           if (value == 'Treemap') {
             svg.attr("visibility", "hidden");
             draw_treemap();
             return;
             }
             */
            /*init the inside cycle*/
            text_name.text(data[data.length - 1].name).style("font-size", "14px");
            text_value.text(data[data.length - 1].value + " datasets").style("font-size", "12px");
            var colorinside = color(data.length - 1);
//            if (value === 'Omics') colorinside = treemap_color[data[data.length - 1].name];
            svg.select("#insidecycle")
                .style("fill", colorinside)
                .style("opacity", ".95");

            /* ------- PIE SLICES -------*/
            var slice = svg.select(".slices").selectAll("path.slice")
                .data(pie(data), key);


            slice.enter()
                .insert("path")
                .style("fill", function (d, i) {
//                    if (value === 'Omics') return treemap_color[d.data.name];
                    return color(i);
                })
                .attr("class", "slice")
                .on("click", function (d, i) {
                    // alert("you have clicked"+d.data.name);
                    // window.open("browse.html#/search?q="+d.data.name);
                    location.href = url_pre + d.data.name + '"';
                        $("#field").val(d.data.name);
                        myQueryEvent();

                    if (d.data.name == "MetaboLights Dataset")
                        location.href = url_pre + "MetaboLights" + '"';
                    if (d.data.name == "Metabolome Workbench")
                        location.href = url_pre + "MetabolomicsWorkbench" + '"';
                })
                .on("mouseover", function (d, i) {
                    var temptext1 = d.data.name;
                    var temptext2 = d.data.value;
                    colorinside = color(i);
//                    if (value === 'Omics') colorinside = treemap_color[d.data.name];
                    svg.select("#insidecycle")
                        .style("fill", colorinside)
                        .style("opacity", ".8");
                    text_name
                        .text(temptext1);
                    text_value
                        .text(temptext2 + " datasets");
                })
                .on("mouseout", function (d, i) {
                    colorinside = color(i);
//                    if (value === 'Omics') colorinside = treemap_color[d.data.name];
                    svg.select("#insidecycle")
                        .style("fill", colorinside)
                        .style("opacity", ".95");
                })
            ;

            slice
                .transition().duration(1000)
                .attrTween("d", function (d) {
                    this._current = this._current || d;
                    var interpolate = d3.interpolate(this._current, d);
                    this._current = interpolate(0);
                    return function (t) {
                        return arc(interpolate(t));
                    };
                })

            ;

            slice.exit()
                .remove();
        };

    }
}

function output_error_info(errordiv) {
    var tempdiv = d3.select("#" + errordiv);

    tempdiv.selectAll("i").remove();
    tempdiv.selectAll("p").remove();
    tempdiv.append("p").attr("class", "error-info")
        .html("Sorry, accessing to this web service was temporally failed.");
}

function output_getting_info(errordiv) {
    var tempdiv = d3.select("#" + errordiv);
    if(tempdiv.select("i")[0][0]===null){
        tempdiv.append("i").attr("class", "fa fa-spinner fa-spin");
    }
}
function remove_getting_info(errordiv) {
    var tempdiv = d3.select("#" + errordiv);
    tempdiv.select("i").remove();
}




function draw_wheel_pie_chart( type ) {

  alert( type );
  return 1;

// Get repository JSON
    var url='http://proteomecentral.proteomexchange.org/devDC/cgi/GetJSON';
    var req=new XMLHttpRequest(); // a new request

//    var domain_url = url + '?mode=species';
    var domain_url = url + '?mode=domains';
    req.open("GET",domain_url,false);
    req.send(null);
    var domains = JSON.parse( req.responseText );

//    var omics_url = url + '?mode=instruments'  // geojson points
    var omics_url = url + '?mode=omics'  // geojson points
    req.open("GET",omics_url,false);
    req.send(null);
    var omics = JSON.parse( req.responseText );

  var url='http://proteomecentral.proteomexchange.org/devDC/cgi/GetJSON';
  var req=new XMLHttpRequest(); // a new request

  var data_url = url + '?mode=type';
  req.open("GET",data_url,false);
  req.send(null);
  var wheel_data = JSON.parse( req.responseText );

        if (error) {
            retry_limit_time--;
            if (retry_limit_time <= 0) {
                output_error_info('chart_repos_omics');
                return;
            }
            output_getting_info('chart_repos_omics');
            pie_charts_repos_omics();
        }
        else {
            remove_getting_info('chart_repos_omics');
            var repos = transformdomains(domains);
            omicstype.shift();
            var unavailableomics = omicstype.pop();

            var total_omics = gettotal(omicstype);
            var total_repos = gettotal(repos);

            omicstype = omicstype.sort(function (a, b) {
                return parseInt(a.value) - parseInt(b.value);
            });
            repos = repos.sort(function (a, b) {
                return parseInt(a.value) - parseInt(b.value);
            });


            /*
             * prepare the treemap data
             */
            var proteomics_list = "pride,peptideatlas,peptide_atlas,massive,PRIDE,PeptideAtlas,MassIVE";
            var metabolomics_list = "MetaboLights Dataset,MetaboLights,metabolights,metabolights_dataset,MetabolomicsWorkbench, Metabolomics Workbench, Metabolome Workbench";
            var genomics_list = "ega,EGA";

            var proteomics_child, metabolomics_child, genomics_child;
            var treemap_data = {
                "name": "Omics",
                "children": [
                    {
                        "name": "Proteomics",
                        "children": []
                    },
                    {
                        "name": "Genomics",
                        "children": []
                    },
                    {
                        "name": "Metabolomics",
                        "children": []
                    }
                ]
            };

            for (var i = 0; i < repos.length; i++) {
                if (proteomics_list.indexOf(repos[i].name) > -1) {
                    proteomics_child = {"name": repos[i].name, "size": repos[i].value};
                    treemap_data.children[0].children.push(proteomics_child);
                    continue;
                }
                if (genomics_list.indexOf(repos[i].name) > -1) {
                    genomics_child = {"name": repos[i].name, "size": repos[i].value};
                    treemap_data.children[1].children.push(genomics_child);
                    continue;
                }
                if (metabolomics_list.indexOf(repos[i].name) > -1) {
                    metabolomics_child = {"name": repos[i].name, "size": repos[i].value};
                    treemap_data.children[2].children.push(metabolomics_child);
                    continue;
                }
            }

            var piechartname = 'chart_repos_omics';
            var body = d3.select("#" + piechartname);

            var div_width_px = body.style("width");
            var div_width = div_width_px.substr(0, div_width_px.length - 2);
            //var div_width = 420;
            var width = div_width,
                height = 300,
                radius = Math.min(width, height) / 2;


            body.attr("position", "relative");
            d3.select("#" + piechartname).selectAll("svg").remove();
            var svg = d3.select("#" + piechartname)
                .append("svg")
                .attr("style", "height:" + height)
                .attr("style", "width:" + width)
                .attr("class", "piesvg")
                .append("g");

            svg.append("g")
                .attr("class", "slices");
            svg.append("circle")
                .attr("id", "insidecycle")
                .attr("style", "stroke:none");
            body.selectAll("div").remove();
            var formdiv = body.append('div');
            formdiv
                .attr("class", "center")
                .attr("style", "width:150px;margin-top:15px")
            ;

            var radio_form = formdiv.append('form');

            radio_form
                .attr("id", piechartname + "_form")
                .attr("class", "center")
                .attr("style", "margin-bottom:8px; ")
                .append('input')
                .attr('type', 'radio')
                .attr('name', 'dataset')
                .attr('value', 'Repos')
                .attr('id', 'Repos')
                .text('Repos');
            radio_form
                .append('label')
                .text('Species')
                .attr('for', 'Repos')
                .append('span')
                .append('span')
            ;

            radio_form
                .append('input')
                .attr('type', 'radio')
                .attr('name', 'dataset')
                .attr('value', 'Omics')
                .attr('id', 'Omics_radio')
                .text('Omics');
            radio_form
                .append('label')
                .text('Instruments')
                .attr('for', 'Omics_radio')
                .append('span')
                .append('span')
            ;

            d3.select("#" + piechartname + "_form").select('input[value=Repos]').property('checked', true)

            d3.select("#" + piechartname + "_form").selectAll('input')
                .on('change', change);


            var pie = d3.layout.pie()
                .sort(null)
                .value(function (d) {
                    return d.value;
                });

            var arc = d3.svg.arc()
                .outerRadius(radius * 0.95)
                .innerRadius(radius * 0.6);

            svg.select("#insidecycle")
                .attr("r", radius * 0.6)
                .style("fill", "white")
                .attr("cx", 0)
                .attr("cy", 0);

            var text_name = svg.append('text')
                .attr('x', 0)
                .attr('y', 0)
                .attr('text-anchor', 'middle')
                .attr('alignment-baseline', 'middle')
                .attr('font-size', '10px')
                .attr('fill', 'white');

            var text_value = svg.append('text')
                .attr('x', 0)
                .attr('y', 0 + radius * 0.2)
                .attr('text-anchor', 'middle')
                .attr('alignment-baseline', 'middle')
                .attr('font-size', '10px')
                .attr('fill', 'white');

            var text_total = svg.append('text')
                .attr('x', radius * 0.65)
                .attr('y', radius * -0.75)
                .attr('text-anchor', 'left')
                .attr('alignment-baseline', 'middle')
                .attr('fill', 'black');

            var text_unavail = svg.append('text')
                .attr('x', radius * 0.65)
                .attr('y', radius * -0.85)
                .attr('text-anchor', 'left')
                .attr('alignment-baseline', 'middle')
                .attr('fill', 'black');


            svg.attr("transform", "translate(" + width / 2.0 + "," + height / 1.8 + ")");

            var key = function (d) {
                return d.data.name;
            };


            var color = d3.scale.category20();
            var treemap_color = {"Proteomics": "#2CA02C", "Metabolomics": "#FF7F0E", "Genomics": "#1f77b4"};

            /*
             * draw the treemap
             var margin = {top: 40, right: 10, bottom: 10, left: 10};
             treemap_width = width - margin.left - margin.right;
             treemap_height = height - margin.top - margin.bottom;
             var treemap = d3.layout.treemap()
             .size([treemap_width, treemap_height])
             .sticky(true)
             .value(function(d) { return d.size; });
             var treemap_tooltip = d3.select('body').append("div")
             .attr("class", "tooltip")
             .style("opacity", 0);

             */

            change();


            function draw_treemap() {
                var treemap_url_pre = '#/search?q=*:* AND repository:"';
                var treemap_div = body.append("div")
                    .attr("id", "treemap_div")
                    .style("position", "absolute")
                    .style("width", (treemap_width + margin.left + margin.right - 40 ) + "px")
                    .style("height", (treemap_height + margin.top + margin.bottom) + "px")
                    .style("margin-left", (margin.left) + "px")
                    .style("top", margin.top + "px");

                var treemap_node = treemap_div.datum(treemap_data).selectAll(".treemap_node")
                    .data(treemap.nodes)
                    .enter().append("div")
                    .attr("class", "treemap_node")
                    .call(position)
                    .style("background", function (d) {
                        return d.children ? treemap_color[d.name] : null;
                    })
                    .text(function (d) {
                        return d.children ? null : d.name;
                    })
                    .on("click", function (d, i) {
                        location.href = treemap_url_pre + d.name + '"';

                        if (d.name == "MetaboLights Dataset")
                            location.href = treemap_url_pre + "MetaboLights" + '"';
                        if (d.name == "Metabolome Workbench")
                            location.href = treemap_url_pre + "MetabolomicsWorkbench" + '"';
                    })
                    .on("mousemove", function (d, i) {
                        treemap_tooltip.transition()
                            .duration(200)
                            .style("opacity", .9);

                        var mouse_coords = d3.mouse(
                            treemap_tooltip.node().parentElement);

                        treemap_tooltip.html("<strong>" + d.name + ": <br>" + d.value + "</strong> datasets" )
                            .style("left", (mouse_coords[0] + screen.width/11) + "px")
                            .style("top", (mouse_coords[1] - 30) + "px")
                            .style("width", d.name.length * 5 + d.value.toString().length * 5 + 80 + "px");
                    })
                    .on("mouseout", function (d, i) {
                        treemap_tooltip.transition()
                            .duration(500)
                            .style("opacity", 0);
                    })
            }

            function position() {
                this.style("left", function (d) {
                    return d.x + "px";
                })
                    .style("top", function (d) {
                        return d.y + "px";
                    })
                    .style("width", function (d) {
                        return Math.max(0, d.dx - 1) + "px";
                    })
                    .style("height", function (d) {
                        return Math.max(0, d.dy - 1) + "px";
                    });
            }
        }
        function transformdomains(arr) {

            var newarry = [];
            for (var i = 0; i < arr.length; i++) {
                newarry.push({
                    "name": arr[i]["domain"]["name"],
                    "value": arr[i]["domain"]["value"]
                });
            }
            return newarry;
        };

        function gettotal(arr) {
            var sum = 0;
            for (var i = 0; i < arr.length; i++)
                sum += parseInt(arr[i].value);
            return sum;
        };

        function change() {
            var value = this.value || 'Repos';
            var data;
            var url_pre;
            if (value == 'Omics') {
                data = omicstype;
                text_total.text("Total:" + total_omics);
//                text_unavail.text("Unavailable:" + unavailableomics.value);
                url_pre = '#/search?q=*:* AND omics_type:"';
                // text_total.text("Total:"+total_omics);
                svg.attr("visibility", null);
//                d3.select("#treemap_div").remove();
            }
            if (value == 'Repos') {
                data = repos;
                text_total.text("Total:" + total_repos);
//                text_unavail.text("");
                url_pre = '#/search?q=*:* AND repository:"';
                // text_total.text("Total:"+total_repos);
                svg.attr("visibility", null);
//                d3.select("#treemap_div").remove();
            }
            /*           if (value == 'Treemap') {
             svg.attr("visibility", "hidden");
             draw_treemap();
             return;
             }
             */
            /*init the inside cycle*/
            text_name.text(data[data.length - 1].name).style("font-size", "14px");
            text_value.text(data[data.length - 1].value + " datasets").style("font-size", "12px");
            var colorinside = color(data.length - 1);
//            if (value === 'Omics') colorinside = treemap_color[data[data.length - 1].name];
            svg.select("#insidecycle")
                .style("fill", colorinside)
                .style("opacity", ".95");

            /* ------- PIE SLICES -------*/
            var slice = svg.select(".slices").selectAll("path.slice")
                .data(pie(data), key);


            slice.enter()
                .insert("path")
                .style("fill", function (d, i) {
//                    if (value === 'Omics') return treemap_color[d.data.name];
                    return color(i);
                })
                .attr("class", "slice")
                .on("click", function (d, i) {
                    // alert("you have clicked"+d.data.name);
                    // window.open("browse.html#/search?q="+d.data.name);
                    location.href = url_pre + d.data.name + '"';

                    if (d.data.name == "MetaboLights Dataset")
                        location.href = url_pre + "MetaboLights" + '"';
                    if (d.data.name == "Metabolome Workbench")
                        location.href = url_pre + "MetabolomicsWorkbench" + '"';
                })
                .on("mouseover", function (d, i) {
                    var temptext1 = d.data.name;
                    var temptext2 = d.data.value;
                    colorinside = color(i);
//                    if (value === 'Omics') colorinside = treemap_color[d.data.name];
                    svg.select("#insidecycle")
                        .style("fill", colorinside)
                        .style("opacity", ".8");
                    text_name
                        .text(temptext1);
                    text_value
                        .text(temptext2 + " datasets");
                })
                .on("mouseout", function (d, i) {
                    colorinside = color(i);
//                    if (value === 'Omics') colorinside = treemap_color[d.data.name];
                    svg.select("#insidecycle")
                        .style("fill", colorinside)
                        .style("opacity", ".95");
                })
            ;

            slice
                .transition().duration(1000)
                .attrTween("d", function (d) {
                    this._current = this._current || d;
                    var interpolate = d3.interpolate(this._current, d);
                    this._current = interpolate(0);
                    return function (t) {
                        return arc(interpolate(t));
                    };
                })

            ;

            slice.exit()
                .remove();
        };

    }

