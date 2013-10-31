package ProteomeXchange::Configuration;

###############################################################################
# Class       : ProteomeXchange::Configuration
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
#
# Description : This class is used to maintain central configuration parameters
#
###############################################################################

use strict;
use warnings;

use Exporter 'import';
use vars qw( %CONFIG );
our @EXPORT_OK = qw( %CONFIG );

use FindBin;
use lib "$FindBin::Bin/../perl";
use lib "$FindBin::Bin/../lib/perl";

#### Go ahead and read the configuration right away upon compile and export
#### a class variable %CONFIG. It is not necessary to actually create an object.
unless (%CONFIG) {
  readConfiguration();
}


###############################################################################
# Constructor
###############################################################################
sub new {
  my $self = shift;
  my %parameters = @_;

  my $class = ref($self) || $self;

  #### Create the object with any attributes if supplied
  bless {
	 _status => 'NOT INIT',
	} => $class;

  $self->setStatus($self->readConfiguration());

}


###############################################################################
# setStatus: Set attribute status
###############################################################################
sub setStatus {
  my $self = shift;
  $self->{_status} = shift;
  return $self->{_status};
}


###############################################################################
# getStatus: Get attribute status
###############################################################################
sub getStatus {
  my $self = shift;
  return $self->{_status};
}


###############################################################################
# readConfiguration
#
# Find and read the configuration file
###############################################################################
sub readConfiguration {
  my $self = shift;
  my %args = @_;
  my $SUB_NAME = 'readConfiguration';

  my @paths = ( "$FindBin::Bin/../conf", "$FindBin::Bin/../lib/conf" );

  my $filename = 'system.conf';
  my $validatedFullPath;
  my $errorBuffer = "Looked for the configuration file at:\n";

  foreach my $path ( @paths ) {
    my $location = "$path/$filename";
    $errorBuffer .= "  $location\n";

    if ( -e $location ) {
      $validatedFullPath = $location;
      last;
    }
  }

  unless ( $validatedFullPath ) {
    print "Content-type: text/plain\n\n";
    print $errorBuffer;
    die("ERROR: Unable to find a configuration file");
  }

  unless (open(INFILE,$validatedFullPath)) {
    print "Content-type: text/plain\n\n";
    die("ERROR: Found configuration file '$validatedFullPath' but unable to open file");
  }

  while ( my $line = <INFILE> ) {
    $line =~ s/[\r\n]//g;
    #### Skip comment lines
    next if ($line =~ /^\s*\#/);
    #### Skip empty lines
    next if ($line =~ /^\s*$/);

    if ($line =~ /(\S+?)=(.*)/) {
      my $key = $1;
      my $value = $2;
      $CONFIG{$key} = $value;
      #print "Parsed parameter $key==$value.\n";
    }
  }

  return("SUCCESS");
}


###############################################################################
1;

__END__
