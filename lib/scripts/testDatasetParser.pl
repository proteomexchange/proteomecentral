#!/usr/local/bin/perl -w

use strict;
#use UNIVERSAL 'isa';
use Data::Dumper;
use FindBin;
use lib "$FindBin::Bin/../perl";
use ProteomeXchange::DatasetParser_z;
my $file = shift;
my $parser = new ProteomeXchange::DatasetParser_z; 
my $response = $parser -> parse (uploadFilename =>$file);

print Dumper(%$response);
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



