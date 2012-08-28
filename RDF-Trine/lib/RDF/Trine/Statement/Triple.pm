package RDF::Trine::Statement::Triple;

use Moose;
use namespace::autoclean;

with qw(
	RDF::Trine::Statement::API
);

sub isa {
	my ($self, $isa) = @_;
	if ($isa eq 'RDF::Trine::Statement')
	{
		Carp::carp("isa(RDF::Trine::Statement) is deprecated; use DOES(RDF::Trine::Statement::API)");
		return 1;
	}
	$self->SUPER::isa($isa);
}

sub type { 'TRIPLE' }
sub node_names { qw(subject predicate object) }

sub to_triple { +shift }  # return $self

sub as_ntriples {
	my $self = shift;
	join q[ ] => (
		(map { $_->as_ntriples } $self->nodes),
		".\n"
	);
}

sub from_sse {
	my $class   = shift;
	my $context = $_[1];
	$_			= $_[0];
	if (m/^[(]triple/) {
		s/^[(]triple\s+//;
		my @nodes;
		push(@nodes, RDF::Trine::Node::API->from_sse( $_, $context ));
		push(@nodes, RDF::Trine::Node::API->from_sse( $_, $context ));
		push(@nodes, RDF::Trine::Node::API->from_sse( $_, $context ));
		if (m/^\s*[)]/) {
			s/^\s*[)]//;
			return RDF::Trine::Statement->new( @nodes );
		} else {
			throw RDF::Trine::Error -text => "Cannot parse end-of-triple from SSE string: >>$_<<";
		}
	} else {
		throw RDF::Trine::Error -text => "Cannot parse triple from SSE string: >>$_<<";
	}
}

__PACKAGE__->meta->make_immutable;
1;
