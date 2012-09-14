# RDF::Trine::Parser::Turtle
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Parser::Turtle - Turtle RDF Parser

=head1 VERSION

This document describes RDF::Trine::Parser::Turtle version 1.000_01

=head1 SYNOPSIS

 use RDF::Trine::Parser;
 my $parser	= RDF::Trine::Parser->new( 'turtle' );
 $parser->parse_into_model( $base_uri, $data, $model );

=head1 DESCRIPTION

This module implements a parser for the Turtle RDF format.

=head1 METHODS

Beyond the methods documented below, this class inherits methods from the
L<RDF::Trine::Parser> class.

=over 4

=cut

package RDF::Trine::Parser::Turtle;

use utf8;
use 5.014;
use Scalar::Util qw(blessed);
use base qw(RDF::Trine::Parser);
use RDF::Trine::Error qw(:try);
use Data::Dumper;
use RDF::Trine::Parser::Turtle::Constants;
use RDF::Trine::Parser::Turtle::Lexer;
use RDF::Trine::Parser::Turtle::Token;

our $VERSION;
BEGIN {
	$VERSION				= '1.000_01';
	foreach my $ext (qw(ttl)) {
		$RDF::Trine::Parser::file_extensions{ $ext }	= __PACKAGE__;
	}
	$RDF::Trine::Parser::parser_names{ 'turtle' }	= __PACKAGE__;
	my $class										= __PACKAGE__;
	$RDF::Trine::Parser::encodings{ $class }		= 'utf8';
	$RDF::Trine::Parser::format_uris{ 'http://www.w3.org/ns/formats/Turtle' }	= __PACKAGE__;
	$RDF::Trine::Parser::canonical_media_types{ $class }	= 'text/turtle';
	foreach my $type (qw(application/x-turtle application/turtle text/turtle)) {
		$RDF::Trine::Parser::media_types{ $type }	= __PACKAGE__;
	}
}

my $rdf	= RDF::Trine::Namespace->new('http://www.w3.org/1999/02/22-rdf-syntax-ns#');
my $xsd	= RDF::Trine::Namespace->new('http://www.w3.org/2001/XMLSchema#');

sub new {
	my $class	= shift;
	my %args	= @_;
	return bless({ %args, stack => [] }, $class);
}

=item C<< parse ( $base_uri, $rdf, \&handler ) >>

Parses the C<< $data >>, using the given C<< $base_uri >>. Calls the
C<< triple >> method for each RDF triple parsed. This method does nothing by
default, but can be set by using one of the default C<< parse_* >> methods.

=cut

sub parse {
	my $self	= shift;
	local($self->{baseURI})	= shift;
	my $string				= shift;
	local($self->{handle_triple}) = shift;
	open(my $fh, '<:encoding(UTF-8)', \$string);
	my $l	= RDF::Trine::Parser::Turtle::Lexer->new($fh);
	$self->_parse($l);
}

=item C<< parse_file ( $base_uri, $fh, $handler ) >>

Parses all data read from the filehandle or file C<< $fh >>, using the given
C<< $base_uri >>. If C<< $fh >> is a filename, this method can guess the
associated parse. For each RDF statement parses C<< $handler >> is called.

=cut

sub parse_file {
	my $self	= shift;
	local($self->{baseURI})	= shift;
	my $fh		= shift;
	local($self->{handle_triple}) = shift;

	unless (ref($fh)) {
		my $filename	= $fh;
		undef $fh;
		unless ($self->can('parse')) {
			my $pclass = $self->guess_parser_by_filename( $filename );
			$self = $pclass->new() if ($pclass and $pclass->can('new'));
		}
		open( $fh, '<:encoding(UTF-8)', $filename ) or throw RDF::Trine::Error::ParserError -text => $!;
	}
	
	my $l	= RDF::Trine::Parser::Turtle::Lexer->new($fh);
	$self->_parse($l);
}

sub _parse {
	my $self	= shift;
	my $l		= shift;
	$l->check_for_bom;
	$self->{map}	= RDF::Trine::NamespaceMap->new();
	while (my $t = $self->_next_nonws($l)) {
		$self->_statement($l, $t);
	}
}

################################################################################

sub _unget_token {
	my $self	= shift;
	my $t		= shift;
	push(@{ $self->{ stack } }, $t);
}

sub _next_nonws {
	my $self	= shift;
	my $l		= shift;
	if (scalar(@{ $self->{ stack } })) {
		return pop(@{ $self->{ stack } });
	}
	while (1) {
		my $t	= $l->get_token;
		return unless ($t);
		my $type = $t->type;
# 		next if ($type == WS or $type == COMMENT);
# 		warn decrypt_constant($type) . "\n";
		return $t;
	}
}

sub _get_token_type {
	my $self	= shift;
	my $l		= shift;
	my $type	= shift;
	my $t		= $self->_next_nonws($l);
	return unless ($t);
	unless ($t->type eq $type) {
		$self->throw_error(sprintf("Expecting %s but got %s", decrypt_constant($type), decrypt_constant($t->type)), $t, $l);
	}
	return $t;
}

sub _statement {
	my $self	= shift;
	my $l		= shift;
	my $t		= shift;
	my $type	= $t->type;
	given ($type) {
# 		when (WS) {}
		when (PREFIX) {
			$t	= $self->_get_token_type($l, PREFIXNAME);
			my $name	= $t->value;
			$t	= $self->_get_token_type($l, IRI);
			my $iri	= $t->value;
			$t	= $self->_get_token_type($l, DOT);
			$self->{map}->add_mapping( $name => $iri );
			if (my $ns = $self->{namespaces}) {
				unless ($ns->namespace_uri($name)) {
					$ns->add_mapping( $name => $iri );
				}
			}
		}
		when (BASE) {
			$t	= $self->_get_token_type($l, IRI);
			my $iri	= $t->value;
			$t	= $self->_get_token_type($l, DOT);
			$self->{baseURI}	= $iri;
		}
		default {
			$self->_triple( $l, $t );
			$t	= $self->_get_token_type($l, DOT);
		}
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
		$self->throw_error("Expecting resource or bnode but got " . decrypt_constant($type), $t, $l);
	} else {
		$subj	= $self->_token_to_node($t);
	}
# 	warn "Subject: $subj\n";
	
	#predicateObjectList
	$self->_predicateObjectList($l, $subj);
}

sub _assert_list {
	my $self	= shift;
	my $subj	= shift;
	my @objects	= @_;
	my $head	= $subj;
	while (@objects) {
		my $obj	= shift(@objects);
		$self->_assert_triple($head, $rdf->first, $obj);
		my $next	= scalar(@objects) ? RDF::Trine::Node::Blank->new() : $rdf->nil;
		$self->_assert_triple($head, $rdf->rest, $next);
		$head		= $next;
	}
}

sub _predicateObjectList {
	my $self	= shift;
	my $l		= shift;
	my $subj	= shift;
	my $t		= $self->_next_nonws($l);
	while (1) {
		my $type = $t->type;
		unless ($type==IRI or $type==PREFIXNAME or $type==A) {
			$self->throw_error("Expecting verb but got " . decrypt_constant($type), $t, $l);
		}
		my $pred	= $self->_token_to_node($t);
		$self->_objectList($l, $subj, $pred);
		
		$t		= $self->_next_nonws($l);
		last unless ($t);
		if ($t->type == SEMICOLON) {
			$t		= $self->_next_nonws($l);
			if ($t->type == IRI or $t->type == PREFIXNAME or $t->type == A) {
				next;
			} else {
				$self->_unget_token($t);
				return;
			}
		} else {
			$self->_unget_token($t);
			return;
		}
	}
}

sub _objectList {
	my $self	= shift;
	my $l		= shift;
	my $subj	= shift;
	my $pred	= shift;
	while (1) {
		my $t		= $self->_next_nonws($l);
		last unless ($t);
		my $obj		= $self->_object($l, $t);
		$self->_assert_triple($subj, $pred, $obj);
		
		my $t	= $self->_next_nonws($l);
		if ($t->type == COMMA) {
			next;
		} else {
			$self->_unget_token($t);
			return;
		}
	}
}

sub _assert_triple {
	my $self	= shift;
	my $subj	= shift;
	my $pred	= shift;
	my $obj		= shift;
	if ($self->{canonicalize} and blessed($obj) and $obj->isa('RDF::Trine::Node::Literal')) {
		$obj	= $obj->canonicalize;
	}
	
	my $t		= RDF::Trine::Statement->new($subj, $pred, $obj);
	if ($self->{handle_triple}) {
		$self->{handle_triple}->( $t );
	}
}


sub _object {
	my $self	= shift;
	my $l		= shift;
	my $t		= shift;
	my $obj;
	my $type	= $t->type;
	if ($type==LBRACKET) {
		$obj	= RDF::Trine::Node::Blank->new();
		my $t	= $self->_next_nonws($l);
		if ($t->type != RBRACKET) {
			$self->_unget_token($t);
			$self->_predicateObjectList( $l, $obj );
			$t	= $self->_get_token_type($l, RBRACKET);
		}
	} elsif ($type == LPAREN) {
		my $t	= $self->_next_nonws($l);
		if ($t->type == RPAREN) {
			$obj	= RDF::Trine::Node::Resource->new('http://www.w3.org/1999/02/22-rdf-syntax-ns#nil');
		} else {
			$obj	= RDF::Trine::Node::Blank->new();
			my @objects	= $self->_object($l, $t);
			
			while (1) {
				my $t	= $self->_next_nonws($l);
				if ($t->type == RPAREN) {
					last;
				} else {
					push(@objects, $self->_object($l, $t));
				}
			}
			$self->_assert_list($obj, @objects);
		}
	} elsif (not($type==IRI or $type==PREFIXNAME or $type==A or $type==STRING1D or $type==STRING3D or $type==BNODE or $type==INTEGER or $type==DECIMAL or $type==DOUBLE or $type==BOOLEAN)) {
		$self->throw_error("Expecting object but got " . decrypt_constant($type), $t, $l);
	} else {
		if ($type==STRING1D or $type==STRING3D) {
			my $value	= $t->value;
			my $t		= $self->_next_nonws($l);
			my $dt;
			my $lang;
			if ($t->type == HATHAT) {
				my $t		= $self->_next_nonws($l);
				if ($t->type == IRI or $t->type == PREFIXNAME) {
					$dt	= $self->_token_to_node($t);
				}
			} elsif ($t->type == LANG) {
				$lang	= $t->value;
			} else {
				$self->_unget_token($t);
			}
			$obj	= RDF::Trine::Node::Literal->new($value, $lang, $dt);
		} else {
			$obj	= $self->_token_to_node($t, $type);
		}
	}
	return $obj;
}

sub _token_to_node {
	my $self	= shift;
	my $t		= shift;
	my $type	= shift || $t->type;
	given ($type) {
		when (A) {
			return $rdf->type;
		}
		when (IRI) {
			return RDF::Trine::Node::Resource->new($t->value, $self->{baseURI});
		}
		when (INTEGER) {
			return RDF::Trine::Node::Literal->new($t->value, undef, $xsd->integer);
		}
		when (DECIMAL) {
			return RDF::Trine::Node::Literal->new($t->value, undef, $xsd->decimal);
		}
		when (DOUBLE) {
			return RDF::Trine::Node::Literal->new($t->value, undef, $xsd->double);
		}
		when (BOOLEAN) {
			return RDF::Trine::Node::Literal->new($t->value, undef, $xsd->boolean);
		}
		when (PREFIXNAME) {
			my ($ns, $local)	= @{ $t->args };
			my $prefix			= $self->{map}->namespace_uri($ns);
			unless (blessed($prefix)) {
				$self->throw_error("Use of undeclared prefix '$ns'", $t);
			}
			my $iri				= $prefix->uri($local);
			return $iri;
		}
		when (BNODE) {
			return RDF::Trine::Node::Blank->new($t->value);
		}
		default {
			$self->throw_error("Converting $type to node not implemented", $t);
		}
	}
}

sub throw_error {
	my $self	= shift;
	my $message	= shift;
	my $t		= shift;
	my $l		= shift;
	my $line	= $t->line;
	my $col		= $t->column;
# 	Carp::cluck "$message at $line:$col";
	throw RDF::Trine::Error::ParserError -text => "$message at $line:$col ('" . $t->value . "')";
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
