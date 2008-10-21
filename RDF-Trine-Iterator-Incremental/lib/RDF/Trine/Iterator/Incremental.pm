# RDF::Trine::Model::RDFS
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Iterator::Incremental - Incremental Parser for SPARQL XML Results Format

=head1 METHODS

=over 4

=cut

package RDF::Trine::Iterator::Incremental;

use strict;
use warnings;
use base qw(RDF::Trine::Iterator);

=item C<< new ( $socket, $chunk_size ) >>

Returns a new iterator using the XML content read from C<< $socket >>.
This call will block until the entire <head/> element is read from the socket,
with results being read incrementally as the C<< next >> method is called.

=cut

sub new {
	my $class		= shift;
	my $handle		= shift;
	my $chunk_size	= shift || 1024;
	my $prelude		= shift || '';
	
	eval "
		require XML::SAX::Expat;
		require XML::SAX::Expat::Incremental;
	";
	if ($@) {
		die $@;
	}
	local($XML::SAX::ParserPackage)	= 'XML::SAX::Expat::Incremental';
	my $handler	= RDF::Trine::Iterator::SAXHandler->new();
	my $p	= XML::SAX::Expat::Incremental->new( Handler => $handler );
	$p->parse_start;

	my $l		= Log::Log4perl->get_logger("rdf.trine.iterator");
	
	if (length($prelude)) {
		$l->debug($prelude);
		$p->parse_more( $prelude );
	}
	
	until ($handler->has_head) {
		my $buffer;
		$handle->sysread($buffer, $chunk_size);
		$l->debug($buffer);
		if (my $size = length($buffer)) {
			$l->debug("read $size bytes");
			$p->parse_more( $buffer );
		} else {
			$l->debug("read 0 bytes");
			if ($handle->eof) {
				$l->debug("-> handle is at eof");
				return undef;
			}
			select( undef, undef, undef, 0.25 );
		}
	}
	
	$l->debug("iterator has head. now returning an iterative stream.");
	
	my @args	= $handler->iterator_args;
	my $iter	= sub {
		my $data;
		while (not($handler->has_end) and not($data = $handler->pull_result)) {
			my $buffer;
			$handle->sysread($buffer, $chunk_size);
			$l->debug($buffer);
			if (my $size = length($buffer)) {
				$l->debug("read $size bytes");
				$p->parse_more( $buffer );
			} else {
				$l->debug("read 0 bytes");
				if ($handle->eof) {
					$l->debug("-> handle is at eof");
					return undef;
				}
				select( undef, undef, undef, 0.25 );
			}
		}
		return $data;
	};
	return $handler->iterator_class->new( $iter, @args );
}


1;

__END__

=back

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=cut
