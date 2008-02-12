# RDF::Query::Algebra
# -------------
# $Revision: 121 $
# $Date: 2006-02-06 23:07:43 -0500 (Mon, 06 Feb 2006) $
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Node - Base class for Algebra expressions

=head1 METHODS

=over 4

=cut

package RDF::Query::Algebra;

BEGIN {
	our $VERSION	= '2.000';
}

use strict;
use warnings;
use Set::Scalar;
use Scalar::Util qw(blessed);
use List::MoreUtils qw(uniq);


use RDF::Query::Algebra::BasicGraphPattern;
use RDF::Query::Algebra::Expr;
use RDF::Query::Algebra::OldFilter;
use RDF::Query::Algebra::Filter;
use RDF::Query::Algebra::GroupGraphPattern;
use RDF::Query::Algebra::Optional;
use RDF::Query::Algebra::Triple;
use RDF::Query::Algebra::Union;
use RDF::Query::Algebra::NamedGraph;
use RDF::Query::Algebra::Service;
use RDF::Query::Algebra::TimeGraph;
use RDF::Query::Algebra::Function;
use RDF::Query::Algebra::Aggregate;

=item C<< referenced_blanks >>

Returns a list of the blank node names used in this algebra expression.

=cut

sub referenced_blanks {
	my $self	= shift;
	my @list;
	foreach my $arg ($self->construct_args) {
		if (blessed($arg) and $arg->isa('RDF::Query::Algebra')) {
			my @blanks	= $arg->referenced_blanks;
			push(@list, @blanks);
		}
	}
	return uniq(@list);
}

=item C<< check_duplicate_blanks >>

Returns true if blank nodes respect the SPARQL rule of no blank-label re-use
across BGPs, otherwise throws a RDF::Query::Error::QueryPatternError exception.

=cut

sub check_duplicate_blanks {
	my $self	= shift;
	my @data;
	foreach my $arg ($self->construct_args) {
		if (blessed($arg) and $arg->isa('RDF::Query::Algebra')) {
			push(@data, $arg->_check_duplicate_blanks);
		}
	}
	
	my %seen;
	foreach my $d (@data) {
		foreach my $b (@$d) {
			if ($seen{ $b }++) {
				throw RDF::Query::Error::QueryPatternError -text => "Same blank node identifier ($b) used in more than one BasicGraphPattern.";
			}
		}
	}
	
	return 1;
}

sub _check_duplicate_blanks {
	my $self	= shift;
	my @data;
	foreach my $arg ($self->construct_args) {
		if (blessed($arg) and $arg->isa('RDF::Query::Algebra')) {
			push( @data, $arg->_check_duplicate_blanks );
		}
	}
	return @data;
}

=item C<< qualify_uris ( \%namespaces, $base ) >>

Returns a new algebra pattern where all referenced Resource nodes representing
QNames (ns:local) are qualified using the supplied %namespaces.

=cut

sub qualify_uris {
	my $self	= shift;
	my $class	= ref($self);
	my $ns		= shift;
	my $base	= shift;
	my @args;
	foreach my $arg ($self->construct_args) {
		if (blessed($arg) and $arg->isa('RDF::Query::Algebra')) {
			push(@args, $arg->qualify_uris( $ns, $base ));
		} else {
			push(@args, $arg);
		}
	}
	return $class->new( @args );
}

1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
