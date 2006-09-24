# RDF::Base::Node::Literal
# -------------
# $Revision $
# $Date $
# -----------------------------------------------------------------------------


=head1 NAME

RDF::Base::Node::Literal - RDF Literal class used for representing scalar literals.


=head1 VERSION

This document describes RDF::Base::Node::Literal version 0.0.1


=head1 SYNOPSIS

    use RDF::Base::Node::Literal;
    $literal = RDF::Base::Node::Literal->new( value => 'hello world' );
    $language = RDF::Base::Node::Literal->new( value => '日本語', language => 'ja' );
    $number = RDF::Base::Node::Literal->new( value => '7', datatype => 'http://www.w3.org/2001/XMLSchema#int' );
    

=head1 DESCRIPTION

RDF Literal nodes.

=cut

package RDF::Base::Node::Literal;

use version; $VERSION = qv('0.0.1');

use strict;
use warnings;
use base qw(RDF::Base::Node);

# use Moose;
use Carp;
use Params::Coerce qw(coerce);
use Scalar::Util qw(blessed);

# extends 'RDF::Base::Node';
# 
# has 'value'		=> ( is => 'rw', isa => 'Str', required => 1 );
# has 'language'	=> ( is => 'rw', isa => 'Str', predicate => 'has_language' );
# has 'datatype'	=> ( is => 'rw', isa => 'Uri', coerce => 1, predicate => 'has_datatype' );

# =begin private
# 
# =item C<< BUILD >>
# 
# Moose BUILD method throws an exception if an attempt is made to create a literal
# with both langauge and datatype.
# 
# =end private
# 
# =cut
# 
# sub BUILD {
# 	my ($self, $params)	= @_;
# 	confess "Literal node cannot have both language and datatype attributes"
# 		if (exists($params->{'language'}) and exists($params->{'datatype'}));
# }


# Module implementation here

=head1 METHODS

=over 4

=cut

=item C<< new ( value => $value ) >>

=item C<< new ( value => $value, language => $language ) >>

=item C<< new ( value => $value, datatype => $datatype ) >>

=cut

sub new {
	my $class	= shift;
	my %args	= @_;
	confess "Literal node cannot have both language and datatype attributes"
		if (exists($args{'language'}) and exists($args{'datatype'}));
	
	my $value		= $args{ value };
	my $language	= $args{ language };
	my $datatype	= $args{ datatype };
	my $self	= bless( { value => $value }, $class );
	
	if (defined($language)) {
		$self->{language}	= $language;
	} elsif (defined($datatype)) {
		if (not(ref($datatype))) {
			$datatype	= RDF::Base::Node::Resource->new( uri => $datatype );
		} elsif (not(blessed($datatype) and $datatype->isa('RDF::Base::Node::Resource'))) {
			$datatype	= coerce( 'RDF::Base::Node::Resource', $datatype );
		}
		
		$self->{datatype}	= $datatype;
	}
	
	return $self;
}


=item C<< value >>

=cut

sub value {
	my $self	= shift;
	return $self->{value};
}

=item C<< literal_value >>

Returns the string value of the literal.

=cut

sub literal_value {
	my $self	= shift;
	return $self->value;
}

=item C<< language >>

Returns the language code of the literal.

=cut

sub language {
	my $self	= shift;
	return $self->{language};
}

=item C<< has_language >>

Returns true if the literal has a language code associated with it.

=cut

sub has_language {
	my $self	= shift;
	return defined($self->{language});
}

=item C<< datatype >>

Returns the datatype URI string of the literal.

=cut

sub datatype {
	my $self	= shift;
	return unless (defined $self->{datatype});
	return $self->{datatype}->uri->as_string;
}

=item C<< has_datatype >>

Returns true if the literal has a datatype associated with it.

=cut

sub has_datatype {
	my $self	= shift;
	return defined($self->{datatype});
}


=item C<< is_literal >>

Returns true if the object is a valid literal node object.

=cut

sub is_literal {
	return 1;
}

=item C<< equal ( $node ) >>

Returns true if the object value is equal to that of the specified C<$node>.

=cut

sub equal {
	my ($self, $other) = @_;
	
	return 0 unless blessed($other) and $other->isa( 'RDF::Base::Node::Literal' );
	
	if ($self->has_language or $other->has_language) {
		no warnings 'uninitialized';
		return ($self->language eq $other->language and $self->value eq $other->value);
	} elsif ($self->has_datatype or $other->has_datatype) {
		no warnings 'uninitialized';
		return ($self->datatype eq $other->datatype and $self->value eq $other->value);
	} else {
		return $self->value eq $other->value;
	}
}

=item C<< as_string >>

Returns a serialized representation of the node.

=cut

sub as_string {
	my $self	= shift;
	my $string;
	if ($self->literal_value =~ /'/) {
		$string	= sprintf('"%s"', $self->literal_value);
	} else {
		$string	= sprintf("'%s'", $self->literal_value);
	}
	
	if ($self->has_language) {
		$string	.= '@' . $self->language;
	} elsif ($self->has_datatype) {
		$string	.= '^^<' . $self->datatype . '>';
	}
	
	return $string;
}

sub __from_RDF_Redland_Node {
	my $class	= shift;
	my $redland	= shift;
	my $value	= $redland->literal_value;
	my %args	= ( value => $value );
	if (my $lang = $redland->literal_value_language) {
		$args{ language }	= $lang;
	} elsif (my $dt = $redland->literal_datatype) {
		$dt	= $dt->as_string;
		$args{ datatype }	= RDF::Base::Node::Resource->new( uri => $dt );
	}
	
	return $class->new( %args );
}

1; # Magic true value required at end of module
__END__

=back

=head1 DIAGNOSTICS

=for author to fill in:
    List every single error and warning message that the module can
    generate (even the ones that will "never happen"), with a full
    explanation of each problem, one or more likely causes, and any
    suggested remedies.

=over

=item C<< Error message here, perhaps with %s placeholders >>

[Description of error here]

=item C<< Another error message here >>

[Description of error here]

[Et cetera, et cetera]

=back


=head1 CONFIGURATION AND ENVIRONMENT

=for author to fill in:
    A full explanation of any configuration system(s) used by the
    module, including the names and locations of any configuration
    files, and the meaning of any environment variables or properties
    that can be set. These descriptions must also include details of any
    configuration language used.
  
RDF::Base::Node::Literal requires no configuration files or environment variables.


=head1 DEPENDENCIES

=for author to fill in:
    A list of all the other modules that this module relies upon,
    including any restrictions on versions, and an indication whether
    the module is part of the standard Perl distribution, part of the
    module's distribution, or must be installed separately. ]

None.


=head1 INCOMPATIBILITIES

=for author to fill in:
    A list of any modules that this module cannot be used in conjunction
    with. This may be due to name conflicts in the interface, or
    competition for system or program resources, or due to internal
    limitations of Perl (for example, many modules that use source code
    filters are mutually incompatible).

None reported.


=head1 BUGS AND LIMITATIONS

=for author to fill in:
    A list of known problems with the module, together with some
    indication Whether they are likely to be fixed in an upcoming
    release. Also a list of restrictions on the features the module
    does provide: data types that cannot be handled, performance issues
    and the circumstances in which they may arise, practical
    limitations on the size of data sets, special cases that are not
    (yet) handled, etc.

No bugs have been reported.

Please report any bugs or feature requests to
C<greg@evilfunhouse.com>.


=head1 AUTHOR

Gregory Todd Williams  C<< <greg@evilfunhouse.com> >>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006, Gregory Todd Williams C<< <greg@evilfunhouse.com> >>. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.


