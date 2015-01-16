# RDF::Trine::Node::Literal
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Node::Literal - RDF Node class for literals

=head1 VERSION

This document describes RDF::Trine::Node::Literal version 1.012

=cut

package RDF::Trine::Node::Literal;

use strict;
use warnings;
no warnings 'redefine';
use base qw(RDF::Trine::Node);

use RDF::Trine::Error;
use Data::Dumper;
use Scalar::Util qw(blessed looks_like_number);
use Carp qw(carp croak confess);

######################################################################

our ($VERSION, $USE_XMLLITERALS, $USE_FORMULAE);
BEGIN {
	$VERSION	= '1.012';
	eval "use RDF::Trine::Node::Literal::XML;";	## no critic (ProhibitStringyEval)
	$USE_XMLLITERALS	= (RDF::Trine::Node::Literal::XML->can('new')) ? 1 : 0;
	eval "use RDF::Trine::Node::Formula;";	## no critic (ProhibitStringyEval)
	$USE_FORMULAE = (RDF::Trine::Node::Formula->can('new')) ? 1 : 0;
}

######################################################################

use overload	'""'	=> sub { $_[0]->sse },
			;

=head1 METHODS

Beyond the methods documented below, this class inherits methods from the
L<RDF::Trine::Node> class.

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
	
	unless (defined($literal)) {
		throw RDF::Trine::Error::MethodInvocationError -text => "Literal constructor called with an undefined value";
	}
	
	if (blessed($dt) and $dt->isa('RDF::Trine::Node::Resource')) {
		$dt	= $dt->uri_value;
	}
	
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
		my $oldlang	= $lang;
		# http://tools.ietf.org/html/bcp47#section-2.1.1
		# All subtags use lowercase letters
		$lang	= lc($lang);

		# with 2 exceptions: subtags that neither appear at the start of the tag nor occur after singletons
		# i.e. there's a subtag of length at least 2 preceding the exception; and a following subtag or end-of-tag

		# 1. two-letter subtags are all uppercase
		$lang	=~ s{(?<=\w\w-)(\w\w)(?=($|-))}{\U$1}g;

		# 2. four-letter subtags are titlecase
		$lang	=~ s{(?<=\w\w-)(\w\w\w\w)(?=($|-))}{\u\L$1}g;
		$self	= [ $literal, $lang, undef ];
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

=item C<< value >>

Returns the literal value.

=cut

sub value {
	my $self	= shift;
	return $self->literal_value;
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

=item C<< canonicalize >>

Returns a new literal node object whose value is in canonical form (where applicable).

=cut

sub canonicalize {
	my $self	= shift;
	my $class	= ref($self);
	my $dt		= $self->literal_datatype;
	my $lang	= $self->literal_value_language;
	my $value	= $self->value;
	if (defined $dt) {
		$value	= RDF::Trine::Node::Literal->canonicalize_literal_value( $value, $dt, 1 );
	}
	return $class->new($value, $lang, $dt);
}

=item C<< canonicalize_literal_value ( $string, $datatype, $warn ) >>

If C<< $datatype >> is a recognized datatype, returns the canonical lexical
representation of the value C<< $string >>. Otherwise returns C<< $string >>.

Currently, xsd:integer, xsd:decimal, and xsd:boolean are canonicalized.
Additionally, invalid lexical forms for xsd:float, xsd:double, and xsd:dateTime
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
			$num		=~ s/^0+(\d)/$1/;
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
			$num		=~ s/^0+(.)/$1/;
			$num		=~ s/[.](\d)0+$/.$1/;
			if ($num =~ /^[.]/) {
				$num	= "0$num";
			}
			if ($num !~ /[.]/) {
				$num	= "${num}.0";
			}
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
		if ($value =~ m/^(?:([-+])?(?:(\d+(?:\.\d*)?|\.\d+)([Ee][-+]?\d+)?|(INF)))|(NaN)$/) {
			my $sign	= $1;
			my $inf		= $4;
			my $nan		= $5;
			no warnings 'uninitialized';
			$sign		= '' if ($sign eq '+');
			return "${sign}$inf" if ($inf);
			return $nan if ($nan);

			$value		= sprintf('%E', $value);
			$value 		=~ m/^(?:([-+])?(?:(\d+(?:\.\d*)?|\.\d+)([Ee][-+]?\d+)?|(INF)))|(NaN)$/;
			$sign		= $1;
			$inf		= $4;
			$nan		= $5;
			my $num		= $2;
			my $exp		= $3;
			$num		=~ s/[.](\d+?)0+/.$1/;
			$exp	=~ tr/e/E/;
			$exp	=~ s/E[+]/E/;
			$exp	=~ s/E(-?)0+([1-9])$/E$1$2/;
			$exp	=~ s/E(-?)0+$/E${1}0/;
			return "${sign}${num}${exp}";
		} else {
			warn "Bad lexical form for xsd:float: '$value'" if ($warn);
			$value	= sprintf('%E', $value);
			$value	=~ s/E[+]/E/;
			$value	=~ s/E0+(\d)/E$1/;
			$value	=~ s/(\d)0+E/$1E/;
		}
	} elsif ($dt eq 'http://www.w3.org/2001/XMLSchema#double') {
		if ($value =~ m/^(?:([-+])?(?:(\d+(?:\.\d*)?|\.\d+)([Ee][-+]?\d+)?|(INF)))|(NaN)$/) {
			my $sign	= $1;
			my $inf		= $4;
			my $nan		= $5;
			no warnings 'uninitialized';
			$sign		= '' if ($sign eq '+');
			return "${sign}$inf" if ($inf);
			return $nan if ($nan);

			$value		= sprintf('%E', $value);
			$value 		=~ m/^(?:([-+])?(?:(\d+(?:\.\d*)?|\.\d+)([Ee][-+]?\d+)?|(INF)))|(NaN)$/;
			$sign		= $1;
			$inf		= $4;
			$nan		= $5;
			my $num		= $2;
			my $exp		= $3;
			$num		=~ s/[.](\d+?)0+/.$1/;
			$exp	=~ tr/e/E/;
			$exp	=~ s/E[+]/E/;
			$exp	=~ s/E(-?)0+([1-9])$/E$1$2/;
			$exp	=~ s/E(-?)0+$/E${1}0/;
			return "${sign}${num}${exp}";
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

=item C<< is_canonical_lexical_form >>

=cut

sub is_canonical_lexical_form {
	my $self	= shift;
	my $value	= $self->literal_value;
	my $dt		= $self->literal_datatype;
	
	unless ($dt =~ qr<^http://www.w3.org/2001/XMLSchema#(integer|decimal|float|double|boolean|dateTime|non(Positive|Negative)Integer|(positive|negative)Integer|long|int|short|byte|unsigned(Long|Int|Short|Byte))>) {
		return '0E0';	# zero but true (it's probably ok, but we don't recognize the datatype)
	}
	
	if ($dt =~ m<http://www.w3.org/2001/XMLSchema#(integer|non(Positive|Negative)Integer|(positive|negative)Integer|long|int|short|byte|unsigned(Long|Int|Short|Byte))>) {
		if ($value =~ m/^([-+])?(\d+)$/) {
			return 1;
		} else {
			return 0;
		}
	} elsif ($dt eq 'http://www.w3.org/2001/XMLSchema#decimal') {
		if ($value =~ m/^([-+])?((\d+)[.]\d+)$/) {
			return 1;
		} elsif ($value =~ m/^([-+])?([.]\d+)$/) {
			return 1;
		} else {
			return 0;
		}
	} elsif ($dt eq 'http://www.w3.org/2001/XMLSchema#float') {
		if ($value =~ m/^[-+]?(\d+\.\d*|\.\d+)([Ee][-+]?\d+)?|[-+]?INF|NaN$/) {
			return 1;
		} elsif ($value =~ m/^[-+]?(\d+(\.\d*)?|\.\d+)([Ee][-+]?\d+)|[-+]?INF|NaN$/) {
			return 1;
		} else {
			return 0;
		}
	} elsif ($dt eq 'http://www.w3.org/2001/XMLSchema#double') {
		if ($value =~ m/^[-+]?((\d+(\.\d*))|(\.\d+))([Ee][-+]?\d+)?|[-+]?INF|NaN$/) {
			return 1;
		} elsif ($value =~ m/^[-+]?((\d+(\.\d*)?)|(\.\d+))([Ee][-+]?\d+)|[-+]?INF|NaN$/) {
			return 1;
		} else {
			return 0;
		}
	} elsif ($dt eq 'http://www.w3.org/2001/XMLSchema#boolean') {
		if ($value =~ m/^(true|false)$/) {
			return 1;
		} else {
			return 0;
		}
	} elsif ($dt eq 'http://www.w3.org/2001/XMLSchema#dateTime') {
		if ($value =~ m/^-?([1-9]\d{3,}|0\d{3})-(0[1-9]|1[0-2])-(0[1-9]|[12]\d|3[01])T(([01]\d|2[0-3]):[0-5]\d:[0-5]\d(\.\d+)?|(24:00:00(\.0+)?))(Z|(\+|-)((0\d|1[0-3]):[0-5]\d|14:00))?$/) {
			return 1;
		} else {
			return 0;
		}
	}
	return 0;
}

=item C<< is_valid_lexical_form >>

Returns true if the node is of a recognized datatype and has a valid lexical form
for that datatype. If the lexical form is invalid, returns false. If the datatype
is unrecognized, returns zero-but-true.

=cut

sub is_valid_lexical_form {
	my $self	= shift;
	my $value	= $self->literal_value;
	my $dt		= $self->literal_datatype;
	
	unless ($dt =~ qr<^http://www.w3.org/2001/XMLSchema#(integer|decimal|float|double|boolean|dateTime|non(Positive|Negative)Integer|(positive|negative)Integer|long|int|short|byte|unsigned(Long|Int|Short|Byte))>) {
		return '0E0';	# zero but true (it's probably ok, but we don't recognize the datatype)
	}
	
	if ($dt =~ m<http://www.w3.org/2001/XMLSchema#(integer|non(Positive|Negative)Integer|(positive|negative)Integer|long|int|short|byte|unsigned(Long|Int|Short|Byte))>) {
		if ($value =~ m/^([-+])?(\d+)$/) {
			return 1;
		} else {
			return 0;
		}
	} elsif ($dt eq 'http://www.w3.org/2001/XMLSchema#decimal') {
		if ($value =~ m/^([-+])?((\d+)([.]\d*)?)$/) {
			return 1;
		} elsif ($value =~ m/^([-+])?([.]\d+)$/) {
			return 1;
		} else {
			return 0;
		}
	} elsif ($dt eq 'http://www.w3.org/2001/XMLSchema#float') {
		if ($value =~ m/^[-+]?(\d+(\.\d*)?|\.\d+)([Ee][-+]?\d+)?|[-+]?INF|NaN$/) {
			return 1;
		} else {
			return 0;
		}
	} elsif ($dt eq 'http://www.w3.org/2001/XMLSchema#double') {
		if ($value =~ m/^[-+]?((\d+(\.\d*)?)|(\.\d+))([Ee][-+]?\d+)?|[-+]?INF|NaN$/) {
			return 1;
		} else {
			return 0;
		}
	} elsif ($dt eq 'http://www.w3.org/2001/XMLSchema#boolean') {
		if ($value =~ m/^(true|false|0|1)$/) {
			return 1;
		} else {
			return 0;
		}
	} elsif ($dt eq 'http://www.w3.org/2001/XMLSchema#dateTime') {
		if ($value =~ m/^-?([1-9]\d{3,}|0\d{3})-(0[1-9]|1[0-2])-(0[1-9]|[12]\d|3[01])T(([01]\d|2[0-3]):[0-5]\d:[0-5]\d(\.\d+)?|(24:00:00(\.0+)?))(Z|(\+|-)((0\d|1[0-3]):[0-5]\d|14:00))?$/) {
			return 1;
		} else {
			return 0;
		}
	}
	return 0;
}

=item C<< is_numeric_type >>

Returns true if the literal is a known (xsd) numeric type.

=cut

sub is_numeric_type {
	my $self	= shift;
	return 0 unless ($self->has_datatype);
	my $type	= $self->literal_datatype;
	if ($type =~ qr<^http://www.w3.org/2001/XMLSchema#(integer|decimal|float|double|non(Positive|Negative)Integer|(positive|negative)Integer|long|int|short|byte|unsigned(Long|Int|Short|Byte))>) {
		return 1;
	} else {
		return 0;
	}
}

=item C<< numeric_value >>

Returns the numeric value of the literal (even if the literal isn't a known numeric type.

=cut

sub numeric_value {
	my $self	= shift;
	if ($self->is_numeric_type) {
		my $value	= $self->literal_value;
		if (looks_like_number($value)) {
			my $v	= 0 + eval "$value";	## no critic (ProhibitStringyEval)
			return $v;
		} else {
			throw RDF::Query::Error::TypeError -text => "Literal with numeric type does not appear to have numeric value.";
		}
	} elsif (not $self->has_datatype) {
		if (looks_like_number($self->literal_value)) {
			return 0+$self->literal_value;
		} else {
			return;
		}
	} elsif ($self->literal_datatype eq 'http://www.w3.org/2001/XMLSchema#boolean') {
		return ($self->literal_value eq 'true') ? 1 : 0;
	} else {
		return;
	}
}

1;

__END__

=back

=head1 BUGS

Please report any bugs or feature requests to through the GitHub web interface
at L<https://github.com/kasei/perlrdf/issues>.

=head1 AUTHOR

Gregory Todd Williams  C<< <gwilliams@cpan.org> >>

=head1 COPYRIGHT

Copyright (c) 2006-2012 Gregory Todd Williams. This
program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
