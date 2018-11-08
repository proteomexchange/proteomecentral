#!/usr/local/bin/perl -w

use strict;
use Data::Dumper;

use FindBin;
use lib "$FindBin::Bin/../perl";

use ProteomeXchange::Configuration qw( %CONFIG );
use ProteomeXchange::PubMedFetcher;

my $pubMedID = shift;
unless ($pubMedID) {
  print "Usage: ./testPubMedFetcher.pl\n";
  print " e.g.: ./testDatasetParser.pl 27453469\n";
  exit;
}

my $fetcher = new ProteomeXchange::PubMedFetcher; 
$! = 1;

my $response = $fetcher->getArticleRef(PubMedID=>$pubMedID,verbose=>2);

print "\n";
print Dumper($response);




