# RDF::Trine::Parser::RDFXML
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Parser::RDFXML - RDF/XML Parser

=head1 VERSION

This document describes RDF::Trine::Parser::RDFXML version 1.012

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

package RDF::Trine::Parser::RDFXML;

use strict;
use warnings;

use base qw(RDF::Trine::Parser);

use URI;
use Carp;
use Encode;
use XML::SAX;
use Data::Dumper;
use Log::Log4perl;
use Scalar::Util qw(blessed);
use Module::Load::Conditional qw[can_load];

use RDF::Trine qw(literal);
use RDF::Trine::Node;
use RDF::Trine::Statement;
use RDF::Trine::Error qw(:try);

######################################################################

our ($VERSION, $HAS_XML_LIBXML);
BEGIN {
	$VERSION	= '1.012';
	$RDF::Trine::Parser::parser_names{ 'rdfxml' }	= __PACKAGE__;
	foreach my $ext (qw(rdf xrdf rdfx)) {
		$RDF::Trine::Parser::file_extensions{ $ext }	= __PACKAGE__;
	}
	my $class										= __PACKAGE__;
	$RDF::Trine::Parser::canonical_media_types{ $class }	= 'application/rdf+xml';
	foreach my $type (qw(application/rdf+xml application/octet-stream)) {
		$RDF::Trine::Parser::media_types{ $type }	= __PACKAGE__;
	}
	$RDF::Trine::Parser::format_uris{ 'http://www.w3.org/ns/formats/RDF_XML' }	= __PACKAGE__;
	
	$HAS_XML_LIBXML	= can_load( modules => {
		'XML::LibXML'	=> 1.70,
	} );

}

######################################################################

=item C<< new >>

=cut

sub new {
	my $class	= shift;
	my %args	= @_;
	$class = ref($class) || $class;

	my $prefix	= '';
	if (defined($args{ BNodePrefix })) {
		$prefix	= delete $args{ BNodePrefix };
	} elsif (defined($args{ bnode_prefix })) {
		$prefix	= delete $args{ bnode_prefix };
	} else {
		$prefix	= $class->new_bnode_prefix();
	}
	
	my $saxhandler	= RDF::Trine::Parser::RDFXML::SAXHandler->new( %args, bnode_prefix => $prefix );
	my $p		= XML::SAX::ParserFactory->parser(Handler => $saxhandler);
	
	my $self = bless( {
		saxhandler	=> $saxhandler,
		parser		=> $p,
		%args,
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
	
	my $handler	= sub {
		my $st	= shift;
		if ($context) {
			my $quad	= RDF::Trine::Statement::Quad->new( $st->nodes, $context );
			$model->add_statement( $quad );
		} else {
			$model->add_statement( $st );
		}
	};
	$self->{saxhandler}->set_handler( $handler );
	return $self->parse( $uri, $input, $handler );
}

=item C<< parse ( $base_uri, $rdf, \&handler ) >>

=cut

sub parse {
	my $self	= shift;
	my $base	= shift;
	my $string	= shift;
	my $handler	= shift;
	unless ($string) {
		throw RDF::Trine::Error::ParserError -text => "No RDF/XML content supplied to parser.";
	}
	if ($base) {
		unless (blessed($base)) {
			$base	= RDF::Trine::Node::Resource->new( $base );
		}
		$self->{saxhandler}->push_base( $base );
	}
	
	if ($handler) {
		$self->{saxhandler}->set_handler( $handler );
	}
	
	eval {
		if (ref($string)) {
			$self->{parser}->parse_file( $string );
		} else {
			$string	= encode('UTF-8', $string, Encode::FB_CROAK);
			$self->{parser}->parse_string( $string );
		}
	};
	if ($@) {
		throw RDF::Trine::Error::ParserError -text => "$@";
	}
	
	my $nodes	= $self->{saxhandler}{nodes};
	if ($nodes and scalar(@$nodes)) {
		warn Dumper($nodes);
		throw RDF::Trine::Error::ParserError -text => "node stack isn't empty after parse";
	}
	my $expect	= $self->{saxhandler}{expect};
	if ($expect and scalar(@$expect) > 2) {
		warn Dumper($expect);
		throw RDF::Trine::Error::ParserError -text => "expect stack isn't empty after parse";
	}
}

=item C<< parse_file ( $base_uri, $fh, \&handler ) >>

Parses all data read from the filehandle C<< $fh >>, using the given
C<< $base_uri >>. For each RDF statement parsed, C<< $handler->( $st ) >> is called.

Note: The filehandle should NOT be opened with the ":encoding(UTF-8)" IO layer,
as this is known to cause problems for XML::SAX.

=cut

sub parse_file {
	my $self	= shift;
	my $base	= shift;
	my $fh		= shift;
	my $handler	= shift;
	
	unless (ref($fh)) {
		my $filename	= $fh;
		undef $fh;
		open( $fh, '<', $filename ) or throw RDF::Trine::Error::ParserError -text => $!;
	}
	if ($base) {
		unless (blessed($base)) {
			$base	= RDF::Trine::Node::Resource->new( $base );
		}
		$self->{saxhandler}->push_base( $base );
	}
	
	if ($handler) {
		$self->{saxhandler}->set_handler( $handler );
	}
	
	eval {
		$self->{parser}->parse_file( $fh );
	};
	if ($@) {
		throw RDF::Trine::Error::ParserError -text => "$@";
	}
	
	my $nodes	= $self->{saxhandler}{nodes};
	if ($nodes and scalar(@$nodes)) {
		warn Dumper($nodes);
		throw RDF::Trine::Error::ParserError -text => "node stack isn't empty after parse";
	}
	my $expect	= $self->{saxhandler}{expect};
	if ($expect and scalar(@$expect) > 2) {
		warn Dumper($expect);
		throw RDF::Trine::Error::ParserError -text => "expect stack isn't empty after parse";
	}
}


package RDF::Trine::Parser::RDFXML::SAXHandler;

use strict;
use warnings;
use base qw(XML::SAX::Base);

use Data::Dumper;
use Scalar::Util qw(blessed);
use RDF::Trine::Namespace qw(rdf);

use constant	NIL			=> 0x00;
use constant	SUBJECT		=> 0x01;
use constant	PREDICATE	=> 0x02;
use constant	OBJECT		=> 0x04;
use constant	LITERAL		=> 0x08;
use constant	COLLECTION	=> 0x16;

sub new {
	my $class	= shift;
	my %args	= @_;
	my $prefix	= '';
	if (defined($args{ BNodePrefix })) {
		$prefix	= $args{ BNodePrefix };
	} elsif (defined($args{ bnode_prefix })) {
		$prefix	= $args{ bnode_prefix };
	}
	my $self	= bless( {
					expect			=> [ SUBJECT, NIL ],
					base			=> [],
					depth			=> 0,
					characters		=> '',
					prefix			=> $prefix,
					counter			=> 0,
					nodes			=> [],
					chars_ok		=> 0,
				}, $class );
	if (my $ns = $args{ namespaces }) {
		$self->{namespaces}	= $ns;
	}
	if (my $base = $args{ base }) {
		$self->push_base( $base );
	}
	return $self;
}

sub new_expect {
	my $self	= shift;
	my $new		= shift;
	unshift( @{ $self->{expect} }, $new );
}

sub old_expect {
	my $self	= shift;
	shift( @{ $self->{expect} } );
}

sub expect {
	my $self	= shift;
	if (scalar(@{ $self->{expect} }) == 0) {
		Carp::cluck '********* expect stack is empty';
	}
	return $self->{expect}[0];
}

sub peek_expect {
	my $self	= shift;
	return $self->{expect}[1];
}


=begin private

=item C<< start_element >>

=cut

sub start_element {
	my $self	= shift;
	my $el		= shift;
	my $l		= Log::Log4perl->get_logger("rdf.trine.parser.rdfxml");
	
	$l->trace('start_element ' . $el->{Name});
	
	$self->{depth}++;
	unless ($self->expect == LITERAL) {
		$self->handle_scoped_values( $el );
	}
	if ($self->{depth} == 1 and $el->{NamespaceURI} eq 'http://www.w3.org/1999/02/22-rdf-syntax-ns#' and $el->{LocalName} eq 'RDF') {
		# ignore the wrapping rdf:RDF element
	} else {
		my $prefix	= $el->{Prefix};
		my $expect	= $self->expect;
		
		if ($expect == NIL) {
			$self->new_expect( $expect = SUBJECT );
		}
		
		if ($expect == SUBJECT or $expect == OBJECT) {
			my $ns		= $self->get_namespace( $prefix );
			my $local	= $el->{LocalName};
			my $uri		= join('', $ns, $local);
			my $node	= $self->new_resource( $uri );
			$l->trace("-> expect SUBJECT or OBJECT");
			if ($self->expect == OBJECT) {
				if (defined($self->{characters}) and length(my $string = $self->{characters})) {
					if ($string =~ /\S/) {
						die "character data found before object element";
					}
				}
				delete($self->{characters});	# get rid of any whitespace we saw before the element
			}
			my $node_id	= $self->node_id( $el );
			
			if ($self->peek_expect == COLLECTION) {
				my $list	= $self->new_bnode;
				$l->trace("adding an OBJECT to a COLLECTION " . $list->sse . "\n");
				if (my $last = $self->{ collection_last }[0]) {
					my $st		= RDF::Trine::Statement->new( $last, $rdf->rest, $list );
					$self->assert( $st );
				}
				$self->{ collection_last }[0]	= $list;
				my $st		= RDF::Trine::Statement->new( $list, $rdf->first, $node_id );
				$self->assert( $st );
				$self->{ collection_head }[0]	||= $list;
			} elsif ($self->expect == OBJECT) {
				my $nodes	= $self->{nodes};
				my $st		= RDF::Trine::Statement->new( @{ $nodes }[ $#{$nodes} - 1, $#{$nodes} ], $node_id );
				$self->assert( $st );
			}
			
			if ($uri eq 'http://www.w3.org/1999/02/22-rdf-syntax-ns#Description') {
				$l->trace("got rdf:Description of " . $node_id->as_string);
			} else {
				my $type	= $node;
				$l->trace("got object node " . $node_id->as_string . " of type " . $node->as_string);
				# emit an rdf:type statement
				my $st	= RDF::Trine::Statement->new( $node_id, $rdf->type, $node );
				$self->assert( $st );
			}
			push( @{ $self->{nodes} }, $node_id );
			
			$self->parse_literal_property_attributes( $el, $node_id );
			$self->new_expect( PREDICATE );
			unshift(@{ $self->{seqs} }, 0);
			$l->trace('unshifting seq counter: ' . Dumper($self->{seqs}));
		} elsif ($self->expect == COLLECTION) {
			$l->logdie("-> expect COLLECTION");
		} elsif ($self->expect == PREDICATE) {
			my $ns		= $self->get_namespace( $prefix );
			my $local	= $el->{LocalName};
			my $uri		= join('', $ns, $local);
			my $node	= $self->new_resource( $uri );
			$l->trace("-> expect PREDICATE");
			
			if ($node->uri_value eq 'http://www.w3.org/1999/02/22-rdf-syntax-ns#li') {
				my $id	= ++(${ $self }{seqs}[0]);
				$node	= $self->new_resource( 'http://www.w3.org/1999/02/22-rdf-syntax-ns#_' . $id );
			}
			
			push( @{ $self->{nodes} }, $node );
			
			if (my $data = $el->{Attributes}{'{http://www.w3.org/1999/02/22-rdf-syntax-ns#}datatype'}) {
				$self->{datatype}		= $data->{Value};
			}
			
			if (my $data = $el->{Attributes}{'{http://www.w3.org/1999/02/22-rdf-syntax-ns#}ID'}) {
				my $id	= $data->{Value};
				unshift(@{ $self->{reify_id} }, $id);
			} else {
				unshift(@{ $self->{reify_id} }, undef);
			}
			
			if (my $pt = $el->{Attributes}{'{http://www.w3.org/1999/02/22-rdf-syntax-ns#}parseType'}) {
				if ($pt->{Value} eq 'Resource') {
					# fake an enclosing object scope
					my $node	= $self->new_bnode;
					my $nodes	= $self->{nodes};
					push( @$nodes, $node );
					my $st	= RDF::Trine::Statement->new( @{ $nodes }[ $#{$nodes} - 2 .. $#{$nodes} ] );
					$self->assert( $st );
					
					$self->new_expect( PREDICATE );
				} elsif ($pt->{Value} eq 'Literal') {
					$self->{datatype}		= 'http://www.w3.org/1999/02/22-rdf-syntax-ns#XMLLiteral';
					my $depth				= $self->{depth};
					$self->{literal_depth}	= $depth - 1;
					$self->new_expect( LITERAL );
				} elsif ($pt->{Value} eq 'Collection') {
					my $depth				= $self->{depth};
					
					unshift( @{ $self->{ collection_head } }, undef );
					unshift( @{ $self->{ collection_last } }, undef );
					$self->new_expect( COLLECTION );
					$self->new_expect( OBJECT );
				}
			} elsif (my $data = $el->{Attributes}{'{http://www.w3.org/1999/02/22-rdf-syntax-ns#}resource'}) {
				# stash the uri away so that we can use it when we get the end_element call for this predicate
				my $uri	= $self->new_resource( $data->{Value} );
				$self->parse_literal_property_attributes( $el, $uri );
				$self->{'rdf:resource'}	= $uri;
				$self->new_expect( OBJECT );
				$self->{chars_ok}	= 1;
			} elsif (my $ndata = $el->{Attributes}{'{http://www.w3.org/1999/02/22-rdf-syntax-ns#}nodeID'}) {
				my $node_name	= $ndata->{Value};
				# stash the bnode away so that we can use it when we get the end_element call for this predicate
				my $bnode	= $self->get_named_bnode( $node_name );
				$self->parse_literal_property_attributes( $el, $uri );
				$self->{'rdf:resource'}	= $bnode;	# the key 'rdf:resource' is a bit misused here, but both rdf:resource and rdf:nodeID use it for the same purpose, so...
				$self->new_expect( OBJECT );
				$self->{chars_ok}	= 1;
			} elsif (my $node = $self->parse_literal_property_attributes( $el )) {
				# fake an enclosing object scope
				my $nodes	= $self->{nodes};
				push( @$nodes, $node );
				my $st	= RDF::Trine::Statement->new( @{ $nodes }[ $#{$nodes} - 2 .. $#{$nodes} ] );
				$self->assert( $st );
				
				$self->new_expect( PREDICATE );
			} else {
				$self->new_expect( OBJECT );
				$self->{chars_ok}	= 1;
			}
		} elsif ($self->expect == LITERAL) {
			my $tag;
			if ($el->{Prefix}) {
				$tag	= join(':', @{ $el }{qw(Prefix LocalName)});
			} else {
				$tag	= $el->{LocalName};
			}
			$self->{characters}	.= '<' . $tag;
			my $attr	= $el->{Attributes};
			
			if (my $ns = $el->{NamespaceURI}) {
				my $abbr = $el->{Prefix};
				unless ($self->{defined_literal_namespaces}{$abbr}{$ns}) {
					$self->{characters}	.= ' xmlns';
					if (length($abbr)) {
						$self->{characters}	.= ':' . $abbr;
					}
					$self->{characters}	.= '="' . $ns . '"';
					$self->{defined_literal_namespaces}{$abbr}{$ns}++;
				}
			}
			if (%$attr) {
				foreach my $k (keys %$attr) {
					$self->{characters}	.= ' ';
					my $el	= $attr->{ $k };
					my $prop;
					if ($el->{Prefix}) {
						$prop	= join(':', @{ $el }{qw(Prefix LocalName)});
					} else {
						$prop	= $el->{LocalName};
					}
					$self->{characters}	.= $prop . '="' . $el->{Value} . '"';
				}
			}
			$self->{characters}	.= '>';
		} else {
			die "not sure what type of token is expected";
		}
# 		warn "GOT: $uri\n";
		
# 		warn 'start_element: ' . Dumper($el);
# 		warn 'namespaces: ' . Dumper($self->{_namespaces});
	}
}

=item C<< end_element >>

=cut

sub end_element {
	my $self	= shift;
	my $el		= shift;
	$self->{depth}--;
	my $l		= Log::Log4perl->get_logger("rdf.trine.parser.rdfxml");
	$l->trace("($self->{depth}) end_element " . $el->{Name});
	
	my $cleanup	= 0;
	my $expect	= $self->expect;
	if ($expect == SUBJECT) {
		$l->trace("-> expect SUBJECT");
		$self->old_expect;
		$cleanup	= 1;
		$self->{chars_ok}	= 0;
		shift(@{ $self->{reify_id} });
	} elsif ($expect == PREDICATE) {
		$l->trace("-> expect PREDICATE");
		$self->old_expect;
		if ($self->expect == PREDICATE) {
			# we're closing a parseType=Resource block, so take off the extra implicit node.
			pop( @{ $self->{nodes} } );
		} else {
			$l->trace('shifting seq counter: ' . Dumper($self->{seqs}));
			shift(@{ $self->{seqs} });
		}
		$cleanup	= 1;
		$self->{chars_ok}	= 0;
	} elsif ($expect == OBJECT or ($expect == LITERAL and $self->{literal_depth} == $self->{depth})) {
		if (exists $self->{'rdf:resource'}) {
			$l->trace("-> predicate used rdf:resource or rdf:nodeID\n");
			my $uri	= delete $self->{'rdf:resource'};
			my $nodes	= $self->{nodes};
			my $st		= RDF::Trine::Statement->new( @{ $nodes }[ $#{$nodes} - 1, $#{$nodes} ], $uri );
			delete $self->{characters};
			$self->assert( $st );
		}
		
		$l->trace("-> expect OBJECT");
		$self->old_expect;
		if (defined($self->{characters})) {
			my $string	= $self->{characters};
			my $literal	= $self->new_literal( $string );
			$l->trace('node stack: ' . Dumper($self->{nodes}));
			my $nodes	= $self->{nodes};
			my $st		= RDF::Trine::Statement->new( @{ $nodes }[ $#{$nodes} - 1, $#{$nodes} ], $literal );
			$self->assert( $st );
			delete($self->{characters});
			delete $self->{datatype};
			delete $self->{defined_literal_namespaces};
		}
		
		if ($self->expect == COLLECTION) {
			# We were expecting an object, but got an end_element instead.
			# after poping the OBJECT expectation, we see we were expecting objects in a COLLECTION.
			# so we're ending the COLLECTION here:
			$self->old_expect;
			my $nodes	= $self->{nodes};
			my $head	= $self->{ collection_head }[0] || $rdf->nil;
			my @nodes	= (@{ $nodes }[ $#{$nodes} - 1, $#{$nodes} ], $head);
			my $st		= RDF::Trine::Statement->new( @nodes );
			$self->assert( $st );
			
			if (my $last = $self->{ collection_last }[0]) {
				my @nodes	= ( $last, $rdf->rest, $rdf->nil );
				my $st		= RDF::Trine::Statement->new( @nodes );
				$self->assert( $st );
			}
			
			shift( @{ $self->{ collection_last } } );
			shift( @{ $self->{ collection_head } } );
		}
		
		$cleanup	= 1;
		$self->{chars_ok}	= 0;
		shift(@{ $self->{reify_id} });
	} elsif ($expect == COLLECTION) {
		shift( @{ $self->{collections} } );
		$self->old_expect;
		$l->trace("-> expect COLLECTION");
	} elsif ($expect == LITERAL) {
		my $tag;
		if ($el->{Prefix}) {
			$tag	= join(':', @{ $el }{qw(Prefix LocalName)});
		} else {
			$tag	= $el->{LocalName};
		}
		$self->{characters}	.= '</' . $tag . '>';
		$cleanup	= 0;
	} else {
		die "how did we get here?";
	}
	
	if ($cleanup) {
		pop( @{ $self->{nodes} } );
		$self->pop_namespace_pad();
		$self->pop_language();
		$self->pop_base();
	}
}

sub characters {
	my $self	= shift;
	my $data	= shift;
	my $expect	= $self->expect;
	my $l		= Log::Log4perl->get_logger("rdf.trine.parser.rdfxml");
	if ($expect == LITERAL or ($expect == OBJECT and $self->{chars_ok})) {
		$l->trace("got character data ($expect): <<$data->{Data}>>\n");
		my $chars	= $data->{Data};
		$self->{characters}	.= $chars;
	}
}

sub parse_literal_property_attributes {			
	my $self	= shift;
	my $el		= shift;
	my $node_id	= shift || $self->new_bnode;
	my @keys	= grep { not(m<[{][}](xmlns|about)>) }
					grep { not(m<[{]http://www.w3.org/1999/02/22-rdf-syntax-ns#[}](resource|about|ID|datatype|nodeID)>) }
					grep { not(m<[{]http://www.w3.org/XML/1998/namespace[}](base|lang)>) }
					keys %{ $el->{Attributes} };
	my $asserted	= 0;
	
	unshift(@{ $self->{reify_id} }, undef);	# don't reify any of these triples
	foreach my $k (@keys) {
		my $data = $el->{Attributes}{ $k };
		my $ns		= $data->{NamespaceURI};
		unless ($ns) {
			my $prefix	= $data->{Prefix};
			next unless (length($ns));
			$ns			= $self->get_namespace( $prefix );
		}
		next if ($ns eq 'http://www.w3.org/XML/1998/namespace');
		next if ($ns eq 'http://www.w3.org/2000/xmlns/');
		my $local	= $data->{LocalName};
		my $uri		= join('', $ns, $local);
		my $value	= $data->{Value};
		my $pred	= $self->new_resource( $uri );
		if ($uri eq 'http://www.w3.org/1999/02/22-rdf-syntax-ns#type') {
			# rdf:type is a special case -- it produces a resource instead of a literal
			my $res		= $self->new_resource( $value );
			my $st		= RDF::Trine::Statement->new( $node_id, $pred, $res );
			$self->assert( $st );
		} else {
			my $lit		= $self->new_literal( $value );
			my $st		= RDF::Trine::Statement->new( $node_id, $pred, $lit );
			$self->assert( $st );
		}
		$asserted++;
	}
	shift(@{ $self->{reify_id} });
	return ($asserted ? $node_id : 0);
}

sub set_handler {
	my $self	= shift;
	my $handler	= shift;
	$self->{sthandler}	= $handler;
}

sub assert {
	my $self	= shift;
	my $st		= shift;
	my $l		= Log::Log4perl->get_logger("rdf.trine.parser.rdfxml");
	$l->debug('[rdfxml parser] ' . $st->as_string);
	
	if ($self->{sthandler}) {
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
		
		$self->{sthandler}->( $st );
		if (defined(my $id = $self->{reify_id}[0])) {
			my $stid	= $self->new_resource( "#$id" );
			
			my $tst	= RDF::Trine::Statement->new( $stid, $rdf->type, $rdf->Statement );
			my $sst	= RDF::Trine::Statement->new( $stid, $rdf->subject, $st->subject );
			my $pst	= RDF::Trine::Statement->new( $stid, $rdf->predicate, $st->predicate );
			my $ost	= RDF::Trine::Statement->new( $stid, $rdf->object, $st->object );
			foreach ($tst, $sst, $pst, $ost) {
				$self->{sthandler}->( $_ );
			}
			$self->{reify_id}[0]	= undef;	# now that we've used this reify ID, get rid of it (because we don't want it used again)
		}
	}
}

sub node_id {
	my $self	= shift;
	my $el		= shift;
	
	if ($el->{Attributes}{'{http://www.w3.org/1999/02/22-rdf-syntax-ns#}about'}) {
		my $uri	= $el->{Attributes}{'{http://www.w3.org/1999/02/22-rdf-syntax-ns#}about'}{Value};
		return $self->new_resource( $uri );
	} elsif ($el->{Attributes}{'{http://www.w3.org/1999/02/22-rdf-syntax-ns#}ID'}) {
		my $uri	= $el->{Attributes}{'{http://www.w3.org/1999/02/22-rdf-syntax-ns#}ID'}{Value};
		return $self->new_resource( '#' . $uri );
	} elsif ($el->{Attributes}{'{http://www.w3.org/1999/02/22-rdf-syntax-ns#}nodeID'}) {
		my $name	= $el->{Attributes}{'{http://www.w3.org/1999/02/22-rdf-syntax-ns#}nodeID'}{Value};
		return $self->get_named_bnode( $name );
	} else {
		return $self->new_bnode;
	}
}

sub handle_scoped_values {
	my $self	= shift;
	my $el		= shift;
	my %new;
	
	{
		# xml:base
		my $base	= '';
		if (exists($el->{Attributes}{'{http://www.w3.org/XML/1998/namespace}base'})) {
			my $uri	= $el->{Attributes}{'{http://www.w3.org/XML/1998/namespace}base'}{Value};
			$base	= $self->new_resource( $uri );
		}
		$self->push_base( $base );
	}
	
	{
		# language
		my $lang	= '';
		if (exists($el->{Attributes}{'{http://www.w3.org/XML/1998/namespace}lang'})) {
			$lang	= $el->{Attributes}{'{http://www.w3.org/XML/1998/namespace}lang'}{Value};
		}
		$self->push_language( $lang );
	}
	
	{
		# namespaces
		my @ns		= grep { m<^[{]http://www.w3.org/2000/xmlns/[}]> } (keys %{ $el->{Attributes} });
		foreach my $n (@ns) {
			my ($prefix)	= substr($n, 31);
			my $value		= $el->{Attributes}{$n}{Value};
			$new{ $prefix }	= $value;
			if (blessed(my $ns = $self->{namespaces})) {
				unless ($ns->namespace_uri($prefix)) {
					$ns->add_mapping( $prefix => $value );
				}
			}
		}
		
		if (exists($el->{Attributes}{'{}xmlns'})) {
			my $value		= $el->{Attributes}{'{}xmlns'}{Value};
			$new{ '' }		= $value;
		}
		
		$self->push_namespace_pad( \%new );
	}
}

sub push_base {
	my $self	= shift;
	my $base	= shift;
	if ($base) {
		my $uri		= (blessed($base) and $base->isa('URI')) ? $base : new URI ($base->uri_value );
		$uri->fragment( undef );
		$base	= RDF::Trine::Node::Resource->new( "$uri" );
	}
	unshift( @{ $self->{base} }, $base );
}

sub pop_base {
	my $self	= shift;
	shift( @{ $self->{base} } );
}

sub get_base {
	my $self	= shift;
	foreach my $level (0 .. $#{ $self->{base} }) {
		my $base		= $self->{base}[ $level ];
		if (length($base)) {
			return $base;
		}
	}
	return ();
}

sub push_language {
	my $self	= shift;
	my $lang	= shift;
	unshift( @{ $self->{language} }, $lang );
}

sub pop_language {
	my $self	= shift;
	shift( @{ $self->{language} } );
}

sub get_language {
	my $self	= shift;
	foreach my $level (0 .. $#{ $self->{language} }) {
		my $lang		= $self->{language}[ $level ];
		if (length($lang)) {
			return $lang;
		}
	}
	return '';
}

sub push_namespace_pad {
	my $self	= shift;
	my $pad		= shift;
	unshift( @{ $self->{_namespaces} }, $pad );
}

sub pop_namespace_pad {
	my $self	= shift;
	shift( @{ $self->{_namespaces} } );
}

sub get_namespace {
	my $self	= shift;
	my $prefix	= shift;
	foreach my $level (0 .. $#{ $self->{_namespaces} }) {
		my $pad		= $self->{_namespaces}[ $level ];
		if (exists($pad->{ $prefix })) {
			my $uri		= $pad->{ $prefix };
			return $uri;
		}
	}
	throw RDF::Trine::Error::ParserError -text => "Unknown namespace: $prefix";
}

sub new_bnode {
	my $self	= shift;
	if (my $prefix = $self->{prefix}) {
		my $id	= $prefix . ++$self->{counter};
		return RDF::Trine::Node::Blank->new( $id );
	} else {
		return RDF::Trine::Node::Blank->new();
	}
}

sub new_literal {
	my $self	= shift;
	my $string	= shift;
	my @args	= (undef, undef);
	if (my $dt = $self->{datatype}) {	# datatype
		$args[1]	= $dt;
		if ($dt eq 'http://www.w3.org/1999/02/22-rdf-syntax-ns#XMLLiteral') {
			if ($HAS_XML_LIBXML) {
				eval {
					if ($string =~ m/^</) {
						my $doc 	= XML::LibXML->load_xml(string => $string);
						my $canon	= $doc->toStringEC14N(1);
						$string	= $canon;
					}
				};
				if ($@) {
					warn "Cannot canonicalize XMLLiteral: $@" . Dumper($string);
				}
			}
		}
	} elsif (my $lang = $self->get_language) {
		$args[0]	= $lang;
	}
	my $literal	= RDF::Trine::Node::Literal->new( $string, @args );
}

sub new_resource {
	my $self	= shift;
	my $uri		= shift;
	my @base	= $self->get_base;
	my $res		= RDF::Trine::Node::Resource->new( $uri, @base );
	return $res;
}

sub get_named_bnode {
	my $self	= shift;
	my $name	= shift;
	return ($self->{named_bnodes}{ $name } ||= $self->new_bnode);
}

1;

__END__

=end private

=back

=head1 BUGS

Please report any bugs or feature requests to through the GitHub web interface
at L<https://github.com/kasei/perlrdf/issues>.

=head1 SEE ALSO

L<http://www.w3.org/TR/rdf-syntax-grammar/>

=head1 AUTHOR

Gregory Todd Williams  C<< <gwilliams@cpan.org> >>

=head1 COPYRIGHT

Copyright (c) 2006-2012 Gregory Todd Williams. This
program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
