# RDF::Trine::Iterator::SAXHandler
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Iterator::SAXHandler - SAX Handler for parsing SPARQL XML Results format

=head1 SYNOPSIS

    use RDF::Trine::Iterator::SAXHandler;
    my $handler = RDF::Trine::Iterator::SAXHandler->new();
    my $p = XML::SAX::ParserFactory->parser(Handler => $handler);
    $p->parse_file( $string );
    my $iter = $handler->iterator;

=head1 METHODS

=over 4

=cut

package RDF::Trine::Iterator::SAXHandler;

use strict;
use warnings;
use Scalar::Util qw(refaddr);
use base qw(XML::SAX::Base);

use Data::Dumper;

my %strings;
my %tagstack;
my %results;
my %values;
my %bindings;
my %booleans;
my %variables;
my %extra;
my %extrakeys;

my %expecting_string	= map { $_ => 1 } qw(boolean bnode uri literal extrakey);

=item C<< iterator >>

Returns the RDF::Trine::Iterator object after parsing is complete.

=cut

sub iterator {
	my $self	= shift;
	my $addr	= refaddr( $self );
	
	if (exists( $booleans{ $addr })) {
		return RDF::Trine::Iterator::Boolean->new( [$booleans{ $addr }] );
	} else {
		my $vars	= delete $variables{ $addr };
		my $results	= delete $results{ $addr };
		my %args;
		if (exists $extra{ $addr }) {
			$args{ extra_result_data }	= delete $extra{ $addr };
		}
		return RDF::Trine::Iterator::Bindings->new( $results, $vars, %args );
	}
}

=begin private

=item C<< start_element >>

=cut

sub start_element {
	my $self	= shift;
	my $el		= shift;
	my $tag		= $el->{LocalName};
	my $addr	= refaddr( $self );
	
	unshift( @{ $tagstack{ $addr } }, [$tag, $el] );
	if ($expecting_string{ $tag }) {
		$strings{ $addr }	= '';
	}
}

=item C<< end_element >>

=cut

sub end_element {
	my $self	= shift;
	my $class	= ref($self);
	my $eel		= shift;
	my $addr	= refaddr( $self );
	my $string	= $strings{ $addr };
	my $taginfo	= shift( @{ $tagstack{ $addr } } );
	my ($tag, $el)	= @$taginfo;
	
	if ($tag eq 'variable') {
		push( @{ $variables{ $addr } }, $el->{Attributes}{'{}name'}{Value});
	} elsif ($tag eq 'boolean') {
		$booleans{ $addr }	= ($string eq 'true') ? 1 : 0;
	} elsif ($tag eq 'binding') {
		my $name	= $el->{Attributes}{'{}name'}{Value};
		my $value	= delete( $values{ $addr } );
		$bindings{ $addr }{ $name }	= $value;
	} elsif ($tag eq 'result') {
		my $result	= delete( $bindings{ $addr } );
		push( @{ $results{ $addr } }, $result );
	} elsif ($tag eq 'bnode') {
		$values{ $addr }	= RDF::Trine::Node::Blank->new( $string );
	} elsif ($tag eq 'uri') {
		$values{ $addr }	= RDF::Trine::Node::Resource->new( $string );
	} elsif ($tag eq 'literal') {
		my ($lang, $dt);
		if (my $dtinf = $el->{Attributes}{'{}datatype'}) {
			$dt		= $dtinf->{Value};
		} elsif (my $langinf = $el->{Attributes}{'{http://www.w3.org/XML/1998/namespace}lang'}) {
			$lang	= $langinf->{Value};
		}
		$values{ $addr }	= RDF::Trine::Node::Literal->new( $string, $lang, $dt );
	} elsif ($tag eq 'link') {
		my $link	= $el->{Attributes}{'{}href'}{Value};
		if ($link and $link =~ m<^data:text/xml,%3Cextra>) {
			my $u		= URI->new( $link );
			my $data	= $u->data;
			my $p		= XML::SAX::ParserFactory->parser(Handler => $self);
			$p->parse_string( $data );
		}
	} elsif ($tag eq 'extra') {
		my $key		= $el->{Attributes}{'{}name'}{Value};
		my $value	= delete( $extrakeys{ $addr } );
		push(@{ $extra{ $addr }{ $key } }, $value);
	} elsif ($tag eq 'extrakey') {
		my $key		= $el->{Attributes}{'{}id'}{Value};
		my $value	= $string;
		push(@{ $extrakeys{ $addr }{ $key } }, $value);
	}
}

=item C<< extra >>

=cut

sub extra {
	my $self	= shift;
	my $addr	= refaddr( $self );
	return $extra{ $addr };
}

=item C<< characters >>

=cut

sub characters {
	my $self	= shift;
	my $data	= shift;
	my $addr	= refaddr( $self );
	
	my $tag		= $self->_current_tag;
	if ($expecting_string{ $tag }) {
		my $chars	= $data->{Data};
		$strings{ $addr }	.= $chars;
	}
}

sub _current_tag {
	my $self	= shift;
	my $addr	= refaddr( $self );
	return $tagstack{ $addr }[0][0];
}

sub DESTROY {
	my $self	= shift;
	my $addr	= refaddr( $self );
	delete $strings{ $addr };
	delete $results{ $addr };
	delete $tagstack{ $addr };
	delete $values{ $addr };
	delete $bindings{ $addr };
	delete $booleans{ $addr };
	delete $variables{ $addr };
	delete $extra{ $addr };
	delete $extrakeys{ $addr };
}


1;

__END__

=end private

=back

=head1 AUTHOR

Gregory Todd Williams  C<< <greg@evilfunhouse.com> >>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2007, Gregory Todd Williams C<< <gwilliams@cpan.org> >>. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.


