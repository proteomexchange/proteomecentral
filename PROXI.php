<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" lang="en" xml:lang="en">
<!--#set var="TITLE" value="PROXI server status"-->
<!--#include virtual="includes/header.inc.php" -->
<link rel="stylesheet" href="css/proxistatus.css">
<script src="javascript/js/proxistatus.js"></script>

<body onload="main();">

<!-- BEGIN main content -->
<h1 style="margin-left:10px;">PROXI Servers Status<span class="code404 running" id="stat">Checking...</span></h1>

<div id="main"></div>
<hr size="1">
Debug Info::<br/>
<div id="debug"></div>
<hr size="1">

<!-- END main content -->

<!--#include virtual="includes/footer.inc.php" -->
</body>
</html>
