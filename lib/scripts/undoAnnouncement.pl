#!/usr/local/bin/perl -w

use strict;
use FindBin;
use Data::Dumper;

use lib "$FindBin::Bin/../perl";

use ProteomeXchange::Database;
use ProteomeXchange::DatasetParser;

my $db;
my $identifier = shift;
my $command = shift;

main();
exit;

###############################################################################
# main
###############################################################################
sub main {

  unless ($identifier) {
    print "undoAnnouncement.pl PXDnnnnnn\n";
    return(0);
  }

  $db = new ProteomeXchange::Database;
  die("ERROR: Unable to connect to database") unless ($db->getStatus eq 'connected');

  undoAnnouncement(identifier=>$identifier);

  return(0);

}


###############################################################################
# undoAnnouncement
###############################################################################
sub undoAnnouncement {
  my %args = @_;
  my $SUB_NAME = 'undoAnnouncement';

  #### Decode the argument list
  my $identifier = $args{'identifier'} || 0;
  my $tableName = 'dataset';

  my $sql = "SELECT dataset_id,datasetIdentifier,identifierVersion,isLatestVersion,PXPartner,status,primarySubmitter,title,species,instrument,publication,keywordList,announcementXML,identifierDate,submissionDate,revisionDate FROM dataset WHERE datasetIdentifier = '$identifier'";
  my @rows = $db->selectSeveralColumns($sql);

  my $nRows = scalar(@rows);
  if (@rows) {
    print "INFO Successfully selected $nRows rows\n";
  } else {
    print "ERROR: Failed to specified dataset identifier '$identifier'\n";
    return;
  }

  foreach my $row ( @rows ) {
    my ( $dataset_id,$datasetIdentifier,$identifierVersion,$isLatestVersion,$PXPartner,$status,$primarySubmitter,$title,$species,$instrument,$publication,$keywordList,$announcementXML,$identifierDate,$submissionDate,$revisionDate ) = @{$row};

    print "** dataset_id = $dataset_id    datasetIdentifier = $datasetIdentifier\n";
    print "   identifierVersion = $identifierVersion   isLatestVersion = $isLatestVersion\n";
    print "   status = $status\n";
    print "   title = $title\n" if ($title);
    print "   identifierDate = $identifierDate\n" if ($identifierDate);
    print "   submissionDate = $submissionDate\n" if ($submissionDate);
    print "   revisionDate = $revisionDate\n" if ($revisionDate);

    my $iVersion = 0;
    my $originalSubmissionDate = 'NULL';

    #### Set the row values
    my %rowdata = (
      status => 'ID requested',
      revisionDate => 'CURRENT_TIMESTAMP',
    );

    my $testonly = 1;
    if ( $command && $command eq 'NO_TEST' ) {
      $testonly = 0;
    }

    #### Insert the new record
    my $datasetHistory_id = $db->updateOrInsertRow(
      update => 1,
      PK => 'dataset_id',
      PK_value => $dataset_id,
      table_name => $tableName,
      rowdata_ref => \%rowdata,
      testonly => $testonly,
      verbose => 1,
    );

  }

  if ( $command && $command eq 'NO_TEST' ) {
  } else {
    print "\n\nTESTING: That was a test. If you like what you see, the redo the command with an additional parameter NO_TEST\n";
  }

  return;

}

