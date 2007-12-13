# RDF::Query::Algebra
# -------------
# $Revision: 121 $
# $Date: 2006-02-06 23:07:43 -0500 (Mon, 06 Feb 2006) $
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Node - Base class for Algebra expressions

=cut

package RDF::Query::Algebra;

use strict;
use warnings;


use RDF::Query::Algebra::BasicGraphPattern;
use RDF::Query::Algebra::Expr;
use RDF::Query::Algebra::OldFilter;
use RDF::Query::Algebra::GroupGraphPattern;
use RDF::Query::Algebra::Optional;
use RDF::Query::Algebra::Triple;
use RDF::Query::Algebra::Union;
use RDF::Query::Algebra::NamedGraph;
use RDF::Query::Algebra::TimeGraph;
use RDF::Query::Algebra::Function;
use RDF::Query::Algebra::Aggregate;

1;

__END__

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
