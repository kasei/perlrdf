# RDF::Trine::Node::Literal
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Node::Literal - RDF Node class for literals

=head1 VERSION

This document describes RDF::Trine::Node::Literal version 0.128

=cut

package RDF::Trine::Node::Literal;

use strict;
use warnings;
no warnings 'redefine';
use base qw(RDF::Trine::Node);

use RDF::Trine::Error;
use Data::Dumper;
use Scalar::Util qw(blessed);
use Carp qw(carp croak confess);

######################################################################

our ($VERSION, $USE_XMLLITERALS, $USE_FORMULAE);
BEGIN {
	$VERSION	= '0.128';
	eval "use RDF::Trine::Node::Literal::XML;";
	$USE_XMLLITERALS	= (RDF::Trine::Node::Literal::XML->can('new')) ? 1 : 0;
	eval "use RDF::Trine::Node::Formula;";
	$USE_FORMULAE = (RDF::Trine::Node::Formula->can('new')) ? 1 : 0;
}

######################################################################

=head1 METHODS

=over 4

=cut

=item C<new ( $string, $lang, $datatype, $canonical_flag )>

Returns a new Literal structure.

=cut

sub new {
	my $class	= shift;
	my $literal	= shift;
	my $lang	= shift;
	my $dt		= shift;
	my $canon	= shift;
	
	if ($dt and $canon) {
		$literal	= $class->canonicalize_literal_value( $literal, $dt );
	}
	
	if ($USE_XMLLITERALS and defined($dt) and $dt eq 'http://www.w3.org/1999/02/22-rdf-syntax-ns#XMLLiteral') {
		return RDF::Trine::Node::Literal::XML->new( $literal, $lang, $dt );
	} elsif ($USE_FORMULAE and defined($dt) and $dt eq RDF::Trine::Node::Formula->literal_datatype) {
		return RDF::Trine::Node::Formula->new( $literal );
	} else {
		return $class->_new( $literal, $lang, $dt );
	}
}

sub _new {
	my $class	= shift;
	my $literal	= shift;
	my $lang	= shift;
	my $dt		= shift;
	my $self;

	if ($lang and $dt) {
		throw RDF::Trine::Error::MethodInvocationError ( -text => "Literal values cannot have both language and datatype" );
	}
	
	if ($lang) {
		$self	= [ $literal, lc($lang), undef ];
	} elsif ($dt) {
		if (blessed($dt)) {
			$dt	= $dt->uri_value;
		}
		$self	= [ $literal, undef, $dt ];
	} else {
		$self	= [ $literal ];
	}
	return bless($self, $class);
}

=item C<< literal_value >>

Returns the string value of the literal.

=cut

sub literal_value {
	my $self	= shift;
	if (@_) {
		$self->[0]	= shift;
	}
	return $self->[0];
}

=item C<< literal_value_language >>

Returns the language tag of the ltieral.

=cut

sub literal_value_language {
	my $self	= shift;
	return $self->[1];
}

=item C<< literal_datatype >>

Returns the datatype of the literal.

=cut

sub literal_datatype {
	my $self	= shift;
	return $self->[2];
}

=item C<< sse >>

Returns the SSE string for this literal.

=cut

sub sse {
	my $self	= shift;
	my $literal	= $self->literal_value;
	my $escaped	= $self->_unicode_escape( $literal );
	$literal	= $escaped;
	if (defined(my $lang = $self->literal_value_language)) {
		return qq("${literal}"\@${lang});
	} elsif (defined(my $dt = $self->literal_datatype)) {
		return qq("${literal}"^^<${dt}>);
	} else {
		return qq("${literal}");
	}
}

=item C<< as_string >>

Returns a string representation of the node.

=cut

sub as_string {
	my $self	= shift;
	my $string	= '"' . $self->literal_value . '"';
	if (defined(my $dt = $self->literal_datatype)) {
		$string	.= '^^<' . $dt . '>';
	} elsif (defined(my $lang = $self->literal_value_language)) {
		$string	.= '@' . $lang;
	}
	return $string;
}

=item C<< as_ntriples >>

Returns the node in a string form suitable for NTriples serialization.

=cut

sub as_ntriples {
	my $self	= shift;
	my $literal	= $self->literal_value;
	my $escaped	= $self->_unicode_escape( $literal );
	$literal	= $escaped;
	if (defined(my $lang = $self->literal_value_language)) {
		return qq("${literal}"\@${lang});
	} elsif (defined(my $dt = $self->literal_datatype)) {
		return qq("${literal}"^^<${dt}>);
	} else {
		return qq("${literal}");
	}
}

=item C<< type >>

Returns the type string of this node.

=cut

sub type {
	return 'LITERAL';
}

=item C<< has_language >>

Returns true if this literal is language-tagged, false otherwise.

=cut

sub has_language {
	my $self	= shift;
	return defined($self->literal_value_language) ? 1 : 0;
}

=item C<< has_datatype >>

Returns true if this literal is datatyped, false otherwise.

=cut

sub has_datatype {
	my $self	= shift;
	return defined($self->literal_datatype) ? 1 : 0;
}

=item C<< equal ( $node ) >>

Returns true if the two nodes are equal, false otherwise.

=cut

sub equal {
	my $self	= shift;
	my $node	= shift;
	return 0 unless (blessed($node) and $node->isa('RDF::Trine::Node::Literal'));
	return 0 unless ($self->literal_value eq $node->literal_value);
	if ($self->literal_datatype or $node->literal_datatype) {
		no warnings 'uninitialized';
		return 0 unless ($self->literal_datatype eq $node->literal_datatype);
	}
	if ($self->literal_value_language or $node->literal_value_language) {
		no warnings 'uninitialized';
		return 0 unless ($self->literal_value_language eq $node->literal_value_language);
	}
	return 1;
}

# called to compare two nodes of the same type
sub _compare {
	my $a	= shift;
	my $b	= shift;
	if ($a->literal_value ne $b->literal_value) {
		return ($a->literal_value cmp $b->literal_value);
	}
	
	# the nodes have the same lexical value
	if ($a->has_language and $b->has_language) {
		return ($a->literal_value_language cmp $b->literal_value_language);
	}
	
	if ($a->has_datatype and $b->has_datatype) {
		return ($a->literal_datatype cmp $b->literal_datatype);
	} elsif ($a->has_datatype) {
		return 1;
	} elsif ($b->has_datatype) {
		return -1;
	}
	
	return 0;
}

=item C<< canonicalize_literal_value ( $string, $datatype, $warn ) >>

If C<< $datatype >> is a recognized datatype, returns the canonical lexical
representation of the value C<< $string >>. Otherwise returns C<< $string >>.

Currently, xsd:integer, xsd:decimal, and xsd:boolean are canonicalized.
Additionaly, invalid lexical forms for xsd:float, xsd:double, and xsd:dateTime
will trigger a warning.

=cut

sub canonicalize_literal_value {
	my $self	= shift;
	my $value	= shift;
	my $dt		= shift;
	my $warn	= shift;
	
	if ($dt eq 'http://www.w3.org/2001/XMLSchema#integer') {
		if ($value =~ m/^([-+])?(\d+)$/) {
			my $sign	= $1 || '';
			my $num		= $2;
			$sign		= '' if ($sign eq '+');
			$num		=~ s/^0+(.)/$1/;
			return "${sign}${num}";
		} else {
			warn "Bad lexical form for xsd:integer: '$value'" if ($warn);
		}
	} elsif ($dt eq 'http://www.w3.org/2001/XMLSchema#decimal') {
		if ($value =~ m/^([-+])?((\d+)([.]\d*)?)$/) {
			my $sign	= $1 || '';
			my $num		= $2;
			my $int		= $3;
			my $frac	= $4;
			$sign		= '' if ($sign eq '+');
			unless ($frac =~ m/[1-9]/) {
				$num	= $int;
			}
			$num		=~ s/^0+(.)/$1/;
			return "${sign}${num}";
		} elsif ($value =~ m/^([-+])?([.]\d+)$/) {
			my $sign	= $1 || '';
			my $num		= $2;
			$sign		= '' if ($sign eq '+');
			$num		=~ s/^0+(.)/$1/;
			return "${sign}${num}";
		} else {
			warn "Bad lexical form for xsd:deciaml: '$value'" if ($warn);
			$value		= sprintf('%f', $value);
		}
	} elsif ($dt eq 'http://www.w3.org/2001/XMLSchema#float') {
		if ($value =~ m/^[-+]?(\d+(\.\d*)?|\.\d+)([Ee][-+]?\d+)?|[-+]?INF|NaN$/) {
			return $value;
		} else {
			warn "Bad lexical form for xsd:float: '$value'" if ($warn);
			$value	= sprintf('%E', $value);
			$value	=~ s/E[+]/E/;
			$value	=~ s/E0+(\d)/E$1/;
			$value	=~ s/(\d)0+E/$1E/;
		}
	} elsif ($dt eq 'http://www.w3.org/2001/XMLSchema#double') {
		if ($value =~ m/^[-+]?(\d+(\.\d*)?|\.\d+)([Ee][-+]?\d+)? |[-+]?INF|NaN$/) {
			return $value;
		} else {
			warn "Bad lexical form for xsd:double: '$value'" if ($warn);
			$value	= sprintf('%E', $value);
			$value	=~ s/E[+]/E/;
			$value	=~ s/E0+(\d)/E$1/;
			$value	=~ s/(\d)0+E/$1E/;
		}
	} elsif ($dt eq 'http://www.w3.org/2001/XMLSchema#boolean') {
		if ($value =~ m/^(true|false|0|1)$/) {
			$value	= 'true' if ($value eq '1');
			$value	= 'false' if ($value eq '0');
			return $value;
		} else {
			warn "Bad lexical form for xsd:boolean: '$value'" if ($warn);
		}
	} elsif ($dt eq 'http://www.w3.org/2001/XMLSchema#dateTime') {
		if ($value =~ m/^-?([1-9]\d{3,}|0\d{3})-(0[1-9]|1[0-2])-(0[1-9]|[12]\d|3[01])T(([01]\d|2[0-3]):[0-5]\d:[0-5]\d(\.\d+)?|(24:00:00(\.0+)?))(Z|(\+|-)((0\d|1[0-3]):[0-5]\d|14:00))?$/) {
			# XXX need to canonicalize the dateTime
			return $value;
		} else {
			warn "Bad lexical form for xsd:boolean: '$value'" if ($warn);
		}
	}
	return $value;
}

1;

__END__

=back

=head1 AUTHOR

Gregory Todd Williams  C<< <gwilliams@cpan.org> >>

=head1 COPYRIGHT

Copyright (c) 2006-2010 Gregory Todd Williams. All rights reserved. This
program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
