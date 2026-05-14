#!/bin/env perl

use strict;
use warnings;

use Data::Dumper;

use FindBin;
use lib "$FindBin::Bin/../perl";

use ProteomeXchange::Configuration qw( %CONFIG );
use ProteomeXchange::DatasetParser;

my $file = shift;
unless ($file) {
  print "Usage: ./testDatasetParser.pl FILENAME\n";
  print " e.g.: ./testDatasetParser.pl $CONFIG{basePath}/var/submissions/testing/Submission_2013-01-15_08:35:30.xml\n";
  exit(10);
}

unless (-e $file) {
  print "ERROR: Unable to find file '$file'\n";
  exit;
}

my $parser = new ProteomeXchange::DatasetParser; 
my $result;
my $useProxiSpecificParser = 1;

#### If selected, use the new PROXI conversion parser
if ( $useProxiSpecificParser ) {
  $result = $parser->proxiParse(filename =>$file);

#### Else use the old style custom parser
} else  {
  my $response = {};
  my $result = $parser -> parse (
    filename =>$file,
    response => $response,
    path => ''
  );
}

print Dumper($result->{proxiDataset});
exit(0);

#### Some code to pull out and print from information from the 
my $ProteomeXchangeDataset = $result->{dataset}->{subelement_by_name}->{ProteomeXchangeDataset};
my $DatasetIdentifierList = $ProteomeXchangeDataset->{subelement_by_name}->{DatasetIdentifierList}->{subelements};
print Dumper($DatasetIdentifierList);

foreach my $identifier ( @{$DatasetIdentifierList} ) {
  my $name = $identifier->{DatasetIdentifier}->{subelement_by_name}->{cvParam}->{attributes}->{name};
  my $value = $identifier->{DatasetIdentifier}->{subelement_by_name}->{cvParam}->{attributes}->{value};
  print "$name=$value\n";
}
