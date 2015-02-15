# RDF::Trine::Parser::TriG
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Parser::TriG - TriG RDF Parser

=head1 VERSION

This document describes RDF::Trine::Parser::TriG version 1.012

=head1 SYNOPSIS

 use RDF::Trine::Parser;
 my $parser	= RDF::Trine::Parser->new( 'trig' );
 $parser->parse_into_model( $base_uri, $data, $model );

=head1 DESCRIPTION

...

=head1 METHODS

Beyond the methods documented below, this class inherits methods from the
L<RDF::Trine::Parser> class.

=over 4

=cut

package RDF::Trine::Parser::TriG;

use 5.010;
use strict;
use warnings;
no warnings 'redefine';
no warnings 'once';
use base qw(RDF::Trine::Parser::Turtle);
use RDF::Trine::Parser::Turtle::Constants;
use RDF::Trine qw(literal);

our ($VERSION);
BEGIN {
	$VERSION				= '1.012';
	$RDF::Trine::Parser::parser_names{ 'trig' }	= __PACKAGE__;
	foreach my $ext (qw(trig)) {
		$RDF::Trine::Parser::file_extensions{ $ext }	= __PACKAGE__;
	}
# 	foreach my $type (qw(application/x-turtle application/turtle text/turtle)) {
# 		$RDF::Trine::Parser::media_types{ $type }	= __PACKAGE__;
# 	}
}

sub _assert_triple {
	my $self	= shift;
	my $subj	= shift;
	my $pred	= shift;
	my $obj		= shift;
	my $graph	= $self->{graph};
	
	if ($self->{canonicalize} and blessed($obj) and $obj->isa('RDF::Trine::Node::Literal')) {
		$obj	= $obj->canonicalize;
	}
	my $st		= RDF::Trine::Statement::Quad->new( $subj, $pred, $obj, $graph );
	
	if (my $code = $self->{handle_triple}) {
		$code->( $st );
	}
	
	my $count	= ++$self->{triple_count};
}

sub _statement {
	my $self	= shift;
	my $l		= shift;
	my $t		= shift;
	my $type	= $t->type;
# 	warn '--> ' . decrypt_constant($type);
	if ($type == LBRACE) { return $self->_graph($l, $t); }
	elsif ($type == LBRACKET) { return $self->_graph($l, $t); }
	elsif ($type == BNODE) { return $self->_graph($l, $t); }
	elsif ($type == EQUALS) { return $self->_graph($l, $t); }
	elsif ($type == IRI) { return $self->_graph($l, $t); }
	elsif ($type == PREFIXNAME) { return $self->_graph($l, $t); }
	elsif ($type == WS) {}
	elsif ($type == PREFIX or $type == SPARQLPREFIX) {
		$t	= $self->_get_token_type($l, PREFIXNAME);
		my $name	= $t->value;
		$name		=~ s/:$//;
		$t	= $self->_get_token_type($l, IRI);
		my $r	= RDF::Trine::Node::Resource->new($t->value, $self->{baseURI});
		my $iri	= $r->uri_value;
		if ($type == PREFIX) {
			$t	= $self->_get_token_type($l, DOT);
		}
		$self->{map}->add_mapping( $name => $iri );
		if (my $ns = $self->{namespaces}) {
			unless ($ns->namespace_uri($name)) {
				$ns->add_mapping( $name => $iri );
			}
		}
	}
	elsif ($type == BASE or $type == SPARQLBASE) {
		$t	= $self->_get_token_type($l, IRI);
		my $r	= RDF::Trine::Node::Resource->new($t->value, $self->{baseURI});
		my $iri	= $r->uri_value;
		if ($type == BASE) {
			$t	= $self->_get_token_type($l, DOT);
		}
		$self->{baseURI}	= $iri;
	}
	else {
		$self->_throw_error("Expecting statement but got " . decrypt_constant($type), $t, $l);
	}
}

sub _graph {
	my $self	= shift;
	my $l		= shift;
	my $t		= shift;
	my $type	= $t->type;
	if ($type == IRI or $type == PREFIXNAME) {
		$self->{graph}	= $self->_token_to_node($t);
		my $old_token	= $t;
		$t		= $self->_next_nonws($l);
		unless (defined($t)) {
			$l->_throw_error("Unexpected EOF after graph");
		}
	} elsif ($type == BNODE) {
		$self->{graph}	= $self->_token_to_node($t);
		$t		= $self->_next_nonws($l);
	} elsif ($type == LBRACKET) {
		$t	= $self->_get_token_type($l, RBRACKET);
		$t	= $self->_next_nonws($l);
		$self->{graph}	= RDF::Trine::Node::Blank->new();
	} else {
		$self->{graph}	= RDF::Trine::Node::Nil->new();
	}
	
	if ($t->type == EQUALS) {
		$t		= $self->_next_nonws($l);
	}
	
	if ($t->type != LBRACE) {
		$self->_throw_error("Expecting LBRACE but got " . decrypt_constant($type), $t, $l);
	}
	
	$t		= $self->_next_nonws($l);
	while (1) {
		my $type	= $t->type;
		unless ($type == LBRACKET or $type == LPAREN or $type == IRI or $type == PREFIXNAME or $type == BNODE) {
			$self->_unget_token($t);
			last;
		}
		$self->_triple($l, $t);
		$t		= $self->_next_nonws($l);
		if ($t->type == RBRACE) {
			$self->_unget_token($t);
			last;
		} elsif ($t->type == DOT) {
			$t		= $self->_next_nonws($l);
			next;
		}
	}
	
	$t	= $self->_get_token_type($l, RBRACE);
	$t		= $self->_next_nonws($l);
	return unless defined($t);
	unless ($t->type == DOT) {
		$self->_unget_token($t);
	}
}

sub _triple {
	my $self	= shift;
	my $l		= shift;
	my $t		= shift;
	my $type	= $t->type;
	# subject
	my $subj;
	if ($type == LBRACKET) {
		$subj	= RDF::Trine::Node::Blank->new();
		my $t	= $self->_next_nonws($l);
		if ($t->type != RBRACKET) {
			$self->_unget_token($t);
			$self->_predicateObjectList( $l, $subj );
			$t	= $self->_get_token_type($l, RBRACKET);
			
			$t		= $self->_next_nonws($l);
			return unless defined($t);
			$self->_unget_token($t);
			if ($t->type == DOT) {
				return;
			}
		}
	} elsif ($type == LPAREN) {
		my $t	= $self->_next_nonws($l);
		if ($t->type == RPAREN) {
			$subj	= RDF::Trine::Node::Resource->new('http://www.w3.org/1999/02/22-rdf-syntax-ns#nil');
		} else {
			$subj	= RDF::Trine::Node::Blank->new();
			my @objects	= $self->_object($l, $t);
			
			while (1) {
				my $t	= $self->_next_nonws($l);
				if ($t->type == RPAREN) {
					last;
				} else {
					push(@objects, $self->_object($l, $t));
				}
			}
			$self->_assert_list($subj, @objects);
		}
	} elsif (not($type==IRI or $type==PREFIXNAME or $type==BNODE)) {
		$self->_throw_error("Expecting resource or bnode but got " . decrypt_constant($type), $t, $l);
	} else {
		$subj	= $self->_token_to_node($t);
	}
# 	warn "Subject: $subj\n";
	
	#predicateObjectList
	$self->_predicateObjectList($l, $subj);
}


1;

__END__

=back

=head1 BUGS

Please report any bugs or feature requests to through the GitHub web interface
at L<https://github.com/kasei/perlrdf/issues>.

=head1 SEE ALSO

L<http://www4.wiwiss.fu-berlin.de/bizer/TriG/>

=head1 AUTHOR

Gregory Todd Williams  C<< <gwilliams@cpan.org> >>

=head1 COPYRIGHT

Copyright (c) 2006-2012 Gregory Todd Williams. This
program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
