package ProteomeXchange::ArticleFinder;

use strict;
use warnings;

use Bio::Biblio;
use XML::Twig;

my $DEBUG = 0;

our %PubMedRecord;

###############################################################################
# Constructor
###############################################################################
sub new {
    my $this = shift;
    my $class = ref($this) || $this;
    my $self = {};
    bless $self, $class;

    #### Initialize class variables the first time the class is used
    # none

    #### Process constructor argument class variables
    my %args = @_;
    $self->setMassType($args{massType}) if ($args{massType});

    #### Process constructor argument object variables
    # none

    return($self);
}


###############################################################################
# findArticle
###############################################################################
sub findArticle {
  my $METHOD = 'findArticle';
  my $self = shift || die ("self not passed");
  my %args = @_;

  #### Process parameters
  my $searchTitle = $args{title};

  #### Prepare response
  my %result;
  $result{status} = 'ERROR';
  $result{message} = 'Unknown failure';

  #### Ensure there is something to search with
  unless ($searchTitle) {
    $result{message} = 'Unable to search without a valid title';
    return \%result;
  }

  #### Look for articles
  print "DEBUG[$METHOD]: Search by title: $searchTitle\n" if ($DEBUG);
  my $pubMed = Bio::Biblio->new(-access=> "eutils");
  my $searchResult = $pubMed->find($searchTitle, "title");
  my $pmids = $searchResult->get_all_ids();

  my $nMatches = scalar(@{$pmids});
  print "  $nMatches articles found\n" if ($DEBUG);

  if ($nMatches eq 0) {
    $result{status} = 'COMPLETE';
    $result{message} = 'No articles found';
    return \%result;
  }

  if ($nMatches > 60) {
    #print "Yikes, $nMatches matches found. Escape!";
    $result{status} = 'INCOMPLETE';
    $result{message} = 'Too many articles found';
    return(\%result);
  }

  print "  pmids = @$pmids\n" if ($DEBUG);

  my $parser = XML::Twig->new(twig_roots => {
    "ArticleTitle" => \&recordValue,
    "PubDate" => \&recordPubYear,
    "MedlineTA" => \&recordValue,
    "Author" => \&recordAuthor,
  } );

  for my $pmid (@$pmids) {
    my $xml = $pubMed->get_by_id($pmid);
    #print $xml;
    %PubMedRecord = ();
    eval {
      $parser->parse($xml);
    };
    if ($@) {
      warn "Problem parsing PubMed $pmid XML: $!\n";
    }

    $PubMedRecord{PMID} = $pmid;
    my $str = createReferenceString(PubMedRecord=>\%PubMedRecord);
    $result{title} = $PubMedRecord{ArticleTitle};
    $result{referenceString} = $str;
    $result{year} = $PubMedRecord{Year};

    #### Save each match
    if ($searchResult->{matches}) {
      my %tmp = %PubMedRecord;
      push(@{$searchResult->{matches}},\%tmp);
    } else {
      my %tmp = %PubMedRecord;
      my @tmp = [ \%tmp ];
      $searchResult->{matches} = \@tmp;
    }

  }

  $result{status} = 'COMPLETE';
  $result{message} = 'Article found';

  return(\%result);
}


###############################################################################
# callback recordArticleTitle
###############################################################################
sub recordValue {
  my ($twig, $elt) = @_;
  my $name = $elt->name;
  my $text = $elt->text;
  $PubMedRecord{$name} = $text;
  print "  -- $name = $text\n" if ($DEBUG);
  $twig->purge;
}

###############################################################################
# callback recordPubYear
###############################################################################
sub recordPubYear {
  my ($twig, $elt) = @_;
  my $name = 'Year';
  my $text = $elt->first_child_text;
  $PubMedRecord{$name} = $text;
  print "  -- $name = $text\n" if ($DEBUG);
  $twig->purge;
}

###############################################################################
# callback recordAuthor
###############################################################################
sub recordAuthor {
  my ($twig, $elt) = @_;
  my $name = 'FirstAuthor';
  my $text = $elt->first_child_text('LastName').", ".$elt->first_child_text('Initials');
  unless ($PubMedRecord{$name}) {
    $PubMedRecord{$name} = $text;
    print "  -- $name = $text\n" if ($DEBUG);
  }
  $twig->purge;
}

###############################################################################
# createReferenceString
###############################################################################
sub createReferenceString {
  my $METHOD = 'createReferenceString';
  my %args = @_;

  #### Process parameters
  my %PubMedRecord = %{$args{PubMedRecord}};

  my $str = $PubMedRecord{FirstAuthor}.'. et al. ('.
    $PubMedRecord{Year}.') '.$PubMedRecord{ArticleTitle}.', '.
    $PubMedRecord{MedlineTA}.', PMID '.$PubMedRecord{PMID};
  $PubMedRecord{referenceString} = $str;

  return($str);
}


###############################################################################
1;
