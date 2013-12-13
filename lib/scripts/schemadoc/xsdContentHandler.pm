package xsdContentHandler;
###############################################################################
###############################################################################
###############################################################################
# xsdContentHandler package: SAX parser callback routines
#
# This xsdContentHandler package defines all the content handling callback
# subroutines used the SAX parser
###############################################################################
use strict;
use XML::Xerces;
use Date::Manip;
use Storable qw/dclone/;
use vars qw(@ISA $VERBOSE $DEBUG);
@ISA = qw(XML::Xerces::PerlContentHandler);
$VERBOSE = 1;
$DEBUG = 1;
$| = 1;

###############################################################################
# new
###############################################################################
sub new {
  my $class = shift;
  my $self = $class->SUPER::new();
  $self->object_stack([]);
  $self->unhandled({});

  $self->{activeElement} = ();
  $self->{activeType} = ();
  my @tmp = ();
  $self->{activeEntityType} = \@tmp;

  return $self;
}


###############################################################################
# object_stack
###############################################################################
sub object_stack {
  my $self = shift;
  if (scalar @_) {
    $self->{OBJ_STACK} = shift;
  }
  return $self->{OBJ_STACK};
}


###############################################################################
# setVerbosity
###############################################################################
sub setVerbosity {
  my $self = shift;
  if (scalar @_) {
    $VERBOSE = shift;
  }
}


###############################################################################
# unhandled
###############################################################################
sub unhandled {
  my $self = shift;
  if (scalar @_) {
    $self->{UNHANDLED} = shift;
  }
  return $self->{UNHANDLED};
}


###############################################################################
# start_element
###############################################################################
sub start_element {
  my ($self,$uri,$localname,$qname,$attrs) = @_;

  #### Make a hash to of the attributes
  my %attrs = $attrs->to_hash();

  #### Convert all the values from hashref to single value
  while (my ($aa1,$aa2) = each (%attrs)) {
    $attrs{$aa1} = $attrs{$aa1}->{value};
  }

  #### mzIdentML hack
  $attrs{name} =~ s/^psi-pi:// if ($attrs{name});
  $attrs{type} =~ s/^psi-pi:// if ($attrs{type});
  $attrs{ref} =~ s/^psi-pi:// if ($attrs{ref});

  #### For wrapper schemas that include a reference to another schema,
  #### there may be a ref attribute instead of a name.
  #### If so, assign the ref to the name, but set the type to a special
  #### *ref* flag, which triggers special code in the documentation writer
  my $specialType;
  if ($localname eq 'element' && $attrs{ref} && ! $attrs{name}) {
    $attrs{name} = $attrs{ref};
    $specialType = '*ref*';
  }
  if ($localname eq 'group' && $attrs{ref} && ! $attrs{name}) {
    #print " --) Found group $attrs{ref}\n";
    $attrs{name} = $attrs{ref};
    $attrs{substitutionGroup} = $attrs{ref};
    $specialType = '*ref*';
  }


  #### Debugging
  if ($DEBUG) {
    my $parent = 'none';
    if ($self->object_stack && $self->object_stack->[-1] && $self->object_stack->[-1]->{name}) {
      $parent = $self->object_stack->[-1]->{name};
    }
    print "---------------------------\n";
    print "localname=$localname\n";
    print "name=$attrs{name}\n" if ($attrs{name});
    print "parent=$parent\n";
  }


  #### element
  if ($localname eq 'element' || $localname eq 'group') {
    if ($self->{namespace}) {
      $attrs{name} = "$self->{namespace}:$attrs{name}"
	unless ($attrs{name} =~ /^$self->{namespace}:/);
    }

    $self->{elements}->{$attrs{name}}->{name} = $attrs{name};
    $self->{elements}->{$attrs{name}}->{type} = $specialType || $attrs{type};

    my $parent = $self->getActiveEntity();
    $self->pushActiveEntity(
      type=>'element',
      specialType=>$specialType,
      name=>$attrs{name},
      parent=>$parent,
      substitutionGroup=>$attrs{substitutionGroup},
    );

    if ($self->object_stack->[-1]->{name} eq 'sequence' ||
        $self->object_stack->[-1]->{name} eq 'choice' ||
        $localname eq 'group') {

      #### If there is cardinality from the parent, use that
      if ((!defined($attrs{minOccurs})) && defined($self->object_stack->[-1]->{minOccurs})) {
	$attrs{minOccurs} = $self->object_stack->[-1]->{minOccurs};
      }
      if ((!defined($attrs{maxOccurs})) && defined($self->object_stack->[-1]->{maxOccurs})) {
	$attrs{maxOccurs} = $self->object_stack->[-1]->{maxOccurs};
      }

      unless ($parent->{subelements}->{'**List'}) {
	$parent->{subelements}->{'**List'} = ();
      }
      if ($DEBUG) {
	print "Adding subelement $attrs{name} to $parent->{name}\n";
      }

      if ($parent->{subelements}->{$attrs{name}}) {
	die( "WHOA: This subelement already exists!!\n");
      } else {
	push(@{$parent->{subelements}->{'**List'}},$attrs{name});
	$parent->{subelements}->{$attrs{name}}->{name} = $attrs{name};
	$parent->{subelements}->{$attrs{name}}->{type} = $specialType || $attrs{type};
	$attrs{minOccurs} = 1 unless(defined($attrs{minOccurs}));
	$attrs{maxOccurs} = 1 unless(defined($attrs{maxOccurs}));
	$parent->{subelements}->{$attrs{name}}->{minOccurs} = $attrs{minOccurs};
	$parent->{subelements}->{$attrs{name}}->{maxOccurs} = $attrs{maxOccurs};
      }
    }
  }

  #### attribute
  if ($localname eq 'attribute') {
    my $parent = $self->getActiveEntity();
    $parent->{attributes}->{$attrs{name}}->{name} = $attrs{name};
    $parent->{attributes}->{$attrs{name}}->{type} = $specialType || $attrs{type};
    $parent->{attributes}->{$attrs{name}}->{use} = $attrs{use};
    $self->{activeAttribute} = $attrs{name};
  }

  #### complexType
  if ($localname eq 'complexType') {
    if ($attrs{name}) {
      #print "ZZ: name=$attrs{name}\n" if ($attrs{name});
      $self->{types}->{$attrs{name}}->{name} = $attrs{name};
      $self->pushActiveEntity(type=>'type',name=>$attrs{name});
    } else {
      print "WARNING: No name here. this is messy\n" if ($DEBUG);
      $self->pushActiveEntity(type=>'type',name=>undef);
    }
  }

  #### simpleType
  if ($localname eq 'simpleType') {
    if ($attrs{name}) {
      $self->{types}->{$attrs{name}}->{name} = $attrs{name};
      $self->pushActiveEntity(type=>'type',name=>$attrs{name});
    } else {
      print "WARNING: No name here. this is messy\n" if ($DEBUG);
      $self->pushActiveEntity(type=>'type',name=>undef);
    }
  }

  #### restriction
  if ($localname eq 'restriction') {
    my $parent = $self->getActiveEntity();
    my $attribute = $self->{activeAttribute};
    if ($attribute) {
      $parent->{attributes}->{$attribute}->{type} = $specialType || $attrs{type} if ($attrs{type});
      $parent->{attributes}->{$attribute}->{type} = $attrs{base} if ($attrs{base});
    } else {
      $parent->{type} = $specialType || $attrs{type} if ($attrs{type});
      $parent->{type} = $attrs{base} if ($attrs{base});
    }
    use Data::Dumper;
    print Dumper($parent);
    #exit;
  }


  #### pattern
  if ($localname eq 'pattern') {
    my $parent = $self->getActiveEntity();
    my $attribute = $self->{activeAttribute};
    if ($attrs{value}) {
      if ($attribute) {
	$parent->{attributes}->{$attribute}->{type} .= " with restriction<BR><PRE>$attrs{value}</PRE>";
      } else {
	$parent->{type} .= " with restriction<BR><PRE>$attrs{value}</PRE>";
      }
    } else {
      print "WARNING: found pattern element without value attribute\n";
    }
    #use Data::Dumper;
    #print Dumper($parent);
    #exit;
  }


  #### extension (for inheritance)
  if ($localname eq 'extension') {
    my $parent = $self->getActiveEntity();
    $parent->{base} = $attrs{base};
  }


  #### Increase the counters and print some progress info
  $self->{counter}++;
  print $self->{counter}."..." if ($VERBOSE && $self->{counter} % 100 == 0);


  #### Push information about this element onto the stack
  my $tmp;
  $tmp->{name} = $localname;
  push(@{$self->object_stack},$tmp);


} # end start_element


###############################################################################
# end_element
###############################################################################
sub end_element {
  my ($self,$uri,$localname,$qname) = @_;

  #### element
  if ($localname eq 'element') {
    $self->popActiveEntity();
  }

  #### attribute
  if ($localname eq 'attribute') {
    $self->{activeAttribute} = undef;
  }

  #### complexType
  if ($localname eq 'complexType' || $localname eq 'group') {
    $self->popActiveEntity();
  }

  #### If there's an object on the stack consider popping it off
  if (scalar @{$self->object_stack()}){

    #### If the top object on the stack is the correct one, pop it off
    #### else die bitterly
    if ($self->object_stack->[-1]->{name} eq "$localname") {
      pop(@{$self->object_stack});
    } else {
      die("STACK ERROR: Wanted to pop off an element fo type '$localname'".
        " but instead we found '".$self->object_stack->[-1]->{name}."'!");
    }

  } else {
    die("STACK ERROR: Wanted to pop off an element of type '$localname'".
        " but instead we found the stack empty!");
  }

}



###############################################################################
# character
###############################################################################
sub characters {
  my ($self,$characters) = @_;

  return if ($characters =~ /^\s*$/);

  my $parent = $self->getActiveEntity();
  return unless($parent);

  if ($DEBUG) {
    print "characterdata:\n";
    print "  activeElement=$parent->{name}\n";
  }

  #### For attribute documentation
  if ($self->{activeAttribute}) {

    if ($DEBUG) {
      print "LLL(1): Adding documentation to $self->{activeAttribute}: '".substr($characters,0,50)."...'\n";
      my $tmpDefinition = $parent->{attributes}->{$self->{activeAttribute}}->{definition} || 'undef';
      print "        Previous definition was $tmpDefinition\n";
    }
    $parent->{attributes}->{$self->{activeAttribute}}->{definition} = $characters;

  #### Otherwise element documentation
  } else {

    #if ($parent->{name} =~ /param/i || $characters =~ /Two or more/) {
    if (0) {
      print "======= Here at $parent->{name}\n";
      print "characterdata:\n";
      print "  activeElement=$parent->{name}\n";
      print "  characters=$characters\n";
      print "  object_stack-2=".$self->object_stack->[-2]->{name}."\n";
    }

    #### Ugly fudge
    if ($parent->{name} eq 'cvParam') {
      $self->{elements}->{selectionWindow}->{subelements}->{cvParam}->{definition} = $characters;

    #} elsif ($parent->{isSubelementOf}) {
    #  $self->{elements}->{$parent->{isSubelementOf}->{parent}->{name}}->{subelements}->{$parent->{name}}->{definition} = $characters;
    #  print "YYYY: Putting definition '$characters' into $parent->{isSubelementOf}->{parent}->{name}:$parent->{name} definition instead of directly onto $parent->{name}\n";

    } else {

      #if ($DEBUG || 1) {
      #	#print "Adding documentation '".substr($characters,0,30)."...' to $parent->{name}\n";
      #	print "Adding documentation '".$characters."' to $parent->{name}\n";
      #}

      if ($DEBUG) {
	print "LLL(2): Adding documentation to $parent->{name}: '".substr($characters,0,50)."...'\n";
	my $tmpDefinition = $parent->{definition} || 'undef';
	print "        Previous definition was $tmpDefinition\n";
      }
      $parent->{definition} = $characters;
      $parent->{nDefinitions}++;
      $parent->{"definition_$parent->{nDefinitions}"} = $characters;
    }


  }

} # end characters



###############################################################################
# readExamplesFile
###############################################################################
sub readExamplesFile {
  my $METHOD = 'readExamplesFile';
  my $self = shift || die ("self not passed");
  my %args = @_;

  my $input_file = $args{input_file};

  $self->{examples}->{'**status'} = 'initialized';
  $self->{cvParams}->{'**status'} = 'initialized';

  unless ($input_file) {
    $input_file = 'tiny.pwiz.mzML';
  }

  #### Check to see if file exists
  unless (-e $input_file) {
    print "ERROR: examples file '$input_file' does not exist\n";
    return;
  }

  #### Open file
  unless (open(INFILE,$input_file)) {
    print "ERROR: Unable to open examples file '$input_file'\n";
    return;
  }
  print "INFO: Reading examples file '$input_file'\n";


  #### Read in file
  #### Very simple reader with no sanity/error checking
  my $line;
  my %activeElements;
  my $currentElement = '';
  while ($line = <INFILE>) {
    $line =~ s/[\r\n]//g;
    next if ($line =~ /^\s*$/);
    #if ($line =~ /^\s*\<([\w-:]+)[ \>]/) {
    if ($line =~ /^\s*\<([-:\w]+)/) {
      my $element = $1;

      #### Truncation hack for mzML binary data
      if ($line =~ /(\s*)\<binary\>(.+)\<\/binary\>/) {
	my $indent = $1;
	my $binaryData = $2;
	my $cutBinaryData = substr($binaryData,0,50)."...";
	$line = "$indent<binary>$cutBinaryData</binary>";
      }

      unless (uc($element) eq 'CVPARAM' || $element eq 'paramGroupRef' || uc($element) eq 'USERPARAM' || $line =~ /\/\>/) {
	$currentElement = $element;
      }

      unless (exists($self->{examples}->{$element}->{text})) {
	$self->{examples}->{$element}->{text} = '';
	$activeElements{$element}++;
      }
    }

    foreach my $activeElement (keys(%activeElements)) {
      my $tmpline = $line;

      if ($self->{examples}->{$activeElement}->{text} eq '') {
	print "First time for $activeElement\n" if ($DEBUG);
	if ($line =~ /^(\s+)\</) {
	  $self->{examples}->{$activeElement}->{indent} = $1;
	} else {
	  $self->{examples}->{$activeElement}->{indent} = undef;
	}
      }

      my $indent = $self->{examples}->{$activeElement}->{indent};
      if (defined($indent)) {
	my $tmpindent = $indent;
	while ($tmpindent =~ /^  /) {
	  $tmpindent =~ s/^  //;
	  $tmpline =~ s/^  //;
	}
      }

      $self->{examples}->{$activeElement}->{text} .= "$tmpline\n";
      $activeElements{$activeElement}++;

      my $elem = "</$activeElement>";
      if ($line =~ /$elem/ || $line =~ /\<$activeElement .+\/\>/) {
	delete($activeElements{$activeElement});
	chooseBetterExample($self->{examples}->{$activeElement});
	#if ($activeElement eq 'IdentificationFile') {
	#  print "IdentificationFile1: $self->{examples}->{$activeElement}->{bestText}\n";
	#}
      } elsif ($activeElements{$activeElement} > 7) {
	$self->{examples}->{$activeElement}->{text} .= "\t...\n</$activeElement>\n";
	delete($activeElements{$activeElement});
	chooseBetterExample($self->{examples}->{$activeElement});
	#if ($activeElement eq 'IdentificationFile') {
	#  print "IdentificationFile2: $self->{examples}->{$activeElement}->{bestText}\n";
	#}
      }



      $elem = "/>";
      if (defined($activeElements{$activeElement}) && $activeElements{$activeElement} == 2 && $line =~ m#/>#) {
	delete($activeElements{$activeElement});
	chooseBetterExample($self->{examples}->{$activeElement});
      }
    }

    #### Collect some examples of CvParam lines to display
    if ($line =~ /\<[cC]vParam .*accession=\"([A-Z]+:\d+)\"/) {
      my $cvParam = $1;
      #print "found cvParam $cvParam\n";
      unless ($self->{cvParams}->{$currentElement}->{$cvParam}) {
	$line =~ s/^\s+//;
	$self->{cvParams}->{$currentElement}->{$cvParam} = $line;
	$self->{cvParams}->{$currentElement}->{possibilities} .= "$line\n";
      }
    }

    #### Collect some examples of userParam lines to display
    if ($line =~ /\<[uU]serParam .*name=\"(.+?)\"/) {
      my $userParam = $1;
      #print "found userParam $userParam\n";
      unless ($self->{userParams}->{$currentElement}->{$userParam}) {
	$line =~ s/^\s+//;
	$self->{userParams}->{$currentElement}->{$userParam} = $line;
	$self->{userParams}->{$currentElement}->{possibilities} .= "$line\n";
      }
    }

  }


  close(INFILE);
  $self->{examples}->{'**status'} = 'read ok';
  $self->{cvParams}->{'**status'} = 'read ok';

  return;

} # end readExamplesFile



###############################################################################
# chooseBetterExample
###############################################################################
sub chooseBetterExample {
  my $METHOD = 'chooseBetterExample';
  my $elementExample = shift || die("ERROR: Did not pass elementExample");

  if (exists($elementExample->{bestText})) {
    if (length($elementExample->{bestText}) < length($elementExample->{text})) {
      $elementExample->{bestText} = $elementExample->{text};
    }
  } else {
    $elementExample->{bestText} = $elementExample->{text};
  }
  delete($elementExample->{text});

}



###############################################################################
# readCvMappingFile
###############################################################################
sub readCvMappingFile {
  my $METHOD = 'readCvMappingFile';
  my $self = shift || die ("self not passed");
  my %args = @_;

  my $input_file = $args{input_file};

  $self->{cvMappings}->{'**status'} = 'initialized';

  unless ($input_file) {
    $input_file = 'ms-mapping.xml';
  }

  #### Check to see if file exists
  unless (-e $input_file) {
    print "ERROR: examples file '$input_file' does not exist\n";
    return;
  }

  #### Open file
  unless (open(INFILE,$input_file)) {
    print "ERROR: Unable to open CV mapping file '$input_file'\n";
    return;
  }
  print "INFO: Reading CV mapping file '$input_file'\n";


  #### Read in file
  #### Very simple reader with no sanity/error checking
  my $line;
  my $parent;
  my $requirementLevel;
  my $commentMode = 0;
  while ($line = <INFILE>) {
    $line =~ s/[\r\n]//g;

    #### Ignore XML comments. This is not very robust. Works only for whole-line comments
    if ($line =~ /^\s*\<!--/) {
      $commentMode = 1;
    }
    if ($commentMode == 1 && $line =~ /--\>/) {
      $commentMode = 0;
      next;
    }
    next if ($commentMode);


    #### If this is a recognizable element
    if ($line =~ /^\s*\<(\w+)[ \>]/) {
      my $element = $1;
      #print "    CCC: element = $element\n";
      if ($line =~ /Format/) {
	#print "    CCC: contains Format: $line\n";
      }

      if ($element eq 'CvMappingRule') {
	my @attrs = qw( cvElementPath requirementLevel );
	my %attrs;
	foreach my $attr (@attrs) {
	  if ($line =~ /$attr=\"(.*?)\"/) {
	    $attrs{$attr} = $1;
	  }
	}
	if ($attrs{cvElementPath} && $attrs{cvElementPath} =~ m#(/ProteomeXchange.+)/cvParam#) {
	  $parent = $1;
	  $parent =~ s/psi-pi://g;

	  #### Kludge to work around problems in the mzQuantML mapping file today 2012-11-08
	  #my @tmp = split("/",$parent);
	  #for (my $i=0; $i<scalar(@tmp); $i++) {
	  #  $tmp[$i] = ucfirst($tmp[$i]);
	  #}
	  #$parent = join("/",@tmp);
	  #### End Kludge

	  #print "    CCC: parent = $parent\n";
	} else {
	  print "WARNING: No parent in $line\n" if ($DEBUG);
	  $parent = undef;
	}
	$requirementLevel = $attrs{requirementLevel};
      }

      if ($element eq 'CvTerm') {
	my @attrs = qw( termAccession useTerm termName isRepeatable allowChildren cvIdentifier );
	my %attrs;
	foreach my $attr (@attrs) {
	  if ($line =~ /$attr=\"(.*?)\"/) {
	    $attrs{$attr} = $1;
	  }
	}

	#### What to do with this cvTerm
	$attrs{requirementLevel} = $requirementLevel;
	if ($parent) {
	  $self->{cvMappings}->{$parent}->{$attrs{termAccession}} = \%attrs;
	}
      }

    } # end if an element

  } # end while

  close(INFILE);
  $self->{cvMappings}->{'**status'} = 'read ok';

  return;

} # end readCvMappingFile



###############################################################################
# readNotesFile
###############################################################################
sub readNotesFile {
  my $METHOD = 'readNotesFile';
  my $self = shift || die ("self not passed");
  my %args = @_;

  my $input_file = $args{input_file};

  $self->{notes}->{'**status'} = 'initialized';

  unless ($input_file) {
    $input_file = 'specialNotes.txt';
  }

  #### Check to see if file exists
  unless (-e $input_file) {
    print "ERROR: Notes file '$input_file' does not exist\n";
    return;
  }

  #### Open file
  unless (open(INFILE,$input_file)) {
    print "ERROR: Unable to open notes file '$input_file'\n";
    return;
  }
  print "INFO: Reading notes file '$input_file'\n";


  #### Read in file
  #### Very simple reader with no sanity/error checking
  my $line;
  my $element;
  while ($line = <INFILE>) {
    #$line =~ s/[\r\n]//g;
    next if ($line =~ /^#/);
    next if ($line =~ /^\s*$/);

    if ($line =~ /^\[(\w+)\]/) {
      $element = $1;
      print "INFO: Reading a note for <$element>\n" if ($DEBUG);

    } else {
      $self->{notes}->{$element} .= $line;
    }

  }

  close(INFILE);
  $self->{notes}->{'**status'} = 'read ok';

  return;

} # end readNotesFile


###############################################################################
# generateDocumentation
###############################################################################
sub generateDocumentation {
  my $METHOD = 'generateDocumentation';
  my $self = shift || die ("self not passed");
  my %args = @_;

  my $starting_element = $args{starting_element} || '???';

  my $buffer = '';

  $self->{queued_elements} = ();
  $self->{completed_elements} = undef;
  $self->{elementEntries};

  $buffer .= $self->writeElement(element=>$starting_element);

  if (1) {
    #### Write all the documentation components into a hash
    while (my $next_element = shift(@{$self->{queued_elements}})) {
      my $elementData = $self->writeElement(element=>$next_element);
      if ($elementData) {
	$self->{elementEntries}->{$next_element} = $elementData;
      }
    }

    #### Sort and print all the elements
    foreach my $element ( sort caseInsensitive (keys(%{$self->{elementEntries}}))) {
      $buffer .= $self->{elementEntries}->{$element};
    }

  }

  return $buffer;

} # end generateDocumentation


###############################################################################
# caseInsensitive
###############################################################################
sub caseInsensitive {
  return(uc($a) cmp uc($b));
}


###############################################################################
# getElementInformationHash
###############################################################################
sub getElementInformationHash {
  my $METHOD = 'getElementInformationHash';
  my $self = shift || die ("self not passed");
  my %args = @_;

  my $element = $args{element} || die("ERROR[$METHOD]: element not passed");

  my $info = $self->{elements}->{$element};
  $self->{returnedBuffer} = '';

  if ($self->{elements}->{$element}->{type}) {
    #$buffer .= "  (xsd type=$self->{elements}->{$element}->{type})\n\n";
    my $type = $self->{elements}->{$element}->{type};
    $type =~ s/^([\w\-]+)://;
    #$type =~ /^([\w\-]+):/;
    my $namespace;
    if ($1) {
      $namespace = $1;
      #print "AA: element=$element, type=$type, namespace=$namespace\n";
    }

    #### If the current element is just a reference to another document, we have no definition
    if ($type eq '*ref*') {
      #print "type=$type\n";
      #print "source=$self->{types}->{$type}\n" if ($self->{types}->{$type});
      #print "dest=$info\n";
      if (exists($self->{types}->{$type})) {
	#### actually we do have it! Use it!
      } elsif ($element =~ /^([\w\-]+):([\w\-]+)$/) {
	if (exists($self->{type}->{$2})) {
	  print "Setting type $type to $2\n";
	  $type = $2;
	} elsif (exists($self->{elements}->{$2})) {
	  print "AB: Found element $2\n";
	  $type = $2;
	  $element = $2;
	  $self->inheritStructure(destination=>$info,source=>$self->{elements}->{$type});
	} else {
	  die("blech");
	}

      } else {
	#$self->{returnedBuffer} .= "<P>This element is defined in another xsd document.</P>\n";
	#$self->{returnedBuffer} .= "</table><br/>\n\n";
	return $info;
      }


      print "type=$type\n";
      #exit;
    }

    #### Instead of just linking to the type, copy the type into the object
    #$info = $self->{types}->{$type};
    if (!defined($namespace) || ($namespace ne 'xs' && $namespace ne 'xsd')) {
      #print "type=$type\n";
      #print "source=$self->{types}->{$type}\n";
      #print "dest=$info\n";
      $self->inheritStructure(destination=>$info,source=>$self->{types}->{$type});
    }

  } elsif ($self->{elements}->{$element}->{base}) {
    #$buffer .= "  (xsd type=$self->{elements}->{$element}->{type})\n\n";
    my $type = $self->{elements}->{$element}->{base};
    $type =~ s/^([\w\-]+)://;

    #### Instead of just linking to the type, copy the type into the object
    #$info = $self->{types}->{$type};
    if ($1 ne 'xs') {
      print "F:type=$type\n";
      print "F:source=$self->{types}->{$type}\n";
      print "F:dest=$info\n";
      $self->inheritStructure(destination=>$info,source=>$self->{types}->{$type});
    }

  } else {
    #$buffer .= "  (no xsd type)\n\n";
  }

  return $info;

} # end getElementInformationHash



###############################################################################
# writeElement
###############################################################################
sub writeElement {
  my $METHOD = 'writeElement';
  my $self = shift || die ("self not passed");
  my %args = @_;

  my $element = $args{element} || die("ERROR[$METHOD]: element not passed");
  print "[writeElement]: Writing out $element\n" if ($DEBUG);

  return if ($self->{completed_elements}->{$element});

  my $buffer = '';
  our $elementCounter++;

  my $info = $self->getElementInformationHash(element => $element);
  if ($self->{returnedBuffer}) {
    $buffer .= $self->{returnedBuffer};
  }

  $self->{completed_elements}->{$element} = 1;

  $buffer .= "<H2>Element &lt;<a name=\"$element\">$element</a>&gt;</H2>\n\n";


  #### open html table
  $buffer .= "<table class='zero'>\n";

  #### Definition
  #$buffer .= "<H3>Definition:</H3>\n";
  $buffer .= "<tr>\n<td class='zero'><b>Definition:</b></td>\n<td class='zero'>";
  my $definition = $self->{elements}->{$element}->{definition};
  unless ($definition) {
    $definition = ($info->{definition}) || '-';
  }
  $definition =~ s/must/MUST/g;
  if ($self->{elements}->{$element}->{nDefinitions} == 1) {
    $buffer .= "$definition\n";
  } else {
    $buffer .= "<B>Depending on context:</B><BR>\n";
    for (my $i=1; $i<=$self->{elements}->{$element}->{nDefinitions}; $i++) {
      $buffer .= "<B>$i</B>: ".$self->{elements}->{$element}->{"definition_$i"}."<BR>\n";
    }
  }
  $buffer .= "</td>\n</tr>\n";


  #### Type
  if ($self->{elements}->{$element}->{type} && $self->{elements}->{$element}->{type} ne '*ref*') {
    $buffer .= "<tr>\n<td class='zero'><b>Type:</b></td>\n<td class='zero'>";
    $buffer .= "$self->{elements}->{$element}->{type}\n";
    $buffer .= "</td>\n</tr>\n";
  }

  #### Context
  #$buffer .= "<H3>Context:</H3>\n";
  #$buffer .= html_encode("  <$element>");
  #$buffer .= "\n\n";


  #### Attributes
  #$buffer .= "<H3>Attributes:</H3>\n";
  $buffer .= "<tr>\n<td class='zero'><b>Attributes:</b></td>\n<td class='zero'>";
  my $tableStart = "<TABLE border=\"1\">\n";
  $tableStart .= "<TR><TH>Attribute Name</TH><TH>Data Type</TH><TH>Use</TH><TH>Definition</TH></TR>\n";
  my $tableStarted = 0;
  if ($info->{attributes}) {
    foreach my $attribute (sort(keys(%{$info->{attributes}}))) {
      unless ($tableStarted) {
	$buffer .= $tableStart;
	$tableStarted = 1;
      }
      my $use = $info->{attributes}->{$attribute}->{use} || 'optional';
      my $definition = $info->{attributes}->{$attribute}->{definition} || '<font color="red">???</font>';
      my $type = $info->{attributes}->{$attribute}->{type} || '<font color="red">???</font>';
      $definition =~ s/must/MUST/g;

      $buffer .= "<TR><TD>$attribute</TD><TD>$type</TD><TD>$use</TD><TD>$definition</TD></TR>\n";
    }
  } else {
    $buffer .= "none<BR>\n";
  }
  if ($tableStarted) {
    $buffer .= "</TABLE>\n";
  }
  $buffer .= "</td>\n</tr>\n";


  #### Subelements
  #$buffer .= "<H3>Subelements:</H3>\n";
  $buffer .= "<tr>\n<td class='zero'><b>Subelements:</b></td>\n<td class='zero'>";
  my $allowsCvParams = 0;
  $tableStart = "<TABLE border=\"1\">\n";
  $tableStart .= "<TR><TH>Subelement Name</TH><TH>minOccurs</TH><TH>maxOccurs</TH><TH>Definition</TH></TR>\n";
  $tableStarted = 0;

  if ($info->{subelements}) {
    #print "ZZ $element: ".join(",",@{$info->{subelements}->{'**List'}})."\n";
    my %processedSubelements;
    foreach my $subelement (@{$info->{subelements}->{'**List'}}) {
      if ($processedSubelements{$subelement}) {
	#print "Yuck! There shouldn't be dupes, but there are!! Why??\n";
	next;
      }
      $processedSubelements{$subelement} = 1;


      my @substitutedElements = ( 'none' );
      if ($self->{substitutionGroups}->{$subelement}) {
	@substitutedElements = sort(keys(%{$self->{substitutionGroups}->{$subelement}}));
      }

      #### If the datatype is a *ref*, then pull the elements out of there
      if ($info->{subelements}->{$subelement}->{type} && $info->{subelements}->{$subelement}->{type} eq '*ref*') {
	my $refGroupInfo = $self->getElementInformationHash(element => $subelement);
	@substitutedElements = sort(@{$refGroupInfo->{subelements}->{'**List'}});
      }

      foreach my $substitutedElement ( @substitutedElements ) {

        unless ($tableStarted) {
	  $buffer .= $tableStart;
	  $tableStarted = 1;
        }

        my $minOccurs = $info->{subelements}->{$subelement}->{minOccurs};
        my $maxOccurs = $info->{subelements}->{$subelement}->{maxOccurs};

        my $definition = $info->{subelements}->{$subelement}->{definition} ||
          $self->{elements}->{$subelement}->{definition};
	my $thisElement = $subelement;

	#### Debugging
	my $thisType = '';
	if ($info->{subelements}->{$subelement}->{type}) {
	  $thisType = "($info->{subelements}->{$subelement}->{type})";
	}

	if ($substitutedElement ne 'none') {
	  #### Erase the previous definition because it will be a holdover from a ref
	  $definition = undef;

	  unless ($definition) {
	    #print "TTTTT: def is $definition\n";
	    $definition = $self->{elements}->{$substitutedElement}->{definition};
	    #print "TTTTT: But changed it to: $definition\n";
	  }
	  $thisElement = $substitutedElement;
	}

        unless ($definition) {
	  my $type = $info->{subelements}->{$subelement}->{type};
	  if ($type) {
	    $type =~ s/^[\w\-]+://;
	    my $typeInfo = $self->{types}->{$type};
	    $definition = $typeInfo->{definition};
	  }
	}

        unless ($definition) {
	  my $trueElementInfo = $self->getElementInformationHash(element=>$subelement);
	  #print "QQQQQ: Had no definition\n";
	  $definition = $trueElementInfo->{definition};
	  #print "QQQ: Now it's '$definition'\n" if (defined($definition));
	}

	$definition = "A single entry from an ontology or a controlled vocabulary." if ($thisElement =~ /cvParam/i);
	$definition = "A single user-defined parameter." if ($thisElement =~ /userParam/i);


        $minOccurs = '-' unless(defined($minOccurs));
        $maxOccurs = '-' unless(defined($maxOccurs));
        $definition = '-' unless(defined($definition));
        $definition =~ s/must/MUST/g;

	if ($thisElement =~ /cvParam/i) {
	  $allowsCvParams = 1;
	}

        $buffer .= "<TR><TD><a href=\"#$thisElement\">$thisElement</a></TD><TD>$minOccurs</TD><TD>$maxOccurs</TD><TD>$definition</TD></TR>\n";
        unless($self->{completed_elements}->{$thisElement}) {
	  push(@{$self->{queued_elements}},$thisElement);
        }
      }
    }

  #### Else no subelements
  } else {
    $buffer .= "none<BR>\n";
  }

  if ($tableStarted) {
    $buffer .= "</TABLE>\n";
  }
  $buffer .= "</td>\n</tr>\n";


  #### Figure
  if ($self->{figureMapping}->{$element}) {
    $buffer .= "<tr>\n<td class='zero'><b>Graphical Context:</b></td>\n<td class='zero'>";
    $buffer .= "<img src=\"$self->{figureMapping}->{$element}\">\n";
    $buffer .= "</td>\n</tr>\n";
  }

  #### Examples
  $buffer .= "<tr>\n<td class='zero'><b>Example Context:</b></td>\n<td class='zero'>";
  $buffer .= "<PRE>";
  if ($self->{examples}->{$element}) {
    my $example = $self->{examples}->{$element}->{bestText};
    $example =~ s/\t/  /g;
    $buffer .= html_encode($example);
  }
  $buffer .= "</PRE>\n";
  $buffer .= "</td>\n</tr>\n";


  #### cvParam mapping rules
  my @relevantMappings;
  foreach my $cvMapping ( keys(%{$self->{cvMappings}}) ) {
    #print "Testing '$element' against cvMapping '$cvMapping'\n";
    if ($cvMapping =~ m#(.+/$element$)#) {
      #print "Found $element in $cvMapping\n";
      push(@relevantMappings,$1);
    }
  }

  if (@relevantMappings || $allowsCvParams) {
    $buffer .= "<tr>\n<td class='zero'><b>cvParam Mapping Rules:</b></td>\n<td class='zero'>";
  }

  foreach my $cvMapping (@relevantMappings) {
    $buffer .= "<PRE>";
    $buffer .= "Path $cvMapping\n";
    my $rules = $self->{cvMappings}->{$cvMapping};
    foreach my $rule ( keys(%{$rules}) ) {
      print "WARNING: empty rule at $element\n" unless ($rule);
      my $requirementLevel = $rules->{$rule}->{requirementLevel};
      my $term = $rules->{$rule}->{termAccession} || '???';
      my $termName = $self->{cv}->{terms}->{$term}->{name} ||
	$rules->{$rule}->{termName} || '???';
      my $termDefinition = $self->{cv}->{terms}->{$term}->{definition} || '???';
      my $isRepeatable = $rules->{$rule}->{isRepeatable};
      my $cardinality = 'with ??? cardinality';
      $cardinality = 'one or more times' if ($isRepeatable eq 'true');
      $cardinality = 'only once' if ($isRepeatable eq 'false');

      my $allowParentTerm = 0;
      $allowParentTerm = 1 if ($rules->{$rule}->{useTerm} && $rules->{$rule}->{useTerm} eq 'true');

      my $allowChildTerm = 0;
      $allowChildTerm = 1 if ($rules->{$rule}->{allowChildren} && $rules->{$rule}->{allowChildren} eq 'true');

      if ($allowParentTerm && $allowChildTerm) {
	$buffer.= "$requirementLevel supply term <a target=\"new\" href=\"http://www.ebi.ac.uk/ontology-lookup/browse.do?ontName=MS&termId=$term\">$term</a> (<span title=\"$termDefinition\" class=\"popup\">$termName</span>) or any of its children $cardinality\n";
      } elsif ($allowParentTerm) {
	$buffer.= "$requirementLevel supply term <a target=\"new\" href=\"http://www.ebi.ac.uk/ontology-lookup/browse.do?ontName=MS&termId=$term\">$term</a> (<span title=\"$termDefinition\" class=\"popup\">$termName</span>) $cardinality\n";
      } elsif ($allowChildTerm) {
	$buffer.= "$requirementLevel supply a *child* term of <a target=\"new\" href=\"http://www.ebi.ac.uk/ontology-lookup/browse.do?ontName=MS&termId=$term\">$term</a> (<span title=\"$termDefinition\" class=\"popup\">$termName</span>) $cardinality\n";
      }

      if ($allowChildTerm) {
	my @childTerms = $self->getLeafLevelChildrenOfCvTerm(term=>$term);
	my $termCount = 0;
	my $previousChildTerm = '';
	foreach my $childTerm ( sort(@childTerms) ) {
	  next if ($childTerm eq $previousChildTerm);
	  $previousChildTerm = $childTerm;
	  my $childTermName = $self->{cv}->{terms}->{$childTerm}->{name} || '???';
          my $childTermDefinition = $self->{cv}->{terms}->{$childTerm}->{definition} || '???';

	  #### Create a warning of terms with no definition
	  my $childTermDefinitionWarning = '';
	  $childTermDefinitionWarning = '<font color="red">WARNING: Term has no definition!</font>' if ($childTermDefinition eq '???');

	  if ($termCount < 10) {
	    #$buffer.= "  e.g.: $childTerm ($childTermName)\n";
            $buffer.= "  e.g.: <a target=\"new\" href=\"http://www.ebi.ac.uk/ontology-lookup/browse.do?ontName=MS&termId=$childTerm\">$childTerm</a> (<span title=\"$childTermDefinition\" class=\"popup\">$childTermName</span>) $childTermDefinitionWarning\n";
	  } elsif ($termCount == 10 && scalar(@childTerms) > 10) {
	    $buffer.= "  <a target=\"new\" href=\"http://www.ebi.ac.uk/ontology-lookup/browse.do?ontName=MS&termId=$term\">et al.</a>\n";
	  }
	  $termCount++;
	}
      }

    }
    #use Data::Dumper;
    #$buffer .= Dumper($rules);
    $buffer .= "</PRE>\n";
  }


  if (@relevantMappings) {
    $buffer .= "</td>\n</tr>\n";
  } elsif ($allowsCvParams) {
    $buffer .= "<font color=\"red\">WARNING: There are no cvParam mapping rules for this element even though cvParam is an allowed subelement.</a></td>\n</tr>\n";
    print "WARNING: There are no cvParam mapping rules for $element\n";
  }


  #### Example cvParams
  if ($self->{cvParams}->{$element}) {
    $buffer .= "<tr>\n<td class='zero'><b>Example cvParams:</b></td>\n<td class='zero'>";
    $buffer .= "<PRE>";
    my $example = $self->{cvParams}->{$element}->{possibilities};
    $example =~ s/\t/  /g;
    $buffer .= html_encode($example);
    $buffer .= "</PRE>\n";
    $buffer .= "</td>\n</tr>\n";
  }


  #### Example userParams
  if ($self->{userParams}->{$element}) {
    $buffer .= "<tr>\n<td class='zero'><b>Example userParams:</b></td>\n<td class='zero'>";
    $buffer .= "<PRE>";
    my $example = $self->{userParams}->{$element}->{possibilities};
    $example =~ s/\t/  /g;
    $buffer .= html_encode($example);
    $buffer .= "</PRE>\n";
    $buffer .= "</td>\n</tr>\n";
  }

  #### Notes and Constraints
  if ($self->{notes}->{$element}) {
    $buffer .= "<tr>\n<td class='zero'><b>Notes and Constraints:</b></td>\n<td class='zero'>";
    my $notes = $self->{notes}->{$element};
    $notes = html_encode($notes);
    $notes =~ s/must/MUST/g;
    $buffer .= "$notes\n";
    $buffer .= "</td>\n</tr>\n";
  } else {
  }


  $buffer .= "</table><br/>\n\n";

  return $buffer;

} # end writeElement



###############################################################################
# pushActiveEntity
###############################################################################
sub pushActiveEntity {
  my $METHOD = 'pushActiveEntity';
  my $self = shift || die ("self not passed");
  my %args = @_;

  my $type = $args{type}; ## || die("ERROR[$METHOD]: type not passed");
  my $name = $args{name}; ## || die("ERROR[$METHOD]: name not passed");
  my $parent = $args{parent};
  my $specialType = $args{specialType};

  push(@{$self->{activeEntityType}},$type);

  if ($type eq 'element') {
    push(@{$self->{activeElement}},$name);
    push(@{$self->{activeParent}},{parent=>$parent,specialType=>$specialType});
  }

  if ($type eq 'type') {
    push(@{$self->{activeType}},$name);
  }

  return;

} # end pushActiveEntity


###############################################################################
# getActiveEntity
###############################################################################
sub getActiveEntity {
  my $METHOD = 'getActiveEntity';
  my $self = shift || die ("self not passed");
  my %args = @_;

  my @list = @{$self->{activeEntityType}};
  return unless(@list);

  my $activeType;
  my $distance = -1;
  my $elementDistance = -1;
  my $typeDistance = -1;

  my $parentName;
  my $parent;

  while (!defined($parentName)) {
    $activeType = $list[$distance];
    if ($activeType eq 'element') {
      $parentName = $self->{activeElement}->[$elementDistance];
      $parent = $self->{elements}->{$parentName};
      my $isSubelementOf = $self->{activeParent}->[$elementDistance];
      if (defined($isSubelementOf->{specialType}) && $isSubelementOf->{specialType} eq '*ref*') {
	$parent->{isSubelementOf} = $isSubelementOf;
      }
      $elementDistance--;
    }

    if ($activeType eq 'type') {
      $parentName = $self->{activeType}->[$typeDistance];
      if ($self->{types} && $parentName) {
	$parent = $self->{types}->{$parentName};
      }
      $typeDistance--;
    }

    if ($parentName) {
      print "--activeType=$activeType (parentName=$parentName) at distance $distance\n" if ($DEBUG);
    } else {
      print "--activeType=$activeType (undef parentName) at distance $distance\n" if ($DEBUG);
    }

    $distance--;

  }

  return $parent;

} # end getActiveEntity



###############################################################################
# popActiveEntity
###############################################################################
sub popActiveEntity {
  my $METHOD = 'popActiveEntity';
  my $self = shift || die ("self not passed");
  my %args = @_;

  my @list = @{$self->{activeEntityType}};
  my $activeType = $list[$#list];
  my $parent;

  if ($activeType eq 'element') {
    pop(@{$self->{activeEntityType}});
    pop(@{$self->{activeElement}});
    pop(@{$self->{activeParent}});
  }

  if ($activeType eq 'type') {
    pop(@{$self->{activeEntityType}});
    pop(@{$self->{activeType}});
  }

  return;

} # end popActiveEntity



###############################################################################
# html_encode
###############################################################################
sub html_encode {
  my $METHOD = 'html_encode';
  my $string = shift;

  return undef unless defined($string);

  $string =~ s/&(?!(?:amp|quot|gt|lt|#\d+);)/&amp;/g;
  $string =~ s/\"/&quot;/g;
  $string =~ s/>/&gt;/g;
  $string =~ s/</\&lt;/g;

  return $string;

} # end html_encode


###############################################################################


###############################################################################
# inheritStructure
###############################################################################
sub inheritStructure {
  my $METHOD = 'inheritStructure';
  my $self = shift || die ("self not passed");
  my %args = @_;

  my $source = $args{source} || die("ERROR[$METHOD]: source not passed");
  my $destination = $args{destination} || die("ERROR[$METHOD]: destination not passed");

  #### Recursively resolve inheritance of the source first
  if ($source->{base} &&$source->{base} ne 'xs:string' ) {
    my $basetype = $source->{base};
    $basetype =~ s/^([\w\-]+)://;
    print "  INFO: Recursing with $basetype\n" if ($DEBUG);
    $self->inheritStructure(destination=>$source,source=>$self->{types}->{$basetype});
    delete($source->{base});
  }

  foreach my $key (keys(%{$source})) {

    #### Consider definition attribute
    if ($key eq 'definition') {
      #print "------------------- $source->{name}\n";
      #print "Source: $source->{$key}\n";
      my $desttmp = $destination->{$key};
      $desttmp = 'undef' if (!defined($destination->{$key}));
      #print "Destin: $desttmp\n";
      #$destination->{$key} = $source->{$key};
      #next;
    }

    if ($key eq 'name') {
      next;
    }
    if (ref($source->{$key}) =~ /HASH/ || ref($source->{$key}) =~ /ARRAY/) {
      print "  INFO: Copying $key: $source->{name} to $destination->{name}\n" if ($DEBUG);
      if (($destination->{$key})) {
	print "        But wait: destination already is $destination->{$key}, so copying each element individually: " if ($DEBUG);
	foreach my $subkey (keys(%{$source->{$key}})) {
	  print "($subkey) " if ($DEBUG);
	  if ($subkey eq '**List') {
	    unshift(@{$destination->{$key}->{$subkey}},@{$source->{$key}->{$subkey}});
	  } else {
	    $destination->{$key}->{$subkey} = $source->{$key}->{$subkey};
	  }
	}
	print "\n" if ($DEBUG);
      } else {
	$destination->{$key} = dclone($source->{$key});
      }
    } else {
      print "  INFO: Copying $key: $source->{name} to $destination->{name}\n" if ($DEBUG);
      if ($destination->{$key} && $destination->{$key} ne "*ref*") {
	if ($DEBUG) {
	  print "        But wait: destination already is value!\n";
	  print "          Not copying: $source->{$key}\n";
	  print "                   to: $destination->{$key}\n";
	}
      } else {
	$destination->{$key} = $source->{$key};
      }
    }
  }

  return;

} # end inheritStructure



###############################################################################
# readControlledVocabularyFile
###############################################################################
sub readControlledVocabularyFile {
  my $METHOD = 'readControlledVocabularyFile';
  my $self = shift || die ("self not passed");
  my %args = @_;

  my $input_file = $args{input_file};

  $self->{cv}->{status} = 'initialized';

  unless ($input_file) {
    $input_file = 'psi-ms.obo';
  }

  #### Check to see if file exists
  unless (-e $input_file) {
    print "ERROR: controlled vocabulary file '$input_file' does not exist\n";
    print "WARNING: NOT CHECKING CV TERMS!!!\n";
    return;
  }

  #### Open file
  unless (open(INFILE,$input_file)) {
    print "ERROR: Unable to open controlled vocabulary file '$input_file'\n";
    print "WARNING: NOT CHECKING CV TERMS!!!\n";
    return;
  }
  print "INFO: Reading cv file '$input_file'\n";


  #### Read in file
  #### Very simple reader with no sanity/error checking
  my ($line,$id,$name,$relationshipType,$parent);
  while ($line = <INFILE>) {
    $line =~ s/[\r\n]//g;
    if ($line =~ /^id: (\S+)\s*/) {
      $id = $1;
    }
    if ($line =~ /^name: (.+)\s*$/) {
      $name = $1;
      $self->{cv}->{terms}->{$id}->{name} = $name;
    }
    if ($line =~ /^def: \"(.+)\"/) {
      $self->{cv}->{terms}->{$id}->{definition} = $1;
    }
    if ($line =~ /^relationship: (\S+) (\S+)/) {
      $relationshipType = $1;
      $parent = $2;
      $self->{cv}->{relationships}->{$id}->{"$relationshipType $parent"} = $parent;
      $self->{cv}->{relationships}->{$parent}->{"has_child $id"} = $id;
    }
    if ($line =~ /^is_a: (\S+)/) {
      $parent = $1;
      $self->{cv}->{relationships}->{$id}->{"is_a $parent"} = $parent;
      $self->{cv}->{relationships}->{$parent}->{"has_child $id"} = $id;
    }
  }


  close(INFILE);
  $self->{cv}->{status} = 'read ok';

  return;

} # end readControlledVocabularyFile



###############################################################################
# readFiguresMappingFile
###############################################################################
sub readFiguresMappingFile {
  my $METHOD = 'readFiguresMappingFile';
  my $self = shift || die ("self not passed");
  my %args = @_;

  my $input_file = $args{input_file};

  $self->{figureMapping}->{status} = 'initialized';

  unless ($input_file) {
    $input_file = 'mzML_figures_mapping.txt';
  }

  #### Check to see if file exists
  unless (-e $input_file) {
    print "ERROR: figures mapping file '$input_file' does not exist\n";
    print "WARNING: No figures will be embedded!!!\n";
    return;
  }

  #### Open file
  unless (open(INFILE,$input_file)) {
    print "ERROR: Unable to open figures mapping file '$input_file'\n";
    print "WARNING: No figures will be embedded!!!\n";
    return;
  }
  print "INFO: Reading figures mapping file '$input_file'\n";


  #### Read in file
  while (my $line = <INFILE>) {
    $line =~ s/[\r\n]//g;
    next if ($line =~ /^\s*$/);
    my ($image,$element) = split(/\s+/,$line);
    $self->{figureMapping}->{$element} = "figures/$image";
  }


  close(INFILE);
  $self->{figureMapping}->{status} = 'read ok';

  return;

} # end readFiguresMappingFile



###############################################################################
# getChildrenOfCvTerm
###############################################################################
sub getChildrenOfCvTerm {
  my $METHOD = 'getChildrenOfCvTerm';
  my $self = shift || die("self not passed");
  my %args = @_;

  my $term = $args{term} || print("ERROR[$METHOD]: Term not passed\n");
  my @terms;

  my $relationships = $self->{cv}->{relationships}->{$term};
  foreach my $relationship ( keys(%{$relationships}) ) {
    if ($relationship =~ /has_child/) {
      my $childTerm = $relationships->{$relationship};
      push(@terms,$childTerm);
    }
  }

  return(@terms);

} # end getChildrenOfCvTerm


###############################################################################
# getLeafLevelChildrenOfCvTerm
###############################################################################
sub getLeafLevelChildrenOfCvTerm {
  my $METHOD = 'getLeafLevelChildrenOfCvTerm';
  my $self = shift || die("self not passed");
  my %args = @_;

  my $term = $args{term} || print("ERROR[$METHOD]: Term not passed\n");
  my @terms;

  my @possibleLeafTerms = $self->getChildrenOfCvTerm(term=>$term);
  foreach my $possibleLeafTerm ( @possibleLeafTerms ) {
    my @possibleLowerTerms = $self->getLeafLevelChildrenOfCvTerm(term=>$possibleLeafTerm);
    if (@possibleLowerTerms) {
      push(@terms,@possibleLowerTerms);
    } else {
      push(@terms,$possibleLeafTerm);
    }
  }

  return(@terms);

} # end getLeafLevelChildrenOfCvTerm


###############################################################################
1;
