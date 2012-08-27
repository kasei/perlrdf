package RDF::Trine::Node::Nil;

use utf8;
use Scalar::Util qw(refaddr);

use Moose;
use MooseX::Singleton;

with 'RDF::Trine::Node::API::BaseNode';

sub is_nil { 1 }
sub sse { '(nil)' }
sub value { '' }
sub as_ntriples {
	my $self = shift;
	return sprintf('<%s>', RDF::Trine::NIL_GRAPH());
}
sub type { 'NIL' }
sub from_sse {
	...;
}
sub equal { refaddr(shift)==refaddr(shift) }

__PACKAGE__->meta->make_immutable;
1;

__END__

