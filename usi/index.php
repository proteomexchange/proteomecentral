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
hr {
  border-bottom: 1px solid black;
  border-top: 0;
}
a {
 text-decoration: none;
 font-weight:bolder;
 color:#2c99ce;
}
a:hover {
 text-decoration: underline;
 color:#f26722;
 cursor:pointer;
}
#usi_input {
 margin: 4px;
 padding: 6px;
 border: 2px solid black;
 vertical-align: baseline;
}
#NBTexamples {
  position: absolute;
  top: 200px;
  left: 200px;
  visibility: hidden;
  opacity: 0;
  transition: visibility 0.5s, opacity 0.5s linear;
}
td[title$=spectrum]:hover {
 cursor:pointer;
 background-color: #2c99ce;
 color: #fff;
}
td[title$=response]:hover {
 cursor:pointer;
 background-color: #e5e5e5;
}
.examples {
 position: relative;
 left: 40px;
 padding: 5px 10px;
 margin: 0;
 border: 1px solid #aaa;
 color: #666;
 border-radius: 20px;
 width:130px;
 background-color: #eee;
}
.examples:hover {
 background-color: #fff;
 cursor:pointer;
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
 font-size: large;
 font-weight:bold;
}
.rep a {
 font-size: 17px;
 float: right;
 color: #777;
}
.code200 { background-color: #5f5; }
.code400 { background-color: #666; color: #eee; }
.code404 { background-color: #ec1; }
.code500 { background-color: #d22; color: #eee; }
.code501 { background-color: #bbb; }
.code598 { background-color: #f55; }
#usi_stat, #usi_valid {
 border-radius: 20px;
 border: 2px solid black;
 transition: background-color .5s;
 background:#000;
 color:#fff;
 padding:5px 10px;
 display:inline-block;
 text-align: center;
}
#usi_stat:hover, #usi_valid:hover {
 cursor:pointer;
 background:#fff;
 color:#000;
}
.valid {
 color: #2b2;
}
.invalid {
 color: #b22;
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

<body onload="init();">

<!-- BEGIN main content -->
<h1 style="display:inline-block;">Universal Spectrum Identifier</h1>

<a href="http://psidev.info/usi" target="PSI" style="margin-left:30px;" class="smgr">what's this?</a>

<!-- select id="example_usis" class="examples" onchange="update_usi_input(this);">
<option value="">Example USIs&nbsp;&nbsp;&nbsp;⇣</option>
<option value="mzspec:PXD000966:CPTAC_CompRef_00_iTRAQ_12_5Feb12_Cougar_11-10-11.mzML:scan:11850:[UNIMOD:214]YYWGGLYSWDMSK[UNIMOD:214]/2">mzspec:PXD000966:CPTAC_CompRef_00_iTRAQ_12_5Feb12_Cougar_11-10-11.mzML:scan:11850:[UNIMOD:214]YYWGGLYSWDMSK[UNIMOD:214]/2</option>
<option value="mzspec:PXD002255:ES_XP_Ubi_97H_HCD_349:scan:9617:LAEIYVNSSFYK/2">mzspec:PXD002255:ES_XP_Ubi_97H_HCD_349:scan:9617:LAEIYVNSSFYK/2</option>
<option value="mzspec:PXD002286:081213-Wittie-Phos-1A:scan:14366:MVC[Carbamidomethyl]S[Phospho]PVTVR/2">mzspec:PXD002286:081213-Wittie-Phos-1A:scan:14366:MVC[Carbamidomethyl]S[Phospho]PVTVR/2</option>
<option value="mzspec:PXD001464:CL_1hRP_rep3:nativeId:1,1,2740,10:Q[Gln->pyro-Glu]IGDALPVSC[Carbamidomethyl]TISASR/2">mzspec:PXD001464:CL_1hRP_rep3:nativeId:1,1,2740,10:Q[Gln->pyro-Glu]IGDALPVSC[Carbamidomethyl]TISASR/2</option>
<option value="mzspec:PXD000865:00603_F01_P004608_B00F_A00_R1:scan:14453:SSLLDVLAAR/2">mzspec:PXD000865:00603_F01_P004608_B00F_A00_R1:scan:14453:SSLLDVLAAR/2</option>
<option value="mzspec:PXD000561:Adult_Urinarybladder_bRP_Elite_71_f14:scan:1872:FSGSSSGADR/2">mzspec:PXD000561:Adult_Urinarybladder_bRP_Elite_71_f14:scan:1872:FSGSSSGADR/2</option>
</select -->

<span onclick="toggle_box_examples();" class="examples">Example USIs&nbsp;&nbsp;&nbsp;⇣</span>

<span style="margin-left:150px;" onclick="check_usi();" id="usi_stat">&nbsp;&nbsp;Look Up USI&nbsp;&nbsp;</span>
<span style="margin-left:50px;" onclick="validate_usi(false);" id="usi_valid">&nbsp;&nbsp;Validate USI&nbsp;&nbsp;</span>

<br>
<input id="usi_input" onchange="document.getElementById('usi_desc').innerHTML = '';" style="min-width:95%;"/><br/>
<span class="smgr" id="usi_desc">&nbsp;</span>
<br>


<div style="margin-top:20px;" id="main"></div>

<div style="min-height:500px;" id="spec"></div>


<div id="NBTexamples">
<div id="dataset-primary" class="site-content">
<h1 style="margin:0;" class="dataset-title">Box 1. Example use cases for Universal Spectrum Identifiers (USIs)</h1>

<div class="dataset-content">

<span class="dataset-secthead">Case 1: Typical identification of an unmodified peptide in support of protein identification (one spectrum, simple interpretation, no mass modifications)</span>
<a onclick="pick_box_example(this);">mzspec:PXD000561:Adult_Frontalcortex_bRP_Elite_85_f09:scan:17555:VLHPLEGAVVIIFK/2</a><br>
<i>Example 1a: Peptide Spectrum Match (PSM) of an unmodified doubly-charged peptide VLHPLEGAVVIIFK from the Kim et al.15 draft human proteome dataset. Most of the intense unannotated peaks are internal fragmentation ions of this peptide.</i>

<br><br>
<span class="dataset-secthead">Case 2: Flexible notation for reporting identification of post-translational modifications (one spectrum, interpretation with Unimod names, Unimod identifiers, PSI-MOD names and PSI-MOD identifiers for mass modifications)</span>
<a onclick="pick_box_example(this);">mzspec:PXD000966:CPTAC_CompRef_00_iTRAQ_05_2Feb12_Cougar_11-10-09.mzML:scan:12298:[iTRAQ4plex]-LHFFM[Oxidation]PGFAPLTSR/2</a><br>
<i>Example 2a: PSM of a iTRAQ4plex-labeled peptide from a CPTAC CompRef dataset16, with modifications specified using Unimod names. This is the recommended notation since it precisely identifies the modification while also being easily interpretable.</i><hr>
<a onclick="pick_box_example(this);">mzspec:PXD000966:CPTAC_CompRef_00_iTRAQ_05_2Feb12_Cougar_11-10-09.mzML:scan:12298:[UNIMOD:214]-LHFFM[UNIMOD:35]PGFAPLTSR/2</a><br>
<i>Example 2b: Same CPTAC PSM with modifications specified using Unimod accession numbers. This notation is equally precise but not as easily readable as modification names.</i><hr>
<a onclick="pick_box_example(this);">mzspec:PXD000966:CPTAC_CompRef_00_iTRAQ_05_2Feb12_Cougar_11-10-09.mzML:scan:12298:[MOD:01505]-LHFFM[L-methionine sulfoxide]PGFAPLTSR/2</a><br>
<i>Example 2c: Same CPTAC PSM with modifications specified using PSI-MOD names and accession numbers.</i><hr>
<a onclick="pick_box_example(this);">mzspec:PXD000966:CPTAC_CompRef_00_iTRAQ_05_2Feb12_Cougar_11-10-09.mzML:scan:12298:[+144.1021]-LHFFM[+15.9949]PGFAPLTSR/2</a><br>
<i>Example 2d: Same CPTAC PSM with modifications specified using mass offsets. This notation is generally discouraged when the type of modification is known in advance, but is the only available option to report results of open modification searches returning algorithmically-detected uninterpreted mass offsets.</i>

<br><br>
<span class="dataset-secthead">Case 3: Supporting evidence of translated gene products (i.e., protein existence) as detected in public datasets, including matches to spectra of synthetic peptides as required by the HUPO Human Proteome Project (HPP) guidelines for detection of novel proteins</span>
<a onclick="pick_box_example(this);">mzspec:PXD022531:j12541_C5orf38:scan:12368:VAATLEILTLK/2</a><br>
<i>Example 3a: Identification derived from a prey protein in the Huttlin et al.17 BioPlex dataset, pulled down as a binding partner to bait protein C5orf38. With only this single identification, this protein remains an HPP missing protein since a single identification does not meet HPP guidelines.</i><hr>
<a onclick="pick_box_example(this);">mzspec:PXD022531:b11156_PRAMEF17:scan:22140:VAATLEILTLK/2</a><br>
<i>Example 3b: PSM of the same peptide as above, but derived from a recombinant protein used as a bait in the Huttlin et al. BioPlex dataset. This PSM provides a much higher signal-to-noise ratio synthetic peptide reference spectrum as required by HPP guidelines.</i>

<br><br>
<span class="dataset-secthead">
Case 4: Data reanalysis refuting previous claims of novel HLA peptides</span>
<a onclick="pick_box_example(this);">mzspec:PXD000394:20130504_EXQ3_MiBa_SA_Fib-2:scan:4234:SGVSRKPAPG/2</a><br>
<i>Example 4a: Identification originally used to reported a novel HLA peptide (Mylonas et al.4 Figure 2A).</i><hr>
<a onclick="pick_box_example(this);">mzspec:PXD010793:20170817_QEh1_LC1_HuPa_SplicingPep_10pmol_G2_R01:scan:8296:SGVSRKPAPG/2</a><br>
<i>Example 4b: Spectrum of a synthetic peptide for the same peptide SGVSRKPAPG/2 revealing a distinctively different fragmentation pattern from example 4a.</i><hr>
<a onclick="pick_box_example(this);">mzspec:PXD000394:20130504_EXQ3_MiBa_SA_Fib-2:scan:4234:ATASPPRQK/2</a><br>
<i>Example 4c: The same spectrum as for example 4a, but correctly identified to commonly-occurring peptide from UniProtKB protein Q9UQ35 (Mylonas et al. Figure 2B).</i><hr>
<a onclick="pick_box_example(this);">mzspec:PXD010793:20170817_QEh1_LC1_HuPa_SplicingPep_10pmol_G2_R01:scan:7452:ATASPPRQK/2</a><br>
<i>Example 4d: Spectrum of a synthetic peptide for ATASPPRQK/2 (same as 4c) with a fragmentation pattern matching example 4c, thus confirming the identification to protein Q9UQ35.</i>

<br><br>
<span class="dataset-secthead">
Case 5: Reporting spectra of unidentified peptides with the potential to lead to interesting new discoveries</span>
<a onclick="pick_box_example(this);">mzspec:PXD010154:01284_E04_P013188_B00_N29_R1.mzML:scan:31291</a><br>
<i>Example 5a: Unidentified peptide detected by clustering as highly abundant only in Small intestine and Duodenum out of 29 human tissues13.</i><hr>
<a onclick="pick_box_example(this);">mzspec:PXD010154:01284_E04_P013188_B00_N29_R1.mzML:scan:31291:DQNGTWEM[Oxidation]ESNENFEGYM[Oxidation]K/2</a><br>
<i>Example 5b: Manual annotation of the spectrum from example 5a reveals it to be a multiply-modified version of a peptide previously detected only as unmodified.</i>

<br>
<a style="float:right" class="dataset-title" onclick="toggle_box_examples();">Dismiss</a>
</div>
</div>
</div>



<!-- END main content -->

<?php
  include("$DOCUMENT_ROOT/includes/footer.inc.php");
?>
</body>
</html>
