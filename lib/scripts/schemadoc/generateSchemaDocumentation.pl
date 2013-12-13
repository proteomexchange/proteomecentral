#!/usr/local/bin/perl -w

###############################################################################
# Program     : generateHTMLDocumentation.pl
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
# $Id$
#
# Description : This script reads an xsd and creates HTML documentation
#
###############################################################################


###############################################################################
   # Generic SBEAMS setup for all the needed modules and objects
###############################################################################
use strict;
use Getopt::Long;
use FindBin;
use XML::Xerces;
use Data::Dumper;

use xsdContentHandler;

use vars qw ($PROG_NAME $USAGE %OPTIONS $QUIET $VERBOSE $NICE_HTML $DEBUG $TESTONLY
            );


###############################################################################
# Set program name and usage banner for command like use
###############################################################################
$PROG_NAME = $FindBin::Script;
$USAGE = <<EOU;
Usage: $PROG_NAME [OPTIONS] mzML_inputfile
Options:
  --starting_element          Set the very top element to begin the documentation
  --verbose n                 Set verbosity level.  default is 1
  --quiet                     Set flag to print nothing at all except errors
  --nice                      Produce 'nice' html output
  --debug n                   Set debug flag
  --testonly                  If set, rows in the database are not changed or added

 e.g.: $PROG_NAME --verbose 1 tiny1.mzML0.93.xml
EOU

#### Process options
unless (GetOptions(\%OPTIONS,"verbose:s","quiet","nice","debug:s","testonly",
		   "starting_element:s","cvFile:s","examplesFile:s",
		   "cvMappingFile:s","notesFile:s","figuresMappingFile:s",
		   "referenced_xsds:s",
    )) {

    die "\n$USAGE";

}


$VERBOSE = $OPTIONS{"verbose"} || 1;
$QUIET = $OPTIONS{"quiet"} || 0;
$NICE_HTML = $OPTIONS{"nice"} || 0;
$DEBUG = $OPTIONS{"debug"} || 0;
$TESTONLY = $OPTIONS{"testonly"} || 0;

if ($DEBUG) {
    print "Options settings:\n";
    print "  VERBOSE = $VERBOSE\n";
    print "  QUIET = $QUIET\n";
    print "  NICE_HTML = $NICE_HTML\n";
    print "  DEBUG = $DEBUG\n";
    print "  TESTONLY = $TESTONLY\n";
}



###############################################################################
# Set Global Variables and execute main()
###############################################################################

main();
exit(0);



###############################################################################
# main: Main Function
###############################################################################
sub main {

  #### Check to see if there is an input file to work on
  unless ( $ARGV[0] ) {
    print "ERROR: No files specified\n";
    print $USAGE;
    return;
  }

  #### Process all files
  foreach my $file ( @ARGV ) {
    print "INFO: Processing file '$file'\n" unless ($QUIET);
    if ( -e $file ) {
      validateMzML(
        inputfile => $file,
        validate => $OPTIONS{validate},
        namespaces => $OPTIONS{namespaces},
        schemas => $OPTIONS{schemas},
        starting_element => $OPTIONS{starting_element},
      );

    } else {
      print "ERROR: File '$file' does not exist\n";
    }

  }

} # end main



#######################################################################
# validateMzML - uses SAX Content handler to parse mzML file
#######################################################################
sub validateMzML {
  my %args = @_;

  my $inputfile = $args{'inputfile'}
    or die("ERROR: inputfile not passed");

  #### Process parser options
  my $validate = $args{'validate'} || 'never';
  my $namespaces = $args{'namespaces'} || 1;
  my $schemas = $args{'schemas'} || 1;
  my $starting_element = $args{'starting_element'} || 'mzML';

  if (uc($validate) eq 'ALWAYS') {
    $validate = $XML::Xerces::SAX2XMLReader::Val_Always;
  } elsif (uc($validate) eq 'NEVER') {
    $validate = $XML::Xerces::SAX2XMLReader::Val_Never;
  } elsif (uc($validate) eq 'AUTO') {
    $validate = $XML::Xerces::SAX2XMLReader::Val_Auto;
  } else {
    die("Unknown value for -v: $validate\n$USAGE");
  }

  #### Set up the Xerces parser
  my $parser = XML::Xerces::XMLReaderFactory::createXMLReader();
  $parser->setFeature("http://xml.org/sax/features/namespaces", $namespaces);

  if ($validate eq $XML::Xerces::SAX2XMLReader::Val_Auto) {
    $parser->setFeature("http://xml.org/sax/features/validation", 1);
    $parser->setFeature("http://apache.org/xml/features/validation/dynamic",1);

  } elsif ($validate eq $XML::Xerces::SAX2XMLReader::Val_Never) {
    $parser->setFeature("http://xml.org/sax/features/validation", 0);

  } elsif ($validate eq $XML::Xerces::SAX2XMLReader::Val_Always) {
    $parser->setFeature("http://xml.org/sax/features/validation", 1);
    $parser->setFeature("http://apache.org/xml/features/validation/dynamic",0);
  }

  $parser->setFeature("http://apache.org/xml/features/validation/schema",
    $schemas);


  #### Create the error handler and content handler
  my $error_handler = XML::Xerces::PerlErrorHandler->new();
  $parser->setErrorHandler($error_handler);

  my $CONTENT_HANDLER = xsdContentHandler->new();
  $parser->setContentHandler($CONTENT_HANDLER);

  $CONTENT_HANDLER->setVerbosity($VERBOSE);
  $CONTENT_HANDLER->{counter} = 0;

  $CONTENT_HANDLER->{namespace} = '';
  $parser->parse(XML::Xerces::LocalFileInputSource->new($inputfile));
  print "\n" if ($VERBOSE);

  print "======================================================\n\n";

  if ($OPTIONS{referenced_xsds}) {
    $CONTENT_HANDLER->{namespace} = 'pf';
    $parser->parse(XML::Xerces::LocalFileInputSource->new($OPTIONS{referenced_xsds}));
  }

  my $examplesFile = $OPTIONS{examplesFile} || '';
  my @examplesFileList = split(/,/,$examplesFile);
  foreach my $file ( @examplesFileList ) {
    $CONTENT_HANDLER->readExamplesFile(input_file=>$file);
  }

  $CONTENT_HANDLER->readNotesFile(input_file=>$OPTIONS{notesFile});
  $CONTENT_HANDLER->readCvMappingFile(input_file=>$OPTIONS{cvMappingFile});
  $CONTENT_HANDLER->readControlledVocabularyFile(input_file=>$OPTIONS{cvFile});
  $CONTENT_HANDLER->readFiguresMappingFile(input_file=>$OPTIONS{figuresMappingFile});

  my $outputFile = $inputfile;
  $outputFile =~ s/\.xsd//;
  $outputFile .= ".html";

  open(OUTFILE,">$outputFile");
  printf OUTFILE "<html><head>\n";

  if ($NICE_HTML) {
      printf OUTFILE qq~
	  <style type="text/css">
	      body {  font-family: Helvetica, Arial, sans-serif; font-size: 9pt; background-color: #ffffff;}
	      table{  border: 1px solid black; border-collapse: collapse; }
	       th   {  border: 1px solid black; font-family: Helvetica, Arial, sans-serif; font-size: 9pt; font-weight: bold;
	       background-color: #dddddd;}
	       td   {  border: 1px solid black; font-family: Helvetica, Arial, sans-serif; font-size: 9pt; padding:3px; vertical-align:top;}
	       table.zero{  border: 0px ; border-collapse: collapse; }
	       td.zero {  border: 0px ; font-family: Helvetica, Arial, sans-serif; font-size: 9pt; padding:3px; vertical-align:top;}
	       form   {  font-family: Helvetica, Arial, sans-serif; font-size: 9pt}
	       pre    {  font-family: Courier New, Courier; font-size: 8pt}
	       h1   {  font-family: Helvetica, Arial, sans-serif; font-size: 14pt; font-weight: bold}
	       h2   {  font-family: Helvetica, Arial, sans-serif; font-size: 12pt; font-weight: bold;
		     padding: 5px;
		     border: 2px dotted black;
		       background-color: #ddddff;
		   }
	       h3   {  font-family: Helvetica, Arial, sans-serif; font-size: 12pt}
	       h4   {  font-family: AHelvetica, rial, sans-serif; font-size: 12pt}
	    </style>
		~;
  } else {
      printf OUTFILE qq~
	 <style type="text/css">
	body {  font-family: Helvetica, Arial, sans-serif; font-size: 9pt}
	th   {  font-family: Helvetica, Arial, sans-serif; font-size: 9pt; font-weight: bold;}
	td   {  font-family: Helvetica, Arial, sans-serif; font-size: 9pt;}
	form   {  font-family: Helvetica, Arial, sans-serif; font-size: 9pt}
	pre    {  font-family: Courier New, Courier; font-size: 8pt}
	h1   {  font-family: Helvetica, Arial, sans-serif; font-size: 14pt; font-weight: bold}
	h2   {  font-family: Helvetica, Arial, sans-serif; font-size: 12pt; font-weight: bold}
	h3   {  font-family: Helvetica, Arial, sans-serif; font-size: 12pt}
	h4   {  font-family: AHelvetica, rial, sans-serif; font-size: 12pt}
        </style>
      ~;
  }

  printf OUTFILE "</head>\n<body>\n";
  printf OUTFILE $CONTENT_HANDLER->generateDocumentation(starting_element=>$starting_element);
  printf OUTFILE "</body></html>\n";
  close(OUTFILE);

  #print Dumper([$CONTENT_HANDLER->{elements}->{activation}]);
  #print "\n";

  return(1);

}
