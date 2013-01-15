#!/usr/local/bin/perl -w

use strict;

use Data::Dumper;
use FindBin;
use lib "$FindBin::Bin/../perl";
use ProteomeXchange::DatasetParser;
my $file = shift;
my $parser = new ProteomeXchange::DatasetParser; 
$! = 1;

my $response;
$response->{result} = "SUCCESS";
$response->{message} = "Parsed";
my @tmp = ('Initialize');
$response->{info} = \@tmp;

my $result = $parser -> parse (uploadFilename =>$file,
  response => $response, path => '');

print Dumper(%$result);

#foreach my $key (keys %$response){
#  if ( isa($response->{$key},'HASH')){
#    print "$key\n";
#    foreach my $key2(keys %{$response->{$key}}){
#     print "$key2 -> $response->{$key}\n";
#   }
# }else{
#     print "$key -> $response->{$key}\n";
# }
#} 



