# RDF::Trine::Node::Resource
# -------------
# $Revision: 121 $
# $Date: 2006-02-06 23:07:43 -0500 (Mon, 06 Feb 2006) $
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Node::Resource - RDF Node class for resources

=cut

package RDF::Trine::Node::Resource;

use strict;
use warnings;
use base qw(RDF::Trine::Node);

use URI;
use Data::Dumper;
use Scalar::Util qw(blessed reftype);
use Carp qw(carp croak confess);

######################################################################

our ($VERSION, $debug, $lang, $languri);
BEGIN {
	$debug		= 0;
	$VERSION	= do { my $REV = (qw$Revision: 121 $)[1]; sprintf("%0.3f", 1 + ($REV/1000)) };
}

######################################################################

=head1 METHODS

=over 4

=cut

=item C<new ( $iri )>

Returns a new Resource structure.

=cut

sub new {
	my $class	= shift;
	my $uri		= shift;
	if (defined($_[0])) {
		my $base	= shift;
		### We have to work around the URI module not accepting IRIs. If there's
		### Unicode in the IRI, pull it out, leaving behind a breadcrumb. Turn
		### the URI into an absolute URI, and then replace the breadcrumbs with
		### the Unicode.
		
		my @uni;
		my $count	= 0;
		while ($uri =~ /([\x{00C0}-\x{00D6}\x{00D8}-\x{00F6}\x{00F8}-\x{02FF}\x{0370}-\x{037D}\x{037F}-\x{1FFF}\x{200C}-\x{200D}\x{2070}-\x{218F}\x{2C00}-\x{2FEF}\x{3001}-\x{D7FF}\x{F900}-\x{FDCF}\x{FDF0}-\x{FFFD}\x{10000}-\x{EFFFF}]+)/) {
			my $text	= $1;
			push(@uni, $text);
			$uri		=~ s/$1/',____' . $count . '____,'/e;
			$count++;
		}
		
		my $abs			= URI->new_abs( $uri, $base->uri_value );
		
		$uri			= $abs->as_string;
		while ($uri =~ /,____(\d+)____,/) {
			my $num	= $1;
			my $i	= index($uri, ",____${num}____,");
			my $len	= 10 + length($num);
			substr($uri, $i, $len)	= shift(@uni);
		}
		$uri	= $uri;
	}
	return bless( [ 'URI', $uri ], $class );
}

=item C<< uri_value >>

Returns the URI/IRI value of this resource.

=cut

sub uri_value {
	my $self	= shift;
	return $self->[1];
}

=item C<< uri ( $uri ) >>

Returns the URI value of this resource, optionally updating the URI.

=cut

sub uri {
	my $self	= shift;
	if (@_) {
		$self->[1]	= shift;
	}
	return $self->[1];
}

=item C<< sse >>

Returns the SSE string for this resource.

=cut

sub sse {
	my $self	= shift;
	my $context	= shift;
	my $uri		= $self->uri_value;
	my $ns		= $context->{namespaces};
	
	if (ref($uri) and reftype($uri) eq 'ARRAY') {
		my ($ns, $local)	= @$uri;
		$ns	= '' if ($ns eq '__DEFAULT__');
		return join(':', $ns, $local);
	} else {
		my $string	= qq(<${uri}>);
		foreach my $n (keys %$ns) {
			if (substr($uri, 0, length($ns->{ $n })) eq $ns->{ $n }) {
				$string	= join(':', $n, substr($uri, length($ns->{ $n })));
				last;
			}
		}
		
		return $string;
	}
}

=item C<< as_sparql >>

Returns the SPARQL string for this node.

=cut

sub as_sparql {
	my $self	= shift;
	my $context	= shift;
	return $self->sse( $context );
}

=item C<< as_string >>

Returns a string representation of the node.

=cut

sub as_string {
	my $self	= shift;
	return '<' . $self->uri_value . '>';
}

=item C<< type >>

Returns the type string of this node.

=cut

sub type {
	return 'URI';
}

=item C<< equal ( $node ) >>

Returns true if the two nodes are equal, false otherwise.

=cut

sub equal {
	my $self	= shift;
	my $node	= shift;
	return 0 unless (blessed($node) and $node->isa('RDF::Trine::Node'));
	return 0 unless ($self->type eq $node->type);
	return ($self->uri_value eq $node->uri_value);
}

1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
