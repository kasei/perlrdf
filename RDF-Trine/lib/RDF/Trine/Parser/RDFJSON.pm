# RDF::Trine::Parser::RDFJSON
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Parser::RDFJSON - RDF/JSON RDF Parser.

=head1 VERSION

This document describes RDF::Trine::Parser::RDFJSON version 0.112_03

=head1 SYNOPSIS

 use RDF::Trine::Parser;
 my $parser	= RDF::Trine::Parser->new( 'RDF/JSON' );
 my $iterator = $parser->parse( $base_uri, $data );

=head1 DESCRIPTION

...

=head1 METHODS

=over 4

=cut

package RDF::Trine::Parser::RDFJSON;

use strict;
use warnings;
no warnings 'redefine';
no warnings 'once';

use URI;
use Data::UUID;
use Log::Log4perl;
use RDF::Trine::Statement;
use RDF::Trine::Namespace;
use RDF::Trine::Node;
use RDF::Trine::Parser::Error;
use Scalar::Util qw(blessed looks_like_number);
use JSON;

our ($VERSION, $rdf, $xsd);
our ($r_boolean, $r_comment, $r_decimal, $r_double, $r_integer, $r_language, $r_lcharacters, $r_line, $r_nameChar_extra, $r_nameStartChar_minus_underscore, $r_scharacters, $r_ucharacters, $r_booltest, $r_nameStartChar, $r_nameChar, $r_prefixName, $r_qname, $r_resource_test, $r_nameChar_test);
BEGIN {
	$VERSION				= '0.112_03';
	
	foreach my $t ('RDFJSON', 'RDF/JSON', 'application/json', 'application/x-rdf+json') {
		$RDF::Trine::Parser::types{ $t }	= __PACKAGE__;
	}
}

=item C<< new >>

Returns a new RDFJSON parser.

=cut

sub new {
	my $class	= shift;
	my $ug		= new Data::UUID;
	my $uuid	= $ug->to_string( $ug->create() );
	$uuid		=~ s/-//g;
	my $self	= bless({
					bindings		=> {},
					bnode_id		=> 0,
					bnode_prefix	=> $uuid,
				}, $class);
	return $self;
}

=item C<< parse ( $base_uri, $data ) >>

Parses the C<< $data >>, using the given C<< $base_uri >>. Calls the
C<< triple >> method for each RDF triple parsed. This method does nothing by
default, but can be set by using one of the default C<< parse_* >> methods.

=cut

sub parse {
	my $self	= shift;
	my $uri		= shift;
	my $input	= shift;
	my $handler	= shift;
	my $opts = shift;
	
	my $index = from_json($input, $opts);
	
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
					my $st = RDF::Trine::Statement->new($ts, $tp, $to);
					$handler->($st);
				}
			}
		}
	}
	
	return;
}

=item C<< parse_into_model ( $base_uri, $data, $model ) >>

Parses the C<< $data >>, using the given C<< $base_uri >>. For each RDF triple
parsed, will call C<< $model->add_statement( $statement ) >>.

=cut

sub parse_into_model {
	my $self	= shift;
	my $uri		= shift;
	my $input	= shift;
	my $model	= shift;
	my $opts = shift;
	my $handler	= sub {
		my $st	= shift;
		$model->add_statement( $st );
	};
	return $self->parse( $uri, $input, $handler, $opts );
}

1;

__END__

=back

=head1 AUTHOR

 Toby Inkster <tobyink@cpan.org>
 Gregory Williams <gwilliams@cpan.org>

=cut

