=head1 NAME

RDF::Trine::Store::SPARQL - RDF Store proxy for a SPARQL endpoint

=head1 VERSION

This document describes RDF::Trine::Store::SPARQL version 1.008

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

use Scalar::Util qw(refaddr reftype blessed);
use HTTP::Request::Common;
use RDF::Trine::Error qw(:try);

######################################################################

my @pos_names;
our $VERSION;
BEGIN {
	$VERSION	= "1.008";
	my $class	= __PACKAGE__;
	$RDF::Trine::Store::STORE_CLASSES{ $class }	= $VERSION;
	@pos_names	= qw(subject predicate object context);
}

######################################################################

=head1 METHODS

Beyond the methods documented below, this class inherits methods from the
L<RDF::Trine::Store> class.

=head2 C<< new ( $url [, $user, $pass, $options ] ) >>

Returns a new storage object that will act as a proxy for the SPARQL
endpoint accessible via the supplied C<$url>. Optionally, an
authentication realm, username and password can be supplied.

=head2 C<new_with_config ( $hashref )>

Returns a new storage object configured with a hashref with certain
keys as arguments.

The C<storetype> key must be C<SPARQL> for this backend.

The following key must also be used:

=head3 C<url>

The URL of the remote endpoint.

And these optional keys:

=head3 C<user>

The username to authenticate with.

=head3 C<password>

The user's password.

=head3 C<options>

There are a number of options to further tune the connection to the
SPARQL endpoint,

=over 4

=item realm

The HTTP authentication realm will be detected when the store is
constructed, but you can skip this step and supply one if you already
know what it is.

=item context

Some endpoints (such as Virtuoso) require a default context for
C<INSERT> and C<DELETE> operations.

=item skolemize

Skolemize blank nodes into IRIs. This should be a CODE reference that
returns an L<RDF::Trine::Node::Resource> object.

=item deskolemize

Do the same thing in the opposite direction. This should be a CODE
reference that returns an L<RDF::Trine::Node::Blank> object.

=item legacy

Set this bit to turn on legacy SPARUL C<INSERT> and C<DELETE> syntax,
to properly communicate with endpoints that support only it.

=item product

The product string overrides a number of behaviours peculiar to a
given endpoint. Currently the only supported product is C<virtuoso>.

=back

=cut

# This structure takes the form product => [ \&skolemize, \&deskolemize ]
my %SKOLEM = (
	virtuoso => [
		sub {
			# assume blank node
			RDF::Trine::Node::Resource->new
				  ('nodeID://' . shift->blank_identifier);
		},
		sub {
			# assume resource
			my ($name) = (shift->uri_value =~ m!nodeID://(.*)!);
			RDF::Trine::Node::Blank->new($name);
		},
	],
);

sub new {
	my $class	= shift;
	my $url		= shift;
	my $user	= shift;
	my $pass	= shift;
	my $options = shift || {};

	my $u		= RDF::Trine->default_useragent->clone;

	# cloning scrubs this away
	$u->conn_cache({ total_capacity => 1 });

	# set up access credentials
	$url = URI->new($url)->canonical;
	if (defined $user) {
		my $realm = $options->{realm};
		unless (defined $realm and $realm ne '') {
			# get the realm
			my $resp = $u->head($url);
			if (my $auth = $resp->www_authenticate) {
				my ($tok) = ($auth =~ /realm\s*=\s*("[^"]*"|'[^']*'|\S+)/i);
				$tok =~ s/^['"]?(.*?)['"]?,?$/$1/;
				$realm = $tok;
			}
		}
		$u->credentials($url->host_port, $realm, $user, $pass);
	}

	if (defined $options->{product}) {
		if (lc $options->{product} eq 'virtuoso') {
			# do virtuoso-specific stuff
			$options->{legacy} = 1;
			$options->{skolemize}   ||= $SKOLEM{virtuoso}[0];
			$options->{deskolemize} ||= $SKOLEM{virtuoso}[1];
			$options->{context} ||= RDF::Trine::Node::Nil->new;
		}
	}

	# XXX virtuoso endpoint doesn't pay attention to the q-values
	#my @accept = qw(application/sparql-results+xml;q=0.9
	#				application/rdf+xml;q=0.7);
	#my @accept = qw(application/sparql-results+json;0.7
	my @accept = qw(application/rdf+json application/sparql-results+json);
	$u->default_headers->push_header('Accept' => join(', ', @accept));

	# virtuoso sparql won't work without a default context
	if (defined (my $context = $options->{context})) {
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
		$options->{context} = $context;
	}

	my $self	= bless({
		ua		=> $u,
		url		=> $url,
		options => $options,
	}, $class);
	return $self;
}

sub _new_with_string {
	my $class	= shift;
	my $config	= shift;
	return $class->new( $config );
}

=head2 C<< new_with_config ( \%config ) >>

Returns a new RDF::Trine::Store object based on the supplied
configuration hashref.

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
	return $class->new(@{$config}{qw(url user password options)});
}

sub _config_meta {
	return {
		required_keys	=> [qw(url)],
		fields			=> {
			url => { description => 'Endpoint URL', type => 'string' },
#			context => { description => 'Default context', type => 'string' },
#			realm => { description => 'Authentication realm', type => 'string' },
			user => { description => 'User name' , type => 'string' },
			password => { description => 'Password', type => 'string' },
			options => { description => 'Misc. Options', type => 'hashref' },
#			legacy => { description => 'Use legacy syntax', type => 'int' },
		}
	}
}


=head2 C<< get_statements ( $subject, $predicate, $object [, $context] ) >>

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
	my $nodes	= join(' ', map {
		($_->is_variable) ? '?' . $_->name : $_->as_ntriples } @triple);

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
	my $format	= 'SELECT DISTINCT %s WHERE { %s %s }';
	if ($use_quad) {
		my $g	= $nodes[3]->is_variable ? '?g' : $nodes[3]->as_ntriples;
		# yo dawg i herd u liek formats so we put a format in yo format
		$format	= sprintf 'SELECT DISTINCT %%s WHERE { GRAPH %s { %%s } %%s }', $g;
	}
	#warn 'wat';
	# create the iterator
	$names = '*' unless $names;
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

=head2 C<< get_pattern ( $bgp [, $context] ) >>

Returns an iterator object of all bindings matching the specified
graph pattern.

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
		#warn $bgp->sse;
		return $self->SUPER::_get_pattern( $bgp, $context, @args );
		throw RDF::Trine::Error::UnimplementedError -text => "SPARQL get_pattern quad support not implemented";
	}

	my $sparql	= <<"END";
SELECT DISTINCT * WHERE {
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

=head2 C<< get_contexts >>

Returns an RDF::Trine::Iterator over the RDF::Trine::Node objects
comprising the set of contexts of the stored quads.

=cut

sub get_contexts {
	my $self	= shift;
	my $sparql	= 'SELECT DISTINCT ?g WHERE { GRAPH ?g { ?s ?p ?o } }';
	my $iter	= $self->get_sparql( $sparql );
	my $sub	= sub {
		my $row	= $iter->next;
		return unless $row;
		my $g	= $row->{g};
		return $g;
	};
	return RDF::Trine::Iterator->new( $sub );
}

=head2 C<< add_statement ( $statement [, $context] ) >>

Adds the specified C<$statement> to the underlying model.

=cut

sub add_statement {
	my $self	= shift;
	my $st		= shift;
	my $context	= shift;
	unless (blessed($st) and $st->isa('RDF::Trine::Statement')) {
		throw RDF::Trine::Error::MethodInvocationError -text => "Not a valid statement object passed to add_statement";
	}

	if (defined $context) {
		unless (blessed($context) and $context->isa('RDF::Trine::Node')) {
			throw RDF::Trine::Error::MethodInvocationError
				-text => "Invalid context $context passed to add_statement";
		}
		if ($st->isa('RDF::Trine::Statement::Quad')) {
			throw RDF::Trine::Error::MethodInvocationError
				-text => "Adding a quad with a context is ambiguous.";
		}
	}

	if ($self->_bulk_ops) {
		push(@{ $self->{ ops } }, ['_add_statements', $st, $context]);
	} else {
		my $sparql	= $self->_add_statements_sparql( [ $st, $context ] );
		#warn $sparql;
		my $iter	= $self->_get_post_iterator( $sparql );
		my $row		= $iter->next;
	}
	return;
}

sub _skolemize {
	my ($self, $node) = @_;
	return $node unless defined $node && $node->is_blank;
	if (my $sk = $self->{options}{skolemize}) {
		return $sk->($node);
	}
	$node;
}

sub _deskolemize {
	my ($self, $node) = @_;
	return $node unless defined $node;
	if (my $dsk = $self->{options}{deskolemize}) {
		return $dsk->($node);
	}
	$node;
}

sub _add_statements_sparql {
	my $self	= shift;
	my @parts;
	my %c;
	foreach my $op (@_) {
		my $st		= $op->[0];

		my ($s, $p, $o, $c) = $st->nodes;
		# quad context supersedes argument context
		$c ||= $op->[1] || $self->{options}{context};
		# default context

		my $x = $c{$c ? $self->_skolemize($c)->as_ntriples : ''} ||= [];

		my $pat = sprintf '%s %s %s .',
			map { $self->_skolemize($_)->as_ntriples } ($s, $p, $o);
		push @$x, $pat;
	}

	my $sparql = '';
	if ($self->{options}{legacy}) {
		for my $k (sort keys %c) {
			my @parts = @{$c{$k}};
			my $stmts = join ("\n\t", @parts);
			$sparql .= $k ? "INSERT INTO GRAPH $k \{$stmts\}\n"
				: "INSERT \{$stmts\}\n";
		}
	}
	else {
		$sparql = "INSERT DATA {\n";
		for my $k (sort keys %c) {
			my @parts = @{$c{$k}};
			my $stmts = join("\n\t", @parts);
			$sparql .= $k ? "GRAPH $k \{$stmts\n\}" : $stmts;
		}
		$sparql .= "\n}";
	}

	return $sparql;
}

=head2 C<< remove_statement ( $statement [, $context]) >>

Removes the specified C<$statement> from the underlying model.

=cut

sub remove_statement {
	my $self	= shift;
	my $st		= shift;
	my $context	= shift;

	unless (blessed($st) and $st->isa('RDF::Trine::Statement')) {
		throw RDF::Trine::Error::MethodInvocationError
			-text => "Not a valid statement object passed to remove_statement";
	}

	if (defined $context) {
		unless (blessed($context) and $context->isa('RDF::Trine::Node')) {
			throw RDF::Trine::Error::MethodInvocationError
				-text => "Invalid context $context passed to remove_statement";
		}
		if ($st->isa('RDF::Trine::Statement::Quad')) {
			throw RDF::Trine::Error::MethodInvocationError
				-text => "Removing a quad with a context is ambiguous.";
		}
	}

	if ($self->_bulk_ops) {
		push(@{ $self->{ ops } }, ['_remove_statements', $st, $context]);
	} else {
		my $sparql	= $self->_remove_statements_sparql( [ $st, $context ] );
		#warn $sparql;
		my $iter	= $self->_get_post_iterator( $sparql );
		my $row		= $iter->next;
	}
	return;
}

sub _remove_statements_sparql {
	my $self	= shift;
	my @parts;
	my %c;
	foreach my $op (@_) {
		my $st		= $op->[0];

		my ($s, $p, $o, $c) = $st->nodes;
		# quad context supersedes argument context
		$c ||= $op->[1] || $self->{options}{context};
		# default context

		my $x = $c{$c ? $self->_skolemize($c)->as_ntriples : ''} ||= [];

		my $pat = sprintf '%s %s %s .',
			map { $self->_skolemize($_)->as_ntriples } ($s, $p, $o);
		push @$x, $pat;
	}

	my $sparql = '';
	if ($self->{options}{legacy}) {
		for my $k (sort keys %c) {
			my @parts = @{$c{$k}};
			my $stmts = join ("\n\t", @parts);
			$sparql .= $k ? "DELETE FROM GRAPH $k \{$stmts\}\n"
				: "DELETE \{$stmts\}\n";
		}
	}
	else {
		$sparql = "DELETE DATA {\n";
		for my $k (sort keys %c) {
			my @parts = @{$c{$k}};
			my $stmts = join("\n\t", @parts);
			$sparql .= $k ? "GRAPH $k \{$stmts\n\}" : $stmts;
		}
		$sparql .= "\n}";
	}

	return $sparql;
}

=head2 C<< remove_statements ( $subject, $predicate, $object [, $context]) >>

Removes statements matching the given nodes from the underlying model.

=cut

sub remove_statements {
	my ($self, @nodes) = @_;

	for my $n (@nodes) {
		throw RDF::Trine::Error::MethodInvocationError
			-text => "Not a valid node object passed to remove_statements"
				if defined $n
					and not blessed($n) && $n->isa('RDF::Trine::Node');
	}

	my %n;
	(@n{qw(s p o)}, my $context) = @nodes;
	$context ||= RDF::Trine::Node::Variable->new('g');

	my $st = RDF::Trine::Statement->new
		(map { $n{$_} || RDF::Trine::Node::Variable->new($_) } qw(s p o));

	if ($self->_bulk_ops) {
		push(@{ $self->{ ops } }, ['_remove_statement_patterns', $st, $context]);
	} else {
		my $sparql	= $self->_remove_statement_patterns_sparql( [ $st, $context ] );
		#warn $sparql;
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

		my ($s, $p, $o, $c) = $st->nodes;
		# quad context supersedes argument context
		$c ||= $op->[1] || $self->{options}{context};
		# default context

		my $pat = sprintf '%s %s %s .',
			map { $_->is_variable ? '?' . $_->name :
					  $self->_skolemize($_)->as_ntriples }
				($s, $p, $o);
		$pat = sprintf 'GRAPH %s { %s }',
			($c->is_variable ? '?' . $c->name : $self->_skolemize($c)->as_ntriples), $pat if $c;

		push @parts, $pat;
	}

	my $sparql	= sprintf( 'DELETE WHERE { %s }', join("\n\t", @parts) );
	return $sparql;
}

=head2 C<< count_statements ( $subject, $predicate, $object, $context ) >>

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
	my $triple	= join(' ', map { $_->is_variable ? '?' . $_->name : $self->_skolemize($_)->as_ntriples } @nodes[0..2]);
	if ($use_quad) {
		my $default = $self->{options}{context};
		my $nodes;
		if ($nodes[3]->isa('RDF::Trine::Node::Variable')) {
			$nodes		= "GRAPH ?rt__graph { $triple }";
		}
		# XXX not sure what to do here re default graph
		elsif ($nodes[3]->isa('RDF::Trine::Node::Nil')
				   and !defined($default) or !$default->is_nil) {
			$nodes	= join(' ', map { $_->is_variable ? '?' . $_->name : $self->_skolemize($_)->as_ntriples } @nodes[0..2]);
		} else {
			my $graph	= $nodes[3]->is_variable ? '?' . $nodes[3]->name : $self->_skolemize($nodes[3])->as_ntriples;
			$nodes		= "GRAPH $graph { $triple }";
		}
		$sparql	= "SELECT (COUNT(*) AS ?count) WHERE { $nodes }";
	} else {
		$sparql	= "SELECT (COUNT(*) AS ?count) WHERE { SELECT DISTINCT $triple WHERE { $triple } }";
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

=head2 C<< size >>

Returns the number of statements in the store.

=cut

sub size {
	my $self	= shift;
	return $self->count_statements( undef, undef, undef, undef );
}

=head2 C<< supports ( [ $feature ] ) >>

If C<< $feature >> is specified, returns true if the feature is
supported by the store, false otherwise. If C<< $feature >> is not
specified, returns a list of supported features.

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

=head2 C<< get_sparql ( $sparql ) >>

Returns an iterator object of all bindings matching the specified
SPARQL query.

=cut

sub _json_maybe_blank {
	my $str = shift;
	$str =~ m!^(_:|nodeID://)(.*?)$!i;
	return RDF::Trine::Node::Blank->new($2) if defined $1;
	return RDF::Trine::Node::Resource->new($str);
}

sub _json_literal {
	RDF::Trine::Node::Literal->new(@{$_[0]}{qw(value lang datatype)});
}
my %JSON = (
	uri			 => sub { RDF::Trine::Node::Resource->new($_[0]{value}) },
	bnode		   => sub { _json_maybe_blank($_[0]{value}) },
	literal			=> \&_json_literal,
	'typed-literal' => \&_json_literal,
);

sub _json_sparql_results {
	my $content = shift;
	require JSON;
	my $js = eval { JSON->new->decode($$content) };
	throw RDF::Trine::Error -text => $@ if $@;

	if ($js->{head} && $js->{results} && $js->{results}{bindings}) {
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
	else {
		throw RDF::Trine::Error -text => "Malformed JSON response: $content";
	}
}

sub _json_graph_results {
	my $content = shift;

	require JSON;
	my $js = eval { JSON->new->decode($$content) };
	throw RDF::Trine::Error -text => $@ if $@;

	# The form of the JSON blob is { s => { p => [\%o] } } .

	# That is, there is an ARRAY ref of object hashes inside a HASH
	# ref keyed by predicate, inside a HASH ref keyed by subject.

	# The problem is we need to turn this structure into an
	# iterator of RDF::Trine::Statement objects.

	# We can use the ARRAY refs as queues, and Perl hash objects
	# have an internal iteration state which can be accessed by
	# the 'each' operator. This naturally means that the state
	# should remain outside the closure.

	my ($s, $p, %sh, %ph, @ol);
	%sh = %$js;

	# shift off the first object and return a statement
	# if we run out of objects, we get the next predicate
	# if we run out of predicates, we get the next subject

	# advance s
	my $as = sub {
		my ($k, $v) = each %sh or return;
		throw RDF::Trine::Error
			-text => 'Malformed JSON' unless $v && ref $v eq 'HASH';
		%ph = %$v;

		_json_maybe_blank($k);
	};

	# advance p
	my $ap = sub {
		my ($k, $v) = each %ph or return;
		throw RDF::Trine::Error
			-text => 'Malformed JSON' unless $v && ref $v eq 'ARRAY';
		@ol = @$v;

		RDF::Trine::Node::Resource->new($k);
	};

	# wind these forward now
	$s = $as->();
	$p = $ap->();

	my $osub = sub {
		my $oh = shift @ol or return;
		my $o = $JSON{$oh->{type}}->($oh);
		return RDF::Trine::Statement->new($s, $p, $o);
	};

	my $psub = sub {
		my $stmt = $osub->();
		return $stmt if $stmt;

		$p = $ap->() or return;

		return $osub->();
	};

	my $sub = sub {
		my $stmt = $psub->();
		return $stmt if $stmt;

		unless ($s = $as->()) {
			undef $js;
			undef $s;
			undef $p;
			undef %sh;
			undef %ph;
			undef @ol;
			undef $as;
			undef $ap;
			undef $osub;
			undef $psub;
			return;
		}

		$stmt = $psub->();
		return $stmt if $stmt;
		undef $js;
		undef $s;
		undef $p;
		undef %sh;
		undef %ph;
		undef @ol;
		undef $as;
		undef $ap;
		undef $osub;
		undef $psub;
		return;
	};

	return RDF::Trine::Iterator::Graph->new($sub);
}

my %DISPATCH = (
	'application/sparql-results+xml' => sub {
		my $cref = shift;
		my $handler	= RDF::Trine::Iterator::SAXHandler->new( {
			generate_blank_id => sub {
				my $string	= shift;
				$string =~ s!nodeID://!!;
				return $string;
			}
		});
		my $p		= XML::SAX::ParserFactory->parser(Handler => $handler);
		$p->parse_string($$cref);
		return $handler->iterator;
	},
	'application/sparql-results+json' => \&_json_sparql_results,
	'application/rdf+json'			=> \&_json_graph_results,
);

# XXX yo is the only difference between these two methods the HTTP method?

sub get_sparql {
	my $self	= shift;
	my $sparql	= shift;
	#my $handler	= RDF::Trine::Iterator::SAXHandler->new();
	#my $p		= XML::SAX::ParserFactory->parser(Handler => $handler);
	my $ua		= $self->{ua};

	#warn $sparql;

	my $urlchar	= ($self->{url} =~ /\?/ ? '&' : '?');
	my $url		= $self->{url} . $urlchar . 'query=' . uri_escape($sparql);
	my $response	= $ua->get( $url );
	if ($response->is_success) {
		my $type = lc $response->content_type;
		($type) = split /\s*;\s*/, $type;
		#warn $response->content;
		if ($DISPATCH{$type}) {
			return $DISPATCH{$type}->($response->content_ref);
		}
		else {
			throw RDF::Trine::Error -text => "Unsupported response type $type";
		}
	}
	else {
		my $status		= $response->status_line;
		my $endpoint	= $self->{url};
#		warn "url: $url\n";
#		warn $sparql;
		#warn Dumper($response);
		throw RDF::Trine::Error
			-text => "Error making remote SPARQL call to endpoint $endpoint ($status):\n" . $response->content;
	}
}

sub _get_post_iterator {
	my $self	= shift;
	my $sparql	= shift;
	my $ua		= $self->{ua};

	my $url			= $self->{url};
	my $response	= $ua->post( $url, { query => $sparql } );
	# first the response has to be successful
	# then the response has to be an acceptable content-type
	# then the response body has to be well-formed
	if ($response->is_success) {
		# clip off any parameters on the content-type
		my $type = lc $response->content_type;
		($type) = split /\s*;\s*/, $type;
		# XXX this should be a dispatch table
		# it IS a dispatch table!
		if ($DISPATCH{$type}) {
			return $DISPATCH{$type}->($response->content_ref);
		}
		else {
			throw RDF::Trine::Error -text => "Unsupported response type $type";
		}
	}
	else {
		my $status		= $response->status_line;
		my $endpoint	= $self->{url};
#		warn "url: $url\n";
#		warn $sparql;
		#warn Dumper($response);
		throw RDF::Trine::Error -text => "Error making remote SPARQL call to endpoint $endpoint ($status):\n" . $response->content;
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
