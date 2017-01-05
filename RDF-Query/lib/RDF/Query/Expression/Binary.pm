# RDF::Query::Expression::Binary
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Expression::Binary - Algebra class for binary expressions

=head1 VERSION

This document describes RDF::Query::Expression::Binary version 2.918.

=cut

package RDF::Query::Expression::Binary;

use strict;
use warnings;
no warnings 'redefine';
use base qw(RDF::Query::Expression);

use Data::Dumper;
use Log::Log4perl;
use Scalar::Util qw(blessed);
use Carp qw(carp croak confess);

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= '2.918';
}

######################################################################

=head1 METHODS

Beyond the methods documented below, this class inherits methods from the
L<RDF::Query::Expression> class.

=over 4

=cut

=item C<< sse >>

Returns the SSE string for this algebra expression.

=cut

sub sse {
	my $self	= shift;
	my $context	= shift;
	
	return sprintf(
		'(%s %s %s)',
		$self->op,
		map { $_->sse( $context ) } $self->operands,
	);
}

=item C<< as_sparql >>

Returns the SPARQL string for this algebra expression.

=cut

sub as_sparql {
	my $self	= shift;
	my $context	= shift;
	my $indent	= shift;
	my $op		= $self->op;
 	$op			= '=' if ($op eq '==');
	return sprintf("(%s $op %s)", map { $_->as_sparql( $context, $indent ) } $self->operands);
}

=item C<< evaluate ( $query, \%bound ) >>

Evaluates the expression using the supplied bound variables.
Will return a RDF::Query::Node object.

=cut

sub evaluate {
	my $self	= shift;
	my $query	= shift;
	my $bound	= shift;
	my $l		= Log::Log4perl->get_logger("rdf.query.expression.binary");
	my $op		= $self->op;
	my @operands	= $self->operands;
	my ($lhs, $rhs)	= map {
						throw RDF::Query::Error::ExecutionError ( -text => "error in evaluating operands to binary $op" )
							unless (blessed($_));
						$_->isa('RDF::Query::Algebra')
							? $_->evaluate( $query, $bound, @_ )
							: ($_->isa('RDF::Trine::Node::Variable'))
								? $bound->{ $_->name }
								: $_
	} @operands;
	
	$l->debug("Binary Operator '$op': " . Dumper($lhs, $rhs));
	
### This does overloading of infix<+> on literal values to perform string concatenation
# 	if ($op eq '+') {
# 		if (blessed($lhs) and $lhs->isa('RDF::Query::Node::Literal') and blessed($rhs) and $rhs->isa('RDF::Query::Node::Literal')) {
# 			if (not($lhs->has_datatype) and not($rhs->has_datatype)) {
# 				my $value	= $lhs->literal_value . $rhs->literal_value;
# 				return RDF::Query::Node::Literal->new( $value );
# 			}
# 		}
# 	}
	
	if ($op =~ m#^[-+/*]$#) {
		if (blessed($lhs) and blessed($rhs) and $lhs->isa('RDF::Query::Node::Literal') and $rhs->isa('RDF::Query::Node::Literal') and $lhs->is_numeric_type and $rhs->is_numeric_type) {
			my $type	= $self->promote_type( $op, $lhs->literal_datatype, $rhs->literal_datatype );
			my $value;
			if ($op eq '+') {
				my $lhsv	= $lhs->numeric_value;
				my $rhsv	= $rhs->numeric_value;
				if (defined($lhsv) and defined($rhsv)) {
					$value		= $lhsv + $rhsv;
				} else {
					throw RDF::Query::Error::ComparisonError -text => "Cannot evaluate infix:<+> on non-numeric types";
				}
			} elsif ($op eq '-') {
				my $lhsv	= $lhs->numeric_value;
				my $rhsv	= $rhs->numeric_value;
				if (defined($lhsv) and defined($rhsv)) {
					$value		= $lhsv - $rhsv;
				} else {
					throw RDF::Query::Error::ComparisonError -text => "Cannot evaluate infix:<-> on non-numeric types";
				}
			} elsif ($op eq '*') {
				my $lhsv	= $lhs->numeric_value;
				my $rhsv	= $rhs->numeric_value;
				if (defined($lhsv) and defined($rhsv)) {
					$value		= $lhsv * $rhsv;
				} else {
					throw RDF::Query::Error::ComparisonError -text => "Cannot evaluate infix:<*> on non-numeric types";
				}
			} elsif ($op eq '/') {
				my $lhsv	= $lhs->numeric_value;
				my $rhsv	= $rhs->numeric_value;
				
				my ($lt, $rt)	= ($lhs->literal_datatype, $rhs->literal_datatype);
				if ($lt eq $rt and $lt eq 'http://www.w3.org/2001/XMLSchema#integer') {
					$type	= 'http://www.w3.org/2001/XMLSchema#decimal';
				}
				
				if (defined($lhsv) and defined($rhsv)) {
					if ($rhsv == 0) {
						throw RDF::Query::Error::FilterEvaluationError -text => "Illegal division by zero";
					}
					$value		= $lhsv / $rhsv;
				} else {
					throw RDF::Query::Error::ComparisonError -text => "Cannot evaluate infix:</> on non-numeric types";
				}
			} else {
				throw RDF::Query::Error::ExecutionError -text => "Unrecognized binary operator '$op'";
			}
			return RDF::Query::Node::Literal->new( $value, undef, $type, 1 );
		} else {
			throw RDF::Query::Error::ExecutionError -text => "Numeric binary operator '$op' with non-numeric data";
		}
	} elsif ($op =~ m#^([<>]=?)|!?=$#) {
		my @types	= qw(RDF::Query::Node::Literal RDF::Query::Node::Resource RDF::Query::Node::Blank);
		
		if ($op =~ /[<>]/) {
			# if it's a relational operation other than equality testing,
			# the two nodes must be of the same type.
			my $ok		= 0;
			foreach my $type (@types) {
				$ok	||= 1 if ($lhs->isa($type) and $rhs->isa($type));
			}
			if (not($ok) and not($RDF::Query::Node::Literal::LAZY_COMPARISONS)) {
				throw RDF::Query::Error::TypeError -text => "Attempt to compare two nodes of different types.";
			}
		}
		
		my $bool;
		if ($op eq '<') {
			$bool	= ($lhs < $rhs);
		} elsif ($op eq '<=') {
			$bool	= ($lhs <= $rhs);
		} elsif ($op eq '>') {
			$bool	= ($lhs > $rhs);
		} elsif ($op eq '>=') {
			$bool	= ($lhs >= $rhs);
		} elsif ($op eq '==') {
			$bool	= ($lhs == $rhs);
		} elsif ($op eq '!=') {
			$bool	= ($lhs != $rhs);
		} else {
			throw RDF::Query::Error::ExecutionError -text => "Unrecognized binary operator '$op'";
		}
		
		my $value	= ($bool) ? 'true' : 'false';
		$l->debug("-> $value");
		return RDF::Query::Node::Literal->new( $value, undef, 'http://www.w3.org/2001/XMLSchema#boolean' );
	} else {
		$l->logdie("Unknown operator: $op");
	}
}

my $xsd				= 'http://www.w3.org/2001/XMLSchema#';
my %integer_types	= map { join('', $xsd, $_) => 1 } qw(nonPositiveInteger nonNegativeInteger positiveInteger negativeInteger short unsignedShort byte unsignedByte long unsignedLong);
my %rel	= (
	"${xsd}integer"				=> 0,
	"${xsd}int"					=> 1,
	"${xsd}unsignedInt"			=> 2,
	"${xsd}nonPositiveInteger"	=> 3,
	"${xsd}nonNegativeInteger"	=> 4,
	"${xsd}positiveInteger"		=> 5,
	"${xsd}negativeInteger"		=> 6,
	"${xsd}short"				=> 7,
	"${xsd}unsignedShort"		=> 8,
	"${xsd}byte"				=> 9,
	"${xsd}unsignedByte"		=> 10,
	"${xsd}long"				=> 11,
	"${xsd}unsignedLong"		=> 12,
	"${xsd}decimal"				=> 13,
	"${xsd}float"				=> 14,
	"${xsd}double"				=> 15,
);

=item C<< promote_type ( $op, $lhs_datatype, $rhs_datatype ) >>

Returns the XSD type URI (as a string) for the resulting value of performing the
supplied operation on arguments of the indicated XSD types.

=cut

sub promote_type {
	my $self	= shift;
	my $op		= shift;
	no warnings 'uninitialized';
	my @types	= sort { $rel{$b} <=> $rel{$a} } @_;
	
	my $type	= $types[0];
	$type		= "${xsd}integer" if ($integer_types{ $type });
	return $type;
}

1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
