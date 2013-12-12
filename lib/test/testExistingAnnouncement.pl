#!/usr/local/bin/perl -w

use strict;
use Data::Dumper;

use FindBin;
use lib "$FindBin::Bin/../perl";

use ProteomeXchange::Dataset;

my $file = shift;
unless ($file) {
  print "Usage: ./testExistingAnnouncement.pl FILENAME\n";
  print " e.g.: ./testExistingAnnouncement.pl PXDT000037.xml\n";
  print " e.g.: ./testExistingAnnouncement.pl /net/dblocal/wwwspecial/proteomecentral/var/submissions/testing/Submission_2013-01-15_08:35:30.xml\n";
  exit;
}

unless (-e $file) {
  print "ERROR: Unable to find file '$file'\n";
  exit;
}

my $dataset = new ProteomeXchange::Dataset;
my $response = $dataset->processAnnouncement(
  params => { test=>'yes',PXPartner=>'TestRepo' },
  method => 'validateXML',
  path => 'none',
  response => { seed => 1 },
  uploadFilename => $file,
  noDatabaseUpdate => 0,
  noEmail => 1,
);

delete($response->{seed});
delete($response->{dataset});

use Data::Dumper;
print Dumper($response);

exit;

