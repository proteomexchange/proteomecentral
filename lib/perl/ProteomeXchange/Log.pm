###############################################################################
# $Id: Log.pm 3452 2005-04-20 20:18:07Z dcampbel $
#
# Description : Module for logging  messages.  For a detailed usage for
# this module, please use `perldoc Log.pm`
#
# SBEAMS is Copyright (C) 2000-2005 Institute for Systems Biology
# This program is governed by the terms of the GNU General Public License (GPL)
# version 2 as published by the Free Software Foundation.  It is provided
# WITHOUT ANY WARRANTY.  See the full description of GPL terms in the
# LICENSE file distributed with this software.
#
###############################################################################

package ProteomeXchange::Log;
use strict;
use IO::File;
use File::Basename;

use vars qw( $PHYSICAL_BASE_DIR $LOG_BASE_DIR $LOGGING_LEVEL );
use ProteomeXchange::Configuration qw( %CONFIG );
$PHYSICAL_BASE_DIR = $CONFIG{basePath};

##### Public Methods ###########################################################

#+
# Constructor.  Tries to use values from Settings.pm by default, user may 
# override.
#-
sub new {
  my $class = shift;
  my %args = @_;
  my $base = ( $args{base} )   ? $args{base} : 
             ( $LOG_BASE_DIR ) ? $LOG_BASE_DIR : "$PHYSICAL_BASE_DIR/var/logs";

  unless( -e $base ){
  print STDERR "Try to create base = $base\n";
    mkdir( $base ) || warn "Unable to create logging dir, $base";
  }

  my $logdir = ( $args{subdir} ) ? $base . '/' . $args{subdir} : $base;

  unless( !$args{subdir} && -e $logdir ){
  print STDERR "Try to create log subdir = $logdir\n";
    mkdir( $logdir ) || warn "Unable to create logging dir, $logdir";
  }
  
  my $this = { debug_log => "$logdir/debug.log",
               info_log => "$logdir/info.log",
               warn_log => "$logdir/warn.log",
               error_log => "$logdir/error.log",
               log_level => $LOGGING_LEVEL || 'warn',
               @_
             };

  foreach my $logfile ( qw( debug_log info_log warn_log error_log ) ) {
    unless( -e $this->{$logfile} ) {
      open FIL, ">$this->{$logfile}" || warn ("Couldn't open log file for writing: $this->{logfile}" );
      print FIL "Initializing\n";
      close FIL;
    }
  }

  # Objectification.
  bless $this, $class;

  $this->_setLogVal();
  return $this;
}

#+
# One of four main object methods, prints if log_level is debug.
#-
sub debug {
  my $this = shift;
  return unless $this->_checkLogLevel( 'debug' );
  my $msg = shift;
  $this->_printMessage ( debug => $msg );
}

#+
# One of four main object methods, prints if log_level is error or lower.
#-
sub error {
  my $this = shift;
  return unless $this->_checkLogLevel( 'error' );
  my $msg = shift;
  $this->_printMessage ( error => $msg );
}

#+
# One of four main object methods, prints if log_level is info or lower.
#-
sub info {
  my $this = shift;
  return unless $this->_checkLogLevel( 'info' );
  my $msg = shift;
  $this->_printMessage ( 'info' => $msg );
}

#+
# One of four main object methods, prints if log_level is warn or lower.
#-
sub warn {
  my $this = shift;
  return unless $this->_checkLogLevel( 'warn' );
  my $msg = shift;
  $this->_printMessage ( 'warn' => $msg );
}

#+
# passthrough method, circumvents log_level
#-
sub pure {
  my $this = shift;
  my $mode = shift || 'error';
  my $msg = shift;
  $this->_printMessage ( $mode => $msg, 2 );
}

#+
# Method to set logging level (overriding construction-time value).
#-
sub setLogLevel {
  my $this = shift;
  my $level = shift;
  die "illegal logging level" unless $level =~ /^debug$|^warn$|^error$|^info$/;
  $this->{log_level} = $level;
  $this->_setLogVal();
}

#+
# prints out call stack
#-
sub printStack {
  my $this = shift;
  my $level = shift || 'error';
  return unless $this->_checkLogLevel( $level );
  my $cnt =  shift || 10;

  my $stack = '';
  my $file = '';
  my $line = '';
  for ( my $i = 0; $i <= $cnt ; $i++ ) {
     my ( $p, $f, $l, $s ) = caller( $i );
     last unless $l;
     $file = $f if $i == 1; 
     $stack .= "$i: $p ($s) line $line\n" if $i;
     $line = $l;
  }
  $stack = "$level [" . $this->_getTimestamp() . "] stack trace:\n$stack"; 
  $this->_printMessage( $level => $stack, 1 );
}

############ Private ###################

#+
# Workhorse, prints messages sent its way.
#-
sub _printMessage {
  my $this = shift;
  my $mode = shift;   # debug/info/warn/error
  my $msg = shift;    # scalar to print
  my $stack = shift;  # semaphore to allow stack printing

  die "Unknown mode: $mode" unless $mode =~ /warn|debug|info|error/;

  $msg .= "\n" unless $stack  && $stack > 1;

  my ( $p, $f, $l, $s ) = caller( 1 );
  ( $p, undef, undef, $s ) = caller( 2 );
  $f = basename( $f ) if $f;

  my $time = $this->_getTimestamp();
  my $lname = $mode . '_log';
  my $lfile = new IO::File ">> $this->{$lname}";
  unless ( defined $lfile ) {
    print STDERR "Failed to open log ($this->{$lname})[$!]";
    print STDERR "$msg";
    return undef;
  }
  my $info = ucfirst( $mode ) . " [$time] ($f line $l): ";
  print $lfile "$info" unless $stack;
  print $lfile "$msg";
  $lfile->flush();
  $lfile->close();
}

#+
# Returns hash of text -> numeric log levels
#-
sub _getLogLevels {
  my $this = shift;
  my %levels = ( debug => 1,
                 info  => 2,
                 warn  => 3,
                 error => 4 );
  return \%levels;
}

#+
#  Sets numeric log level
#-
sub _setLogVal {
  my $this = shift;
  my $ll = $this->{log_level} || 'error';
  my $levels = $this->_getLogLevels();
  $this->{_log_val} = $levels->{$ll};
  die "Illegal log level" unless $this->{_log_val}; 
  return 1;
}

sub _checkLogLevel {
  my $this = shift;
  my $ll = shift || 'error';
  my $levels = $this->_getLogLevels();
  return ( $levels->{$ll} >= $this->{_log_val} ) ? 1 : 0;
}

#+
# Get pretty time string.
#-
sub _getTimestamp {
  my $this = shift;
  my @time = localtime();
  my @days = qw(Sun Mon Tue Wed Thu Fri Sat );
  my $year = $time[5] + 1900;
  my $mon = $time[4] + 1;
  my $day = $time[3];
  my $hour = $time [2];
  my $min = $time[1];
  my $sec = $time[0];
  for ( $min, $day, $hour, $mon, $sec ) {
    $_ = '0' . $_ if length( $_ ) == 1;
  }
  return "${year}-${mon}-${day} ${hour}:${min}:${sec}";
}

sub _purgeLogs {
  my $this = shift;
  my @logs = @_;
  for my $log ( qw(debug_log info_log warn_log error_log ) ) {
    if ( grep @logs, /^$log$/ && $this->{$log} ) {
      open( FIL, ">$this->{$log}" ); 
      print FIL "Log reset: " . $this->_getTimestamp() . "\n";
    }
  }
}

1;

__END__

=head1 NAME: 

SBEAMS::Connection::Log, sbeams logging object

=head1 SYNOPSIS

The sbeams logger is a simple object that prints information
to a file (log) during program execution.  

=head1 DESCRIPTION

use SBEAMS::Connection::Log;

my $logbase = '/var/log/sbeams/';

my $loglevel = $LOG_LEVEL || 'warn';

my $log = SBEAMS::Connection::Log->new(
                              base      => $logbase,
                              debug_log => '$logbase/debug.log',
                              error_log => '$logbase/error.log',
                              info_logi => '$logbase/info.log',
                              warn_log  => '$logbase/warn.log',
                              log_level => $loglevel
                                       );

$log->debug( "VAR is $var on the $cnt time through the loop" );

if ( $some_frightful_condition ) {
  $log->error( "The sky is falling!  run away!" );
  die( "The sky fell" );
}

$log->printStack();


=head2 Logging files:

These file can be specified at object creation, otherwise default to
$sbeams_base/logs/xxx.log, where xxx is one of error or info.

=head2 Logging levels:

At any given time, the logger has a logging level set, and it will
print any messages for states that meet or exceed that level.  For
example, if the level is set to warn, only warn and error messages
will print.  If it is set to debug, all four types will print.  The
hierarchy is debug < info < warn < error.  The logging level should
be set to one of debug/info/warn/error via the SBEAMS.conf file. 
If this is not set, it defaults to error in the logging object.  If
the specified file does not exist and can't be created, messages are
directed to STDERR.  These levels allow programmers to leave 
debugging statements in the code, knowing that they will not be 
printed under normal operation.  If it becomes necessary to debug a 
problem, debugging can be turned on to gather information, then 
easily turned off again.

=head2 Default logging object

The module Connection.pm exports a log object that can be easily 
imported by other packages and scripts, to avoid the overhead of 
creating the object.

use SBEAMS::Connection qw($log);

=cut
