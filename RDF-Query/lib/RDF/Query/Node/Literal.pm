# RDF::Query::Node::Literal
# -------------
# $Revision: 121 $
# $Date: 2006-02-06 23:07:43 -0500 (Mon, 06 Feb 2006) $
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Node::Literal - RDF Node class for literals

=cut

package RDF::Query::Node::Literal;

use strict;
use warnings;
no warnings 'redefine';
use base qw(RDF::Query::Node RDF::Trine::Node::Literal);

use DateTime;
use RDF::Query;
use RDF::Query::Error;
use Data::Dumper;
use Scalar::Util qw(blessed refaddr looks_like_number);
use Carp qw(carp croak confess);

######################################################################

our ($VERSION, $debug, $LAZY_COMPARISONS);
BEGIN {
	$debug		= 0;
	$VERSION	= '2.000';
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

=over 4

=cut

sub _cmp {
	my $nodea	= shift;
	my $nodeb	= shift;
	my $op	= shift;
	
	warn '-------------------------------' if ($debug);
	warn 'literal comparison: ' . Dumper($nodea, $nodeb) if ($debug);
	
	return 1 unless blessed($nodeb);
	return 1 if ($nodeb->isa('RDF::Query::Node::Blank'));
	return 1 if ($nodeb->isa('RDF::Query::Node::Resource'));
	return 1 unless ($nodeb->isa('RDF::Query::Node::Literal'));
	
	my $dta			= $nodea->literal_datatype || '';
	my $dtb			= $nodeb->literal_datatype || '';
	my $datetype	= '^http://www.w3.org/2001/XMLSchema#dateTime';
	my $datecmp		= ($dta =~ $datetype and $dtb =~ $datetype);
	my $numericcmp	= ($nodea->is_numeric_type and $nodeb->is_numeric_type);

	if ($datecmp) {
		warn 'datecmp' if ($debug);
		my $datea	= $nodea->datetime;
		my $dateb	= $nodeb->datetime;
		return DateTime->compare( $datea, $dateb );
	} elsif ($numericcmp) {
		warn 'both numeric cmp' if ($debug);
		return $nodea->numeric_value <=> $nodeb->numeric_value;
	} else {
		warn 'other cmp' if ($debug);
		
		if ($nodea->has_language and $nodeb->has_language) {
			warn "both have language" if ($debug);
			my $lc	= lc($nodea->literal_value_language) cmp lc($nodeb->literal_value_language);
			my $vc	= $nodea->literal_value cmp $nodeb->literal_value;
			my $c;
			if ($LAZY_COMPARISONS and ($lc != 0)) {
				$c	= ($vc || $lc);
			} elsif ($lc == 0) {
				$c	= $vc;
			} else {
				warn "Attempt to compare literals with differing languages." if ($debug);
				throw RDF::Query::Error::TypeError -text => "Attempt to compare literals with differing languages.";
			}
			warn "-> $c" if ($debug);
			return $c;
		} elsif (($nodea->has_datatype and $dta eq 'http://www.w3.org/2001/XMLSchema#string') or ($nodeb->has_datatype and $dtb eq 'http://www.w3.org/2001/XMLSchema#string')) {
			warn "one is xsd:string" if ($debug);
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
			} else {
				throw RDF::Query::Error::TypeError -text => "Attempt to compare typed-literal with xsd:string.";
			}
			warn "-> $c" if ($debug);
			return $c;
		} elsif ($nodea->has_datatype and $nodeb->has_datatype) {
			warn "both have datatype" if ($debug);
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
					warn "Attempt to compare literals with different datatypes." if ($debug);
					throw RDF::Query::Error::TypeError -text => "Attempt to compare literals with differing datatypes.";
				}
				warn "-> $c" if ($debug);
				return $c;
			}
		} elsif ($nodea->has_language or $nodeb->has_language) {
			warn "one has language" if ($debug);
			if ($LAZY_COMPARISONS) {
				my $c	= refaddr($nodea) <=> refaddr($nodeb);	# not equal, but will make the sort stable
				warn "-> $c" if ($debug);
				return $c;
			} else {
				my $c	= refaddr($nodea) <=> refaddr($nodeb);	# not equal, but stable sorting
				warn "-> $c" if ($debug);
				return $c;
			}
		} elsif ($nodea->has_datatype or $nodeb->has_datatype) {
			warn "one has datatype" if ($debug);
			if ($LAZY_COMPARISONS) {
				my $c	= refaddr($nodea) <=> refaddr($nodeb);	# not equal, but will make the sort stable
				warn "-> $c" if ($debug);
				return $c;
			} else {
				warn "Attempt to compare typed-literal with plain-literal" if ($debug);
				throw RDF::Query::Error::TypeError -text => "Attempt to compare typed-literal with plain-literal";
			}
		} else {
			warn "something else" if ($debug);
			my $vcmp	= $nodea->literal_value cmp $nodeb->literal_value;
			warn "-> $vcmp" if ($debug);
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
			return 0 + $value;
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
