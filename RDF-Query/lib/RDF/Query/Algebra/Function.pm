# RDF::Query::Algebra::Function
# -------------
# $Revision: 121 $
# $Date: 2006-02-06 23:07:43 -0500 (Mon, 06 Feb 2006) $
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Algebra::Function - Algebra class for Function expressions

=cut

package RDF::Query::Algebra::Function;

use strict;
use warnings;
use base qw(RDF::Query::Algebra);

use Data::Dumper;
use Scalar::Util qw(blessed);
use List::MoreUtils qw(uniq);
use Carp qw(carp croak confess);

######################################################################

our ($VERSION, $debug, $lang, $languri);
BEGIN {
	$debug		= 0;
	$VERSION	= do { my $REV = (qw$Revision: 121 $)[1]; sprintf("%0.3f", 1 + ($REV/1000)) };
}

######################################################################

our %FUNCTION_MAP	= (
	str			=> "STR",
	lang		=> "LANG",
	langmatches	=> "LANGMATCHES",
	sameTerm	=> "sameTerm",
	datatype	=> "DATATYPE",
	isBound		=> "BOUND",
	isURI		=> "isURI",
	isIRI		=> "isIRI",
	isBlank		=> "isBlank",
	isLiteral	=> "isLiteral",
);

=head1 METHODS

=over 4

=cut

=item C<new ( $uri, @arguments )>

Returns a new Function structure.

=cut

sub new {
	my $class	= shift;
	my $uri		= shift;
	my @args	= @_;
	return bless( [ 'FUNCTION', $uri, @args ] );
}

=item C<< construct_args >>

Returns a list of arguments that, passed to this class' constructor,
will produce a clone of this algebra pattern.

=cut

sub construct_args {
	my $self	= shift;
	return ($self->uri, $self->arguments);
}

=item C<< uri >>

Returns the URI of the function.

=cut

sub uri {
	my $self	= shift;
	return $self->[1];
}

=item C<< arguments >>

Returns a list of the arguments to the function.

=cut

sub arguments {
	my $self	= shift;
	return @{ $self }[ 2 .. $#{ $self } ];
}

=item C<< sse >>

Returns the SSE string for this alegbra expression.

=cut

sub sse {
	my $self	= shift;
	my $context	= shift;
	
	return sprintf(
		'(function %s %s)',
		$self->uri,
		join(' ', map { $self->sse( $context ) } $self->arguments),
	);
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
	my $func	= ($uri =~ m/^(sop|sparql):(str|lang|langmatches|sameTerm|datatype|is(Bound|URI|IRI|Blank|Literal))/)
				? $FUNCTION_MAP{ $2 }
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

=item C<< referenced_variables >>

Returns a list of the variable names used in this algebra expression.

=cut

sub referenced_variables {
	my $self	= shift;
	return uniq(map { $_->name } grep { blessed($_) and $_->isa('RDF::Query::Node::Variable') } $self->arguments);
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
	
	my $uri		= $self->uri;	# $bridge->as_native( $self->uri );
	my @args	= map {
					$_->isa('RDF::Query::Node')
						? $bridge->as_native( $_, $base, $ns )
						: $_->fixup( $bridge, $base, $ns )
				} $self->arguments;
	return $class->new( $uri, @args );
}




1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
