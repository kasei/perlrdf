# RDF::Trine::Parser
# -------------
# $Revision: 127 $
# $Date: 2006-02-08 14:53:21 -0500 (Wed, 08 Feb 2006) $
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Parser - RDF Parser class.

=head1 VERSION

This document describes RDF::Trine::Parser version 1.001

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

use RDF::Trine::Parser::Turtle;

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

