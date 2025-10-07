package ProteomeXchange::DatasetParser;

###############################################################################
# Class       : ProteomeXchange::DatasetParser
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
#
# Description : This class is used to parser a ProteomeXchangeXML document
#
###############################################################################

use strict;
use Data::Dumper;

use ProteomeXchange::Configuration qw( %CONFIG );


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
# proxiParse: Parse a ProteomeXchange XML file into a PROXI Dataset format
###############################################################################
sub proxiParse {
  my $self = shift;
  my %args = @_;
  my $SUB_NAME = 'proxiParse';

  #### Decode the argument list
  my $params = $args{'announcementXML'};
  my $filename = $args{'filename'};

  #### Set a default error message in case something goes wrong
  our $response;
  $response->{result} = "ERROR";
  $response->{message} = "Unable to parse file: Unknown error";

  #### Check the filename
  unless ( $filename ) {
    $response->{message} = "ERROR: [$SUB_NAME]: filename not specified!";
    return($response);
  }

  #### Check the file existence
  if ( ! -f $filename ) {
    $response->{message} = "Unable to parse file. Does not exist!";
    return($response);
  }

  #### Set up on basic structures

  #### dataset gets a generic XML structure import that is a bit cumbersome
  $response->{dataset} = { attributes=>{}, subelements=>[] };
  $response->{stack} = [ { name=>"dataset", addr=>$response->{dataset} } ];
  #### proxiDataset gets a special PROXI specific reformulation of the XML
  $response->{proxiDataset} = { };
  $response->{messages} = [];
  $response->{warnings} = [];
  $response->{errors} = [];

  #### Define a simplified mapping from PX XML to PROXI JSON
  our $mapping = { DatasetIdentifier => { name=>"identifiers", type=>"OntologyTerm" },
                   Species => { name=>"species", type=>"OntologyTermList" },
                   Instrument => { name=>"instruments", type=>"OntologyTerm" },
                   ModificationList => { name=>"modifications", type=>"OntologyTerm" },
                   Contact => { name=>"contacts", type=>"OntologyTermList" },
                   Publication => { name=>"publications", type=>"OntologyTermList" },
                   KeywordList => { name=>"keywords", type=>"OntologyTerm" },
                   FullDatasetLink => { name=>"fullDatasetLinks", type=>"OntologyTerm" },
                   DatasetFile => { name=>"datasetFiles", type=>"OntologyTerm" },
  };

  #### Open the file
  unless (open(INFILE,$filename)) {
    $response->{message} = "Unable to open the document '$filename'";
    return($response);
  }

  #### Set up the SAX Parser
  use XML::Parser;
  my $parser = XML::Parser->new(Handlers => {Start => \&proxiParse_start,
                                   End   => \&proxiParse_end,
                                   Char  => \&proxiParse_char});
 
  $parser->parse(*INFILE, ProtocolEncoding => 'UTF-8');
  close(INFILE);
 
  return($response);
}


###############################################################################
# proxiParse_start: proxiParser start tag handler
###############################################################################
sub proxiParse_start {
  my $SUB_NAME = 'proxiParse_start';
  our $response;
  our $previousParentAddr;
  our $previousContainerAddr;

  #### Decode the argument list
  my ($expat,$element,@attributes) = @_;
  my %attributes = @attributes;
  #print("  - start $element: ".join(",",@attributes)."\n");

  #### Find parent in the stack
  my @stack = @{$response->{stack}};
  my $topItem = $stack[-1];
  #print("    ( top item in stack is: ".Dumper($topItem)."\n");

  my $object = { $element => { attributes => \%attributes, subelements => [], subelement_by_name => {} } };
  push(@{$topItem->{addr}->{subelements}}, $object);
  $topItem->{addr}->{subelement_by_name}->{$element} = $object->{$element};

  push(@{$response->{stack}},{ name=>$element, addr=>$object->{$element} } );


  #### Custom code to build the PROXI Dataset object
  our $mapping;
  if ( $element eq "DatasetSummary" ) {
    $response->{proxiDataset}->{title} = $attributes{title};
  }

  #### Handle cvParam based on its parent
  if ( $element eq "cvParam" ) {
    my $parent = $topItem->{name};
    if ($mapping->{$parent} ) {
      if ( ! exists($response->{proxiDataset}->{$mapping->{$parent}->{name}}) ) {
        $response->{proxiDataset}->{$mapping->{$parent}->{name}} = [];
      }
      my %ontologyTerm = %attributes;
      delete($ontologyTerm{cvRef});

      #### Handle the OntologyTerm type of mapping
      if ( $mapping->{$parent}->{type} eq "OntologyTerm" ) {
        push(@{$response->{proxiDataset}->{$mapping->{$parent}->{name}}}, \%ontologyTerm);

      #### Handle the OntologyTermList type of mapping
      } elsif ( $mapping->{$parent}->{type} eq "OntologyTermList" ) {

        #### If this is the first term
        my $needNewContainer = 0;
        my $container = $previousContainerAddr;
        my $arrayLength = @{$response->{proxiDataset}->{$mapping->{$parent}->{name}}};
        if ( $arrayLength == 0 || ! defined($previousParentAddr) ) {
          $needNewContainer = 1;
          
        } elsif ( $topItem->{addr} ne $previousParentAddr ) {
          $needNewContainer = 1;
          $previousParentAddr = $topItem->{addr};
        }

        #print("needNewContainer=$needNewContainer, previousParentAddr=$previousParentAddr, topItemAddr=$topItem->{addr}\n");
        
        #### If we need a new container, create it
        if ( $needNewContainer == 1 ) {
          $container = [];
          my $ontologyTermList = { terms => $container };
          push( @{$response->{proxiDataset}->{$mapping->{$parent}->{name}}}, $ontologyTermList );
        }

        #### Add the current ontologyTerm
        push(@{$container}, \%ontologyTerm);

        $previousParentAddr = $topItem->{addr};
        $previousContainerAddr = $container;

      } else {
        die("ERROR: Unrecognized mapping type");
      }
    }
  }

  return;
}


###############################################################################
# proxiParse_end: proxiParser end tag handler
###############################################################################
sub proxiParse_end {
  my $SUB_NAME = 'proxiParse_end';
  our $response;

  #### Decode the argument list
  my ($expat,$element) = @_;

  #### Pop the top item off the stack and make sure it is the correct name
  my $object = pop(@{$response->{stack}});
  if ( $object->{name} ne $element ) {
    print("ERROR: Expected to find top element on the stack of $element, but found $object->{name}!\n");
    exit(11);
  }

  return;
}


###############################################################################
# proxiParse_char: proxiParser character handler
###############################################################################
sub proxiParse_char {
  my $SUB_NAME = 'proxiParse_char';
  our $response;

  #### Decode the argument list
  my ($expat,$characterData) = @_;
  return if ( $characterData =~ /^\s*$/ );

  my @stack = @{$response->{stack}};
  my $object = $stack[-1];
  $object->{addr}->{character_data} = $characterData;

  #### Custom code to build the PROXI Dataset object
  my $parent = $object->{name};
  if ( $parent eq "Description" ) {
    $response->{proxiDataset}->{description} = $characterData;
  }

  return;
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

  #### Check the filename
  unless ( $filename ) {
    $response->{message} = "ERROR: Filename not specified!";
    return($response);
  }
  if ( ! -f "$filename" ) {
    $filename =~ s/local/net\/dblocal/;
    if ( ! -f "$filename" ) {
      $response->{message} = "Unable to parse file. Does not exist!";
      return($response);
    }
  }

  my $dataset;
  my @messages = ();
  my @warnings = ();
  my @errors = ();


  #### Open the file
  #### (switching to ISO-8859-1 seems to fix some special characters, but causes a complete Perl core dump in others. See emails of 2019-11-26)
  #unless (open(FH,'<:encoding(ISO-8859-1)',$filename)){
  unless (open(FH,$filename)){
    $response->{message} = "Unable to open the document '$filename'";
    return($response);
  }


  #### Parse the XML into an addressable tree
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


  #### Extract the ChangeLogEntry. There could be multiple. Only the first is looked at here! FIXME
  my @changeLogEntries = $doctree->find_by_tag_name('ChangeLogEntry');
  my $iChangeLogEntry = 0;
  if (@changeLogEntries) {
    foreach my $changeLogEntry ( @changeLogEntries ) {
      if ( $iChangeLogEntry == 0 ) {
	$dataset->{changeLogEntry} = $changeLogEntry->attr('date').": ".$changeLogEntry->as_text();
      } else {
	$dataset->{changeLogEntry} .= "\n".$changeLogEntry->attr('date').": ".$changeLogEntry->as_text();
      }
      $iChangeLogEntry++;
    }
  }


  #### Extract the DatasetIdentifier
  my @datasetIdentifiers = $doctree->find_by_tag_name('DatasetIdentifier');
  foreach my $datasetIdentifier ( @datasetIdentifiers ) {
    my @cvParams = $datasetIdentifier->find_by_tag_name('cvParam');
    foreach my $cvParam ( @cvParams ) {
      if ($cvParam->attr('accession') eq "MS:1001919" || $cvParam->attr('name') eq "ProteomeXchange accession number") {
	$dataset->{identifier} = $cvParam->attr('value');
      }
      if ($cvParam->attr('accession') eq "MS:1001921" || $cvParam->attr('name') eq "ProteomeXchange accession version number") {
	$dataset->{revisionNumber} = $cvParam->attr('value');
      }
      if ($cvParam->attr('accession') eq "MS:1002997" || $cvParam->attr('name') eq "ProteomeXchange dataset identifier reanalysis number") {
	$dataset->{reanalysisNumber} = $cvParam->attr('value');
      }
      if ($cvParam->attr('name') =~ /Digital Object Identifier/){
	$dataset->{DigitalObjectIdentifier} =  "https://dx.doi.org/". $cvParam->attr('value');
      }
    }
  }

  #### Ensure that there is an identifier
  unless ($dataset->{identifier}) {
    $response->{message} = "Unable to extract PXD identifier";
    return($response);
  }

  #### Ensure that reanalysis rules are followed
  if ( $dataset->{identifier} =~ /^RPX/ ) {
    if ( defined($dataset->{reanalysisNumber}) ) {
      # good
    } else {
      $self->addCvError(errorMessage=>"ERROR: RPXD is missing a MS:1002997 reanalysis number");
    }
  } else {
    if ( defined($dataset->{reanalysisNumber}) ) {
      $self->addCvError(errorMessage=>"ERROR: An original data PXD should not have a reanalysis number");
    } else {
      # good
    }
  }


  #### Extract the DatasetOrigins
  my @datasetOriginTags = $doctree->find_by_tag_name('DatasetOrigin');
  my @datasetOrigins = ();
  foreach my $datasetOrigin ( @datasetOriginTags ) {
    my @cvParams = $datasetOrigin->find_by_tag_name('cvParam');
    my %origin = ();
    foreach my $cvParam ( @cvParams ) {
      if ($cvParam->attr('accession') eq "MS:1001919" || $cvParam->attr('name') eq "ProteomeXchange accession number") {
	$origin{identifier} = $cvParam->attr('value');
      } elsif ($cvParam->attr('accession') eq "MS:0002863" || $cvParam->attr('name') eq "Data derived from previous dataset") {
	$origin{derived} = 1;
      } elsif ($cvParam->attr('accession') eq "MS:1002868" || $cvParam->attr('name') eq "Original data") {
	$origin{original} = 1;
      } elsif ($cvParam->attr('accession') eq "MS:1002487" || $cvParam->attr('name') eq "MassIVE dataset identifier" ||
               $cvParam->attr('accession') eq "MS:1002872" || $cvParam->attr('name') eq "Panorama Public dataset identifier" ||
               $cvParam->attr('accession') eq "MS:1002836" || $cvParam->attr('name') eq "iProX Public dataset identifier" ||
               $cvParam->attr('accession') eq "MS:1002632" || $cvParam->attr('name') eq "jPOST Public dataset identifier" ||
               $cvParam->attr('accession') eq "MS:1002032" || $cvParam->attr('name') eq "PeptideAtlas dataset URI"
              ) {
	$origin{identifier} = $cvParam->attr('value');
      } else {
        $self->addCvError(errorMessage=>"ERROR: DatasetOrigin has unrecognized term '".$cvParam->attr('accession')."'");
      }
    }
    #### Do some basic checks on what we found and store it
    if ( $origin{original} ) {
      if ( $origin{derived} ) {
        $self->addCvError(errorMessage=>"ERROR: The same DatasetOrigin may not be both original and derived. Use separate DatasetOrigins");
      }
      if ( $origin{identifier} ) {
        $self->addCvError(errorMessage=>"ERROR: An original dataset may not reference an identifier. Use separate DatasetOrigins");
      }
      if ( $dataset->{identifier} !~ /^PX/ ) {
        $self->addCvError(errorMessage=>"ERROR: An original dataset identifier must begin with a PXD prefix, not RPXD");
      }
    } elsif ( $origin{derived} ) {
      unless ( $origin{identifier} ) {
        $self->addCvError(errorMessage=>"ERROR: A derived dataset must be accompanied by an identifier of some sort");
      }
      if ( $dataset->{identifier} !~ /^RPX/ ) {
	#### By general consensus, there are plausible scenarios for this being valid, so not and error any more
        #$self->addCvError(errorMessage=>"ERROR: A derived dataset identifier must begin with a RPXD prefix, not PXD");
      }
    } else {
      $self->addCvError(errorMessage=>"ERROR: Each DatasetOrigin must be either original or derived");
    }
    push(@datasetOrigins,\%origin);
  }
  $dataset->{datasetOriginAccession} = "DEPRECATED";
  $dataset->{DatasetOriginList} = \@datasetOrigins;


  #### Parse some other document sections generically
  foreach my $tag ( qw(Species Instrument ModificationList) ){
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
					#push(@warnings,'WARNING: There appears to be more than one dataset submitter. Only the first may appear in scalar uses.');
					push(@errors,'ERROR: There appears to be more than one dataset submitter. Only a single submitter may be specified.');
				} else {
					$dataset->{primarySubmitter} = $contact{'contact name'};
				}
      }

      if (exists($contact{'lab head'})) {
				if ($dataset->{labHead}) {
				        #### Now permitted as per group discussion
					#push(@warnings,'WARNING: There appears to be more than one lab head. Only the first may appear in scalar uses.');
					$dataset->{labHead} .= ", ".$contact{'contact name'};
				} else {
					$dataset->{labHead} = $contact{'contact name'};
				}
      }
    }
  }

  unless ($dataset->{primarySubmitter}) {
    push(@errors,"ERROR: No contact had the designation 'dataset submitter'.");
    $dataset->{primarySubmitter} = $firstContact{'contact name'};
  }
  unless ($dataset->{labHead}) {
    push(@errors,"ERROR: No contact had the designation 'lab head'");
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
       }elsif($cvParam->attr('name') =~ /Digital Object Identifier/i){
          $lists{$id}{DOI} = $cvParam->attr('value');
          $lists{$id}{name} = $cvParam->attr('name');
       }else{
         $lists{$id}{name} = $cvParam->attr('name');
         $lists{$id}{value} = $cvParam->attr('value');
       }
     }
   }
  }

  use ProteomeXchange::PubMedFetcher;
  my $PubMedFetcher = new ProteomeXchange::PubMedFetcher;
  my $sep='';
  foreach my $id (%lists){
    if (defined($lists{$id}{name}) && ($lists{$id}{name} =~ /reference/i || $lists{$id}{name} =~ /digital/i)){
      #if ( 0 ){    ##### !!!!!!!!!!!!!!!!!!!!!!!!!!! DISABLED
      if (defined $lists{$id}{pubmedid}){
        my ($pubname, $pubmed_info) = $PubMedFetcher->getArticleRef(
          PubMedID=>$lists{$id}{pubmedid});
        $dataset->{publicationList} .= "$sep$pubmed_info";
        $dataset->{publication} .= "$sep<a href=\"https://www.ncbi.nlm.nih.gov/pubmed/$lists{$id}{pubmedid}\" target=\"_blank\">$pubname</a>";;  
        $sep = '; ' if (!$sep);
      }elsif(defined $lists{$id}{DOI}){
         #my $pubmedid = $PubMedFetcher->getPubmedID(DOI=>$lists{$id}{DOI});
         #if ($pubmedid){
         #  my ($pubname, $pubmed_info) = $PubMedFetcher->getArticleRef(PubMedID=>$pubmedid);
         #  $dataset->{publicationList} .= "$sep$pubmed_info";
         #  $dataset->{publication} .= "$sep<a href=\"https://dx.doi.org/$lists{$id}{DOI}\">$pubname</a>";
         #}else{
           $dataset->{publication} .= "$sep<a href=\"https://dx.doi.org/$lists{$id}{DOI}\" target=\"_blank\">$lists{$id}{DOI}</a>";
           $dataset->{publicationList} .= "$sep<a href=\"https://dx.doi.org/$lists{$id}{DOI}\" target=\"_blank\">$lists{$id}{DOI}</a>;" || '';
         #}
         $sep = '; ' if (!$sep);
      }else{
         if ( defined $dataset->{publication} ){
           $dataset->{publicationList} .= "$sep$lists{$id}{value}";
           $dataset->{publication} .= "$sep$lists{$id}{value}";
         }else{
           $dataset->{publicationList} = "$sep$lists{$id}{value}";
           $dataset->{publication} = "$sep$lists{$id}{value}";
         }
         $sep = '; ' if (!$sep);
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
         $dataset->{publication} .= "; $str";
         $dataset->{publicationList} .= "; $str";
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
                                                ' target="_blank">'.  "PRIDE experiment $1 </a>; ";
	     }
           } else {
             $dataset->{fullDatasetLinkList} .= '<a href='. $cvParam->attr('value') .
                                              ' target="_blank">'.  $cvParam->attr('name') .'</a>';
             if ($cvParam->attr('name') =~ /FTP/i) {
               $dataset->{fullDatasetLinkList} .= "<BR>\n<b>NOTE:</b> Most web browsers have now discontinued native support for FTP access within the browser window. But you can usually install another FTP app (we recommend FileZilla) and configure your browser to launch the external application when you click on this FTP link. Or otherwise, launch an app that supports FTP (like FileZilla) and use this address: " . $cvParam->attr('value') . "; ";
	     } else {
               $dataset->{fullDatasetLinkList} .= "; ";
	     }
           }
         }else{
           $dataset->{fullDatasetLinkList} .= $cvParam->attr('name') .": ". $cvParam->attr('value') ."; ";
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
  $response->{errors} = \@errors;

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
    my $infile = "$CONFIG{basePath}/extern/CVs/psi-ms.obo";
    $self->readControlledVocabularyFile(input_file=>$infile);
    return unless ($self->{cv}->{status} eq 'read ok');

    #### The PRIDE CV is no longer supported
    #$infile = '/net/dblocal/wwwspecial/proteomecentral/extern/CVs/pride_cv.obo';
    #$self->readControlledVocabularyFile(input_file=>$infile);

    $infile = "$CONFIG{basePath}/extern/CVs/PSI-MOD.obo";
    $self->readControlledVocabularyFile(input_file=>$infile);
    $infile = '/net/dblocal/wwwspecial/proteomecentral/extern/CVs/cl.obo';
    $self->readControlledVocabularyFile(input_file=>$infile);
    $infile = '/net/dblocal/wwwspecial/proteomecentral/extern/CVs/BrendaTissueOBO';
    $self->readControlledVocabularyFile(input_file=>$infile);
    $infile = '/net/dblocal/wwwspecial/proteomecentral/extern/CVs/doid.obo';
    $self->readControlledVocabularyFile(input_file=>$infile);
    $infile = "$CONFIG{basePath}/extern/CVs/unimod.obo";
    $self->readControlledVocabularyFile(input_file=>$infile);
    my @tmp = ();
    $self->{cvErrors} = \@tmp;
  }

  my $accession = $paramAccession;
  my $name = $paramName;
  my $value = $paramValue;

  if ($accession =~ /\s/) {
    $self->addCvError(errorMessage=>"ERROR: term '$accession' has whitespace in it. This is not good.");
    $accession =~ s/\s//g;
  }

  unless ($name) {
    $self->addCvError(errorMessage=>"ERROR: term '$accession' does not have a corresponding name specified.");
  }

  #### Disallow the PRIDE CV now
  if ( $accession =~ /^PRIDE:/ ) {
    $self->addCvError(errorMessage=>"WARNING: the PRIDE CV will soon no longer supported at term '$accession'.");
    return;
  }

  if ($self->{cv}->{terms}->{$accession}) {
    if ($self->{cv}->{terms}->{$accession}->{name} eq $name) {
      #print "INFO: $accession = $name matches CV\n";
      if ( $name =~ /deprecated/i ) {
        $self->addCvError(errorMessage=>"ERROR: $accession:$name is a deprecated term. Deprecated terms should not be used");
        $self->{cv}->{n_deprecated_terms}++;
      } else {
        $self->{cv}->{n_valid_terms}++;
      }
    } elsif ($self->{cv}->{terms}->{$accession}->{synonyms}->{$name}) {
      #print "INFO: $accession = $name matches CV\n";
      $self->{cv}->{n_valid_terms}++;
    } else {
      if ( $accession =~ /^MOD:/ ) {
        #print "WARNING: As of 2021-02-08, strict checking of PSI-MOD is disabled";
      } else {
        my $available_synonyms = "";
        foreach my $avail_key ( keys %{$self->{cv}->{terms}->{$accession}->{synonyms}} ) {
          $available_synonyms .= "'$avail_key',";
        }
        if ( $available_synonyms ne "" ) {
          chop($available_synonyms);
          $available_synonyms = " (or synonyms $available_synonyms also okay)";
        }
        $self->addCvError(errorMessage=>"ERROR: $accession should be ".
          "'$self->{cv}->{terms}->{$accession}->{name}' instead of '$name'$available_synonyms");
        $self->{cv}->{mislabeled_terms}++;
        #print "replaceall.pl \"$name\" \"$self->{cv}->{terms}->{$accession}->{name}\" \$file\n";
      }
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
#    if ($paramCvRef eq 'NEWT') {
#      #### Skip for now
#    } else {
      $self->addCvError(errorMessage=>"ERROR: CV term $accession ('$name') is not in the cv");
      $self->{cv}->{unrecognized_terms}++;
#    }
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
    if ($line =~ /^synonym:\s*\"(.+)?\"/) {
      $synonym = $1;
      $self->{cv}->{terms}->{$id}->{synonyms}->{$synonym} = $synonym;
    }
    if ($line =~ /^relationship:\s*has_units\s*(\S+) \! (.+)?\s*$/) {
      my $unit = $1;
      my $unitName = $2;
      $self->{cv}->{terms}->{$id}->{units}->{$unit} = $unitName;
    }
    if ($line =~ /^relationship:\s*has_value_type\s*(\S+)\s+/) {
      my $datatype = $1;
      $datatype =~ s/\\//g;
      $self->{cv}->{terms}->{$id}->{datatypes}->{$datatype} = $datatype;
    }
  }

  #### Create reverse lookup keys
  foreach my $id ( keys(%{$self->{cv}->{terms}}) ) {
    my $name = $self->{cv}->{terms}->{$id}->{name};
    $self->{cv}->{names}->{$name} = $id;
  }

  close(INFILE);
  $self->{cv}->{status} = 'read ok';

  return;

}


###############################################################################
# correctXMLFile: Correct a ProteomeXchange XML file for certain known issues
###############################################################################
sub correctXMLFile {
  my $self = shift;
  my %args = @_;
  my $SUB_NAME = 'correctXMLFile';

  #### Decode the argument list
  my $filename = $args{'filename'};

  #### Set a default error message in case something goes wrong
  my $response;
  $response->{result} = "ERROR";
  $response->{message} = "ERROR: Unable to parse file: Unknown error";

  #### Check the filename
  unless ( $filename ) {
    $response->{message} = "ERROR: Filename not specified!";
    return($response);
  }
  if ( ! -f "$filename" ) {
    $filename =~ s/local/net\/dblocal/;
    if ( ! -f "$filename" ) {
      $response->{message} = "ERROR: Unable to parse file. Does not exist!";
      return($response);
    }
  }


  #### Get the properties of the original file and open it
  my @properties = stat($filename);
  my $mode = $properties[2];

  #### Open the input file
  unless (open(INFILE,$filename)){
    $response->{message} = "ERROR: Unable to open the document '$filename'";
    return($response);
  }

  #### Loop through the file, putting the lines into an array
  my @xmlArray;
  while ( my $line = <INFILE> ) {
    push(@xmlArray,$line);
  }

  close(INFILE);

  $response = $self->correctXML( xmlArray=>\@xmlArray );

  #### If there was a change made, then mv the change file to the
  #### original file and set the original mode
  if ( $response->{nXmlChanges} ) {

    #### Open the input file
    my $outputFilename = "$filename.tmp";
    unless (open(OUTFILE,">$outputFilename")){
      $response->{message} = "ERROR: Unable to open the temporary output file '$outputFilename'";
      return($response);
    }

    #### Write out the new XML
    foreach my $line ( @{$response->{xmlArray}} ) {
      print OUTFILE $line;
    }
    close(OUTFILE);

    #### Check that the new file seems good
    my @newProperties = stat($outputFilename);
    my $originalSize = $properties[7];
    my $newSize = $newProperties[7];
    if ( $originalSize && $newSize && $newSize*1.05 > $originalSize ) {
      rename($outputFilename,$filename);
      chmod($mode,$filename);
      $response->{message} = "File fixed";
    } else {
      $response->{result} = "FileSizesProblem";
      $response->{message} = "ERROR: Original file size $originalSize and new file size $newSize, which is a suspected problem. Aborting.";
    }

  #### If no change was made, then just remove the change file
  } else {
    $response->{message} = "No change needed";
  }

  return($response);
}


###############################################################################
# correctXML: Correct a ProteomeXchange XML for certain known issues
###############################################################################
sub correctXML {
  my $self = shift;
  my %args = @_;
  my $SUB_NAME = 'correctXML';

  #### Decode the argument list
  my $xmlArray = $args{'xmlArray'};

  #### Set a default error message in case something goes wrong
  my $response;
  $response->{result} = "ERROR";
  $response->{message} = "ERROR: Unable to parse XML: Unknown error";

  #### Check the xmlArray
  unless ( $xmlArray ) {
    $response->{message} = "xmlArray is undefined";
    return($response);
  }
  my $nLines = scalar(@{$xmlArray});
  unless ( $nLines ) {
    $response->{message} = "xmlArray has no lines";
    return($response);
  }

  #### Load the PRIDE CV if it has not already been loaded
  unless ( exists($self->{PRIDEcv}) ) {

    #### But if we've already loaded the main CV, then stash it away temporarily
    if ( exists($self->{cv}) ) {
      $self->{Savedcv} = $self->{cv};
      delete($self->{cv});
    }

    my $cvfile = '/net/dblocal/wwwspecial/proteomecentral/extern/CVs/pride_cv.obo';
    print "INFO: Loading PRIDE CV\n";
    $self->readControlledVocabularyFile(input_file=>$cvfile);
    unless ($self->{cv}->{status} eq 'read ok') {
      $response->{message} = "ERROR: Unable to read PRIDE CV";
    }
    #### Since the two CVs will have overlapping names, move the PRIDE CV data structure to its own name space
    $self->{PRIDEcv} = $self->{cv};
    delete($self->{cv});

    #### Load the PSI-MS CV, unless it's already been stashed
    if ( exists($self->{Savedcv} ) ) {
      $self->{cv} = $self->{Savedcv};
      delete($self->{Savedcv});
    } else {
      $cvfile = '/net/dblocal/wwwspecial/proteomecentral/extern/CVs/psi-ms.obo';
      print "INFO: Loading PSI-MS CV\n";
      $self->readControlledVocabularyFile(input_file=>$cvfile);
      unless ($self->{cv}->{status} eq 'read ok') {
        $response->{message} = "ERROR: Unable to read PSI-MS CV";
      }
    }
  }

  #### Prepare a new array for the changed result
  my @newArray;
  my $nXmlChanges = 0;

  #### Loop through the file, looking for problems to fix
  foreach my $line ( @{$xmlArray} ) {
    if ( $line =~ /pride_cv\.obo/ ) {
      print "  -- Removing $line";
      next;
    } elsif ( $line =~ /(PRIDE:\d+)/ ) {
      my $prideAccession = $1;
      my $termName = $self->{PRIDEcv}->{terms}->{$prideAccession}->{name};
      if ( $termName ) {
	my $psiMsAccession = $self->{cv}->{names}->{$termName};
	if ( $psiMsAccession ) {
	  print("  -- Replacing $prideAccession --> $psiMsAccession ($termName)\n");
	  $line =~ s/$prideAccession/$psiMsAccession/g;
	  $line =~ s/cvRef="PRIDE"/cvRef="MS"/g;
	  $nXmlChanges++;
        } else {
	  print("  ERROR: Unable to find match for $prideAccession ($termName)\n");
        }
      } else {
	print("  ERROR: Unable to find $prideAccession in CV\n");
      }
    }
    push(@newArray,$line);
  }

  $response->{result} = "OK";
  $response->{xmlArray} = \@newArray;
  $response->{nXmlChanges} = $nXmlChanges;
  $response->{message} = "$nXmlChanges changes made to XML";
  return($response);
}


###############################################################################
1;
