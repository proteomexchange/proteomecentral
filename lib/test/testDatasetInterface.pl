#!/usr/local/bin/perl -w

use strict;
use warnings;

use FindBin;
use LWP::UserAgent;
use HTTP::Request::Common;

use lib "$FindBin::Bin/../perl";

main();
exit;

###############################################################################
# main
###############################################################################
sub main {

  unless ($ARGV[0]) {
    print "Usage: testDatasetInterface.pl <command> <command> <command>\n";
    print " e.g.: testDatasetInterface serverStatus\n";
    print " Supported commands:\n";
    print "   serverStatus         Test to see if the remote server is alive and functioning\n";
    print "   testAuthorization    Test to see if the supplied credentials will validate\n";
    print "   requestID            Request a new ProteomeXchange identifier for a new dataset\n";
    print "   requestRID           Request a new ProteomeXchange identifier for a reprocessed dataset\n";
    print "   submitDataset=file   Submit a the PX XML file specified to the system\n";
    print "   validateXML=file     Send and validate the specified PX XML file\n";
    print "\n";
    exit;
  }

  my @authParameters = ( PXPartner => 'TestRepo', authentication => 'foon8000', test => 'yes' );
  my $url = 'http://proteomecentral.proteomexchange.org/devED/cgi/Dataset';

  foreach my $arg ( @ARGV ) {
    print "==============================================================\n";
    if ($arg eq 'serverStatus' || $arg eq 'testAuthorization' || $arg eq 'requestID' || $arg eq 'requestRID') {
      print "INFO: Processing argument: $arg\n";
      my $userAgent = LWP::UserAgent->new();

      #### Hack for testing a request for a reprocessed ID
      my @additionalParameters = ();
      if ($arg eq 'requestRID') {
	$arg = 'requestID';
	@additionalParameters = ( reprocessed => 'true', verbose => 'true' );
      }

      my $response = $userAgent->request(
        POST $url,
        [method => $arg, @authParameters, @additionalParameters],
      );

      if ($response->is_success) {
	print "** Response is:\n";
        print $response->decoded_content();
      } else {
	print "** ERROR: Response is:\n";
        print STDERR $response->status_line, "\n";
      }

    #### Or if the command is one that sends a file
    } elsif ($arg =~ /^(submitDataset)=(\S+)$/ || $arg =~ /^(validateXML)=(\S+)$/) {
      my $command = $1;
      my $filename = $2;
      unless (-e $filename) {
	die("ERROR: Filename $filename not found");
      }
      print "INFO: Processing argument: $arg\n";
      my $userAgent = LWP::UserAgent->new();

      my $response = $userAgent->request(
        POST $url,
        Content_Type => 'multipart/form-data',
        Content => [ ProteomeXchangeXML => [ $filename ], method => $command, @authParameters],
      );

      if ($response->is_success) {
	print "** Response is:\n";
        print $response->decoded_content();
      } else {
	print "** ERROR: Response is:\n";
        print STDERR $response->status_line, "\n";
      }


    } else {
      print "ERROR: Unsupported argument: $arg\n";
    }
  }

  exit;

}

