#!/usr/local/bin/perl -w

use strict;
use FindBin;
use lib "$FindBin::Bin/../lib/perl";

use JSON;
use ProteomeXchange::Dataset;
use ProteomeXchange::DatasetParser;
$| = 1;
use CGI qw/:standard/;
my $cgi = new CGI;
$cgi->charset('utf-8');


my $response = {};
$response->{result} = "ERROR";
$response->{message} = "ERROR: Unhandled exception E001";
my @tmp = ( 'Dataset service start' );
$response->{info} = \@tmp;

my $params;
my @parameters = qw ( test verbose action ID filterstr outputMode detailLevel limit start sort);

#### Extract CGI parameters
foreach my $parameter ( @parameters ) {
  if ($cgi->param($parameter)) {
    $params->{$parameter} = $cgi->param($parameter);
  	push(@{$response->{info}},"Found input parameter $parameter=$params->{$parameter}") if ($cgi->param('verbose'));
  }
}
#### Also extract command-line parameters, useful for testing
foreach my $arg ( @ARGV ) {
  if ( $arg =~ /(\S+)=(.*)/) {
    my $key = $1;
	  my $value = $2;
		foreach my $parameter ( @parameters ) {
			if ($key eq $parameter) {
				$params->{$parameter} = $value;
				push(@{$response->{info}},"Found input parameter $key=$value");
			}
		}
  }# else {
   #  $response->{message} = "ERROR: Unable to parse method line parameter '$arg'\n";
	 #  exit;
  #}
}

if ($params->{ID}  and $params->{ID} ne '') {
  showDataset(params=>$params,response=>$response);
}else{
  listDatasets(params=>$params,response=>$response);
}
exit(0);
###############################################################################
# listDatasets
###############################################################################
sub  listDatasets {
  my %args = @_;
  my $SUB_NAME = 'listDatasets';

  #### Decode the argument list
  my $params = $args{'params'}; 
  my $response = $args{'response'} || die("[$SUB_NAME] ERROR: response not passed");
  my $test = $params->{test} || 'no';
  my $filterstr = $params->{filterstr} || '';
  my $outputMode=$params->{outputMode} || 'html';
  my $extended = $params->{detailLevel} || '0';
  my $pageStart = $params->{start} || 0;
  my $pageLimit = $params->{limit} || 10;
  my $searchType = $params->{action} || '';
 
  my $table_name = 'dataset';
  my $teststr = '';
  my $path = '/local/wwwspecial/proteomecentral/var/submissions/';
  if ($test && ($test =~ /yes/i || $test =~ /true/i)){
    $teststr = "&test=$test";
    $table_name = 'dataset_test';
    $path = "$path/testing";
  }
	my $dbh = new ProteomeXchange::Database;
  my $whereclause = '';
  my %hidden_cols = ();
  my @headings = (); 
 
  if ($extended !~ /extended/i){
    $whereclause = "where status != 'ID requested'";
    %hidden_cols = (
                  "Status" => 1,
                  "IdentifierDate"=> 1,
                  "RevisionDate" => 1,);
  }

  my  @column_array =(
        ["datasetIdentifier","id"],
        ["PXPartner","Repository"],
        ["status","Status"],
        ["primarySubmitter","PSubmitter"],
        ["labHead", "LabHead"],
        ["title","Title"],
        ["species","Species"],
        ["instrument","Instrument"],
        ["publication","Publication"],
        ["DATE_FORMAT(identifierDate,'\%Y-\%m-\%d')","IdentifierDate"],
        ["DATE_FORMAT(submissionDate,'\%Y-\%m-\%d')","AnnouncementDate"],
        ["DATE_FORMAT(revisionDate,'\%Y-\%m-\%d')","RevisionDate"],
        ["announcementXML", "announcementXML"],
        );

  my $columns_clause =  build_SQL_columns_list(
				column_array_ref=>\@column_array,
        hidden_cols_ref => \%hidden_cols,
        heading => \@headings);

  #my $order_clause="REPLACE(DATASETIDENTIFIER, 'R', '') DESC";
  my $order_clause = "submissionDate DESC ";
  my $sort_col = '';
  my $sort_dir = '';
  if ($params->{sort}){
    $params->{sort} =~ /property.*:"(\w+)".*:"(\w+)".*/;
    $order_clause = $1 ." " .$2; 
    $sort_col = $1;
    $sort_dir = $2;
  }
  my $idx = 0;
  my %col_idx = ();
  my %col_name = ();
  my %is_number_col = ();
  foreach my $col (@column_array){
    next if ($hidden_cols{$col->[1]});
    if(lc($col->[1]) eq 'id' || $col->[1] =~ /date/i){
      $is_number_col{$idx} = 1;
    }
    $col_idx{lc($col->[1])} = $idx;
    $col_name{$idx} = $col->[1];
    $idx++;
  }
  if($sort_col ne ''){
    $sort_col = $col_idx{lc($sort_col)};
  }else{
    $sort_col = $col_idx{lc('AnnouncementDate')};
    $sort_dir = 'desc';
  }

	my $sql = qq~ select
                 $columns_clause 
                 from $table_name
                 $whereclause
                 ORDER BY $order_clause 
             ~;

	my @results = $dbh->selectSeveralColumns($sql);
  my $json = new JSON;
  my $hash;
  my $cnt = 0;
  my @query_terms = ();
  my %sorter = ();
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
  $idx=0;

  foreach my $row (@results){
    if ($filterstr ne ''){
			my $matches = 0;
      if ( $searchType !~ /^advsearch/ ){
				foreach my $q (@query_terms){
					my $match  = grep (/$q/i, @$row);
					## search xml file also
					if ( ! $match){
						my $xml_file = $row->[$#headings];
						open (IN, "<$path/$xml_file") or die "cannot open $xml_file";
						my @lines = <IN>;
						$match = grep  (/$q/i,@lines);
					}
					if ($match){
						$matches++;
					}
				}
				next if ($matches < @query_terms);
      }else{ ## advanced search
         foreach my $q (@query_terms){
           my ($colname, $cond, $str) = split(/\+/, $q);
           for(my $i =0; $i<= $#headings; $i++){
             if ($headings[$i] =~ /$colname/i){
                if ($cond =~ /^contain$/){
                  if ( $row->[$i] =~ /$str/i){
                    $matches++;
                  }
                }elsif ($cond =~ /^notontained/){
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
      }## advanced search

    }
		my %data=();
		foreach my $i (0..$#headings-1){
			$data{$headings[$i]} =  $row->[$i];
		}
		if($col_name{$sort_col} =~/^id$/i ){
			$row->[$sort_col] =~ s/^[A-Z]+0{0,}//;
		}elsif($col_name{$sort_col} =~ /date/i){
			$row->[$sort_col] =~ s/-//g;
		}elsif($col_name{$sort_col} =~ /publication/i){
			$row->[$sort_col] =~ s/<[^>]+//g;
		}
		##add idx in case there is a empty string.
		$sorter{lc($row->[$sort_col])}{$idx} = \%data; 
		$idx++; 
  }
  close IN;
  $cnt= $idx;
  $idx = 0;

  if($is_number_col{$sort_col}){
		if ($sort_dir =~ /desc/i){
			foreach my $entry (sort {$b <=> $a} keys %sorter){
				foreach my $n (keys %{$sorter{$entry}}){
          if( $idx < $pageStart || $idx > ( $pageStart + $pageLimit - 1)){$idx++; next;}
					push @{$hash->{QueryResponse}{dataset}},{%{$sorter{$entry}{$n}}};
          $idx++;
				}
			}
		}else{
			foreach my $entry (sort {$a <=> $b} keys %sorter){
				foreach my $n (keys %{$sorter{$entry}}){
          if( $idx < $pageStart || $idx > ( $pageStart + $pageLimit - 1)){$idx++; next;}
					push @{$hash->{QueryResponse}{dataset}},{%{$sorter{$entry}{$n}}};
          $idx++;
				}
			}
		}
   }else{
    if ($sort_dir =~ /desc/i){
      foreach my $entry (sort {$b cmp  $a} keys %sorter){
        foreach my $n (keys %{$sorter{$entry}}){
          if( $idx < $pageStart || $idx > ( $pageStart + $pageLimit - 1)){$idx++; next;}
          push @{$hash->{QueryResponse}{dataset}},{%{$sorter{$entry}{$n}}};
          $idx++;
        }
      }
    }else{
      foreach my $entry (sort {$a cmp $b} keys %sorter){
        foreach my $n (keys %{$sorter{$entry}}){
          if( $idx < $pageStart || $idx > ( $pageStart + $pageLimit - 1)){$idx++; next;}
          push @{$hash->{QueryResponse}{dataset}},{%{$sorter{$entry}{$n}}};
          $idx++;
        }
      }
    }
  }

  $hash ->{"QueryResponse" }{"counts"}{"dataset"} = $cnt;
  $hash ->{"QueryResponse" }{"counts"}{"order_clause"} = $order_clause; 

  print  $cgi -> header('application/json');
  $json = $json->pretty([1]);
  print  $json->encode($hash);


}
sub showDataset {
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
    $teststr = "&test=$test";
  }

  if ($datasetID =~ /^R?PX[DT]/){
    $datasetID =~ s/^R?PX[DT]//;
    $datasetID =~ s/^0+//;
  }
  my ($title,$str,$id,$status,$announcementXML);
  my $dbh = new ProteomeXchange::Database;
  my $sql = qq~ select announcementXML
                 from $table_name where dataset_id=$datasetID;
             ~;
  my @results = $dbh->selectSeveralColumns($sql);
  $announcementXML = $results[0]->[0];
  my $parser = new ProteomeXchange::DatasetParser;
  $parser->parse('uploadFilename' => $announcementXML, 'response' => $response, 'filename'=>"$path/$announcementXML");
  my $result = $response->{dataset};
  my ($hash, %data);
  $hash ->{"QueryResponse" }{"counts"}{"dataset"} = 1;

  foreach my $key (qw(PXPartner
                          announceDate
                          announcementXML
                          DigitalObjectIdentifier
                          ReviewLevel
                          datasetOrigin
                          RepositorySupport
                          primarySubmitter
                          labHead
                          title
                          description
                          speciesList
                          modificationList
                          instrument)){
     my $idx = $key;
     $idx =~ s/^[A-Z]+//;
     $data{$idx} = $result->{$key};

  }
  $data{id} = $datasetID;
  $data{test} = $teststr;
  push @{$hash->{QueryResponse}{dataset}}, {%data};
  print  $cgi -> header('application/json');
  my $json = new JSON;

  $json = $json->pretty([1]);
  print  $json->encode($hash);

}
##e############################################################################
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
}

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
    $columns_clause .= qq ~
           $element->[0] AS "$element->[1]"~;
    push @$heading , $element->[1];
  }
  #### Return result
  return $columns_clause;

} # end build_SQL_columns_list
	
