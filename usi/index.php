<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" lang="en" xml:lang="en">
<?php
  $DOCUMENT_ROOT = $_SERVER['DOCUMENT_ROOT'];
  /* $Id$ */
  $TITLE="Universal Spectrum Identifier // ProteomeXchange";
  $SUBTITLE="";
  include("$DOCUMENT_ROOT/includes/header.inc.php");
?>
<script src="../javascript/js/usi.js"></script>
<script src="../javascript/js/lorikeet/jquery.min.js"></script>
<script src="../javascript/js/lorikeet/jquery-ui.min.js"></script>
<script src="../javascript/js/lorikeet/jquery.flot.js"></script>
<script src="../javascript/js/lorikeet/jquery.flot.selection.js"></script>
<script src="../javascript/js/lorikeet/specview.js"></script>
<script src="../javascript/js/lorikeet/peptide.js"></script>
<script src="../javascript/js/lorikeet/aminoacid.js"></script>
<script src="../javascript/js/lorikeet/ion.js"></script>
<link rel="stylesheet" type="text/css" href="../javascript/css/lorikeet.css">
<style type="text/css">
h1 {
  margin-left: 5px;
  margin-bottom: 0px;
}
a {
 text-decoration: none;
 font-weight:bolder;
 color:#2c99ce;
}
a:hover {
 text-decoration: underline;
 color:#f26722;
}
#usi_input {
 margin: 4px;
 padding: 6px;
 border: 2px solid black;
 vertical-align: baseline;
}
td[title$=spectrum]:hover, td[title$=response]:hover {
 cursor:pointer;
 background-color: #2c99ce;
 color: #fff;
}
.smgr {
 font-size: small;
 font-weight: normal;
 color: #aaa;
}
.prox {
 border-collapse: collapse;
}
.rowdata:hover {
 border-bottom: 2px solid #f26722;
}
.prox td {
 border-bottom: 1px solid #cdcdcd;
 padding: 3px 10px;
}
.prox th {
 border-bottom: 2px solid black;
 margin: 5px;
 padding: 3px 10px;
 text-align:left;
 background-color: #e5e5e5;
}
h1.title {
 line-height: normal;
 padding: 10px;
 margin:0;
 position: relative;
 top: -10px;
 left: -10px;
 width: 100%;
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
#usi_stat {
 border-radius: 20px;
 border: 2px solid black;
 transition: background-color .5s;
 background:#000;
 color:#fff;
 padding:5px 10px;
 display:inline-block;
 text-align: center;
}
#usi_stat:hover {
 cursor:pointer;
 background:#fff;
 color:#000;
}
.running {
    animation-name:processing;
    animation-duration:0.7s;
    animation-direction:alternate;
    animation-iteration-count:infinite;
    animation-timing-function:linear;
}
@keyframes processing {
    from { background-color:#f26722; }
    to   { background-color:#000000; }
}
.json {
 font-family: Consolas,monospace;
 white-space: pre;
 display:inline-block;
 border: 1px solid #999;
 margin-left:10px;
 margin-bottom:30px;
 padding: 10px;
 background-color: #fff;
 box-shadow: 0 3px 10px 0 rgba(0,0,0,.5);
 max-width: 100%;
}
</style>

<body>

<!-- BEGIN main content -->
<h1 style="display:inline-block;">Universal Spectrum Identifier</h1>
<span onclick="document.getElementById('usi_input').value='mzspec:PXD000966:CPTAC_CompRef_00_iTRAQ_12_5Feb12_Cougar_11-10-11.mzML:scan:11850:[UNIMOD:214]YYWGGLYSWDMSK[UNIMOD:214]/2';" style="cursor:pointer;margin-left:40px;" class="smgr">[ example ]</span>
<br>
<input id="usi_input" size="120"/>&nbsp;<span onclick="check_usi();" id="usi_stat">&nbsp;&nbsp;Look Up USI&nbsp;&nbsp;</span>

<br>

<div style="margin-top:50px;" id="main"></div>

<div id="spec"></div>

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
