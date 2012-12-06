#!/usr/local/bin/perl -w

use strict;

use lib "../perl";
use ProteomeXchange::DBConnector;

main();
exit;

###############################################################################
# main
###############################################################################
sub main {

  my $db = new ProteomeXchange::DBConnector;
  $db->connect();
  print "Success!\n";

}

