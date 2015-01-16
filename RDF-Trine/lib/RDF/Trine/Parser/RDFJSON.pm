# RDF::Trine::Parser::RDFJSON
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Parser::RDFJSON - RDF/JSON RDF Parser

=head1 VERSION

This document describes RDF::Trine::Parser::RDFJSON version 1.012

=head1 SYNOPSIS

 use RDF::Trine::Parser;
 my $parser	= RDF::Trine::Parser->new( 'RDF/JSON' );
 $parser->parse_into_model( $base_uri, $data, $model );

=head1 DESCRIPTION

...

=head1 METHODS

Beyond the methods documented below, this class inherits methods from the
L<RDF::Trine::Parser> class.

=over 4

=cut

package RDF::Trine::Parser::RDFJSON;

use strict;
use warnings;
no warnings 'redefine';
no warnings 'once';
use base qw(RDF::Trine::Parser);

use URI;
use Log::Log4perl;

use RDF::Trine qw(literal);
use RDF::Trine::Statement;
use RDF::Trine::Namespace;
use RDF::Trine::Node;
use RDF::Trine::Error qw(:try);

use Scalar::Util qw(blessed looks_like_number);
use JSON;

our ($VERSION, $rdf, $xsd);
our ($r_boolean, $r_comment, $r_decimal, $r_double, $r_integer, $r_language, $r_lcharacters, $r_line, $r_nameChar_extra, $r_nameStartChar_minus_underscore, $r_scharacters, $r_ucharacters, $r_booltest, $r_nameStartChar, $r_nameChar, $r_prefixName, $r_qname, $r_resource_test, $r_nameChar_test);
BEGIN {
	$VERSION				= '1.012';
	$RDF::Trine::Parser::parser_names{ 'rdfjson' }	= __PACKAGE__;
	foreach my $ext (qw(json js)) {
		$RDF::Trine::Parser::file_extensions{ $ext }	= __PACKAGE__;
	}
	my $class										= __PACKAGE__;
	$RDF::Trine::Parser::canonical_media_types{ $class }	= 'application/json';
	foreach my $type (qw(application/json application/x-rdf+json)) {
		$RDF::Trine::Parser::media_types{ $type }	= __PACKAGE__;
	}
}

=item C<< new >>

Returns a new RDFJSON parser.

=cut

sub new {
	my $class	= shift;
	my %args	= @_;
	my $prefix	= '';
	if (defined($args{ bnode_prefix })) {
		$prefix	= $args{ bnode_prefix };
	} else {
		$prefix	= $class->new_bnode_prefix();
	}
	my $self	= bless({
					bindings		=> {},
					bnode_id		=> 0,
					bnode_prefix	=> $prefix,
					@_
				}, $class);
	return $self;
}

=item C<< parse_into_model ( $base_uri, $data, $model [, context => $context] ) >>

Parses the bytes in C<< $data >>, using the given C<< $base_uri >>. For each RDF
statement parsed, will call C<< $model->add_statement( $statement ) >>.

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
	my $opts	= $args{'json_opts'};
	
	my $handler	= sub {
		my $st	= shift;
		if ($context) {
			my $quad	= RDF::Trine::Statement::Quad->new( $st->nodes, $context );
			$model->add_statement( $quad );
		} else {
			$model->add_statement( $st );
		}
	};
	return $self->parse( $uri, $input, $handler, $opts );
}

=item C<< parse ( $base_uri, $rdf, \&handler ) >>

Parses the bytes in C<< $data >>, using the given C<< $base_uri >>. Calls the
C<< triple >> method for each RDF triple parsed. This method does nothing by
default, but can be set by using one of the default C<< parse_* >> methods.

=cut

sub parse {
	my $self	= shift;
	my $uri		= shift;
	my $input	= shift;
	my $handler	= shift;
	my $opts	= shift;
	
	my $index	= eval { from_json($input, $opts) };
	if ($@) {
		throw RDF::Trine::Error::ParserError -text => "$@";
	}
	
	foreach my $s (keys %$index) {
		my $ts = ( $s =~ /^_:(.*)$/ ) ?
		         RDF::Trine::Node::Blank->new($self->{bnode_prefix} . $1) :
					RDF::Trine::Node::Resource->new($s, $uri);
		
		foreach my $p (keys %{ $index->{$s} }) {
			my $tp = RDF::Trine::Node::Resource->new($p, $uri);
			
			foreach my $O (@{ $index->{$s}->{$p} }) {
				my $to;
				
				# $O should be a hashref, but we can do a little error-correcting.
				unless (ref $O) {
					if ($O =~ /^_:/) {
						$O = { 'value'=>$O, 'type'=>'bnode' };
					} elsif ($O =~ /^[a-z0-9._\+-]{1,12}:\S+$/i) {
						$O = { 'value'=>$O, 'type'=>'uri' };
					} elsif ($O =~ /^(.*)\@([a-z]{2})$/) {
						$O = { 'value'=>$1, 'type'=>'literal', 'lang'=>$2 };
					} else {
						$O = { 'value'=>$O, 'type'=>'literal' };
					}
				}
				
				if (lc $O->{'type'} eq 'literal') {
					$to = RDF::Trine::Node::Literal->new(
						$O->{'value'}, $O->{'lang'}, $O->{'datatype'});
				} else {
					$to = ( $O->{'value'} =~ /^_:(.*)$/ ) ?
						RDF::Trine::Node::Blank->new($self->{bnode_prefix} . $1) :
						RDF::Trine::Node::Resource->new($O->{'value'}, $uri);
				}
				
				if ( $ts && $tp && $to ) {
					if ($self->{canonicalize}) {
						if ($to->isa('RDF::Trine::Node::Literal') and $to->has_datatype) {
							my $value	= $to->literal_value;
							my $dt		= $to->literal_datatype;
							my $canon	= RDF::Trine::Node::Literal->canonicalize_literal_value( $value, $dt, 1 );
							$to	= literal( $canon, undef, $dt );
						}
					}
					my $st = RDF::Trine::Statement->new($ts, $tp, $to);
					$handler->($st);
				}
			}
		}
	}
	
	return;
}


1;

__END__

=back

=head1 BUGS

Please report any bugs or feature requests to through the GitHub web interface
at L<https://github.com/kasei/perlrdf/issues>.

=head1 AUTHOR

 Toby Inkster <tobyink@cpan.org>
 Gregory Williams <gwilliams@cpan.org>

=head1 COPYRIGHT

Copyright (c) 2006-2012 Gregory Todd Williams. This
program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
