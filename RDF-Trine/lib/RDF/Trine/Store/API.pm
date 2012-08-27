package RDF::Trine::Store::API;
use Moose::Role;

sub BUILD {}
after BUILD => sub {
	my $self	= shift;
	my $class	= ref($self);
	unless ($self->does('RDF::Trine::Store::API::Readable') or $self->does('RDF::Trine::Store::Writeable')) {
		confess "Store of type $class must compose either RDF::Trine::Store::API::Readable or RDF::Trine::Store::API::Writeable";
	}
};

requires 'supports';

around supports => sub {
	my $next	= shift;
	my $self	= shift;
	return 1 if eval { $self->does(@_) };
	return $self->$next(@_);
};

1;
