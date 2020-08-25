<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" lang="en" xml:lang="en">
<?php
  $DOCUMENT_ROOT = $_SERVER['DOCUMENT_ROOT'];
  /* $Id$ */
  $TITLE="PROXI server status";
  $SUBTITLE="";
  include("$DOCUMENT_ROOT/includes/header.inc.php");
?>
<script src="javascript/js/he-master/he.js"></script>
<script src="javascript/js/proxistatus.js"></script>
<style type="text/css">
a {
 text-decoration: none;
}
a:hover {
 text-decoration: underline;
}
.prox {
 border-collapse: collapse;
}
.rowdata:hover {
 border: 3px solid black;
}
.prox td {
 border-bottom: 1px solid #cdcdcd;
 padding: 3px 10px;
 transition: background-color 2s;
}
.prox th {
 border-bottom: 2px solid black;
 margin: 5px;
 padding: 3px 10px;
 text-align:left;
 background-color: #e5e5e5;
// color: #fff;
}
.rep {
 border-top: 2px solid black;
 background-color: #cdcdcd;
 font-size: 25px;
 font-weight:bold;
}
.rep a {
 font-size: 17px;
 float: right;
 color: #777;
}
.code200 {
 background-color: #5f5;
}
.code-200 {
 background-color: #f88;
}
.code404 {
 background-color: #ec1;
}
.code500 {
 background-color: #d22;
 color: #eee;
}
.code501 {
 background-color: #bbb;
}
.code598 {
 background-color: #f55;
}
#stat {
 border-radius: 20px;
 border: 1px solid black;
 transition: background-color 2s;
 padding:5px 10px;
 width: 200px;
 display:inline-block;
 text-align: center;
}
.running {
    animation-name:processing;
    animation-duration:0.7s;
    animation-direction:alternate;
    animation-iteration-count:infinite;
    animation-timing-function:linear;
}
@keyframes processing {
    from { background-color:#ec1; }
    to   { background-color:#fff; }
}

</style>

<body onload="main();">

<!-- BEGIN main content -->
<h1>PROXI Servers Status&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;<span class="code404 running" id="stat">&nbsp;&nbsp;Checking...&nbsp;&nbsp;</span></h1>

<div id="main"></div>
<hr size="1">
Debug Info::<br/>
<div id="debug"></div>
<hr size="1">

<!-- END main content -->

<?php
  include("$DOCUMENT_ROOT/includes/footer.inc.php");
?>
</body>
</html>
