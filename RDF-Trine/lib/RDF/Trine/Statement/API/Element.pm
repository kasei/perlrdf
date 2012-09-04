{
	package RDF::Trine::Statement::API::Element;
	
	use MooseX::Types::Moose qw(Str Bool);
	use RDF::Trine::Types qw(TrineNode);
	use MooseX::Role::Parameterized;
	
	parameter name => (
		isa      => 'Str',
		required => 1,
	);
	parameter require => (
		isa      => 'Bool',
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

__END__

=head1 NAME

RDF::Trine::Statement::API::Element - a parameterizable Moose role for elements of a statement

=head1 SYNOPSIS

  {
    package My::Statement::WithProvenance;
    use Moose;
    use RDF::Trine::Statement::API::Element ();
    with (
      'RDF::Trine::Statement::API::Element::Subject',
      'RDF::Trine::Statement::API::Element::Predicate',
      'RDF::Trine::Statement::API::Element::Object',
      'RDF::Trine::Statement::API::Element' => {
        name     => 'source',
      },
      'RDF::Trine::Statement::API::Element' => {
        name     => 'owner',
        required => 0,
      },
    );
  }

=head1 DESCRIPTION

In the example in the SYNOPSIS above, a class is created which has
C<subject>, C<predicate> and C<object> attributes (just like
L<RDF::Trine::Statement::Triple>), a similar C<source> property,
and an C<owner> property which was optional.

=head2 Parameters

RDF::Trine::Statement::API::Element is a parameterized role with two
parameters:

=over

=item C<< name >>

=item C<< required >>

=back

=head2 Convenience Roles

The following additional convenience roles are defined (which will improve
the behaviour of C<does>).

=over

=item C<< RDF::Trine::Statement::API::Element::Subject >>

=item C<< RDF::Trine::Statement::API::Element::Predicate >>

=item C<< RDF::Trine::Statement::API::Element::Object >>

=item C<< RDF::Trine::Statement::API::Element::Graph >>

=back

