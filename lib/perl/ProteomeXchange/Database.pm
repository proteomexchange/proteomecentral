package ProteomeXchange::Database;

###############################################################################
# Class       : ProteomeXchange::Database
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
#
# Description : This class is used to operate on the database itself.
#
###############################################################################

use strict;

use ProteomeXchange::DBConnector;
use ProteomeXchange::Log;

use vars qw($dbh $log);
$log = new ProteomeXchange::Log;






###############################################################################
# Constructor
###############################################################################
sub new {
  my $self = shift;
  my %parameters = @_;

  my $class = ref($self) || $self;

  my $status = 'not connected';

  #### Create the object with any attributes if supplied
  $self = {
	 _status => $status,
	};

  bless $self => $class;

  #### Try to connect to the database
  my $connection = new ProteomeXchange::DBConnector;
  $connection->connect();
  $self->setHandle($connection->getDBHandle());
  $self->setStatus('connected');

  return $self ;
}


###############################################################################
# setHandle: Set attribute dbh
###############################################################################
sub setHandle {
  my $self = shift;
  $dbh = shift;
  return $dbh;
}


###############################################################################
# getHandle: Get attribute dbh
###############################################################################
sub getHandle {
  my $self = shift;
  return $dbh;
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
# createTables: Create the database tables
###############################################################################
sub createTables {
  my $self = shift;
  die("ERROR: No database connection yet") unless ($dbh);

  my $ddl = qq~

  CREATE TABLE dataset (
    dataset_id          int AUTO_INCREMENT NOT NULL,
    datasetIdentifier   varchar(50) NULL,
    identifierVersion   int NOT NULL default 1,
    isLatestVersion     char(1) NOT NULL default 'Y',
    PXPartner           varchar(50) NOT NULL,
    status              varchar(50) NOT NULL,
    primarySubmitter    varchar(255) NULL,
    labHead             varchar(255) NULL,
    datasetOrigin       varchar(255) NULL,
    title               varchar(255) NULL,
    species             varchar(255) NULL,
    instrument          varchar(255) NULL,
    publication         varchar(255) NULL,
    keywordList         varchar(255) NULL, 
    announcementXML     varchar(255) NULL,
    identifierDate      datetime NOT NULL,
    submissionDate      datetime NULL,
    revisionDate        datetime NULL,
    PRIMARY KEY (dataset_id)
  ) ENGINE=InnoDB;

  CREATE TABLE datasetHistory (
    datasetHistory_id   int AUTO_INCREMENT NOT NULL,
    dataset_id          int NOT NULL,
    datasetIdentifier   varchar(50) NOT NULL,
    identifierVersion   int NOT NULL,
    isLatestVersion     char(1) NOT NULL,
    PXPartner           varchar(50) NULL,
    status              varchar(50) NOT NULL,
    primarySubmitter    varchar(255) NULL,
    labHead             varchar(255) NULL,
    datasetOrigin       varchar(255) NULL,
    title               varchar(255) NULL,
    species             varchar(255) NULL,
    instrument          varchar(255) NULL,
    publication         varchar(255) NULL,
    keywordList         varchar(255) NULL, 
    announcementXML     varchar(255) NULL,
    identifierDate      datetime NULL,
    submissionDate      datetime NULL,
    revisionDate        datetime NULL,
    changeLogEntry      varchar(255) NULL,
    PRIMARY KEY (datasetHistory_id)
  ) ENGINE=InnoDB;

  CREATE TABLE supplementalLinkList (
    supplementalLinkList_id   int AUTO_INCREMENT NOT NULL,
    datasetIdentifier   varchar(50) NOT NULL,
    PXPartner           varchar(50) NOT NULL,
    supplementalXML     varchar(255) NULL,
    PRIMARY KEY (supplementalLinkList_id)
  ) ENGINE=InnoDB;

  ~;

  $ddl = qq~
  CREATE TABLE server (
    server_id          int AUTO_INCREMENT NOT NULL,
    name               varchar(50) NULL,
    domain             varchar(50) NULL,
    state              varchar(50) NOT NULL,
    type               varchar(50) NOT NULL,
    url                char(255) NOT NULL,
    proxiUrl           char(255) NOT NULL,
    description        char(255) NULL,
    creationDate       datetime NOT NULL,
    modificationDate   datetime NOT NULL,
    modificationLogEntry char(255) NULL,
    PRIMARY KEY (server_id)
  ) ENGINE=InnoDB;
  ~;

  my $result = $self->executeSQL(sql=>$ddl);

  if ($result) {
    print "Tables successfully created.\n";
    return 1;
  } else {
    print "Error creating tables\n";
    return(0);
  }

}


###############################################################################
# dropTables: Drop the database tables. Careful!
###############################################################################
sub dropTables {
  my $self = shift;
  die("ERROR: No database connection yet") unless ($dbh);

  my $ddl = qq~

  argh!DROP TABLE dataset;

  ~;

  my $result = $self->executeSQL(sql=>$ddl);

  if ($result) {
    print "Tables successfully dropped.\n";
    return 1;
  } else {
    print "Error dropping tables\n";
    return(0);
  }

}


###############################################################################
# modifyTables: Modify the database tables during development. Not for production
###############################################################################
sub modifyTables {
  my $self = shift;
  die("ERROR: No database connection yet") unless ($dbh);

  my $ddl = qq~

  argh!DROP TABLE datasetHistory_test;

  ~;

  #my $result = 1;
  my $result = $self->executeSQL(sql=>$ddl);

  if ($result) {
    print "Table successfully dropped.\n";
  } else {
    print "Error dropping table\n";
  }

  $ddl = qq~

  CREATE TABLE datasetHistory_test (
    datasetHistory_id   int AUTO_INCREMENT NOT NULL,
    dataset_id          int NOT NULL,
    datasetIdentifier   varchar(50) NOT NULL,
    identifierVersion   int NOT NULL,
    isLatestVersion     char(1) NOT NULL,
    PXPartner           varchar(50) NULL,
    status              varchar(50) NOT NULL,
    primarySubmitter    varchar(255) NULL,
    labHead             varchar(255) NULL,
    datasetOrigin       varchar(255) NULL,
    title               varchar(255) NULL,
    species             varchar(255) NULL,
    instrument          varchar(255) NULL,
    publication         varchar(255) NULL,
    keywordList         varchar(255) NULL, 
    announcementXML     varchar(255) NULL,
    identifierDate      datetime NULL,
    submissionDate      datetime NULL,
    revisionDate        datetime NULL,
    changeLogEntry      varchar(255) NULL,
    PRIMARY KEY (datasetHistory_id)
  ) ENGINE=InnoDB;

  ~;

  $result = $self->executeSQL(sql=>$ddl);

  if ($result) {
    print "Tables successfully modified.\n";
  } else {
    print "Error modifying tables\n";
  }

  return(1);

}


###############################################################################
# testInsert: Test a row INSERT operation
###############################################################################
sub testInsert {
  my $self = shift;
  die("ERROR: No database connection yet") unless ($dbh);

  my %rowdata = (
    PXPartner => 'PRIDE',
    datasetIdentifier => 'PXD000001',
    status => 'ID requested',
    identifierDate => 'CURRENT_TIMESTAMP',
  );
  my $result = $self->updateOrInsertRow(
    insert => 1,
    table_name => 'dataset',
    rowdata_ref => \%rowdata,
    return_PK => 1,
  );

  if ($result) {
    print "Successfully inserted rowdata with returned dataset_id '$result'.\n";
  } else {
    print "Error inserting row\n";
    return(0);
  }

  ## insert one more row for PRIDE and another row for testing.
  $result = $self->updateOrInsertRow(
    insert => 1,
    table_name => 'dataset',
    datasetIdentifier => 'PXD000002',
    rowdata_ref => \%rowdata,
    return_PK => 1,
  );
  print "Successfully inserted rowdata with returned dataset_id '$result'.\n";

  $rowdata{PXPartner} = 'PeptideAtlas';
  $result = $self->updateOrInsertRow(
    insert => 1,
    table_name => 'dataset',
    rowdata_ref => \%rowdata,
    return_PK => 1,
  );
  print "Successfully inserted rowdata with returned dataset_id '$result'.\n";
  return 1;
}


###############################################################################
# testSelect: Test a SELECT operation
###############################################################################
sub testSelect {
  my $self = shift;
  die("ERROR: No database connection yet") unless ($dbh);

  my $sql = "SELECT dataset_id,identifierDate,PXPartner,datasetIdentifier FROM dataset";

  my @rows = $self->selectSeveralColumns($sql);

  if (@rows) {
    print "Successfully selected rows:\n";
    foreach my $row ( @rows ) {
      for (my $i=0; $i<scalar(@{$row}); $i++) {
	$row->[$i] = 'NULL' unless (defined($row->[$i]));
      }
      print join(" | ",@{$row})."\n";
    }
    return 1;
  } else {
    print "Error selecting data\n";
    return(0);
  }

}



###############################################################################
###############################################################################
###############################################################################

sub croak {
  die(@_);
}


###############################################################################
# prepareSQL
#
# Prepare the supplied SQL statement, but do not execute.
# Primarily for use by SQL testing scripts, when actual modification of
#    database records is not desired.
# NOTE: This is probably not working as intended, because some databases
#    (which? - don't know) apparently don't process prepare() statement until
#    execute() occurs.
###############################################################################
sub prepareSQL {
    my $self = shift || croak("parameter self not passed");
    my $SUB_NAME = "prepareSQL";

    #### Allow old-style single argument
    my $n_params = scalar @_;
    my %args;
    die("parameter sql not passed") unless ($n_params >= 1);
    #### If the old-style single argument exists, create args hash with it
    if ($n_params == 1) {
      $args{sql} = shift;
    } else {
      %args = @_;
    }

    #### Decode the argument list
    my $sql = $args{'sql'} || die("parameter sql not passed");
    my $return_error = $args{'return_error'} || '';

    #### Prepare the query and return if successful
    my $sth = $dbh->prepare($sql);
    if ( $sth ) {
	return $sth;
    } else {
	die( "ERROR on SQL prepare(): ".$dbh->errstr );
    }
}


###############################################################################
# executeSQL
#
# Execute the supplied SQL statement with no return value.
###############################################################################
sub executeSQL {
    my $self = shift || croak("parameter self not passed");
    my $SUB_NAME = "executeSQL";


    #### Allow old-style single argument
    my $n_params = scalar @_;
    my %args;
    die("parameter sql not passed") unless ($n_params >= 1);
    #### If the old-style single argument exists, create args hash with it
    if ($n_params == 1) {
      $args{sql} = shift;
    } else {
      %args = @_;
    }


    #### Decode the argument list
    my $sql = $args{'sql'} || die("parameter sql not passed");
    my $return_error = $args{'return_error'} || '';

    #### Prepare the query
    my $sth = $dbh->prepare($sql);
    my $rows;

    #### If the prepare() succeeds, execute
    if ($sth) {

      my $rows = '';
      eval {
           $rows  = $sth->execute();
           };
      if ( $@ ) {
        $log->error( "Caught error: $@" );
        $log->error( "DBI errorstring is $DBI::errstr" );
      }

      if ($rows) {
        if (ref($return_error)) {
          $$return_error = '';
        }
        return $rows;
      } elsif ($return_error) {
        if (ref($return_error)) {
          $$return_error = $dbh->errstr;
        }
        return 0;
      } else {
        $log->error( "Error on execute DBI errorstring is $DBI::errstr" );
        die("ERROR on SQL execute():\n$sql\n\n".$dbh->errstr);
      }

    #### If the prepare() fails
    } elsif ($return_error) {
      if (ref($return_error)) {
        $$return_error = $dbh->errstr;
      }
      return 0;
    } else {
      die("ERROR on SQL prepare(): ".$dbh->errstr);
    }


    #### Return the number of rows affected, or some other non-0 result
    return $rows;

}



###############################################################################
# getLastInsertedPK
#
# Return the value of the AUTO GEN key for the last INSERTed row
###############################################################################
sub getLastInsertedPK {
    my $self = shift || croak("parameter self not passed");
    my %args = @_;
    my $subName = "getLastInsertedPK";


    #### Decode the argument list
    my $table_name = $args{'table_name'};
    my $PK_column_name = $args{'PK_column_name'};


    my $sql;
    my $DBType = 'MySQL';


    #### Method to determine last inserted PK depends on database server
    if ($DBType =~ /MS SQL Server/i) {
      $sql = "SELECT SCOPE_IDENTITY()";

    } elsif ($DBType =~ /MySQL/i) {
      $sql = "SELECT LAST_INSERT_ID()";

    } elsif ($DBType =~ /PostgreSQL/i) {
      die "ERROR[$subName]: Both table_name and PK_column_name need to be " .
        "specified here for PostgreSQL since no automatic PK detection is " .
        "yet possible." unless ($table_name && $PK_column_name);

      #### YUCK! PostgreSQL 7.1 appears to truncate table name and PK name at
      #### 13 characters to form the automatic SEQUENCE.  Might be fixed later?
      my $sequence_name;
      if (0) {
        my $table_name_tmp = substr($table_name,0,13);
        my $PK_column_name_tmp = substr($PK_column_name,0,13);
        $sequence_name = "${table_name_tmp}_${PK_column_name_tmp}_seq";

      #### To avoid possible complications with this, SBEAMS now just creates
      #### SEQUENCEs explicitly and simply truncates them at the PostgreSQL
      #### 7.1 limit of 31 characters.  I hope this will be lifted sometime
      } else {
        $sequence_name = "seq_${table_name}_${PK_column_name}";
        $sequence_name = substr($sequence_name,0,31);
      }

      $sql = "SELECT currval('$sequence_name')"

    #### Complain bitterly if we don't recognize the RDBMS type
    } else {
      die "ERROR[$subName]: Unable to determine DBType\n\n";
    }


    #### Get value and return it
    my ($returned_PK) = $self->selectOneColumn($sql);
    return $returned_PK;

}


###############################################################################
# SelectOneColumn
#
# Given a SQL query, return an array containing the first column of
# the resultset of that query.
###############################################################################
sub selectOneColumn {
    my $self = shift || croak("parameter self not passed");
    my $sql = shift || croak("parameter sql not passed");

    my @row;
    my @rows;

    my $sth = $dbh->prepare($sql) or croak $dbh->errstr;

    my $rv  = $sth->execute; # or croak $dbh->errstr;
    unless( $rv ) {
      $log->error( "Error executing SQL:\n $sql" );
      $log->printStack( 'error' );
      die $dbh->errstr;
    }

    while (@row = $sth->fetchrow_array) {
        push(@rows,$row[0]);
    }

    $sth->finish;

    return @rows;

} # end selectOneColumn


###############################################################################
# selectSeveralColumns
#
# Given a SQL statement which returns one or more columns, return an array
# of references to arrays of the results of each row of that query.
###############################################################################
sub selectSeveralColumns {
    my $self = shift || croak("parameter self not passed");
    my $sql = shift || croak("parameter sql not passed");

    my @rows;

    my ($sth, $rv);
    eval {
      $sth = $dbh->prepare($sql) or croak $dbh->errstr;
      $rv  = $sth->execute or croak $dbh->errstr;
    };
    if ( $@ ) {
      $log->error( "Error running SQL: $sql\n $@" );
      die( $@ );
    }

    unless( $rv ) {
      $log->error( "Error executing SQL:\n $sql" );
      $log->printStack( 'error' );
      die $dbh->errstr;
    }

    while (my @row = $sth->fetchrow_array) {
        push(@rows,\@row);
    }

    $sth->finish;

    return @rows;

} # end selectSeveralColumns



###############################################################################
# selectHashArray
#
# Given a SQL statement which returns one or more columns, return an array
# of references to hashes of the results of each row of that query.
###############################################################################
sub selectHashArray {
    my $self = shift || croak("parameter self not passed");
    my $sql = shift || croak("parameter sql not passed");

    my @rows;

    my ($sth, $rv);
    eval {
      $sth = $dbh->prepare($sql) or croak $dbh->errstr;
      $rv  = $sth->execute or croak $dbh->errstr;
    };
    if ( $@ ) {
      $log->error( "Error running SQL: $sql\n $@" );
      die( $@ );
    }

    while (my $columns = $sth->fetchrow_hashref) {
        push(@rows,$columns);
    }

    $sth->finish;

    return @rows;

} # end selectHashArray

###############################################################################
# selectTwoColumnHashref
#
# Given a SQL statement which returns exactly two columns, return reference to
# a hash where key is column 0 and value is column 1.
# 
###############################################################################
sub selectTwoColumnHashref {
    my $self = shift || croak("parameter self not passed");
    my $sql = shift || croak("parameter sql not passed");

    my %hash;

    my ($sth, $rv);
    eval {
      $sth = $dbh->prepare($sql) or croak $dbh->errstr;
      $rv  = $sth->execute or croak $dbh->errstr;
    };
    if ( $@ ) {
      $log->error( "Error running SQL: $sql\n $@" );
      die( $@ );
    }

    while (my @row = $sth->fetchrow_array()) {
        $hash{$row[0]} = $row[1];
    }

    $sth->finish;

    return \%hash;
}

###############################################################################
# selectTwoColumnHash
#
# Given a SQL statement which returns exactly two columns, return a hash
# containing the results of that query. 
###############################################################################
sub selectTwoColumnHash {
  my $self = shift || croak("parameter self not passed");
  my $sql = shift || croak("parameter sql not passed");

  my ($rv, $sth, %hash);

  eval {
    $sth = $dbh->prepare("$sql") or croak $dbh->errstr;
    $rv  = $sth->execute or croak $dbh->errstr;
  };
  if ( $@ ) {
    my $msg =<<"    END";
    Error executing SQL: $@
    SQL causing error: $sql
    END
    $log->error( $msg );
    die $msg;
  }

  while (my @row = $sth->fetchrow_array) {
    $hash{$row[0]} = $row[1];
  }

  $sth->finish;

  return %hash;
}


###############################################################################
# updateOrInsertRow
#
# This method builds either an INSERT or UPDATE SQL statement based on the
# supplied parameters and executes the statement.
###############################################################################
sub updateOrInsertRow {
  my $self = shift || croak("parameter self not passed");
  my %args = @_;

  #### Decode the argument list
  my $table_name = $args{'table_name'} || die "ERROR: table_name not passed";
  my $rowdata_ref = $args{'rowdata_ref'}
    || die "ERROR: rowdata_ref not passed";
  my $database_name = $args{'database_name'} || '';
  my $return_PK = $args{'return_PK'} || 0;
  my $verbose = $args{'verbose'} || 0;
  my $print_SQL = $args{'print_SQL'} || 0;
  my $testonly = $args{'testonly'} || 0;
  my $insert = $args{'insert'} || 0;
  my $update = $args{'update'} || 0;
  my $PK = $args{'PK_name'} || $args{'PK'} || '';
  my $PK_value = $args{'PK_value'} || '';
  my $quoted_identifiers = $args{'quoted_identifiers'} || '';
  my $return_error = $args{'return_error'} || '';
  my $add_audit_parameters = $args{'add_audit_parameters'} || 0;


  #### Make sure either INSERT or UPDATE was selected
  unless ( ($insert or $update) and (!($insert and $update)) ) {
    croak "ERROR: Need to specify either 'insert' or 'update'\n\n";
  }


  #### If this is an UPDATE operation, make sure that we got the PK and value
  if ($update) {
    unless ($PK and $PK_value) {
      croak "ERROR: Need both PK and PK_value if operation is UPDATE\n\n";
    }
  }


  #### Initialize some variables
  my ($column_list,$value_list,$columnvalue_list) = ("","","");
  my ($key,$value,$value_ref);


  #### If verbose, prepare this section
  if ($verbose) {
    print "---- updateOrInsertRow --------------------------------\n";
    print "  Key,value pairs:\n";
  }


  #### If add_audit_parameters is enabled, add those columns 
  if ($add_audit_parameters) {
    if ($insert) {
      $rowdata_ref->{date_created}='CURRENT_TIMESTAMP';
      $rowdata_ref->{created_by_id}=$self->getCurrent_contact_id();
      $rowdata_ref->{owner_group_id}=$self->getCurrent_work_group_id();
      $rowdata_ref->{record_status}='N';
    }

    $rowdata_ref->{date_modified}='CURRENT_TIMESTAMP';
    $rowdata_ref->{modified_by_id}=$self->getCurrent_contact_id();
  }


  #### Loops over each passed rowdata element, building the query
  while ( ($key,$value) = each %{$rowdata_ref} ) {

    #### If quoted identifiers is set, then quote the key
    $key = '"'.$key.'"' if ($quoted_identifiers);

    #### If $value is a reference, assume it's a reference to a hash and
    #### extract the {value} key value.  This is because of Xerces.
    $value = $value->{value} if (ref($value));


    #### If the value is undef, then change it to NULL
    $value = 'NULL' unless (defined($value));

    print "KEY VAL	$key = $value\n" if ($verbose > 0);

    #### Add the key as the column name
    $column_list .= "$key,";

    #### Enquote and add the value as the column value
    $value = $self->convertSingletoTwoQuotes($value);
    if (uc($value) eq "CURRENT_TIMESTAMP" || uc($value) eq "NULL") {
      $value_list .= "$value,";
      $columnvalue_list .= "$key = $value,\n";
    } else {
      $value_list .= "'$value',";
      $columnvalue_list .= "$key = '$value',\n";
    }

  }


  unless ($column_list) {
    print "ERROR: insert_row(): column_list is empty!\n";
    return '';
  }


  #### Chop off the final commas
  chop $column_list;
  chop $value_list;
  chop $columnvalue_list;  # First the \n
  chop $columnvalue_list;  # Then the comma


  #### Create the final table name
  my $full_table_name = "$database_name$table_name";
  $full_table_name = '"'.$full_table_name.'"' if ($quoted_identifiers);

  #### Build the SQL statement
  #### Could also imagine allowing parameter binding as an option
  #### for database engines that support it instead of sending
  #### the full text SQL statement.  This should then support
  #### cached statement handles for multiple bindings per prepare.
  my $sql;
  if ($update) {
    my $PK_tag = $PK;
    $PK_tag = '"'.$PK.'"' if ($quoted_identifiers);
    $sql = "UPDATE $full_table_name SET $columnvalue_list WHERE $PK_tag = '$PK_value'";
  } else {
    $sql = "INSERT INTO $full_table_name ( $column_list ) VALUES ( $value_list )";
  }

  #### Print out the SQL if desired
  if ($verbose > 0 || $print_SQL > 0) {
    print "  SQL statement:\n";
    print "    $sql\n\n";
  }


  #### If we're just testing
  if ( $testonly ) {
      print "          ( not actually executing SQL ... )\n" if ($verbose > 0);
      $self->prepareSQL( sql => $sql );

      #### If the user asked for the PK to be returned, make a random one up
      if ( $return_PK ) {
	  return int( rand()*10000 ) + 1;
	  #### Otherwise, just return a 1
      } else {
	  return 1;
      }
  }


  #### Execute the SQL
  my $result = $self->executeSQL(sql=>$sql,return_error=>$return_error);


  #### If executeSQL() did not report success, return
  return $result unless ($result);


  #### If user didn't want PK, return with success
  return "1" unless ($return_PK);


  #### If user requested the resulting PK, return it
  if ($update) {
    return $PK_value;
  } else {
    return $self->getLastInsertedPK(table_name=>"$database_name$table_name",
      PK_column_name=>"$PK");
  }


}


###############################################################################
# convertSingletoTwoQuotes
#
# Converts all instances of a single quote to two consecutive single
# quotes as wanted by an SQL string already enclosed in single quotes
###############################################################################
sub convertSingletoTwoQuotes {
  my $self = shift;
  my $string = shift;

  return if (! defined($string));
  return '' if ($string eq '');
  return 0 unless ($string);

  my $resultstring = $string;
  $resultstring =~ s/'/''/g;  ####'

  return $resultstring;
} # end convertSingletoTwoQuotes





###############################################################################

1;

__END__
###############################################################################
###############################################################################
###############################################################################


