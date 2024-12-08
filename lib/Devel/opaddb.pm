package dumpvar;

=encoding utf8

=head1 NAME

Devel::opaddb.pm - Display Object::Pad objects in Perl's debugger

=head1 SYNOPSIS

  perl -d:opaddb your/program.pl

=head1 DESCRIPTION

This module enhances Perl's builtin debugger's ability to display
L<Object::Pad|https://metacpan.org/pod/Object::Pad> objects and L<PDL>
ndarrays.  For Object::Pad, It shows the name of the fields, base
classes and roles in addition to their values.  PDL objects are
printed using PDL's stringification of the object instead of the
value of its scalar.


=head2 NORMAL USE

Drop this file in a directory within your C<@INC> path in a directory
F<Devel>, so that Perl can find it as module C<Devel::opaddb>.  Then
start the debugger by enabling this module as debugger:

   perl -d:opaddb your/program.pl

=head2 PURPOSE

As much as L<Object::Pad> is being used as a testbed for
L<Corinna|https://github.com/Ovid/Cor>, this module might serve as a
testbed for what we might want to expect from the Perl debugger when
Corinna objects are in the wild.

It is the author's belief that the missing support for debugging,
either with the Perl debugger or with L<Data::Dumper> and friends, is
a major obstacle for the adoption of OO frameworks like L<Class::Std>.
Their "inside out" objects provide nice encapsulation, but also
difficult bug hunting.

=head1 EXAMPLE

Here's an output comparison for a simple object.

Perl's builtin debugger:

  DB<1> x $sphere
  0  Sphere=ARRAY(0x565204bbfd28)
     0  Point=HASH(0x565204a90bc8)
        'Object::Pad/fields' => ARRAY(0x565204bbfcb0)
           0  ARRAY(0x565204bbfbf0)
              0  '-1'
              1  '-2'
              2  '-3'
           1  'Center'
     1  4
     2  'BLACK'

Devel::opaddb debugger:

  DB<1> x $sphere
  0  Sphere=ARRAY(0x55724f5e5da0)
      -> Object::Pad object with 2 field(s):
        field $center = Point=HASH(0x55724f4b1588)
         -> Object::Pad object with 1 field(s):
           field $name = 'Center'
         -> extends Vector with 1 field(s):
           field @coords = ARRAY(0x55724f5e5cc8)
           0  '-1'
           1  '-2'
           2  '-3'
        field $radius = 4
      -> consumes:
        role Pigment with 1 field(s):
        field $color = 'BLACK'

=head1 CAVEATS

L<Object::Pad> is a module with many experimental capabilities and
still evolving, and this debugger is even more experimental and tries
to catch up.

=head1 BUGS

=over 4

=item * There's no debugger interface to access an indivdual field by
its name.

=item * There's no proper indentation for nested objects.

=back

=head1 RESTRICTIONS

This module doesn't play well with other debugger extensions which
change the format of the debugger output.  It overrides changes made
in F<.perldb>.

L<Object::Pad> needs to be version 0.63 or newer.

=head1 NOTES

This is a hack.  The Perl debugger isn't very invitating for
extensions, and the author didn't spend much time to write a complete
Perl debugger.  It works by overriding the function C<dumpvar::unwrap>
which is provided by Perl's F<dumpvar.pl>.  The function in this
module is almost a verbatim copy.  Two short chunks have been added to
call new routines which handle Object::Pad objects in C<NATIVE> and
C<HASH> representation.

=head1 AUTHOR

Harald Jörg, <haj@posteo.de>

=head1 COPYRIGHT AND LICENSE

COPYRIGHT 2021-2022 Harald Jörg

This library is free software; you may redistribute it and/or
modify it under the same terms as Perl itself.

=cut

# We apologize for that, but the debugger uses a lot of variables
# which might- or not - be provided by the user.
no warnings;

# Load the original debugger, and also immediately load dumpvar.pl.
# We want our function to override dumpvar.pl's, and not vice versa.
require 'perl5db.pl';
require 'dumpvar.pl';

package dumpvar;

# unwrap_object: 

sub unwrap_object {
    my ($v) = @_;
    require Object::Pad::MOP::Class;
    my $class = Object::Pad::MOP::Class->for_class(ref $v);
    unwrap_opad_object($v,$class);
}

sub unwrap_opad_object {
    my ($v,$class) = @_;
    print "${sp} -> Object::Pad object";
    unwrap_object_fields($v,$class);
    unwrap_object_roles($v,$class);
    my @parents = $class->superclasses;
    if (@parents) {
	for my $parent (@parents) {
            print "$sp -> extends ", $parent->name;
            unwrap_opad_object($v,$parent);
        }
    }
}

sub unwrap_object_fields {
    my ($object,$class) = @_;
    my @fields = $class->fields;
    if (@fields) {
	print " with ", scalar @fields, " field(s):\n";
	for my $field(@fields) {
	    print "$sp   field ",$field->name, " = ";
	    DumpElem($field->value($object), $s, $m-1),
	}
    }
    else {
	print " without fields\n";
    }
}

sub unwrap_object_roles {
    my ($object,$class) = @_;
    my @roles = $class->roles;
    if (@roles) {
	print "$sp -> consumes:\n";
	for my $role(@roles) {
	    print "$sp   role ", $role->name;
	    unwrap_object_fields($object,$role);
	}
    }
}

sub DumpElem; # unwrap calls this sub without params, so predeclare it

# The following is an almost verbatim copy of &dumpvar::unwrap, as
# available from dumpvar.pl in the Perl core.  Two blocks have been
# inserted here, marked like this:
#     # *** begin support of Object::Pad objects
#     ... inserted code here
#     # *** end   support of Object::Pad objects
no warnings 'redefine';
*dumpvar::unwrap = sub {
    return if $DB::signal;
    local($v) = shift ; 
    local($s) = shift ; # extra no of spaces
    local($m) = shift ; # maximum recursion depth
    return if $m == 0;
    local(%v,@v,$sp,$value,$key,@sortKeys,$more,$shortmore,$short) ;
    local($tHashDepth,$tArrayDepth) ;

    $sp = " " x $s ;
    $s += 3 ; 

    eval {
    # Check for reused addresses
    if (ref $v) { 
      my $val = $v;
      $val = &{'overload::StrVal'}($v) 
	if %overload:: and defined &{'overload::StrVal'};
      # Match type and address.                      
      # Unblessed references will look like TYPE(0x...)
      # Blessed references will look like Class=TYPE(0x...)
      $val =~ s/^.*=//; # suppress the Class part, just keep TYPE(0x...)
      ($item_type, $address) = 
        $val =~ /([^\(]+)        # Keep stuff that's     
                                 # not an open paren
                 \(              # Skip open paren
                 (0x[0-9a-f]+)   # Save the address
                 \)              # Skip close paren
                 $/x;            # Should be at end now

      if (!$dumpReused && defined $address) { 
	$address{$address}++ ;
	if ( $address{$address} > 1 ) { 
	  print "${sp}-> REUSED_ADDRESS\n" ; 
	  return ; 
	} 
      }
    } elsif (ref \$v eq 'GLOB') {
      # This is a raw glob. Special handling for that.
      $address = "$v" . "";	# To avoid a bug with globs
      $address{$address}++ ;
      if ( $address{$address} > 1 ) { 
	print "${sp}*DUMPED_GLOB*\n" ; 
	return ; 
      } 
    }

    if (ref $v eq 'Regexp') {
      # Reformat the regexp to look the standard way.
      my $re = "$v";
      $re =~ s,/,\\/,g;
      print "$sp-> qr/$re/\n";
      return;
    }

    # *** begin support of Object::Pad objects
    if ( $item_type eq 'HASH' &&
	 UNIVERSAL::isa($v,'Object::Pad::UNIVERSAL') ) {
	&unwrap_object($v);
    }
    # *** end   support of Object::Pad objects

    elsif ( $item_type eq 'HASH' ) {
        # Hash ref or hash-based object.
	my @sortKeys = sort keys(%$v) ;
	undef $more ; 
	$tHashDepth = $#sortKeys ; 
	$tHashDepth = $#sortKeys < $hashDepth-1 ? $#sortKeys : $hashDepth-1
	  unless $hashDepth eq '' ; 
	$more = "....\n" if $tHashDepth < $#sortKeys ; 
	$shortmore = "";
	$shortmore = ", ..." if $tHashDepth < $#sortKeys ; 
	$#sortKeys = $tHashDepth ; 
	if ($compactDump && !grep(ref $_, values %{$v})) {
	  #$short = $sp . 
	  #  (join ', ', 
# Next row core dumps during require from DB on 5.000, even with map {"_"}
	  #   map {&stringify($_) . " => " . &stringify($v->{$_})} 
	  #   @sortKeys) . "'$shortmore";
	  $short = $sp;
	  my @keys;
	  for (@sortKeys) {
	    push @keys, &stringify($_) . " => " . &stringify($v->{$_});
	  }
	  $short .= join ', ', @keys;
	  $short .= $shortmore;
	  (print "$short\n"), return if length $short <= $compactDump;
	}
	for $key (@sortKeys) {
	    return if $DB::signal;
	    $value = $ {$v}{$key} ;
	    print "$sp", &stringify($key), " => ";
	    DumpElem $value, $s, $m-1;
	}
	print "$sp  empty hash\n" unless @sortKeys;
	print "$sp$more" if defined $more ;
    }

    # *** begin support of Object::Pad objects
    elsif ( $item_type eq 'ARRAY' &&
	    UNIVERSAL::isa($v,'Object::Pad::UNIVERSAL') ) {
	&unwrap_object($v);
    }
    # *** end   support of Object::Pad objects

    elsif ( $item_type eq 'ARRAY' ) { 
        # Array ref or array-based object. Also: undef.
        # See how big the array is.
	$tArrayDepth = $#{$v} ; 
	undef $more ; 
        # Bigger than the max?
	$tArrayDepth = $#{$v} < $arrayDepth-1 ? $#{$v} : $arrayDepth-1 
	  if defined $arrayDepth && $arrayDepth ne '';
        # Yep. Don't show it all.
	$more = "....\n" if $tArrayDepth < $#{$v} ; 
	$shortmore = "";
	$shortmore = " ..." if $tArrayDepth < $#{$v} ;

	if ($compactDump && !grep(ref $_, @{$v})) {
	  if ($#$v >= 0) {
	    $short = $sp . "0..$#{$v}  " . 
	      join(" ", 
		   map {exists $v->[$_] ? stringify $v->[$_] : "empty"} (0..$tArrayDepth)
		  ) . "$shortmore";
	  } else {
	    $short = $sp . "empty array";
	  }
	  (print "$short\n"), return if length $short <= $compactDump;
	}
	#if ($compactDump && $short = ShortArray($v)) {
	#  print "$short\n";
	#  return;
	#}
	for $num (0 .. $tArrayDepth) {
	    return if $DB::signal;
	    print "$sp$num  ";
	    if (exists $v->[$num]) {
                if (defined $v->[$num]) {
	          DumpElem $v->[$num], $s, $m-1;
                } 
                else {
                  print "undef\n";
                }
	    } else {
	    	print "empty field\n";
	    }
	}
	print "$sp  empty array\n" unless @$v;
	print "$sp$more" if defined $more ;
    } elsif ( $item_type eq 'SCALAR' ) {
	# *** begin support of PDL objects
	use builtin qw( blessed );
	if (blessed($v)  eq  'PDL') {
	    print "$sp-> $v\n";
	}
	else {
	# *** end   support of PDL objects
            unless (defined $$v) {
              print "$sp-> undef\n";
              return;
            }
	    print "$sp-> ";
	    DumpElem $$v, $s, $m-1;
	}
    } elsif ( $item_type eq 'REF' ) { 
	    print "$sp-> $$v\n";
            return unless defined $$v;
	    unwrap($$v, $s+3, $m-1);
    } elsif ( $item_type eq 'CODE' ) { 
            # Code object or reference.
	    print "$sp-> ";
	    dumpsub (0, $v);
    } elsif ( $item_type eq 'GLOB' ) {
      # Glob object or reference.
      print "$sp-> ",&stringify($$v,1),"\n";
      if ($globPrint) {
	$s += 3;
       dumpglob($s, "{$$v}", $$v, 1, $m-1);
      } elsif (defined ($fileno = eval {fileno($v)})) {
	print( (' ' x ($s+3)) .  "FileHandle({$$v}) => fileno($fileno)\n" );
      }
    } elsif (ref \$v eq 'GLOB') {
      # Raw glob (again?)
      if ($globPrint) {
       dumpglob($s, "{$v}", $v, 1, $m-1) if $globPrint;
      } elsif (defined ($fileno = eval {fileno(\$v)})) {
	print( (' ' x $s) .  "FileHandle({$v}) => fileno($fileno)\n" );
      }
    }
    };
    if ($@) {
      print( (' ' x $s) .  "<< value could not be dumped: $@ >>\n");
    }

    return;
};

1;
