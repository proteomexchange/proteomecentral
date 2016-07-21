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
my $log_dir = ( $CONFIG{basePath} ) ? $CONFIG{basePath} . '/logs/' :
                                    '/net/dblocal/wwwspecial/proteomecentral/devDC/logs/';
my $log =  ProteomeXchange::Log->new( base => $log_dir, log_level => 'debug' );
my $baseUrl = $CONFIG{baseUrl} || 'http://www.proteomecentral.org';

$| = 1;
use CGI qw/:standard/;
my $cgi = new CGI;
our $CGI_BASE_DIR = $cgi->new->url();
$CGI_BASE_DIR =~ s/cgi.*/cgi/;

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

  $self->log_em( "List Datasets" );
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
    $table_name = 'dataset_test';
    $path .= "/testing";
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
				$log->info($cgi->Tr($cgi->th([@headings])));
				print "\n</thead>\n<tbody>\n";
        my $cnt;
        if (@results){
				  foreach my $row (@results){
            $cnt++;
					  print $cgi->Tr($cgi->td([@$row]));
            print "\n";

            # This limits the number of rows shown on initial load, which makes
            # the apparent load time much quicker. Once loaded, the page does
            # an AJAX call to fetch more data and fill in the pager widget.
            last if $cnt >= 10 && !$searchType;
				  }
        }else{
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


  }elsif($outputMode=~ /xml/i){
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
  }elsif($outputMode=~ /tsv/i){
    print "Content-type:text/plain\r\n\r\n";
    foreach my $h (@headings){
     print "$h\t";
    }
    print "\n";
    foreach my $values (@results){
     print join("\t", @$values);
     print "\n";
   }
  }

  $self->log_em( "Finished" );
}

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
# printPageHeader                                                     #
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
			}elsif ($line =~ /^<!-- BEGIN main content -->/){
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
					}else{
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
						}else{
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
     }else{
       print "$line";
     }

   }
  }
}

sub printPageHeader {
  my $self = shift;
  my %args = @_;
  my $template = $args{template};
  my $params = $args{params};
  my $outputMode=$params->{outputMode} || 'html';
  my $datasetID = $params->{ID} || $params->{id};
  #### Print the template
  print "Content-type:text/html; charset=ISO-8859-1\r\n\r\n";

  foreach my $line ( @$template ){
    #if ($line =~/meta/){
    #  $line =~ s/utf-8/ISO-8859-1/;
    #}
		if($line =~ /(TEMPLATESUBTITLE|TEMPLATETITLE)/){
			my $len = 9 - length($datasetID);
      my $title = $datasetID;
			$line =~ s/$1/ProteomeXchange Dataset $title/;
			print "$line\n";
		} elsif ($line =~ /class="node-inner-padding"/) {
			#$line =~ s/>/style="padding: 0">/g;
			print "$line\n";
		} elsif ($line =~ /^<!-- BEGIN main content -->/) {
      print "$line\n";
      print qq~
				<link rel='stylesheet' id='style-css'  href='../javascript/css/patchwork.css' type='text/css' media='all' />
        <script type="text/javascript" src="http://localhost/../javascript/js/toggle.js"></script>
        ~;
     }elsif($line =~ /END/){
        last;
     }else{
       print "$line";
     }
  }
}
#####################################################################
# printPagerFooter                                                    #
#####################################################################
sub printPageFooter {
  my $self = shift;
  my %args = @_;
  my $template = $args{template};
  my $params = $args{params};
  my $outputMode=$params->{outputMode} || 'html';
  return if ($outputMode !~ /html/i);

  my $begin =0;
  foreach my $line (@$template){
    if($line =~ /END main content/){
      $begin = 1;
			print '<a href="http://www.proteomexchange.org/storys/how-get-informed-new-datasets-available-proteomexchange"><img width="50" height="15" src="/devED/images/subscribe_button-small.jpg"><font size="+1" color="#aa0000">Subscribe to receive all new ProteomeXchange announcements!</font></a>';
    }
    if($begin){
      print "$line";
    }
  }
}
#####################################################################
# processresult                                                     #
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
  my $teststr=$args{teststr};

  my @query_terms;
  if ($filterstr ne ''){
    if ($searchType !~ /^advsearch/){
      @query_terms = split(/\s+/, $filterstr);
    }else{
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
    if ($row->[5] =~ /href/ && $row->[5] !~ /blank/){
       $row->[5] =~ s/(href\s?=\s?"[^"]+")>/$1 target="_blank">/g;
    }

    if ($filterstr ne ''){
      my $matches = 0;
      if ( $searchType !~ /^advsearch/ ){
        foreach my $q (@query_terms){
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
      }else{ ## advanced search
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
                }elsif ($cond =~ /^notcontain/){
                  if ( $row->[$i] !~ /$str/i){
                    $matches++;
                  }
                }elsif($cond =~ /exactly/){
                  if ( $row->[$i] =~ /^$str$/i){
                    $matches++;
                  }
                }
                if($colname =~ /date/i){## two more conditions to check for date
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
                    if($val1 >= $val2){
                      $matches++;
                    }
                  }elsif($cond =~ /less/i){
                    if($val1 <= $val2){
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
    }else{
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

  my $table_name = 'dataset';
  my $path = '/local/wwwspecial/proteomecentral/var/submissions';
  my $teststr = '';

  if ($test && ($test =~ /yes/i || $test =~ /true/i)){
    $table_name = 'dataset_test';
    $path .= "/testing";
    $teststr = "?test=$test";
  }

  my $prefix = '';
  if (($datasetID =~ /^(R?PXD)/i && $teststr eq '') ||
      ($datasetID =~ /^(R?PXT)/i && $teststr ne '')) {
    $prefix = $1;
    $datasetID =~ s/$prefix//;
    $datasetID =~ s/^0+//;
  }

  my ($title,$status,$PXPartner,$announcementXML,$identifierDate,$datasetIdentifier,$datasetTitle);
  my ($datasetSubmitter,$datasetLabHead,$datasetSpeciesString);


  my $pageStatus = 'OK';
  my $str = '';
  $title  = $params->{ID};

  #### If a valid identifier was not obtained
  if ( $datasetID !~ /^\d+$/) {
    $str = "The input identifier is not valid and should be of the form PXDnnnnnn or numbers only.";
    $pageStatus = 'ERROR';
  }

  if ($pageStatus eq 'OK') {
    my $len = 9 - length($datasetID);
    $title = substr ($prefix."000001",0, $len) . "$datasetID";
    #### Fetch results from dataset table
    my $dbh = new ProteomeXchange::Database;
    my $sql = qq~
               select datasetIdentifier
               from $table_name
               where dataset_id in (
               select dataset_id
               from $table_name
               where datasetOrigin like '%$title%')
              ~;
    my @derivedDatasets = $dbh->selectOneColumn($sql);
    $sql = qq~
                  SELECT STATUS,
                        PXPARTNER,
                        ANNOUNCEMENTXML,
                       IDENTIFIERDATE,
                       DATASETIDENTIFIER,
                       DATASETORIGIN
                  from $table_name
                  where dataset_id=$datasetID
              ~;
    my @results = $dbh->selectSeveralColumns($sql);

    #### If no row was returned, then this identifer must not have been assigned yet
    if ( scalar(@results) == 0) {
      $str = "The identifier $title has not yet been assigned. Please check the identifier and type it in again.";
      $pageStatus = 'ERROR';
    }
    #### If more than one row is returned, this suggests database corruption or some other problem
    if ( scalar(@results) > 1) {
      $str = "Too many rows returned. Please report error GDSsD0001 to administrator.";
      $pageStatus = 'ERROR';
    }

    if ( $pageStatus eq 'OK' ) {
      ($status,$PXPartner,$announcementXML,$identifierDate,$datasetIdentifier) = @{$results[0]};
      $title = $datasetIdentifier;

      #print "Content-Type: text/html\n\nLooking for data file <BR>\n";
      #print "Looking for data file $path/$announcementXML<BR>\n";

      my $parser = new ProteomeXchange::DatasetParser;
      $parser->parse('announcementXML' => $announcementXML, 'response' => $response, filename=> "$path/$announcementXML" );
      my $result = $response->{dataset};

      my $header;

      $str .= "<p> <b>DataSet Summary</b> </p>\n<ul>";
      foreach my $key ( qw( PXPartner
           announceDate
           announcementXML
           DigitalObjectIdentifier
           ReviewLevel
           datasetOrigin
           derivedDataset
           RepositorySupport
			     primarySubmitter
           title
           description
           speciesList
           modificationList
           instrument
        ) ) {

        $header =  ucfirst($key);
        if ($header eq 'PXPartner'){
          $header = 'HostingRepository';
					$result->{$key} = $PXPartner unless ($result->{$key});
        }

        if ($key eq 'announcementXML'){
          $str .= qq~
                <li><b>$header</b>: <a href='GetDataset?ID=$datasetID&outputMode=XML&test=$test' target="_blank">$result->{$key}</a></li>
                ~;
        } elsif ($key eq 'DigitalObjectIdentifier') {
          $str .= qq~<li><b>$header</b>: <a href="$result->{$key}" target="_blank">$result->{$key}</a></li>~;
        }elsif ($key eq 'derivedDataset'){
           if(@derivedDatasets){
             $str .= '<li><b>Reprocessed datasets that are derived from this dataset</b>: ';
             foreach my $acc (@derivedDatasets){
               $str .=  "<a href=\"GetDataset?ID=$acc&test=$test\" target=\"_blank\">$acc<\/a> " ;
             }
             $str .='</li>';
           }
        }elsif($key eq 'datasetOrigin'){
           if($result->{$key} =~ /ProteomeXchange accession.*PXD\d+/i){
             $result->{$key} =~ s#(PXD\d+)#<a href="GetDataset?ID=$1&test=$test" target="_blank">$1<\/a>#;
           }
           $str .= qq~<li><b>$header</b>: $result->{$key}</li>~;
        }else {
          $str .= qq~<li><b>$header</b>: $result->{$key}</li>~;
        }
      }
      $str .= "</ul>\n";


      #### Display the dataset history
      $str .= showDatasetHistory(dataset_id => $datasetID, test => $test);


      #### Provide information on several of the major data lists
      foreach my $key (qw (publicationList keywordList contactList fullDatasetLinkList)){
				if ( defined $result->{$key}){
          $header = ucfirst($key);
          $header =~  s/([A-Z][a-z]+)/$1 /g;
					$str .= "<p> <b>$header</b> </p>\n<ol>\n";
          if ($key eq 'contactList'){
            foreach my $id (keys %{$result->{contactList}}){
              if ( defined $result->{contactList}{$id}{'contact name'}){
                $str .= "<b>$result->{contactList}{$id}{'contact name'}</b>\n<ul>";
              } else {
                $str .= "<b>$id</b>\n<ul>";
              }
              foreach my $name (keys %{$result->{contactList}{$id}}){
                next if($name eq 'contact name');
                $str .= qq~<li>$name: $result->{contactList}{$id}{$name}</li> ~;
              }
              $str .= "</ul>\n";
            }
          } else {
						my @lists = split (";",  $result->{$key});
						foreach my $list(@lists){
							next if ($list !~ /\w/);
							$str .= qq~<li>$list</li>~;
						}
          }
					$str .= "</ol>\n";
        }
      }

      if ( defined $result->{repositoryRecordList}){
        my $key = "repositoryRecordList";
        my $header = ucfirst($key);
        $header =~  s/([A-Z][a-z]+)/$1 /g;
        $str .= qq~<tr>
					 <td><b>$header</b></td><td>
					 <div id="less" onclick='toggle("less","more","repositoryRecordList")' >[+]</div>
					 <div id="more" onclick='toggle("more","less","repositoryRecordList")' style='display: none'>[-]</div>
						</td></tr>
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


  if ( $pageStatus eq 'OK' && $status =~ /requested/ ) {
    $str = getNotAccessibleMessage( identifier => $title, PXPartner => $PXPartner );
    $pageStatus = 'ERROR';
  }


  #### Special handling if the output mode is XML
  if ( $outputmode =~ /XML/i ) {
    if ( $pageStatus eq 'OK' ) {

      #### If there's no filename available, error out
      if ( !defined($announcementXML) || $announcementXML eq '' ) {
				$response->{result} = "ERROR";
				$response->{message} = "no submission found for $params->{ID}\n";
				sendResponse(response=>$response);

      #### Else open and dump the file
      } else {

			#### If the file exists
			if ( -e "$path/$announcementXML" ) {
				open (INFILE, "$path/$announcementXML" ) || die("ERROR: Unable to open $path/$announcementXML");
				print "Content-type: text/plain\n\n";
				my $inline;
				while ($inline = <INFILE>) {
					print $inline;
				}
				close(INFILE);

				#### Or if the file doesn't exist, error out
				} else {
					$response->{result} = "ERROR";
					$response->{message} = "cannot find submission file $announcementXML\n";
					sendResponse(response=>$response);
					return;
				}
      }
    } else {
      $response->{result} = "ERROR";
      $response->{message} = $str;
      sendResponse(response=>$response);
      return;
    }

  #### Otherwise present the information as an HTML page
  } else {
		#### Show the dataset information window
     print qq~
       <div id="main">
       <div id="primary" class="site-content">
       <div><a href="$CGI_BASE_DIR/GetDataset$teststr"> << Full experiment listing </a></div>
        <h1 class="entry-title"> $title </h1>
     ~;


			#### Show what the tweet message would be
			use ProteomeXchange::Tweet;
			my $tweet = new ProteomeXchange::Tweet;
			$tweet->prepareTweetContent(
							datasetTitle => $datasetTitle,
							PXPartner => $PXPartner,
							datasetIdentifier => $title,
							datasetSubmitter  => $datasetSubmitter,
							datasetLabHead => $datasetLabHead,
							datasetSpeciesString => $datasetSpeciesString,
							datasetStatus => 'new',
			);

		 print qq~
				<div class="entry-content">
				$str
		 ~;
     #### Removed display of the tweet here. It wasn't working correctly anyway. Would be good to revive for testing.
		 #print "<BR><BR>".$tweet->getTweetAsHTML()."<BR><BR>";

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
  my $str = '';

  my $tableName = "datasetHistory";
  $tableName .= "_test" if ($test =~ /yes|true/i);

  $str .= "<p><b>Dataset History</b></p>\n";
  #$str .= "test=$test  tableName=$tableName<BR>\n";

  $str .= "<table class=\"table\" cellpadding=\"2\">\n";

  my $sql = "SELECT dataset_id,datasetIdentifier,identifierVersion,isLatestVersion,PXPartner,status,primarySubmitter,title,species,instrument,publication,keywordList,announcementXML,identifierDate,submissionDate,revisionDate,changeLogEntry FROM $tableName WHERE dataset_id = $dataset_id";

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

  $str .= "<tr>";
  foreach my $item ( 'Version','Datetime','Status','ChangeLog Entry' ) {
    $str .= "<td class=\"tableTitle\">$item</td>";
  }
  $str .= "</tr>\n";

  foreach my $row ( @rows ) {
    my ( $dataset_id,$datasetIdentifier,$identifierVersion,$isLatestVersion,$PXPartner,$status,$primarySubmitter,$title,$species,$instrument,$publication,$keywordList,$announcementXML,$identifierDate,$submissionDate,$revisionDate,$changeLogEntry ) = @{$row};

    $str .= "<tr>";
    foreach my $item ( $identifierVersion,$revisionDate||$submissionDate||$identifierDate,$status,$changeLogEntry ) {
      $item = '' unless (defined($item));
      $str .= "<td class=\"tableText\">$item</td>";
    }
    $str .= "</tr>\n";

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

  print "Content-type: text/plain\n\n";

  print "result=$response->{result}\n";
  print "message=$response->{message}\n" if ($response->{result});
  print "identifier=$response->{identifier}\n" if ($response->{identifier});

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

  my $str = qq~
ProteomeXchange dataset $identifier has been reserved by the $PXPartner repository for a dataset that has been deposited but is not yet publicly released and announced to ProteomeXchange.<BR><BR>
~;

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



