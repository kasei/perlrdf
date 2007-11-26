# RDF::Base::Parser::RDFXML_Native
# -------------
# $Revision $
# $Date $
# -----------------------------------------------------------------------------


=head1 NAME

RDF::Base::Parser::RDFXML - Base class for RDF parser classes.


=head1 VERSION

This document describes RDF::Base::Parser::RDFXML version 0.0.1


=head1 SYNOPSIS

    use RDF::Base::Parser::RDFXML;

=head1 DESCRIPTION

=for author to fill in:
    Write a full description of the module and its features here.
    Use subsections (=head2, =head3) as appropriate.


=cut

package RDF::Base::Parser::RDFXML_Native;

use version; $VERSION = qv('0.0.1');

use utf8;
use strict;
use warnings;
use Data::Dumper;
use RDF::Base::Iterator::Statement;
use RDF::SPARQLResults qw(smap sgrep);

use XML::SAX::ParserFactory;
use LWP::Simple qw(get);
use Params::Coerce 'coerce';

# Module implementation here

=head1 METHODS

=over 4

=cut



=item C<< new >>

Returns a new rdf-xml parser.

=cut

sub new {
	my $class	= shift;
	my $parser	= XML::SAX::ParserFactory->parser();
	my $self	= bless( { parser => $parser }, $class );
	return $self;
}





=item C<< parse_as_stream ( $SOURCE_URI, $BASE_URI ) >>

Parse the syntax at the RDF::Redland::URI I<SOURCE_URI> with optional base
RDF::Redland::URI I<BASE_URI>.  If the base URI is given then the content is
parsed as if it was at the base URI rather than the source URI.

Returns an RDF::Redland::Stream of RDF::Redland::Statement objects or
undef on failure.

=cut

sub parse_as_stream ($$) {
	my $self		= shift;
	my $source_uri	= coerce( 'RDF::Query::Node::Resource', shift );
	my $base_uri	= shift;
	
	my $content		= get( $source_uri->uri_value );
	my $stream		= $self->parse_string_as_stream($content, $base_uri);
	my $iter		= smap { $_->{context} = $base_uri; $_ } $stream;
	
	return $iter;
}

=item C<< parse_into_model ( SOURCE_URI BASE_URI MODEL [HANDLER] ) >>

=cut

sub parse_into_model ($$$;$) {
	my $self		= shift;
	my $source_uri	= shift;
	my $base_uri	= shift;
	my $model		= shift;
	
	my $stream	= $self->parse_as_stream( $source_uri, $base_uri );
	my $count	= 0;
	while (my $st = $stream->next) {
		$model->add_statement( $st );
		$count++;
		
		my $storage	= $model->storage;
#		warn "parse_into_model: ($count) ($model) ($storage)\n" if ($count % 50 == 0);
	}
}

=item C<< parse_string_as_stream ( STRING BASE_URI ) >>

=cut

sub parse_string_as_stream ($$) {
	my $self		= shift;
	my $string		= shift;
	my $base_uri	= shift;
	my $stream		=  $self->{parser}->parse_string( $string, Handler => $self );
	return $stream;
}

=item C<< parse_string_into_model ( STRING BASE_URI MODEL [HANDLER] ) >>

=cut

sub parse_string_into_model ($$$;$) {
	my $self	= shift;
	my $string	= shift;
	my $base_uri	= shift;
	my $model	= shift;
	
	my $stream	= $self->parse_string( $string, Handler => $self );
	while (my $st = $stream->next) {
		$model->add_statement( $st );
	}
}




=begin private

=item C<< parser_info >>

Returns the parser info including serialization name, mime-type and uri.

=end private

=cut

sub parser_info {
	return {
# 		name		=> qr/rdf-?xml/,
# 		mimetype	=> 'application/rdf+xml',
# 		uri			=> '...',
		name		=> 'xxx', #qr/rdf-?xml/,
		mimetype	=> 'xxx', #'application/rdf+xml',
		uri			=> '...',
	};
}


sub start_document {
	my ($self, $doc) = @_;
	# process document start event
	warn "start doc: " . Dumper($doc);
	$self->{'elements'}	= [];
}

sub start_element {
	my ($self, $el) = @_;
	my $element	= join('', @{ $el }{ 'NamespaceURI', 'LocalName' } );
	
	if (@{ $self->{'elements'} } == 0 and $element eq 'http://www.w3.org/1999/02/22-rdf-syntax-ns#RDF') {
		# ignore rdf:RDF
	} else {
		warn "+ start element: <$element>\n";
		my $atts	= $el->{'Attributes'};
		my %atts	= map { join('', @{$_}{qw(NamespaceURI LocalName)}) => $_->{'Value'} } (values %$atts);
		
		my $count	= scalar(@{ $self->{'elements'} });
		
		
		push( @{ $self->{'elements'} }, $element );
		if ($count % 2 == 0 and $self->{'literal'}) {
			# looking for a resource
			if ($element eq 'http://www.w3.org/1999/02/22-rdf-syntax-ns#Description') {
				warn "untyped object";
			} else {
				warn "typed object: $element";
			}
		} else {
			# looking for a predicate
			warn "predicate: $element";
			# check if predicate contains rdf:resource
			if (my $object = $atts{'http://www.w3.org/1999/02/22-rdf-syntax-ns#resource'}) {
				push( @{ $self->{'elements'} }, $object );
				warn "got triple with p,o: $element, $object\n";
			} else {
				# might be a literal
				delete $self->{'literal'};
			}
		}
		
		warn Dumper(\%atts);
	}
}

sub end_element {
	my $self	= shift;
#	warn "- end element    <$element>\n";
	my $count	= scalar(@{ $self->{'elements'} });
	my $element	= pop(@{ $self->{'elements'} });
	
	unless ($count == 0) {
		if ($count % 3 == 0) {
			my $object	= $element;
			warn "got triple with resource as object\n";
		} elsif ($count % 2 == 0 and $self->{'literal'}) {
			my $literal	= delete $self->{'literal'};
			warn "got triple with literal as object: «${literal}»\n";
		}
	}
	
}

sub characters {
	my $self	= shift;
	my $data	= shift;
	my $text	= $data->{ Data };
	my $count	= scalar(@{ $self->{'elements'} });
	
	if ($count % 2 == 0) {
		no warnings 'uninitialized';
		$self->{'literal'}	.=	$text;
		warn "characters: «${text}»\n";
	}
}


1; # Magic true value required at end of module
__END__



=back

=head1 DIAGNOSTICS

=for author to fill in:
    List every single error and warning message that the module can
    generate (even the ones that will "never happen"), with a full
    explanation of each problem, one or more likely causes, and any
    suggested remedies.

=over

=item C<< Error message here, perhaps with %s placeholders >>

[Description of error here]

=item C<< Another error message here >>

[Description of error here]

[Et cetera, et cetera]

=back


=head1 CONFIGURATION AND ENVIRONMENT

=for author to fill in:
    A full explanation of any configuration system(s) used by the
    module, including the names and locations of any configuration
    files, and the meaning of any environment variables or properties
    that can be set. These descriptions must also include details of any
    configuration language used.
  
RDF::Base::Parser::RDFXML requires no configuration files or environment variables.


=head1 DEPENDENCIES

=for author to fill in:
    A list of all the other modules that this module relies upon,
    including any restrictions on versions, and an indication whether
    the module is part of the standard Perl distribution, part of the
    module's distribution, or must be installed separately. ]

None.


=head1 INCOMPATIBILITIES

=for author to fill in:
    A list of any modules that this module cannot be used in conjunction
    with. This may be due to name conflicts in the interface, or
    competition for system or program resources, or due to internal
    limitations of Perl (for example, many modules that use source code
    filters are mutually incompatible).

None reported.


=head1 BUGS AND LIMITATIONS

=for author to fill in:
    A list of known problems with the module, together with some
    indication Whether they are likely to be fixed in an upcoming
    release. Also a list of restrictions on the features the module
    does provide: data types that cannot be handled, performance issues
    and the circumstances in which they may arise, practical
    limitations on the size of data sets, special cases that are not
    (yet) handled, etc.

No bugs have been reported.

Please report any bugs or feature requests to
C<greg@evilfunhouse.com>.


=head1 AUTHOR

Gregory Todd Williams  C<< <greg@evilfunhouse.com> >>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2006, Gregory Todd Williams C<< <greg@evilfunhouse.com> >>. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.


