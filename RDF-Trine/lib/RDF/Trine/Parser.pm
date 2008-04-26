# RDF::Trine::Parser
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Parser - RDF Parser class.

=head1 VERSION

This document describes RDF::Trine::Parser version 0.107

=head1 SYNOPSIS

 use RDF::Trine::Parser;
 my $parser	= RDF::Trine::Parser->new( 'turtle' );
 my $iterator = $parser->parse( $base_uri, $data );

=head1 DESCRIPTION

...

=head1 METHODS

=over 4

=cut

package RDF::Trine::Parser;

use strict;
use warnings;
no warnings 'redefine';

our ($VERSION, $debug);
BEGIN {
	$debug		= 0;
	$VERSION	= 0.107;
}

use RDF::Trine::Parser::Turtle;
use RDF::Trine::Parser::RDFXML;

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
		throw RDF::Trine::Parser::Error -text => "No parser known for type $type";
	}
}

1;

__END__

=back

=head1 AUTHOR

 Gregory Williams <gwilliams@cpan.org>

=cut

