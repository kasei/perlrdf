# RDF::Trine
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine - An RDF Framework for Perl

=head1 VERSION

This document describes RDF::Trine version 1.012

=head1 SYNOPSIS

  use RDF::Trine;
  
  my $store = RDF::Trine::Store::Memory->new();
  my $model = RDF::Trine::Model->new($store);
  
  # parse some web data into the model, and print the count of resulting RDF statements
  RDF::Trine::Parser->parse_url_into_model( 'http://kasei.us/about/foaf.xrdf', $model );
  print $model->size . " RDF statements parsed\n";
  
  # Create a namespace object for the foaf vocabulary
  my $foaf = RDF::Trine::Namespace->new( 'http://xmlns.com/foaf/0.1/' );
  
  # Create a node object for the FOAF name property
  my $pred = $foaf->name;
  # alternatively:
  # my $pred = RDF::Trine::Node::Resource->new('http://xmlns.com/foaf/0.1/name');
  
  # Create an iterator for all the statements in the model with foaf:name as the predicate
  my $iter = $model->get_statements(undef, $pred, undef);
  
  # Now print the results
  print "Names of things:\n";
  while (my $st = $iter->next) {
    my $s = $st->subject;
    my $name = $st->object;
    
    # $s and $name have string overloading, so will print correctly
    print "The name of $s is $name\n";
  }

=head1 DESCRIPTION

RDF::Trine provides an Resource Descriptive Framework (RDF) with an emphasis on
extensibility, API stability, and the presence of a test suite. The package
consists of several components:

=over 4

=item 

L<RDF::Trine::Model> - RDF model providing access to a triple store. This module would typically be used to access an existing store by a developer looking to "Just get stuff done."

=item 

L<RDF::Trine::Parser> - RDF parsers for various serialization formats including RDF/XML, Turtle, RDFa, and RDF/JSON.

=item 

L<RDF::Trine::Store::Memory> - An in-memory, non-persistant triple store. Typically used for temporary data.

=item 

L<RDF::Trine::Store::DBI> - A triple store for MySQL, PostgreSQL, and SQLite, based on the relational schema used by Redland. Typically used to for large, persistent data.

=item 

L<RDF::Trine::Iterator> - Iterator classes for variable bindings and RDF statements, used by RDF::Trine::Store, RDF::Trine::Model, and RDF::Query.

=item 

L<RDF::Trine::Namespace> - A convenience class for easily constructing RDF::Trine::Node::Resource objects from URI namespaces.

=back

=cut

package RDF::Trine;

use 5.010;
use strict;
use warnings;
no warnings 'redefine';
use Module::Load::Conditional qw[can_load];
use LWP::UserAgent;

our ($debug, @ISA, $VERSION, @EXPORT_OK);
BEGIN {
	$debug		= 0;
	$VERSION	= '1.012';
	
	require Exporter;
	@ISA		= qw(Exporter);
	@EXPORT_OK	= qw(iri blank literal variable statement store UNION_GRAPH NIL_GRAPH);
	
	unless ($ENV{RDFTRINE_NO_REDLAND}) {
		can_load( modules => {
			'RDF::Redland'					=> undef,
			'RDF::Trine::Store::Redland'	=> undef,
			'RDF::Trine::Parser::Redland'	=> undef,
		} );
	}
}

use constant UNION_GRAPH	=> 'tag:gwilliams@cpan.org,2010-01-01:RT:ALL';
use constant NIL_GRAPH		=> 'tag:gwilliams@cpan.org,2010-01-01:RT:NIL';

use Log::Log4perl qw(:easy);
if (! Log::Log4perl::initialized() ) {
    Log::Log4perl->easy_init($ERROR);
}

use RDF::Trine::Graph;
use RDF::Trine::Parser;
use RDF::Trine::Serializer;
use RDF::Trine::Node;
use RDF::Trine::Statement;
use RDF::Trine::Namespace;
use RDF::Trine::NamespaceMap;
use RDF::Trine::Iterator;
use RDF::Trine::Store;
use RDF::Trine::Error;
use RDF::Trine::Model;

use RDF::Trine::Parser::Turtle;
use RDF::Trine::Parser::TriG;


sub _uniq {
	my %seen;
	my @data;
	foreach (@_) {
		push(@data, $_) unless ($seen{ $_ }++);
	}
	return @data;
}

=head1 FUNCTIONS

=over 4

=item C<< iri ( $iri ) >>

Returns a L<RDF::Trine::Node::Resource> object with the given IRI value.

=cut

sub iri {
	my $iri	= shift;
	return RDF::Trine::Node::Resource->new( $iri );
}

=item C<< blank ( $id ) >>

Returns a L<RDF::Trine::Node::Blank> object with the given identifier.

=cut

sub blank {
	my $id	= shift;
	return RDF::Trine::Node::Blank->new( $id );
}

=item C<< literal ( $value, $lang, $dt ) >>

Returns a L<RDF::Trine::Node::Literal> object with the given value and optional
language/datatype.

=cut

sub literal {
	return RDF::Trine::Node::Literal->new( @_ );
}

=item C<< variable ( $name ) >>

Returns a L<RDF::Trine::Node::Variable> object with the given variable name.

=cut

sub variable {
	my $name	= shift;
	return RDF::Trine::Node::Variable->new( $name );
}

=item C<< statement ( @nodes ) >>

Returns a L<RDF::Trine::Statement> object with the supplied node objects.

=cut

sub statement {
	my @nodes	= @_;
	if (scalar(@nodes) == 4) {
		return RDF::Trine::Statement::Quad->new( @nodes );
	} else {
		return RDF::Trine::Statement->new( @nodes );
	}
}

=item C<< store ( $config ) >>

Returns a L<RDF::Trine::Store> object based on the supplied configuration string.

=cut

sub store {
	my $config	= shift;
	return RDF::Trine::Store->new_with_string( $config );
}

=item C<< default_useragent ( [ $ua ] ) >>

Returns the L<LWP::UserAgent> object used by default for any operation requiring network
requests. Ordinarily, the calling code will obtain the default user agent, and clone it
before further configuring it for a specific request, thus leaving the default object
untouched.

If C<< $ua >> is passed as an argument, sets the global default user agent to this object.

=cut

{ my $_useragent;
sub default_useragent {
	my $class	= shift;
	my $ua		= shift || $_useragent;
	unless (defined($ua)) {
		$ua	= LWP::UserAgent->new( agent => "RDF::Trine/$RDF::Trine::VERSION" );
	}
	$_useragent	= $ua;
	return $ua;
}}

1; # Magic true value required at end of module
__END__

=back

=head1 BUGS

Please report any bugs or feature requests to through the GitHub web interface
at L<https://github.com/kasei/perlrdf/issues>.

=head1 SEE ALSO

L<http://www.perlrdf.org/>

=head1 AUTHOR

Gregory Todd Williams  C<< <gwilliams@cpan.org> >>

=head1 COPYRIGHT

Copyright (c) 2006-2012 Gregory Todd Williams. This
program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
