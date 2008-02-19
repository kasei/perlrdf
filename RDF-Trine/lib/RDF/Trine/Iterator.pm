# RDF::Trine::Iterator
# -------------
# $Revision $
# $Date $
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Iterator - Stream (iterator) class for SPARQL query results.

=head1 VERSION

This document describes RDF::Trine::Iterator version 1.000.


=head1 SYNOPSIS

    use RDF::Trine::Iterator;
    my $iterator = RDF::Trine::Iterator->new( \&data, 'bindings', \@names );
    while (my $row = $iterator->next) {
    	my @vars	= keys %$row;
    	# do something with @vars
    }

=head1 METHODS

=over 4

=cut

package RDF::Trine::Iterator;

use strict;
use warnings;
no warnings 'redefine';

use JSON;
use XML::Twig;
use Data::Dumper;
use Carp qw(carp);
use List::MoreUtils qw(uniq);
use Scalar::Util qw(blessed reftype);

use RDF::Trine::Node;

our ($REVISION, $VERSION, $debug, @ISA, @EXPORT_OK);
use constant DEBUG	=> 0;
BEGIN {
	$debug		= DEBUG;
	$REVISION	= do { my $REV = (qw$Revision: 293 $)[1]; sprintf("%0.3f", 1 + ($REV/1000)) };
	$VERSION	= '1.000';
	
	require Exporter;
	@ISA		= qw(Exporter);
	@EXPORT_OK	= qw(sgrep smap swatch);
	use overload 'bool' => sub { $_[0] };
	use overload '&{}' => sub {
		my $self	= shift;
		return sub {
			return $self->next;
		};
	};
}

use RDF::Trine::Iterator::Bindings;
use RDF::Trine::Iterator::Boolean;
use RDF::Trine::Iterator::Graph;

=item C<new ( \@results, $type, \@names, %args )>

=item C<new ( \&results, $type, \@names, %args )>

Returns a new SPARQL Result interator object. Results must be either
an reference to an array containing results or a CODE reference that
acts as an iterator, returning successive items when called, and
returning undef when the iterator is exhausted.

$type should be one of: bindings, boolean, graph.

=cut

sub new {
	my $proto		= shift;
	my $class		= ref($proto) || $proto;
	my $stream		= shift || sub { undef };
	my $type		= shift || 'bindings';
	my $names		= shift || [];
	my %args		= @_;
	
	if (ref($stream) and reftype($stream) eq 'ARRAY') {
		my $array	= $stream;
		$stream	= sub {
			return shift(@$array);
		}
	}
	
	my $open		= 0;
	my $finished	= 0;
	my $row;
	
	my $data	= {
		_open		=> 0,
		_finished	=> 0,
		_type		=> $type,
		_names		=> $names,
		_stream		=> $stream,
		_args		=> \%args,
		_row		=> undef,
#		_source		=> Carp::longmess(),
	};
	
	my $self	= bless($data, $class);
	return $self;
}

=item C<type>

Returns the underlying result type (boolean, graph, bindings).

=cut

sub type {
	my $self			= shift;
	return $self->{_type};
}

=item C<is_boolean>

Returns true if the underlying result is a boolean value.

=item C<is_bindings>

Returns true if the underlying result is a set of variable bindings.

=item C<is_graph>

Returns true if the underlying result is an RDF graph.

=cut

sub is_boolean { 0 }
sub is_bindings { 0 }
sub is_graph { 0 }



=item C<to_string ( $format )>

Returns a string representation of the stream data in the specified
C<$format>. If C<$format> is missing, defaults to XML serialization.
Other options are:

  http://www.w3.org/2001/sw/DataAccess/json-sparql/

=cut

sub to_string {
	my $self	= shift;
	my $format	= shift || 'http://www.w3.org/2001/sw/DataAccess/rf1/result2';
	if (ref($format) and $format->isa('RDF::Redland::URI')) {
		$format	= $format->as_string;
	}
	
	if ($format eq 'http://www.w3.org/2001/sw/DataAccess/json-sparql/') {
		return $self->as_json;
	} else {
		return $self->as_xml;
	}
}

=item C<from_string ( $xml )>

Returns a new iterator using the supplied XML in the SPARQL XML Results format.

=cut

sub from_string {
	my $class	= shift;
	my $string	= shift;
	
	my $bool;
	my @vars;
	my $value;
	my @results;
	my $result	= {};
	
	my $twig	= XML::Twig->new(
		twig_handlers => {
			variable	=> sub { push(@vars, $_->att('name')) },
			binding		=> sub { $result->{ $_->att('name') }	= $value; },
			result		=> sub { push(@results, $result); $result	= {}; },
			bnode		=> sub { $value	= RDF::Trine::Node::Blank->new( $_->text ) },
			uri			=> sub { $value	= RDF::Trine::Node::Resource->new( $_->text ) },
			literal		=> sub {
							my $lang	= $_->att('xml:lang');
							my $dt		= $_->att('datatype');
							$value	= RDF::Trine::Node::Literal->new( $_->text, $lang, $dt )
						},
			boolean		=> sub { $bool	= ($_->text eq 'true') ? 1 : 0 },
		},
	);
	$twig->parse( $string );
	
	if (defined($bool)) {
		return RDF::Trine::Iterator::Boolean->new( [$bool] );
	} else {
		return RDF::Trine::Iterator::Bindings->new( \@results, \@vars );
	}
}

=item C<< next >>

=item C<< next_result >>

Returns the next item in the stream.

=cut

sub next { $_[0]->next_result }
sub next_result {
	my $self	= shift;
	return if ($self->{_finished});
	
	my $stream	= $self->{_stream};
	my $value	= $stream->();
	unless (defined($value)) {
		$self->{_finished}	= 1;
	}

	my $args	= $self->_args;
# 	if ($args->{named}) {
# 		if ($self->_bridge->supports('named_graph')) {
# 			my $bridge	= $self->_bridge;
# 			$args->{context}	= $bridge->get_context( $self->{_stream}, %$args );
# 		}
# 	}
	
	$self->{_open}	= 1;
	$self->{_row}	= $value;
	return $value;
}


=item C<< current >>

Returns the current item in the stream.

=cut

sub current {
	my $self	= shift;
	if ($self->open) {
		return $self->_row;
	} else {
		return $self->next;
	}
}

=item C<< end >>

=item C<< finished >>

Returns true if the end of the stream has been reached, false otherwise.

=cut

sub end { $_[0]->finished }
sub finished {
	my $self	= shift;
	return $self->{_finished};
}

=item C<< open >>

Returns true if the first element of the stream has been retrieved, false otherwise.

=cut

sub open {
	my $self	= shift;
	return $self->{_open};
}

=item C<< close >>

Closes the stream. Future attempts to retrieve data from the stream will act as
if the stream had been exhausted.

=cut

sub close {
	my $self			= shift;
	$self->{_finished}	= 1;
	undef( $self->{ _stream } );
	return;
}

# =item C<< context >>
# 
# Returns the context node of the current result (if applicable).
# 
# =cut
# 
# sub context {
# 	my $self	= shift;
# 	my $args	= $self->_args;
# 	my $bridge	= $args->{bridge};
# 	my $stream	= $self->{_stream};
# 	my $context	= $bridge->get_context( $stream, %$args );
# 	return $context;
# }


=item C<< concat ( $stream ) >>

Returns a new stream resulting from the concatenation of the referant and the
argument streams. The new stream uses the stream type, and optional binding
names and C<<%args>> from the referant stream.

=cut

sub concat {
	my $self	= shift;
	my $stream	= shift;
	my @args	= $stream->construct_args();
	my $class	= ref($self);
	my @streams	= ($self, $stream);
	my $next	= sub {
		while (@streams) {
			my $data	= $streams[0]->next;
			unless (defined($data)) {
				shift(@streams);
				next;
			}
			return $data;
		}
		return;
	};
	my $s	= $stream->_new( $next, @args );
	return $s;
}


=item C<get_boolean>

Returns the boolean value of the first item in the stream.

=cut

sub get_boolean {
	my $self	= shift;
	my $data	= $self->next_result;
	return +$data;
}

=item C<get_all>

Returns an array containing all the items in the stream.

=cut

sub get_all {
	my $self	= shift;
	
	my @data;
	while (my $data = $self->next) {
		push(@data, $data);
	}
	return @data;
}

=item C<< join_streams ( $stream, $stream ) >>

Performs a natural, nested loop join of the two streams, returning a new stream
of joined results.

=cut

sub join_streams {
	my $self	= shift;
	my $astream	= shift;
	my $bstream	= shift;
#	my $bridge	= shift;
	my %args	= @_;
	
#	my $debug	= $args{debug};
	
	Carp::confess unless ($astream->isa('RDF::Trine::Iterator::Bindings'));
	Carp::confess unless ($bstream->isa('RDF::Trine::Iterator::Bindings'));
	
	my @names	= uniq( map { $_->binding_names() } ($astream, $bstream) );
	my $a		= $astream->project( @names );
	my $b		= $bstream->project( @names );
	
	my @results;
	my @data	= $b->get_all();
	no warnings 'uninitialized';
	while (my $rowa = $a->next) {
		LOOP: foreach my $rowb (@data) {
			warn "[--JOIN--] " . join(' ', map { my $row = $_; '{' . join(', ', map { join('=',$_,$row->{$_}->as_string) } (keys %$row)) . '}' } ($rowa, $rowb)) . "\n" if ($debug);
			my %keysa	= map {$_=>1} (keys %$rowa);
			my @shared	= grep { $keysa{ $_ } } (keys %$rowb);
			foreach my $key (@shared) {
				my $val_a	= $rowa->{ $key };
				my $val_b	= $rowb->{ $key };
				my $defined	= 0;
				foreach my $n ($val_a, $val_b) {
					$defined++ if (defined($n));
				}
				if ($defined == 2) {
					unless ($val_a->equal($val_b)) {
						warn "can't join because mismatch of $key (" . join(' <==> ', map {$_->as_string} ($val_a, $val_b)) . ")" if ($debug);
						next LOOP;
					}
				}
			}
			
			my $row	= { (map { $_ => $rowa->{$_} } grep { defined($rowa->{$_}) } keys %$rowa), (map { $_ => $rowb->{$_} } grep { defined($rowb->{$_}) } keys %$rowb) };
			if ($debug) {
				warn "JOINED:\n";
				foreach my $key (keys %$row) {
					warn "$key\t=> " . $row->{ $key }->as_string . "\n";
				}
			}
			push(@results, $row);
		}
	}
	
	my $args	= $astream->_args;
	return $astream->_new( \@results, 'bindings', \@names, %$args );
}





=begin private

=item C<format_node_xml ( $node, $name )>

Returns a string representation of C<$node> for use in an XML serialization.

=end private

=cut

sub format_node_xml ($$$$) {
	my $self	= shift;
# 	my $bridge	= shift;
# 	return undef unless ($bridge);
	
	my $node	= shift;
	my $name	= shift;
	my $node_label;
	
	if(!defined $node) {
		$node_label	= "<unbound/>";
	} elsif ($node->is_resource) {
		$node_label	= $node->uri_value;
		$node_label	=~ s/&/&amp;/g;
		$node_label	=~ s/</&lt;/g;
		$node_label	=~ s/"/&quot;/g;
		$node_label	= qq(<uri>${node_label}</uri>);
	} elsif ($node->is_literal) {
		$node_label	= $node->literal_value;
		$node_label	=~ s/&/&amp;/g;
		$node_label	=~ s/</&lt;/g;
		$node_label	=~ s/"/&quot;/g;
		$node_label	= qq(<literal>${node_label}</literal>);
	} elsif ($node->is_blank) {
		$node_label	= $node->blank_identifier;
		$node_label	=~ s/&/&amp;/g;
		$node_label	=~ s/</&lt;/g;
		$node_label	=~ s/"/&quot;/g;
		$node_label	= qq(<bnode>${node_label}</bnode>);
	} else {
		$node_label	= "<unbound/>";
	}
	return qq(<binding name="${name}">${node_label}</binding>);
}

=item C<< construct_args >>

Returns the arguments necessary to pass to a stream constructor
to re-create this stream (assuming the same closure as the first
argument).

=cut

sub construct_args {
	my $self	= shift;
	my $type	= $self->type;
	my $args	= $self->_args || {};
	return ($type, []);
}

=begin private

=item C<< debug >>

Prints debugging information about the stream.

=end private

=cut

sub debug {
	my $self	= shift;
	my $stream	= $self->{_stream};
	RDF::Query::_debug_closure( $stream );
}

sub _args {
	my $self	= shift;
	return $self->{_args};
}

sub _row {
	my $self	= shift;
	return $self->{_row};
}

# =item C<< bridge >>
# 
# Returns the model bridge object used for insepcting the objects returned by the stream.
# 
# =cut
# 
# sub bridge {
# 	my $self	= shift;
# 	if (@_) {
# 		$self->_args->{bridge}	= shift;
# 	}
# 	return $self->_args->{bridge};
# }
# 
# sub _bridge {
# 	my $self	= shift;
# 	return $self->bridge;
# }

sub _names {
	my $self	= shift;
	return $self->{_names};
}

sub _stream {
	my $self	= shift;
	return $self->{_stream};
}






=back

=head1 FUNCTIONS

=over 4

=item C<sgrep { COND } $stream>

=cut

sub sgrep (&$) {
	my $block	= shift;
	my $stream	= shift;
	my @args	= $stream->construct_args();
	my $class	= ref($stream);
	
	my $open	= 1;
	my $next;
	
	$next	= sub {
		return undef unless ($open);
		my $data	= $stream->next;
		unless ($data) {
			$open	= 0;
			return undef;
		}
		
		local($_)	= $data;
		my $bool	= $block->( $data );
		if ($bool) {
#			warn "[SGREP] TRUE with: " . $data->as_string;
			if (@_ and $_[0]) {
				$stream->close;
				$open	= 0;
			}
			return $data;
		} else {
#			warn "[SGREP] FALSE with: " . $data->as_string;
			goto &$next;
		}
	};
	
	Carp::confess "not a stream: " . Dumper($stream) unless (blessed($stream));
	Carp::confess unless ($stream->can('_new'));
	my $s	= $stream->_new( $next, @args );
	return $s;
}

=item C<smap { EXPR } $stream>

=cut

sub smap (&$;$$$) {
	my $block	= shift;
	my $stream	= shift;
	my @args	= $stream->construct_args();
	my $class	= ref($stream);
	
	my $open	= 1;
	my $next	= sub {
		return undef unless ($open);
		if (@_ and $_[0]) {
			$stream->close;
			$open	= 0;
		}
		my $data	= $stream->next;
		unless ($data) {
			$open	= 0;
			return undef;
		}
		
		local($_)	= $data;
		my ($item)	= $block->( $data );
		return $item;
	};
	
	return $stream->_new( $next, @args );
}

=item C<swatch { EXPR } $stream>

=cut

sub swatch (&$) {
	my $block	= shift;
	my $stream	= shift;
	my @args	= $stream->construct_args();
	my $class	= ref($stream);
	
	my $open	= 1;
	my $next	= sub {
		return undef unless ($open);
		if (@_ and $_[0]) {
			$stream->close;
			$open	= 0;
		}
		my $data	= $stream->next;
		unless ($data) {
			$open	= 0;
			return undef;
		}
		
		local($_)	= $data;
		$block->( $data );
		return $data;
	};
	
	my $s		= $stream->_new( $next, @args );
	return $s;
}

1;

__END__

=back

=head1 DEPENDENCIES

L<JSON|JSON>

L<Scalar::Util|Scalar::Util>


=head1 AUTHOR

Gregory Todd Williams  C<< <greg@evilfunhouse.com> >>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2007, Gregory Todd Williams C<< <gwilliams@cpan.org> >>. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.


