<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" lang="en" xml:lang="en">
<?php
  $DOCUMENT_ROOT = $_SERVER['DOCUMENT_ROOT'];
  /* $Id$ */
  $TITLE="ProteomeXchange Dataset Submission Service Documentation";
  $SUBTITLE="TEMPLATESUBTITLE";
  include("$DOCUMENT_ROOT/includes/header.inc.php");
?>

<!-- BEGIN main content -->

<H2><?php echo "$TITLE"; ?></H2>

<P>The ProteomeXchange ProteomeCentral server has two main components, the front-facing dataset browsing interface and the back-end dataset management/announcement system. The front-facing dataset browsing interface is largely self-explanatory and is accessible to a web browser at <a href="http://proteomecentral.proteomexchange.org/">http://proteomecentral.proteomexchange.org/</a>. The back-end dataset management/announcement system is used as a web service by automated software rather than interactively via a web browser. This page provides documentation to this web service.<P>
<P>The primary workflow for registering datasets via ProteomeXchange is as follows:
<UL>
<LI> The handling repository requests a ProteomeXchange identifier via the ID service.
<LI> The handling repository coordinates with the journal to see the manuscript describing the dataset and the results therefrom through the journal review process. This step may sometimes be skipped for datasets not associated with an article or associated with an already-published article.
<LI> The handling repository creates an announcement ProteomeXchange XML document and sends it to ProteomeXchange submission service.
</UL>
<h3>ProteomeXchange service instances</h3> 
<table border="1">
<tr><td>Primary</td>
<td>Primary service that should be used by all repositories:<BR>
<b>http://proteomecentral.proteomexchange.org/cgi/Dataset</b>
</td></tr>
<tr><td>Beta</td>
<td>For testing new unreleased code in the service as appropriate:<BR>
<b>http://proteomecentral.proteomexchange.org/beta/cgi/Dataset</b>
</td></tr>
<tr><td>Backup</td>
<td>If the production code is failing due to recently-added features, the backup area contains a previous checkpoint of known-stable code. All handling repositories should implement a strategy to fail over to this backup area if they are unable to use the production code area and unable to wait for a fix.<BR>
<b>http://proteomecentral.proteomexchange.org/backup/cgi/Dataset</b>
</td></tr>
</table>

<P>Parameters for the Dataset service are described below. It is recommended that parameters be passed to the service via the HTTP POST protocol. See at the bottom for a sample Perl and Java code implementation of communication with the service:

<h3>Service Parameters</h3>
<P>All these parameters are case sensitive

<table border="1">
<tr><td>
PXPartner</td><td>Username of the ProteomeXchange partner that is acting as the hosting repository for a dataset. This name is assigned by ProteomeXchange. A value of “TestRepo” may be used for testing.
</td></tr>
<tr><td>
authentication</td><td>The authentication string/password for the specified PXPartner. Authentication strings are provided upon request to prospective ProteomeXchange partners.
</td></tr>
<tr><td>
method</td><td>The desired method call for the invocation of the service. This service offers several different methods, which are described in the next table below
</td></tr>
<tr><td>
test</td><td>If set to “true” or “yes”, then all actions occur in the parallel test area/database, which does not share entries with the production database. The general use of the test flag is to request an ID with test set to true, and then submit a dataset using that furnished accession with test still set to true. A production accession number cannot be submitted in test mode, since it does not exist in the test database.
</td></tr>
<tr><td>
verbose</td><td>This parameter is intended to control the verbosity level of the response. At the present time, this really has no effect and all responses are fairly verbose in the INFO fields. See documentation for the service responses below.
</td></tr>
<tr><td>
ProteomeXchangeXML</td><td>This field specifies MIME-encoded XML document that is to be submitted to the service. It is encoded as if being supplied to an HTML file widget. See sample code on how to do this programmatically.
</td></tr>
<tr><td>
noEmailBroadcast</td><td>If set to “true” or “yes”, the normal email/RSS broadcast that accompanies email submission is suppressed. This may be useful for extensive testing where repeated emails may become tiresome to developments, or in cases where many production submissions need to be updated trivially to support new ProteomeXchange features (such as “lab head”) without a desired email for each one.
</td></tr>
<tr><td>
noDatabaseUpdate</td><td>If set to “true” or “yes”, then all code will be executed until the last moment when a database record would be written or updated. Instead the service ends there with a note that everything was successful or unsuccessful. This also serves as another type of test mode that can act on the production database without actually making any changes to it.
</td></tr>
<tr><td>
reprocessed</td><td>This parameter is only used when requesting new identifiers to signify that the identifier is for a reprocessed dataset. Most repositories are not registered to submit reprocessed datasets.
</td></tr>
</table>

<h3>Available methods</h3>

<table border="1">
<tr><td>
serverStatus</td><td>A simple call that returns SUCCESS if the ProteomeCentral service is alive and operating normally as far as it is aware.
</td></tr>
<tr><td>
testAuthorization</td><td>Requires parameters PXPartner and authentication, and returns SUCCESS if the supplied credentials are valid such that more complex options could take place.
</td></tr>
<tr><td>
requestID</td><td>Requires parameters PXPartner and authentication, and returns SUCCESS and a ProteomeXchange accession number if credentials are valid. If the test parameter is set to true or the authorized user is jailed in test mode, then the supplied access will be an accession from the test database instead of the production database. If the reprocessed parameter is true, then an RPXD accession is furnished for reprocessed datasets.
</td></tr>
<tr><td>
submitDataset</td><td>This method requires that a MIME-encoded XML document be provided via the ProteomeXchangeXML parameter in addition to the proper credentials. If the XML is valid and all checks are passed, the dataset is written to the database, is available on the web site, and an email/RSS announcement is sent.
</td></tr>
<tr><td>
validateXML</td><td>This is similar to submitXML, except that the uploaded XML is validated for correctness, both at the structural schema level as well as the semantic level. If there are any problems with the XML, they are listed in the INFO fields. Severe schema problems will cause an error, but minor semantic issues merely generate warning messages and the validation may return SUCCESS. A return value of SUCCESS does not therefore mean that the file is fully valid, merely that the validation completed successfully and problems were successfully reported.
</td></tr>
</table>

<h3>Interacting with the Service</h3>

<P>There is a <a href="../Dataset.html">test form</a> that can be used to interact with the service.

<P>But most likely you will want to interact with the service programmatically. Here are a few examples:

<UL>
<LI> <a href="https://github.com/proteomexchange/proteomecentral/tree/master/lib/test/simplestValidateXML.pl">Simplest example</a> of Perl code using the service to validate a ProteomeXchange XML file
<LI> <a href="https://github.com/proteomexchange/proteomecentral/tree/master/lib/java/px-xml-validator/PxXmlValidator.java">Simplest example</a> of Java code using the service to validate a ProteomeXchange XML file
<LI> <a href="https://github.com/proteomexchange/proteomecentral/tree/master/lib/test/testDatasetInterface.pl">Simple Perl example</a> of testing and using the service
</UL>


<!-- END main content -->

<?php
  include("$DOCUMENT_ROOT/includes/footer.inc.php");
?>
</html>
