# RDF::Query::Algebra::OldFilter
# -------------
# $Revision: 121 $
# $Date: 2006-02-06 23:07:43 -0500 (Mon, 06 Feb 2006) $
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Algebra::OldFilter - Algebra class for Filter expressions

=cut

package RDF::Query::Algebra::OldFilter;

use strict;
use warnings;
no warnings 'redefine';
use base qw(RDF::Query::Algebra);

use Data::Dumper;
use List::MoreUtils qw(uniq);
use Carp qw(carp croak confess);
use Scalar::Util qw(blessed reftype);

######################################################################

our ($VERSION, $debug, $lang, $languri);
BEGIN {
	$debug		= 0;
	$VERSION	= do { my $REV = (qw$Revision: 121 $)[1]; sprintf("%0.3f", 1 + ($REV/1000)) };
}

######################################################################

# function
# operator
# 	unary
# 	binary


our %OPERATORS	= (
	'~~'	=> {
				arity	=> { 2 => 'REGEX(%s, %s)', 3 => "REGEX(%s, %s, %s)" },
			},
	'=='	=> {
				arity	=> { 2 => '%s = %s' },
			},
	'!='	=> {
				arity	=> { 2 => '%s != %s' },
			},
	'<'		=> {
				arity	=> { 2 => '%s < %s' },
			},
	'>'		=> {
				arity	=> { 2 => '%s > %s' },
			},
	'<='	=> {
				arity	=> { 2 => '%s <= %s' },
			},
	'>='	=> {
				arity	=> { 2 => '%s >= %s' },
			},
	'&&'	=> {
				arity	=> { 2 => '%s && %s' },
			},
	'||'	=> {
				arity	=> { 2 => '%s || %s' },
			},
	'*'		=> {
				arity	=> { 2 => '%s * %s' },
			},
	'/'		=> {
				arity	=> { 2 => '%s / %s' },
			},
	'+'		=> {
				arity	=> { 2 => '%s + %s' },
			},
	'-'		=> {
				arity	=> { 1 => '-%s', 2 => '%s - %s' },
			},
	'!'		=> {
				arity	=> { 1 => '! %s' },
			},
);


=head1 METHODS

=over 4

=cut

=item C<new ( $filter_expression )>

Returns a new Filter structure.

=cut

sub new {
	my $class	= shift;
	my $expr	= shift;
	return bless( [ 'OLDFILTER', $expr ] );
}

=item C<< construct_args >>

Returns a list of arguments that, passed to this class' constructor,
will produce a clone of this algebra pattern.

=cut

sub construct_args {
	my $self	= shift;
	return ($self->expr);
}

=item C<< expr >>

Returns the filter expression.

=cut

sub expr {
	my $self	= shift;
	if (@_) {
		$self->[1]	= shift;
	}
	return $self->[1];
}

=item C<< sse >>

Returns the SSE string for this alegbra expression.

=cut

sub sse {
	my $self	= shift;
	my $context	= shift;
	
	return sprintf(
		'(oldfilter %s)',
		$self->expr->sse( $context ),
	);
}

=item C<< as_sparql >>

Returns the SPARQL string for this alegbra expression.

=cut

sub as_sparql {
	my $self	= shift;
	my $context	= shift;
	my $indent	= shift;
	
	my $expr	= $self->expr;
	my ($op, @ops)	= @{ $expr };
	if (exists($OPERATORS{$op})) {
		my $data	= $OPERATORS{ $op };
		my $arity	= scalar(@ops);
		if (exists($data->{arity}{$arity})) {
			my $template	= $data->{arity}{$arity};
			my $expr	= sprintf( $template, map { $_->as_sparql( $context, $indent ) } @ops );
			my $string	= sprintf(
				"FILTER %s",
				$expr,
			);
			return $string;
		} else {
			warn "Operator '$op' is not defined for arity of $arity\n";
			die;
		}
	} else {
		die Dumper($expr);
	}
}

=item C<< type >>

Returns the type of this algebra expression.

=cut

sub type {
	return 'FILTER';
}

=item C<< referenced_variables >>

Returns a list of the variable names used in this algebra expression.

=cut

sub referenced_variables {
	my $self	= shift;
	my $expr	= $self->expr;
	if (blessed($expr) and $expr->isa('RDF::Query::Algebra')) {
		return uniq($self->expr->referenced_variables);
	} elsif (blessed($expr) and $expr->isa('RDF::Query::Node::Variable')) {
		return $expr->name;
	} else {
		return ();
	}
}

=item C<< definite_variables >>

Returns a list of the variable names that will be bound after evaluating this algebra expression.

=cut

sub definite_variables {
	my $self	= shift;
	return ();
}

=item C<< fixup ( $bridge, $base, \%namespaces ) >>

Returns a new pattern that is ready for execution using the given bridge.
This method replaces generic node objects with bridge-native objects.

=cut

sub fixup {
	my $self	= shift;
	my $class	= ref($self);
	my $bridge	= shift;
	my $base	= shift;
	my $ns		= shift;
	
	my $expr	= $self->expr;
	if (blessed($expr) and $expr->isa('RDF::Query::Algebra::Expr::Function')) {
		$self->expr( $expr->fixup( $bridge, $base, $ns ) );
	} else {
		my @constraints	= ($expr);
		while (my $data = shift @constraints) {
			if (ref($data) and reftype($data) eq 'ARRAY') {
				my ($op, @rest)	= @$data;
				if (blessed($data) and $data->isa('RDF::Query::Node::Resources')) {
					$data->uri( $data->qualify( $base, $ns ) );
				} elsif (blessed($data) and $data->isa('RDF::Query::Node::Literal')) {
					no warnings 'uninitialized';
					if ($data->has_datatype) {
						my $dt	= $data->literal_datatype;
	#					$data->[3][1]	= $self->qualify_uri( $data->[3] );
					}
				} elsif ($op !~ /^(VAR|LITERAL)$/) {
					push(@constraints, @rest);
				}
			}
		}
	}
	return $self;
}

=item C<< qualify_uris ( \%namespaces, $base ) >>

Returns a new algebra pattern where all referenced Resource nodes representing
QNames (ns:local) are qualified using the supplied %namespaces.

=cut

sub qualify_uris {
	my $self	= shift;
	my $class	= ref($self);
	my $ns		= shift;
	my $base	= shift;
	my @args;
	foreach my $arg ($self->construct_args) {
		if (blessed($arg) and $arg->isa('RDF::Query::Algebra')) {
			push(@args, $arg->qualify_uris( $ns, $base ));
		} elsif (blessed($arg) and $arg->isa('RDF::Query::Node::Resource')) {
			my $uri	= $arg->uri;
			if (ref($uri)) {
				my ($n,$l)	= @$uri;
				unless (exists($ns->{ $n })) {
					throw RDF::Query::Error::QuerySyntaxError -text => "Namespace $n is not defined";
				}
				my $resolved	= RDF::Query::Node::Resource->new( join('', $ns->{ $n }, $l), $base );
				push(@args, $resolved);
			} else {
				push(@args, $arg);
			}
		} elsif (ref($arg) and ref($arg) eq 'ARRAY') {
			push(@args, _descend( $arg, $ns, $base ));
		} else {
			push(@args, $arg);
		}
	}
	return $class->new( @args );
}

sub _descend {
	my $array	= shift;
	my $ns		= shift;
	my $base	= shift;
	my @data	= @$array;
	my @args;
	foreach my $arg (@data) {
		if (blessed($arg) and $arg->isa('RDF::Query::Algebra')) {
			push(@args, $arg->qualify_uris( $ns, $base ));
		} elsif (blessed($arg) and $arg->isa('RDF::Query::Node::Literal') and $arg->has_datatype) {
			my $dt	= $arg->literal_datatype;
			if (ref($dt)) {
				my ($n,$l)	= @$dt;
				unless (exists($ns->{ $n })) {
					throw RDF::Query::Error::QuerySyntaxError -text => "Namespace $n is not defined";
				}
				my $resolved	= RDF::Query::Node::Resource->new( join('', $ns->{ $n }, $l), $base );
				my $lit			= RDF::Query::Node::Literal->new( $arg->literal_value, undef, $resolved->uri_value );
				push(@args, $lit);
			} else {
				push(@args, $arg);
			}
		} elsif (blessed($arg) and $arg->isa('RDF::Query::Node::Resource')) {
			my $uri	= $arg->uri;
			if (ref($uri)) {
				my ($n,$l)	= @$uri;
				unless (exists($ns->{ $n })) {
					throw RDF::Query::Error::QuerySyntaxError -text => "Namespace $n is not defined";
				}
				my $resolved	= RDF::Query::Node::Resource->new( join('', $ns->{ $n }, $l), $base );
				push(@args, $resolved);
			} else {
				push(@args, $arg);
			}
		} elsif (ref($arg) and ref($arg) eq 'ARRAY') {
			push(@args, _descend( $arg, $ns, $base ));
		} else {
			push(@args, $arg);
		}
	}
	return \@args;
}



1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
