=head1 NAME

RDF::Endpoint - A SPARQL Endpoint (server) implementation based on RDF::Query.

=head1 VERSION

This document describes RDF::Endpoint version 1.000, released XXX August 2009.

=head1 SYNOPSIS

 my $s	= RDF::Endpoint::Server->new_with_model( $model,
   Port    => $port,
   Prefix  => '/path/to/server-root/',
 );
 
 my $pid	= $s->run();

=head1 DESCRIPTION

...

=head1 METHODS

=over 4

=cut

package RDF::Endpoint;

use strict;
use warnings;
no warnings 'redefine';
no warnings 'redefine';

our $VERSION;
BEGIN {
	$VERSION	= '1.000';
}

use Template;
use RDF::Query;
use File::Spec;
use File::Slurp;
use URI::Escape;
use Data::Dumper;
use LWP::UserAgent;
use HTTP::Negotiate qw(choose);

use List::Util qw(first);
use Scalar::Util qw(blessed);

use RDF::Endpoint::Error qw(:try);

use RDF::Trine::Store::DBI;
use RDF::Trine::Model::StatementFilter;


=item C<< new ( $dsn, $username, $password, $model_name, SubmitURL => $url, IncludePath => $path, %optional_args ) >>

Returns a new Endpoint object based on an RDF::Trine::Store::DBI model created
with the specified DBI $dsn, $username, $password, and $model_name.

The supplied $url should map back to the endpoint server, allowing query forms
to be submitted and handled properly.

The IncludePath $path variable is used as the base path for templates used by
the endpoint including HTML forms and query results. If not supplied, it
defaults to './include'.

=cut

sub new {
	my $class		= shift;
	my $dsn			= shift;
	my $user		= shift;
	my $pass		= shift;
	my $model		= shift;
	my %args		= @_;
	
	my $incpath		= $args{ IncludePath } || './include';
	my $submiturl	= $args{ SubmitURL };
	
	my $store		= RDF::Trine::Store::DBI->new( $model, $dsn, $user, $pass );
	my $m			= RDF::Trine::Model->new( $store );
	return $class->new_with_model( $m, %args, dbh => $store->dbh );
}

=item C<< new_with_model ( $model, SubmitURL => $url, IncludePath => $path, IncludePath => $path, %optional_args ) >>

Returns a new Endpoint object based on the supplied RDF::Trine::Model object.

The supplied $url should map back to the endpoint server, allowing query forms
to be submitted and handled properly.

The IncludePath $path variable is used as the base path for templates used by
the endpoint including HTML forms and query results. If not supplied, it
defaults to './include'.

=cut

sub new_with_model {
	my $class		= shift;
	my $m			= shift;
	my %args		= @_;
	
	my $incpath		= $args{ IncludePath } || './include';
	my $submiturl	= $args{ SubmitURL };
	
	my $self		= bless( {
						incpath		=> $incpath,
						submit		=> $submiturl,
						_model		=> $m,
						_ua			=> LWP::UserAgent->new,
					}, $class );
	if (my $dbh = $args{dbh}) {
		$self->{_dbh}	= $dbh;
	}
	
	$self->{_ua}->agent( "RDF::Endpoint/${VERSION}" );
	$self->{_ua}->default_header( 'Accept' => 'application/turtle,application/x-turtle,application/rdf+xml' );
	
	my $template	= Template->new( {
						INCLUDE_PATH	=> $incpath,
					} );
	$self->{_tt}	= $template;
	return $self;
}

sub query_page {
	my $self	= shift;
	my $cgi		= shift;
	my $prefix	= shift;
	
	my $variants = [
		['html',	1.000, 'text/html', undef, undef, undef, 1],
		['html',	1.000, 'application/xhtml+xml', undef, undef, undef, 1],
		['rdf',		1.000, 'application/rdf+xml', undef, undef, undef, 1],
		['turtle',	1.000, 'text/turtle', undef, undef, undef, 1],
	];
	my $choice	= choose($variants) || 'html';
#	warn "conneg prefers: $choice\n";
	
	my $model		= $self->_model;
	my $count		= $model->count_statements;
	my @extensions	= map { { url => $_ } } RDF::Query->supported_extensions;
	my @functions	= map { { url => $_ } } RDF::Query->supported_functions;
	my $submit		= $self->submit_url;
	if ($choice eq 'html') {
		my $tt		= $self->_template;
		my $file	= 'index.html';
		
		print $cgi->header( -status => "200 OK", -type => 'text/html; charset=utf-8' );
		$tt->process( $file, {
			submit_url		=> $submit,
			triples			=> $count,
			functions		=> \@functions,
			extensions		=> \@extensions,
		} ) || die $tt->error();
	} else {
		my $tt		= $self->_template;
		my $file	= 'endpoint_description.rdf';
		
		print $cgi->header( -status => "200 OK", -type => 'text/turtle; charset=utf-8' );
		$tt->process( $file, {
			submit_url		=> $submit,
			triples			=> $count,
			functions		=> \@functions,
			extensions		=> \@extensions,
		} ) || die $tt->error();
	}
}

sub run_query {
	my $self	= shift;
	my $cgi		= shift;
	my $sparql	= shift;
	
	my $model		= $self->_model;
	
	my $variants = [
		['html',			1.000, 'text/html', undef, undef, undef, 1],
		['html-xhtml',		0.900, 'application/xhtml+xml', undef, undef, undef, 1],
		['xml-sparqlres',	0.900, 'application/sparql-results+xml', undef, undef, undef, 1],
		['json-sparqlres',	0.800, 'application/sparql-results+json', undef, undef, undef, 1],
		['json-sparqlres',	0.800, 'application/json', undef, undef, undef, 1],
		['xml-rdf',			0.900, 'application/rdf+xml', undef, undef, undef, 1],
		['xml',				0.500, 'text/xml', undef, undef, undef, 1],
		['xml',				0.500, 'application/xml', undef, undef, undef, 1],
	];
	
	if (my $t = $cgi->param('mime-type')) {
		$ENV{HTTP_ACCEPT}	= $t;
	}
	my @choices	= grep { $_->[1] > 0 } choose($variants);
#	warn "conneg prefers: " . Dumper(\@choices) . "\n";
	
	my $query	= RDF::Query->new( $sparql, { lang => 'sparql11', update => 1 } );
	unless ($query) {
		my $error	= RDF::Query->error;
		throw RDF::Endpoint::Error::MalformedQuery -text => $error, -value => 400;
	}
	my $stream	= $query->execute( $model );
	if ($stream) {
		my $tt		= $self->_template;
		my $file	= 'results.html';
		
		if ($stream->isa('RDF::Trine::Iterator::Graph')) {
			# graph results can't be serialized as JSON
			@choices	= grep { not m/^json/ } @choices;
		}
		
		my $choice	= shift @choices;
		if (ref($choice)) {
			my $choice_name	= $choice->[0];
			my %header_args	= ( '-X-Endpoint-Description' => $self->submit_url );
			if ($choice_name =~ /html/) {
				local($Template::Directive::WHILE_MAX)	= 1_000_000_000;
				print $cgi->header( -type => "text/html; charset=utf-8", %header_args );
				my $total	= 0;
				my $rtype	= $stream->type;
				my $rstream	= ($rtype eq 'graph') ? $stream->unique() : $stream;
				my $content;
				$tt->process( $file, {
					result_type => $rtype,
					next_result => sub {
									my $r = $rstream->next_result;
									$total++ if ($r);
									return $r
								},
					columns		=> sub { $rstream->binding_names },
					values		=> sub {
									my $row 	= shift;
									my $col 	= shift;
									my $node	= $row->{ $col };
									my $str		= ($node) ? $node->as_string : '';
									return _html_escape( $str )
								},
					boolean		=> sub { $rstream->get_boolean },
					nodes		=> sub {
									my $s 		= shift;
									my @nodes	= map { $s->$_() } qw(subject predicate object);
									my @strs	= map { ($_) ? $_->as_string : '' } @nodes;
									return [ map { _html_escape( $_ ) } @strs ];
								},
					total		=> sub { $total },
					feed_url	=> $self->feed_url( $cgi ),
				}, \$content ) or warn $tt->error();
				print $content;
			} elsif ($choice_name =~ /xml/) {
				my $type	= ($stream->isa('RDF::Trine::Iterator::Graph'))
							? 'application/rdf+xml'
							: 'application/sparql-results+xml';
				print $cgi->header( -type => "$type; charset=utf-8", %header_args );
				my $outfh	= select();
				$stream->print_xml( $outfh );
			} elsif ($choice_name =~ /json/) {
				my $type	= 'application/sparql-results+json';
				print $cgi->header( -type => "$type; charset=utf-8", %header_args );
				print $stream->as_json;
			} else {
				print $cgi->header( -type => "text/plain; charset=utf-8", %header_args );
				my $outfh	= select();
				$stream->print_xml( $outfh );
			}
			
		} else {
			throw RDF::Endpoint::Error::EncodingError -text => 'No acceptable result encoding was found matching the request', -value => 406;
		}
	} else {
		my $error	= RDF::Query->error;
		throw RDF::Endpoint::Error::InternalError -text => $error, -value => 500;
	}
}

sub feed_url {
	my $self	= shift;
	my $cgi		= shift;
	my @keys	= grep { $_ ne 'mime-type' } $cgi->param();
	my %args;
	foreach my $key ($cgi->param()) {
		$args{ $key }	= $cgi->param( $key );
	}
	$args{ 'mime-type' }	= 'application/rdf+xml';
	my $url		= '?' . join('&', map { join('=', uri_escape( $_ ), uri_escape( $args{ $_ } )) } (keys %args));
	return $url
}

sub stream_as_html {
	my $self	= shift;
	my $stream	= shift;
	
	if ($stream->isa('RDF::Trine::Iterator::Graph')) {
		print "<html><head><title>SPARQL Results</title></head><body>\n";
		print "</body></html>\n";
	} elsif ($stream->isa('RDF::Trine::Iterator::Boolean')) {
		print "<html><head><title>SPARQL Results</title></head><body>\n";
		print (($stream->get_boolean) ? "True" : "False");
		print "</body></html>\n";
	} elsif ($stream->isa('RDF::Trine::Iterator::Bindings')) {
		print "<html><head><title>SPARQL Results</title>\n";
		print <<"END";
			<style type="text/css">
				table {
					border: 1px solid #000;
					border-collapse: collapse;
				}
				
				th { background-color: #ddd; }
				td, th {
					padding: 1px 5px 1px 5px;
					border: 1px solid #000;
				}
			</style>
END
		print "</head><body>\n";
		print "<table>\n<tr>\n";
		
		my @names	= $stream->binding_names;
		my $columns	= scalar(@names);
		foreach my $name (@names) {
			print "\t<th>" . $name . "</th>\n";
		}
		print "</tr>\n";
		
		my $count	= 0;
		while (my $row = $stream->next) {
			$count++;
			print "<tr>\n";
			foreach my $k (@names) {
				my $node	= $row->{ $k };
				my $value	= ($node) ? $node->as_string : '';
				$value		=~ s/&/&amp;/g;
				$value		=~ s/</&lt;/g;
				print "\t<td>" . $value . "</td>\n";
			}
			print "</tr>\n";
		}
		print qq[<tr><th colspan="$columns">Total: $count</th></tr>];
		print "</table>\n";
		print "</body></html>\n";
	} else {
	
	}
}

sub submit_url {
	my $self	= shift;
	return $self->{submit};
}

sub _template {
	my $self	= shift;
	return $self->{_tt};
}

sub _agent {
	my $self	= shift;
	return $self->{_ua};
}

sub _model {
	my $self	= shift;
	return $self->{_model};
}

sub _html_escape {
	my $text	= shift || '';
	for ($text) {
		s/&/&amp;/g;
		s/</&lt;/g;
		s/>/&gt;/g;
		s/'/&apos;/g;
		s/"/&quot;/g;
	}
	return $text;
}

sub error {
	my $self	= shift;
	my $cgi		= shift;
	my $code	= shift;
	my $name	= shift;
	my $error	= shift;
	print $cgi->header( -status => "${code} ${name}" );
	print "<html><head><title>${name}</title></head><body><h1>${name}</h1><p>${error}</p></body></html>";
	return;
}

sub redir {
	my $self	= shift;
	my $cgi		= shift;
	my $code	= shift;
	my $message	= shift;
	my $url		= shift;
	print $cgi->header( -status => "${code} ${message}", -Location => $url );
	return;
}

sub dbh {
	my $self	= shift;
	my $dbh		= $self->{_dbh};
	return $dbh;
}

1;

__END__

=head1 AUTHOR

 Gregory Todd Williams <gwilliams@cpan.org>

=head1 COPYRIGHT

Copyright (c) 2007-2009 Gregory Todd Williams. This
program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
