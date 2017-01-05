# RDF::Query::Node::Literal
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Node::Literal - RDF Node class for literals

=head1 VERSION

This document describes RDF::Query::Node::Literal version 2.918.

=cut

package RDF::Query::Node::Literal;

use strict;
use warnings;
no warnings 'redefine';
use base qw(RDF::Query::Node RDF::Trine::Node::Literal);

use DateTime;
use DateTime::Format::W3CDTF;
use RDF::Query::Error;
use Data::Dumper;
use Log::Log4perl;
use Scalar::Util qw(blessed refaddr looks_like_number);
use Carp qw(carp croak confess);

######################################################################

our ($VERSION, $LAZY_COMPARISONS);
BEGIN {
	$VERSION	= '2.918';
}

######################################################################

use overload	'<=>'	=> \&_cmp,
				'cmp'	=> \&_cmp,
				'<'		=> sub { _cmp(@_[0,1], '<') == -1 },
				'>'		=> sub { _cmp(@_[0,1], '>') == 1 },
				'!='	=> sub { _cmp(@_[0,1], '!=') != 0 },
				'=='	=> sub { _cmp(@_[0,1], '==') == 0 },
				'+'		=> sub { $_[0] },
				'""'	=> sub { $_[0]->sse },
			;

my %INSIDE_OUT_DATES;

=head1 METHODS

Beyond the methods documented below, this class inherits methods from the
L<RDF::Query::Node> and L<RDF::Trine::Node::Literal> classes.

=over 4

=cut

sub _cmp {
	my $nodea	= shift;
	my $nodeb	= shift;
	my $op		= shift;
	
	my $l		= Log::Log4perl->get_logger("rdf.query.node.literal");
	$l->debug('literal comparison: ' . Dumper($nodea, $nodeb));
	
	return 1 unless blessed($nodeb);
	return -1 if ($nodeb->isa('RDF::Trine::Node::Nil'));
	return 1 if ($nodeb->isa('RDF::Query::Node::Blank'));
	return 1 if ($nodeb->isa('RDF::Query::Node::Resource'));
	return 1 unless ($nodeb->isa('RDF::Query::Node::Literal'));
	
	my $dta			= $nodea->literal_datatype || '';
	my $dtb			= $nodeb->literal_datatype || '';
	my $datetype	= '^http://www.w3.org/2001/XMLSchema#dateTime';
	my $datecmp		= ($dta =~ $datetype and $dtb =~ $datetype);
	my $numericcmp	= ($nodea->is_numeric_type and $nodeb->is_numeric_type);
	
	if ($datecmp) {
		$l->trace('datecmp');
		my $datea	= $nodea->datetime;
		my $dateb	= $nodeb->datetime;
		if ($datea and $dateb) {
			my $cmp		= eval { DateTime->compare_ignore_floating( $datea, $dateb ) };
			return $cmp unless ($@);
		}
	}
	
	if ($numericcmp) {
		$l->trace('both numeric cmp');
		return 0 if ($nodea->equal( $nodeb ));	# if the nodes are identical, return true (even if the lexical values don't appear to be numeric). i.e., "xyz"^^xsd:integer should equal itself, even though it's not a valid integer.
		return $nodea->numeric_value <=> $nodeb->numeric_value;
	}
	
	{
		$l->trace('other cmp');
		
		if ($nodea->has_language and $nodeb->has_language) {
			$l->trace('both have language');
			my $lc	= lc($nodea->literal_value_language) cmp lc($nodeb->literal_value_language);
			my $vc	= $nodea->literal_value cmp $nodeb->literal_value;
			my $c;
			if ($LAZY_COMPARISONS and ($lc != 0)) {
				$c	= ($vc || $lc);
			} elsif ($lc == 0) {
				$c	= $vc;
			} else {
				$l->debug("Attempt to compare literals with differing languages.");
				throw RDF::Query::Error::TypeError -text => "Attempt to compare literals with differing languages.";
			}
			$l->trace("-> $c");
			return $c;
		} elsif (($nodea->has_datatype and $dta eq 'http://www.w3.org/2001/XMLSchema#string') or ($nodeb->has_datatype and $dtb eq 'http://www.w3.org/2001/XMLSchema#string')) {
			$l->trace("one is xsd:string");
			no warnings 'uninitialized';
			my ($na, $nb)	= sort {
								(blessed($b) and $b->isa('RDF::Query::Node::Literal'))
									? $b->literal_datatype eq 'http://www.w3.org/2001/XMLSchema#string'
									: ($LAZY_COMPARISONS)
										? refaddr($a) <=> refaddr($b)
										: throw RDF::Query::Error::TypeError -text => "Attempt to compare xsd:string with non-literal";
							} ($nodea, $nodeb);
			
			my $c;
			if ($nb->has_language) {
				$c	= -1;
			} elsif (not($nb->has_datatype) or $nb->literal_datatype eq 'http://www.w3.org/2001/XMLSchema#string') {
				$c	= $nodea->literal_value cmp $nodeb->literal_value;
			} elsif ($LAZY_COMPARISONS) {
				return $nodea->as_string cmp $nodeb->as_string;
			} else {
				throw RDF::Query::Error::TypeError -text => "Attempt to compare typed-literal with xsd:string.";
			}
			$l->trace("-> $c");
			return $c;
		} elsif ($nodea->has_datatype and $nodeb->has_datatype) {
			$l->trace("both have datatype");
			my $dc	= $nodea->literal_datatype cmp $nodeb->literal_datatype;
			my $vc	= $nodea->literal_value cmp $nodeb->literal_value;
			my $c;
			
			if ($op eq '!=') {
				throw RDF::Query::Error::TypeError -text => "Attempt to compare (neq) literals with unrecognized datatypes.";
			} else {
				if ($LAZY_COMPARISONS) {
					$c	= ($vc || $dc);
				} elsif ($dc == 0) {
					$c	= $vc;
				} else {
					$l->debug("Attempt to compare literals with different datatypes.");
					throw RDF::Query::Error::TypeError -text => "Attempt to compare literals with differing datatypes.";
				}
				$l->trace("-> $c");
				return $c;
			}
		} elsif ($nodea->has_language or $nodeb->has_language) {
			$l->trace("one has language");
			my $c	= ($nodea->has_language) ? 1 : -1;
			$l->trace("-> $c");
			return $c;
		} elsif ($nodea->has_datatype or $nodeb->has_datatype) {
			$l->trace("one has datatype");
			if ($LAZY_COMPARISONS) {
				my $c	= ($nodea->has_datatype) ? 1 : -1;
				$l->trace("-> $c");
				return $c;
			} else {
				$l->debug("Attempt to compare typed-literal with plain-literal");
				throw RDF::Query::Error::TypeError -text => "Attempt to compare typed-literal with plain-literal";
			}
		} else {
			$l->trace("something else");
			my $vcmp	= $nodea->literal_value cmp $nodeb->literal_value;
			$l->trace("-> $vcmp");
			return $vcmp;
		}
	}
}

=item C<< datetime >>

Returns a DateTime object from the literal if the literal value is in W3CDTF format.

=cut

sub datetime {
	my $self	= shift;
	my $addr	= refaddr( $self );
	if (exists($INSIDE_OUT_DATES{ $addr })) {
		return $INSIDE_OUT_DATES{ $addr };
	} else {
		my $value	= $self->literal_value;
		my $f		= DateTime::Format::W3CDTF->new;
		my $dt		= eval { $f->parse_datetime( $value ) };
		$INSIDE_OUT_DATES{ $addr }	= $dt;
		return $dt;
	}
}

=item C<< as_sparql >>

Returns the SPARQL string for this node.

=cut

sub as_sparql {
	my $self	= shift;
	if ($self->is_numeric_type) {
		return $self->literal_value;
	} else {
		return $self->sse;
	}
}

=item C<< as_hash >>

Returns the query as a nested set of plain data structures (no objects).

=cut

sub as_hash {
	my $self	= shift;
	my $context	= shift;
	my $hash	= {
		type 		=> 'node',
		literal		=> $self->literal_value,
	};
	$hash->{ language }	= $self->literal_value_language if ($self->has_language);
	$hash->{ datatype }	= $self->literal_datatype if ($self->has_datatype);
	return $hash;
}

=item C<< is_simple_literal >>

Returns true if the literal is "simple" -- is a literal without datatype or language.

=cut

sub is_simple_literal {
	my $self	= shift;
	return not($self->has_language or $self->has_datatype);
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
			my $v	= 0 + eval "$value";
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

=item C<< type_list >>

Returns a two-item list suitable for use as the second and third arguments to
RDF::Query::Node::Literal constructor. The two returned values correspond to
literal language tag and literal datatype URI, respectively.

=cut

sub type_list {
	my $self	= shift;
	return ($self->literal_value_language, $self->literal_datatype);
}

sub DESTROY {
	my $self	= shift;
	my $addr	= refaddr($self);
	delete $INSIDE_OUT_DATES{ $addr };
}


1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
