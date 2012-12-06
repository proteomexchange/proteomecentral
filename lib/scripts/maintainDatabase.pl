#!/usr/local/bin/perl -w

use strict;

use lib "../perl";
use ProteomeXchange::Database;

my $command = shift;

main();
exit;

###############################################################################
# main
###############################################################################
sub main {

  unless ($command) {
    print "maintainDatabase.pl <command>\n";
    print "  Supported commands: TEST, CREATE, DROP\n\n";
    return(0);
  }

  my $db = new ProteomeXchange::Database;
  die("ERROR: Unable to connect to database") unless ($db->getStatus eq 'connected');

  if (uc($command) eq 'TEST') {
    print "Connected to database\n";
    return(1);

  } elsif (uc($command) eq 'CREATE') {
    print "Creating database tables...\n";
    $db->createTables();
    return(1);

  } elsif (uc($command) eq 'DROP') {
    print "DROP is a dangerous command! It will destroy all the tables.\n";
    print "If you really want to do this, use command DROP_YES\n";
    return(1);

  } elsif (uc($command) eq 'DROP_YES') {
    print "Dropping database tables...\n";
    $db->dropTables();
    return(1);

  } elsif (uc($command) eq 'INSERT') {
    print "Inserting a row...\n";
    $db->testInsert();
    return(1);

  } elsif (uc($command) eq 'SELECT') {
    print "Selecting rows...\n";
    $db->testSelect();
    return(1);

  } else {
    print "ERROR: Unrecognized maintenance command '$command'\n";
    return(0);
  }

  return(0);

}

