=head1 NAME

RDF::Trine::Store::Memory - Simple in-memory RDF store

=head1 VERSION

This document describes RDF::Trine::Store::Memory version 1.012

=head1 SYNOPSIS

 use RDF::Trine::Store::Memory;

=head1 DESCRIPTION

RDF::Trine::Store::Memory provides an in-memory triple-store.

=cut

package RDF::Trine::Store::Memory;

use strict;
use warnings;
no warnings 'redefine';
use base qw(RDF::Trine::Store);

use Encode;
use Set::Scalar;
use Data::Dumper;
use Digest::SHA qw(sha1);
use List::Util qw(first);
use Scalar::Util qw(refaddr reftype blessed);
use RDF::Trine::Statement::Quad;

use RDF::Trine qw(iri);
use RDF::Trine::Error;

######################################################################

my @pos_names;
our $VERSION;
BEGIN {
	$VERSION	= "1.012";
	my $class	= __PACKAGE__;
	$RDF::Trine::Store::STORE_CLASSES{ $class }	= $VERSION;
	@pos_names	= qw(subject predicate object context);
}

######################################################################

=head1 METHODS

Beyond the methods documented below, this class inherits methods from the
L<RDF::Trine::Store> class.

=over 4

=item C<< new () >>

Returns a new memory-backed storage object.

=item C<new_with_config ( $hashref )>

Returns a new storage object configured with a hashref with certain
keys as arguments.

The C<storetype> key must be C<Memory> for this backend.

This module also supports initializing the store from a file or URL,
in which case, a C<sources> key may be used. This holds an arrayref of
hashrefs.  To load a file, you may give the file name with a C<file>
key in the hashref, and to load a URL, use C<url>. See example
below. Furthermore, the following keys may be used:

=over

=item C<syntax>

The syntax of the parsed file or URL.

=item C<base_uri>

The base URI to be used for a parsed file.

=item C<graph> NOT IMPLEMENTED

Use this URI as a graph name for the contents of the file or URL.

=back

The following example initializes a Memory store based on a local file and a remote URL:

  my $store = RDF::Trine::Store->new_with_config(
                {
                  storetype => 'Memory',
                  sources => [
                    {
                      file => 'test-23.ttl',
                      syntax => 'turtle',
                    },
                    {
                      url => 'http://www.kjetil.kjernsmo.net/foaf',
                      syntax => 'rdfxml',
                      graph => 'http://example.org/graph/remote-users'
                    }
                  ]
                });

=cut

sub new {
	my $class	= shift;
	my $self	= bless({
		size		=> 0,
		statements	=> [],
		subject		=> {},
		predicate	=> {},
		object		=> {},
		context		=> {},
		ctx_nodes	=> {},
		hash		=> Digest::SHA->new,
		statement_hashes	=> {},
	}, $class);

	return $self;
}

sub _new_with_string {
	my $class	= shift;
	my $config	= shift || '';
	my @uris	= split(';', $config);
	my $self	= $class->new();
	
	my $model	= RDF::Trine::Model->new( $self );
	foreach my $u (@uris) {
		RDF::Trine::Parser->parse_url_into_model( $u, $model );
	}
	
	return $self;
}

sub _config_meta {
	return {
		required_keys	=> []
	}
}

sub _new_with_config {
	my $class	= shift;
	my $config	= shift;
	my @sources	= @{$config->{sources}};
	my $self	= $class->new();
	foreach my $source (@sources) {
		my %args;
		if (my $g = $source->{graph}) {
			$args{context}	= (blessed($g) ? $g : iri($g));
		}
		if ($source->{url}) {
			my $parser	= RDF::Trine::Parser->new($source->{syntax});
			my $model	= RDF::Trine::Model->new( $self );
			$parser->parse_url_into_model( $source->{url}, $model, %args );
			
		} elsif ($source->{file}) {
			open(my $fh, "<:encoding(UTF-8)", $source->{file}) 
	|| throw RDF::Trine::Error -text => "Couldn't open file $source->{file}";
			my $parser = RDF::Trine::Parser->new($source->{syntax});
			my $model	= RDF::Trine::Model->new( $self );
			$parser->parse_file_into_model( $source->{base_uri}, $source->{file}, $model, %args );
		} else {
			throw RDF::Trine::Error::MethodInvocationError -text => "$class needs a url or file argument";
		}
	}
	return $self;
}



=item C<< temporary_store >>

Returns a temporary (empty) triple store.

=cut

sub temporary_store {
	my $class	= shift;
	return $class->new();
}

=item C<< get_statements ( $subject, $predicate, $object [, $context] ) >>

Returns a stream object of all statements matching the specified subject,
predicate and objects. Any of the arguments may be undef to match any value.

=cut

sub get_statements {
	my $self	= shift;
	my @nodes	= @_[0..3];
	my $bound	= 0;
	my %bound;
	
	my $use_quad	= 0;
	if (scalar(@_) >= 4) {
		$use_quad	= 1;
		my $g	= $nodes[3];
		if (blessed($g) and not($g->is_variable)) {
			$bound++;
			$bound{ 3 }	= $g;
		}
	}
	
	foreach my $pos (0 .. 2) {
		my $n	= $nodes[ $pos ];
		if (blessed($n) and not($n->is_variable)) {
			$bound++;
			$bound{ $pos }	= $n;
		}
	}
	
	my $iter	= ($use_quad)
				? $self->_get_statements_quad( $bound, %bound )
				: $self->_get_statements_triple( $bound, %bound );
	return $iter;
}

sub _get_statements_triple {
	my $self	= shift;
	my $bound	= shift;
	my %bound	= @_;
	
	my $match_set	= Set::Scalar->new( 0 .. $#{ $self->{statements} } );
	if ($bound) {
# 		warn "getting $bound-bound statements";
		my @pos		= sort { $a <=> $b } keys %bound;
		my @names	= @pos_names[ @pos ];
# 		warn "\tbound nodes are: " . join(', ', @names) . "\n";
		
		my @sets;
		foreach my $i (0 .. $#pos) {
			my $pos	= $pos[ $i ];
			my $node	= $bound{ $pos };
			my $string	= $node->as_string;
# 			warn $node . " has string: '" . $string . "'\n";
			my $hash	= $self->{$names[$i]};
			my $set		= $hash->{ $string };
			push(@sets, $set);
		}
		
		foreach my $s (@sets) {
			unless (blessed($s)) {
				return RDF::Trine::Iterator::Graph->new();
			}
		}
		
# 		warn "initial set: $i\n";
		while (@sets) {
			my $s	= shift(@sets);
# 			warn "new set: $s\n";
			$match_set	= $match_set->intersection($s);
# 			warn "intersection: $i";
		}
	}
	
	my $open	= 1;
	my %seen;
	
	my @members	= sort { $a <=> $b } $match_set->members;
	my $sub	= sub {
		while (1) {
			my $e = shift(@members);
			unless (defined($e)) {
				$open	= 0;
				return;
			}
			
			my $st		= $self->{statements}[ $e++ ];
			unless (blessed($st)) {
				next;
			}
			my @nodes	= $st->nodes;
			my $triple	= RDF::Trine::Statement->new( @nodes[0..2] );
			if ($seen{ $triple->as_string }++) {
# 				warn "already seen " . $triple->as_string . "\n" if ($::debug);
				next;
			}
#			warn "returning statement from $bound-bound iterator: " . $triple->as_string . "\n";
			return $triple;
		}
	};
	return RDF::Trine::Iterator::Graph->new( $sub );
}

sub _get_statements_quad {
	my $self	= shift;
	my $bound	= shift;
	my %bound	= @_;
	if ($bound == 0) {
# 		warn "getting all statements";
# 		warn Dumper($self);
		my $i	= 0;
		my $sub	= sub {
# 			warn "quad iter called with i=$i, last=" . $#{ $self->{statements} };
			return unless ($i <= $#{ $self->{statements} });
			my $st	= $self->{statements}[ $i ];
# 			warn $st;
			while (not(blessed($st)) and ($i <= $#{ $self->{statements} })) {
				$st	= $self->{statements}[ ++$i ];
# 				warn "null st. next: $st";
			}
			$i++;
			return $st;
		};
# 		warn "returning all quads sub $sub";
		return RDF::Trine::Iterator::Graph->new( $sub );
	}
	
	my $match_set;
	if ($bound == 1) {
# 		warn "getting 1-bound statements";
		my ($pos)		= keys %bound;
		my $name		= $pos_names[ $pos ];
# 		warn "\tbound node is $name\n";
		my $node	= $bound{ $pos };
		my $string	= $node->as_string;
		$match_set	= $self->{$name}{ $string };
# 		warn "\tmatching statements: $match_set\n";
		unless (blessed($match_set)) {
			return RDF::Trine::Iterator::Graph->new();
		}
	} else {
# 		warn "getting $bound-bound statements";
		my @pos		= keys %bound;
		my @names	= @pos_names[ @pos ];
# 		warn "\tbound nodes are: " . join(', ', @names) . "\n";
		
		my @sets;
		foreach my $i (0 .. $#pos) {
			my $pos	= $pos[ $i ];
			my $node	= $bound{ $pos };
			my $string	= $node->as_string;
# 			warn $node . " has string: '" . $string . "'\n";
			my $hash	= $self->{$names[$i]};
			my $set		= $hash->{ $string };
			push(@sets, $set);
		}
		
		foreach my $s (@sets) {
			unless (blessed($s)) {
				return RDF::Trine::Iterator::Graph->new();
			}
		}
		my $i	= shift(@sets);
# 		warn "initial set: $i\n";
		while (@sets) {
			my $s	= shift(@sets);
# 			warn "new set: $s\n";
			$i	= $i->intersection($s);
# 			warn "intersection: $i";
		}
		$match_set	= $i;
# 		warn "\tmatching statements: $match_set\n";
	}
	
	my $open	= 1;
	my @e		= $match_set->elements;
	my $sub	= sub {
		unless (scalar(@e)) {
			$open	= 0;
			return;
		}
		my $e = shift(@e);
# 		warn "quad iterator returning statement $e";
		
		my $st	= $self->{statements}[ $e ];
# 		warn "returning statement from $bound-bound iterator: " . $st->as_string . "\n";
		return $st;
	};
	return RDF::Trine::Iterator::Graph->new( $sub );
}

=item C<< get_contexts >>

Returns an RDF::Trine::Iterator over the RDF::Trine::Node objects comprising
the set of contexts of the stored quads.

=cut

sub get_contexts {
	my $self	= shift;
	my @ctx		= grep { not($_->isa('RDF::Trine::Node::Nil')) } values %{ $self->{ ctx_nodes } };
 	return RDF::Trine::Iterator->new( \@ctx );
}

=item C<< add_statement ( $statement [, $context] ) >>

Adds the specified C<$statement> to the underlying model.

=cut

sub add_statement {
	my $self	= shift;
	my $st		= shift;
	my $context	= shift;
	
	if ($st->isa( 'RDF::Trine::Statement::Quad' )) {
		if (blessed($context)) {
			throw RDF::Trine::Error::MethodInvocationError -text => "add_statement cannot be called with both a quad and a context";
		}
	} else {
		my @nodes	= $st->nodes;
		if (blessed($context)) {
			$st	= RDF::Trine::Statement::Quad->new( @nodes[0..2], $context );
		} else {
			my $nil	= RDF::Trine::Node::Nil->new();
			$st	= RDF::Trine::Statement::Quad->new( @nodes[0..2], $nil );
		}
	}
	
	my $string	= encode_utf8($st->as_string);
	my $st_hash	= sha1($string);
	if ($self->{statement_hashes}{$st_hash}++) {
		my $count	= $self->count_statements( $st->nodes );
# 		warn "store already has statement " . $st->as_string;
		return if $count;
	}
	
	$self->{size}++;
	my $id	= scalar(@{ $self->{ statements } });
	$self->{hash}->add('+' . $string);
	push( @{ $self->{ statements } }, $st );
	foreach my $pos (0 .. $#pos_names) {
		my $name	= $pos_names[ $pos ];
		my $node	= $st->$name();
		my $string	= $node->as_string;
		my $set	= $self->{$name}{ $string };
		unless (blessed($set)) {
			$set	= Set::Scalar->new();
			$self->{$name}{ $string }	= $set;
		}
		$set->insert( $id );
	}
	
	my $ctx	= $st->context;
	my $str	= $ctx->as_string;
	unless (exists $self->{ ctx_nodes }{ $str }) {
		$self->{ ctx_nodes }{ $str }	= $ctx;
	}
	return;
}

=item C<< remove_statement ( $statement [, $context]) >>

Removes the specified C<$statement> from the underlying model.

=cut

sub remove_statement {
	my $self	= shift;
	my $st		= shift;
	my $context	= shift;
	
	if ($st->isa( 'RDF::Trine::Statement::Quad' )) {
		if (blessed($context)) {
			throw RDF::Trine::Error::MethodInvocationError -text => "remove_statement cannot be called with both a quad and a context";
		}
	} else {
		my @nodes	= $st->nodes;
		if (blessed($context)) {
			$st	= RDF::Trine::Statement::Quad->new( @nodes[0..2], $context );
		} else {
			my $nil	= RDF::Trine::Node::Nil->new();
			$st	= RDF::Trine::Statement::Quad->new( @nodes[0..2], $nil );
		}
	}

	my $string	= encode_utf8($st->as_string);
	my $st_hash	= sha1($string);
	unless (exists $self->{statement_hashes}{$st_hash}) {
		return;
	}
	
	if (0 == --$self->{statement_hashes}{$st_hash}) {
		delete $self->{statement_hashes}{$st_hash};
	}
	
	my @nodes	= $st->nodes;
	my $count	= $self->count_statements( @nodes[ 0..3 ] );
# 	warn "remove_statement: count of statement is $count";
	if ($count > 0) {
		$self->{size}--;
		my $id	= $self->_statement_id( $st->nodes );
# 		warn "removing statement $id: " . $st->as_string . "\n";
		$self->{hash}->add('-' . $string);
		$self->{statements}[ $id ]	= undef;
		foreach my $pos (0 .. 3) {
			my $name	= $pos_names[ $pos ];
			my $node	= $st->$name();
			my $str		= $node->as_string;
			my $set		= $self->{$name}{ $str };
			$set->delete( $id );
			if ($set->size == 0) {
				if ($pos == 3) {
					delete $self->{ ctx_nodes }{ $str };
				}
				delete $self->{$name}{ $str };
			}
		}
	}
	return;
}

=item C<< remove_statements ( $subject, $predicate, $object [, $context]) >>

Removes the specified C<$statement> from the underlying model.

=cut

sub remove_statements {
	my $self	= shift;
	my $subj	= shift;
	my $pred	= shift;
	my $obj		= shift;
	my $context	= shift;
	my $iter	= $self->get_statements( $subj, $pred, $obj, $context );
	while (my $st = $iter->next) {
		$self->remove_statement( $st );
	}
}

=item C<< count_statements ( $subject, $predicate, $object, $context ) >>

Returns a count of all the statements matching the specified subject,
predicate, object, and context. Any of the arguments may be undef to match any
value.

=cut

sub count_statements {
	my $self	= shift;
	my @nodes	= @_[0..3];
	my $bound	= 0;
	my %bound;
	
	my $use_quad	= 0;
	if (scalar(@_) >= 4) {
		$use_quad	= 1;
# 		warn "count statements with quad" if ($::debug);
		my $g	= $nodes[3];
		if (blessed($g) and not($g->is_variable)) {
			$bound++;
			$bound{ 3 }	= $g;
		}
	}
	
	foreach my $pos (0 .. 2) {
		my $n	= $nodes[ $pos ];
# 		unless (blessed($n)) {
# 			$n	= RDF::Trine::Node::Nil->new();
# 			$nodes[ $pos ]	= $n;
# 		}
		
		if (blessed($n) and not($n->is_variable)) {
			$bound++;
			$bound{ $pos }	= $n;
		}
	}
	
# 	warn "use quad: $use_quad\n" if ($::debug);
# 	warn "bound: $bound\n" if ($::debug);
	if ($use_quad) {
		if ($bound == 0) {
# 			warn "counting all statements";
			return $self->size;
		} elsif ($bound == 1) {
			my ($pos)	= keys %bound;
			my $name	= $pos_names[ $pos ];
			my $set		= $self->{$name}{ $bound{ $pos }->as_string };
# 			warn Dumper($set) if ($::debug);
			unless (blessed($set)) {
				return 0;
			}
			return $set->size;
		} else {
			my @pos		= keys %bound;
			my @names	= @pos_names[ @pos ];
			my @sets;
			foreach my $i (0 .. $#names) {
				my $pos		= $pos[ $i ];
				my $setname	= $names[ $i ];
				my $data	= $self->{ $setname };
				
				my $node	= $bound{ $pos };
				my $str		= $node->as_string;
				my $set		= $data->{ $str };
				push( @sets, $set );
			}
			foreach my $s (@sets) {
# 				warn "set: " . Dumper($s) if ($::debug);
				unless (blessed($s)) {
# 					warn "*** returning zero" if ($::debug);
					return 0;
				}
			}
			my $i	= shift(@sets);
			while (@sets) {
				my $s	= shift(@sets);
				$i	= $i->intersection($s);
			}
			return $i->size;
		}
	} else {
		# use_quad is false here
		# we're counting distinct (s,p,o) triples from the quadstore
		my $count	= 0;
		my $iter	= $self->get_statements( @nodes[ 0..2 ] );
		while (my $st = $iter->next) {
# 			warn $st->as_string if ($::debug);
			$count++;
		}
		return $count;
	}
}

=item C<< etag >>

If the store has the capability and knowledge to support caching, returns a
persistent token that will remain consistent as long as the store's data doesn't
change. This token is acceptable for use as an HTTP ETag.

=cut

sub etag {
	my $self	= shift;
	return $self->{hash}->b64digest;
}

=item C<< size >>

Returns the number of statements in the store.

=cut

sub size {
	my $self	= shift;
	my $size	= $self->{size};
	return $size;
}

=item C<< supports ( [ $feature ] ) >>

If C<< $feature >> is specified, returns true if the feature is supported by the
store, false otherwise. If C<< $feature >> is not specified, returns a list of
supported features.

=cut

sub supports {
	return;
}

sub _statement_id {
	my $self	= shift;
	my @nodes	= @_;
	foreach my $pos (0 .. 3) {
		my $n	= $nodes[ $pos ];
# 		unless (blessed($n)) {
# 			$n	= RDF::Trine::Node::Nil->new();
# 			$nodes[ $pos ]	= $n;
# 		}
	}
	
	my ($subj, $pred, $obj, $context)	= @nodes;
	
	my @pos		= (0 .. 3);
	my @names	= @pos_names[ @pos ];
	my @sets;
	foreach my $i (0 .. $#names) {
		my $pos		= $pos[ $i ];
		my $setname	= $names[ $i ];
		my $data	= $self->{ $setname };
		my $node	= $nodes[ $pos ];
		my $str		= $node->as_string;
		my $set		= $data->{ $str };
		push( @sets, $set );
	}
	
	foreach my $s (@sets) {
		unless (blessed($s)) {
			return -1;
		}
	}
	my $i	= shift(@sets);
	while (@sets) {
		my $s	= shift(@sets);
		$i	= $i->intersection($s);
	}
	if ($i->size == 1) {
		my ($id)	= $i->members;
		return $id;
	} else {
		return -1;
	}
}

# sub _debug {
# 	my $self	= shift;
# 	my $size	= scalar(@{ $self->{statements} });
# 	warn "Memory quad-store contains " . $size . " statements:\n";
# 	foreach my $st (@{ $self->{statements} }) {
# 		if (blessed($st)) {
# 			warn $st->as_string . "\n";
# 		}
# 	}
# }

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
