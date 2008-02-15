# RDF::Query
# -------------
# $Revision: 306 $
# $Date: 2007-12-12 21:26:57 -0500 (Wed, 12 Dec 2007) $
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query - An RDF query implementation of SPARQL/RDQL in Perl for use with RDF::Redland and RDF::Core.

=head1 VERSION

This document describes RDF::Query version 1.502, released XX December 2007.

=head1 SYNOPSIS

 my $query = new RDF::Query ( $rdql, undef, undef, 'rdql' );
 my @rows = $query->execute( $model );
 
 my $query = new RDF::Query ( $sparql, undef, undef, 'sparql' );
 my $iterator = $query->execute( $model );
 while (my $row = $iterator->()) {
   ...
 }

=head1 DESCRIPTION

RDF::Query allows RDQL and SPARQL queries to be run against an RDF model, returning rows
of matching results.

See L<http://www.w3.org/TR/rdf-sparql-query/> for more information on SPARQL.
See L<http://www.w3.org/Submission/2004/SUBM-RDQL-20040109/> for more information on RDQL.

=head1 REQUIRES

L<RDF::Redland|RDF::Redland> or L<RDF::Core|RDF::Core>

L<Parse::RecDescent|Parse::RecDescent> (for RDF::Core)

L<LWP|LWP>

L<DateTime::Format::W3CDTF|DateTime::Format::W3CDTF>

L<Scalar::Util|Scalar::Util>

L<I18N::LangTags|I18N::LangTags>

L<Storable|Storable>

L<List::Utils|List::Utils>

L<RDF::Trine::Iterator|RDF::Trine::Iterator>

=cut

package RDF::Query;

use strict;
use warnings;
use Carp qw(carp croak confess);

use Data::Dumper;
use LWP::UserAgent;
use I18N::LangTags;
use Storable qw(dclone);
use List::Util qw(first);
use List::MoreUtils qw(uniq);
use Scalar::Util qw(blessed reftype looks_like_number);
use DateTime::Format::W3CDTF;
use RDF::Trine::Iterator qw(sgrep smap swatch);

use RDF::Query::Functions;	# all the built-in functions including:
							#     datatype casting, language ops, logical ops,
							#     numeric ops, datetime ops, and node type testing
							# also, custom functions including:
							#     jena:sha1sum, jena:now, jena:langeq, jena:listMember
							#     ldodds:Distance, kasei:warn
use RDF::Query::Algebra;
use RDF::Query::Node;
use RDF::Query::Parser::RDQL;
use RDF::Query::Parser::SPARQL;
use RDF::Query::Parser::tSPARQL;	# XXX temporal extensions
use RDF::Query::Compiler::SQL;
use RDF::Query::Error qw(:try);

######################################################################

our ($REVISION, $VERSION, $debug, $js_debug, $DEFAULT_PARSER);
use constant DEBUG	=> 0;
BEGIN {
	$debug		= DEBUG;
	$js_debug	= 0;
	$REVISION	= do { my $REV = (qw$Revision: 306 $)[1]; sprintf("%0.3f", 1 + ($REV/1000)) };
	$VERSION	= '1.502';
	$ENV{RDFQUERY_NO_RDFBASE}	= 1;	# XXX Not ready for release
	$DEFAULT_PARSER		= 'sparql';
}

our %PATTERN_TYPES	= map { $_ => 1 } (qw(
						BGP
						GGP
						GRAPH
						OPTIONAL
						UNION
						TRIPLE
					));
my $KEYWORD_RE	= qr/^(BGP|GGP|OPTIONAL|UNION|GRAPH|FILTER|TIME)$/;

######################################################################

=head1 METHODS

=over 4

=item C<new ( $query, $baseuri, $languri, $lang )>

Returns a new RDF::Query object for the query specified.
The query language used will be set if $languri or $lang
is passed as the URI or name of the query language, otherwise
the query defaults to SPARQL.

=cut
sub new {
	my $class	= shift;
	my ($query, $baseuri, $languri, $lang, %options)	= @_;
	$class->clear_error;
	
	my $f	= DateTime::Format::W3CDTF->new;
	no warnings 'uninitialized';
	
	my %names	= (
					rdql	=> 'RDF::Query::Parser::RDQL',
					sparql	=> 'RDF::Query::Parser::SPARQL',
					tsparql	=> 'RDF::Query::Parser::tSPARQL',
				);
	my %uris	= (
					'http://jena.hpl.hp.com/2003/07/query/RDQL'	=> 'RDF::Query::Parser::RDQL',
					'http://www.w3.org/TR/rdf-sparql-query/'	=> 'RDF::Query::Parser::SPARQL',
				);
	
	
	my $pclass	= $names{ $lang } || $uris{ $languri } || $names{ $DEFAULT_PARSER };
	my $parser	= $pclass->new();
#	my $parser	= ($lang eq 'rdql' or $languri eq 'http://jena.hpl.hp.com/2003/07/query/RDQL')
#				? RDF::Query::Parser::RDQL->new()
#				: RDF::Query::Parser::SPARQL->new();
	my $parsed	= $parser->parse( $query );
	
	my $ua		= LWP::UserAgent->new( agent => "RDF::Query/${VERSION}" );
	my $self 	= bless( {
					base			=> $baseuri,
					dateparser		=> $f,
					parser			=> $parser,
					parsed			=> $parsed,
					parsed_orig		=> $parsed,
					named_models	=> {},
					useragent		=> $ua,
				}, $class );
	unless ($parsed->{'triples'}) {
		$class->set_error( $parser->error );
		warn $parser->error if ($debug);
		return;
	}
	
	if ($options{net_filters}) {
		require JavaScript;
		$self->{options}{net_filters}++;
	}
	if ($options{trusted_keys}) {
		require Crypt::GPG;
		$self->{options}{trusted_keys}	= $options{trusted_keys};
	}
	if ($options{gpg}) {
		$self->{_gpg_obj}	= delete $options{gpg};
	}
	if (defined $options{keyring}) {
		$self->{options}{keyring}	= $options{keyring};
	}
	if (defined $options{secretkey}) {
		$self->{options}{secretkey}	= $options{secretkey};
	}
	
	# add rdf as a default namespace to RDQL queries
	if ($pclass eq 'RDF::Query::Parser::RDQL') {
		$self->{parsed}{namespaces}{rdf}	= 'http://www.w3.org/1999/02/22-rdf-syntax-ns#';
	}
	return $self;
}

=item C<get ( $model )>

Executes the query using the specified model,
and returns the first row found.

=cut
sub get {
	my $self	= shift;
	my $stream	= $self->execute( @_ );
	my $row		= $stream->next;
	if (ref($row)) {
		return @{ $row }{ $self->variables };
	} else {
		return undef;
	}
}

=item C<execute ( $model, %args )>

Executes the query using the specified model. If called in a list
context, returns an array of rows, otherwise returns an iterator.

=cut
sub execute {
	my $self	= shift;
	my $model	= shift;
	my %args	= @_;
	
	local($::NO_BRIDGE)	= 0;
	$self->{parsed}	= dclone( $self->{parsed_orig} );
	my $parsed	= $self->{parsed};
	
	my $stream;
	$self->{model}		= $model;
	
	my %bound	= ($args{ 'bind' }) ? %{ $args{ 'bind' } } : ();
	my $bridge	= $self->get_bridge( $model, %args );
	if ($bridge) {
		$self->bridge( $bridge );
	} else {
		throw RDF::Query::Error::ModelError ( -text => "Could not create a model object." );
	}
	
	$self->load_data();
	my ($pattern, $cpattern)	= $self->fixup();
	$bridge		= $self->bridge();	# reload the bridge object, because fixup might have changed it.
	my @vars	= $self->variables( $parsed );
	
	# RUN THE QUERY!

	my $options	= $parsed->{options} || {};		
	$stream		= $pattern->execute( $self, $bridge, \%bound, undef, %$options );

	_debug( "got stream: $stream" ) if (DEBUG);
	my $sorted		= $self->sort_rows( $stream, $parsed );
	my $projected	= $sorted->project( @vars );
	$stream			= $projected;
#	$stream->bridge( $bridge );

	if ($parsed->{'method'} eq 'DESCRIBE') {
		$stream	= $self->describe( $stream );
	} elsif ($parsed->{'method'} eq 'CONSTRUCT') {
		$stream	= $self->construct( $stream, $cpattern, $parsed );
	} elsif ($parsed->{'method'} eq 'ASK') {
		$stream	= $self->ask( $stream );
	}
	
	if (wantarray) {
		return $stream->get_all();
	} else {
		return $stream;
	}
}

=begin private

=item C<describe ( $stream )>

Takes a stream of matching statements and constructs a DESCRIBE graph.

=end private

=cut

sub describe {
	my $self	= shift;
	my $stream	= shift;
	my $bridge	= $self->bridge;
	my @nodes;
	my %seen;
	while (my $row = $stream->next) {
		foreach my $node (values %$row) {
			push(@nodes, $node) unless ($seen{ $bridge->as_string( $node ) }++);
		}
	}
	
	my @streams;
	$self->{'describe_nodes'}	= [];
	foreach my $node (@nodes) {
		push(@{ $self->{'describe_nodes'} }, $node);
		push(@streams, $bridge->get_statements( $node, undef, undef ));
		push(@streams, $bridge->get_statements( undef, undef, $node ));
	}
	
	my $ret	= sub {
		while (@streams) {
			my $val	= $streams[0]->next;
			if (defined $val) {
				return $val;
			} else {
				shift(@streams);
				return undef if (not @streams);
			}
		}
	};
	return RDF::Trine::Iterator::Graph->new( $ret, bridge => $bridge );
}

=begin private

=item C<construct ( $stream )>

Takes a stream of matching statements and constructs a result graph matching the
uery's CONSTRUCT graph patterns.

=end private

=cut

sub construct {
	my $self		= shift;
	my $stream		= shift;
	my $ctriples	= shift;
	my $parsed		= shift;
	my $bridge		= $self->bridge;
	my @streams;
	
	my %seen;
	my %variable_map;
	foreach my $var_count (0 .. $#{ $parsed->{'variables'} }) {
		$variable_map{ $parsed->{'variables'}[ $var_count ]->name }	= $var_count;
	}
	
	while (my $row = $stream->next) {
		my %blank_map;
		my @triples;	# XXX move @triples out of the while block, and only push one stream below (just before the continue{})
		TRIPLE: foreach my $triple ($ctriples->patterns) {
			my @triple	= $triple->nodes;
			for my $i (0 .. 2) {
				if (blessed($triple[$i]) and $triple[$i]->isa('RDF::Query::Node')) {
					if ($triple[$i]->isa('RDF::Query::Node::Variable')) {
						my $name	= $triple[$i]->name;
						$triple[$i]	= $row->{ $name };
					} elsif ($triple[$i]->isa('RDF::Query::Node::Blank')) {
						my $id	= $triple[$i]->blank_identifier;
						unless (exists($blank_map{ $id })) {
							$blank_map{ $id }	= $self->bridge->new_blank();
						}
						$triple[$i]	= $blank_map{ $id };
					}
				}
			}
			
			foreach (@triple) {
				if (not blessed($_)) {
					next TRIPLE;
				}
			}
			
			my $st	= $bridge->new_statement( @triple );
			push(@triples, $st);
		}
		push(@streams, RDF::Trine::Iterator::Graph->new( sub { shift(@triples) } ));
	}
	
	
	my $ret	= sub {
		while (@streams) {
			my $val	= $streams[0]->next;
			if (defined $val) {
				return $val;
			} else {
				shift(@streams);
				return undef if (not @streams);
			}
		}
		return undef;
	};
	return RDF::Trine::Iterator::Graph->new( $ret, bridge => $bridge );
}

=begin private

=item C<ask ( $stream )>

Takes a stream of matching statements and returns a boolean query result stream.

=end private

=cut

sub ask {
	my $self	= shift;
	my $stream	= shift;
	my $value	= $stream->next;
	my $bool	= ($value) ? 1 : 0;
	return RDF::Trine::Iterator::Boolean->new( [ $bool ], bridge => $self->bridge );
}

######################################################################

=item C<< aggregate ( \@groupby, $alias => [ $op, $col ] ) >>

=cut

sub aggregate {
	my $self	= shift;
	my $groupby	= shift;
	my %aggs	= @_;
	my $pattern	= $self->pattern;
	my $agg		= RDF::Query::Algebra::Aggregate->new( $pattern, $groupby, %aggs );
	$self->{parsed}{triples}	= [ $agg ];
	$self->{parsed}{'variables'}	= [ map { RDF::Query::Node::Variable->new( $_ ) } (@$groupby, keys %aggs) ];
}

=item C<< pattern >>

Returns the RDF::Query::Algebra::GroupGraphPattern algebra pattern for this query.

=cut

sub pattern {
	my $self	= shift;
	my $parsed	= $self->parsed;
	my @triples	= @{ $parsed->{triples} };
	if (scalar(@triples) == 1 and ($triples[0]->isa('RDF::Query::Algebra::GroupGraphPattern') or $triples[0]->isa('RDF::Query::Algebra::Filter'))) {
		my $ggp		= $triples[0];
		return $ggp;
	} else {
		return RDF::Query::Algebra::GroupGraphPattern->new( @triples );
	}
}

=item C<< construct_pattern >>

Returns the RDF::Query::Algebra::GroupGraphPattern algebra pattern for this query's CONSTRUCT block.

=cut

sub construct_pattern {
	my $self	= shift;
	my $parsed	= $self->parsed;
	my @triples	= @{ $parsed->{construct_triples} };
	my $ggp		= RDF::Query::Algebra::GroupGraphPattern->new( @triples );
	return $ggp;
}

=item C<< as_sparql >>

Returns the query as a string in the SPARQL syntax.

=cut

sub as_sparql {
	my $self	= shift;
	my $parsed	= $self->parsed;
	
	my $context	= { namespaces => $self->{parsed}{namespaces} };
	my $method	= $parsed->{method};
	my @vars	= map { $_->as_sparql( $context, '' ) } @{ $parsed->{ variables } };
	my $vars	= join(' ', @vars);
	my $ggp		= $self->pattern;
	
	{
		my $pvars	= join(' ', sort $ggp->referenced_variables);
		my $svars	= join(' ', sort map { $_->name } @{ $parsed->{ variables } });
		if ($pvars eq $svars) {
			$vars	= '*';
		}
	}
	
	my @ns		= map { "PREFIX $_: <$parsed->{namespaces}{$_}>" } (sort keys %{ $parsed->{namespaces} });
	my @mod;
	if (my $ob = $parsed->{options}{orderby}) {
		push(@mod, 'ORDER BY ' . join(' ', map {
					my ($dir,$v) = @$_;
					($dir eq 'ASC')
						? $v->as_sparql( $context, '' )
						: "${dir}" . $v->as_sparql( $context, '' );
				} @$ob));
	}
	if (my $l = $parsed->{options}{limit}) {
		push(@mod, "LIMIT $l");
	}
	if (my $o = $parsed->{options}{offset}) {
		push(@mod, "OFFSET $o");
	}
	my $mod	= join("\n", @mod);
	
	my $methoddata;
	if ($method eq 'SELECT') {
		my $dist	= ($parsed->{options}{distinct}) ? 'DISTINCT ' : '';
		$methoddata	= sprintf("%s %s%s\nWHERE", $method, $dist, $vars);
	} elsif ($method eq 'ASK') {
		$methoddata	= $method;
	} elsif ($method eq 'CONSTRUCT') {
		my $ctriples	= $parsed->{construct_triples};
		my $ggp			= RDF::Query::Algebra::GroupGraphPattern->new( @$ctriples );
		$methoddata		= sprintf("%s %s\nWHERE", $method, $ggp->as_sparql( $context, '' ));
	} elsif ($method eq 'DESCRIBE') {
		my $ctriples	= $parsed->{construct_triples};
		my $ggp			= RDF::Query::Algebra::GroupGraphPattern->new( @$ctriples );
		$methoddata		= sprintf("%s %s\nWHERE", $method, $vars);
	}
	
	my $sparql	= sprintf(
		"%s\n%s %s\n%s",
		join("\n", @ns),
		$methoddata,
		$ggp->as_sparql( $context, '' ),
		$mod,
	);
	
	chomp($sparql);
	return $sparql;
}

=item C<< sse >>

Returns the query as a string in the SSE syntax.

=cut

sub sse {
	my $self	= shift;
	my $parsed	= $self->parsed;
	
	my $ggp		= $self->pattern;
	my $context	= { namespaces => $self->{parsed}{namespaces} };
	my $sse	= $ggp->sse( $context, '' );
	
	chomp($sse);
	return $sse;
}

=begin private

=item C<supports ( $model, $feature )>

Returns a boolean value representing the support of $feature for the given model.

=end private

=cut

sub supports {
	my $self	= shift;
	my $model	= shift;
	my $bridge	= $self->get_bridge( $model );
	return $bridge->supports( @_ );
}

=begin private

=item C<loadable_bridge_class ()>

Returns the class name of a model backend that is present and loadable on the system.

=end private

=cut

sub loadable_bridge_class {
	my $self	= shift;
	
	if (not $ENV{RDFQUERY_NO_RDFTRICE}) {
		eval "use RDF::Query::Model::RDFTrine;";
		if (RDF::Query::Model::RDFTrine->can('new')) {
			return 'RDF::Query::Model::RDFTrine';
		} else {
			warn "RDF::Query::Model::RDFTrine didn't load cleanly" if ($debug);
		}
	} else { warn "RDF::Trine supressed" if ($debug and not $ENV{RDFQUERY_SILENT}) }
	
	if (not $ENV{RDFQUERY_NO_REDLAND}) {
		eval "use RDF::Query::Model::Redland;";
		if (RDF::Query::Model::Redland->can('new')) {
			return 'RDF::Query::Model::Redland';
		} else {
			warn "RDF::Query::Model::Redland didn't load cleanly" if ($debug);
		}
	} else { warn "RDF::Redland supressed" if ($debug and not $ENV{RDFQUERY_SILENT}) }
	
	if (not $ENV{RDFQUERY_NO_RDFCORE}) {
		eval "use RDF::Query::Model::RDFCore;";
		if (RDF::Query::Model::RDFCore->can('new')) {
			return 'RDF::Query::Model::RDFCore';
		} else {
			warn "RDF::Query::Model::RDFCore didn't load cleanly" if ($debug);
		}
	} else { warn "RDF::Core supressed" if ($debug and not $ENV{RDFQUERY_SILENT}) }
	
	return undef;
}

=begin private

=item C<new_bridge ()>

Returns a new bridge object representing a new, empty model.

=end private

=cut

sub new_bridge {
	my $self	= shift;
	
	my $bridge_class	= $self->loadable_bridge_class;
	if ($bridge_class) {
		return $bridge_class->new();
	} else {
		return undef;
	}
}

=begin private

=item C<get_bridge ( $model )>

Returns a bridge object for the specified model object.

=end private

=cut

sub get_bridge {
	my $self	= shift;
	my $model	= shift;
	my %args	= @_;
	
	my $parsed	= ref($self) ? $self->{parsed} : undef;
	
	my $bridge;
	if (not $model) {
		$bridge	= $self->new_bridge();
	} elsif (blessed($model) and ($model->isa('RDF::Trine::Store::DBI') or $model->isa('RDF::Trine::Model'))) {
		require RDF::Query::Model::RDFTrine;
		$bridge	= RDF::Query::Model::RDFTrine->new( $model, parsed => $parsed );
	} elsif (blessed($model) and $model->isa('RDF::Redland::Model')) {
		require RDF::Query::Model::Redland;
		$bridge	= RDF::Query::Model::Redland->new( $model, parsed => $parsed );
	} elsif (blessed($model) and $model->isa('RDF::Core::Model')) {
		require RDF::Query::Model::RDFCore;
		$bridge	= RDF::Query::Model::RDFCore->new( $model, parsed => $parsed );
	} else {
		require Data::Dumper;
		Carp::confess "unknown model type: " . Data::Dumper::Dumper($model);
	}
	
	return $bridge;
}

=begin private

=item C<< load_data >>

Loads any external data required by this query (FROM and FROM NAMED clauses).

=end private

=cut

sub load_data {
	my $self	= shift;
	my $bridge	= $self->bridge;
	my $parsed	= $self->{parsed};
	
	## LOAD ANY EXTERNAL RDF FILES
	my $sources	= $parsed->{'sources'};
	if (ref($sources) and reftype($sources) eq 'ARRAY') {
		my $need_new_bridge	= 1;
		my $named_query	= 0;
		foreach my $source (sort { scalar(@$b) == 2 } @{ $sources }) {
			my $named_source	= (2 == @{$source} and $source->[1] eq 'NAMED');
			if ((not $named_source) and $need_new_bridge) {
				# query uses FROM <..> clauses, so create a new bridge so we don't add the statements to a persistent default graph
				$bridge				= $self->new_bridge();
				$self->bridge( $bridge );
				$need_new_bridge	= 0;
			}
			
			my $uri	= $source->[0]->uri_value;
			$self->parse_url( $uri, $named_source );
		}
		$self->run_hook( 'http://kasei.us/code/rdf-query/hooks/post-create-model', $bridge );
	}
}


=begin private

=item C<fixup ()>

Does last-minute fix-up on the parse tree. This involves:

	* Loading any external files into the model.
	* Converting URIs and strings to model-specific objects.
	* Fixing variable list in the case of 'SELECT *' queries.

=end private

=cut

sub fixup {
	my $self	= shift;
	my $pattern	= $self->pattern;
	my $bridge	= $self->bridge;
	my $parsed	= $self->parsed;
	my $base	= $parsed->{base};
	my $namespaces	= $parsed->{namespaces};
# 	if ($base) {
# 		foreach my $ns (keys %$namespaces) {
# 			warn $namespaces->{ $ns };
# 		}
# 	}
	my $native	= $pattern->fixup( $bridge, $base, $namespaces );
	$self->{known_variables}	= map { RDF::Query::Node::Variable->new($_) } $pattern->referenced_variables;
#	$parsed->{'method'}	||= 'SELECT';
	
	## CONSTRUCT HAS IMPLICIT VARIABLES
	if ($parsed->{'method'} eq 'CONSTRUCT') {
		my @vars	= map { RDF::Query::Node::Variable->new($_) } $pattern->referenced_variables;
		$parsed->{'variables'}	= \@vars;
		my $cnative	= $self->construct_pattern->fixup( $bridge, $base, $namespaces );
		return ($native, $cnative);
	} else {
		return ($native, undef);
	}
	
	return $native;
}


=begin private

=item C<qualify_uri ( [ 'URI', [ $prefix, $localPart ] ] )>

=item C<qualify_uri ( [ 'URI', $uri )>

Returns a full URI given the URI data structure passed as an argument.
For already-qualified URIs, simply returns the URI.
For QNames, looks up the QName prefix in the parse-tree namespaces, and
concatenates with the QName local part.

=end private

=cut

sub qualify_uri {
	my $self	= shift;
	my $data	= shift;
	my $parsed	= $self->{parsed};
	my $base	= $parsed->{base};
	if ($base) {
		$base	= $base->uri_value;
	} else {
		$base	= $self->{base};
	}
	
	if (ref($data) and reftype($data) eq 'ARRAY') {
		if ($data->[0] ne 'URI') {
			$data	= ['URI',$data];
		}
	}
	
	my $uri;
	if (ref($data)) {
		if (reftype($data) eq 'ARRAY' and ref($data->[1])) {
			my $prefix	= $data->[1][0];
			unless (exists($parsed->{'namespaces'}{$data->[1][0]})) {
				_debug( "No namespace defined for prefix '${prefix}'" ) if (DEBUG);
			}
			my $ns	= $parsed->{'namespaces'}{$prefix};
			$uri	= join('', $ns, $data->[1][1]);
		} else {
			$uri	= $data->[1];
		}
	} else {
		$uri	= $data;
	}
	
	if ($base) {
		### We have to work around the URI module not accepting IRIs. If there's
		### Unicode in the IRI, pull it out, leaving behind a breadcrumb. Turn
		### the URI into an absolute URI, and then replace the breadcrumbs with
		### the Unicode.
		my @uni;
		my $count	= 0;
		while ($uri =~ /([\x{00C0}-\x{00D6}\x{00D8}-\x{00F6}\x{00F8}-\x{02FF}\x{0370}-\x{037D}\x{037F}-\x{1FFF}\x{200C}-\x{200D}\x{2070}-\x{218F}\x{2C00}-\x{2FEF}\x{3001}-\x{D7FF}\x{F900}-\x{FDCF}\x{FDF0}-\x{FFFD}\x{10000}-\x{EFFFF}]+)/) {
			my $text	= $1;
			push(@uni, $text);
			$uri		=~ s/$1/',____' . $count . '____,'/e;
			$count++;
		}
		my $abs			= URI->new_abs( $uri, $base );
		my $uri			= $abs->as_string;
		while ($uri =~ /,____(\d+)____,/) {
			my $num	= $1;
			my $i	= index($uri, ",____${num}____,");
			my $len	= 10 + length($num);
			substr($uri, $i, $len)	= shift(@uni);
		}
		return $uri;
	} else {
		return $uri;
	}
}

=begin private

=item C<_check_constraints ( \%bound, \@data )>

Returns the value returned by evaluating the expression structures in C<@data>
with the bound variables in C<%bound>.

=end private

=cut

{
our %functions;
no warnings 'numeric';
my %dispatch	= (
					VAR		=> sub {
								my ($self, $values, $data) = @_;
								my $name	= $data->[0]->name;
								my $value	= $values->{ $name };
								return $value;
							},
					URI		=> sub {
								my $self	= shift;
								my $values	= shift;
								my $data	= shift;
								my $uri		= $data->[0]->uri_value;
								if (ref($uri)) {
									$uri	= $self->qualify_uri( $uri );
								}
								return $uri;
							},
					LITERAL	=> sub {
								my $self	= shift;
								my $values	= shift;
								my $data	= shift;
								my %args	= @_;
								my $bridge	= $args{bridge};
								
								my $l	= $data->[0];
								if (blessed($l) and $l->has_datatype) {
									my $literal	= $l->literal_value;
									my $lang	= $l->literal_value_language;
									my $uri		= $l->literal_datatype;
									return $bridge->new_literal( $literal, $lang, $uri );
								} else {
									Carp::confess unless (ref($l));
									return $l->literal_value;
								}
							},
					'~~'	=> sub {
								my $self	= shift;
								my $values	= shift;
								my $data	= shift;
								my %args	= @_;
								my $bridge	= $args{bridge};
								
								my $text	= $self->_check_constraints( $values, $data->[0], %args );
								my $pattern	= $self->_check_constraints( $values, $data->[1], %args );
								if (scalar(@$data) == 3) {
									my $flags	= $self->get_value( $self->_check_constraints( $values, $data->[2], %args ), %args );
									if ($flags !~ /^[smix]*$/) {
										throw RDF::Query::Error::FilterEvaluationError ( -text => 'REGEX() called with unrecognized flags' );
									}
									$pattern	= qq[(?${flags}:$pattern)];
								}
								if ($bridge->is_literal($text)) {
									$text	= $bridge->literal_value( $text );
								} elsif (blessed($text)) {
									throw RDF::Query::Error::TypeError ( -text => 'REGEX() called with non-string data' );
								}
								
								return ($text =~ /$pattern/)
							},
					'=='	=> sub {
								my $self	= shift;
								my $values	= shift;
								my $data	= shift;
								my %args	= @_;
								my $bridge	= $args{bridge};
								my @operands = map {
									my $value	= $self->_check_constraints( $values, $_, %args );
									my $v		= $self->get_value( $value, %args );
									$v;
								} @{ $data };

								my $eq;
								if ($self->_one_isa( $bridge, 'DateTime', @operands )) {
									@operands	= $self->_promote_to( $bridge, 'DateTime', @operands );
									$eq			= (0 == DateTime->compare( $operands[0], $operands[1] ));
								} else {
									$eq		= eval { (0 == ncmp(@operands, $bridge)) };
#									warn $@;
								}
# 								warn "EQ [$eq]: " . Dumper(\@operands);
								return $eq;
							},
					'!='	=> sub {
								my $self	= shift;
								my $values	= shift;
								my $data	= shift;
								my %args	= @_;
								my $bridge	= $args{bridge};
								my @operands = map { $self->get_value( $self->_check_constraints( $values, $_, %args ), %args ) } @{ $data };
								if ($self->_one_isa( $bridge, 'DateTime', @operands )) {
									@operands	= $self->_promote_to( $bridge, 'DateTime', @operands );
								}
								foreach my $node (@operands) {
									next unless (ref($node));
									unless ($self->_isa_known_node_type( $bridge, $node )) {
										warn "not a known type in neq: " . Dumper($node) if ($debug);
										return 0;
									}
								}
								my $eq	= ncmp($operands[0], $operands[1], $bridge) != 0;
								return $eq;
							},
					'<'		=> sub {
								my $self	= shift;
								my $values	= shift;
								my $data	= shift;
								my %args	= @_;
								my $bridge	= $args{bridge};
								my @operands = map { $self->_check_constraints( $values, $_, %args ) } @{ $data };
								my $cmp;
								if ($self->_one_isa( $bridge, 'DateTime', @operands )) {
									@operands	= $self->_promote_to( $bridge, 'DateTime', @operands );
									$cmp		= (DateTime->compare( $operands[0], $operands[1] ));
								} else {
									$cmp		= ncmp($operands[0], $operands[1], $bridge);
								}

# 								warn '-----------------------------';
# 								warn "LESS-THAN OP[0]: " . eval { $operands[0]->as_string };
# 								warn "LESS-THAN OP[1]: " . eval { $operands[1]->as_string };
# 								warn "LESS-THAN: $cmp\n";
								return $cmp == -1;
							},
					'>'		=> sub {
								my $self	= shift;
								my $values	= shift;
								my $data	= shift;
								my %args	= @_;
								my $bridge	= $args{bridge};
								my @operands = map { $self->_check_constraints( $values, $_, %args ) } @{ $data };
								my $cmp;
								if ($self->_one_isa( $bridge, 'DateTime', @operands )) {
									@operands	= $self->_promote_to( $bridge, 'DateTime', @operands );
									$cmp		= (DateTime->compare( $operands[0], $operands[1] ));
								} else {
									$cmp		= ncmp($operands[0], $operands[1], $bridge);
								}
# 								warn '-----------------------------';
# 								warn "GREATER-THAN OP[0]: " . eval { $operands[0]->as_string };
# 								warn "GREATER-THAN OP[1]: " . eval { $operands[1]->as_string };
# 								warn "GREATER-THAN: $cmp\n";
								return $cmp == 1;
							},
					'<='	=> sub {
								my $self	= shift;
								my $values	= shift;
								my $data	= shift;
								my %args	= @_;
								my $bridge	= $args{bridge};
								my @operands = map { $self->_check_constraints( $values, $_, %args ) } @{ $data };
								my $cmp;
								if ($self->_one_isa( $bridge, 'DateTime', @operands )) {
									@operands	= $self->_promote_to( $bridge, 'DateTime', @operands );
									$cmp		= (DateTime->compare( $operands[0], $operands[1] ));
								} else {
									$cmp		= ncmp($operands[0], $operands[1], $bridge);
								}
								return $cmp != 1;
							},
					'>='	=> sub {
								my $self	= shift;
								my $values	= shift;
								my $data	= shift;
								my %args	= @_;
								my $bridge	= $args{bridge};
								my @operands = map { $self->_check_constraints( $values, $_, %args ) } @{ $data };
								my $cmp;
								if ($self->_one_isa( $bridge, 'DateTime', @operands )) {
									@operands	= $self->_promote_to( $bridge, 'DateTime', @operands );
									$cmp		= (DateTime->compare( $operands[0], $operands[1] ));
								} else {
									$cmp		= ncmp($operands[0], $operands[1], $bridge);
								}
								return $cmp != -1;
							},
					'&&'	=> sub {
								my $self	= shift;
								my $values	= shift;
								my $data	= shift;
								my %args	= @_;
								my $bridge	= $args{bridge};
								my @results;
								foreach my $part (@{ $data }) {
									my $error;
									my $value;
									try {
										my $data	= $self->_check_constraints( $values, $part, %args );
										$value		= $self->get_function('sop:boolean')->( $self, $bridge, $data );
										push(@results, $value);
									} catch RDF::Query::Error::FilterEvaluationError with {
										$error	= shift;
										push(@results, $error);
									};
									if (not $error and not $value) {
										return 0;
									}
								}
								
								if ($results[0] and $results[1]) {
									return 1;
								} else {
									foreach my $r (@results) {
										throw $r if (ref($r) and $r->isa('RDF::Query::Error'));
									}
									throw RDF::Query::Error::FilterEvaluationError;
								}
							},
					'||'	=> sub {
								my $self	= shift;
								my $values	= shift;
								my $data	= shift;
								my %args	= @_;
								my $bridge	= $args{bridge};
								my $error;
								my $bool	= 0;
								foreach my $part (@{ $data }) {
									undef $error;
									my $value;
									try {
										my $data	= $self->_check_constraints( $values, $part, %args );
										$value		= $self->get_function('sop:boolean')->( $self, $bridge, $data );
									} catch RDF::Query::Error::FilterEvaluationError with {
										$error	= shift;
										$value	= 0;
									};
									
# 									warn "OR [1]: " . Dumper($part);
									if ($value) {
										$bool	= 1;
										last;
									}
								}
								
								if ($error) {
									throw $error;
								} else {
									return $bool;
								}
							},
					'*'		=> sub {
								my $self	= shift;
								my $values	= shift;
								my $data	= shift;
								my %args	= @_;
								my $bridge	= $args{bridge};
								my @operands	= map { $self->_check_constraints( $values, $_, %args ) } @{ $data };
								my @types		= map { $bridge->literal_datatype( $_ ) } @operands;
								my @values		= map { $self->get_function('sop:numeric')->( $self, $bridge, $_ ) } @operands;
								my $value		= $values[0] * $values[1];
								my $type		= $self->_result_type( '*', @types );
								return $bridge->new_literal($value, undef, $type);
							},
					'/'		=> sub {
								my $self	= shift;
								my $values	= shift;
								my $data	= shift;
								my %args	= @_;
								my $bridge	= $args{bridge};
								my @operands	= map { $self->_check_constraints( $values, $_, %args ) } @{ $data };
								my @types		= map { $bridge->literal_datatype( $_ ) } @operands;
								my @values		= map { $self->get_function('sop:numeric')->( $self, $bridge, $_ ) } @operands;
								my $value		= $values[0] / $values[1];
								my $type		= $self->_result_type( '/', @types );
								return $bridge->new_literal($value, undef, $type);
							},
					'+'		=> sub {
								my $self	= shift;
								my $values	= shift;
								my $data	= shift;
								my %args	= @_;
								my $bridge	= $args{bridge};
								my @operands	= map { $self->_check_constraints( $values, $_, %args ) } @{ $data };
								my @types		= map { $bridge->literal_datatype( $_ ) } @operands;
								my @values		= map { $self->get_function('sop:numeric')->( $self, $bridge, $_ ) } @operands;
								my $value		= $values[0] + $values[1];
								my $type		= $self->_result_type( '+', @types );
								return $bridge->new_literal($value, undef, $type);
							},
					'-'		=> sub {
								my $self	= shift;
								my $values	= shift;
								my $data	= shift;
								my %args	= @_;
								my $bridge	= $args{bridge};
								my @operands	= map { $self->_check_constraints( $values, $_, %args ) } @{ $data };
								my @types		= map { $bridge->literal_datatype( $_ ) } @operands;
								my @values		= map { $self->get_function('sop:numeric')->( $self, $bridge, $_ ) } @operands;
								my $value		= (1 == @operands) ? (-1 * $values[0]) : ($values[0] - $values[1]);
								my $type		= $self->_result_type( '-', @types );
								return $bridge->new_literal($value, undef, $type);
							},
					'!'		=> sub {
								my $self	= shift;
								my $values	= shift;
								my $data	= shift;
								my %args	= @_;
								my $bridge	= $args{bridge};
								my $value	= $self->_check_constraints( $values, $data->[0], %args );
								if (defined $value) {
									my $bool	= $self->get_function('sop:boolean')->( $self, $bridge, $value );
									return (not $bool) ? $self->_true( $bridge ) : $self->_false( $bridge );
								} else {
									throw RDF::Query::Error::TypeError ( -text => 'Cannot negate an undefined value' );
								}
							},
					'FUNCTION'	=> sub {
						our %functions;
						my $self	= shift;
						my $values	= shift;
						my $data	= shift;
						my %args	= @_;
						my $bridge	= $args{bridge};
						my $uri		= $self->qualify_uri( $data->[0][1] );
						my $func	= $self->get_function( $uri, %args );
						if (ref($func) and reftype($func) eq 'CODE') {
							my $value;
							$self->{'values'}	= $values;
							my @args;
							foreach my $d (@{ $data }[1..$#{ $data }]) {
								if (blessed($d) and $d->isa('RDF::Query::Node::Variable')) {
									push(@args, $values->{ $d->name });
								} elsif (blessed($d) and $bridge->is_node( $d )) {
									push(@args, $d);
								} else {
									push(@args, $self->_check_constraints( $values, $d, %args ));
								}
							}
							$value	= $func->(
										$self,
										$bridge,
										@args
									);
							{ no warnings 'uninitialized';
								_debug( "function <$uri> -> $value" ) if (DEBUG);
							}
							return $value;
						} else {
							warn "No function defined for <${uri}>\n";
							Carp::cluck if ($::counter++ > 5);
							return undef;
						}
					},
				);
sub _check_constraints {
	my $self	= shift;
	my $values	= shift;
	my $data	= shift;
	my %args	= @_;
	Carp::confess unless ($args{bridge});	# XXXassert
	
	_debug( '_check_constraints: ' . Dumper($data), 2 ) if (DEBUG);
	return 1 unless ref($data);
	
	my ($op, @data);
	if (blessed($data) and $data->isa('RDF::Query::Node')) {
		$op		= $data->type;
		@data	= $data;
	} else {
		$op		= $data->[0];
		@data	= @{ $data }[ 1 .. $#{ $data } ];
	}
	my $code	= $dispatch{ $op };
	
	if ($code) {
#		local($Data::Dumper::Indent)	= 0;
		my $result	= $code->( $self, $values, \@data, %args );
		_debug( "OP: $op -> " . Dumper($data), 2 ) if (DEBUG);
		return $result;
	} else {
		confess "OPERATOR $op NOT IMPLEMENTED!";
	}
}
}

=begin private

=item C<check_constraints ( \%bound, \@data )>

Returns the value returned by evaluating the expression structures in C<@data>
with the bound variables in C<%bound>. Catches any evaluation exceptions,
returning undef if an error is raised.

=end private

=cut

sub check_constraints {
	my $self	= shift;
	my $values	= shift;
	my $data	= shift;
	my %args	= @_;
	
	my $result;
	try {
		$result	= $self->_check_constraints( $values, $data, %args );
	} catch RDF::Query::Error::FilterEvaluationError with {
		my $error	= shift;
		warn "FilterEvaluationError: $error\n" if ($debug);
		$result	= undef;
	} catch RDF::Query::Error::TypeError with {
		my $error	= shift;
		warn "TypeError: $error\n" if ($debug);
		$result	= undef;
	} except {
		my $error	= shift;
		warn "Error: $error\n" if ($debug);
	};
	return $result;
}


{
my $xsd				= 'http://www.w3.org/2001/XMLSchema#';
my $integerTypes	= qr<^http://www.w3.org/2001/XMLSchema#(integer|non(Positive|Negative)Integer|(positive|negative)Integer|long|int|short|byte|unsigned(Long|Int|Short|Byte))>;
my @typeOrder		= qw(double float decimal integer);
sub _result_type {
	my $self	= shift;
	my $op		= shift;
	my @data	= @_;
	no warnings 'uninitialized';
	return "${xsd}integer" if ($data[0] =~ $integerTypes and $data[1] =~ $integerTypes);
	foreach my $t (@typeOrder) {
		no warnings 'uninitialized';
		return "${xsd}${t}" if ($data[0] =~ /$t/i or $data[1] =~ /$t/i);
	}
}
}

sub _true {
	my $self	= shift;
	my $bridge	= shift || $self->bridge;
	return $bridge->new_literal('true', undef, 'http://www.w3.org/2001/XMLSchema#boolean');
}

sub _false {
	my $self	= shift;
	my $bridge	= shift || $self->bridge;
	return $bridge->new_literal('false', undef, 'http://www.w3.org/2001/XMLSchema#boolean');
}

sub _isa_known_datatype {
	my $self	= shift;
	my $type	= shift;
	no warnings 'uninitialized';
	return 1 if ($type =~ m<^http://www.w3.org/2001/XMLSchema#(boolean|double|float|decimal|integer|dateTime|string)$>);
	return 0;
}

sub _isa_known_node_type {
	my $self	= shift;
	my $bridge	= shift;
	my $data	= shift;
	
	return 0 unless (ref($data));
	return 1 if (blessed($_) and $_->isa( 'DateTime' ));
	return 1 if (blessed($_) and $bridge->is_resource($_));
	if (blessed($data) and $bridge->is_literal($data)) {
		my $type	= $bridge->literal_datatype( $data );
		if ($type) {
			return $self->_isa_known_datatype( $type );
		} else {
			return 1;
		}
	}
	
	if (reftype($data) eq 'ARRAY') {
		if ($data->[0] eq 'LITERAL') {
			if ($data->[3]) {
				my $type	= $data->[3];
				return $self->_isa_known_datatype( $type );
			} else {
				return 1;
			}
		} else {
			if ($data->[2]) {
				my $type	= $data->[2];
				return 1 if ($type =~ m<^http://www.w3.org/2001/XMLSchema#(boolean|double|float|decimal|integer|dateTime|string)$>);
				return 0;
			} else {
				return 1;
			}
		}
	} else {
		return 0;
	}
}

sub _one_isa {
	my $self	= shift;
	my $bridge	= shift;
	my $type	= shift;
	my $a		= shift;
	my $b		= shift;
#	warn Data::Dumper->Dump([$a,$b], [qw(a b)]);
	for ($a, $b) {
		return 1 if (blessed($_) and $_->isa( $type ));
		return 1 if (blessed($_) and reftype($_) eq 'ARRAY' and $_->[0] eq $type);
		if ($type eq 'DateTime') {
			no warnings 'uninitialized';
			return 1 if (blessed($_) and $bridge->is_literal($_) and $bridge->literal_datatype($_) eq 'http://www.w3.org/2001/XMLSchema#dateTime');
			no warnings 'uninitialized';
			if (reftype($_) eq 'ARRAY') {
				return 1 if ($_->[2] eq 'http://www.w3.org/2001/XMLSchema#dateTime');
			}
		}
	}
	return 0;
}

sub _promote_to {
	my $self	= shift;
	my $bridge	= shift;
	Carp::confess unless (blessed($bridge));	# XXXassert
	
	my $type	= shift;
	my @objects	= @_;
	if ($type eq 'DateTime') {
		@objects	= map {
						(blessed($_) and $_->isa($type))
							? $_
							: (blessed($_) and $_->isa('RDF::Query::Node::Literal'))
								? $self->call_function( $bridge, {}, 'http://www.w3.org/2001/XMLSchema#dateTime', $_ )
								: (blessed($_) and $bridge->is_literal($_))
									? $self->call_function( $bridge, {}, 'http://www.w3.org/2001/XMLSchema#dateTime', $_ )
									: $self->call_function( $bridge, {}, 'http://www.w3.org/2001/XMLSchema#dateTime', RDF::Query::Node::Literal->new( @$_ ) )
					} @objects;
	}
	return @objects;
}

=begin private

=item C<get_value ( $value )>

Returns the scalar value (string literal, URI value, or blank node identifier)
for the specified model-specific node object.

=end private

=cut

sub get_value {
	my $self	= shift;
	my $value	= shift;
	my %args	= @_;
	my $bridge	= $args{bridge};
	Carp::confess unless ($bridge);	# XXXassert
	
	if (blessed($value) and $value->isa('DateTime')) {
		return $value;
		return $self->{dateparser}->format_datetime($value);
	} elsif ($bridge->is_resource($value)) {
		return $bridge->uri_value( $value );
	} elsif ($bridge->is_literal($value)) {
		my $literal	= $bridge->literal_value( $value );
		if (my $dt = $bridge->literal_datatype( $value )) {
			return [$literal, undef, $dt]
		} elsif (my $lang = $bridge->literal_value_language( $value )) {
			return [$literal, $lang, undef];
		} else {
			return $literal;
		}
	} elsif ($bridge->is_blank($value)) {
		return $bridge->blank_identifier( $value );
	} else {
		return $value;
	}
}

=item C<add_function ( $uri, $function )>

Associates the custom function C<$function> (a CODE reference) with the
specified URI, allowing the function to be called by query FILTERs.

=cut

sub add_function {
	my $self	= shift;
	my $uri		= shift;
	my $code	= shift;
	if (ref($self)) {
		$self->{'functions'}{$uri}	= $code;
	} else {
		our %functions;
		$RDF::Query::functions{ $uri }	= $code;
	}
}

=begin private

=item C<get_function ( $uri, %args )>

If C<$uri> is associated with a query function, returns a CODE reference
to the function. Otherwise returns C<undef>.

=end private

=cut

sub get_function {
	my $self	= shift;
	my $uri		= shift;
	my %args	= @_;
	warn "trying to get function from $uri" if ($debug);
	
	my $func	= $self->{'functions'}{$uri}
				|| $RDF::Query::functions{ $uri };
	if ($func) {
		return $func;
	} elsif ($self->{options}{net_filters}) {
		return $self->net_filter_function( $uri, %args );
	}
	return;
}


=begin private

=item C<< call_function ( $bridge, $bound, $uri, @args ) >>

If C<$uri> is associated with a query function, calls the function with the supplied arguments.

=end private

=cut

sub call_function {
	my $self	= shift;
	my $bridge	= shift;
	my $bound	= shift;
	my $uri		= shift;
	warn "trying to get function from $uri" if (DEBUG);
	
	my $filter			= [ 'FUNCTION', RDF::Query::Node::Resource->new($uri), @_ ];
	return $self->check_constraints( $bound, $filter, bridge => $bridge );
}


=item C<< net_filter_function ( $uri ) >>

Takes a URI specifying the location of a javascript implementation.
Returns a code reference implementing the javascript function.

If the 'trusted_keys' option is set, a GPG signature at ${uri}.asc is
retrieved and verified against the arrayref of trusted key fingerprints.
A code reference is returned only if a trusted signature is found.

=cut

sub net_filter_function {
	my $self	= shift;
	my $uri		= shift;
	my %args	= @_;
	warn "fetching $uri\n" if ($debug);
	
	my $bridge	= $self->new_bridge();
	$bridge->add_uri( $uri );
	
	my $subj	= $bridge->new_resource( $uri );
	
	my $func	= do {
		my $pred	= $bridge->new_resource('http://www.mindswap.org/~gtw/sparql#function');
		my $stream	= $bridge->get_statements( $subj, $pred, undef );
		my $st		= $stream->();
		my $obj		= $bridge->object( $st );
		my $func	= $bridge->literal_value( $obj );
	};
	
	my $impl	= do {
		my $pred	= $bridge->new_resource('http://www.mindswap.org/~gtw/sparql#source');
		my $stream	= $bridge->get_statements( $subj, $pred, undef );
		my $st		= $stream->();
		my $obj		= $bridge->object( $st );
		my $impl	= $bridge->uri_value( $obj );
	};
	
	my $resp	= $self->{useragent}->get( $impl );
	unless ($resp->is_success) {
		warn "No content available from $uri: " . $resp->status_line;
		return;
	}
	my $content	= $resp->content;
	
	if ($self->{options}{trusted_keys}) {
		my $gpg		= $self->{_gpg_obj} || new Crypt::GPG;
		$gpg->gpgbin('/sw/bin/gpg');
		$gpg->secretkey($self->{options}{secretkey} || $ENV{GPG_KEY} || '0xCAA8C82D');
		my $keyring	= exists($self->{options}{keyring})
					? $self->{options}{keyring}
					: File::Spec->catfile($ENV{HOME}, '.gnupg', 'pubring.gpg');
		$gpg->gpgopts("--lock-multiple --keyring " . $keyring);
		
		my $sigresp	= $self->{useragent}->get( "${impl}.asc" );
#		if (not $sigresp) {
#			throw RDF::Query::Error::ExecutionError -text => "Required signature not found: ${impl}.asc\n";
		if ($sigresp->is_success) {
			my $sig		= $sigresp->content;
			my $ok	= $self->_is_trusted( $gpg, $content, $sig, $self->{options}{trusted_keys} );
			unless ($ok) {
				throw RDF::Query::Error::ExecutionError -text => "Not a trusted signature";
			}
		} else {
			throw RDF::Query::Error::ExecutionError -text => "Could not retrieve required signature: ${uri}.asc";
			return;
		}
	}

	my ($rt, $cx)	= $self->new_javascript_engine(%args);
	my $r		= $cx->eval( $content );
	
#	die "Requested function URL does not match the function's URI" unless ($meta->{uri} eq $url);
	return sub {
		my $query	= shift;
		my $bridge	= shift;
		warn "Calling javascript function $func with: " . Dumper(\@_) if ($debug);
		my $value	= $cx->call( $func, @_ );
		warn "--> $value\n" if ($debug);
		return $value;
	};
}

sub _is_trusted {
	my $self	= shift;
	my $gpg		= shift;
	my $file	= shift;
	my $sigfile	= shift;
	my $trusted	= shift;
	
	my (undef, $sig)	= $gpg->verify($sigfile, $file);
	
	return 0 unless ($sig->validity eq 'GOOD');
	
	my $id		= $sig->keyid;
	
	my @keys	= $gpg->keydb($id);
	foreach my $key (@keys) {
		my $fp	= $key->{Fingerprint};
		$fp		=~ s/ //g;
		return 1 if (first { s/ //g; $_ eq $fp } @$trusted);
	}
	return 0;
}



=begin private

=item C<new_javascript_engine ()>

Returns a new JavaScript Runtime and Context object for running network FILTER
functions.

=end private

=cut

sub new_javascript_engine {
	my $self	= shift;
	my %args	= @_;
	my $bridge	= $args{bridge};
	
	my $rt		= JavaScript::Runtime->new();
	my $cx		= $rt->create_context();
	my $meta	= $bridge->meta;
	$cx->bind_function( 'warn' => sub { warn @_ if ($debug || $js_debug) } );
	$cx->bind_function( '_warn' => sub { warn @_ } );
	$cx->bind_function( 'makeTerm' => sub {
		my $term	= shift;
		my $lang	= shift;
		my $dt		= shift;
#		warn 'makeTerm: ' . Dumper($term);
		if (not blessed($term)) {
			my $node	= $bridge->new_literal( $term, $lang, $dt );
			return $node;
		} else {
			return $term;
		}
	} );
	
	my $toString	= sub {
		my $string	= $bridge->literal_value( @_ ) . '';
		return $string;
	};
	
	$cx->bind_class(
		name		=> 'RDFNode',
		constructor	=> sub {},
		'package'	=> $meta->{node},
		'methods'	=> {
						is_literal	=> sub { return $bridge->is_literal( $_[0] ) },
						is_resource	=> sub { return $bridge->is_resource( $_[0] ) },
						is_blank	=> sub { return $bridge->is_blank( $_[0] ) },
						toString	=> $toString,
					},
		ps			=> {
						literal_value			=> [sub { return $bridge->literal_value($_[0]) }],
						literal_datatype		=> [sub { return $bridge->literal_datatype($_[0]) }],
						literal_value_language	=> [sub { return $bridge->literal_value_language($_[0]) }],
						uri_value				=> [sub { return $bridge->uri_value($_[0]) }],
						blank_identifier		=> [sub { return $bridge->blank_identifier($_[0]) }],
					},
	);

	if ($meta->{literal} ne $meta->{node}) {
		$cx->bind_class(
			name		=> 'RDFLiteral',
			constructor	=> sub {},
			'package'	=> $bridge->meta->{literal},
			'methods'	=> {
							is_literal	=> sub { return 1 },
							is_resource	=> sub { return 0 },
							is_blank	=> sub { return 0 },
							toString	=> $toString,
						},
			ps			=> {
							literal_value			=> [sub { return $bridge->literal_value($_[0]) }],
							literal_datatype		=> [sub { return $bridge->literal_datatype($_[0]) }],
							literal_value_language	=> [sub { return $bridge->literal_value_language($_[0]) }],
						},
		);
#		$cx->eval( 'RDFLiteral.prototype.__proto__ = RDFNode.prototype;' );
	}
	if ($meta->{resource} ne $meta->{node}) {
		$cx->bind_class(
			name		=> 'RDFResource',
			constructor	=> sub {},
			'package'	=> $bridge->meta->{resource},
			'methods'	=> {
							is_literal	=> sub { return 0 },
							is_resource	=> sub { return 1 },
							is_blank	=> sub { return 0 },
							toString	=> $toString,
						},
			ps			=> {
							uri_value				=> [sub { return $bridge->uri_value($_[0]) }],
						},
		);
#		$cx->eval( 'RDFResource.prototype.__proto__ = RDFNode.prototype;' );
	}
	if ($meta->{blank} ne $meta->{node}) {
		$cx->bind_class(
			name		=> 'RDFBlank',
			constructor	=> sub {},
			'package'	=> $bridge->meta->{blank},
			'methods'	=> {
							is_literal	=> sub { return 0 },
							is_resource	=> sub { return 0 },
							is_blank	=> sub { return 1 },
							toString	=> $toString,
						},
			ps			=> {
							blank_identifier		=> [sub { return $bridge->blank_identifier($_[0]) }],
						},
		);
#		$cx->eval( 'RDFBlank.prototype.__proto__ = RDFNode.prototype;' );
	}
	
	
	return ($rt, $cx);
}

=item C<add_hook ( $uri, $function )>

Associates the custom function C<$function> (a CODE reference) with the
RDF::Query code hook specified by C<$uri>. Each function that has been
associated with a particular hook will be called (in the order they were
registered as hooks) when the hook event occurs. See L</"Defined Hooks">
for more information.

=cut

sub add_hook {
	my $self	= shift;
	my $uri		= shift;
	my $code	= shift;
	if (ref($self)) {
		push(@{ $self->{'hooks'}{$uri} }, $code);
	} else {
		our %hooks;
		push(@{ $RDF::Query::hooks{ $uri } }, $code);
	}
}

=begin private

=item C<get_hooks ( $uri )>

If C<$uri> is associated with any query callback functions ("hooks"),
returns an ARRAY reference to the functions. If no hooks are associated
with C<$uri>, returns a reference to an empty array.

=end private

=cut

sub get_hooks {
	my $self	= shift;
	my $uri		= shift;
	my $func	= $self->{'hooks'}{$uri}
				|| $RDF::Query::hooks{ $uri }
				|| [];
	return $func;
}

=begin private

=item C<run_hook ( $uri, @args )>

Calls any query callback functions associated with C<$uri>. Each callback
is called with the query object as the first argument, followed by any
caller-supplied arguments from C<@args>.

=end private

=cut

sub run_hook {
	my $self	= shift;
	my $uri		= shift;
	my @args	= @_;
	my $hooks	= $self->get_hooks( $uri );
	foreach my $hook (@$hooks) {
		$hook->( $self, @args );
	}
}

=begin private

=item C<ncmp ( $value )>

General-purpose sorting function for both numbers and strings.

=end private

=cut

sub ncmp ($$;$) {
	my ($a, $b, $bridge)	= @_;
	for ($a, $b) {
		throw RDF::Query::Error::FilterEvaluationError ( -text => 'Cannot sort undefined values' ) unless defined($_);
	}
	my @node_type	= map {
		my $node	= $_;
		my $type;
		if (blessed($node) and not $node->isa('DateTime')) {
			if ($bridge->is_blank( $node )) {
				$type	= 'BLANK' ;
			} elsif ($bridge->is_resource( $node )) {
				$type	= 'URI';
			} elsif ($bridge->is_literal( $node )) {
				$type	= 'LITERAL';
			} else {
				$type	= undef;
			}
		} elsif (ref($node) and reftype($node) eq 'ARRAY' and $node->[0] =~ /^[A-Z]+$/) {
			$type	= 'LITERAL';
		} else {
			$type	= 'LITERAL';
		}
		$type;
	} ($a, $b);
	
	if ($node_type[0] ne $node_type[1]) {
		throw RDF::Query::Error::FilterEvaluationError ( -text => 'Cannot compare values of different types' );
	}
	
	my $get_value	= sub {
		my $node	= shift;
		if (blessed($node) and not $node->isa('DateTime')) {
			return $bridge->literal_value( $node );
		} elsif (ref($node) and reftype($node) eq 'ARRAY') {
			return $node->[0];
		} else {
			return $node;
		}
	};
	
	my $get_type	= sub {
		my $node	= shift;
		if (blessed($node) and not $node->isa('DateTime')) {
			return $bridge->literal_datatype( $node );
		} elsif (ref($node) and reftype($node) eq 'ARRAY') {
			return $node->[2];
		} else {
			return undef;
		}
	};
	
	my $get_lang	= sub {
		my $node	= shift;
		if (blessed($node) and not $node->isa('DateTime')) {
			return $bridge->literal_value_language( $node );
		} elsif (ref($node) and reftype($node) eq 'ARRAY') {
			return $node->[1];
		} else {
			return undef;
		}
	};
	
	my @values	= map { $get_value->( $_ ) } ($a, $b);
	my @types	= map { $get_type->( $_ ) } ($a, $b);
	my @langs	= map { $get_lang->( $_ ) } ($a, $b);
	my @numeric	= map { is_numeric_type($_) } @types;
#	warn Dumper(\@values, \@types, \@langs, \@numeric);	# XXX
	
	no warnings 'numeric';
	no warnings 'uninitialized';
	my $num_cmp		= ($numeric[0] and $numeric[1]);
	my $lang_cmp	= ($langs[0] or $langs[1]);
	
	if ($num_cmp) {
#		warn "num cmp";
		for (@values) {
			unless (looks_like_number($_)) {
				throw RDF::Query::Error::FilterEvaluationError ( -text => "Not a numeric literal: '$_'" );
			}
		}
		return ($values[0] <=> $values[1]);
	} elsif ($lang_cmp) {
#		warn "lang cmp";
		return (lc($langs[0]) cmp lc($langs[1])) if (lc($langs[0]) ne lc($langs[1]));
		my $av	= $values[0];
		my $bv	= $values[1];
		return ($values[0] cmp $values[1]);
	} else {
#		warn "plain cmp";
		if (RDF::Query->_isa_known_datatype($types[0]) xor RDF::Query->_isa_known_datatype($types[1])) {
			if ($types[0] eq $types[1] and $values[0] eq $values[1]) {
				return 0;
			} else {
				throw RDF::Query::Error::FilterEvaluationError ( -text => 'Cannot compare values of unknown types' );
			}
		}
		if (defined($types[0]) or defined($types[1])) {
			no warnings 'uninitialized';
			if ($types[0] ne $types[1]) {
				throw RDF::Query::Error::FilterEvaluationError ( -text => 'Cannot compare values of unknown types' );
			}
		}
#		warn "plain cmp";
		return ($values[0] cmp $values[1]);
	}
}

=begin private

=item C<is_numeric_type ( $type )>

Returns true if the specified C<$type> URI represents a numeric type.
This includes XSD numeric, double and integer types.
	
=end private

=cut

sub is_numeric_type {
	my $type	= shift || '';
	return ($type =~ m<^http://www.w3.org/2001/XMLSchema#(integer|decimal|float|double|numeric|non(Positive|Negative)Integer|(positive|negative)Integer|long|int|short|byte|unsigned(Long|Int|Short|Byte))>) ? 1 : 0;
}

=begin private

=item C<sort_rows ( $nodes, $parsed )>

Called by C<execute> to handle result forms including:
	* Sorting results
	* Distinct results
	* Limiting result count
	* Offset in result set
	
=end private

=cut

sub sort_rows {
	my $self	= shift;
	my $nodes	= shift;
	my $parsed	= shift;
	my $bridge	= $self->bridge;
	my $args		= $parsed->{options} || {};
	my $limit		= $args->{'limit'};
	my $unique		= $args->{'distinct'};
	my $orderby		= $args->{'orderby'};
	my $offset		= $args->{'offset'} || 0;
	my @variables	= $self->variables( $parsed );
	my %colmap		= map { $variables[$_] => $_ } (0 .. $#variables);
	
	if ($unique or $orderby or $offset or $limit) {
		_debug( 'sort_rows column map: ' . Dumper(\%colmap) ) if (DEBUG);
	}
	
	Carp::confess unless ($nodes);	# XXXassert
	
	if ($unique) {
		my %seen;
		my $old	= $nodes;
		$nodes	= sgrep {
			my $row	= $_;
			no warnings 'uninitialized';
			my $key	= join($;, map {$bridge->as_string( $_ )} map { $row->{$_} } @variables);
			return (not $seen{ $key }++);
		} $nodes;
		$nodes->_args->{distinct}++;
	}
	
	if ($orderby) {
		my $cols		= $args->{'orderby'};
		
		my ($req_sort, $actual_sort);
		eval {
			$req_sort	= join(',', map { $_->[1]->name => $_->[0] } @$cols);
			$actual_sort	= join(',', $nodes->sorted_by());
			if (DEBUG) {
				warn "stream is sorted by $actual_sort\n";
				warn "trying to sort by $req_sort\n";
			}
		};
		
		if (not($@) and substr($actual_sort, 0, length($req_sort)) eq $req_sort) {
			warn "Already sorted. Ignoring." if (DEBUG);
		} else {
	#		warn Dumper($data);
			my ($dir, $data)	= @{ $cols->[0] };
			if ($dir ne 'ASC' and $dir ne 'DESC') {
				warn "Direction of sort not recognized: $dir";
				$dir	= 'ASC';
			}
			
			my $col				= $data;
			my $colmap_value	= $colmap{$col};
			_debug( "ordering by $col" ) if (DEBUG);
			
			my @nodes;
			while (my $node = $nodes->()) {
				_debug( "node for sorting: " . Dumper($node) ) if (DEBUG);
				push(@nodes, $node);
			}
			
			no warnings 'numeric';
			@nodes	= map {
						my $node	= $_;
						Carp::cluck if (reftype($node) eq 'ARRAY');
						my %data	= %$node;
	#					my %data	= map { $_ => $node->[ $colmap{$_} ] } (keys %colmap);
	#					warn "data: " . Dumper(\%data, $data);
						my $result	= $self->check_constraints( \%data, $data, bridge => $bridge );
						my $value	= $self->get_value( $result, bridge => $bridge );
						[ $node, $value ]
					} @nodes;
			
			use sort 'stable';
			@nodes	= sort {
						my $val	= eval { ncmp($a->[1],$b->[1]) } || 0;
					} @nodes;
			@nodes	= reverse @nodes if ($dir eq 'DESC');
			
			@nodes	= map { $_->[0] } @nodes;
	
	
			my $type	= $nodes->type;
			my $names	= [$nodes->binding_names];
			my $args	= $nodes->_args;
			my %sorting	= (sorted_by => [$col, $dir]);
			$nodes		= RDF::Trine::Iterator::Bindings->new( sub { shift(@nodes) }, $names, %$args, %sorting );
		}
	}
	
	if ($offset) {
		$nodes->() while ($offset--);
	}
	
	if (defined($limit)) {
		$nodes	= sgrep { if ($limit > 0) { $limit--; 1 } else { 0 } } $nodes;
	}
	
	return $nodes;
}

=begin private

=item C<parse_url ( $url, $named )>

Retrieve a remote file by URL, and parse RDF into the RDF store.
If $named is TRUE, associate all parsed triples with a named graph.

=end private

=cut
sub parse_url {
	my $self	= shift;
	my $url		= shift;
	
	my $named	= shift;
	my $bridge	= $self->bridge;
	
	if ($named) {
		my $class	= ref($self->bridge) || $self->loadable_bridge_class;
		my $bridge	= $class->new();
		$bridge->add_uri( $url, $named );
		$self->{ named_models }{ $url }	= [$bridge, $bridge->new_resource($url)];
	} else {
		$bridge->add_uri( $url );
	}
}

=begin private

=item C<parse_string ( $string, $name )>

Parse the RDF in $string into the RDF store.
If $name is TRUE, associate all parsed triples with a named graph.

=end private

=cut
sub parse_string {
	my $self	= shift;
	my $string	= shift;
	my $name	= shift;
	my $bridge	= $self->bridge;
	
	if ($name) {
		my $class	= ref($self->bridge) || $self->loadable_bridge_class;
		my $bridge	= $class->new();
		$bridge->add_string( $string, $name, $name );
		$self->{ named_models }{ $name }	= [$bridge, $bridge->new_resource($name)];
	} else {
		$bridge->add_string( $string );
	}
}

=begin private

=item C<variables ()>

Returns a list of the ordered variables the query is selecting.
	
=end private

=cut

sub variables {
	my $self	= shift;
	my $parsed	= shift || $self->parsed;
	my @vars	= map { $_->name } @{ $parsed->{'variables'} };
	return @vars;
}

# =begin private
# 
# =item C<all_variables ()>
# 
# Returns a list of all variables referenced in the query.
# 	
# =end private
# 
# =cut
# 
# sub all_variables {
# 	my $self	= shift;
# 	my $parsed	= $self->parsed;
# 	my @vars	= map { $_->[1] } @{ $self->{'known_variables'} };
# 	return @vars;
# }


=item C<parsed ()>

Returns the parse tree.

=cut

sub parsed {
	my $self	= shift;
	if (@_) {
		$self->{parsed}	= shift;
	}
	return $self->{parsed};
}

=item C<bridge ()>

Returns the model bridge of the default graph.

=cut

sub bridge {
	Carp::confess if ($::NO_BRIDGE);
	my $self	= shift;
	if (@_) {
		$self->{bridge}	= shift;
	}
	my $bridge	= $self->{bridge};
	unless (defined $bridge) {
		$bridge	= $self->get_bridge();
	}
	
	return $bridge;
}

=item C<error ()>

Returns the last error the parser experienced.

=cut

sub error {
	my $self	= shift;
	if (blessed($self)) {
		return $self->{error};
	} else {
		our $_ERROR;
		return $_ERROR;
	}
}

=begin private

=item C<set_error ( $error )>

Sets the object's error variable.

=end private

=cut

sub set_error {
	my $self	= shift;
	my $error	= shift;
	if (blessed($self)) {
		$self->{error}	= $error;
	}
	our $_ERROR	= $error;
}

=begin private

=item C<clear_error ()>

Clears the object's error variable.

=end private

=cut

sub clear_error {
	my $self	= shift;
	if (blessed($self)) {
		$self->{error}	= undef;
	}
	our $_ERROR;
	undef $_ERROR;
}


=begin private

=item C<_debug_closure ( $code )>

Debugging function to print out a deparsed (textual) version of a closure.
	
=end private

=cut

sub _debug_closure {
	return unless ($debug > 1);
	my $closure	= shift;
	require B::Deparse;
	my $deparse	= B::Deparse->new("-p", "-sC");
	my $body	= $deparse->coderef2text($closure);
	warn "--- --- CLOSURE --- ---\n";
	Carp::cluck $body;
}

=begin private

=item C<_debug ( $message, $level, $trace )>

Debugging function to print out C<$message> at or above the specified debugging
C<$level>, with an optional stack C<$trace>.
	
=end private

=cut

sub _debug {
	my $mesg	= shift;
	my $level	= shift	|| 1;
	my $trace	= shift || 0;
	my ($package, $filename, $line, $sub, $hasargs, $wantarray, $evaltext, $is_require, $hints, $bitmask)	= caller(1);
	
	$sub		=~ s/^.*://;
	chomp($mesg);
	my $output	= join(' ', $mesg, 'at', $filename, $line); # . "\n";
	if ($debug >= $level) {
		carp $output;
		if ($trace) {
			unless ($filename =~ m/Redland/) {
				warn Carp::longmess();
			}
		}
	}
}


1;

__END__

=back

=head1 Defined Hooks

=over 4

=item http://kasei.us/code/rdf-query/hooks/post-create-model

Called after loading all external files to a temporary model in queries that
use FROM and FROM NAMED.

Args: ( $query, $bridge )

C<$query> is the RDF::Query object.
C<$bridge> is the model bridge (RDF::Query::Model::*) object.

=back

=head1 Supported Built-in Operators and Functions

=over 4

=item * REGEX, BOUND, ISURI, ISBLANK, ISLITERAL

=item * Data-typed literals: DATATYPE(string)

=item * Language-typed literals: LANG(string), LANGMATCHES(string, lang)

=item * Casting functions: xsd:dateTime, xsd:string

=item * dateTime-equal, dateTime-greater-than

=back

=head1 TODO

=over 4

=item * Built-in Operators and Functions

L<http://www.w3.org/TR/rdf-sparql-query/#StandardOperations>

Casting functions: xsd:{boolean,double,float,decimal,integer}, rdf:{URIRef,Literal}, STR

XPath functions: numeric-equal, numeric-less-than, numeric-greater-than, numeric-multiply, numeric-divide, numeric-add, numeric-subtract, not, matches

SPARQL operators: sop:RDFterm-equal, sop:bound, sop:isURI, sop:isBlank, sop:isLiteral, sop:str, sop:lang, sop:datatype, sop:logical-or, sop:logical-and

=back

=head1 AUTHOR

 Gregory Todd Williams <greg@evilfunhouse.com>

=cut
