package ProteomeXchange::Dataset;

###############################################################################
# Class       : ProteomeXchange::Dataset
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
#
# Description : This class is used to represent a dataset announcement in ProteomeXchange
#
###############################################################################

use strict;

use ProteomeXchange::Database;
use ProteomeXchange::DatasetParser;
use ProteomeXchange::EMailProcessor;
use vars qw($db);
$db = new ProteomeXchange::Database;

#my $TESTSUFFIX = "_newschema";
my $TESTSUFFIX = "_test";


###############################################################################
# Constructor
###############################################################################
sub new {
  my $self = shift;
  my %parameters = @_;

  my $class = ref($self) || $self;

  #### Create the object with any attributes if supplied
  $self = {
         dataset_id => $parameters{dataset_id},
         datasetIdentifier => $parameters{datasetIdentifier},
         PXPartner => $parameters{PXPartner},
         status => $parameters{status},
         primarySubmitter => $parameters{primarySubmitter},
         title => $parameters{title},
         identifierDate => $parameters{identifierDate},
         submissionDate => $parameters{submissionDate},
         revisionDate => $parameters{revisionDate},
				 password => $parameters{password},
				 announcementXML => $parameters{announcementXML},
         labHead => $parameters{labHead},
         datasetOrigin => $parameters{datasetOriginAccession},
	};

  bless $self => $class;

  return $self;
}


###############################################################################
# setDataset_id: Set attribute dataset_id
###############################################################################
sub setDataset_id {
  my $self = shift;
  $self->{dataset_id} = shift;
  return $self->{dataset_id};
}


###############################################################################
# getDataset_id: Get attribute dataset_id
###############################################################################
sub getDataset_id {
  my $self = shift;
  return $self->{dataset_id};
}


###############################################################################
# setDatasetIdentifier: Set attribute datasetIdentifier
###############################################################################
sub setDatasetIdentifier {
  my $self = shift;
  $self->{datasetIdentifier} = shift;
  return $self->{datasetIdentifier};
}


###############################################################################
# getDatasetIdentifier: Get attribute datasetIdentifier
###############################################################################
sub getDatasetIdentifier {
  my $self = shift;
  return $self->{datasetIdentifier};
}


###############################################################################
# setPXPartner: Set attribute PXPartner
###############################################################################
sub setPXPartner {
  my $self = shift;
  $self->{PXPartner} = shift;
  return $self->{PXPartner};
}


###############################################################################
# getPXPartner: Get attribute PXPartner
###############################################################################
sub getPXPartner {
  my $self = shift;
  return $self->{PXPartner};
}


###############################################################################
# setPassword: Set attribute password
###############################################################################
sub setPassword {
  my $self = shift;
  $self->{password} = shift;
  return $self->{password};
}


###############################################################################
# getPassword: Get attribute password
###############################################################################
sub getPassword {
  my $self = shift;
  return $self->{password};
}


###############################################################################
# setAnnouncementXML: Set attribute announcementXML
###############################################################################
sub setAnnouncementXML {
  my $self = shift;
  $self->{announcementXML} = shift;
  return $self->{announcementXML};
}


###############################################################################
# getAnnouncementXML: Get attribute announcementXML
###############################################################################
sub getAnnouncementXML {
  my $self = shift;
  return $self->{announcementXML};
}


###############################################################################
# setStatus: Set attribute status
###############################################################################
sub setStatus {
  my $self = shift;
  $self->{status} = shift;
  return $self->{status};
}


###############################################################################
# getStatus: Get attribute status
###############################################################################
sub getStatus {
  my $self = shift;
  return $self->{status};
}

###############################################################################
# updateRecord
###############################################################################
sub updateRecord{
  my $self = shift;
  my %args = @_;
  my $result = $args{result}; 
  my $response = $args{response};
  my $test = $args{test} || 'no';
  my $noDatabaseUpdate = $args{noDatabaseUpdate};

  $test = 'no' if (!defined($test));
  $noDatabaseUpdate = 0 if (!defined($noDatabaseUpdate));

  my $datasetidentifier = $result->{identifier};

  my $mainTableName = 'dataset';
  my $historyTableName = 'datasetHistory';
  if ($test && ($test =~ /yes/i || $test =~ /true/i)) {
    $test = "true";
    $mainTableName .= $TESTSUFFIX;
    $historyTableName .= $TESTSUFFIX;
  }


  #### Verify that we have a dataset identifier
  if ( ! $datasetidentifier ) {
     $response->{result} = "ERROR";
     $response->{message} = "datasetidentifier not parsed";
     return;
  }


  #### Set the revision and realanysis states
  my $isReanalysis = 0;
  my $isRevision = 0;
  $isReanalysis = 1 if ( $datasetidentifier =~ /^RP/ );
  $isRevision = 1 if ( $result->{revisionNumber} && $result->{revisionNumber} > 1 );


  #### Verify that the test mode and the identifier types are compatible
  if ( $test eq "true" && $datasetidentifier =~ /PXD/ ) {
    $response->{result} = "ERROR";
    $response->{message} = "The dataset identifier \"$datasetidentifier\" must be PXTnnnnnn not PXDnnnnnn if test=yes\n";
    return;
  }
  if ( $test ne "true" && $datasetidentifier =~ /PXT/ ) {
    $response->{result} = "ERROR";
    $response->{message} = "The dataset identifier \"$datasetidentifier\" must be PXDnnnnnn not PXTnnnnnn if test=false\n";
    return;
  }

  #### Verify that the ChangeLogEntry information is appropriate
  my $changeLogEntry = $result->{changeLogEntry};
  $response->{changeLogEntry} = $changeLogEntry;

  #### If this should be a new submission
  if ( $isRevision == 0 ) {
    if ($changeLogEntry) {
      $response->{result} = "ERROR";
      $response->{message} = "This submission is not a revision (revision number is not specified or less than 2 for \"$datasetidentifier\" and therefore should NOT have a ChangeLogEntry\n";
      return;
    } else {
      # good
    }
  #### Otherwise this should be a revision with a Changlog
  } else {
    if ( $changeLogEntry ) {
      # good
    } else {
      $response->{result} = "ERROR";
      $response->{message} = "There was already an announcement for this dataset, and thus, this submission is a revision, which must have a ChangeLogEntry. Yet it does not. Please add a ChangeLogEntry to make it clear how this record has been altered in this revised submission.";
      return;
    }
  }


  #### Query the information for the current record
  push(@{$response->{info}},"Checking current database records for '$datasetidentifier'");
  my $sql = "select dataset_id,SubmissionDate,RevisionDate,revisionNumber,reanalysisNumber from $historyTableName where datasetIdentifier='$datasetidentifier'";
  my @rows = $db->selectSeveralColumns($sql);
  my $nRows = scalar(@rows);


  #### If there's no row yet, then an ID needs to be requested first
  if (@rows == 0 ) {
    $response->{result} = "ERROR";
    $response->{message} ="no record found for identifier '$datasetidentifier'. Please request ID first.\n";
    return;
  }


  #### Record all the revisions we have already by reanalysis number if appropriate
  my ($dataset_id,$submissionDate,$revisionDate,$revisionNumber,$reanalysisNumber);
  my %revisionNumbersByReanalysis;
  foreach my $row ( @rows ) {
    ($dataset_id,$submissionDate,$revisionDate,$revisionNumber,$reanalysisNumber) = @{$row};
    $reanalysisNumber = 0 unless ( $reanalysisNumber );
    $revisionNumber = 0 unless ( defined($revisionNumber) );
    $revisionNumbersByReanalysis{$reanalysisNumber}->{$revisionNumber} = 1;
    push(@{$response->{info}},"Found history record: $dataset_id,$submissionDate,$revisionDate,$revisionNumber,$reanalysisNumber");
  }

  #### Compute the maximum revision numbers
  foreach my $iReanalysisNumber ( keys(%revisionNumbersByReanalysis) ) {
    foreach my $iRevisionNumber ( keys(%{$revisionNumbersByReanalysis{$iReanalysisNumber}}) ) {
      $revisionNumbersByReanalysis{$iReanalysisNumber}->{max} = 0 unless ($revisionNumbersByReanalysis{$iReanalysisNumber}->{max});
      $revisionNumbersByReanalysis{$iReanalysisNumber}->{max} = $iRevisionNumber if ( $iRevisionNumber > $revisionNumbersByReanalysis{$iReanalysisNumber}->{max} );
    }
  }


  #### If this is a re-analysis, check the number
  my $expectedRevisionNumber = -1;
  my $thisReanalysisNumber = -1;
  if ( $isReanalysis ) {
    $expectedRevisionNumber = 0;
    $thisReanalysisNumber = 0;
    if ( $result->{reanalysisNumber} && $result->{reanalysisNumber} =~ /^\s*\d+\s*$/ ) {
      $thisReanalysisNumber = $result->{reanalysisNumber};
    } else {
      $response->{result} = "ERROR";
      $response->{message} = "This dataset '$datasetidentifier' appears to be a reanalyzed datasets, but the reanalysisNumber '$result->{reanalysisNumber}' is not valid";
      return;
    }

  #### Else this is not a reanalysis
  } else {
    $expectedRevisionNumber = 1;
    $thisReanalysisNumber = 0;
  }

  #### if this is a reanalysis, check the revision
  if ( $isReanalysis ) {
    #### If there are already some revisions for this reanalysis, then set the expectation
    if ( exists($revisionNumbersByReanalysis{$thisReanalysisNumber}) ) {
      $expectedRevisionNumber = $revisionNumbersByReanalysis{$thisReanalysisNumber}->{max} + 1;
    #### Otherwise, there must be a revision number of 0 for the container
    } else {
      $expectedRevisionNumber = 0;
    }
  }

  #### Now check the revision number
  my $thisRevisionNumber = $result->{revisionNumber};
  $thisRevisionNumber = '' if (!defined($thisRevisionNumber));
  push(@{$response->{info}},"The revisionNumber in the document is listed as '$thisRevisionNumber'");
  if ( $expectedRevisionNumber > 1 && ! $thisRevisionNumber ) {
    $response->{result} = "ERROR";
    $response->{message} = "A submission for dataset '$datasetidentifier' already exists and a revision number '$expectedRevisionNumber' was expected, but none was provided. This is unexpected. Please check carefully and fix or report a server problem.";
    return;

  } elsif ( $isReanalysis == 0 && $isRevision == 0 && $thisRevisionNumber eq '' && $expectedRevisionNumber == 1 ) {
    push(@{$response->{info}},"For this new submission, the revision is implicitly set to 1");
    $thisRevisionNumber = 1;

  } elsif ( $isReanalysis && $thisRevisionNumber eq '' ) {
    $response->{result} = "ERROR";
    $response->{message} = "For reanalyses, revisionNumbers must always be specified, with 0 for the container. Please check carefully and fix or report a server problem.";
    return;

  } elsif ( $thisRevisionNumber == $expectedRevisionNumber ) {
    push(@{$response->{info}},"The revisionNumber in the document is as expected at $thisRevisionNumber");

  } else {
    $response->{result} = "ERROR";
    my $reanalysisMessage = "";
    my $reanalysisMessage2 = "";
    $reanalysisMessage = " (reanalysis $thisReanalysisNumber)" if ( $datasetidentifier =~ /RPX/ );
    $reanalysisMessage2 = " Note that container definitions are denoted with a revision number of 0." if ( $datasetidentifier =~ /RPX/ );
    $response->{message} = "The provided revision number for this document for '$datasetidentifier'$reanalysisMessage was expected to be '$expectedRevisionNumber' but was provided as '$thisRevisionNumber'. This is unexpected. Please check carefully and fix or report a server problem.$reanalysisMessage2";
    return;
  }


  #### Set the final revision and reanalysis
  $revisionNumber = $thisRevisionNumber;
  $reanalysisNumber = $thisReanalysisNumber;


  #### If there is a dataset origin, add it, else just insert NULL
  my $datasetOrigin = 'NULL';
  if ($result->{datasetOrigins}) {
    $datasetOrigin = '';
    foreach my $origin ( @{$result->{datasetOrigins}} ) {
      if ( $origin->{original} ) {
	$datasetOrigin .= "original;";
      } elsif ( $origin->{derived} ) {
	$datasetOrigin .= "$origin->{identifier},";
      } else {
	$datasetOrigin .= "???,";
      }
    }
    chop($datasetOrigin);
  }


  my %rowdata = (
    'primarySubmitter' => $result->{primarySubmitter}, 
    'title' => $result->{title},
    'revisionNumber' => $revisionNumber,
    'reanalysisNumber' => $reanalysisNumber,
    'isLatestRevision' => 'Y',
    'status' => 'announced',
    'instrument' => $result->{instrument},
    'publication' => $result->{publication},
    'species' => $result->{species},
    'keywordList' => $result->{keywordList},
    'announcementXML' => $result->{announcementXML},
    'labHead' => $result->{labHead},
    'datasetOrigin' => $datasetOrigin, 
  ); 

  #### If there is already a previously recorded submissionDate, then this is a revision
  if ( $submissionDate =~ /\d+/){ 
    $rowdata{revisionDate} = 'CURRENT_TIMESTAMP';

  #### Else this is a new submission
  } else{
     $rowdata{submissionDate} = 'CURRENT_TIMESTAMP' ; 
  }

  #### If we asked not to do the update, set to test_only and verbose
  my @testFlags = ();
  if ($noDatabaseUpdate && $noDatabaseUpdate !~ /no/i && $noDatabaseUpdate !~ /false/i) {
    push(@{$response->{info}},"Will pretend to update database, but won't really do it because noDatabaseUpdate=$noDatabaseUpdate.");
    @testFlags = ( testonly=>1 );
  }

  my $value = $db->updateOrInsertRow(
    update => 1,
    table_name => $mainTableName,
    rowdata_ref => \%rowdata,
    PK => 'dataset_id',
    PK_value => $dataset_id,
    @testFlags,
  );

  if ($value == 1 ) {
    $response->{result} = "Success";
    $response->{message} = "Database was updated. ";
    $response->{link} = "http://proteomecentral.proteomexchange.org/cgi/GetDataset?ID=$dataset_id&test=$test";

    #### Now add to the history table

    $rowdata{dataset_id} = $dataset_id;
    $rowdata{datasetIdentifier} = $datasetidentifier;
    $rowdata{changeLogEntry} = $changeLogEntry;

    $value = $db->updateOrInsertRow(
      insert => 1,
      table_name => $historyTableName,
      rowdata_ref => \%rowdata,
      @testFlags,
    );

    if ($value == 1 ) {
      $response->{result} = "Success";
      $response->{message} = "Database was updated. History table was updated.";
    } else {
      $response->{result} = "ERROR";
      $response->{message} = "ERROR: failed to update history table for record $datasetidentifier. $value";
    }

  } else {
    $response->{result} = "ERROR";
    $response->{message} = "ERROR: failed to update record $datasetidentifier. $value";
  }

  return $response;

}


###############################################################################
# createNewIdentifier
###############################################################################
sub createNewIdentifier {
  my $self = shift;
  my %args = @_;
  my $SUB_NAME = 'createNewIdentifier';

  #### Decode the argument list
  my $test = $args{'test'};
  my $response = $args{response};
  my $reprocessed = $args{reprocessed};

  my $mainTableName = 'dataset';
  my $historyTableName = 'datasetHistory';

  my $testPhrase = "";
  my $accessionTemplate = 'PXD000000';
  if ($test && ($test =~ /yes/i || $test =~ /true/i)) {
    $mainTableName .= $TESTSUFFIX;
    $historyTableName .= $TESTSUFFIX;
    $testPhrase = "Test ";
    $accessionTemplate = 'PXT000000';
  }

  #### Prepend R in front of PXD if this is a reprocessed dataset
  if ($reprocessed) {
    if ($reprocessed =~ /yes/i || $reprocessed =~ /true/i) {
      $accessionTemplate = 'R'.$accessionTemplate;
    } elsif ($reprocessed =~ /no/i && $reprocessed =~ /false/i) {
    } else {
      $response->{result} = "ERROR";
      $response->{message} = "Unrecognized value '$reprocessed' for reprocessed flag";
      return($response);
    }
  }

  $response->{result} = "ERROR";
  $response->{message} = "Unable to create a new ${testPhrase}identifier";

  #### Make sure we have the required information
  my $PXPartner = $self->getPXPartner();
  unless ($PXPartner) {
    $response->{result} = "ERROR";
    $response->{message} = "PXPartner not available";
    return($response);
  }

  #### Make sure we don't already have an identifier
  if ($self->getDataset_id() || $self->getDatasetIdentifier()) {
    $response->{result} = "ERROR";
    $response->{message} = "Dataset object already has an identifier. Cannot request a new one";


  #### Else create a new one
  } else {
    my $datasetIdentifier;

    #### Set database row fields
    my %rowdata = (
      PXPartner => $PXPartner,
      revisionNumber => 0,
      isLatestRevision => 'Y',
      status => 'ID requested',
      identifierDate => 'CURRENT_TIMESTAMP',
    );
    push(@{$response->{info}},"Preparing to request the next ID from table '$mainTableName' via testMode='$test'");

    if ( 0 ) {
      $response->{result} = "ERROR";
      $response->{message} = "DEBUGHALT: Halting right before the assignment of ID into $mainTableName with testMode=$test";
      return $response;
    }

    #### Insert the new record
    my $dataset_id = $db->updateOrInsertRow(
      insert => 1,
      table_name => $mainTableName,
      rowdata_ref => \%rowdata,
      return_PK => 1,
    );

    if ($dataset_id) {
      if ($dataset_id >=1 && $dataset_id < 1000000) {
				my $datasetIdentifier = substr($accessionTemplate,0,length($accessionTemplate)-length($dataset_id)).$dataset_id;
				push(@{$response->{info}},"Obtained identifier $datasetIdentifier");

				#### Set database row fields
				my %rowdata = (
          datasetIdentifier => $datasetIdentifier,
        );

				#### Insert the new record
				$db->updateOrInsertRow(
          update => 1,
          table_name => $mainTableName,
          rowdata_ref => \%rowdata,
          PK => 'dataset_id',
          PK_value => $dataset_id,
        );

				#### Prepare to update the history table
				%rowdata = (
					dataset_id => $dataset_id,
					datasetIdentifier => $datasetIdentifier,
					revisionNumber => 0,
					isLatestRevision => 'Y',
          PXPartner => $PXPartner,
          status => 'ID requested',
          identifierDate => 'CURRENT_TIMESTAMP',
        );

				#### Insert the new record
				my $datasetHistory_id = $db->updateOrInsertRow(
           insert => 1,
           table_name => $historyTableName,
           rowdata_ref => \%rowdata,
           return_PK => 1,
        );
				push(@{$response->{info}},"Updated history table and received datasetHistory_id=$datasetHistory_id");

				#### Return a successful message
				$response->{result} = "SUCCESS";
				$response->{identifier} = $datasetIdentifier;
				$response->{dataset_id} = $dataset_id;
				$response->{message} = "${testPhrase}Identifier $datasetIdentifier granted to $PXPartner";

      #### Report a database problem
      } else {
				$response->{result} = "ERROR";
				$response->{message} = "Illegal dataset_id '$dataset_id' returned from database";
      }

    #### Otherwise Insert failed
    } else {
      $response->{result} = "ERROR";
      $response->{message} = "Unable to insert new dataset row in database";
    }

  }

  return($response);
}


###############################################################################
# processAnnouncement: Process an announcement XML by ProteomeCentral
###############################################################################
sub processAnnouncement {
  my $self = shift;
  my %args = @_;
  my $SUB_NAME = 'processAnnouncement';

  #### Decode the argument list
  my $method = $args{'method'} || die("[$SUB_NAME] ERROR:method  not passed");
  my $path = $args{'path'} || die("[$SUB_NAME] ERROR:path  not passed");
  my $params = $args{'params'} || die("[$SUB_NAME] ERROR:params  not passed");
  my $response = $args{'response'} || die("[$SUB_NAME] ERROR:response  not passed");
  my $uploadFilename = $args{'uploadFilename'} || die("[$SUB_NAME] ERROR: uploadFilename not passed");

  my $test = $params->{test};
  my $noDatabaseUpdate = $params->{noDatabaseUpdate};
  my $noEmailBroadcast = $params->{noEmailBroadcast};

  $test = 'no' if (!defined($test));
  $noDatabaseUpdate = 0 if (!defined($noDatabaseUpdate));
  $noEmailBroadcast = 0 if (!defined($noEmailBroadcast));

  #### Testing
  if ( 0 ) {
    push(@{$response->{info}},"noDatabaseUpdate=$noDatabaseUpdate, but forcing it to yes");
    push(@{$response->{info}},"noEmailBroadcast=$noEmailBroadcast, but forcing it to yes");
    $noEmailBroadcast = 'yes';
    $noDatabaseUpdate = 'yes';
  }

  #### Set a default error message in case something goes wrong
  $response->{result} = "ERROR";
  $response->{message} = "Unable to process XML: Unknown error.";

  push(@{$response->{info}},"File has been uploaded. Begin processing it.");

  #### Parse and check the validity of the submitted file
  my $result = $self->validatePXXMLDocument( filename => "$path/$uploadFilename", params => $params );
  $response = $result;

  #### If things did not go perfectly, then return
  my $nWarnings = @{$response->{warnings}};
  if ( $response->{result} ne 'OK' ) {
    return($response);
  }
  if ( $nWarnings ) {
    $response->{result} = "ERROR";
    $response->{message} = "Unresolved issues with the submitted XML. Please correct and try again.";
    return($response);
  }

  #### Extract the dataset and proceed. This is very messy. FIXME
  $result = $response->{dataset};

  #### If the method is just to test the XML, then we're done
  if ($method eq 'validateXML') {
    push(@{$response->{info}},"XML and CV validation complete.");
    $response->{result} = "SUCCESS";
    $response->{message} = "XML validation complete. See INFO lines for validation problems.";
    return($response);
  }

  push(@{$response->{info}},"Ready to update database record");

  #### For debugging, escape out here for no database change or email
  if ( 0 ) {
    push(@{$response->{info}},"The database would be updated here and an email sent, but escape for test.");
    $response->{result} = "TESTSUCCESSFUL";
    $response->{message} = "Test processing was successful, although no database changes occurred.";
    return($response);
  }

  #### If we're not just validating, then begin the database update and announcement
  $self -> updateRecord (
    result => $result,
    response => $response,
    test => $params->{test},
    noDatabaseUpdate => $noDatabaseUpdate,
  );
  push(@{$response->{info}},"Update returned '$response->{result}'");

  #### If the dataset update did not return an error, then send an email
  if ( $response->{result} ne "ERROR" ) {
    my @toRecipients;
    my $testFlag = '';
    my $testClause = '';
    if ($params->{test} =~ /^[yt]/i) {
	$testFlag = ' (test only)';
	@toRecipients = (
			 'ProteomeXchange Test','proteomexchange-test@googlegroups.com',
			 );
	#@toRecipients = (
	#		 'Eric Deutsch','edeutsch@systemsbiology.org',
	#		 );
	$testClause = '&test=yes';
    } else {
	@toRecipients = (
			 'ProteomeXchange','proteomexchange@googlegroups.com',
			 );
    }
    my @ccRecipients = ();
    my @bccRecipients = ();
    my $identifier = $result->{identifier} || '??';
    my %messageType = ( status=> 'new', titleIntro => 'New', midSentence => 'new' );
    if ($response->{revisionNumber} && $response->{revisionNumber} > 1) {
	%messageType = ( status => 'revision', titleIntro => 'Updated information for', midSentence => 'revision to a' );
    }

    my $modeClause = '&outputMode=XML';
    my $description = $result->{description} || '???';
    $description =~ s/[\r\n]//g;

    my $changeLogEntry = '';
    if ($result->{changeLogEntry}) {
      $changeLogEntry = "Changes: $result->{changeLogEntry}\n";
    }

    #### Create a tweet message from the available information
    use ProteomeXchange::Tweet;
    my $tweet = new ProteomeXchange::Tweet;
    $tweet->prepareTweetContent(
      datasetTitle => $result->{title},
      PXPartner => $params->{PXPartner},
      datasetIdentifier => $identifier,
      datasetSubmitter  => $result->{primarySubmitter},
      datasetLabHead => $result->{labHead},
      datasetSpeciesString => $result->{species},
      datasetStatus => $messageType{status},
    );
    my $tweetString = $tweet->getTweet();

    #### If emailing has been temporarily disabled, just create an INFO entry about it
    if ($noEmailBroadcast && $noEmailBroadcast !~ /no/i && $noEmailBroadcast !~ /false/i) {
	push(@{$response->{info}},"Will pretend to send around an email to ".join(',',@toRecipients)." but won't really do it because noEmailBroadcast=$noEmailBroadcast.");

    #### Otherwise, send the email!
    } else {
	push(@{$response->{info}},"Sending an announcement email to ".join(',',@toRecipients));
	my $emailProcessor = new ProteomeXchange::EMailProcessor;
      $emailProcessor -> sendEmail(
				   toRecipients=>\@toRecipients,
				   ccRecipients=>\@ccRecipients,
				   bccRecipients=>\@bccRecipients,
				   subject=>"$messageType{titleIntro} ProteomeXchange dataset $identifier$testFlag",
				   message=>"Dear$testFlag ProteomeXchange subscriber, a $messageType{midSentence} ProteomeXchange dataset is being announced$testFlag. To see more information, click here:\n\nhttp://proteomecentral.proteomexchange.org/dataset/$identifier$testClause\n\nSummary of dataset\n\nStatus: $messageType{status}\nIdentifier: $identifier\n${changeLogEntry}HostingRepository: $params->{PXPartner}\nSpecies: $result->{species}\nTitle: $result->{title}\nSubmitter: $result->{primarySubmitter}\nLabHead: $result->{labHead}\nDescription: $description\n\nHTML_URL: http://proteomecentral.proteomexchange.org/dataset/$identifier$testClause\nXML_URL: http://proteomecentral.proteomexchange.org/dataset/$identifier$testClause$modeClause\n\n",
				   );

	#### Send a tweet too if this is a new dataset
      if ( $messageType{status} eq 'new' && !$testClause ) {
	  push(@{$response->{info}},"Sending tweet to ProteomeXchange");
	  my $tweetResponse = $tweet->sendTweet();
	  push(@{$response->{info}},"Result from tweet: $tweetResponse");
	} else {
	  push(@{$response->{info}},"Tweet of revision suppressed");
	}

    }
  }

  #### Processing complete
  return($response);
}


###############################################################################
# validatePXXMLDocument: Carefully check a submitted file for issues
###############################################################################
sub validatePXXMLDocument {
  my $self = shift;
  my %args = @_;
  my $SUB_NAME = 'validatePXXMLDocument';

  #### Decode the argument list
  my $filename = $args{'filename'} || die("[$SUB_NAME] ERROR: filename not passed");
  my $params = $args{'params'} || die("[$SUB_NAME] ERROR: params not passed");
  my $permitOldSchemas = $args{'permitOldSchemas'} || 0;

  my $response;
  $response->{result} = "ERROR";
  $response->{message} = "Internal error";
  $response->{validationWarnings} = [];
  $response->{validationErrors} = [];
  $response->{info} = [];
  $response->{warnings} = [];

  #### Check to make sure the file exists
  unless ( -f $filename ) {
    $response->{message} = "File '$filename' not found";
    return($response);
  }

  #### Open the file or report an error
  unless (open(INFILE,$filename)) {
    $response->{message} = "File '$filename' exists, but cannot be opened for read";
    return($response);
  }

  #### Check to make sure this is an XML file that reports the right SchemaLocation
  my $nLines = 0;
  my $info;
  my $schema = '';
  while ($nLines < 50) {
    my $line = <INFILE>;
    if ($line && $line =~ /\<\?xml/) {
      push(@{$response->{info}},"File does appear to be XML");
      $info->{isXML} = 'passed';
    }
    if ($line && $line =~ /SchemaLocation=\"(.+?)\"/) {
      $schema = $1;
      if ( $permitOldSchemas ) {
        if ( $schema =~ /^proteomeXchange-1.[0-4].0.xsd$/ ) {
	  push(@{$response->{info}},"File has as acceptable XSD $schema");
	  $info->{hasRightXSD} = 'passed';
        } else {
	  $response->{result} = "ERROR";
	  $response->{message} = "File has unexpected XSD '$schema'. Cannot process this file. Sorry.";
	  push(@{$response->{info}},"File has unexpected XSD '$schema'. Cannot process this file. Sorry. At present, only proteomeXchange-1.[0-4].0.xsd");
	  $info->{hasRightXSD} = 'failed';
        }
      } else {
        if ($schema eq 'proteomeXchange-1.4.0.xsd') {
	  push(@{$response->{info}},"File has as acceptable XSD $schema");
	  $info->{hasRightXSD} = 'passed';
        } else {
	  $response->{result} = "ERROR";
	  $response->{message} = "File has unexpected XSD '$schema'. Cannot process this file. Sorry.";
	  push(@{$response->{info}},"File has unexpected XSD '$schema'. Cannot process this file. Sorry. At present, only proteomeXchange-1.4.0.xsd is permitted");
	  $info->{hasRightXSD} = 'failed';
        }
      }
    }
    $nLines++;
  }
  close(INFILE);


  #### Return unless everything is okay thus far
  if ( $info->{isXML} && $info->{isXML} eq 'passed' &&
	   $info->{hasRightXSD} && $info->{hasRightXSD} eq 'passed') {
    #### All is well
  } else {
    unless ($info->{isXML} && $info->{isXML} eq 'passed') {
      $response->{message} = "The uploaded file does not appear to be proper XML. It is missing the expected preamble, at least.";
    }
    unless ($info->{hasRightXSD} && $info->{hasRightXSD} eq 'passed') {
      $response->{message} = "The uploaded file does not appear to have the needed schema reference. Please check schema definition.";
    }
    return($response);
  }


  #### Check to make sure we have the schema available
  my $root = '';
  if ( $filename =~ /^(.+)\/(.+)$/ ) {
    $root = $1;
  }
  unless ( -f "$root/$schema" ) {
    $response->{message} = "The schema $schema is not found on the local system. Please report this internal error.";
    return($response);
  }


  #### Run the XML through a validating parser
  push(@{$response->{info}},"Validating XML...");
  my @result = `export LD_LIBRARY_PATH=/tools/xerces-c-src_2_7_0/lib; /tools/xerces-c-src_2_7_0/bin/SAX2Count -v=always $filename 2>&1`;
  $nLines = scalar(@result);

  #### If the file is valid XML
  if ($nLines == 1 && $result[0] =~ /elems,/) {
    push(@{$response->{info}},"Submitted XML is valid according to the XSD.");
  #### If it is not valid XML
  } else {
    $response->{message} = "File does not validate against the schema. Cannot process this file. Sorry.";
    foreach my $line ( @result ) {
      chomp($line);
      push(@{$response->{info}},$line);
    }
    return($response);
  }


  #### Run the file through our own parser to check semantic issues
  my $parser = new ProteomeXchange::DatasetParser;
  $parser->parse(filename=>$filename,response=>$response);
  my $dataset = $response->{dataset};

  #### If there are cvErrors, put them in info
  my $nCvErrors = 0;
  if ($parser->{cvErrors}) {
    foreach my $error ( @{$parser->{cvErrors}} ) {
      my $count = $parser->{cvErrorHash}->{$error}->{count} || -1;
      $error .= " ($count times)" if ($count != 1);
      $nCvErrors++;
      push(@{$response->{info}},$error);
      push(@{$response->{validationErrors}},$error);
    }
  }
  push(@{$response->{info}},"There were a total of $nCvErrors different CV errors or warnings.");


  #### If there are other warnings or errors, put them in info
  my $nWarnings = 0;
  foreach my $warning ( @{$response->{warnings}} ) {
    $nWarnings++;
    push(@{$response->{info}},$warning);
  }
  push(@{$response->{info}},"There was a total of $nWarnings non-CV warnings.");

  #### If there are other warnings or errors, put them in info
  my $nErrors = 0;
  foreach my $error ( @{$response->{errors}} ) {
    $nErrors++;
    push(@{$response->{info}},$error);
    push(@{$response->{validationErrors}},$error);
  }
  push(@{$response->{info}},"There was a total of $nErrors non-CV errors.");


  ### If the PXPartner does not match the one in XML file, report an error
  if ($params->{PXPartner} ne 'ANY' && $params->{PXPartner} ne $dataset->{PXPartner} ){
    my $message = "PXPartners in input ($params->{PXPartner}) and in xml ($dataset->{PXPartner}) don't match.";
    push(@{$response->{info}},$message);
    push(@{$response->{validationErrors}},$message);
  }

  ### Check if the description is  at least 50 characters
  if ( !exists($dataset->{description}) || !defined($dataset->{description}) || length($dataset->{description}) < 50 ) {
    my $descriptionLength = length($dataset->{description});
    if ( $dataset->{changeLogEntry} ) {
      my $message = "WARNING: The description for the submission is supposed to be least 50 characters, but for a revision, $descriptionLength is allowed for now";
      push(@{$response->{info}},$message);
    } else {
      my $message = "The description length for a NEW submission must be at least 50 characters, but here is only $descriptionLength.";
      push(@{$response->{info}},$message);
      push(@{$response->{validationErrors}},$message);
    }
  }

  ### If the title is at least 30 characters
  if ( !exists($dataset->{title}) || !defined($dataset->{title}) || length($dataset->{title}) < 30 ){
    my $titleLength = length($dataset->{title});
    if ( $dataset->{changeLogEntry} ) {
      my $message = "WARNING: The title for the submission is supposed to be least 30 characters, but for a revision, $titleLength is allowed for now";
      push(@{$response->{info}},$message);
    } else {
      my $message = "The title length for a NEW submission must be at least 30 characters, but here is only $titleLength.";
      push(@{$response->{info}},$message);
      push(@{$response->{validationErrors}},$message);
    }
  }

  #### Finish
  $nErrors = scalar(@{$response->{validationErrors}});
  if ( $nErrors ) {
    $response->{result} = "FoundValidationErrors";
    $response->{message} = "PX XML document parsing completed with errors";
  } else {
    $response->{result} = "OK";
    $response->{message} = "PX XML document parsing completed without error";
  }

  return($response);
}



###############################################################################
# processSupplementalFullDatasetLinkList: Process a submitted SupplementalFullDatasetLinkList
###############################################################################
sub processSupplementalFullDatasetLinkList {
  my $self = shift;
  my %args = @_;
  my $SUB_NAME = 'processSupplementalFullDatasetLinkList';

  #### Decode the argument list
  my $method = $args{'method'} || die("[$SUB_NAME] ERROR:method  not passed");
  my $path = $args{'path'} || die("[$SUB_NAME] ERROR:path  not passed");
  my $params = $args{'params'} || die("[$SUB_NAME] ERROR:params  not passed");
  my $response = $args{'response'} || die("[$SUB_NAME] ERROR:response  not passed");
  my $uploadFilename = $args{'uploadFilename'} || die("[$SUB_NAME] ERROR: uploadFilename not passed");

  my $test = $params->{test};
  $test = 'no' if (!defined($test));

  #### Set a default error message in case something goes wrong
  $response->{result} = "ERROR";
  $response->{message} = "Unable to process XML: Unknown error.";

  push(@{$response->{info}},"File has been uploaded. Begin processing it.");

  #### Parse and check the validity of the submitted file
  my $result = $self->validatePXXMLDocument( filename => "$path/$uploadFilename", params => $params );
  $response = $result;

  #### If things did not go perfectly, then return
  my $nWarnings = @{$response->{warnings}};
  if ( $response->{result} ne 'OK' ) {
    return($response);
  }
  if ( $nWarnings ) {
    $response->{result} = "ERROR";
    $response->{message} = "Unresolved issues with the submitted XML. Please correct and try again.";
    return($response);
  }

  #### Extract the dataset and proceed. This is very messy. FIXME
  $result = $response->{dataset};

  push(@{$response->{info}},"Ready to update database record");

  #### Try to add or update the database for this submitted information
  if ( 0 ) {
    $self->updateSupplementalFullDatasetLinkListRecord(
      result => $result,
      response => $response,
      test => $params->{test},
    );
    push(@{$response->{info}},"Update returned '$response->{result}'");
  }

  #### Processing complete
  return($response);
}


###############################################################################
1;

