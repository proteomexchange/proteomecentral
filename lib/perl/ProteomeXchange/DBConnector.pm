package ProteomeXchange::DBConnector;

###############################################################################
# Class       : ProteomeXchange::DBConnector
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
#
# Description : This class is used to manage communication with the
#               ProteomeCentral database
#
###############################################################################

use strict;
use warnings;

use DBI;
use ProteomeXchange::Configuration qw( %CONFIG );

use vars qw($dbh);


###############################################################################
# Constructor
###############################################################################
sub new {
  my $self = shift;
  my %parameters = @_;

  my $class = ref($self) || $self;

  my $status = 'not connected';


  #### Create the object with any attributes if supplied
  bless {
	 _serverName => $parameters{serverName},
	 _databaseName => $parameters{databaseName},
	 _userName => $parameters{userName},
	 _password => $parameters{password},
	 _status => $status,
	} => $class;
}


###############################################################################
# setServerName: Set attribute serverName
###############################################################################
sub setServerName {
  my $self = shift;
  $self->{_serverName} = shift;
  return $self->{_serverName};
}


###############################################################################
# getServerName: Get attribute serverName
###############################################################################
sub getServerName {
  my $self = shift;
  return $self->{_serverName};
}


###############################################################################
# setDatabaseName: Set attribute databaseName
###############################################################################
sub setDatabaseName {
  my $self = shift;
  $self->{_databaseName} = shift;
  return $self->{_databaseName};
}


###############################################################################
# getDatabaseName: Get attribute databaseName
###############################################################################
sub getDatabaseName {
  my $self = shift;
  return $self->{_databaseName};
}


###############################################################################
# setUserName: Set attribute userName
###############################################################################
sub setUserName {
  my $self = shift;
  $self->{_userName} = shift;
  return $self->{_userName};
}


###############################################################################
# getUserName: Get attribute userName
###############################################################################
sub getUserName {
  my $self = shift;
  return $self->{_userName};
}


###############################################################################
# setPassword: Set attribute password
###############################################################################
sub setPassword {
  my $self = shift;
  $self->{_password} = shift;
  return $self->{_password};
}


###############################################################################
# getPassword: Get attribute password
###############################################################################
sub getPassword {
  my $self = shift;
  return $self->{_password};
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
# setRaiseErrorOn
#  Set attribute for the global $dbh.
###############################################################################
sub setRaiseErrorOn {
  my $self = shift;
  $dbh->{RaiseError} = 1;
}


###############################################################################
# setRaiseErrorOff
#  Set attribute for the global $dbh.
###############################################################################
sub setRaiseErrorOff {
  my $self = shift;
  $dbh->{RaiseError} = 0;
}


###############################################################################
# setAutoCommitOn
#  Set attribute for the global $dbh.
###############################################################################
sub setAutoCommitOn {
  my $self = shift;
  $dbh->{AutoCommit} = 1;
}


###############################################################################
# setAutoCommitOff
#  Set attribute for the global $dbh.
###############################################################################
sub setAutoCommitOff {
  my $self = shift;
  $dbh->{AutoCommit} = 0;
}


###############################################################################
# getDBHandle
#
# Returns the current database connection handle to be used by any query.
# If the database handle doesn't yet exist, dbConnect() is called to create
# one.
###############################################################################
sub getDBHandle {
  my $self = shift;

  $dbh = $self->dbConnect(@_) unless defined($dbh);

  return $dbh;
}


###############################################################################
# connect
#
# Perform the actual database connection open call via DBI.  This should
# be database independent, but hasn't been tested with many databases.
# This should never be called directly except by getDBHandle().
###############################################################################
sub connect {
  my $self = shift;
  my %args = @_;
  my $SUB_NAME = 'dbConnect';

  #### Process the arguments list
  my $serverName = $args{'serverName'} || $self->{getServerName};
  my $databaseName = $args{'databaseName'} || $self->{getDatabaseName};
  my $userName = $args{'userName'} || $self->{getUserName};
  my $password = $args{'password'} || $self->{getPassword};

  #### Set the default parameters
  $serverName = $CONFIG{DB_serverName};
  $databaseName = $CONFIG{DB_databaseName};
  $userName = $CONFIG{DB_userName};
  $password = $CONFIG{DB_password};
  my $databaseType = $CONFIG{DB_databaseType};
  my $databaseAdmin = $CONFIG{DB_databaseAdmin};
  my $driverString = 'DBI:$databaseType:$databaseName:$serverName';

  $self->setServerName($serverName);
  $self->setDatabaseName($databaseName);
  $self->setUserName($userName);
  $self->setPassword($password);

  #### Set error handling attributes
  my (%error_attr) = (
    PrintError => 0,
    RaiseError => 0
  );

  $driverString = eval "\"$driverString\"";

  #### Try to connect to database
  $dbh = DBI->connect($driverString,$userName,$password,\%error_attr);
  my $error = $DBI::errstr || '';
  if ( ! $dbh ) {
    my $err = "ERROR: Unable to connect to database, please contact $databaseAdmin:\n$error";
    die ( $err );
  }

  #### Place any DB specific initialization calls here
  if ( !$databaseType ) {
    die( 'Database type not defined, cannot continue' );
  } elsif ( $databaseType =~ /mysql/i ) {
    # Set mysql mode to honor || as concatenation symbol
    $dbh->do( "SET sql_mode=PIPES_AS_CONCAT" );
  }

  $self->setStatus('connected');

  return $dbh;
}


###############################################################################
# disconnect
#
# Disconnect from the database.
###############################################################################
sub disconnect {
  my $self = shift;
  $dbh->disconnect() or die "Error disconnecting from database: $DBI::errstr";
  return 1;
}



###############################################################################

1;

__END__
###############################################################################
###############################################################################
###############################################################################

=head1 SBEAMS::Connection::DBConnector

SBEAMS Core database connection methods

=head2 SYNOPSIS

See SBEAMS::Connection for usage synopsis.

=head2 DESCRIPTION

This module is inherited by the SBEAMS::Connection module, although it
can be used on its own. Its main function is to provide a single
database connection to be used by all programs included in this
application.


=head2 METHODS

=over

=item * B<getDBHandle()>

    Returns the current database handle (opening a connection if one does
    not yet exist) for a connection defined in the config file.


=item * B<dbConnect()>

    Perform the actual database connection open call via DBI.  This should
    be database independent, but has not been tested with many databases.
    This should never be called directly except by getDBHandle().


=item * B<dbDisconnect()>

    Forcibly disconnect from the RDBMS.  This is usually only necessary
    when authentication fails.


=item * B<getDBServer()>

    Return the servername of the database.


=item * B<getDBDriver()>

    Return the driver name (DSN string) of the database connection.


=item * B<getDBType()>

    Return the server type of the database connection.  This is defined
    in the conf file.  See that file for supported options.


=item * B<getBIOSAP_DB() and similar>

    This is old and fusty and should be removed in favor of a
    getModuleDatabasePrefix()


=item * B<getDBDatabase()>

    Return the database name of the connection.


=item * B<getDBUser()>

    Return the username used to open the connection to the RDBMS.


=item * B<getDBROUser()>

    Return the username used to open a read-only connection to the RDBMS.

=back

=head2 BUGS

Please send bug reports to the author

=head2 AUTHOR

Eric Deutsch <edeutsch@systemsbiology.org>

=head2 SEE ALSO

SBEAMS::Connection

=cut

