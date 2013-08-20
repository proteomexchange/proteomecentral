#!/usr/local/bin/perl -w

use strict;
use FindBin;
use Data::Dumper;

use lib "$FindBin::Bin/../perl";

use ProteomeXchange::Database;
use ProteomeXchange::DatasetParser;

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

  my $db = new ProteomeXchange::Database;
  die("ERROR: Unable to connect to database") unless ($db->getStatus eq 'connected');

  if (uc($command) eq 'TEST') {
    print "Examining the submission history\n";
    updateSubmissionHistory(test=>1);
    return(1);

  } elsif (uc($command) eq 'UPDATE') {
    print "This has not been implemented yet\n";
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
	$identifier =~ s/PXD/PDX/;
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

