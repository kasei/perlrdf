# RDF::Trine::Iterator::SAXHandler
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Iterator::SAXHandler - SAX Handler for parsing SPARQL XML Results format

=head1 VERSION

This document describes RDF::Trine::Iterator::SAXHandler version 1.012

=head1 STATUS

This module's API and functionality should be considered unstable.
In the future, this module may change in backwards-incompatible ways,
or be removed entirely. If you need functionality that this module provides,
please L<get in touch|http://www.perlrdf.org/>.

=head1 SYNOPSIS

    use RDF::Trine::Iterator::SAXHandler;
    my $handler = RDF::Trine::Iterator::SAXHandler->new();
    my $p = XML::SAX::ParserFactory->parser(Handler => $handler);
    $p->parse_file( $string );
    my $iter = $handler->iterator;

=head1 METHODS

Beyond the methods documented below, this class inherits methods from the
L<XML::SAX::Base> class.

=over 4

=cut

package RDF::Trine::Iterator::SAXHandler;

use strict;
use warnings;
use Scalar::Util qw(refaddr);
use base qw(XML::SAX::Base);

use Data::Dumper;
use RDF::Trine::VariableBindings;

our ($VERSION);
BEGIN {
	$VERSION	= '1.012';
}

my %strings;
my %tagstack;
my %results;
my %values;
my %bindings;
my %booleans;
my %variables;
my %has_head;
my %has_end;
my %result_count;
my %result_handlers;
my %config;

my %expecting_string	= map { $_ => 1 } qw(boolean bnode uri literal);

=item C<< new ( [ \&handler ] ) >>

Returns a new XML::SAX handler object. If C<< &handler >> is supplied, it will
be called with a variable bindings object as each is parsed, bypassing the
normal process of collecting the results for retrieval via an iterator object.

=cut

sub new {
	my $class	= shift;
	my $self	= $class->SUPER::new();
	if (@_) {
		my $addr	= refaddr( $self );
		my $code	= shift;
		my $args	= shift || {};
		$result_handlers{ $addr }	= $code;
		$config{ $addr }			= { %$args };
	}
	return $self;
}

=item C<< iterator >>

Returns the RDF::Trine::Iterator object after parsing is complete.

=cut

sub iterator {
	my $self	= shift;
	my $addr	= refaddr( $self );
	
	if (exists( $booleans{ $addr })) {
		return $self->iterator_class->new( [$booleans{ $addr }] );
	} else {
		my $vars	= delete $variables{ $addr };
		my $results	= delete $results{ $addr };
		return $self->iterator_class->new( $results, $vars );
	}
}

# =item C<< has_head >>
# 
# Returns true if the <head/> element has been completely parsed, false otherwise.
# 
# =cut
# 
# sub has_head {
# 	my $self	= shift;
# 	my $addr	= refaddr( $self );
# 	return ($has_head{ $addr }) ? 1 : 0;
# }
# 
# =item C<< has_end >>
# 
# Returns true if the <sparql/> element (the entire iterator) has been completely
# parsed, false otherwise.
# 
# =cut
# 
# sub has_end {
# 	my $self	= shift;
# 	my $addr	= refaddr( $self );
# 	return ($has_end{ $addr }) ? 1 : 0;
# }

=item C<< iterator_class >>

Returns the iterator class appropriate for the parsed results (either
::Iterator::Boolean or ::Iterator::Bindings).

=cut

sub iterator_class {
	my $self	= shift;
	my $addr	= refaddr( $self );
	if (exists( $booleans{ $addr })) {
		return 'RDF::Trine::Iterator::Boolean';
	} else {
		return 'RDF::Trine::Iterator::Bindings';
	}
}

=item C<< iterator_args >>

Returns the arguments suitable for passing to the iterator constructor after
the iterator data.

=cut

sub iterator_args {
	my $self	= shift;
	my $addr	= refaddr( $self );
	
	if (exists( $booleans{ $addr })) {
		return;
	} else {
		my $vars	= $variables{ $addr };
		return ($vars);
	}
}

=item C<< pull_result >>

Returns the next result from the iterator, if available (if it has been parsed yet).
Otherwise, returns the empty list.

=cut

sub pull_result {
	my $self	= shift;
	my $addr	= refaddr( $self );
	
	if (exists( $booleans{ $addr })) {
		if (exists($booleans{ $addr })) {
			return [$booleans{ $addr }];
		}
	} else {
		if (scalar(@{ $results{ $addr } || [] })) {
			my $result	= shift( @{ $results{ $addr } } );
			return $result;
		}
	}
	return;
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
	
	if ($tag eq 'head') {
		$has_head{ $addr }	= 1;
		if (my $code = $result_handlers{ $addr }) {
			if ($config{ $addr }{ variables }) {
				$code->( $variables{ $addr } );
			}
		}
	} elsif ($tag eq 'sparql') {
		$has_end{ $addr }	= 1;
	} elsif ($tag eq 'variable') {
		push( @{ $variables{ $addr } }, $el->{Attributes}{'{}name'}{Value});
	} elsif ($tag eq 'boolean') {
		$booleans{ $addr }	= ($string eq 'true') ? 1 : 0;
	} elsif ($tag eq 'binding') {
		my $name	= $el->{Attributes}{'{}name'}{Value};
		my $value	= delete( $values{ $addr } );
		$bindings{ $addr }{ $name }	= $value;
	} elsif ($tag eq 'result') {
		my $result	= delete( $bindings{ $addr } ) || {};
		$result_count{ $addr }++;
		my $vb	= RDF::Trine::VariableBindings->new( $result );
		
		if (my $code = $result_handlers{ $addr }) {
			$code->( $vb );
		} else {
			push( @{ $results{ $addr } }, $vb );
		}
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
	}
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
	delete $has_head{ $addr };
	delete $has_end{ $addr };
	delete $result_count{ $addr };
	delete $result_handlers{ $addr };
	delete $config{ $addr };
}


1;

__END__

=end private

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
