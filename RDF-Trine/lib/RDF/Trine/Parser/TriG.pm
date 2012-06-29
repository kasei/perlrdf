# RDF::Trine::Parser::TriG
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Parser::TriG - TriG RDF Parser

=head1 VERSION

This document describes RDF::Trine::Parser::TriG version 0.999_02

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

use strict;
use warnings;
no warnings 'redefine';
no warnings 'once';
use base qw(RDF::Trine::Parser::Turtle);

use RDF::Trine qw(literal);

our ($VERSION);
BEGIN {
	$VERSION				= '0.999_02';
	$RDF::Trine::Parser::parser_names{ 'trig' }	= __PACKAGE__;
	foreach my $ext (qw(trig)) {
		$RDF::Trine::Parser::file_extensions{ $ext }	= __PACKAGE__;
	}
# 	foreach my $type (qw(application/x-turtle application/turtle text/turtle)) {
# 		$RDF::Trine::Parser::media_types{ $type }	= __PACKAGE__;
# 	}
}

sub _triple {
	my $self	= shift;
	my $s		= shift;
	my $p		= shift;
	my $o		= shift;
	foreach my $n ($s, $p, $o) {
		unless ($n->isa('RDF::Trine::Node')) {
			throw RDF::Trine::Error::ParserError;
		}
	}
	
	my $graph	= $self->{graph};
	if ($self->{canonicalize}) {
		if ($o->isa('RDF::Trine::Node::Literal') and $o->has_datatype) {
			my $value	= $o->literal_value;
			my $dt		= $o->literal_datatype;
			my $canon	= RDF::Trine::Node::Literal->canonicalize_literal_value( $value, $dt, 1 );
			$o	= literal( $canon, undef, $dt );
		}
	}
	my $st		= RDF::Trine::Statement::Quad->new( $s, $p, $o, $graph );
	
	if (my $code = $self->{handle_triple}) {
		$code->( $st );
	}
	
	my $count	= ++$self->{triple_count};
}

sub _Document {
	my $self	= shift;
	while ($self->_statement_test()) {
		$self->_statement();
	}
}

sub _statement_test {
	my $self	= shift;
	if (length($self->{tokens})) {
		return 1;
	} else {
		return 0;
	}
}

sub _statement {
	my $self	= shift;
	if ($self->_directive_test()) {
		$self->_directive();
		$self->__consume_ws();
		$self->_eat('.');
		$self->__consume_ws();
	} elsif ($self->_graph_test()) {
		$self->_graph();
		$self->__consume_ws();
	} else {
		$self->_ws();
		$self->__consume_ws();
	}
}

sub _graph_test {
	my $self	= shift;
	return 1 if $self->_resource_test;
	return 1 if $self->__startswith('=');
	return $self->__startswith('{');
}

sub _graph {
	my $self	= shift;
	if ($self->_resource_test) {
		$self->{graph}	= $self->_resource;
	} else {
		$self->{graph}	= RDF::Trine::Node::Nil->new();
	}
	$self->__consume_ws();
	if ($self->__startswith('=')) {
		$self->_eat('=');
		$self->__consume_ws();
	}
	$self->_eat('{');
	$self->__consume_ws();
	my $gotdot	= 1;
	while ($self->_triples_test()) {
		unless ($gotdot) {
			use Data::Dumper;
			warn Dumper($self->{tokens});
			throw RDF::Trine::Error::ParserError -text => "Missing '.' between triples";
		}
		$self->_triples();
		$self->__consume_ws();
		if ($self->__startswith('.')) {
			$self->_eat('.');
			$self->__consume_ws();
			$gotdot	= 1;
		} else {
			$gotdot	= 0;
		}
		$self->__consume_ws();
	}
	$self->_eat('}');
	$self->__consume_ws();
	if ($self->__startswith('.')) {
		$self->_eat('.');
	}
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
