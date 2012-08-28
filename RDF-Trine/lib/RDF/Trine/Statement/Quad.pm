package RDF::Trine::Statement::Quad;

use Moose;
use MooseX::Aliases;
use namespace::autoclean;

with qw(
	RDF::Trine::Statement::API
	RDF::Trine::Statement::API::Element::Graph
);

alias context => 'graph';

sub isa {
	my ($self, $isa) = @_;
	if ($isa eq 'RDF::Trine::Statement')
	{
		Carp::carp("isa(RDF::Trine::Statement) is deprecated; use DOES(RDF::Trine::Statement::API)");
		return 1;
	}
	$self->SUPER::isa($isa);
}

sub type { 'QUAD' }
sub node_names { qw(subject predicate object graph) }

sub from_sse {
	my $class   = shift;
	my $context = $_[1];
	$_          = $_[0];
	if (m/^[(]quad/) {
		s/^[(]quad\s+//;
		my @nodes;
		push(@nodes, RDF::Trine::Node::API->from_sse( $_, $context ));
		push(@nodes, RDF::Trine::Node::API->from_sse( $_, $context ));
		push(@nodes, RDF::Trine::Node::API->from_sse( $_, $context ));
		push(@nodes, RDF::Trine::Node::API->from_sse( $_, $context ));
		if (m/^\s*[)]/) {
			s/^\s*[)]//;
			return RDF::Trine::Statement::Triple->new( @nodes );
		} else {
			throw RDF::Trine::Error -text => "Cannot parse end-of-quad from SSE string: >>$_<<";
		}
	} else {
		throw RDF::Trine::Error -text => "Cannot parse quad from SSE string: >>$_<<";
	}
}

__PACKAGE__->meta->make_immutable;
1;
