package ProteomeXchange::DatasetParser;

###############################################################################
# Class       : ProteomeXchange::DatasetParser
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
#
# Description : This class is used to parser a ProteomeXchangeXML document
#
###############################################################################

use strict;
#use lib "/local/wwwspecial/proteomecentral/lib/perl";
use ProteomeXchange::Database;

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
	 announcementXML => $parameters{announcementXML},
	};

  bless $self => $class;

  return $self;
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
# parse: Parser a ProteomeXchange XML file
###############################################################################
sub parse {
  my $self = shift;
  my %args = @_;
  my $SUB_NAME = 'parse';

  #### Decode the argument list
  my $params = $args{'announcementXML'};
  my $response = $args{'response'};
  my $filename = $args{'filename'};

  #### Set a default error message in case something goes wrong
  $response->{result} = "ERROR";
  $response->{message} = "Unable to parse file: Unknown error";

  if ( ! -f "$filename" ) {
    $filename =~ s/local/net\/dblocal/;
    if ( ! -f "$filename" ) {
      $response->{message} = "Unable to parse file. Does not exist!";
      return($response);
    }
  }

  my $dataset;
  my @warnings;

  #### Open the file
  unless (open(FH,$filename)){
    $response->{message} = "Unable to open the document '$filename'";
    return($response);
  }

  use XML::TreeBuilder;
  my $doctree = XML::TreeBuilder->new();
  $doctree->parse(*FH);

  #### Check all the cvParams that they do not conflict with the CV
  push(@{$response->{info}},"Checking the cvParams in the document");
  my @cvParams = $doctree->find_by_tag_name('cvParam');
  foreach my $cvParam (@cvParams) {
    my $paramAccession = $cvParam->attr('accession');
    my $paramName = $cvParam->attr('name');
    my $paramValue = $cvParam->attr('value');
    my $paramCvRef = $cvParam->attr('cvRef');
    #print "Checking $paramAccession==$paramName\n";
    $self->checkCvParam(paramAccession=>$paramAccession,paramName=>$paramName,paramValue=>$paramValue,paramCvRef=>$paramCvRef);
  }

  #### Extract all the needed pieces of information

  my ($datasetSummary) = $doctree->find_by_tag_name('DatasetSummary');
  $dataset->{title} = $datasetSummary->attr('title');
  $dataset->{broadcaster} = $datasetSummary->attr('broadcaster');
  $dataset->{announceDate} = $datasetSummary->attr('announceDate');
  $dataset->{PXPartner} = $datasetSummary->attr('hostingRepository');
  push(@{$response->{info}},"PXParter is '$dataset->{PXPartner}'");

  $dataset->{announcementXML} = $filename;
  if ($filename =~ /\//) {
    $filename =~ /^(.+)\/(.+?)$/;
    $dataset->{announcementXML} = $2;
  }

  my ($description) = $datasetSummary->find_by_tag_name('Description');
  $dataset->{description} = $description->as_text();

  foreach my $str (qw (RepositorySupport ReviewLevel)){
    my ($var) = $datasetSummary->find_by_tag_name($str);
    if ( $var){
      my ($cvParam) = $var ->find_by_tag_name('cvParam');
      if ($cvParam){
        $dataset->{$str} = $cvParam->attr('name');
      }
    }
  }

  my ($changeLogEntry) = $doctree->find_by_tag_name('ChangeLogEntry');
  if ($changeLogEntry) {
    $dataset->{changeLogEntry} = $changeLogEntry->as_text();
  }

  my @datasetIdentifiers = $doctree->find_by_tag_name('DatasetIdentifier');
  foreach my $datasetIdentifier ( @datasetIdentifiers ) {
    my @cvParams = $datasetIdentifier->find_by_tag_name('cvParam');
    foreach my $cvParam ( @cvParams ) {
			if ($cvParam->attr('name') eq "ProteomeXchange accession number") {
				$dataset->{identifier} = $cvParam->attr('value');
			}
			if ($cvParam->attr('name') eq "ProteomeXchange accession version number") {
				$dataset->{identifierVersion} = $cvParam->attr('value');
			}
      if ($cvParam->attr('name') =~ /Digital Object Identifier/){
        $dataset->{DigitalObjectIdentifier} =  "http://dx.doi.org/". $cvParam->attr('value');
      }
	  }
  }
  unless ($dataset->{identifier}) {
    #### Error: Unable to extract ProteomeXchange accession from the submitted document
  }

  foreach my $tag (qw (Species Instrument ModificationList DatasetOrigin)){


    my @lists = $doctree->find_by_tag_name($tag);
    foreach my $list ( @lists ) {
      #my  $list = $lists[0];
      if($tag =~ /Modification/){
        my $immediate_parent = ( $list->lineage_tag_names() )[0];
        if ($immediate_parent =~ /RepositoryRecord/){
	  next;
        }
      }

      my @cvParams = $list->find_by_tag_name('cvParam');
      foreach my $cvParam ( @cvParams ) {
        my $name = $cvParam->attr('name') || '';
        my $value = $cvParam->attr('value') || '';
        $name =~ s/^\s+//;
        $value =~ s/^\s+//;
        $name =~ s/\s+$//;
        $value =~ s/\s+$//;
        if($name =~ /accession/){
          push @{$dataset->{datasetOriginAccession}} , $value;
        }

	if ($value){
	  if ($tag eq 'Species'){
	    $dataset->{speciesList} .=  $name . ": ";
	    $dataset->{speciesList} .= $value . "; " ;
	    $dataset->{speciesList} =~ s/taxonomy://;
	    if ($name =~ /scientific name/i){
	      if ( defined($dataset->{species}) && $dataset->{species} ne '' ){
		$dataset->{species} .=  ", ". $value;
	      }else{
		$dataset->{species} =  $value;
	      }
	      $dataset->{species} =~ s/\(\w+\)//;
	    }
	  }else{
	    if ( defined($dataset->{lcfirst($tag)})){
	      $dataset->{lcfirst($tag)} .=  "; ". $name . ": ";
	      $dataset->{lcfirst($tag)} .= $value;
	    }else{
	      $dataset->{lcfirst($tag)} =  $name .": ";;
	      $dataset->{lcfirst($tag)} .= $value;
	    }
	  }
	}else{
	  if (not defined $dataset->{lcfirst($tag)}){
	    $dataset->{lcfirst($tag)} =  $name ;
	  }else{
	    $dataset->{lcfirst($tag)} .=  "; ". $name; 
	  }
	}
	
	#if ($cvParam->attr('accession') eq "MS:1001469") {
	#	$dataset->{species} .= $cvParam->attr('value') ."; ";
	#}elsif($cvParam->attr('accession') =~ /^MOD:/){
	#  $dataset->{modification} .=  $cvParam->attr('name') ."; ";
	#}else {
	#  $dataset->{instrument} .= $cvParam->attr('name') ."; ";
	#}
      }
    }
  }

  unless ($dataset->{species}) {
    push(@warnings,'ERROR: Unable to extract scientific species name from the document.');
  }

  
  my @contactList = $doctree->find_by_tag_name('ContactList');
  my %firstContact;
  foreach my $contactListItem (@contactList){
    my @contacts =  $contactListItem->find_by_tag_name('Contact');
    foreach my $contact (@contacts){
      my $id = $contact->attr('id');
      my @cvParams = $contact->find_by_tag_name('cvParam');
      my %contact;

      foreach my $cvParam ( @cvParams ) {
				my $paramAccession = $cvParam->attr('accession');
				my $paramName = $cvParam->attr('name');
				my $paramValue = $cvParam->attr('value');
				chomp $paramValue if (defined($paramValue)); # EWD might not be needed, but left it as found
				$contact{$paramName} = $paramValue;
				$dataset->{contactList}->{$id}->{$paramName} = $paramValue;
      }

      unless (%firstContact) {
				%firstContact = %contact;
      }

      if (exists($contact{'dataset submitter'})) {
				if ($dataset->{primarySubmitter}) {
					push(@warnings,'WARNING: There appears to be more than one dataset submitter. Only the first may appear in scalar uses.');
				} else {
					$dataset->{primarySubmitter} = $contact{'contact name'};
				}
      }

      if (exists($contact{'lab head'})) {
				if ($dataset->{labHead}) {
					push(@warnings,'WARNING: There appears to be more than one lab head. Only the first may appear in scalar uses.');
				} else {
					$dataset->{labHead} = $contact{'contact name'};
				}
      }
    }
  }

  unless ($dataset->{primarySubmitter}) {
    push(@warnings,"WARNING: No contact had the designation 'primary submitter'. Will assume that the first contact is the 'primary submitter'");
    $dataset->{primarySubmitter} = $firstContact{'contact name'};
  }
  unless ($dataset->{labHead}) {
    push(@warnings,"WARNING: No contact had the designation 'lab head'");
  }

  my %lists=();
  my @publicationLists = $doctree->find_by_tag_name('PublicationList');
  foreach my $publicationList (@publicationLists){ 
    my @lists =  $publicationList->find_by_tag_name('Publication');
    foreach my $publication (@lists){
     my @cvParams = $publication->find_by_tag_name('cvParam');
     my $id = $publication -> attr('id'); 
     foreach my $cvParam ( @cvParams ) {
       if ($cvParam->attr('name') =~ /pubmed/i) {
          $lists{$id}{pubmedid} = $cvParam->attr('value');
       }else{
         $lists{$id}{name} = $cvParam->attr('name');
         $lists{$id}{value} = $cvParam->attr('value');
       }
     }
   }
  }

  foreach my $id (%lists){
    if (defined($lists{$id}{name}) && $lists{$id}{name} =~ /reference/i){
      #if ( 0 ){    ##### !!!!!!!!!!!!!!!!!!!!!!!!!!! DISABLED
      if (defined $lists{$id}{pubmedid}){
        use ProteomeXchange::PubMedFetcher;
        my $PubMedFetcher = new ProteomeXchange::PubMedFetcher;
        my ($pubname, $pubmed_info) = $PubMedFetcher->getArticleRef(
          PubMedID=>$lists{$id}{pubmedid});
        $dataset->{publicationList} .= "$pubmed_info;" || '';
        $dataset->{publication} .= "<a href=\"http://www.ncbi.nlm.nih.gov/pubmed/$lists{$id}{pubmedid}\">$pubname</a>";;  
      }else{
         if ( defined $dataset->{publication} ){
           $dataset->{publicationList} .= "; $lists{$id}{value}";
           $dataset->{publication} .= "; $lists{$id}{value}";
         }else{
           $dataset->{publicationList} = "$lists{$id}{value}";
           $dataset->{publication} = "$lists{$id}{value}";
         }
      }
    }else{
       my $str;
       if (defined($lists{$id}{value}) && $lists{$id}{value} ne ''){ 
         $str = $lists{$id}{value};
       }else{
         if ( defined($lists{$id}{name}) && $lists{$id}{name}  =~ /no associated published/){
            $lists{$id}{name} = "no publication";
         }
         $str = $lists{$id}{name};
       }
       next unless (defined($str));
       next if ($str eq '');
       if ( defined $dataset->{publication} ){
         $dataset->{publication} .= ";$str";
         $dataset->{publicationList} .= ";$str";
       }else{
          $dataset->{publication} = "$str";
          $dataset->{publicationList} = "$str";
       }
    }
  }
  %lists =();
  my %keywords = ();
  my @keywordList = $doctree->find_by_tag_name('KeywordList');
  foreach my $keyword (@keywordList){
     my @cvParams = $keyword->find_by_tag_name('cvParam');
     foreach my $cvParam ( @cvParams ) {
      if($cvParam->attr('value')){
       push @{$keywords{$cvParam->attr('name')}},  $cvParam->attr('value');
      }
    }
  }
  foreach my $key (keys %keywords){
    $dataset->{keywordList} .= "$key: ";
    $dataset->{keywordList} .= join(", ", @{$keywords{$key}});
    $dataset->{keywordList} .= "; ";
  }

  my @fullDatasetLinkList = $doctree->find_by_tag_name('FullDatasetLinkList');
  foreach my $fullDatasetLink (@fullDatasetLinkList){
     my @cvParams = $fullDatasetLink->find_by_tag_name('cvParam');
     foreach my $cvParam ( @cvParams ) {
      if($cvParam->attr('value') ne '' ){
         if ( $cvParam->attr('name') =~ /URI/i || $cvParam->attr('name') =~ /FTP/i){
           if ($cvParam->attr('name') =~ /PRIDE experiment URI/i){
             if ($cvParam->attr('value') =~ /.*=(\d+)/) {
               $dataset->{fullDatasetLinkList} .= '<a href='. $cvParam->attr('value') .
                                                '>'.  "PRIDE experiment $1 </a>;";
	     }
           } else {
           $dataset->{fullDatasetLinkList} .= '<a href='. $cvParam->attr('value') .
                                              '>'.  $cvParam->attr('name') .'</a>;';
           }
         }else{
           $dataset->{fullDatasetLinkList} .= $cvParam->attr('name') .": ". $cvParam->attr('value') .";";
         }
      }
    }
  }

  my @repositoryRecords  = $doctree->find_by_tag_name('RepositoryRecord');
  foreach my $repositoryRecord (@repositoryRecords){
    my $repositoryID = $repositoryRecord->attr('repositoryID');
    my $recordID = $repositoryRecord->attr('recordID');
    if ( $repositoryID and $recordID){
      foreach my $name (keys %{$repositoryRecord}){
        next if ($name =~ /^\_/ || $name =~ /(repositoryID|recordID)/);
        my $value = $repositoryRecord ->attr($name);
        $dataset->{repositoryRecordList}{$repositoryID}{$recordID}{ucfirst($name)} = $value;
      }
      my $PublicationRef = $repositoryRecord->find_by_tag_name ('PublicationRef');
      if ($PublicationRef){
        $dataset->{repositoryRecordList}{$repositoryID}{$recordID}{PublicationRef} = $PublicationRef->attr('ref');
      }
      my $InstrumentRef = $repositoryRecord->find_by_tag_name('InstrumentRef');
      if ($InstrumentRef){
        $dataset->{repositoryRecordList}{$repositoryID}{$recordID}{InstrumentRef} = $InstrumentRef->attr('ref');
      }
      my $ModificationList = $repositoryRecord->find_by_tag_name('ModificationList');
      if ($ModificationList){
        my @cvParams = $ModificationList -> find_by_tag_name('cvParam');
        foreach my $cvParam ( @cvParams ) {
          if ($cvParam->attr('name') ne '' ){
            $dataset->{repositoryRecordList}{$repositoryID}{$recordID}{ModificationList} .= $cvParam->attr('name') .", ";
          }
        }
      }
    }
  }

  #### Store the data and warnings in the response
  #push(@{$response->{info}},"+++ datasets Keys are: ".join(",",keys(%{$dataset})));
  $response->{dataset} = $dataset;
  $response->{warnings} = \@warnings;

  #push(@{$response->{info}},"+++ response Keys are: ".join(",",keys(%{$response})));
  return($response);
}


###############################################################################
# checkCvParam
###############################################################################
sub checkCvParam {
  my $METHOD = 'checkCvParam';
  my $self = shift || die ("self not passed");
  my %args = @_;

  my $paramAccession = $args{paramAccession};
  my $paramName = $args{paramName};
  my $paramValue = $args{paramValue};
  my $paramCvRef = $args{paramCvRef};

  #### Check all the CV params
  unless ($self->{cv}) {
    my $infile = '/net/dblocal/wwwspecial/proteomecentral/extern/PSI-MS/controlledVocabulary/psi-ms.obo';
    $self->readControlledVocabularyFile(input_file=>$infile);
    return unless ($self->{cv}->{status} eq 'read ok');
    $infile = '/net/dblocal/wwwspecial/proteomecentral/extern/PRIDE/schema/pride_cv.obo';
    $self->readControlledVocabularyFile(input_file=>$infile);
    $infile = '/net/dblocal/wwwspecial/proteomecentral/extern/PSI-MOD/data/PSI-MOD.obo';
    $self->readControlledVocabularyFile(input_file=>$infile);
    $infile = '/net/dblocal/wwwspecial/proteomecentral/extern/CELL/ontology/cl.obo';
    $self->readControlledVocabularyFile(input_file=>$infile);
    $infile = '/net/dblocal/wwwspecial/proteomecentral/extern/BRENDA/BrendaTissueOBO';
    $self->readControlledVocabularyFile(input_file=>$infile);
    $infile = '/net/dblocal/wwwspecial/proteomecentral/extern/DOID/doid.obo';
    $self->readControlledVocabularyFile(input_file=>$infile);
    $infile = '/net/dblocal/wwwspecial/proteomecentral/extern/Unimod/unimod.obo';
    $self->readControlledVocabularyFile(input_file=>$infile);
    my @tmp = ();
    $self->{cvErrors} = \@tmp;
  }

  my $accession = $paramAccession;
  my $name = $paramName;
  my $value = $paramValue;

  if ($accession =~ /\s/) {
    $self->addCvError(errorMessage=>"WARNING: term '$accession' has whitespace in it. This is not good.");
    $accession =~ s/\s//g;
  }

  unless ($name) {
    $self->addCvError(errorMessage=>"WARNING: term '$accession' does not have a corresponding name specified.");
  }

  if ($self->{cv}->{terms}->{$accession}) {
    if ($self->{cv}->{terms}->{$accession}->{name} eq $name) {
      #print "INFO: $accession = $name matches CV\n";
      $self->{cv}->{n_valid_terms}++;
    } elsif ($self->{cv}->{terms}->{$accession}->{synonyms}->{$name}) {
      #print "INFO: $accession = $name matches CV\n";
      $self->{cv}->{n_valid_terms}++;
    } else {
      $self->addCvError(errorMessage=>"WARNING: $accession should be ".
	"'$self->{cv}->{terms}->{$accession}->{name}' instead of '$name'");
      $self->{cv}->{mislabeled_terms}++;
      #print "replaceall.pl \"$name\" \"$self->{cv}->{terms}->{$accession}->{name}\" \$file\n";
    }

    #### Assess the correct presence of a value attribute
    my $shouldHaveValue = 0;
    my $hasValue = 0;
    if ($self->{cv}->{terms}->{$accession}->{datatypes}) {
      $shouldHaveValue = 1;
    }
    if (defined($value) && $value ne '') {
      $hasValue = 1;
    }
    if ($shouldHaveValue && $hasValue) {
      $self->{cv}->{correctly_has_value}++
    } elsif ($shouldHaveValue && ! $hasValue) {
      $self->addCvError(errorMessage=>"ERROR: cvParam $accession ('$name') should have a value, but it does not!");
      $self->{cv}->{is_missing_value}++
    } elsif (! $shouldHaveValue && $hasValue) {
      $self->addCvError(errorMessage=>"ERROR: cvParam $accession ('$name') has a value, but it should not!");
      $self->{cv}->{incorrectly_has_value}++
    } else {
      $self->{cv}->{correctly_has_no_value}++
    }

  } else {
    #### Exceptions
    if ($paramCvRef eq 'NEWT') {
      #### Skip for now
    } else {
      $self->addCvError(errorMessage=>"WARNING: CV term $accession ('$name') is not in the cv");
      $self->{cv}->{unrecognized_terms}++;
    }
  }

}


###############################################################################
# addCvError
###############################################################################
sub addCvError {
  my $METHOD = 'addCvError';
  my $self = shift || die ("self not passed");
  my %args = @_;

  my $errorMessage = $args{errorMessage} || '?? Unknown Error ??';
  $errorMessage = "CV $errorMessage";

  if ($self->{cvErrorHash} && $self->{cvErrorHash}->{$errorMessage}) {
    # It exists already, nothing to do
  } else {
    push(@{$self->{cvErrors}},$errorMessage);
  }

  #### Create or increment the counter
  $self->{cvErrorHash}->{$errorMessage}->{count}++;

  return;
}


###############################################################################
# readControlledVocabularyFile
###############################################################################
sub readControlledVocabularyFile {
  my $METHOD = 'readControlledVocabularyFile';
  my $self = shift || die ("self not passed");
  my %args = @_;

  my $input_file = $args{input_file};

  $self->{cv}->{status} = 'initialized';

  unless ($input_file) {
    $input_file = 'psi-ms.obo';
  }

  #### Check to see if file exists
  unless (-e $input_file) {
    print "ERROR: controlled vocabulary file '$input_file' does not exist\n";
    print "WARNING: NOT CHECKING CV TERMS!!!\n";
    return;
  }

  #### Open file
  unless (open(INFILE,$input_file)) {
    print "ERROR: Unable to open controlled vocabulary file '$input_file'\n";
    print "WARNING: NOT CHECKING CV TERMS!!!\n";
    return;
  }
  #print "INFO: Reading cv file '$input_file'\n";


  #### Read in file
  #### Very simple reader with no sanity/error checking
  my ($line,$id,$name,$synonym);
  while ($line = <INFILE>) {
    $line =~ s/[\r\n]//g;
    if ($line =~ /^id:\s*(\S+)\s*/) {
      $id = $1;
    }
    if ($line =~ /^name:\s*(.+)\s*$/) {
      $name = $1;
      $self->{cv}->{terms}->{$id}->{name} = $name;
    }
    if ($line =~ /^exact_synonym:\s*\"(.+)\"\s*[\[\]]*\s*$/) {
      $synonym = $1;
      $self->{cv}->{terms}->{$id}->{synonyms}->{$synonym} = $synonym;
    }
    if ($line =~ /^relationship:\s*has_units\s*(\S+) \! (.+)?\s*$/) {
      my $unit = $1;
      my $unitName = $2;
      $self->{cv}->{terms}->{$id}->{units}->{$unit} = $unitName;
    }
    if ($line =~ /^xref:\s*value-type:\s*(\S+)\s+\"/) {
      my $datatype = $1;
      $datatype =~ s/\\//g;
      $self->{cv}->{terms}->{$id}->{datatypes}->{$datatype} = $datatype;
    }
  }


  close(INFILE);
  $self->{cv}->{status} = 'read ok';

  return;

}

###############################################################################

1;
