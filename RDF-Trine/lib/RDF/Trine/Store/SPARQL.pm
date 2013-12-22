=head1 NAME

RDF::Trine::Store::SPARQL - RDF Store proxy for a SPARQL endpoint

=head1 VERSION

This document describes RDF::Trine::Store::SPARQL version 1.001

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

use URI;
use URI::Escape;
use Data::Dumper;
use List::Util qw(first);
use List::MoreUtils qw(any);
use Scalar::Util qw(refaddr reftype blessed);

use RDF::Trine::Error qw(:try);

######################################################################

my @pos_names;
our $VERSION;
BEGIN {
	$VERSION	= "1.001";
	my $class	= __PACKAGE__;
	$RDF::Trine::Store::STORE_CLASSES{ $class }	= $VERSION;
	@pos_names	= qw(subject predicate object context);
}

######################################################################

=head1 METHODS

Beyond the methods documented below, this class inherits methods from the
L<RDF::Trine::Store> class.

=over 4

=item C<< new ( $url [, $realm, $user, $pass ] ) >>

Returns a new storage object that will act as a proxy for the SPARQL
endpoint accessible via the supplied C<$url>. Optionally, an
authentication realm, username and password can be supplied.

=item C<new_with_config ( $hashref )>

Returns a new storage object configured with a hashref with certain
keys as arguments.

The C<storetype> key must be C<SPARQL> for this backend.

The following key must also be used:

=over

=item C<url>

The URL of the remote endpoint.

=back

And these optional keys:

=over

=item C<context>

The default context for graph queries.

=item C<realm>

The authentication realm of the endpoint.

=item C<user>

The username to authenticate with.

=item C<password>

The password.

=back

=cut

sub new {
	my $class	= shift;
	my $url		= shift;
	my $context	= shift;
	my $realm	= shift;
	my $user	= shift;
	my $pass	= shift;
	my $u		= RDF::Trine->default_useragent->clone;

	# XXX virtuoso endpoint doesn't pay attention to the q-values
	#my @accept = qw(application/sparql-results+xml;q=0.9
	#				application/rdf+xml;q=0.7);
	my @accept = qw(application/sparql-results+json);
	$u->default_headers->push_header('Accept' => join(', ', @accept));

	# cloning scrubs this away
	$u->conn_cache({ total_capacity => 1 });

	# set up access credentials
	$url = URI->new($url)->canonical;
	if (defined $realm && defined $user) {
		$u->credentials($url->host_port, $realm, $user, $pass);
	}

	# virtuoso sparql won't work without a default context
	if (defined $context) {
		if (blessed $context) {
			$context = RDF::Trine::Node::Resource->new("$context")
				if $context->isa('URI');
			throw RDF::Trine::Error::MethodInvocationError
				-text => "Context must be a Node object"
					unless $context->isa('RDF::Trine::Node');
		}
		else {
			$context = RDF::Trine::Node::Resource->new($context);
		}
	}

	my $self	= bless({
		ua		=> $u,
		url		=> $url,
		context => $context,
	}, $class);
	return $self;
}

sub _new_with_string {
	my $class	= shift;
	my $config	= shift;
	return $class->new( $config );
}

=item C<< new_with_config ( \%config ) >>

Returns a new RDF::Trine::Store object based on the supplied configuration hashref.

=cut

sub new_with_config {
	my $proto	= shift;
	my $config	= shift;
	$config->{storetype}	= 'SPARQL';
	return $proto->SUPER::new_with_config( $config );
}

sub _new_with_config {
	my $class	= shift;
	my $config	= shift;
	return $class->new( @{$config}{qw(url context realm user password)} );
}

sub _config_meta {
	return {
		required_keys	=> [qw(url)],
		fields			=> {
			url	=> { description => 'Endpoint URL', type => 'string' },
		}
	}
}


=item C<< get_statements ( $subject, $predicate, $object [, $context] ) >>

Returns a stream object of all statements matching the specified subject,
predicate and objects. Any of the arguments may be undef to match any value.

=cut

sub get_statements {
	my $self	= shift;
	my @nodes	= @_;

	my $use_quad	= 0;
	my @var_map	= qw(s p o g);
	my @node_map;
	my %in;
	foreach my $i (0 .. $#nodes) {
		# stop processing
		last if $i > 3;

		# quad logic
		$use_quad = 1 if $i == 3;

		if (!defined $nodes[$i]
				or (blessed($nodes[$i]) and $nodes[$i]->is_variable)) {
			$nodes[$i]	= RDF::Trine::Node::Variable->new( $var_map[ $i ] );
		}
		elsif (ref $nodes[$i] eq 'ARRAY') {
			throw RDF::Trine::Error::MethodInvocationError
				-text => "ARRAY ref contents must be non-variable Node objects"
					if any { !blessed($_) or !$_->isa('RDF::Trine::Node')
								 or $_->is_variable } @{$nodes[$i]};

			my $len = scalar @{$nodes[$i]};
			if ($len == 1) {
				# behave normally
				$nodes[$i] = $nodes[$i][0] if $len == 1;
			}
			else {
				if ($len != 0) {
					# populate list for IN operator
					for my $node (@{$nodes[$i]}) {
						push @{$in{$var_map[$i]} ||= []}, $node;
					}
				}

				# do this either way
				$nodes[$i] = RDF::Trine::Node::Variable->new( $var_map[ $i ] );
			}
		}
		elsif (blessed($nodes[$i]) and $nodes[$i]->isa('RDF::Trine::Node')) {
			# noop
		}
		else {
			throw RDF::Trine::Error::MethodInvocationError
				-text => "Don't know what to do with $nodes[$i]";
		}
	}

	my $node_count	= ($use_quad) ? 4 : 3;
	my $st_class	= 'RDF::Trine::Statement';
	$st_class .= '::Quad' if $use_quad;

	my @triple	= @nodes[ 0..2 ];

	# create the select list
	my @vars	= grep { blessed($_) and $_->is_variable } @nodes;
	my $names	= join ' ', map { '?' . $_->name } @vars;
	# create the where clause
	my $nodes	= join(' ', map { ($_->is_variable) ? '?' . $_->name : $_->as_ntriples } @triple);

	# create the (optional) filter
	my $filter  = '';
	if (keys %in) {
		my @f;
		for my $k (keys %in) {
			push @f, sprintf '?%s IN (%s)', $k, join(', ', @{$in{$k}});
		}
		$filter = sprintf 'FILTER (%s)', join(' && ', @f);
	}

	# create the format string
	my $format	= 'SELECT %s WHERE { %s %s }';
	if ($use_quad) {
		my $g	= $nodes[3]->is_variable ? '?g' : $nodes[3]->as_ntriples;
		# yo dawg i herd u liek formats so we put a format in yo format
		$format	= sprintf 'SELECT %%s WHERE { GRAPH %s { %%s } %%s }', $g;
	}
	# create the iterator
	my $sparql	= sprintf $format, $names, $nodes, $filter;
	#warn $sparql;
	my $iter	= $self->get_sparql($sparql);

	my $sub		= sub {
		my $row	= $iter->next;
		return unless defined $row;
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

Returns an iterator object of all bindings matching the specified graph pattern.

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
	
	my $iter	= $self->get_sparql( $sparql );
	return $iter;
}

=item C<< get_contexts >>

Returns an RDF::Trine::Iterator over the RDF::Trine::Node objects comprising
the set of contexts of the stored quads.

=cut

sub get_contexts {
	my $self	= shift;
	my $sparql	= 'SELECT DISTINCT ?g WHERE { GRAPH ?g {} }';
	my $iter	= $self->get_sparql( $sparql );
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
	unless (blessed($st) and $st->isa('RDF::Trine::Statement')) {
		throw RDF::Trine::Error::MethodInvocationError -text => "Not a valid statement object passed to add_statement";
	}

	if (defined $context and not
			(blessed($context) and $context->isa('RDF::Trine::Node'))) {
		throw RDF::Trine::Error::MethodInvocationError -text => "Invalid context $context passed to add_statement";
	}

	if ($self->_bulk_ops) {
		push(@{ $self->{ ops } }, ['_add_statements', $st, $context]);
	} else {
		my $sparql	= $self->_add_statements_sparql( [ $st, $context ] );
		my $iter	= $self->_get_post_iterator( $sparql );
		my $row		= $iter->next;
	}
	return;
}

sub _add_statements_sparql {
	my $self	= shift;
	my @parts;
	foreach my $op (@_) {
		my $st		= $op->[0];

		my ($s, $p, $o, $c) = $st->nodes;
		# quad context supersedes argument context
		$c ||= $op->[1] || $self->{context};
		# default context

		my $pat = sprintf '%s %s %s .', map { $_->as_ntriples } ($s, $p, $o);
		$pat = sprintf 'GRAPH %s { %s }', $c->as_ntriples, $pat if $c;

		push @parts, $pat;
	}
	my $sparql	= sprintf( 'INSERT DATA { %s }', join("\n\t", @parts) );
	#warn $sparql;
	return $sparql;
}

=item C<< remove_statement ( $statement [, $context]) >>

Removes the specified C<$statement> from the underlying model.

=cut

sub remove_statement {
	my $self	= shift;
	my $st		= shift;
	my $context	= shift;
	
	unless (blessed($st) and $st->isa('RDF::Trine::Statement')) {
		throw RDF::Trine::Error::MethodInvocationError -text => "Not a valid statement object passed to remove_statement";
	}
	
	if ($self->_bulk_ops) {
		push(@{ $self->{ ops } }, ['_remove_statements', $st, $context]);
	} else {
		my $sparql	= $self->_remove_statements_sparql( [ $st, $context ] );
		my $iter	= $self->_get_post_iterator( $sparql );
		my $row		= $iter->next;
	}
	return;
}

sub _remove_statements_sparql {
	my $self	= shift;
	my @parts;
	foreach my $op (@_) {
		my $st		= $op->[0];
		my $context	= $op->[1];
		if ($st->isa('RDF::Trine::Statement::Quad')) {
			push(@parts, 'GRAPH ' . $st->context->as_ntriples . ' { ' . join(' ', map { $_->as_ntriples } ($st->nodes)[0..2]) . ' }');
		} else {
			push(@parts, join(' ', map { $_->as_ntriples } $st->nodes) . ' .');
		}
	}
	my $sparql	= sprintf( 'DELETE DATA { %s }', join("\n\t", @parts) );
	return $sparql;
}

=item C<< remove_statements ( $subject, $predicate, $object [, $context]) >>

Removes the specified C<$statement> from the underlying model.

=cut

sub remove_statements {
	my $self	= shift;
	my $st		= shift;
	my $context	= shift;
	
	unless (blessed($st) and $st->isa('RDF::Trine::Statement')) {
		throw RDF::Trine::Error::MethodInvocationError -text => "Not a valid statement object passed to remove_statements";
	}
	
	if ($self->_bulk_ops) {
		push(@{ $self->{ ops } }, ['_remove_statement_patterns', $st, $context]);
	} else {
		my $sparql	= $self->_remove_statement_patterns_sparql( [ $st, $context ] );
		my $iter	= $self->_get_post_iterator( $sparql );
		my $row		= $iter->next;
	}
	return;
}

sub _remove_statement_patterns_sparql {
	my $self	= shift;
	my @parts;
	foreach my $op (@_) {
		my $st		= $op->[0];
		my $context	= $op->[1];
		my $sparql;
		if ($st->isa('RDF::Trine::Statement::Quad')) {
			push(@parts, 'GRAPH ' . $st->context->as_ntriples . ' { ' . join(' ', map { $_->is_variable ? '?' . $_->name : $_->as_ntriples } ($st->nodes)[0..2]) . ' }');
		} else {
			push(@parts, join(' ', map { $_->is_variable ? '?' . $_->name : $_->as_ntriples } $st->nodes) . ' .');
		}
		
	}
	my $sparql	= sprintf( 'DELETE WHERE { %s }', join("\n\t", @parts));
	return $sparql;
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
	
	foreach my $i (0 .. $#nodes) {
		my $node	= $nodes[$i];
		unless (defined($node)) {
			$nodes[$i]	= RDF::Trine::Node::Variable->new( "rt__" . $pos_names[$i] );
		}
	}
	
	
	my $sparql;
	my $triple	= join(' ', map { $_->is_variable ? '?' . $_->name : $_->as_ntriples } @nodes[0..2]);
	if ($use_quad) {
		my $nodes;
		if ($nodes[3]->isa('RDF::Trine::Node::Variable')) {
			$nodes		= "GRAPH ?rt__graph { $triple }";
		} elsif ($nodes[3]->isa('RDF::Trine::Node::Nil')) {
			$nodes	= join(' ', map { $_->is_variable ? '?' . $_->name : $_->as_ntriples } @nodes[0..2]);
		} else {
			my $graph	= $nodes[3]->is_variable ? '?' . $nodes[3]->name : $nodes[3]->as_ntriples;
			$nodes		= "GRAPH $graph { $triple }";
		}
		$sparql	= "SELECT (COUNT(*) AS ?count) WHERE { $nodes }";
	} else {
		$sparql	= "SELECT (COUNT(*) AS ?count) WHERE { $triple }";
	}
	my $iter	= $self->get_sparql( $sparql );
	my $row		= $iter->next;
	my $count	= $row->{count};
	return unless ($count);
	return $count->literal_value;
	
# 	
# 	
# 	
# 	
# 	
# 	# XXX try to send a COUNT() query and fall back if it fails
# 	my $iter	= $self->get_statements( @_ );
# 	my $count	= 0;
# 	while (my $st = $iter->next) {
# 		$count++;
# 	}
# 	return $count;
}

=item C<< size >>

Returns the number of statements in the store.

=cut

sub size {
	my $self	= shift;
	return $self->count_statements( undef, undef, undef, undef );
}

=item C<< supports ( [ $feature ] ) >>

If C<< $feature >> is specified, returns true if the feature is supported by the
store, false otherwise. If C<< $feature >> is not specified, returns a list of
supported features.

=cut

sub supports {
	my $self	= shift;
	my %features	= map { $_ => 1 } (
		'http://www.w3.org/ns/sparql-service-description#SPARQL10Query',
		'http://www.w3.org/ns/sparql-service-description#SPARQL11Query',
		'http://www.w3.org/ns/sparql-service-description#SPARQL11Update',
	);
	if (@_) {
		my $f	= shift;
		return $features{ $f };
	} else {
		return keys %features;
	}
}

=item C<< get_sparql ( $sparql ) >>

Returns an iterator object of all bindings matching the specified SPARQL query.

=cut

sub _json_literal {
	RDF::Trine::Node::Literal->new(@{$_[0]}{qw(value lang datatype)});
}
my %JSON = (
	uri   => sub { RDF::Trine::Node::Resource->new($_[0]{value}) },
	bnode => sub {
		my $x = $_[0]{value};
		$x =~ s!nodeID://!!;
		RDF::Trine::Node::Blank->new($x);
	},
	literal		 => \&_json_literal,
	'typed-literal' => \&_json_literal,
);

sub get_sparql {
	my $self	= shift;
	my $sparql	= shift;
	my $handler	= RDF::Trine::Iterator::SAXHandler->new();
	my $p		= XML::SAX::ParserFactory->parser(Handler => $handler);
	my $ua		= $self->{ua};
	
# 	warn $sparql;
	
	my $urlchar	= ($self->{url} =~ /\?/ ? '&' : '?');
	my $url		= $self->{url} . $urlchar . 'query=' . uri_escape($sparql);
	my $response	= $ua->get( $url );
	if ($response->is_success) {
		my $type = lc $response->content_type;
		if ($type =~ /xml/) {
			my $handler	= RDF::Trine::Iterator::SAXHandler->new();
			my $p		= XML::SAX::ParserFactory->parser(Handler => $handler);
			$p->parse_string( $response->content );
			return $handler->iterator;
		}
		elsif ($type =~ /json/) {
			#warn $response->as_string;
			require JSON;
			my $js = JSON->new->decode($response->content);
			#warn Dumper($js);
			my @names = @{$js->{head}{vars} || []};
			my @b = @{$js->{results}{bindings} || []};
			return RDF::Trine::Iterator::Bindings->new(
				sub {
					return unless my $x = shift @b;
					return { map {
						($_ => $JSON{$x->{$_}{type}}->($x->{$_}) ) } keys %$x };
				},
				\@names);
		}
		# elsif ($type =~ m!text/csv!) {
		# 	warn $response->as_string;
		# 	# XXX CSV would parse way faster but you can't tell what
		# 	# the damn results are.
		# 	require IO::Scalar;
		# 	require Text::CSV;
		# 	my $csv = Text::CSV->new({ binary => 1 });
		# 	my $fh  = IO::Scalar->new($response->content_ref);
		# 	my @names = $csv->getline($fh);
		# 	$csv->column_names(@names);
		# 	return RDF::Trine::Iterator::Bindings->new
		# 		(sub { $csv->getline_hr($fh) }, \@names);
		# }
	} else {
		my $status		= $response->status_line;
		my $endpoint	= $self->{url};
#		warn "url: $url\n";
#		warn $sparql;
		warn Dumper($response);
		throw RDF::Trine::Error -text => "Error making remote SPARQL call to endpoint $endpoint ($status)";
	}
}

sub _get_post_iterator {
	my $self	= shift;
	my $sparql	= shift;
	my $ua		= $self->{ua};
	
# 	warn $sparql;
	
	my $url			= $self->{url};
	my $response	= $ua->post( $url, query => $sparql );
	if ($response->is_success) {
		warn $response->content;
		my $type = lc $response->content_type;
		if ($type =~ /xml/) {
			my $handler	= RDF::Trine::Iterator::SAXHandler->new();
			my $p		= XML::SAX::ParserFactory->parser(Handler => $handler);
			$p->parse_string( $response->content );
			return $handler->iterator;
		}
		elsif ($type =~ /turtle/) {
			#warn $response->content;
			my $p = RDF::Trine::Parser->new('turtle');
			my $m = RDF::Trine::Model->temporary_model;
		}
		else {
			warn $response->content;
		}
	} else {
		my $status		= $response->status_line;
		my $endpoint	= $self->{url};
#		warn "url: $url\n";
#		warn $sparql;
		warn Dumper($response);
		throw RDF::Trine::Error -text => "Error making remote SPARQL call to endpoint $endpoint ($status)";
	}
}

sub _bulk_ops {
	my $self	= shift;
	return $self->{BulkOps};
}

sub _begin_bulk_ops {
	my $self			= shift;
	$self->{BulkOps}	= 1;
}

sub _end_bulk_ops {
	my $self			= shift;
	if (scalar(@{ $self->{ ops } || []})) {
		#warn scalar @{$self->{ops}};
		my @ops	= splice(@{ $self->{ ops } });
		#warn scalar @ops;
		my @aggops	= $self->_group_bulk_ops( @ops );
		my @sparql;
		#warn Dumper(@aggops);
		foreach my $aggop (@aggops) {
			my ($type, @ops)	= @$aggop;
			#warn 'wtf ' . scalar @ops;
			my $method	= "${type}_sparql";
			push(@sparql, $self->$method( @ops ));
		}
		my $sparql	= join(";\n", @sparql);
		#warn $sparql;
		my $iter	= $self->_get_post_iterator( $sparql );
		my $row		= $iter->next;
	}
	$self->{BulkOps}	= 0;
}

sub _group_bulk_ops {
	my $self	= shift;
	return unless (scalar(@_));
	my @ops		= @_;

	my %agg;
	for my $op (@ops) {
		# collate operations with a hash
		my $x = $agg{$op->[0]} ||= [];
		# add them as array ref
		push @$x, [@{$op}[1..$#$op]];
	}

	#warn Dumper(\%agg);
	# unwind the contents
	return map { [$_ => @{$agg{$_}}] } keys %agg;
}

sub _results {
	my ($iter, $which) = @_;
	my @out;
	while (my $stmt = $iter->next) {
		my @n = $stmt->nodes;
		push @out, $n[$which];
	}
	@out;
}

sub _subjects {
	my $self = shift;
	my @nodes = (undef, @_);

	_results($self->get_statements(@nodes), 0);
}

sub _predicates {
	my $self = shift;
	my @nodes = @_;
	splice @nodes, 1, 0, undef;

	_results($self->get_statements(@nodes), 1);
}

sub _objects {
	my $self = shift;
	my @nodes = @_;
	splice @nodes, 2, 0, undef;

	_results($self->get_statements(@nodes), 2);
}

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
