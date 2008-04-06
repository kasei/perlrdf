# RDF::Query::Algebra::Sort
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Algebra::Sort - Algebra class for sorting

=cut

package RDF::Query::Algebra::Sort;

use strict;
use warnings;
no warnings 'redefine';
use base qw(RDF::Query::Algebra);

use Data::Dumper;
use Set::Scalar;
use Scalar::Util qw(blessed);
use List::MoreUtils qw(uniq);
use Carp qw(carp croak confess);

######################################################################

our ($VERSION, $debug);
BEGIN {
	$debug		= 0;
	$VERSION	= '2.000';
}

######################################################################

=head1 METHODS

=over 4

=cut

=item C<new ( $pattern, [ $dir => $expr ] )>

Returns a new Sort structure.

=cut

sub new {
	my $class	= shift;
	my $pattern	= shift;
	my @orderby	= @_;
	return bless( [ $pattern, @orderby ], $class );
}

=item C<< construct_args >>

Returns a list of arguments that, passed to this class' constructor,
will produce a clone of this algebra pattern.

=cut

sub construct_args {
	my $self	= shift;
	my $pattern	= $self->pattern;
	my @orderby	= $self->orderby;
	return ($pattern, @orderby);
}

=item C<< pattern >>

Returns the pattern to be sorted.

=cut

sub pattern {
	my $self	= shift;
	return $self->[0];
}

=item C<< orderby >>

Returns the array of ordering definitions.

=cut

sub orderby {
	my $self	= shift;
	my @orderby	= @{ $self }[ 1 .. $#{ $self } ];
	return @orderby;
}

=item C<< sse >>

Returns the SSE string for this alegbra expression.

=cut

sub sse {
	my $self	= shift;
	my $context	= shift;
	
	my @order_sse;
	my @orderby	= $self->orderby;
	foreach my $o (@orderby) {
		my ($dir, $val)	= @$o;
		push(@order_sse, sprintf("($dir %s)", $val->sse( $context )));
	}
	
	return sprintf(
		'(sort %s %s)',
		$self->pattern->sse( $context ),
		join(' ', @order_sse),
	);
}

=item C<< as_sparql >>

Returns the SPARQL string for this alegbra expression.

=cut

sub as_sparql {
	my $self	= shift;
	my $context	= shift;
	my $indent	= shift;
	
	my @order_sparql;
	my @orderby	= $self->orderby;
	foreach my $o (@orderby) {
		my ($dir, $val)	= @$o;
		$dir			= uc($dir);
		my $str			= ($dir eq 'ASC')
						? $val->as_sparql( $context )
						: sprintf("%s(%s)", $dir, $val->as_sparql( $context ));
		push(@order_sparql, $str);
	}
	
	my $string	= sprintf(
		"%s\nORDER BY %s",
		$self->pattern->as_sparql( $context, $indent ),
		join(' ', @order_sparql),
	);
	return $string;
}

=item C<< type >>

Returns the type of this algebra expression.

=cut

sub type {
	return 'SORT';
}

=item C<< referenced_variables >>

Returns a list of the variable names used in this algebra expression.

=cut

sub referenced_variables {
	my $self	= shift;
	return uniq($self->pattern->referenced_variables);
}

=item C<< definite_variables >>

Returns a list of the variable names that will be bound after evaluating this algebra expression.

=cut

sub definite_variables {
	my $self	= shift;
	return $self->pattern->definite_variables;
}

=item C<< fixup ( $query, $bridge, $base, \%namespaces ) >>

Returns a new pattern that is ready for execution using the given bridge.
This method replaces generic node objects with bridge-native objects.

=cut

sub fixup {
	my $self	= shift;
	my $class	= ref($self);
	my $query	= shift;
	my $bridge	= shift;
	my $base	= shift;
	my $ns		= shift;
	
	if (my $opt = $bridge->fixup( $self, $query, $base, $ns )) {
		return $opt;
	} else {
		my $pattern	= $self->pattern->fixup( $query, $bridge, $base, $ns );
		my @order	= map {
						my ($d,$e)	= @$_;
						my $ne		= ($e->isa('RDF::Query::Node::Variable'))
									? $e
									: $e->fixup( $query, $bridge, $base, $ns );
						[ $d, $ne ]
					} $self->orderby;
		return $class->new( $pattern, @order );
	}
}

=item C<< execute ( $query, $bridge, \%bound, $context, %args ) >>

=cut

sub execute {
	my $self		= shift;
	my $query		= shift;
	my $bridge		= shift;
	my $bound		= shift;
	my $context		= shift;
	my %args		= @_;
	
	my $stream		= $self->pattern->execute( $query, $bridge, $bound, $context, %args );
	my @cols		= $self->orderby;
	
#	local($debug)	= 1;
	my ($req_sort, $actual_sort);
	eval {
		$req_sort	= join(',', map { $_->[1]->name => $_->[0] } @cols);
		$actual_sort	= join(',', $stream->sorted_by());
		if ($debug) {
			warn "stream is sorted by $actual_sort\n";
			warn "trying to sort by $req_sort\n";
		}
	};
	
	my @variables	= $self->pattern->referenced_variables;
	my %colmap		= map { $variables[$_] => $_ } (0 .. $#variables);
	warn 'sort variable colmap: ' . Dumper(\@variables, \%colmap) if ($debug);
	
	if (not($@) and substr($actual_sort, 0, length($req_sort)) eq $req_sort) {
		warn "Already sorted. Ignoring." if ($debug);
	} else {
		my ($dir, $data)	= @{ $cols[0] };
		if ($dir ne 'ASC' and $dir ne 'DESC') {
			warn "Direction of sort not recognized: $dir";
			$dir	= 'ASC';
		}
		
		my $col				= $data;
		my $colmap_value	= $colmap{$col};
		
		my @nodes;
		while (my $node = $stream->next()) {
			push(@nodes, $node);
		}
		
		no warnings 'numeric';
		@nodes	= map {
					my $bound	= $_;
					my $value	= $query->var_or_expr_value( $bridge, $bound, $data );
					[ $_, $value ]
				} @nodes;
		
		{
			local($RDF::Query::Node::Literal::LAZY_COMPARISONS)	= 1;
			use sort 'stable';
			@nodes	= sort { $a->[1] <=> $b->[1] } @nodes;
			@nodes	= reverse @nodes if ($dir eq 'DESC');
		}
		
		@nodes	= map { $_->[0] } @nodes;


		my $type	= $stream->type;
		my $names	= [ $stream->binding_names ];
		my $args	= $stream->_args;
		my %sorting	= (sorted_by => [$col, $dir]);
		$stream		= RDF::Trine::Iterator::Bindings->new( sub { shift(@nodes) }, $names, %$args, %sorting );
	}
	
	return $stream;
}


1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
