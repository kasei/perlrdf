# RDF::Trine::Parser
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Parser - RDF Parser class.

=head1 VERSION

This document describes RDF::Trine::Parser version 0.112_03

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

our ($VERSION);
BEGIN {
	$VERSION	= '0.112_03';
}

use RDF::Trine::Parser::Turtle;
use RDF::Trine::Parser::RDFXML;
use RDF::Trine::Parser::RDFJSON;

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

=item C<< parse ( $base_uri, $data ) >>

=item C<< parse_into_model ( $base_uri, $data, $model ) >>

=cut



1;

__END__

=back

=head1 AUTHOR

Gregory Todd Williams  C<< <gwilliams@cpan.org> >>

=head1 COPYRIGHT

Copyright (c) 2006-2009 Gregory Todd Williams. All rights reserved. This
program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
