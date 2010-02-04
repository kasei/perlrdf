# RDF::Trine::Parser::RDFa
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Parser::RDFa - RDFa Parser.

=head1 VERSION

This document describes RDF::Trine::Parser::RDFa version 0.117

=head1 SYNOPSIS

 use RDF::Trine::Parser;
 my $parser	= RDF::Trine::Parser->new( 'rdfxml' );
 $parser->parse_into_model( $base_uri, $data, $model );

=head1 DESCRIPTION

...

=head1 METHODS

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

use RDF::Trine::Node;
use RDF::Trine::Statement;
use RDF::Trine::Error qw(:try);

######################################################################

our ($VERSION, $HAVE_RDFA_PARSER);
BEGIN {
	$VERSION	= '0.117';
	$RDF::Trine::Parser::parser_names{ 'rdfa' }	= __PACKAGE__;
	foreach my $type (qw(application/xhtml+xml)) {
		$RDF::Trine::Parser::media_types{ $type }	= __PACKAGE__;
	}
	
	eval "use RDF::RDFa::Parser;";
	unless ($@) {
		$HAVE_RDFA_PARSER	= 1;
	}
}

######################################################################

=item C<< new >>

=cut

sub new {
	my $class	= shift;
	unless ($HAVE_RDFA_PARSER) {
		throw RDF::Trine::Error -text => "Can't locate RDF::RDFa::Parser";
	}
	
	my $self = bless( {}, $class);
	return $self;
}

=item C<< parse_into_model ( $base_uri, $data, $model [, context => $context ] ) >>

Parses the C<< $data >>, using the given C<< $base_uri >>. For each RDF triple
parsed, will call C<< $model->add_statement( $statement ) >>.

=cut

sub parse_into_model {
	my $proto	= shift;
	my $self	= blessed($proto) ? $proto : $proto->new();
	my $uri		= shift;
	if (blessed($uri) and $uri->isa('RDF::Trine::Node::Resource')) {
		$uri	= $uri->uri_value;
	}
	my $input	= shift;
	my $model	= shift;
	my %args	= @_;
	my $context	= $args{'context'};
	
	my $handler	= sub {
		my $st	= shift;
		if ($context) {
			my $quad	= RDF::Trine::Statement::Quad->new( $st->nodes, $context );
			$model->add_statement( $quad );
		} else {
			$model->add_statement( $st );
		}
	};
	return $self->parse( $uri, $input, $handler );
}

=item C<< parse ( $base_uri, $rdf, \&handler ) >>

=cut

sub parse {
	my $self	= shift;
	my $base	= shift;
	my $string	= shift;
	my $handler	= shift;
	
	my $parser	= RDF::RDFa::Parser->new($string, $base);
	$parser->consume;
	my $graph	= $parser->graph;
	my $iter	= $graph->as_stream;
	while (my $st = $iter->next()) {
		if (reftype($handler) eq 'CODE') {
			$handler->( $st );
		}
	}
}


1;

__END__

=back

=head1 AUTHOR

Gregory Todd Williams  C<< <gwilliams@cpan.org> >>

=head1 COPYRIGHT

Copyright (c) 2006-2010 Gregory Todd Williams. All rights reserved. This
program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
