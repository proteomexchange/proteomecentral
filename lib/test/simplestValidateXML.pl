#!/usr/local/bin/perl

use strict;
use warnings;

use LWP::UserAgent;
use HTTP::Request::Common;

my $filename = shift or die("ERROR Must supply 1 argument which is file to validate");
die("ERROR: Filename $filename not found") unless (-e $filename);

my @authParameters = ( PXPartner => 'TestRepo', authentication => 'XXXX', test => 'yes' );
my $url = 'http://proteomecentral.proteomexchange.org/beta/cgi/Dataset';

my $userAgent = LWP::UserAgent->new();

my $response = $userAgent->request(
  POST $url,
  Content_Type => 'multipart/form-data',
  Content => [ ProteomeXchangeXML => [ $filename ], method => 'validateXML', @authParameters],
);

if ($response->is_success) {
  print "** Response is:\n";
  print $response->decoded_content();
} else {
  print "** ERROR: Response is:\n";
  print STDERR $response->status_line, "\n";
}

