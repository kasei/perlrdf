=head1 NAME

RDF::Query::Functions::Jena - Jena/ARQ work-alike functions

=head1 VERSION

This document describes RDF::Query::Functions::Jena version 2.918.

=head1 DESCRIPTION

Defines the following functions:

=over

=item * java:com.hp.hpl.jena.query.function.library.langeq

=item * java:com.hp.hpl.jena.query.function.library.listMember

=item * java:com.hp.hpl.jena.query.function.library.now

=item * java:com.hp.hpl.jena.query.function.library.sha1sum

=back

=cut

package RDF::Query::Functions::Jena;

use strict;
use warnings;
use Log::Log4perl;
our ($VERSION, $l);
BEGIN {
	$l			= Log::Log4perl->get_logger("rdf.query.functions.jena");
	$VERSION	= '2.918';
}

use Digest::SHA qw(sha1_hex);
use I18N::LangTags;
use Scalar::Util qw(blessed reftype refaddr looks_like_number);

=begin private

=item C<< install >>

Documented in L<RDF::Query::Functions>.

=end private

=cut

sub install {
	RDF::Query::Functions->install_function(
		["http://jena.hpl.hp.com/ARQ/function#sha1sum", "java:com.hp.hpl.jena.query.function.library.sha1sum"],
		sub {
			my $query	= shift;
			my $node	= shift;
			
			my $value;
			if ($node->isa('RDF::Query::Node::Literal')) {
				$value	= $node->literal_value;
			} elsif ($node->isa('RDF::Query::Node::Resource')) {
				$value	= $node->uri_value;
			} else {
				throw RDF::Query::Error::TypeError -text => "jena:sha1sum called without a literal or resource";
			}
			my $hash	= sha1_hex( $value );
			return RDF::Query::Node::Literal->new( $hash );
		}
	);
	
	RDF::Query::Functions->install_function(
		["http://jena.hpl.hp.com/ARQ/function#now", "java:com.hp.hpl.jena.query.function.library.now"],
		sub {
			my $query	= shift;
			my $dt		= DateTime->now();
			my $f		= ref($query) ? $query->dateparser : DateTime::Format::W3CDTF->new;
			my $value	= $f->format_datetime( $dt );
			return RDF::Query::Node::Literal->new( $value, undef, 'http://www.w3.org/2001/XMLSchema#dateTime' );
		}
	);
	
	RDF::Query::Functions->install_function(
		["http://jena.hpl.hp.com/ARQ/function#langeq", "java:com.hp.hpl.jena.query.function.library.langeq"],
		sub {
			my $query	= shift;
			my $node	= shift;
			my $lang	= shift;
			my $litlang	= $node->literal_value_language;
			my $match	= $lang->literal_value;
			return I18N::LangTags::is_dialect_of( $litlang, $match )
				? RDF::Query::Node::Literal->new('true', undef, 'http://www.w3.org/2001/XMLSchema#boolean')
				: RDF::Query::Node::Literal->new('false', undef, 'http://www.w3.org/2001/XMLSchema#boolean');
		}
	);
	
	RDF::Query::Functions->install_function(
		["http://jena.hpl.hp.com/ARQ/function#listMember", "java:com.hp.hpl.jena.query.function.library.listMember"],
		sub {
			my $query	= shift;
			
			my $list	= shift;
			my $value	= shift;
			
			my $first	= RDF::Query::Node::Resource->new( 'http://www.w3.org/1999/02/22-rdf-syntax-ns#first' );
			my $rest	= RDF::Query::Node::Resource->new( 'http://www.w3.org/1999/02/22-rdf-syntax-ns#rest' );
			
			my $result;
			LIST: while ($list) {
				if ($list->is_resource and $list->uri_value eq 'http://www.w3.org/1999/02/22-rdf-syntax-ns#nil') {
					return RDF::Query::Node::Literal->new('false', undef, 'http://www.w3.org/2001/XMLSchema#boolean');
				} else {
					my $stream	= $query->model->get_statements( $list, $first, undef );
					while (my $stmt = $stream->next()) {
						my $member	= $stmt->object;
						return RDF::Query::Node::Literal->new('true', undef, 'http://www.w3.org/2001/XMLSchema#boolean') if ($value->equal( $member ));
					}
					
					my $stmt	= $query->model->get_statements( $list, $rest, undef )->next();
					return RDF::Query::Node::Literal->new('false', undef, 'http://www.w3.org/2001/XMLSchema#boolean') unless ($stmt);
					
					my $tail	= $stmt->object;
					if ($tail) {
						$list	= $tail;
						next; #next LIST;
					} else {
						return RDF::Query::Node::Literal->new('false', undef, 'http://www.w3.org/2001/XMLSchema#boolean');
					}
				}
			}
			
			return RDF::Query::Node::Literal->new('false', undef, 'http://www.w3.org/2001/XMLSchema#boolean');
		}
	);
}

1;

__END__

=head1 AUTHOR

 Gregory Williams <gwilliams@cpan.org>.

=cut
