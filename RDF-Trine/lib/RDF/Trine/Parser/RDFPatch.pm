# RDF::Trine::Parser::RDFPatch
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Parser::RDFPatch - RDF-Patch Parser

=head1 VERSION

This document describes RDF::Trine::Parser::RDFPatch version 1.007

=head1 SYNOPSIS

 use RDF::Trine::Parser::RDFPatch;
 my $serializer	= RDF::Trine::Parser::RDFPatch->new();

=head1 DESCRIPTION

The RDF::Trine::Parser::RDFPatch class provides an API for serializing RDF
graphs to the RDF-Patch syntax.

=head1 METHODS

=over 4

=cut

package RDF::Trine::Parser::RDFPatch;

use strict;
use warnings;

use URI;
use Carp;
use Data::Dumper;
use Scalar::Util qw(blessed);
use List::Util qw(min);

use RDF::Trine::Node;
use RDF::Trine::Statement;
use RDF::Trine::Error qw(:try);

e######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= '1.007';
}

######################################################################

=item C<< new (  ) >>

Returns a new RDF-Patch Parser object.

=cut

sub new {
	my $class	= shift;
	my $self = bless( {}, $class );
	return $self;
}

=item C<< parse ( $base_uri, $rdf, \&handler ) >>

=cut

sub parse {
	my $self	= shift;
	my $base	= shift;
	my $string	= shift;
	my $handler	= shift;
	open( my $fh, '<:encoding(UTF-8)', \$string );
	return $self->parse_file( $base, $fh, $handler );
}

=item C<< parse_file ( $base, $fh, \&handler ) >>

=cut

sub parse_file {
	my $self	= shift;
	my $base	= shift;
	my $fh		= shift;
	my $handler	= shift;
	
	unless (ref($fh)) {
		my $filename	= $fh;
		undef $fh;
		open( $fh, '<:encoding(UTF-8)', $filename ) or throw RDF::Trine::Error::ParserError -text => $!;
	}
	
	...
}

1;

__END__

=back

=head1 BUGS

Please report any bugs or feature requests to through the GitHub web interface
at L<https://github.com/kasei/perlrdf/issues>.

=head1 SEE ALSO

L<http://afs.github.io/rdf-patch/>

=head1 AUTHOR

Gregory Todd Williams  C<< <gwilliams@cpan.org> >>

=head1 COPYRIGHT

Copyright (c) 2006-2012 Gregory Todd Williams. This
program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
