# RDF::Trine::Parser::TriG
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Parser::TriG - TriG RDF Parser

=head1 VERSION

This document describes RDF::Trine::Parser::TriG version 1.000

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
	$VERSION				= '1.000';
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
	
	my $st		= RDF::Trine::Statement::Quad->new( $s, $p, $o, $self->{graph} );
	
	if (my $code = $self->{handle_triple}) {
		$code->( $st );
	}
	
	my $count	= ++$self->{triple_count};
}

sub _Document {
	my $self	= shift;
	$self->_statement while length($self->{tokens});
}

sub _statement {
	my $self	= shift;
	if ($self->_directive_test()) {
		$self->_directive();
		$self->__consume_ws();
		$self->{tokens} =~ s/^\.// or die $self->_error('Expected: .');
		$self->__consume_ws();
	} elsif ($self->_resource_test() or $self->{tokens} =~ /^[=\{]/) {
		$self->_graph();
		$self->__consume_ws();
	} else {
		$self->_ws();
	}
}

sub _graph {
	my $self	= shift;
	if ($self->_resource_test) {
		$self->{graph}	= $self->_resource;
	} else {
		$self->{graph}	= RDF::Trine::Node::Nil->new();
	}
	$self->__consume_ws();
	if ($self->{tokens} =~ s/^=//) {
		$self->__consume_ws();
	}
	$self->{tokens} =~ s/^\{// or die $self->_error('Expected: {');
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
			$self->{tokens} =~ s/^\.// or die $self->_error('Expected: .');
			$self->__consume_ws();
			$gotdot	= 1;
		} else {
			$gotdot	= 0;
		}
		$self->__consume_ws();
	}
	$self->{tokens} =~ s/^\}// or die $self->_error('Expected: }');
	$self->__consume_ws();
	$self->{tokens} =~ s/^\.//;
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
