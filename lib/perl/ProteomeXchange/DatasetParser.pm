package ProteomeXchange::DatasetParser;

###############################################################################
# Class       : ProteomeXchange::DatasetParser
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
#
# Description : This class is used to parser a ProteomeXchangeXML document
#
###############################################################################

use strict;
use lib "/local/wwwspecial/proteomecentral/lib/perl";
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
  my $uploadFilename = $args{'uploadFilename'};
  my $path = $args{path};
  #my $path = '/local/wwwspecial/proteomecentral/var/submissions';

  push(@{$response->{info}},"uploaded file path=$path");
  $response->{result} = "ERROR";
  $response->{message} = "Unable to process announcement: Unknown error";
  push(@{$response->{info}},"File has been uploaded. Begin processing it");

  if ( ! -f "$path/$uploadFilename" ) {
    $response->{message} = "Unable to parse file. Does not exist!";
    return($response);
  }

  my $dataset;

  use XML::TreeBuilder;

  #### EWD removed UTF-8 pragma, okayed by Zhi 2013-01-15. Not needed and
  #### can cause TreeBuilder to hang with some documents when used.
  #unless (open (FH, "<:encoding(UTF-8)", "$path/$uploadFilename")){

  unless (open (FH, "$path/$uploadFilename")){
    #### Unable to parse the XML for unknown reason
    $response->{message} = "Unable to parse the XML for unknown reason.";
    return($response);
  }

  my $doctree = XML::TreeBuilder->new();
  $doctree->parse(*FH);

  my ($datasetSummary) = $doctree->find_by_tag_name('DatasetSummary');
  $dataset->{title} = $datasetSummary->attr('title');
  $dataset->{broadcaster} = $datasetSummary->attr('broadcaster');
  $dataset->{announceDate} = $datasetSummary->attr('announceDate');
  $dataset->{PXPartner} = $datasetSummary->attr('hostingRepository');
  $dataset->{announcementXML} = $uploadFilename;

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
    #foreach my $list ( @lists ) {
    my  $list = $lists[0];
			my @cvParams = $list->find_by_tag_name('cvParam');
			foreach my $cvParam ( @cvParams ) {
        if ($cvParam->attr('value') ne ''){
          if ($tag eq 'Species'){
						$dataset->{speciesList} .=  $cvParam->attr('name') . ": ";
						$dataset->{speciesList} .= $cvParam->attr('value') . "; " ;
						$dataset->{speciesList} =~ s/taxonomy://;
            if ($cvParam->attr('name') =~ /scientific name/i){
              if ( $dataset->{species} ne '' ){
                $dataset->{species} .=  ", ". $cvParam->attr('value');
              }else{
                $dataset->{species} =  $cvParam->attr('value');
              }
              $dataset->{species} =~ s/\(\w+\)//;
            }
          }else{
            if (  $dataset->{lcfirst($tag)} eq ''){
              $dataset->{lcfirst($tag)} .=  "; ". $cvParam->attr('name') . ": ";
              $dataset->{lcfirst($tag)} .= $cvParam->attr('value');
            }else{
              $dataset->{lcfirst($tag)} =  $cvParam->attr('name') .": ";;
              $dataset->{lcfirst($tag)} .= $cvParam->attr('value');
            }
          }
        }else{
          if ( $dataset->{lcfirst($tag)} eq ''){
            $dataset->{lcfirst($tag)} =  $cvParam->attr('name') ;
          }else{
            $dataset->{lcfirst($tag)} .=  "; ". $cvParam->attr('name') ."; ";
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
    #}
  }

  unless ($dataset->{species}) {
    $response->{message} = "Unable to extract species from the submitted document";
    return($response);
    #### Error: Unable to extract species from the submitted document
  }

  
  my @contactLists = $doctree->find_by_tag_name('ContactList');
  my $first = 1;
  foreach my $contactList (@contactLists){
    my @lists =  $contactList->find_by_tag_name('Contact');
    foreach my $contact (@lists){
      my $id = $contact->attr('id');
      my @cvParams = $contact->find_by_tag_name('cvParam');
      foreach my $cvParam ( @cvParams ) {
        my $str =  $cvParam->attr('value');
        chomp $str;
        if ($cvParam->attr('name') eq "contact name" and $first) {
         $first = 0;
         $dataset->{primarySubmitter} = $cvParam->attr('value');
        }
        if($cvParam->attr('value') ne ''){
          $dataset->{contactList}{$id}{$cvParam->attr('name')} = $cvParam->attr('value');
        }
      }
    }
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
    if ($lists{$id}{name} =~ /reference/i){
      if (defined $lists{$id}{pubmedid} ){
        use ProteomeXchange::PubMedFetcher;
        my $PubMedFetcher = new ProteomeXchange::PubMedFetcher;
        my ($pubname, $pubmed_info) = $PubMedFetcher->getArticleRef(
          PubMedID=>$lists{$id}{pubmedid});
        $dataset->{publicationList} .= $pubmed_info;
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
       if ($lists{$id}{value} ne ''){ 
         $str = $lists{$id}{value};
       }else{
         if ( $lists{$id}{name}  =~ /no associated published/){
            $lists{$id}{name} = "no publication";
         }
         $str = $lists{$id}{name};
       }
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
             $cvParam->attr('value') =~ /.*=(\d+)/;
             $dataset->{fullDatasetLinkList} .= '<a href='. $cvParam->attr('value') .
                                              '>'.  "PRIDE experiment $1 </a>;";
           }else{
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
  $response->{dataset} = $dataset;

  return($response);
}

###############################################################################
1;

