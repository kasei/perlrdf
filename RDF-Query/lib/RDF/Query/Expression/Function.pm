# RDF::Query::Expression::Function
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Expression::Function - Class for Function expressions

=head1 VERSION

This document describes RDF::Query::Expression::Function version 2.918.

=cut

package RDF::Query::Expression::Function;

use strict;
use warnings;
no warnings 'redefine';
use base qw(RDF::Query::Expression);

use RDF::Query::Error qw(:try);
use Data::Dumper;
use Scalar::Util qw(blessed reftype);
use Carp qw(carp croak confess);

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= '2.918';
}

######################################################################

our %FUNCTION_MAP	= (
	str			=> "STR",
	strdt		=> "STRDT",
	strlang		=> "STRLANG",
	lang		=> "LANG",
	langmatches	=> "LANGMATCHES",
	sameterm	=> "sameTerm",
	datatype	=> "DATATYPE",
	bound		=> "BOUND",
	isuri		=> "isURI",
	isiri		=> "isIRI",
	isblank		=> "isBlank",
	isliteral	=> "isLiteral",
	regex		=> "REGEX",
	iri			=> "IRI",
	uri			=> "IRI",
	bnode		=> "BNODE",
	in			=> "IN",
	notin		=> "NOT IN",
	if			=> "IF",
	'logical-or'	=> "||",
	'logical-and'	=> "&&",
);

=head1 METHODS

Beyond the methods documented below, this class inherits methods from the
L<RDF::Query::Expression> class.

=over 4

=cut

=item C<new ( $uri, @arguments )>

Returns a new Expr structure.

=cut

sub new {
	my $class	= shift;
	my $uri		= shift;
	my @args	= @_;
	unless (blessed($uri) and $uri->isa('RDF::Trine::Node::Resource')) {
		$uri	= RDF::Query::Node::Resource->new( $uri );
	}
	return $class->SUPER::new( $uri, @args );
}

=item C<< uri >>

Returns the URI of the function.

=cut

sub uri {
	my $self	= shift;
	return $self->op;
}

=item C<< arguments >>

Returns a list of the arguments to the function.

=cut

sub arguments {
	my $self	= shift;
	return $self->operands;
}

=item C<< sse >>

Returns the SSE string for this algebra expression.

=cut

sub sse {
	my $self	= shift;
	my $context	= shift;
	
	my $uri		= $self->uri->uri_value;
	if ($uri =~ m/^(sop|sparql):(in|notin|str(dt|lang)?|if|iri|uri|bnode|lang(matches)?|sameTerm|datatype|regex|bound|is(URI|IRI|Blank|Literal))/i) {
		my $func	= $2;
		return sprintf(
			'(%s %s)',
			$func,
			join(' ', map { $_->sse( $context ) } $self->arguments),
		);
	} else {
		return sprintf(
			'(%s %s)',
			$self->uri->sse( $context ),
			join(' ', map { $_->sse( $context ) } $self->arguments),
		);
	}
}

=item C<< as_sparql >>

Returns the SPARQL string for this algebra expression.

=cut

sub as_sparql {
	my $self	= shift;
	my $context	= shift;
	my $indent	= shift;
	my @args	= $self->arguments;
	my $uri		= $self->uri->uri_value;
	my $func	= ($uri =~ m/^(sop|sparql):(logical-and|logical-or|in|notin|str(dt|lang)?|if|iri|uri|bnode|lang(matches)?|sameTerm|datatype|regex|bound|is(URI|IRI|Blank|Literal))/i)
				? $FUNCTION_MAP{ lc($2) }
				: $self->uri->as_sparql( $context, $indent );
	if ($func eq 'IN' or $func eq 'NOT IN') {
		my $term	= shift(@args);
		my $string	= sprintf(
			"%s %s (%s)",
			$term->as_sparql( $context, $indent ),
			$func,
			join(', ', map { $_->as_sparql( $context, $indent ) } @args),
		);
		return $string;
	} elsif ($func eq '||' or $func eq '&&') {
		my $string	= sprintf(
			"(%s) $func (%s)",
			(map { $_->as_sparql( $context, $indent ) } @args),
		);
		return $string;
	} else {
		my $string	= sprintf(
			"%s(%s)",
			$func,
			join(', ', map { $_->as_sparql( $context, $indent ) } @args),
		);
		return $string;
	}
}

=item C<< type >>

Returns the type of this algebra expression.

=cut

sub type {
	return 'FUNCTION';
}

=item C<< qualify_uris ( \%namespaces, $base_uri ) >>

Returns a new algebra pattern where all referenced Resource nodes representing
QNames (ns:local) are qualified using the supplied %namespaces.

=cut

sub qualify_uris {
	my $self	= shift;
	my $class	= ref($self);
	my $ns		= shift;
	my $base_uri	= shift;
	my @args;
	foreach my $arg ($self->construct_args) {
		if (blessed($arg) and $arg->isa('RDF::Query::Algebra')) {
			push(@args, $arg->qualify_uris( $ns, $base_uri ));
		} elsif (blessed($arg) and $arg->isa('RDF::Query::Node::Resource')) {
			my $uri	= $arg->uri;
			if (ref($uri)) {
				my ($n,$l)	= @$uri;
				unless (exists($ns->{ $n })) {
					throw RDF::Query::Error::QuerySyntaxError -text => "Namespace $n is not defined";
				}
				my $resolved	= RDF::Query::Node::Resource->new( join('', $ns->{ $n }, $l), $base_uri );
				push(@args, $resolved);
			} else {
				push(@args, $arg);
			}
		} else {
			push(@args, $arg);
		}
	}
	return $class->new( @args );
}

=item C<< evaluate ( $query, \%bound, $context ) >>

Evaluates the expression using the supplied bound variables.
Will return a RDF::Query::Node object.

=cut

sub evaluate {
	my $self	= shift;
	my $query	= shift || 'RDF::Query';
	my $bound	= shift;
	my $context	= shift;
	my $active_graph	= shift;
	my $uri		= $self->uri;
	
	no warnings 'uninitialized';
	my $uriv	= $uri->uri_value;
	if ($uriv =~ /^sparql:logical-(.+)$/ or $uriv =~ /^sparql:(not)?in$/ or $uriv eq 'sparql:coalesce') {
		# logical operators must have their arguments passed lazily, because
		# some of them can still succeed even if some of their arguments throw
		# TypeErrors (e.g. true || fail ==> true).
		my @args	= $self->arguments;
		my $args	= sub {
						my $value	= shift(@args);
						return unless (blessed($value));
						my $val	= 0;
						try {
							$val	= $value->isa('RDF::Query::Expression')
								? $value->evaluate( $query, $bound, $context, $active_graph )
								: ($value->isa('RDF::Trine::Node::Variable'))
									? $bound->{ $value->name }
									: $value;
						} otherwise {};
						return $val || 0;
					};
		my $func	= $query->get_function( $uri );
		my $value	= $func->( $query, $args );
		return $value;
	} elsif ($uriv =~ /^sparql:if$/) {
		my @args	= $self->arguments;
		my $ebv		= RDF::Query::Node::Resource->new( "sparql:ebv" );
		my $expr	= shift(@args);
		my $index	= 1;
		my $ok		= 1;
		try {
			my $exprval	= $query->var_or_expr_value( $bound, $expr, $context );
			my $func	= RDF::Query::Expression::Function->new( $ebv, $exprval );
			my $value	= $func->evaluate( $query, {}, $context, $active_graph );
			my $bool	= ($value->literal_value eq 'true') ? 1 : 0;
			if ($bool) {
				$index	= 0;
			}
		} catch RDF::Query::Error::TypeError with {
			$ok	= 0;
		};
		if ($ok) {
			my $expr2	= $args[$index];
			return $query->var_or_expr_value( $bound, $expr2, $context );
		} else {
			return;
		}
	} elsif ($uriv eq 'sparql:exists') {
		my $func	= $query->get_function($uri);
		my ($ggp)	= $self->arguments;
		return $func->( $query, $context, $bound, $ggp, $active_graph );
	} else {
		my $model	= ref($query) ? $query->{model} : undef;
		if (blessed($context)) {
			$model	= $context->model;
		}
		
		my @args;
		if (ref($query)) {
			# localize the model in the query object (legacy code wants the model accessible from the query object)
			local($query->{model})	= $model;
			@args	= map {
							$_->isa('RDF::Query::Algebra')
								? $_->evaluate( $query, $bound, $context, $active_graph )
								: ($_->isa('RDF::Trine::Node::Variable'))
									? $bound->{ $_->name }
									: $_
						} $self->arguments;
		} else {
			@args	= map {
							$_->isa('RDF::Query::Algebra')
								? $_->evaluate( $query, $bound, $context, $active_graph )
								: ($_->isa('RDF::Trine::Node::Variable'))
									? $bound->{ $_->name }
									: $_
						} $self->arguments;
		}
		
		my $func	= $query->get_function($uri);
		unless ($func) {
			throw RDF::Query::Error::ExecutionError -text => "Failed to get function for IRI $uri";
		}
		my $value	= $func->( $query, @args );
		return $value;
	}
}

1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
