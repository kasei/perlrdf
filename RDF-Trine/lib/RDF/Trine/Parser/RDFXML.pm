# RDF::Trine::Parser::RDFXML
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Parser::RDFXML - RDF/XML Parser.

=head1 VERSION

This document describes RDF::Trine::Parser::RDFXML version 0.108

=head1 SYNOPSIS

 use RDF::Trine::Parser;
 my $parser	= RDF::Trine::Parser->new( 'rdfxml' );
 my $iterator = $parser->parse( $base_uri, $data );

=head1 DESCRIPTION

...

=head1 METHODS

=over 4

=cut

package RDF::Trine::Parser::RDFXML;

use strict;
use warnings;

use URI;
use Carp;
use XML::SAX;
use Data::Dumper;
use Scalar::Util qw(blessed);

use RDF::Trine::Node;
use RDF::Trine::Statement;
use RDF::Trine::Parser::Error qw(:try);

######################################################################

our ($VERSION, $debug);
BEGIN {
	$debug		= 0;
	$VERSION	= 0.108;
	foreach my $t ('rdfxml', 'application/rdf+xml') {
		$RDF::Trine::Parser::types{ $t }	= __PACKAGE__;
	}
}

######################################################################

=item C<< new >>

=cut

sub new {
	my $class	= shift;
	my %args	= @_;
	$class = ref($class) || $class;
	my $saxhandler	= RDF::Trine::Parser::RDFXML::SAXHandler->new( %args );
	my $p		= XML::SAX::ParserFactory->parser(Handler => $saxhandler);
	
	my $self = bless( {
		saxhandler	=> $saxhandler,
		parser		=> $p,
	}, $class);
	return $self;
}

=item C<< parse_into_model ( $base_uri, $data, $model ) >>

Parses the C<< $data >>, using the given C<< $base_uri >>. For each RDF triple
parsed, will call C<< $model->add_statement( $statement ) >>.

=cut

sub parse_into_model {
	my $self	= shift;
	my $uri		= shift;
	if (blessed($uri) and $uri->isa('RDF::Trine::Node::Resource')) {
		$uri	= $uri->uri_value;
	}
	my $input	= shift;
	my $model	= shift;
	my $handler	= sub { my $st	= shift; $model->add_statement( $st ) };
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
	if ($base) {
		unless (blessed($base)) {
			$base	= RDF::Trine::Node::Resource->new( $base );
		}
		$self->{saxhandler}->push_base( $base );
	}
	
	if ($handler) {
		$self->{saxhandler}->set_handler( $handler );
	}
	
	if (ref($string)) {
		$self->{parser}->parse_file( $string );
	} else {
		$self->{parser}->parse_string( $string );
	}
	my $nodes	= $self->{saxhandler}{nodes};
	if ($nodes and scalar(@$nodes)) {
		warn Dumper($nodes);
		die "node stack isn't empty after parse";
	}
	my $expect	= $self->{saxhandler}{expect};
	if ($expect and scalar(@$expect) > 2) {
		warn Dumper($expect);
		die "expect stack isn't empty after parse";
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
	my $prefix	= $args{ BNodePrefix } || '';
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
	warn 'start_element ' . $el->{Name} if ($debug);
	
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
			warn "-> expect SUBJECT or OBJECT" if ($debug);
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
				warn "adding an OBJECT to a COLLECTION " . $list->sse . "\n" if ($debug);
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
				warn "got rdf:Description of " . $node_id->as_string if ($debug);
			} else {
				my $type	= $node;
				warn "got object node " . $node_id->as_string . " of type " . $node->as_string if ($debug);
				# emit an rdf:type statement
				my $st	= RDF::Trine::Statement->new( $node_id, $rdf->type, $node );
				$self->assert( $st );
			}
			push( @{ $self->{nodes} }, $node_id );
			
			$self->parse_literal_property_attributes( $el, $node_id );
			$self->new_expect( PREDICATE );
			unshift(@{ $self->{seqs} }, 0);
			warn 'unshifting seq counter: ' . Dumper($self->{seqs}) if ($debug);
		} elsif ($self->expect == COLLECTION) {
			warn "-> expect COLLECTION" if ($debug);
			die;
		} elsif ($self->expect == PREDICATE) {
			my $ns		= $self->get_namespace( $prefix );
			my $local	= $el->{LocalName};
			my $uri		= join('', $ns, $local);
			my $node	= $self->new_resource( $uri );
			warn "-> expect PREDICATE" if ($debug);
			
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
# 		warn 'namespaces: ' . Dumper($self->{namespaces});
	}
}

=item C<< end_element >>

=cut

sub end_element {
	my $self	= shift;
	my $el		= shift;
	$self->{depth}--;
	warn "($self->{depth}) end_element " . $el->{Name} if ($debug);
	
	my $cleanup	= 0;
	my $expect	= $self->expect;
	if ($expect == SUBJECT) {
		warn "-> expect SUBJECT" if ($debug);
		$self->old_expect;
		$cleanup	= 1;
		$self->{chars_ok}	= 0;
		shift(@{ $self->{reify_id} });
	} elsif ($expect == PREDICATE) {
		warn "-> expect PREDICATE" if ($debug);
		$self->old_expect;
		if ($self->expect == PREDICATE) {
			# we're closing a parseType=Resource block, so take off the extra implicit node.
			pop( @{ $self->{nodes} } );
		} else {
			warn 'shifting seq counter: ' . Dumper($self->{seqs}) if ($debug);
			shift(@{ $self->{seqs} });
		}
		$cleanup	= 1;
		$self->{chars_ok}	= 0;
	} elsif ($expect == OBJECT or ($expect == LITERAL and $self->{literal_depth} == $self->{depth})) {
		if (exists $self->{'rdf:resource'}) {
			warn "-> predicate used rdf:resource or rdf:nodeID\n" if ($debug);
			my $uri	= delete $self->{'rdf:resource'};
			my $nodes	= $self->{nodes};
			my $st		= RDF::Trine::Statement->new( @{ $nodes }[ $#{$nodes} - 1, $#{$nodes} ], $uri );
			delete $self->{characters};
			$self->assert( $st );
		}
		
		warn "-> expect OBJECT" if ($debug);
		$self->old_expect;
		if (defined($self->{characters})) {
			my $string	= $self->{characters};
			my $literal	= $self->new_literal( $string );
			if ($debug) {
				Carp::cluck "new literal: " . $literal->as_string;
				warn 'node stack: ' . Dumper($self->{nodes});
			}
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
		warn "-> expect COLLECTION" if ($debug);
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
	if ($expect == LITERAL or ($expect == OBJECT and $self->{chars_ok})) {
		warn "got character data ($expect): <<$data->{Data}>>\n" if ($debug);
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
	if ($debug) {
		warn '[rdfxml parser] ' . $st->as_string . "\n";
	}
	
	if ($self->{sthandler}) {
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
	unshift( @{ $self->{namespaces} }, $pad );
}

sub pop_namespace_pad {
	my $self	= shift;
	shift( @{ $self->{namespaces} } );
}

sub get_namespace {
	my $self	= shift;
	my $prefix	= shift;
	foreach my $level (0 .. $#{ $self->{namespaces} }) {
		my $pad		= $self->{namespaces}[ $level ];
		if (exists($pad->{ $prefix })) {
			my $uri		= $pad->{ $prefix };
			return $uri;
		}
	}
	throw RDF::Trine::Parser::Error::ValueError -text => "Unknown namespace: $prefix";
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

=head1 AUTHOR

 Gregory Williams <gwilliams@cpan.org>

=cut

