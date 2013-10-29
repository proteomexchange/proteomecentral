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
    print "Usage: testDatasetInterface.pl\n";
    print " e.g.: testDatasetInterface serverStatus\n\n";
    exit;
  }

  my @authParameters = ( PXPartner => 'TestRepo', authentication => '', test => 'yes' );
  my $url = 'http://proteomecentral.proteomexchange.org/backup/cgi/Dataset';

  foreach my $arg ( @ARGV ) {
    print "==============================================================\n";
    if ($arg eq 'serverStatus' || $arg eq 'testAuthorization' || $arg eq 'requestID') {
      print "INFO: Processing argument: $arg\n";
      my $userAgent = LWP::UserAgent->new();

      my $response = $userAgent->request(
        POST $url,
        [method => $arg, @authParameters],
      );

      if ($response->is_success) {
	print "** Response is:\n";
        print $response->decoded_content();
      } else {
	print "** ERROR: Response is:\n";
        print STDERR $response->status_line, "\n";
      }

    } elsif ($arg =~ /^submitDataset=(\S+)$/) {
      my $filename = $1;
      unless (-e $filename) {
	die("ERROR: Filename $filename not found");
      }
      print "INFO: Processing argument: $arg\n";
      my $userAgent = LWP::UserAgent->new();

      my $response = $userAgent->request(
        POST $url,
        Content_Type => 'multipart/form-data',
        Content => [ ProteomeXchangeXML => [ $filename ], method => 'submitDataset', @authParameters],
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

