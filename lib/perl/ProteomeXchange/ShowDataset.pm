package ProteomeXchange::ShowDataset;
###############################################################################
# Class       : ProteomeXchange::GetDataset
# Author      : Zhi Sun <zsun@systemsbiology.org>
#
# Description : list dataset
#
###############################################################################
use ProteomeXchange::Database;
use ProteomeXchange::DatasetParser;
use ProteomeXchange::Configuration qw(%CONFIG);

use strict;
use XML::Writer;
use Data::Dumper;
use JSON;

my $log_dir = ( $CONFIG{basePath} ) ? $CONFIG{basePath} . '/logs/' :
                                    '/net/dblocal/wwwspecial/proteomecentral/devDC/logs/';
my $log =  ProteomeXchange::Log->new( base => $log_dir, log_level => 'debug' );
my $baseUrl = $CONFIG{baseUrl} || 'http://www.proteomecentral.org';

$| = 1;
use CGI qw/:standard/;
my $cgi = new CGI;
our $CGI_BASE_DIR = $cgi->new->url();
$CGI_BASE_DIR =~ s/cgi.*/cgi/;

my $TESTSUFFIX = "_test";

###############################################################################
# Constructor
###############################################################################
sub new {
  my $self =shift;
  my %parameters = @_;
  my $class = ref($self) || $self;
  $self = { prev_time => time() } ;
  bless $self => $class;
  return $self;
}


###############################################################################
# listDatasets
###############################################################################
sub listDatasets {
  my $self = shift;
  my %args = @_;
  my $SUB_NAME = 'listDatasets';

  #$self->log_em( "List Datasets" );
  #### Decode the argument list
  my $params = $args{'params'};
  my $response = $args{'response'} || die("[$SUB_NAME] ERROR: response not passed");
  my $test = $params->{test} || 'no';
  my $filterstr = $params->{filterstr} || '';
  my $outputMode=$params->{outputMode} || 'html';
  my $extended = $params->{detailLevel} || '0';
  my $searchType = $params->{action} || '';

  my $table_name = 'dataset';
  my $teststr = '';
  my $path = '/local/wwwspecial/proteomecentral/var/submissions';

  if ($test && ($test =~ /yes/i || $test =~ /true/i)){
    $teststr = "&test=$test";
    $path .= "/testing";
    $table_name .= $TESTSUFFIX;
  }

  my $dbh = new ProteomeXchange::Database;
  my $whereclause = '';
  my %hidden_cols = ( );
  my @headings = ();

  if ($extended !~ /extended/i){
    $whereclause = "where status != 'ID requested'";
    %hidden_cols = (
      "Status" => 1,
      "Identifier Date"=> 1,
      "Primary Submitter"=> 1,
      "Revision Date" => 1,);
  }

  my  @column_array =(
    ["datasetIdentifier","Dataset Identifier"],
    ["title","Title"],
    ["PXPartner","Repos"],
    ["species","Species"],
    ["instrument","Instrument"],
    ["publication","Publication"],
    ["status","Status"],
    ["primarySubmitter","Primary Submitter"],
    ["labHead", "LabHead"],
    ["DATE_FORMAT(identifierDate,'\%Y-\%m-\%d')","Identifier Date"],
    ["DATE_FORMAT(submissionDate,'\%Y-\%m-\%d')","Announce Date"],
    ["DATE_FORMAT(revisionDate,'\%Y-\%m-\%d')","Revision Date"],
    ["keywordList", "Keywords" ],
    ["announcementXML", "announcementXML"],
      );

  my $columns_clause =  build_SQL_columns_list(
    column_array_ref=>\@column_array,
    hidden_cols_ref => \%hidden_cols,
    heading => \@headings);

  my $order_clause = "submissionDate DESC ";
  my $sql = qq~ SELECT
                 $columns_clause
                 FROM $table_name
                 $whereclause
                 ORDER BY $order_clause
             ~;

  my @rows = $dbh->selectSeveralColumns($sql);
  my @results = ();
  process_result(result =>\@rows,
                 newresult => \@results,
                 xmlloc => $path,
		 search_type=> $searchType,
		 filterstr => $filterstr,
		 heading => \@headings,
                 teststr => $teststr);

  if ($outputMode=~ /html/i){
    print qq~
         <div id="result">
        ~;
    print $cgi->start_table ({-border=>'0',
			      -cellspacing => '1',
			      -align => 'center',
			      -class => 'tablesorter',
			      -id => 'datatable'}) ,"\n";
    print "<thead>\n";
    pop @headings;
    print $cgi->Tr($cgi->th([@headings]));
    #$log->info($cgi->Tr($cgi->th([@headings])));
    print "\n</thead>\n<tbody>\n";
    my $cnt;
    if (@results){
      foreach my $row (@results){
	for (my $i=0; $i <= $#$row; $i++) {
	  $row->[$i] = '' unless $row->[$i];  # eliminate literally HUNDREDS of warning messages / page view
	}
	$cnt++;
	print $cgi->Tr($cgi->td([@$row]));
	print "\n";

	# This limits the number of rows shown on initial load, which makes
	# the apparent load time much quicker. Once loaded, the page does
	# an AJAX call to fetch more data and fill in the pager widget.
	last if $cnt >= 10 && !$searchType;
      }
    } else {
      ## if no result enter a blank row
      print "<tr>";
      foreach my $i (0..$#headings){
	print "<td></td>";
      }
      print "</tr>\n";
    }
    print "\n</tbody>\n";
    print $cgi ->end_table, "\n";

    print qq~
          <div id="pager" class="pager">
		<form>
		<img src="../javascript/image/first.png" class="first"/>
		<img src="../javascript/image/prev.png" class="prev"/>
		<input type="text" class="pagedisplay"/>
		<img src="../javascript/image/next.png" class="next"/>
		<img src="../javascript/image/last.png" class="last"/>
                <a> Page Size</a>
		<select class="pagesize">
			<option selected="selected"  value="10">10</option>
			<option value="20">20</option>
			<option value="30">30</option>
			<option value="50">50</option>
			<option value="100">100</option>
			<option value="500">500</option>
			<option value="1000">1000</option>
		</select>
		</form>
	</div>
      </div>\n
      ~;
    

    #### Or if output mode is 'xml', then wite results in XML
  } elsif ($outputMode=~ /xml/i) {
    print "Content-type:text/xml\r\n\r\n";
    my $writer = new XML::Writer(DATA_MODE => 1, DATA_INDENT => 4,ENCODING=>'UTF-8',);
    $writer->xmlDecl("UTF-8");
    $writer->startTag("ProteomeXchangeDataset",
		      "xmlns:xsi"=>"http://www.w3.org/2001/XMLSchema-instance",
		      "xsi:noNamespaceSchemaLocation"=>"proteomeXchange-draft-05.xsd",
		      "formatVersion"=>"1.0.0",
	);

    foreach my $values (@results) {
      $headings[0] =~ s/\s+/_/g;
      $writer->startTag($headings[0], ,id=>"$values->[0]");
      for (my $i=1;$i<=$#headings;$i++){
        $headings[$i] =~ s/\s+/_/g;
        $writer->startTag($headings[$i],);
        $writer->characters($values->[$i]);
        $writer->endTag($headings[$i]);
      }
      $writer->endTag($headings[0]);
    }
    $writer->endTag("ProteomeXchangeDataset");
    $writer->end();

    #### Or if the output mode is 'tsv', the write results in tab-separated values
  } elsif ($outputMode=~ /tsv/i) {
    print "Content-type:text/plain\r\n\r\n";
    foreach my $h (@headings){
      print "$h\t";
    }
    print "\n";
    foreach my $values (@results){
      print join("\t", @$values);
      print "\n";
    }

    #### Or if the output mode is 'json', the write results as JSON
  } elsif ($outputMode=~ /json/i) {
    print "Content-type: application/json\n\n";
    my $json = new JSON;

    my @datasets = ();
    foreach my $row ( @results ) {
      my %dataset = ();
      my $index = 0;
      foreach my $heading ( @headings ) {
	$dataset{$heading} = $row->[$index];
	$index++;
      }
      push(@datasets,\%dataset);
    }
    print $json->encode(\@datasets)."\n";

    #### Or if the output mode is not recognized, write a simple error
  } else {
    print "Content-type: text/plain\r\n\r\n";
    print "ERROR: Unrecognized outputMode '$outputMode'\n";
  }

  #$self->log_em( "Finished" );
}


#####################################################################
# log_em
#####################################################################
sub log_em {
  my $self = shift;
  my $msg = shift;
  my $curr = time();
  my $prev = $self->{prev_time};
  my $elapsed = $curr - $prev;
  print STDERR "LOG time $elapsed seconds\n";
  print STDERR "$msg\n";
  $self->{prev_time} = $curr;
}


#####################################################################
# printPageHeader
#####################################################################
sub printTablePageHeader {
  my $self = shift;
  my %args = @_;
  my $template = $args{template};
  my $params = $args{params};
  my $outputMode=$params->{outputMode} || 'html';

  if ($outputMode =~ /html/i){
    print "Content-type:text/html\r\n\r\n";
    my $last = 0;
    foreach my $line (@$template){
      if($line =~ /END main content/){
	$last =1;
      }
      next if ($last);

      if($line =~ /(TEMPLATESUBTITLE|TEMPLATETITLE)/){
	$line =~ s/$1/ProteomeXchange Datasets/;
	print "$line\n";
      } elsif ($line =~ /^<!-- BEGIN main content -->/) {
	print "$line\n";

        my $col_options = qq~ ;
		<option value="Title">Title</option>
		<option value="id">Dataset ID</option>
		<option value="AnnouncementDate">Date</option>
		<option value="Instrument">Instrument</option>
		<option value="Labhead">Lab Head</option>
                <option value="Publication">Publication</option>
		<option value="Repository">Repository</option>
		<option value="Species">Species</option>
		<option value="Psubmitter">Submitter</option>
		<option value="Keywords">Keywords</option>
         ~;

	my $cond_options = qq~;
          <option value="contain">Contains</option>
          <option value="notcontain">Does not contain</option>
          <option value="exactly">Is exactly</option>
          <option value="less">Is less than</option>
          <option value="greater">Is greater than</option>
         ~;
	my $str = qq~
           <div class="wrapper">
           <link rel="stylesheet" type="text/css" href="$baseUrl/javascript/css/button.css"/>
 	   <link rel="stylesheet" href="$baseUrl/javascript/css/table.css" type="text/css" media="print, projection, screen" />
           <script type="text/javascript" src="$baseUrl/javascript/js/jquery.js"></script>
           <script type="text/javascript" src="$baseUrl/javascript/js/tablesorter.pager.js"></script>
           <script type="text/javascript" src="$baseUrl/javascript/js/tablesorter.js"></script>
           <script type="text/javascript" src="$baseUrl/javascript/js/toggle.js"></script>
           <script type="text/javascript" src="$baseUrl/javascript/js/search.js"></script>
	 <script type="text/javascript">
			\$(function() {
				\$("#datatable")
					.tablesorter({widthFixed: true, widgets: ['zebra']})
					.tablesorterPager({container: \$("#pager")});
			});
			 </script>
           <br>

           <div class=infotext style="margin: auto; text-align: center"> Below is a listing of publicly accessible ProteomeXchange datasets. You can use the search box or interactive graphics to filter the list. </div>
        ~;

	$str .= "$args{inject_content}" if $args{inject_content};

	$str .= qq~
          <font face="Calibri">
          <div style="color:red;" id='basic_search'
            onclick='toggle_more("basic_search","advanced_search","buildQuery","searchContainer")'>
            &nbsp;&nbsp;&nbsp;&nbsp;[Go to Advanced Search]</div>
          <div id='advanced_search' onclick='toggle_less("advanced_search","basic_search","buildQuery","searchContainer")'
            style='display:none; color:red;'>&nbsp;&nbsp;&nbsp;&nbsp;[Go back to Basic free-text Search]</div>
          <div id='buildQuery' style='display: none; font-size:14px;'>
            &nbsp;&nbsp;&nbsp;&nbsp;Build your metadata query constraints below (not yet possible to query for individual proteins)
          <div style="padding:30px; font-size:18px;"><a style="color:red;" id="error"></a>
		<table cellpadding="10" >
        ~;
	my $cnt = 1;
	foreach my $sel ( qw(
				Title
				Instrument
				Publication
				AnnouncementDate
			)){
	  my $options2 = $cond_options;
	  if ($sel !~ /date/i){
	    $options2 =~ s/value="greater"/value="greater" disabled/;
	    $options2 =~ s/value="less"/value="less" disabled/;
	  }
	  if($cnt == 1){
	    $str .= qq~<tr><td align="position" valign="position" height="35">
				&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
				<select id="sel_col1" onchange="configureDropDownList(this,'sel_con1')">$col_options</select>
				</td><td>&nbsp;
				<select id="sel_con1">$options2</select>
			</td>
			<td>&nbsp;<input type="text" id="sel1"></input></td></tr>
			~;
	  } else {
	    my $options = $col_options;
	    $options =~ s/(value="$sel")/$1 selected="selected"/;
	    $str .= qq~
			<tr><td height="35">
			AND&nbsp;&nbsp;
			<select id="sel_col$cnt" onchange="configureDropDownList(this, \'sel_con$cnt\')">$options</select>
			</td><td>&nbsp;
			<select id="sel_con$cnt">$options2</select>
			</td>
			<td>&nbsp;<input type="text" id="sel$cnt"></input></td>
		~;
	    if($cnt == 4){
	      $str .= qq~
			<td>&nbsp;&nbsp;<input type="button" name="advsearchbtn" id="advsearchbtn" value="Advanced Search"/>
			&nbsp;&nbsp;<input  type="button" name="clear" id="clear" value="Clear"/>
			</tr>
							~;
	    } else {
	      $str .= "</tr>";
	    }
	  }
	  $cnt++;
	}
	$str .= qq~
		</table>
		</div></div></font>
		<div id="searchContainer">
		<div class=infotext>Search metadata for ProteomeXchange datasets: (e.g. "liver", "musculus", "5600", etc. Not yet possible to search for individual proteins)</div>
        <br>
		<input type="text" id="field" id="s" name="q">
		<div id="delete"><span id="x">x</span></div></input>
		<input type="button" name="searchbtn" id="searchbtn" value="Search" />
        <p><br>
		</div>
			~;
	print "$str";
      } else {
	print "$line";
      }

    }
  }
}

#####################################################################
# createPageHeader
#####################################################################
sub createPageHeader {
  my $self = shift;
  my %args = @_;

  my $template = $args{template};
  my $params = $args{params};
  my $outputMode=$params->{outputMode} || 'html';
  my $datasetID = $params->{ID} || $params->{id};

  #### If there is no datasetID, make up something
  $datasetID = 'PXD000000' unless ( $datasetID );

  #### Create a buffer for storing the content
  my $buf = '';

  #### Create a HTTP content preamble
  $buf .= "Status: 200 OK\r\nContent-type:text/html; charset=UTF-8\r\n\r\n";

  #### Loop over each line in the template, adjusting it
  foreach my $line ( @$template ){

    #### Some relic for fixing encoding??
    #if ($line =~/meta/){
    #  $line =~ s/utf-8/ISO-8859-1/;
    #}

    #### Adjust the title
    if ($line =~ /(TEMPLATESUBTITLE|TEMPLATETITLE)/){
      my $len = 9 - length($datasetID);
      my $title = $datasetID;
      $line =~ s/$1/ProteomeXchange Dataset $title/;
      $buf .= "$line\n";

      #### Obsolete adjustment??
    } elsif ($line =~ /class="node-inner-padding"/) {
      #$line =~ s/>/style="padding: 0">/g;
      $buf .= "$line\n";

      #### At the beginning of the main content area, add some custom code
    } elsif ($line =~ /^<!-- BEGIN main content -->/) {
      $buf .= "$line\n";
      $buf .= qq~
	 <link rel='stylesheet' id='style-css'  href='../javascript/css/patchwork.css' type='text/css' media='all' />
         <script type="text/javascript" src="/javascript/js/toggle.js"></script>
      ~;

      #### When we reach the END, terminate loop
    } elsif ($line =~ /END/) {
      last;

      #### Or if any other line, just pass through
    } else {
      $buf .= "$line";
    }

  } # end foreach

  return $buf;
}


#####################################################################
# printPagerFooter
#####################################################################
sub printPageFooter {
  my $self = shift;
  my %args = @_;
  my $template = $args{template};
  my $params = $args{params};
  my $outputMode=$params->{outputMode} || 'html';
  return if ($outputMode !~ /html/i);

  my $begin = 0;
  foreach my $line (@$template) {
    #### Inject some content at the end
    if ($line =~ /END main content/) {
      $begin = 1;
      print '';
      #print '<a href="http://www.proteomexchange.org/storys/how-get-informed-new-datasets-available-proteomexchange"><img width="50" height="15" src="/devED/images/subscribe_button-small.jpg"><font size="+1" color="#aa0000">Subscribe to receive all new ProteomeXchange announcements!</font></a>';
    }
    if ($begin) {
      print "$line";
    }
  }
}


#####################################################################
# process_result
#####################################################################
sub process_result{
  my %args = @_;
  my $result = $args{result};
  my $newresult = $args{newresult};
  my $searchType = $args{search_type};
  my $filterstr = $args{filterstr};
  my $xmlloc = $args{xmlloc};
  my $headings = $args{heading};
  my @headings = @$headings;
  my $teststr = $args{teststr};

  my @query_terms;
  if ($filterstr ne ''){
    if ($searchType !~ /^advsearch/){
      @query_terms = split(/\s+/, $filterstr);
    } else {
      @query_terms = split('\]\[',$filterstr);
      foreach (@query_terms){
        s/^\[//;
        s/\]$//;
      }
    }
  }

  my $kw_idx;
  for ( my $i = 0; $i <= $#headings; $i++ ) {
    if ( $headings[$i] eq 'Keywords' ) {
      $kw_idx = $i;
      last;
    }
  }

  foreach my $row (@$result){
    ## fix old publication link. open link to new tab by default
    $row->[5] ||= '';   # to silence perl warning when this is undefined
    if ($row->[5] =~ /href/ && $row->[5] !~ /blank/){
      $row->[5] =~ s/(href\s?=\s?"[^"]+")>/$1 target="_blank">/g;
    }

    if ($filterstr ne ''){
      my $matches = 0;
      if ( $searchType !~ /^advsearch/ ){
        foreach my $q (@query_terms){
	  no warnings qw(uninitialized);  # silence yet more warnings...
          my $match  = grep (/$q/i, @$row);
          ## search xml file also
          if ( $match eq ''){
            my $xml_file = $row->[$#headings];
            open (IN, "<$xmlloc/$xml_file") or die "cannot open $xml_file";
            my @lines = <IN>;
            $match = grep  (/$q/i,@lines);
          }
          if ($match){
            $matches++;
          }
        }
        next if ($matches < @query_terms);
	pop @$row;
	$row->[0] = "<a href=\"$CGI_BASE_DIR/GetDataset?ID=$row->[0]$teststr\" target=\"_blank\">$row->[0]</a>";
        $row->[$kw_idx] =~ s/,\s*$//ig if defined $kw_idx;
        $row->[$kw_idx] =~ s/;/,/ig if defined $kw_idx;
        $row->[$kw_idx] =~ s/submitter keyword:\s*//ig if defined $kw_idx;
        $row->[$kw_idx] =~ s/curator keyword:\s*//ig if defined $kw_idx;
        $row->[$kw_idx] =~ s/ProteomeXchange project tag:\s*//ig if defined $kw_idx;
	push @$newresult, $row;
      } else { ## advanced search
	foreach my $q (@query_terms){
	  my ($colname, $cond, $str) = split(/\|/, $q);
	  for(my $i =0; $i<= $#headings; $i++){
	    if ($headings[$i] =~ /$colname/i){
	      if ($cond =~ /^contain$/) {
		if ( $str =~ /^EXCLUSION/ ) {
		  my $ok = 1;
		  for my $excl ( split( /\./, $str ) ) {
		    if ( $row->[$i] =~ /$excl/i) {
		      $ok = 0;
		    }
		  }
		  $matches++ if $ok;
		} elsif ( $row->[$i] =~ /$str/i){
		  $matches++;
		}
	      } elsif ($cond =~ /^notcontain/){
		if ( $row->[$i] !~ /$str/i){
		  $matches++;
		}
	      } elsif ($cond =~ /exactly/){
		if ( $row->[$i] =~ /^$str$/i){
		  $matches++;
		}
	      }
	      if ($colname =~ /date/i){## two more conditions to check for date
		my $val1= $row->[$i];
		my $val2 = $str;
		$val1 =~ s/[\-\s]//g;
		$val2 =~s/[\-\s]//g;
		# format query date. make it have length 6
		my $zeros = '00000000';
		my $n = length($val2);
		$zeros =~ s/^.{$n}/$val2/;
		$val2 = $zeros;
		if($cond =~ /greater/i){
		  if ($val1 >= $val2){
		    $matches++;
		  }
		} elsif ($cond =~ /less/i){
		  if ($val1 <= $val2){
		    $matches++;
		  }
		}
	      }
	    }
	  }
	}
	next if ($matches < @query_terms);
	pop @$row;
	$row->[0] = "<a href=\"$CGI_BASE_DIR/GetDataset?ID=$row->[0]$teststr\" target=\"_blank\">$row->[0]</a>";

	$row->[$kw_idx] =~ s/,\s*$//ig if defined $kw_idx;
	$row->[$kw_idx] =~ s/;/,/ig if defined $kw_idx;
	$row->[$kw_idx] =~ s/submitter keyword:\s*//ig if defined $kw_idx;
	$row->[$kw_idx] =~ s/curator keyword:\s*//ig if defined $kw_idx;
	$row->[$kw_idx] =~ s/ProteomeXchange project tag:\s*//ig if defined $kw_idx;
	push @$newresult, $row;
      }## advanced search
    } else {
      pop @$row;
      $row->[0] = "<a href=\"$CGI_BASE_DIR/GetDataset?ID=$row->[0]$teststr\" target=\"_blank\">$row->[0]</a>";
      $row->[$kw_idx] =~ s/,\s*$//ig if defined $kw_idx;
      $row->[$kw_idx] =~ s/;/,/ig if defined $kw_idx;
      $row->[$kw_idx] =~ s/submitter keyword:\s*//ig if defined $kw_idx;
      $row->[$kw_idx] =~ s/curator keyword:\s*//ig if defined $kw_idx;
      $row->[$kw_idx] =~ s/ProteomeXchange project tag:\s*//ig if defined $kw_idx;
      push @$newresult, $row;
    }
  }
}


###############################################################################
# showDataset
###############################################################################
sub showDataset {
  my $self = shift;
  my %args = @_;
  my $SUB_NAME = 'showDataset';

  #### Decode the argument list
  my $params = $args{'params'} || die("[$SUB_NAME] ERROR: params not passed");
  my $response = $args{'response'} || die("[$SUB_NAME] ERROR: response not passed");
  my $outputmode = $params->{outputMode} || '';
  my $datasetID = $params->{ID} || die("[$SUB_NAME] ERROR: datasetID not passed");
  my $test = $params->{test} || 'no';
  my $headerStr = $args{headerStr};

  my $table_name = 'dataset';
  my $history_table_name = 'datasetHistory';
  my $path = '/local/wwwspecial/proteomecentral/var/submissions';
  my $teststr = '';

  #### If a PXT was provided, then we should be in test mode
  if ( $datasetID =~ /PXT/i ) {
    $test = "yes";
  }

  #### If test mode was specified, set everything to test mode and normalize $test
  if ($test && ($test =~ /yes/i || $test =~ /true/i || $test =~ /t/i)){
    $test = "true";
    $table_name .= $TESTSUFFIX;
    $history_table_name .= $TESTSUFFIX;
    $path .= "/testing";
    $teststr = "?test=$test";
  }

  #### Parse the input identifier and extract the various components
  my $prefix = '';
  if ( $datasetID =~ /^(R?PX[DT])/i ) {
    $prefix = $1;
    $datasetID =~ s/$prefix//;
    $datasetID =~ s/^0+//;
  }

  #### Parse out the reanalysis number if present
  my $inputReanalysisNumber = '';
  if ( $datasetID =~ /\.(\d+)/ ) {
    $inputReanalysisNumber = $1;
    $datasetID =~ s/\.\d+//;
  }

  #### Parse out the revision number if present
  my $inputRevisionNumber = '';
  if ( $datasetID =~ /-(\d+)/ ) {
    $inputRevisionNumber = $1;
    $datasetID =~ s/-\d+//;
  }

  my ($title,$status,$PXPartner,$announcementXML,$identifierDate,$datasetIdentifier,$datasetTitle);
  my ($datasetSubmitter,$datasetLabHead,$datasetSpeciesString);

  #### Find the record for this identifier and get the official identifier
  my $dbh = new ProteomeXchange::Database;
  my $sql = qq~
    SELECT datasetIdentifier,status
      FROM $table_name
     WHERE dataset_id = "$datasetID"
  ~;
  my @datasets = $dbh->selectSeveralColumns($sql);
  my $baseIdentifier = $datasets[0][0];
  $status = $datasets[0][1];

  #print STDERR "datasetID=$datasetID, inputReanalysisNumber=$inputReanalysisNumber, inputRevisionNumber=$inputRevisionNumber\n";

  #### Set the default status to be set later
  $response->{httpStatus} = "200 OK";
  $response->{status} = "OK";
  $response->{code} = "0";
  $response->{message} = "Request completed normally";

  my $str = '';
  my $containerStr = $str;
  my $nReanalyses = 0;
  $title  = $params->{ID};
  my $fullDatasetIDstr = $title;

  #### If a valid identifier was not obtained
  if ( $datasetID !~ /^\d+$/) {
    $response->{httpStatus} = "404 Malformed identifier";
    $response->{status} = "ERROR";
    $response->{code} = "1001";
    $response->{message} = "Identifier '$title' is not valid and should be of the form PXDnnnnnn or numbers only";
  }

  my $datasetIDstr = $datasetID;
  if ($response->{status} eq 'OK' ) {
    my $len = 9 - length($datasetID);
    $datasetIDstr = $baseIdentifier;
    $title = $datasetIDstr;
    $fullDatasetIDstr = $datasetIDstr;
    $fullDatasetIDstr .= ".$inputReanalysisNumber" if ( $inputReanalysisNumber );
    $fullDatasetIDstr .= "-$inputRevisionNumber" if ( $inputRevisionNumber );

    #### Fetch results from dataset table FIXME ! FIXME ! FIXME ! FIXME ! FIXME ! FIXME ! FIXME ! 
    $sql = qq~
               select datasetIdentifier
               from $table_name
               where dataset_id in (
               select dataset_id
               from $table_name
               where datasetOrigin like '%$datasetIDstr%')
              ~;
    my @derivedDatasets = $dbh->selectOneColumn($sql);

    #### If this is a reanalysis identifier, and there is no reanalysis number selected (or it's 0), show the container (0)
    my $entityType = "Dataset";
    if ( $baseIdentifier =~ /^RP/ && ! $inputReanalysisNumber ) {
      $inputReanalysisNumber = 0;
      $entityType = "Reanalysis Container";
    }

    #### Get all the record for this dataset from the history table
    $sql = qq~
        SELECT STATUS,PXPARTNER,ANNOUNCEMENTXML,IDENTIFIERDATE,DATASETIDENTIFIER,DATASETORIGIN,title,reanalysisNumber,revisionNumber
          FROM $history_table_name
         WHERE dataset_id=$datasetID
    ~;
    $sql .= "   AND revisionNumber = $inputRevisionNumber\n" if ( $inputRevisionNumber );
    $sql .= "   AND ( reanalysisNumber = $inputReanalysisNumber OR reanalysisNumber IS NULL )\n" if ( defined($inputReanalysisNumber) && $inputReanalysisNumber ne '' );
    $sql .= "   ORDER BY reanalysisNumber DESC, revisionNumber DESC\n";

    my @results = $dbh->selectSeveralColumns($sql);

    #### If no row was returned, then this identifer must not have been assigned yet
    if ( scalar(@results) == 0) {
      $response->{httpStatus} = "404 Identifier not assigned";
      $response->{status} = "ERROR";
      $response->{code} = "1002";
      $response->{message} = "The requested identifier has not yet been assigned to a repository";
    }


    #### Check the status of this dataset in the main table. If this dataset is not public yet, then set a special status to be handled later
    #### Note that this also catches datasets that have been "reverted", i.e. the main status set back to "ID requested". This really should be
    #### Handled better! FIXME.
    if ( $response->{status} eq 'OK' ) {
      $sql = qq~
        SELECT status,PXPartner,title
          FROM $table_name
         WHERE dataset_id=$datasetID
      ~;
      my @rows = $dbh->selectSeveralColumns($sql);
      ($status,$PXPartner,$title) = @{$rows[0]};
      if ( $status =~ /requested/ ) {
	$response->{status} = "DEFERRED";
      }
    }


    my ($selectedReanalysisNumber, $selectedRevisionNumber, $datasetOrigin);
    if ( $response->{status} eq 'OK' ) {

      #### Go through the result of the history table query to compute how many reanalyses there are
      my %reanalyses = ();
      foreach my $row ( @results ) {
	($status,$PXPartner,$announcementXML,$identifierDate,$datasetIdentifier,$datasetOrigin,$title,$selectedReanalysisNumber,$selectedRevisionNumber) = @{$row};
	$reanalyses{$selectedReanalysisNumber} = 1 if ( $selectedReanalysisNumber );
      }
      $nReanalyses = scalar(keys(%reanalyses));

      ($status,$PXPartner,$announcementXML,$identifierDate,$datasetIdentifier,$datasetOrigin,$title,$selectedReanalysisNumber,$selectedRevisionNumber) = @{$results[0]};
      $title = $datasetIdentifier;

      my $fullpath = $announcementXML ? "$path/$announcementXML" : "$path/";
      my $parser = new ProteomeXchange::DatasetParser;
      $parser->parse('announcementXML' => $announcementXML, 'response' => $response, filename=> $fullpath );
      my $result = $response->{dataset};

      my $header;

      #### Write out a little preamble based on what this is
      if ( $datasetIdentifier =~ /^PX/ ) {
	$str .= "$datasetIdentifier is an <b>original dataset</b> announced via ProteomeXchange.<BR><BR>";

      } elsif ( $datasetIdentifier =~ /^RPX/ ) {
	if ( ! defined($selectedReanalysisNumber) ) {
	  $str .= "$datasetIdentifier is an <b>old-style reanalysis</b> announcement missing a container. This dataset should be updated with a proper container and revision following 2019 ProteomeXchange protocols.<BR><BR>";
	  $entityType = "Outdated Reanalysis Missing a Container";

	} elsif ( $selectedReanalysisNumber == 0 ) {
	  $str .= "$datasetIdentifier is container for <b>one or more analyses</b>. The general container metadata is provided below and the table under Dataset History provides links to the various reanalyses have been provided (if any) in this container.<BR><BR>";
        } else {
	  $str .= "$datasetIdentifier.$selectedReanalysisNumber is a <b>reanalysis</b> of an original dataset. All reanalyses under this identifier are organized under a container with general attributes common to all reanalyses. Other reanalyses (if any) may be accessed by viewing the top-level container. Note that there may also be multiple revisions of each reanalysis, generally to correct errors.<BR><BR><H3>[<a href=\"GetDataset?ID=$datasetIdentifier&test=$test\">View Reanalysis Container $datasetIdentifier</a>]</H3><BR>";
        }
      }


      $str .= "<div class='dataset-secthead'>$entityType Summary</div>\n<table class='dataset-summary'>";
      foreach my $key ( qw( 
           title
           description
           PXPartner
           announceDate
           announcementXML
           DigitalObjectIdentifier
           ReviewLevel
           DatasetOriginList
           derivedDataset
           RepositorySupport
	   primarySubmitter
           speciesList
           modificationList
           instrument
        ) ) {

        $header =  ucfirst($key);
        if ($header eq 'PXPartner'){
          $header = 'HostingRepository';
	  $result->{$key} = $PXPartner unless ($result->{$key});
        }

	$result->{$key} ||= '';  # to silence perl warning when this is undefined

        if ($key eq 'announcementXML') {
          my $fullIdentifier = $baseIdentifier;
	  if ( defined($selectedReanalysisNumber) && $selectedReanalysisNumber gt "" ) { $fullIdentifier .= ".$selectedReanalysisNumber"; }
	  if ( defined($selectedRevisionNumber) && $selectedRevisionNumber gt "" ) { $fullIdentifier .= "-$selectedRevisionNumber"; }
          $str .= qq~
                <tr><td><b>$header</b></td><td><a href='GetDataset?ID=$fullIdentifier&outputMode=XML&test=$test' target="_blank">$result->{$key}</a></td></tr>
                ~;

        } elsif ($key eq 'DigitalObjectIdentifier') {
          $str .= qq~<tr><td><b>$header</b></td><td><a href="$result->{$key}" target="_blank">$result->{$key}</a></td></tr>~;

        } elsif ($key eq 'derivedDataset'){
           if(@derivedDatasets){
             $str .= '<tr><td><b>Reprocessed datasets that are derived from this dataset</b></td><td>';
             foreach my $acc (@derivedDatasets){
               $str .=  "<a href=\"GetDataset?ID=$acc&test=$test\" target=\"_blank\">$acc<\/a> " ;
             }
             $str .='</td></tr>';
           }

	#### Display the dataset Origin information
        } elsif ( $key eq 'DatasetOriginList' && defined($result->{$key}) && $result->{$key} ne '' ) {
	  foreach my $origin ( @{$result->{$key}} ) {
	    if ( exists($origin->{derived}) ) {
	      my $originalIdentifier = $origin->{identifier} || '??';
	      if ( $originalIdentifier =~ /PXD/ ) {
		$originalIdentifier = "<a href=\"GetDataset?ID=$originalIdentifier&test=$test\" target=\"_blank\">$originalIdentifier<\/a>";
	      } elsif ( $originalIdentifier =~ /MSV/ ) {
		$originalIdentifier = "<a href=\"https://www.omicsdi.org/dataset/massive/$originalIdentifier\" target=\"_blank\">$originalIdentifier<\/a>";
	      }
	      $str .= qq~<tr><td><b>DatasetOrigin</b></td><td>Reanalysis of $originalIdentifier</td></tr>~;
	    } elsif ( exists($origin->{original}) ) {
	      $str .= qq~<tr><td><b>DatasetOrigin</b></td><td>Original dataset</td></tr>~;
  	    } else {
	      $str .= qq~<tr><td><b>DatasetOrigin</b></td><td>Unknown</td></tr>~;
	    }
	  }

	} elsif ($key eq 'description') {
          $str .= qq~<tr><td><b>$header</b></td><td class='breakwords'>$result->{$key}</td></tr>~;

	} else {
          $str .= qq~<tr><td><b>$header</b></td><td>$result->{$key}</td></tr>~;
        }
      }

      $str .= "</table>\n";


      #### Display the dataset history
      $selectedReanalysisNumber ||= 0;    # to silence perl warning when this is undefined
      if ( $selectedReanalysisNumber == 0 ) {
	$str .= showDatasetHistory(dataset_id => $datasetID, test => $test, selectedReanalysisNumber => $selectedReanalysisNumber, selectedRevisionNumber => $selectedRevisionNumber );
      } else {
	$str .= showDatasetHistory(dataset_id => $datasetID, test => $test, selectedReanalysisNumber => $selectedReanalysisNumber, selectedRevisionNumber => $selectedRevisionNumber, containersOnly=>"true" );
      }


      #### Provide information on several of the major data lists
      foreach my $key (qw (publicationList keywordList contactList fullDatasetLinkList)){
	if ( defined $result->{$key}){
	  $header = ucfirst($key);
	  $header =~  s/([A-Z][a-z]+)/$1 /g;
	  $str .= "<div class='dataset-secthead'>$header</div>\n<table class='dataset-summary'>\n";
	  if ($key eq 'contactList'){
	    foreach my $id (keys %{$result->{contactList}}){
	      if ( defined $result->{contactList}{$id}{'contact name'}){
		$str .= "<tr><th colspan='2'>$result->{contactList}{$id}{'contact name'}</th></tr>\n";
	      } else {
		$str .= "<tr><th colspan='2'>$id</th></tr>\n";
	      }
	      foreach my $name (keys %{$result->{contactList}{$id}}){
		next if($name eq 'contact name');
		$result->{contactList}{$id}{$name} ||= '';  # to silence perl warning when this is undefined
		$str .= qq~<tr><td>$name</td><td>$result->{contactList}{$id}{$name}</td></tr>~;
	      }
	    }
	  } else {
	    my @lists = split (/; /,  $result->{$key});
	    foreach my $list(@lists) {
	      next if ($list !~ /\w/);
	      $str .= qq~<tr><td>$list</td></tr>~;
	    }
	  }
	  $str .= "</table>\n";
	}
      }

      if ( defined $result->{repositoryRecordList}){
        my $key = "repositoryRecordList";
        my $header = ucfirst($key);
        $header =~  s/([A-Z][a-z]+)/$1 /g;
        $str .= qq~
		 <div class='dataset-secthead'>$header</div>
                 <div id="less" onclick='toggle("less","more","repositoryRecordList")' title='Expand Record List'>[ + ]</div>
		 <div id="more" onclick='toggle("more","less","repositoryRecordList")' title='Hide Record List' style='display: none'>[ - ]</div>
		 <ul id="repositoryRecordList" style='display: none'>
        ~;

        foreach my $repositoryid (keys %{$result->{repositoryRecordList}}){
          $str .= "<li>$repositoryid<ol>";
          foreach my $recordid (keys %{$result->{repositoryRecordList}{$repositoryid}}){
            if (defined $result->{repositoryRecordList}{$repositoryid}{$recordid}{Uri}){
	      $str .= "<li><a href=\"$result->{repositoryRecordList}{$repositoryid}{$recordid}{Uri}\" target=\"_blank\">$recordid</a><ol>";
            }else{
	      $str .= "<li>$recordid<ol>";
            }
            foreach my $name (sort{$a cmp $b} keys %{$result->{repositoryRecordList}{$repositoryid}{$recordid}}){
	      next if($name =~ /Uri/);
	      $str .= "<li>$name: $result->{repositoryRecordList}{$repositoryid}{$recordid}{$name}</li>";
            }
            $str .= "</ol></li>";
          }
          $str .= "</li>";
        }
        $str .= "</ul>\n";
      }
    }

  } # end else


  if ( $status =~ /requested/ ) {
    $response->{httpStatus} = "404 Dataset not yet accessible";
    $response->{status} = "ERROR";
    $response->{code} = "1003";
    $response->{message} = "The identifier '$datasetIDstr' has been reserved but it not yet accessible";
    $str = getNotAccessibleMessage( identifier => $datasetIDstr, PXPartner => $PXPartner, title => $title );
  }


  #### If the output mode is XML, render output as XML
  if ( $outputmode =~ /XML/i || $outputmode =~ /JSON/i ) {

    #### If data was successfully accessed
    if ( $response->{status} eq 'OK' ) {

      #### If there's no filename available, error out
      if ( !defined($announcementXML) || $announcementXML eq '' ) {
        $response->{httpStatus} = "404 Dataset submission file undefined";
        $response->{status} = "ERROR";
        $response->{code} = "1004";
        $response->{message} = "Submission file for dataset '$title' is undefined";
        sendResponse(response=>$response);
        return;

      #### Else open and dump the file
      } else {

        #### If the file exists
        if ( -e "$path/$announcementXML" ) {
        
          if ( $outputmode =~ /XML/i ) {
            #### (switching to ISO-8859-1 seems to fix some special characters, but causes a complete Perl core dump in others. See emails of 2019-11-26)
            #open (INFILE, '<:encoding(ISO-8859-1)', "$path/$announcementXML" ) || die("ERROR: Unable to open $path/$announcementXML");
            open (INFILE, "$path/$announcementXML" ) || die("ERROR: Unable to open $path/$announcementXML");
            print "Content-type: text/plain\n\n";
            while ( my $inline = <INFILE> ) {
              print $inline;
            }
            close(INFILE);
          } else {
            my $proxiParser = new ProteomeXchange::DatasetParser; 
            my $result = $proxiParser->proxiParse(filename =>"$path/$announcementXML");
            print "Content-type: application/json\n\n";
            my $json = new JSON;
            print $json->encode($result->{proxiDataset})."\n";
          }

        #### Or if the file doesn't exist, error out
        } else {
          $response->{httpStatus} = "404 Dataset submission file unavailable";
          $response->{status} = "ERROR";
          $response->{code} = "1005";
          $response->{message} = "Submission file for dataset '$title' is not available at $announcementXML";
          sendResponse(response=>$response);
          return;
        }
      }

    #### Something went wrong, so just error out
    } else {
      sendResponse(response=>$response);
      return;
    }

  #### Otherwise present the information as an HTML page
  } else {

    #### If the dataset information is not being provided, then return status 404 per ELIXIR request
    if ( $headerStr ) {
      if ( $response->{status} ne 'OK' ) {
        $headerStr =~ s/200 OK/$response->{httpStatus}/;
      }
      print $headerStr;
    } else {
      $response->{httpStatus} = "500 Internal Error: No header available";
      $response->{status} = "ERROR";
      $response->{code} = "1098";
      $response->{message} = "Proper HTML header is not available. Please report to administrator.";
      sendResponse(response=>$response);
      return;
    }

    #### If there isn't some content already defined, there was probably an error, so set the content to the error message
    $str = $response->{message} unless ( $str );

    #### Show the dataset information window
    print qq~
       <div id="main">
       <a class="linkback" href="$CGI_BASE_DIR/GetDataset$teststr"> &lt;&lt;&lt; Full experiment listing </a>
       <div id="dataset-primary" class="site-content">
       <h1 class="dataset-title">$fullDatasetIDstr</h1>
    ~;


    #### If there are multiple reanalyses and no one specified, list them all in special content
    #### No longer relevant??
#    if ( 0 && $nReanalyses => 1 && ! $inputReanalysisNumber ) {
#      print qq~
#	<div class="entry-content">
#	$containerStr
#      ~;
#    #### Else show the card for this record
#    } else {
    print qq~
	<div class="dataset-content">
	$str
      ~;
#    }

    #### Finish the display card window
    print qq~
	 </div><!-- #content -->
	 </div><!-- #primary .site-content -->
	 </div><!-- #main -->
      ~;
  }

} # end showDataset


###############################################################################
# build_SQL_columns_list
###############################################################################
sub build_SQL_columns_list {
  my %args = @_;
  my $METHOD = 'build_SQL_columns_list';
  #### Process the arguments list
  my $column_array_ref = $args{'column_array_ref'} ||
      die "$METHOD: column_array_ref not passed!";
  my $hidden_cols_ref = $args{'hidden_cols_ref'};
  my $heading = $args{'heading'};

  my $columns_clause = "";
  my $element;
  foreach $element (@{$column_array_ref}) {
    next if ( defined $hidden_cols_ref->{$element->[1]});
    $columns_clause .= "," if ($columns_clause);
    $columns_clause .= "$element->[0]";

    push @$heading , $element->[1];
  }
  #### Return result
  return $columns_clause;

} # end build_SQL_columns_list


###############################################################################
# showDatasetHistory
###############################################################################
sub showDatasetHistory {
  my %args = @_;
  my $SUB_NAME = 'showDatasetHistory';

  #### Decode the argument list
  my $outputMode = $args{outputMode} || '';
  my $test = $args{test} || 'no';
  my $dataset_id = $args{dataset_id} || die("[$SUB_NAME] ERROR: dataset_id not passed");
  my $selectedReanalysisNumber = $args{selectedReanalysisNumber};
  my $selectedRevisionNumber = $args{selectedRevisionNumber};
  my $containersOnly = $args{containersOnly};
  my $str = '';

  my $tableName = "datasetHistory";
  $tableName .= $TESTSUFFIX if ($test =~ /yes|true/i);

  $str .= "<div class='dataset-secthead'>Dataset History</div>\n";
  #$str .= "test=$test  tableName=$tableName<BR>\n";

  $str .= "<table class=\"dataset-summary\">\n";

  my $sql = "SELECT dataset_id,datasetIdentifier,revisionNumber,reanalysisNumber,isLatestRevision,PXPartner,status,primarySubmitter,title,species,instrument,publication,keywordList,announcementXML,identifierDate,submissionDate,revisionDate,changeLogEntry FROM $tableName WHERE dataset_id = $dataset_id ORDER BY reanalysisNumber,revisionNumber,revisionDate";

  my $db = new ProteomeXchange::Database;

  #### Get the data from the database
  #### If the table is missing, this leads to a silent crash! FIXME
  my @rows = $db->selectSeveralColumns($sql);

  my $nRows = scalar(@rows);
  if (@rows) {
    #print "Successfully selected $nRows rows\n";
  } else {
    $str .= "<tr><td>History information is not currently available for this dataset</td></tr>\n";
    $str .= "</table>\n";
    return $str;
  }


  #### Print out the table of history information
  my $iRow = 0;
  foreach my $row ( @rows ) {
    my ( $dataset_id,$datasetIdentifier,$revisionNumber,$reanalysisNumber,$isLatestRevision,$PXPartner,$status,$primarySubmitter,$title,$species,$instrument,$publication,$keywordList,$announcementXML,$identifierDate,$submissionDate,$revisionDate,$changeLogEntry ) = @{$row};

    #### If this is the first row, then first print out the header
    if ( $iRow == 0 ) {
      $str .= "<tr>";
      my @columnTitles = ();
      push(@columnTitles,'Reanalysis') if ( $datasetIdentifier =~ /^RPX/ );
      push(@columnTitles,'Revision','Datetime','Status');
      if ( $datasetIdentifier =~ /^RP/ ) {
	push(@columnTitles,'Title / <I>ChangeLog Entry</I>');
      } else {
	push(@columnTitles,'ChangeLog Entry');
      }

      foreach my $item ( @columnTitles ) {
	$str .= "<th>$item</th>";
      }
      $str .= "</tr>\n";
    }

    #### For containersOnly, skip non-containers
    if ( $containersOnly && $containersOnly eq 'true' ) {
      if ( $reanalysisNumber != $selectedReanalysisNumber ) {
	$iRow++;
	next;
      }
    }

    #### Print out the row
    $str .= "<tr>";
    my $tdclass = '';
    my @columns = ();
    push(@columns,$reanalysisNumber) if ( $datasetIdentifier =~ /^RPX/ );
    push(@columns,$revisionNumber,$revisionDate||$submissionDate||$identifierDate,$status,$changeLogEntry);
    my $iColumn = 0;
    foreach my $item ( @columns ) {
      $item = '' unless (defined($item));

      #### If in RPXD mode, create hyperlinks for both reanalysis and revision
      if ( $datasetIdentifier =~ /^RP/ ) {

	#### Insert a hyperlink in the Reanalysis column
	if ( $iColumn == 0 && $item gt '') {
	  if ( $selectedReanalysisNumber gt '' && $reanalysisNumber == $selectedReanalysisNumber && $selectedRevisionNumber && $revisionNumber == $selectedRevisionNumber ) {
	    $tdclass = 'class="dataset-currentrev"';
          }
	  $item = "<a href=\"GetDataset?ID=$datasetIdentifier.$reanalysisNumber&test=$test\">$item</a>";
        } elsif ( $iColumn == 4 ) {
	  if ( $item > '' ) {
	    $item = "$title<BR><I>$item</I>";
 	  } else {
	    $item = "$title";
	  }
        }

	#### Insert a hyperlink in the Revision column
	if ( $iColumn == 1 && $item ) {
	  $item = "<a href=\"GetDataset?ID=$datasetIdentifier.$reanalysisNumber-$revisionNumber&test=$test\">$item</a>";
        }

      #### Otherwise, for just a PXD, create a hyperlink for revision only
      } else {
	#### Insert a hyperlink in the Revision column
	if ( $iColumn == 0 && $item ) {
	  if ( $selectedRevisionNumber && $revisionNumber == $selectedRevisionNumber ) {
	    $tdclass = 'class="dataset-currentrev"';
	    $item = "<span class='current'>&#9205;</span> $item";
          }
	  $item = "<a href=\"GetDataset?ID=$datasetIdentifier-$revisionNumber&test=$test\">$item</a>";
        }
      }

      $item =~ s/\n/<BR>\n/g;
      $str .= "<td $tdclass>$item</td>";
      $iColumn++;
    }
    $str .= "</tr>\n";
    $iRow++;

  }
  $str .= "</table>\n";

  return $str;
}


###############################################################################
# sendResponse
###############################################################################
sub sendResponse {
  my %args = @_;
  my $SUB_NAME = 'sendResponse';

  #### Decode the argument list
  my $response = $args{'response'} || die("[$SUB_NAME] ERROR: response not passed");

  #### Default HTTP code
  my $httpCode = "200 OK\n";

  #### If there's an explicit HTTP error code, then set it
  if ( $response->{httpStatus} ) {
    $httpCode = "$response->{httpStatus}\n";
  }

  #### Send HTTP header
  $httpCode = "Status: $httpCode" if ( $httpCode );
  print "${httpCode}Content-type: text/plain\n\n";

  #### Preferred status is the new status keyword but allow older result
  my $status = $response->{status} || $response->{result};
  
  print "result=$status\n";
  print "message=$response->{message}\n" if ($response->{message});
  print "identifier=$response->{identifier}\n" if ($response->{identifier});
  print "code=$response->{code}\n" if ($response->{code});

  #if ($response->{info} && $response->{verbose}) {
  if ($response->{info}) {
    foreach my $line (@{$response->{info}}) {
      print "info=$line\n";
    }
  }

  exit;
}


###############################################################################
# getNotAccessibleMessage
###############################################################################
sub getNotAccessibleMessage {
  my %args = @_;
  my $SUB_NAME = 'getNotAccessibleMessage';

  #### Decode the argument list
  my $identifier = $args{'identifier'} || die("[$SUB_NAME] ERROR: identifier not passed");
  my $PXPartner = $args{'PXPartner'} || die("[$SUB_NAME] ERROR: PXPartner not passed");
  my $title = $args{'title'};

  my $str = "ProteomeXchange dataset $identifier has been reserved by the $PXPartner repository for a dataset that has been deposited, ";

  if ( $title ) {
    $str .= "and it was announced as released, but then a problem was discovered, and the dataset was removed from circulation while the problem is being addressed.";
  } else {
    $str .= "but is not yet publicly released and announced to ProteomeXchange.";
  }
  $str .= "<BR><BR>";

  my $url = "??";
  my $contact = "??";

  if ( $PXPartner eq 'PRIDE' ) {

    $url = "https://www.ebi.ac.uk/pride/archive/login";
    $contact = "pride-support\@ebi.ac.uk";

    $str .= qq~
<B>If you are a reviewer of a manuscript that includes this dataset:</B><BR><BR>
<UL>
<LI> You should also have received a username and password to access this dataset $identifier.
<LI> If you did not, contact your manuscript editor about obtaining this information.
</UL>
~;

    $str .= qq~
<UL>
<LI> If you did, go to the <a href="$url">PRIDE Archive login page $url</a> to enter the reviewer credentials and access the data.
<LI> If you have questions or problems about this process, please contact <a href="mailto:$contact">$contact</a>
</UL>
    ~;

    $str .= qq~
<B>If you have seen this identifier in an accepted manuscript:</B><BR><BR>
<UL>
<LI> Then this dataset should be publicly released. Probably the authors and/or the journal have not contacted the original repository yet in order to trigger the public release.
<LI> Please go to the <a href="https://www.ebi.ac.uk/pride/archive/projects/$identifier/publish">PRIDE Publication Notification Page for this dataset</a> and enter in the citation information so that the dataset can be associated with the article and released.
</UL>
~;

  }


  if ( $PXPartner eq 'MassIVE' ) {

    $url = "http://massive.ucsd.edu/ProteoSAFe/QueryPXD?id=$identifier";
    $contact = "ccms\@proteomics.ucsd.edu";

    $str .= qq~
<B>If you are a reviewer of a manuscript that includes this dataset:</B><BR><BR>
<UL>
<LI> You should also have received a username and password to access this dataset $identifier.
<LI> If you did not, contact your manuscript editor about obtaining this information.
</UL>
~;

    $str .= qq~
<UL>
<LI> If you did, go to the <a href="$url">MassIVE dataset page $url</a> to enter the reviewer credentials and access the data.
<LI> If you have questions or problems about this process, please contact <a href="mailto:$contact">$contact</a>
</UL>
    ~;

    $str .= qq~
<B>If you have seen this identifier in an accepted manuscript:</B><BR><BR>
<UL>
<LI> Then this dataset should be publicly released. Probably the authors and/or the journal have not contacted the original repository yet in order to trigger the public release.
<LI> Please contact <a href="mailto:$contact">$contact</a> to request that the dataset be associated with the article and released.
</UL>
~;

  }


  $str .= qq~
<B>If you are just waiting for this dataset to be released:</B><BR><BR>
<UL>
<LI> The dataset has not yet been released.
<LI> Please check again later or contact the original data submitters to see when it will be public.
</UL>
~;

  return $str;
}


1;
