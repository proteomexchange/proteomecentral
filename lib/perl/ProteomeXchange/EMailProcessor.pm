package ProteomeXchange::EMailProcessor;

###############################################################################
# Class       : ProteomeXchange::EMailProcessor
# Author      : Eric Deutsch <edeutsch@systemsbiology.org>
#
# Description : This class is used to manage email communication with the
#               users and administrators of the ProteomeCentral resource
#
###############################################################################

use strict;

use DBI;

use vars qw($dbh);


###############################################################################
# Constructor
###############################################################################
sub new {
  my $self = shift;
  my %parameters = @_;

  my $class = ref($self) || $self;

  my $status = 'OK';


  #### Create the object with any attributes if supplied
  bless {
	 _status => $status,
	} => $class;
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


#######################################################################
# sendEmail
#######################################################################
sub sendEmail {
  my $self = shift;
  my %args = @_;
  my $SUB_NAME = 'sendEmail';

  #### Decode the argument list
  my $toRecipients = $args{'toRecipients'} || die "[$SUB_NAME] ERROR: toRecipients  not passed";
  my $ccRecipients = $args{'ccRecipients'} || die "[$SUB_NAME] ERROR: ccRecipients not passed";
  my $bccRecipients = $args{'bccRecipients'} || die "[$SUB_NAME] ERROR: bccRecipients not passed";
  my $subject = $args{'subject'} || die "[$SUB_NAME] ERROR: subject not passed";
  my $message = $args{'message'} || die "[$SUB_NAME] ERROR: message not passed";

  my @toRecipients = @{$toRecipients};
  my @ccRecipients = @{$ccRecipients};
  my @bccRecipients = @{$bccRecipients};

  my $toLine = '';
  my $ccLine = '';
  my $recipients = '';

  #### Process recipients in the To: part
  for (my $i=0; $i<scalar(@toRecipients); $i+=2) {
    my $j = $i+1;
    $toLine .= " $toRecipients[$i] <$toRecipients[$j]>,";
    $recipients .= "$toRecipients[$j],";
  }

  #### Process recipients in the Cc: part
  if (scalar(@ccRecipients) > 1) {
    for (my $i=0; $i<scalar(@ccRecipients); $i+=2) {
      my $j = $i+1;
      $ccLine .= " $ccRecipients[$i] <$ccRecipients[$j]>,";
      $recipients .= "$ccRecipients[$j],";
    }
  }

  #### Process recipients in the Bcc: part
  if (scalar(@bccRecipients) > 1) {
    for (my $i=0; $i<scalar(@bccRecipients); $i+=2) {
      my $j = $i+1;
      $recipients .= "$bccRecipients[$j],";
    }
  }

  #### Remove trailing commas
  chop($toLine);
  chop($ccLine);
  chop($recipients);

  #### Create message
  my $content = '';
  $content .= "From: ProteomeCentral Agent <sbeams\@systemsbiology.org>\n";
  $content .= "To:$toLine\n";
  $content .= "Cc:$ccLine\n" if ($ccLine);
  $content .= "Reply-to: ProteomeCentral Agent <sbeams\@systemsbiology.org>\n";
  $content .= "Subject: $subject\n\n";
  $content .= $message;

  if (1) {
    my $mailprog = "/usr/lib/sendmail";
    open (MAIL, "|$mailprog $recipients") || die("Can't open $mailprog!\n");
    print MAIL $content;
    close (MAIL);
  } else {
    print $content;
  }

  return(1);
}



###############################################################################

1;

__END__
###############################################################################
###############################################################################
###############################################################################

