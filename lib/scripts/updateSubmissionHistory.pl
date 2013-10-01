#!/usr/local/bin/perl -w

use strict;
use FindBin;
use Data::Dumper;

use lib "$FindBin::Bin/../perl";

use ProteomeXchange::Database;
use ProteomeXchange::DatasetParser;

my $db;
my $command = shift;

main();
exit;

###############################################################################
# main
###############################################################################
sub main {

  unless ($command) {
    print "updateSubmissionHistory.pl <command>\n";
    print "  Supported commands: TEST, UPDATE\n\n";
    return(0);
  }

  $db = new ProteomeXchange::Database;
  die("ERROR: Unable to connect to database") unless ($db->getStatus eq 'connected');

  if (uc($command) eq 'TEST') {
    print "Examining the submission history\n";
    updateSubmissionHistory(test=>1);
    return(1);

  } elsif (uc($command) eq 'UPDATE') {
    updateSubmissionHistory(test=>0);
    return(1);

  } else {
    print "ERROR: Unrecognized command '$command'\n";
    return(0);
  }

  return(0);

}


###############################################################################
# updateSubmissionHistory
###############################################################################
sub updateSubmissionHistory {
  my %args = @_;
  my $SUB_NAME = 'updateSubmissionHistory';

  #### Decode the argument list
  my $test = $args{'test'} || 0;
  my $tableName = 'datasetHistory';

  my $submissionsDirectory = "/net/dblocal/wwwspecial/proteomecentral/var/submissions";

  #### Get the file listing of submission files
  my @files = getDirListing(directory=>$submissionsDirectory);

  my %submissions;

  foreach my $file ( @files ) {
    if ($file =~ /^Submission_(.+)\.xml$/) {
      my $timestamp = $1;
      print "Examining $file\n";
      my $fileSize = ( -s "$submissionsDirectory/$file" );
      print "  File size: $fileSize\n";
      if (-z "$submissionsDirectory/$file" ) {
	print "  File is zero length. Skipping.\n";
	next;
      }

      my $parser = new ProteomeXchange::DatasetParser; 
      my $response = $parser -> parse (uploadFilename =>"$submissionsDirectory/$file");
      #print Dumper($response);
      #exit;

      my $identifier = $response->{dataset}->{identifier};
      if ($identifier =~ /PDX/) {
	print "  ERROR: Correcting $identifier to PXD (i.e. PDX -> PXD).\n";
	$identifier =~ s/PDX/PXD/;
      }
      print "  identifier = $identifier  timestamp = $timestamp\n";
      $submissions{byIdentifier}->{$identifier}->{byTimestamp}->{$timestamp} = $response;
      #exit;

    } else {
      print "  File is not a submissions xml file. Skipping file $file\n";
    }
  }

  #### Now summarize by dataset
  print "=============================\n";
  print "==== Summary by dataset =====\n";
  print "=============================\n";
  my @identifiers = sort(keys(%{$submissions{byIdentifier}}));
  foreach my $identifier ( @identifiers ) {
    print "$identifier:\n";
    my @timestamps = sort(keys(%{$submissions{byIdentifier}->{$identifier}->{byTimestamp}}));
    foreach my $timestamp ( @timestamps ) {
      my $dataset = $submissions{byIdentifier}->{$identifier}->{byTimestamp}->{$timestamp}->{dataset};
      my $description = $dataset->{description} || '???';
      my $changeLogEntry = $dataset->{changeLogEntry} || '???';
      my $tmp = substr($changeLogEntry,0,50);
      print "  $timestamp  $tmp\n";
    }
  }


  #### Get all current data from the main table in order to write it to the history table
  print "================================================\n";
  print "==== Get and iterate through history table =====\n";
  print "================================================\n";

  my $sql = "SELECT dataset_id,datasetIdentifier,identifierVersion,isLatestVersion,PXPartner,status,primarySubmitter,title,species,instrument,publication,keywordList,announcementXML,identifierDate,submissionDate,revisionDate FROM dataset";
  my @rows = $db->selectSeveralColumns($sql);

  my $nRows = scalar(@rows);
  if (@rows) {
    print "Successfully selected $nRows rows\n";
  } else {
    print "ERROR: Failed to get rows from dataset table\n";
    return;
  }

  #### FIXME FIXME  ADD labHead !!!!!!!!!!!!!!!!!!!!1

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
      dataset_id => $dataset_id,
      datasetIdentifier => $datasetIdentifier,
      identifierVersion => $iVersion,
      isLatestVersion => 'N',
      PXPartner => $PXPartner,
      status => 'ID requested',
      identifierDate => $identifierDate,
    );

    #### Insert the new record
    my $datasetHistory_id = $db->updateOrInsertRow(
      insert => 1,
      table_name => $tableName,
      rowdata_ref => \%rowdata,
      return_PK => 1,
      testonly => 0,
      verbose => 1,
    );

    $iVersion++;

    #### Iterate over all file submissions for this dataset
    my @timestamps = sort(keys(%{$submissions{byIdentifier}->{$datasetIdentifier}->{byTimestamp}}));
    foreach my $timestamp ( @timestamps ) {
      my $dataset = $submissions{byIdentifier}->{$datasetIdentifier}->{byTimestamp}->{$timestamp}->{dataset};
      my $description = $dataset->{description} || '???';

      my $changeLogEntry = $dataset->{changeLogEntry} || '';
      $changeLogEntry = substr($changeLogEntry,0,255);

      my $timestampStr = $timestamp;
      $timestampStr =~ s/\_/ /;

      $originalSubmissionDate = $timestampStr if ($iVersion == 1);

      $revisionDate = 'NULL';
      $revisionDate = $timestampStr if ($iVersion > 1);

      $publication = $dataset->{publication} || '???';

      unless ($changeLogEntry) {
	$changeLogEntry = 'NULL' if ($iVersion < 2);
	$changeLogEntry = 'missing' if ($iVersion > 1);
      }

      #### Set the row values
      %rowdata = (
        dataset_id => $dataset_id,
        datasetIdentifier => $datasetIdentifier,
        identifierVersion => $iVersion,
        isLatestVersion => 'N',
        PXPartner => $PXPartner,
        status => 'announced',
        primarySubmitter => $primarySubmitter,
        labHead => 'NULL',
        title => $title,
        species => $species,
        instrument => $instrument,
        publication => $publication,
        keywordList => $keywordList,
        announcementXML => $announcementXML,
        identifierDate => $identifierDate,
        submissionDate => $originalSubmissionDate,
        revisionDate => $revisionDate,
        changeLogEntry => $changeLogEntry,
      );

      #### Insert the new record
      $datasetHistory_id = $db->updateOrInsertRow(
        insert => 1,
        table_name => $tableName,
        rowdata_ref => \%rowdata,
        return_PK => 1,
        testonly => 0,
        verbose => 1,
      );

      $iVersion++;

    }

    #### Set the row values
    %rowdata = (
      isLatestVersion => 'Y',
    );

    #### Update the last record with being the latest version
    my $result = $db->updateOrInsertRow(
      update => 1,
      PK => 'datasetHistory_id',
      PK_value => $datasetHistory_id,
      table_name => $tableName,
      rowdata_ref => \%rowdata,
      testonly => 0,
      verbose => 1,
    );

  }


  return;

}


###############################################################################
# getDirListing
###############################################################################
sub getDirListing {
  my %args = @_;
  my $SUB_NAME = 'getDirListing';

  #### Decode the argument list
  my $dir = $args{'directory'} || die "[$SUB_NAME] ERROR: directory not passed";
  my $exclude_dot_files = $args{'exclude_dot_files'} || 0;

  #### Open the directory and get the files (except . and ..)
  opendir(DIR, $dir) || die "[$SUB_NAME] Cannot open $dir: $!";
  my @files = grep (!/^\.{1,2}$/, readdir(DIR));
  closedir(DIR);

  #### Remove the dot files if we don't want them
  if ($exclude_dot_files) {
    @files = grep (!/^\./,@files);
  }

  #### Always sort the files
  @files = sort(@files);

  return @files;
}

