package RDF::Trine::Statement::API;

use Moose::Role;
use MooseX::Aliases;
use RDF::Trine::Statement::API::Element ();

with qw(
	RDF::Trine::Statement::API::Element::Subject
	RDF::Trine::Statement::API::Element::Predicate
	RDF::Trine::Statement::API::Element::Object
	MooseX::Clone
);

requires qw(
	type
	node_names
	from_sse
);

sub RDF::Trine::Statement::new
{
	my $class = shift;
	Carp::carp("RDF::Trine::Statement->new is deprecated; use RDF::Trine::Statement::Triple->new instead");
	@_==4
		? RDF::Trine::Statement::Quad->new(@_)
		: RDF::Trine::Statement::Triple->new(@_);
}

sub sse {
	my $self    = shift;
	
	return sprintf(
		'(%s %s)',
		lc( $self->type ),
		join q( ), map { $_->sse(@_) } $self->nodes,
	);
}
alias as_string => 'sse';

sub nodes {
	my $self = shift;
	map { $self->$_ } $self->node_names
}

alias construct_args => 'nodes';

my $VAR;
sub BUILDARGS {
	my $class    = shift;
	my @elements = $class->node_names;
	return +{} unless @_;
	if ((scalar @elements == scalar @_ and ref $_[0] and not ref $_[0] eq 'HASH')
	or  (scalar @elements == scalar @_ and not defined $_[0])) {
		return +{ map {
			$elements[$_] => ($_[$_] // RDF::Trine::Node::Variable->new('vvvv'.++$VAR));
		} 0 .. $#elements };
	}
	(@_==1 and ref $_[0] eq 'HASH')
		? $class->Moose::Object::BUILDARGS(@_)
		: $class->Moose::Object::BUILDARGS(+{@_})
}

sub has_blanks {
	my $self = shift;
	grep { $_->is_blank } $self->nodes;
}

sub referenced_variables {
	my $self = shift;
	RDF::Trine::_uniq(
		map { $_->name }
		grep { $_->is_variable }
		$self->nodes
	);
}

alias definite_variables => 'referenced_variables'; # an alias?!?!!!11

sub bind_variables {
	my $self   = shift;
	my $class  = ref($self);
	my $bound  = shift;
	my @nodes  = $self->nodes;
	foreach my $i (0 .. $#nodes) {
		my $n = $nodes[ $i ];
		if ($n->isa('RDF::Trine::Node::Variable')) {
			my $name = $n->name;
			if (my $value = $bound->{ $name }) {
				$nodes[ $i ] = $value;
			}
		}
	}
	return $class->new( @nodes );
}

sub subsumes {
	my $self  = shift;
	my $st    = shift;
	my @nodes = $self->nodes;
	my @match = $st->nodes;
	
	my %bind;
	my $l = Log::Log4perl->get_logger("rdf.trine.statement");
	foreach my $i (0 .. $#nodes) {
		my $m = $match[ $i ];
		if ($nodes[$i]->isa('RDF::Trine::Node::Variable')) {
			my $name = $nodes[$i]->name;
			if (exists( $bind{ $name } )) {
				$l->debug("variable $name has already been bound");
				if (not $bind{ $name }->equal( $m )) {
					$l->debug("-> and " . $bind{$name}->sse . " does not equal " . $m->sse);
					return 0;
				}
			} else {
				$bind{ $name } = $m;
			}
		} else {
			return 0 unless ($nodes[$i]->equal( $m ));
		}
	}
	return 1;
}

# sub from_redland {
# 	my $self   = shift;
# 	my $rstmt  = shift;
# 	my $graph  = shift;
# 	
# 	my $cast = sub
# 	{
# 		my $node = shift;
# 		my $type = $node->type;
# 		if ($type == $RDF::Redland::Node::Type_Resource) {
# 			my $uri = $node->uri->as_string;
# 			if ($uri =~ /%/) {
# 				# Redland's parser doesn't properly unescape percent-encoded RDF URI References
# 				$uri = decode_utf8(uri_unescape(encode_utf8($uri)));
# 			}
# 			return RDF::Trine::Node::Resource->new( $uri );
# 		}
# 		elsif ($type == $RDF::Redland::Node::Type_Blank) {
# 			return RDF::Trine::Node::Blank->new( $node->blank_identifier );
# 		}
# 		elsif ($type == $RDF::Redland::Node::Type_Literal) {
# 			my $lang  = $node->literal_value_language;
# 			my $dturi = $node->literal_datatype;
# 			my $dt    = $dturi ? $dturi->as_string : undef;
# 			return RDF::Trine::Node::Literal->new( $node->literal_value, $lang, $dt );
# 		}
# 		else {
# 			confess 'Unknown node type in statement conversion';
# 		}
# 	};
# 	
# 	return RDF::Trine::Statement::Quad->new({
# 		subject   => $cast->($rstmt->subject),
# 		predicate => $cast->($rstmt->predicate),
# 		object    => $cast->($rstmt->object),
# 		graph     => $graph,
# 	});
# }

sub to_triple {
	my $self = shift;
	RDF::Trine::Statement::Triple->new(
		subject    => $self->subject,
		predicate  => $self->predicate,
		object     => $self->object,
	);
}

sub rdf_compatible {
	my $self = shift;
	
	return
		unless $self->subject->is_resource
		||     $self->subject->is_blank;
	
	return
		unless $self->predicate->is_resource;
	
	return
		unless $self->object->is_resource
		||     $self->object->is_blank
		||     $self->object->is_literal;
	
	return $self;
}

sub as_ntriples {
	shift->to_triple->as_ntriples;
}

1;

__END__

=head1 NAME

RDF::Trine::Statement::API - a role for triples and more

=head1 DESCRIBE

=head2 Consumes

This role consumes several other roles:

=over

=item C<< RDF::Trine::Statement::API::Element::Subject >>

=item C<< RDF::Trine::Statement::API::Element::Predicate >>

=item C<< RDF::Trine::Statement::API::Element::Object >>

=item C<< MooseX::Clone >>

=back

=head2 Requires

=over

=item C<< type >>

=item C<< node_names >>

=item C<< from_sse >>

=back

=head2 Methods

The following methods are provided:

=over

=item C<< sse >>

=item C<< as_string >>

=item C<< nodes >>

=item C<< construct_args >>

=item C<< has_blanks >>

=item C<< referenced_variables >>

=item C<< definite_variables >>

=item C<< bind_variables >>

=item C<< subsumes >>

=item C<< from_redland >>

=item C<< to_triple >>

=item C<< rdf_compatible >>

=item C<< as_ntriples >>

=back


