package ProteomeXchange::DDIJS;

###############################################################################
# $Id:  $
#
# Description : 
#
# SBEAMS is Copyright (C) 2000-2016 Institute for Systems Biology
# This program is governed by the terms of the GNU General Public License (GPL)
# version 2 as published by the Free Software Foundation.  It is provided
# WITHOUT ANY WARRANTY.  See the full description of GPL terms in the
# LICENSE file distributed with this software.
#
###############################################################################

use strict;
use IO::File;
use File::Basename;
use ProteomeXchange::Log;

my $log =  ProteomeXchange::Log->new( base => "/net/dblocal/wwwspecial/proteomecentral/devDC/logs/", log_level => 'debug' );


my $PHYSICAL_BASE_DIR = '/net/dblocal/wwwspecial/proteomecentral';

##### Public Methods ###########################################################

#+
# Constructor.  Tries to use values from Settings.pm by default, user may 
#-
sub new {
  my $class = shift;
  
  my $this = {  
               @_
             };


  # Objectification.
  bless $this, $class;

  return $this;
}

sub get_onload_script {
  my $mode = shift || '';

  my $json_base = 'http://proteomecentral.proteomexchange.org/devDC/cgi/GetJSON';
  my $wc_json = $json_base . '?mode=keywords';

  my $onload = q~
    <script type=text/javascript>
    $(document).ready(function() {
      myQueryEvent();
    });
  ~;
  $onload .= qq~
    pie_charts_repos_omics();
    draw_word_cloud( '$wc_json', 'keywords', 240, 240 );
  </script>
  ~;
  return $onload;
}

sub get_js_includes {
  my $this = shift;
  my $mode = shift || '';
  $log->info( "Mode is $mode" );

  my $js_includes = '';
#  for my $js ( qw( angular-animate.min.js angular-cookies.js angular.js angular-route.min.js app.js autocomplete.js d3.layout.cloud.js d3.min.js DDIDatasetCtl.js DDIDatasetListsCtl.js DDIGetTweets.js DDIMainContentCtl.js DDIPieCharts.js DDIQueryCtl.js DDIResultsListCtl.js DDIService.js DDIWordCloud.js jquery-1.10.1.min.js ngprogress.min.js queue.v1.min.js underscore-min.js ) ) {
#  for my $js ( qw( d3.layout.cloud.js d3.min.js DDIDatasetCtl.js DDIDatasetListsCtl.js DDIGetTweets.js DDIMainContentCtl.js DDIPieCharts.js DDIQueryCtl.js DDIResultsListCtl.js DDIService.js DDIWordCloud.js jquery-1.10.1.min.js  ) ) {
#  for my $js ( qw( d3.min.js DDISBPieCharts.js DDISBWordCloud.js ) ) {
  for my $js ( qw( d3.min.js d3.layout.cloud.js DDISBPieCharts.js DDISBWordCloud.js ) ) {
    if ( $js eq 'DDISBPieCharts.js' && $mode ) {
      $log->info( "adding single" );
      $js_includes .= "<script src=/devDC/javascript/js/ddi/DDISBPieChartsSingle.js></script>\n";
    } else {
      $log->info( "adding $js" );
      $js_includes .= "<script src=/devDC/javascript/js/ddi/$js></script>\n";
    }
  }
  $js_includes .= "<link type='text/css' href='/devDC/javascript/css/bootstrap.min.css' rel='stylesheet'>";
  $js_includes .= "<link type='text/css' href='/devDC/javascript/css/ddi-min.css' rel='stylesheet'>";
#  $js_includes .= "<script type=text/javascript>myQueryEvent();</script>";
  return $js_includes;

#  /net/dblocal/wwwspecial/proteomecentral/backup/javascript/js/
}

1;

__DATA__

