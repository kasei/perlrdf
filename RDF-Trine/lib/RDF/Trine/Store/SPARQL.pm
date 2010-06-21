=head1 NAME

RDF::Trine::Store::SPARQL - RDF Store proxy for a SPARQL endpoint

=head1 VERSION

This document describes RDF::Trine::Store::SPARQL version 0.124

=head1 SYNOPSIS

 use RDF::Trine::Store::SPARQL;

=head1 DESCRIPTION

RDF::Trine::Store::SPARQL provides a RDF::Trine::Store API to interact with a
remote SPARQL endpoint.

=cut

package RDF::Trine::Store::SPARQL;

use strict;
use warnings;
no warnings 'redefine';
use base qw(RDF::Trine::Store);

use Set::Scalar;
use URI::Escape;
use Data::Dumper;
use List::Util qw(first);
use List::MoreUtils qw(any mesh);
use Scalar::Util qw(refaddr reftype blessed);

use RDF::Trine::Error qw(:try);

######################################################################

my @pos_names;
our $VERSION;
BEGIN {
	$VERSION	= "0.124";
	my $class	= __PACKAGE__;
	$RDF::Trine::Store::STORE_CLASSES{ $class }	= $VERSION;
	@pos_names	= qw(subject predicate object context);
}

######################################################################

=head1 METHODS

=over 4

=item C<< new ( $url ) >>

Returns a new storage object that will act as a proxy for the SPARQL endpoint
accessible via the supplied C<$url>.

=cut

sub new {
	my $class	= shift;
	my $url		= shift;
	my $u = LWP::UserAgent->new( agent => "RDF::Trine/${RDF::Trine::VERSION}" );
	$u->default_headers->push_header( 'Accept' => "application/sparql-results+xml;q=0.9,application/rdf+xml;q=0.5,text/turtle;q=0.7,text/xml" );
	
	my $self	= bless({
		ua		=> $u,
		url		=> $url,
	}, $class);
	return $self;
}

sub _new_with_string {
	my $class	= shift;
	my $config	= shift;
	return $class->new( $config );
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
	
	my @var_map	= qw(s p o g);
	my %var_map	= map { $var_map[$_] => $_ } (0 .. $#var_map);
	my @node_map;
	foreach my $i (0 .. $#nodes) {
		if (not(blessed($nodes[$i])) or $nodes[$i]->is_variable) {
			$nodes[$i]	= RDF::Trine::Node::Variable->new( $var_map[ $i ] );
		}
	}
	
	my $node_count	= ($use_quad) ? 4 : 3;
	my $st_class	= ($use_quad) ? 'RDF::Trine::Statement::Quad' : 'RDF::Trine::Statement';
	my @triple	= @nodes[ 0..2 ];
	my $iter;
	if ($use_quad) {
		my @vars	= grep { $_->is_variable } @nodes;
		my $names	= join(' ', map { '?' . $_->name } @vars);
		my $nodes	= join(' ', map { ($_->is_variable) ? '?' . $_->name : $_->as_ntriples } @triple);
		my $g		= $nodes[3]->is_variable ? '?g' : $nodes[3]->as_ntriples;
		$iter	= $self->_get_iterator( <<"END" );
SELECT $names WHERE {
	GRAPH $g {
		$nodes
	}
}
END
	} else {
		my @vars	= grep { $_->is_variable } @triple;
		my $names	= join(' ', map { '?' . $_->name } @vars);
		my $nodes	= join(' ', map { ($_->is_variable) ? '?' . $_->name : $_->as_ntriples } @triple);
		$iter	= $self->_get_iterator( <<"END" );
SELECT $names WHERE { $nodes }
END
	}
	my $sub		= sub {
		my $row	= $iter->next;
		return unless $row;
		my @triple;
		foreach my $i (0 .. ($node_count-1)) {
			if ($nodes[$i]->is_variable) {
				$triple[$i]	= $row->{ $nodes[$i]->name };
			} else {
				$triple[$i]	= $nodes[$i];
			}
		}
		my $triple	= $st_class->new( @triple );
		return $triple;
	};
	return RDF::Trine::Iterator::Graph->new( $sub );
}

=item C<< get_pattern ( $bgp [, $context] ) >>

Returns a stream object of all bindings matching the specified graph pattern.

=cut

sub get_pattern {
	my $self	= shift;
	my $bgp		= shift;
	my $context	= shift;
	my @args	= @_;
	my %args	= @args;
	
	if ($bgp->isa('RDF::Trine::Statement')) {
		$bgp	= RDF::Trine::Pattern->new($bgp);
	}
	
	my %iter_args;
	my @triples	= grep { $_->type eq 'TRIPLE' } $bgp->triples;
	my @quads	= grep { $_->type eq 'QUAD' } $bgp->triples;
	
	my @tripless;
	foreach my $t (@triples) {
		my @nodes	= $t->nodes;
		my @nodess;
		foreach my $n (@nodes) {
			push(@nodess, ($n->is_variable ? '?' . $n->name : $n->as_ntriples));
		}
		push(@tripless, join(' ', @nodess) . ' .');
	}
	my $triples	= join("\n\t", @tripless);
	my $quads	= '';
	if (@quads) {
		return $self->SUPER::get_pattern( $bgp, $context, @args );
		throw RDF::Trine::Error::UnimplementedError -text => "SPARQL get_pattern quad support not implemented";
	}
	
	my $sparql	= <<"END";
SELECT * WHERE {
	$triples
	$quads
}
END
	if (my $o = delete $args{orderby}) {
		my @order;
		while (@$o) {
			my ($k,$order)	= splice(@$o,0,2,());
			push(@order, "${order}(?$k)");
		}
		if (@order) {
			$sparql	.= "ORDER BY " . join(' ', @order);
		}
	}
	
	my $iter	= $self->_get_iterator( $sparql );
	return $iter;
}

=item C<< get_contexts >>

Returns an RDF::Trine::Iterator over the RDF::Trine::Node objects comprising
the set of contexts of the stored quads.

=cut

sub get_contexts {
	my $self	= shift;
	my $sparql	= 'SELECT DISTINCT ?g WHERE { GRAPH ?g {} }';
	my $iter	= $self->_get_iterator( $sparql );
	my $sub	= sub {
		my $row	= $iter->next;
		return unless $row;
		my $g	= $row->{g};
		return $g;
	};
	return RDF::Trine::Iterator->new( $sub );
}

=item C<< add_statement ( $statement [, $context] ) >>

Adds the specified C<$statement> to the underlying model.

=cut

sub add_statement {
	my $self	= shift;
	my $st		= shift;
	my $context	= shift;
	
	throw RDF::Trine::Error::UnimplementedError;
}

=item C<< remove_statement ( $statement [, $context]) >>

Removes the specified C<$statement> from the underlying model.

=cut

sub remove_statement {
	my $self	= shift;
	my $st		= shift;
	my $context	= shift;

	throw RDF::Trine::Error::UnimplementedError;
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

	throw RDF::Trine::Error::UnimplementedError;
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
	
	# XXX try to send a COUNT() query and fall back if it fails
	my $iter	= $self->get_statements( @_ );
	my $count	= 0;
	while (my $st = $iter->next) {
		$count++;
	}
	return $count;
}

=item C<< size >>

Returns the number of statements in the store.

=cut

sub size {
	my $self	= shift;
	return $self->count_statements( undef, undef, undef, undef );
}

sub _get_iterator {
	my $self	= shift;
	my $sparql	= shift;
	my $handler	= RDF::Trine::Iterator::SAXHandler->new();
	my $p		= XML::SAX::ParserFactory->parser(Handler => $handler);
	my $ua		= $self->{ua};
	
# 	warn $sparql;
	
	my $url			= $self->{url} . '?query=' . uri_escape($sparql);
	my $response	= $ua->get( $url );
	if ($response->is_success) {
		$p->parse_string( $response->content );
		return $handler->iterator;
	} else {
		my $status		= $response->status_line;
		my $endpoint	= $self->{url};
#		warn "url: $url\n";
#		warn $sparql;
		throw RDF::Trine::Error -text => "Error making remote SPARQL call to endpoint $endpoint ($status)";
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
