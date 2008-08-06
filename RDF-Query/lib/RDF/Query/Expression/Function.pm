# RDF::Query::Expression::Function
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Expression::Function - Class for Function expressions

=cut

package RDF::Query::Expression::Function;

use strict;
use warnings;
no warnings 'redefine';
use base qw(RDF::Query::Expression);

use Data::Dumper;
use Scalar::Util qw(blessed);
use List::MoreUtils qw(uniq);
use Carp qw(carp croak confess);

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= '2.002';
}

######################################################################

our %FUNCTION_MAP	= (
	str			=> "STR",
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
);

=head1 METHODS

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

Returns the SSE string for this alegbra expression.

=cut

sub sse {
	my $self	= shift;
	my $context	= shift;
	
	my $uri		= $self->uri->uri_value;
	if ($uri =~ m/^(sop|sparql):(str|lang|langmatches|sameTerm|datatype|regex|is(Bound|URI|IRI|Blank|Literal))/i) {
		return sprintf(
			'(%s %s)',
			$uri,
			join(' ', map { $_->sse( $context ) } $self->arguments),
		);
	} else {
		return sprintf(
			'(function %s %s)',
			$self->uri->sse( $context ),
			join(' ', map { $_->sse( $context ) } $self->arguments),
		);
	}
}

=item C<< as_sparql >>

Returns the SPARQL string for this alegbra expression.

=cut

sub as_sparql {
	my $self	= shift;
	my $context	= shift;
	my $indent	= shift;
	my @args	= $self->arguments;
	my $uri		= $self->uri->uri_value;
	my $func	= ($uri =~ m/^(sop|sparql):(str|lang|langmatches|sameTerm|datatype|regex|bound|is(URI|IRI|Blank|Literal))/i)
				? $FUNCTION_MAP{ lc($2) }
				: $self->uri->as_sparql( $context, $indent );
	my $string	= sprintf(
		"%s( %s )",
		$func,
		join(', ', map { $_->as_sparql( $context, $indent ) } @args),
	);
	return $string;
}

=item C<< type >>

Returns the type of this algebra expression.

=cut

sub type {
	return 'FUNCTION';
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
		} else {
			push(@args, $arg);
		}
	}
	return $class->new( @args );
}

=item C<< evaluate ( $query, $bridge, \%bound ) >>

Evaluates the expression using the supplied context (bound variables and bridge
object). Will return a RDF::Query::Node object.

=cut

sub evaluate {
	my $self	= shift;
	my $query	= shift || 'RDF::Query';
	my $bridge	= shift;
	my $bound	= shift;
	my $uri		= $self->uri;
	
	no warnings 'uninitialized';
	if ($uri->uri_value =~ /^sparql:logical-(.+)$/) {
		# logical operators must have their arguments passed lazily, because
		# some of them can still succeed even if some of their arguments throw
		# TypeErrors (e.g. true || fail ==> true).
		my @args	= $self->arguments;
		my $args	= sub {
						my $value	= shift(@args);
						return unless (defined $value);
						return $value->isa('RDF::Query::Algebra')
							? $value->evaluate( $query, $bridge, $bound )
							: ($value->isa('RDF::Trine::Node::Variable'))
								? $bound->{ $value->name }
								: $value
					};
		my $func	= $query->get_function( $uri );
		my $value	= $func->( $query, $bridge, $args );
		return $value;
	} else {
		my @args	= map {
						$_->isa('RDF::Query::Algebra')
							? $_->evaluate( $query, $bridge, $bound )
							: ($_->isa('RDF::Trine::Node::Variable'))
								? $bound->{ $_->name }
								: $_
					} $self->arguments;
		
		my $func	= $query->get_function($uri);
		my $value	= $func->( $query, $bridge, @args );
		return $value;
	}
}

1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
