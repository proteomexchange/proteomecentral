package ProteomeXchange::PubMedFetcher;
###############################################################################
# Program     : ProteomeXchange::PubMedFetcher
# Author      : copy and modified from PeptideAtlas PubMedFetcher.pm
# $Id: PubMedFetcher.pm 7106 2012-06-07 21:44:25Z zsun $
#
# Description : This is part of the SBEAMS::Connection module which handles
#               getting data from NCBI's PubMed for a given PubMed ID.
#
# SBEAMS is Copyright (C) 2000-2005 Institute for Systems Biology
# This program is governed by the terms of the GNU General Public License (GPL)
# version 2 as published by the Free Software Foundation.  It is provided
# WITHOUT ANY WARRANTY.  See the full description of GPL terms in the
# LICENSE file distributed with this software.
#
###############################################################################

  use strict;
  use XML::Parser;
  use LWP::UserAgent;

  use vars qw($VERSION @ISA);
  use vars qw(@stack %info);

  @ISA = ();
  $VERSION = '0.1';

###############################################################################
# Constructor
###############################################################################
sub new {
    my $this = shift;
    my $class = ref($this) || $this;
    my $self = {};
    bless $self, $class;
    return($self);
}


###############################################################################
# get Pubmed id 
# input DOI  
###############################################################################
sub getPubmedID{
  my $SUB_NAME = 'getPubmedID';
  my $self = shift || die("$SUB_NAME: Parameter self not passed");
  my %args = @_;
  my $doi = $args{'DOI'};
  my $verbose = $args{'verbose'} || 0;

  unless ($doi){
     print "$SUB_NAME: Error: Parameter DOI not passed\n";
  }
  #### Get the XML data from NCBI
  my $url = 'http://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?'.
            'db=PubMed&retmode=xml&term='.$doi;
  my $xml = getHTTPData($url);

  print "------ Returned XML -------\n$xml\n-----------------------\n"
    if ($verbose > 1);
  %info = ();
  #### Set up the XML parser and parse the returned XML
  my $parser = new XML::Parser(
             Handlers => {
              Start => \&start_element,
              End => \&end_element,
              Char => \&characters,
             }
            );
  $parser->parse($xml);
  return  ($info{Id});

}
 

###############################################################################
# getArticleInfo
###############################################################################
sub getArticleRef {
  my $SUB_NAME = 'getArticleRef';
  my $self = shift || die("$SUB_NAME: Parameter self not passed");
  my %args = @_;

  my $PubMedID = $args{'PubMedID'} || '';
  my $verbose = $args{'verbose'} || 0;


  #### Return if no PubMedID was supplied
  unless ($PubMedID) {
    print "$SUB_NAME: Error: Parameter PubMedID not passed\n" if ($verbose);
    return 0;
  }


  #### Return if supplied PubMedID isn't all digits
  unless ($PubMedID =~ /^\d+$/) {
    print "$SUB_NAME: Error: Parameter PubMedID '$PubMedID'not valid\n"
      if ($verbose);
    return 0;
  }


  #### Get the XML data from NCBI
  my $url = "http://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?".
    "db=PubMed&id=$PubMedID&report=xml&mode=text";
  my $xml = getHTTPData($url);

  print "------ Returned XML -------\n$xml\n-----------------------\n"
    if ($verbose > 1);

  #### Return if no XML was returned
  unless ($xml) {
    print "$SUB_NAME: Error: No XML returned for PubMedID '$PubMedID'\n"
      if ($verbose);
    return 0;
  }

  %info = ();
  #### Set up the XML parser and parse the returned XML
  my $parser = new XML::Parser(
			       Handlers => {
					    Start => \&start_element,
					    End => \&end_element,
					    Char => \&characters,
					   }
			      );
  $parser->parse($xml);


  #### Generate a synthetic PublicationName based on AuthorList
  if ($info{AuthorList} && $info{PublishedYear}) {
	$info{AuthorList} =~ s/^\,//;
    my $publication_name = '';
    my @authors = split(', ',$info{AuthorList});
    my $n_authors = scalar(@authors);
    for (my $i=0; $i < $n_authors; $i++) {
      $authors[$i] =~ s/\ [A-Z]{1,4}$//;
    }
    $publication_name = $authors[0] if ($n_authors == 1);
    $publication_name = join(' & ',@authors) if ($n_authors == 2);
    $publication_name = $authors[0].', '.join(' & ',@authors[1..2])
      if ($n_authors == 3);
    $publication_name = $authors[0].' et al.' if ($n_authors > 3);
    $publication_name .= ' ('.$info{PublishedYear}.')';
    $info{PublicationName} = $publication_name;
  }

  #### If verbose mode, print out everything we gathered
  if ($verbose) {
    while (my ($key,$value) = each %info) {
      print "publication: $key=$value=\n";
    }
  }
  my $ref  = "$info{AuthorList}, $info{ArticleTitle} $info{MedlineTA}, $info{Volume}".
             "($info{Issue}):$info{MedlinePgn}($info{PublishedYear}) [".
             "<a href=\"http://www.ncbi.nlm.nih.gov/pubmed?term=$PubMedID\" target=\"_blank\">pubmed</a>]";
 
  return ($info{PublicationName}, $ref);

}



###############################################################################
# start_element
#
# Internal SAX callback function to start tags
###############################################################################
sub start_element {
  my $handler = shift;
  my $element = shift;
  my %attrs = @_;

  #### Push this element name onto a stack for later possible use
  push(@stack,$element);

  #### And that's it for now.  Maybe more processing needed eventually
  return;

}



###############################################################################
# end_element
#
# Internal SAX callback function to end tags
###############################################################################
sub end_element {
  my $handler = shift;
  my $element = shift;

  #### Just pop the top item off the stack.  It should be the current
  #### element, but we lazily don't check
  pop(@stack);

  #### And that's it for now.  Maybe more processing needed eventually
  return;

}



###############################################################################
# characters
#
# Internal SAX callback function to handle character data between tags
###############################################################################
sub characters {
  my $handler = shift;
  my $string = shift;
  my $context = $handler->{Context}->[-1];
	
  my %element_type = (
    PMID => 'reg',
    ArticleTitle => 'reg',
    AbstractText => 'reg',
    Volume => 'reg',
    Issue => 'reg',
    MedlinePgn => 'reg',
    MedlineTA => 'reg',
    LastName => 'append(AuthorList), ',
    Initials => 'append(AuthorList) ',
    Id  => 'reg'
  );

  if (defined($element_type{$context}) && $element_type{$context} eq 'reg') {
    $info{$context} = $string;
  }

  if (defined($element_type{$context}) &&
      $element_type{$context} =~ /^append\((.+)\)(.*)$/) {
				
    my $prepend = $2 || '';
    if (defined($info{$1})) {
      $info{$1} .= $prepend;
    } else {
      $info{$1} = '';
    }
    $info{$1} .= $string;
  }

  if ($context eq 'Year' && $handler->{Context}->[-2] eq 'PubDate') {
  
    $info{PublishedYear} = $string;
  }
  if (!defined $info{PublishedYear}  && $handler->{Context}->[-2] eq 'PubDate') {
  # 2001 Dec 20-27
    ($info{PublishedYear}) = $string =~ /^(\d{4})/;
    
  }  

}



###############################################################################
# getHTTPData
#
# Simple internal function to fetch data via HTTP
###############################################################################
sub getHTTPData {
  my $url = shift || die("getHTTPData: Must supply the URL");

  #### Create a user agent object pretending to be Mozilla
  my $ua = new LWP::UserAgent;
  $ua->agent("Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.0.0)");

  #### Create a request object with the supplied URL
  my $request = HTTP::Request->new(GET=>$url);

  #### Pass request to the user agent and get a response back
  my $response = $ua->request($request);

  #### Return the data
  if ($response->is_success) {
    return $response->content;
  } else {
    return '';
  }

}

###############################################################################

1;

__END__

###############################################################################
###############################################################################
###############################################################################

=head1 SBEAMS::Connection::PubMedFetcher

SBEAMS module for fetching article information for a specified article

=head2 SYNOPSIS

      use SBEAMS::Connection::PubMedFetcher;
      my $PubMedFetcher = new SBEAMS::Connection::PubMedFetcher;
      my $PubMedID = 123;

      my $pubmed_info = $PubMedFetcher->getArticleInfo(
        PubMedID=>$PubMedID,
      );

      if ($pubmed_info) {
        while (my ($key,$value) = each %{$pubmed_info}) {
          print "$key=$value=<BR>\n";
	}
      }


=head2 DESCRIPTION

This module provides a set of methods for obtaining article information
given a specified article.  At present, articles may only be specified
by PubMedID.  When the getArticleInfo() method is invoked with a PubMedID,
an HTTP request is sent to NCBI, the information for the article is returned
in XML format, the XML is parsed and certain interesting values are
extracted into a simple hash.


=head2 METHODS

=over

=item * B<getArticleInfo( see key value input parameters below )>

    Given a PubMedID, return a hash of attributes of the article.  See above
    module synopsis for an example of this method.

    INPUT PARAMETERS:

      PubMedID => Numeric PubMedID of the article for which information is
      desired.

      verbose => Set to TRUE to print error, warning, and diagnostic
      information

    OUTPUT:

      A hash reference of some article attributes if the fetch was
      successful, or 0 if the fetch was not successful.


=item * B<getHTTPData( $url )>

    This internal method is just a wrapper for LWP.  It returns the result
    from a URL in a string.

      my $url = 'http://db.systemsbiology.net/';
      my $result = getHTTPData($url);

    INPUT PARAMETERS:

      $url: a string containing the URL to fetch

    OUTPUT:

      A string containing the contents fetched from the specified URL or the
      empty string if the data could not be fetched.


=back

=head2 BUGS

Please send bug reports to the author

=head2 AUTHOR

Eric Deutsch <edeutsch@systemsbiology.org>

=head2 SEE ALSO

SBEAMS::Connection

=cut

