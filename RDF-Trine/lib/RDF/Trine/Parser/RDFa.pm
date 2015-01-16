# RDF::Trine::Parser::RDFa
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Parser::RDFa - RDFa Parser

=head1 VERSION

This document describes RDF::Trine::Parser::RDFa version 1.012

=head1 SYNOPSIS

 use RDF::Trine::Parser;
 my $parser	= RDF::Trine::Parser->new( 'rdfxml' );
 $parser->parse_into_model( $base_uri, $data, $model );

=head1 DESCRIPTION

...

=head1 METHODS

Beyond the methods documented below, this class inherits methods from the
L<RDF::Trine::Parser> class.

=over 4

=cut

package RDF::Trine::Parser::RDFa;

use strict;
use warnings;

use base qw(RDF::Trine::Parser);

use Carp;
use Data::Dumper;
use Log::Log4perl;
use Scalar::Util qw(blessed reftype);
use Module::Load::Conditional qw[can_load];

use RDF::Trine qw(literal);
use RDF::Trine::Node;
use RDF::Trine::Statement;
use RDF::Trine::Error qw(:try);

######################################################################

our ($VERSION, $HAVE_RDFA_PARSER);
BEGIN {
	$VERSION	= '1.012';
	if (can_load( modules => { 'RDF::RDFa::Parser' => 0.30 })) {
		$HAVE_RDFA_PARSER	= 1;
		$RDF::Trine::Parser::parser_names{ 'rdfa' }	= __PACKAGE__;
		foreach my $ext (qw(html xhtml htm)) {
			$RDF::Trine::Parser::file_extensions{ $ext }	= __PACKAGE__;
		}
		my $class										= __PACKAGE__;
		$RDF::Trine::Parser::canonical_media_types{ $class }	= 'application/xhtml+xml';
		foreach my $type (qw(application/xhtml+xml text/html)) {
			$RDF::Trine::Parser::media_types{ $type }	= __PACKAGE__;
		}
		$RDF::Trine::Parser::format_uris{ 'http://www.w3.org/ns/formats/RDFa' }	= __PACKAGE__;
	}
}

######################################################################

=item C<< new ( options => \%options ) >>

Returns a new RDFa parser object with the supplied options.

=cut

sub new {
	my $class	= shift;
	my %args	= @_;
	unless ($HAVE_RDFA_PARSER) {
		throw RDF::Trine::Error -text => "Failed to load RDF::RDFa::Parser >= 0.30";
	}
	
	my $self = bless( { %args }, $class);
	return $self;
}

=item C<< parse_into_model ( $base_uri, $data, $model [, context => $context] ) >>

Parses the bytes in C<< $data >>, using the given C<< $base_uri >>. For each RDF
statement parsed, will call C<< $model->add_statement( $statement ) >>.

=cut

=item C<< parse ( $base_uri, $rdf, \&handler ) >>

=cut

sub parse {
	my $self	= shift;
	my $base	= shift;
	my $string	= shift;
	my $handler	= shift;
	
	my $parser  = RDF::RDFa::Parser->new($string, $base, $self->{'options'});
	$parser->set_callbacks({
		ontriple	=> sub {
			my ($p, $el, $st)	= @_;
			if (reftype($handler) eq 'CODE') {
				if ($self->{canonicalize}) {
					my $o	= $st->object;
					if ($o->isa('RDF::Trine::Node::Literal') and $o->has_datatype) {
						my $value	= $o->literal_value;
						my $dt		= $o->literal_datatype;
						my $canon	= RDF::Trine::Node::Literal->canonicalize_literal_value( $value, $dt, 1 );
						$o	= literal( $canon, undef, $dt );
						$st->object( $o );
					}
				}
				$handler->( $st );
			}
			return 1;
		}
	});
	$parser->consume;
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
