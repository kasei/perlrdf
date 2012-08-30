# RDF::Trine::Parser::NQuads
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Parser::NQuads - N-Quads Parser

=head1 VERSION

This document describes RDF::Trine::Parser::NQuads version 1.000

=head1 SYNOPSIS

 use RDF::Trine::Parser;
 my $parser	= RDF::Trine::Parser->new( 'nquads' );
 $parser->parse_into_model( $base_uri, $data, $model );

=head1 DESCRIPTION

...

=head1 METHODS

Beyond the methods documented below, this class inherits methods from the
L<RDF::Trine::Parser> class.

=over 4

=cut

package RDF::Trine::Parser::NQuads;

use strict;
use warnings;
use utf8;

use base qw(RDF::Trine::Parser::NTriples);

use Carp;
use Encode qw(decode);
use Data::Dumper;
use Log::Log4perl;
use Scalar::Util qw(blessed reftype);

use RDF::Trine qw(literal);
use RDF::Trine::Statement::Triple;
use RDF::Trine::Error qw(:try);

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= '1.000';
	$RDF::Trine::Parser::parser_names{ 'nquads' }	= __PACKAGE__;
	$RDF::Trine::Parser::format_uris{ 'http://sw.deri.org/2008/07/n-quads/#n-quads' }	= __PACKAGE__;
	foreach my $ext (qw(nq)) {
		$RDF::Trine::Parser::file_extensions{ $ext }	= __PACKAGE__;
	}
	my $class										= __PACKAGE__;
	$RDF::Trine::Parser::canonical_media_types{ $class }	= 'text/x-nquads';
	foreach my $type (qw(text/x-nquads)) {
		$RDF::Trine::Parser::media_types{ $type }	= __PACKAGE__;
	}
}

######################################################################

sub parse_line {
	my $self = shift;
	my $line = shift;
	$line =~ s/^[ \t]*(?:#.*)?//;
	return unless $line;

	my $subject = $self->_parse_subject($line);
	$line =~ s/^[ \t]+// or _error("No whitespace between subject and predicate");
	my $predicate = $self->_parse_predicate($line);
	$line =~ s/^[ \t]+// or _error("No whitespace between predicate and object");
	my $object = $self->_parse_object($line);
	if ($line =~ /^[ \t]*\./) {
		$line =~ s/^[ \t]*\.// or _error("Missing dot");
		$line =~ /^[ \t]*$/ or _error("Invalid syntax after dot");
		return RDF::Trine::Statement::Triple->new($subject, $predicate, $object);
	} else {
		$line =~ s/^[ \t]+// or _error("No whitespace between object and graph");
		my $graph = $self->_parse_object($line);
		$line =~ s/^[ \t]*\.// or _error("Missing dot");
		$line =~ /^[ \t]*$/ or _error("Invalid syntax after dot");
		return RDF::Trine::Statement::Quad->new($subject, $predicate, $object, $graph);
	}

}


1;

__END__

=back

=head1 BUGS

Please report any bugs or feature requests to through the GitHub web interface
at L<https://github.com/kasei/perlrdf/issues>.

=head1 AUTHOR

Gregory Todd Williams  C<< <gwilliams@cpan.org> >>

=head1 COPYRIGHT

Copyright (c) 2006-2012 Gregory Todd Williams. This
program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
