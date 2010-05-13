# RDF::Trine::Parser::NQuads
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Parser::NQuads - N-Quads Parser

=head1 VERSION

This document describes RDF::Trine::Parser::NQuads version 0.122

=head1 SYNOPSIS

 use RDF::Trine::Parser;
 my $parser	= RDF::Trine::Parser->new( 'nquads' );
 $parser->parse_into_model( $base_uri, $data, $model );

=head1 DESCRIPTION

...

=head1 METHODS

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
use RDF::Trine::Node;
use RDF::Trine::Statement;
use RDF::Trine::Error qw(:try);

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= '0.122';
	$RDF::Trine::Parser::parser_names{ 'nquads' }	= __PACKAGE__;
# 	foreach my $type (qw(text/plain)) {
# 		$RDF::Trine::Parser::media_types{ $type }	= __PACKAGE__;
# 	}
}

######################################################################

=item C<< parse_into_model ( $base_uri, $data, $model ) >>

Parses the C<< $data >>, using the given C<< $base_uri >>. For each RDF triple
or quad parsed, will call C<< $model->add_statement( $statement ) >>.

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
	
	if (my $context = $args{'context'}) {
		throw RDF::Trine::Error::ParserError -text => "Cannot pass a context node to N-Quads parse_into_model method";
	}
	
	my $handler	= sub {
		my $st	= shift;
		$model->add_statement( $st );
	};
	return $self->parse( $uri, $input, $handler );
}

sub _emit_statement {
	my $self	= shift;
	my $handler	= shift;
	my $nodes	= shift;
	my $lineno	= shift;
	my $st;
	
	if ($self->{canonicalize}) {
		if ($nodes->[2]->isa('RDF::Trine::Node::Literal') and $nodes->[2]->has_datatype) {
			my $value	= $nodes->[2]->literal_value;
			my $dt		= $nodes->[2]->literal_datatype;
			my $canon	= $self->canonicalize_literal_value( $value, $dt );
			$nodes->[2]	= literal( $canon, undef, $dt );
		}
	}

	if (scalar(@$nodes) == 3) {
		$st	= RDF::Trine::Statement->new( @$nodes );
	} elsif (scalar(@$nodes) == 4) {
		$st	= RDF::Trine::Statement::Quad->new( @$nodes );
	} else {
# 		warn Dumper($nodes);
		throw RDF::Trine::Error::ParserError -text => "Not valid N-Quads data at line $lineno";
	}
	
	$handler->( $st );
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
