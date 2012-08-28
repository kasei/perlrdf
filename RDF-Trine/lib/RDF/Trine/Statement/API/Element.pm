{
	package RDF::Trine::Statement::API::Element;
	
	use MooseX::Types::Moose qw(Str Bool);
	use RDF::Trine::Types qw(TrineNode);
	use MooseX::Role::Parameterized;
	
	parameter name => (
		isa      => Str,
		required => 1,
	);
	parameter require => (
		isa      => Bool,
		default  => 1,
	);
	role {
		my $p = shift;
		
		has $p->name => (
			is       => 'rw',       # :-(
			isa      => TrineNode,
			required => $p->require,
		);
	}
}

{
	package RDF::Trine::Statement::API::Element::Subject;
	use Moose::Role;
	with 'RDF::Trine::Statement::API::Element' => { name => 'subject' };
}

{
	package RDF::Trine::Statement::API::Element::Predicate;
	use Moose::Role;
	with 'RDF::Trine::Statement::API::Element' => { name => 'predicate' };
}

{
	package RDF::Trine::Statement::API::Element::Object;
	use Moose::Role;
	with 'RDF::Trine::Statement::API::Element' => { name => 'object' };
}

{
	package RDF::Trine::Statement::API::Element::Graph;
	use Moose::Role;
	with 'RDF::Trine::Statement::API::Element' => { name => 'graph' };
}

1;
