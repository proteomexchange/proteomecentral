#!/usr/local/bin/perl -w

use strict;
use Data::Dumper;
use FindBin;
use lib "$FindBin::Bin/../perl";
use ProteomeXchange::DatasetParser;

my $file = shift;
unless ($file) {
  print "Usage: ./testExistingAnnouncement.pl FILENAME\n";
  print " e.g.: ./testExistingAnnouncement.pl /net/dblocal/wwwspecial/proteomecentral/var/submissions/testing/Submission_2013-01-15_08:35:30.xml\n";
  exit;
}

unless (-e $file) {
  print "ERROR: Unable to find file '$file'\n";
  exit;
}

my $response = submitAnnouncement(
  params => {test => 1,PXPartner => 'PRIDE'},
  response => {seed => 1},
  uploadFilename => $file,
);

delete($response->{seed});
delete($response->{dataset});

use Data::Dumper;
print Dumper($response);
exit;



###############################################################################
# submitAnnouncement: Submit an announcement XML to ProteomeCentral
###############################################################################
sub submitAnnouncement {
  my %args = @_;
  my $SUB_NAME = 'submitAnnouncement';

  #### Decode the argument list
  my $params = $args{'params'};
  my $response = $args{'response'};
  my $uploadFilename = $args{'uploadFilename'};

  my $test = $params->{test};
  my $path = '/local/wwwspecial/proteomecentral/var/submissions/';
  $path .= "testing/" if ($test && ($test =~ /yes/i || $test =~ /true/i));
  $path = '' if ($uploadFilename =~ /^\//);

  $response->{result} = "ERROR";
  $response->{message} = "Unable to process announcement: Unknown error";
  push(@{$response->{info}},"File has been uploaded. Begin processing it");

  if ( -f "$path$uploadFilename" ) {
    if (open(INFILE,"$path$uploadFilename")) {
      my $nLines = 0;
      my $info;
      while ($nLines < 50) {
	my $line = <INFILE>;
	if ($line && $line =~ /\<\?xml/) {
	  push(@{$response->{info}},"File does appear to be XML");
	  $info->{isXML} = 'passed';
	}
	if ($line && $line =~ /SchemaLocation=\"(.+?)\"/) {
	  if ($1 eq 'proteomeXchange-draft-07.xsd' || $1 eq 'proteomeXchange-1.1.0.xsd') {
	    push(@{$response->{info}},"File has an acceptable XSD $1");
	    $info->{hasRightXSD} = 'passed';
	  } else {
	    $response->{result} = "ERROR";
	    $response->{message} = "File has unexpected XSD '$1'. Cannot process this file. Sorry.";
	    push(@{$response->{info}},$response->{message});
	    $info->{hasRightXSD} = 'failed';
	  }
	}
	$nLines++;
      }
      close(INFILE);
      
      if ($info->{isXML} && $info->{isXML} eq 'passed' &&
          $info->{hasRightXSD} && $info->{hasRightXSD} eq 'passed') {

	push(@{$response->{info}},"Validating XML...");
	my @result = `export LD_LIBRARY_PATH=/tools/src/Xerces/xerces-c-src_2_7_0/lib; /tools/src/Xerces/xerces-c-src_2_7_0/bin/SAX2Count -v=always $path$uploadFilename 2>&1`;

	my $nLines = scalar(@result);

	#### If the file is valid XML
	if ($nLines == 1 && $result[0] =~ /elems,/) {
	  push(@{$response->{info}},"Submitted XML is valid.");

	  my $parser = new ProteomeXchange::DatasetParser;
	  $parser -> parse ('uploadFilename' => $uploadFilename, 'response' => $response, 'path' => $path);
	  my $result = $response->{dataset};

	  ### If the PXPartner does not match the one in XML file, report an error
	  if ($params->{PXPartner} ne $result->{PXPartner} ){
	    $response->{result} = "ERROR";
	    $response->{message} = "PXPartner in input, $params->{PXPartner}, and in xml, $result->{PXPartner}, does not match.";

	  ### Verify the identifier
	  } elsif ($response->{dataset}->{identifier} !~ /^PXD\d\d\d\d\d\d/ ){
	    $response->{result} = "ERROR";
	    $response->{message} = "Identifier $response->{dataset}->{identifier} does not match format PXDnnnnnn";

	  #### Else everything is okay, so record the result and email the announcement
	  } else {
	    push(@{$response->{info}},"Ready to update database record");
	    #$self -> updateRecord ('result' => $result, 'response' => $response, 'test' => $params->{test});
	    $response->{result} = 'Database update would be okay, but skipped for this test';
	    push(@{$response->{info}},"Update returned: $response->{result}");

	    if ( $response->{result} ne "ERROR" ) {
	      my @toRecipients;
	      my $testFlag = '';
	      my $testClause = '';
	      if ($params->{test} =~ /^[yt]/i) {
		$testFlag = ' (test only)';
		@toRecipients = (
				 'ProteomeXchange Test','proteomexchange-test@googlegroups.com',
				 );
		$testClause = '&test=yes';
	      } else {
		@toRecipients = (
				 'ProteomeXchange','proteomexchange@googlegroups.com',
				 );
	      }
	      my @ccRecipients = ();
	      my @bccRecipients = ();
	      my $identifier = $result->{identifier} || '??';
	      my $messageType = 'new' || 'revision to a';
	      my $modeClause = '&outputMode=XML';
	      my $description = $result->{description} || '???';
	      $description =~ s/[\r\n]//g;
	      push(@{$response->{info}},"Email would go out, but skipped for this test");
	      $response->{result} = "SUCCESS";
	      $response->{message} = "It appears that the message has been fully parsed and is valid";

	    }
	  }

	#### else the file does not validate against the schema. Report the error
	} else {
	  $response->{result} = "ERROR";
	  $response->{message} = "File does not validate against the schema. Cannot process this file. Sorry.";
	  foreach my $line ( @result ) {
	    chomp($line);
	    push(@{$response->{info}},$line);
	  }
	}

      } else {
	unless ($info->{isXML} && $info->{isXML} eq 'passed') {
	  $response->{message} = "The uploaded file does not appear to be proper XML. It is missing the expected preamble, at least.";
	}
	unless ($info->{hasRightXSD} && $info->{hasRightXSD} eq 'passed') {
	  $response->{message} = "The uploaded file does not appear to have the needed schema reference. Please check schema definition."
	    unless ($response->{message} =~ /XSD/);
	}
      }

    } else {
      $response->{message} = "Internal error. Unable to open stored file.";
    }

  } else {
    $response->{message} = "Internal error. Unable to find stored file.";
  }

  return($response);
}
