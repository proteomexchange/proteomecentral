#!/usr/local/bin/perl

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../perl";

use ProteomeXchange::Configuration qw( %CONFIG );

main();
exit;

###############################################################################
# main
###############################################################################
sub main {

  print "mode=$CONFIG{mode}\n";
  print "DB_userName=$CONFIG{DB_userName}\n";

}

