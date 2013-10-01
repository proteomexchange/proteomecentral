package ProteomeXchange::Dataset;

###############################################################################
# Class       : ProteomeXchange::Dataset
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
#
# Description : This class is used to represent a dataset announcement in ProteomeXchange
#
###############################################################################

use strict;
use lib "/local/wwwspecial/proteomecentral/lib/perl";
use ProteomeXchange::Database;
use ProteomeXchange::DatasetParser;
use ProteomeXchange::EMailProcessor;
use vars qw($db);
$db = new ProteomeXchange::Database;


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
  my $datasetidentifier = $result->{identifier};

  my $table_name = 'dataset';
  if ($test && ($test =~ /yes/i || $test =~ /true/i)) {
    $table_name = 'dataset_test';
  }

  if ( $datasetidentifier eq '' ){
     $response->{result} = "ERROR";
     $response->{message} = "datasetidentifier not parsed";
     return;
  }

  my $sql = "select dataset_id, SubmissionDate from $table_name where datasetIdentifier='$datasetidentifier'";
  my @rows = $db->selectSeveralColumns($sql);

  if(@rows > 1){
    $response->{result} = "ERROR";
    $response->{message} = "more than one record found for identifier \"$datasetidentifier\".\n";
    return;
  }elsif(@rows == 0 ){
    $response->{result} = "ERROR";
    $response->{message} ="no record found for identifier \"$datasetidentifier\". Please request ID first.\n";
    return;
  }
    
  my $dataset_id = $rows[0]->[0];
  my $submissionDate = $rows[0]->[1];

  ## need to check if the version number is same as the one in the database. if not
  ## might need to do something.
  my %rowdata = (
    'primarySubmitter' => $result->{primarySubmitter}, 
    'title' => $result->{title},
    'identifierVersion' => $result->{identifierVersion},
    'instrument' => $result->{instrument},
    'publication' => $result->{publication},
    'species' => $result->{species},
    'keywordList' => $result->{keywordList},
    'announcementXML' => $result->{announcementXML},
    'status' => 'announced',
  ); 
  if ( $submissionDate =~ /\d+/){ 
    $rowdata{revisionDate} = 'CURRENT_TIMESTAMP';
  } else{
     $rowdata{submissionDate} = 'CURRENT_TIMESTAMP' ; 
  }

  my $value = $db->updateOrInsertRow(
				     update => 1,
				     table_name => $table_name,
				     rowdata_ref => \%rowdata,
				     PK => 'dataset_id',
				     PK_value => $dataset_id,
				     );
  if ($value == 1 ) {
    $response->{result} = "Success";
    $response->{'link'} = "http://proteomecentral.proteomexchange.org/cgi/GetDataset?ID=$dataset_id&test=$test";

  } else {
    $response->{result} = "ERROR";
    $response->{message} = "ERROR: fail to update record $datasetidentifier. $value";
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

  my $response;
  $response->{result} = "ERROR";
  $response->{message} = "Unable to create a new identifier";

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

    if ($test && ($test =~ /yes/i || $test =~ /true/i)) {
      $datasetIdentifier = 'PXT000001';
      $response->{result} = "SUCCESS";
      $response->{identifier} = $datasetIdentifier;
      $response->{message} = "Identifier $datasetIdentifier granted to $PXPartner";
    } else {

      #print "Content-type: text/html\n\n";
      #print "test mode=$test<BR>\n";
      #print "Halting right before the assignment of a new real ID\n";
      #exit;

      #### Set database row fields
      my %rowdata = (
        PXPartner => $PXPartner,
        status => 'ID requested',
        identifierDate => 'CURRENT_TIMESTAMP',
      );

      #### Insert the new record
      my $dataset_id = $db->updateOrInsertRow(
        insert => 1,
        table_name => 'dataset',
        rowdata_ref => \%rowdata,
        return_PK => 1,
      );

      if ($dataset_id) {
        if ($dataset_id >=1 && $dataset_id < 1000000) {
          my $template = 'PXD000000';
	  my $datasetIdentifier = substr($template,0,length($template)-length($dataset_id)).$dataset_id;

	  #### Set database row fields
	  my %rowdata = (
            datasetIdentifier => $datasetIdentifier,
          );

	  #### Insert the new record
	  $db->updateOrInsertRow(
            update => 1,
            table_name => 'dataset',
            rowdata_ref => \%rowdata,
            PK => 'dataset_id',
            PK_value => $dataset_id,
          );

	  #### Return a successful message
	  $response->{result} = "SUCCESS";
	  $response->{identifier} = $datasetIdentifier;
    $response->{dataset_id} = $dataset_id;
	  $response->{message} = "Identifier $datasetIdentifier granted to $PXPartner";

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

  }

  return($response);
}


###############################################################################
# submitAnnouncement: Submit an announcement XML to ProteomeCentral
###############################################################################
sub submitAnnouncement {
  my $self = shift;
  my %args = @_;
  my $SUB_NAME = 'submitAnnouncement';

  #### Decode the argument list
  my $params = $args{'params'};
  my $response = $args{'response'};
  my $uploadFilename = $args{'uploadFilename'};
  my $test = $params->{test};
  my $path = '/local/wwwspecial/proteomecentral/var/submissions';
  $path .= "/testing" if ($test && ($test =~ /yes/i || $test =~ /true/i));

  $response->{result} = "ERROR";
  $response->{message} = "Unable to process announcement: Unknown error";
  push(@{$response->{info}},"File has been uploaded. Begin processing it");

  if ( -f "$path/$uploadFilename" ) {
    if (open(INFILE,"$path/$uploadFilename")) {
      my $nLines = 0;
      my $info;
      while ($nLines < 50) {
	my $line = <INFILE>;
	if ($line && $line =~ /\<\?xml/) {
	  push(@{$response->{info}},"File does appear to be XML");
	  $info->{isXML} = 'passed';
	}
	if ($line && $line =~ /SchemaLocation=\"(.+?)\"/) {
	  if ($1 eq 'proteomeXchange-draft-07.xsd' || $1 eq 'proteomeXchange-1.1.0.xsd') {
	    push(@{$response->{info}},"File has the correct XSD");
	    $info->{hasRightXSD} = 'passed';
	  } else {
	    $response->{result} = "ERROR";
	    $response->{message} = "File has unexpected XSD '$1'. Cannot process this file. Sorry.";
	    $info->{hasRightXSD} = 'failed';
	  }
	}
	$nLines++;
      }
      close(INFILE);

      if ($info->{isXML} && $info->{isXML} eq 'passed' &&
          $info->{hasRightXSD} && $info->{hasRightXSD} eq 'passed') {

	push(@{$response->{info}},"Validating XML...");
	my @result = `export LD_LIBRARY_PATH=/tools/src/Xerces/xerces-c-src_2_7_0/lib; /tools/src/Xerces/xerces-c-src_2_7_0/bin/SAX2Count -v=always $path/$uploadFilename 2>&1`;

	my $nLines = scalar(@result);

	#### If the file is valid XML
	if ($nLines == 1 && $result[0] =~ /elems,/) {
	  push(@{$response->{info}},"Submitted XML is valid.");

	  my $parser = new ProteomeXchange::DatasetParser;
	  $parser -> parse ('uploadFilename' => $uploadFilename, 'response' => $response, 'path' => $path);
	  my $result = $response->{dataset};

	  ### If the PXPartner does not match the one in XML file, report an error
	  if ($params->{PXPartner} ne $result->{PXPartner} ){
	    $response->{result} = "ERROR";
	    $response->{message} = "PXPartner in input, $params->{PXPartner}, and in xml, $result->{PXPartner}, doesn't match.";

	  #### Else everything is okay, so record the result and email the announcement
	  } else {
	    push(@{$response->{info}},"Ready to update database record");
	    $self -> updateRecord ('result' => $result, 'response' => $response, 'test' => $params->{test});
	    push(@{$response->{info}},"Update returned '$response->{result}'");
	    if ( $response->{result} ne "ERROR" ) {
	      my @toRecipients;
	      my $testFlag = '';
	      my $testClause = '';
	      if ($params->{test} =~ /^[yt]/i) {
		$testFlag = ' (test only)';
		@toRecipients = (
				 'ProteomeXchange Test','proteomexchange-test@googlegroups.com',
				 );
		$testClause = '&test=yes';
	      } else {
		@toRecipients = (
				 'ProteomeXchange','proteomexchange@googlegroups.com',
				 );
	      }
	      my @ccRecipients = ();
	      my @bccRecipients = ();
	      my $identifier = $result->{identifier} || '??';
	      my $messageType = 'new' || 'revision to a';
	      my $modeClause = '&outputMode=XML';
	      my $description = $result->{description} || '???';
	      $description =~ s/[\r\n]//g;
	      my $emailProcessor = new ProteomeXchange::EMailProcessor;
	      $emailProcessor -> sendEmail(
					   toRecipients=>\@toRecipients,
					   ccRecipients=>\@ccRecipients,
					   bccRecipients=>\@bccRecipients,
					   subject=>"New ProteomeXchange dataset $identifier$testFlag",
					   message=>"Dear$testFlag ProteomeXchange subscriber, a $messageType ProteomeXchange dataset is being announced$testFlag. To see more information, click here:\n\nhttp://proteomecentral.proteomexchange.org/dataset/$identifier$testClause\n\nSummary of dataset\n\nStatus: $messageType\nIdentifier: $identifier\nSpecies: $result->{species}\nTitle: $result->{title}\nDescription: $description\nSubmitter: $result->{primarySubmitter}\nHTML_URL: http://proteomecentral.proteomexchange.org/dataset/$identifier$testClause\nXML_URL: http://proteomecentral.proteomexchange.org/dataset/$identifier$testClause$modeClause\n\n",
					   );
	    }
	  }

	#### else the file does not validate against the schema. Report the error
	} else {
	  $response->{result} = "ERROR";
	  $response->{message} = "File does not validate against the schema. Cannot process this file. Sorry.";
	  foreach my $line ( @result ) {
	    chomp($line);
	    push(@{$response->{info}},$line);
	  }
	}

      } else {
	unless ($info->{isXML} && $info->{isXML} eq 'passed') {
	  $response->{message} = "The uploaded file does not appear to be proper XML. It is missing the expected preamble, at least.";
	}
	unless ($info->{hasRightXSD} && $info->{hasRightXSD} eq 'passed') {
	  $response->{message} = "The uploaded file does not appear to have the needed schema reference. Please check schema definition.";
	}
      }

    } else {
      $response->{message} = "Internal error. Unable to open stored file.";
    }

  } else {
    $response->{message} = "Internal error. Unable to find stored file.";
  }

  return($response);
}

###############################################################################
1;

