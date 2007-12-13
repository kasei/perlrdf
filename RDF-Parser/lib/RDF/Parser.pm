package RDF::Parser;

use strict;
use warnings;

use RDF::Parser::Turtle;

our %types;

=item C<< new ( $type ) >>

=cut

sub new {
	my $class	= shift;
	my $type	= shift;
	
	if ($type eq 'guess') {
		die;
	} elsif (my $class = $types{ $type }) {
		return $class->new( @_ );
	} else {
		throw RDF::Parser::Error -text => "No parser known for type $type";
	}
}
