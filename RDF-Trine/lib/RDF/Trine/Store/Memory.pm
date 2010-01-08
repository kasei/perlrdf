=head1 NAME

RDF::Trine::Store::Memory - Simple in-memory RDF store

=head1 VERSION

This document describes RDF::Trine::Store::Memory version 0.113

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

our $VERSION	= 0.100;

use Set::Scalar;
use Data::Dumper;
use List::Util qw(first);
use List::MoreUtils qw(any mesh);
use Scalar::Util qw(refaddr reftype blessed);

use RDF::Trine::Error;

my @pos_names	= qw(subject predicate object context);

=head1 METHODS

=over 4

=item C<< new () >>

Returns a new storage object using the supplied arguments to construct a DBI
object for the underlying database.

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
	}, $class);
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
	my @nodes	= @_;
	my $bound	= 0;
	my %bound;
	foreach my $pos (0 .. 3) {
		my $n	= $nodes[ $pos ];
		unless (blessed($n)) {
			$n	= RDF::Trine::Node->new();
			$nodes[ $pos ]	= $n;
		}
		
		if (blessed($n) and $n->isa('RDF::Trine::Node') and not($n->is_nil) and not($n->isa('RDF::Trine::Node::Variable'))) {
			$bound++;
			$bound{ $pos }	= $n;
		}
	}
	
	if ($bound == 0) {
# 		warn "getting all statements";
		my $i	= 0;
		my $sub	= sub {
			return unless ($i <= $#{ $self->{statements} });
			return $self->{statements}[ $i++ ];
		};
		return RDF::Trine::Iterator::Graph->new( $sub );
	}
	
	my $match_set;
	if ($bound == 1) {
# 		warn "getting 1-bound statements";
		my ($pos)		= keys %bound;
		my $name		= $pos_names[ $pos ];
# 		warn "\tbound node is $name\n";
		my $node	= $bound{ $pos };
		my $string	= blessed($node) ? $node->as_string : '';
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
			my $string	= blessed($node) ? $node->as_string : '';
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
	my $sub	= sub {
		return unless ($open);
		my $e = $match_set->each();
		unless (defined($e)) {
			$open	= 0;
			return;
		}
		
		my $st	= $self->{statements}[ $e++ ];
# 		warn "returning statement from $bound-bound iterator: " . $st->as_string . "\n";
		return $st;
	};
	return RDF::Trine::Iterator::Graph->new( $sub );
}

=item C<< get_contexts >>

=cut

sub get_contexts {
	die;
}

=item C<< add_statement ( $statement [, $context] ) >>

Adds the specified C<$statement> to the underlying model.

=cut

sub add_statement {
	my $self	= shift;
	my $st		= shift;
	my $context	= shift;
	if (blessed($context) and not($st->isa('RDF::Trine::Statment::Quad'))) {
		$st	= RDF::Trine::Statement::Quad->new( $st->nodes, $context );
	}
	
	my $count	= $self->count_statements( $st->nodes );
	if ($count == 0) {
		$self->{size}++;
		my $id	= scalar(@{ $self->{ statements } });
		push( @{ $self->{ statements } }, $st );
		foreach my $pos (0 .. $#pos_names) {
			my $name	= $pos_names[ $pos ];
			my $node	= $st->can($name) ? $st->$name() : undef;
			my $string	= blessed($node) ? $node->as_string : '';
			my $set	= $self->{$name}{ $string };
			unless (blessed($set)) {
				$set	= Set::Scalar->new();
				$self->{$name}{ $string }	= $set;
			}
			$set->insert( $id );
		}
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
	if (blessed($context) and not($st->isa('RDF::Trine::Statment::Quad'))) {
		$st	= RDF::Trine::Statement::Quad->new( $st->nodes, $context );
	}
	
	my $count	= $self->count_statements( $st->nodes );
	if ($count > 0) {
		$self->{size}--;
		my $id	= $self->_statement_id( $st->nodes );
		if ($id < 0) {
			throw RDF::Trine::Error -text => "No statement found after count_statements indicated one exists";
		} else {
			$self->{statements}[ $id ]	= undef;
			foreach my $pos (0 .. $#pos_names) {
				my $name	= $pos_names[ $pos ];
				my $set	= $self->{$name}{ $st->$name()->as_string };
				if (blessed($set)) {
					$set->delete( $id );
				}
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
	die;
}

=item C<< count_statements ( $subject, $predicate, $object ) >>

Returns a count of all the statements matching the specified subject,
predicate and objects. Any of the arguments may be undef to match any value.

=cut

sub count_statements {
	my $self	= shift;
	my @nodes	= @_;
	my $bound	= 0;
	my %bound;
	foreach my $pos (0 .. 3) {
		my $n	= $nodes[ $pos ];
		unless (blessed($n)) {
			$n	= RDF::Trine::Node->new();
			$nodes[ $pos ]	= $n;
		}
		
		if (blessed($n) and $n->isa('RDF::Trine::Node') and not($n->isa('RDF::Trine::Node::Variable'))) {
			$bound++;
			$bound{ $pos }	= $n;
		}
	}
	
	if ($bound == 0) {
		return $self->size;
	} elsif ($bound == 1) {
		my ($pos)	= keys %bound;
		my $name	= $pos_names[ $pos ];
		my $set		= $self->{$name};
		unless (blessed($set)) {
			return 0;
		}
		return $set->size;
	} else {
		my @pos		= keys %bound;
		my @names	= @pos_names[ @pos ];
		my @sets	= map { $self->{$names[$_]}{ $bound{$_} } } (0 .. $#names);
		foreach my $s (@sets) {
			unless (blessed($s)) {
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
}

=item C<< size >>

Returns the number of statements in the store.

=cut

sub size {
	my $self	= shift;
	return $self->{size};
}

sub _statement_id {
	my $self	= shift;
	my @nodes	= @_;
	foreach my $pos (0 .. 3) {
		my $n	= $nodes[ $pos ];
		unless (blessed($n)) {
			$n	= RDF::Trine::Node->new();
			$nodes[ $pos ]	= $n;
		}
	}
	
	my ($subj, $pred, $obj, $context)	= @nodes;
	
	my @pos		= (0 .. 3);
	my @names	= @pos_names[ @pos ];
	my @sets	= map { $self->{$_} } @names;
	foreach my $s (@sets) {
		unless (blessed($s)) {
			return 0;
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
	} elsif ($i->size == 0) {
		return -1;
	} else {
		throw RDF::Trine::Error -text => "*** Multiple statements found in store where one expected.";
	}
}

1;

__END__

=back

=head1 BUGS

Please report any bugs or feature requests to C<< <gwilliams@cpan.org> >>.

=head1 AUTHOR

Gregory Todd Williams  C<< <gwilliams@cpan.org> >>

=head1 COPYRIGHT

Copyright (c) 2006-2010 Gregory Todd Williams. All rights reserved. This
program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
