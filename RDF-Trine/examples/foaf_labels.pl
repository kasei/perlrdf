#!/usr/bin/env perl

use strict;
use warnings;

=head1 DESCRIPTION

This example script shows how to create a new RDF store based on a SQLite
database, load RDF data into the store from a file, and retrieve data from
the store matching a statement pattern.

=cut

use RDF::Trine;
use LWP::Simple qw(get);

# The temporary_store method will return a RDF::Trine::Store object
# based on a SQLite database created in a temporary file.
my $store	= RDF::Trine::Store::DBI->temporary_store();

# If you want to keep the SQLite database file around and use it
# again later, you should use the regular new() constructor of the
# RDF::Trine::Store::DBI class. If you create a new store using the
# new() method, you'll need to call $store->init() once, immediately
# after creating the store -- this will create all the necessary
# database tables that the store will need.


# now wrap the store in a model:
my $model	= RDF::Trine::Model->new( $store );


# Now we'll load the RDF data for the FOAF vocabulary from its URL:
my $url		= 'http://xmlns.com/foaf/0.1/index.rdf';
RDF::Trine::Parser->parse_url_into_model( $url, $model );


# $model now contains all the FOAF data. To look up specific triples
# from this data, use the get_statements() and get_pattern() methods
# of the model object:

# Get all labels of things (triples matching "?thing rdfs:label ?label"):
# [  Note that get_statements() can take undef as a value in any position that
# [  you don't care to specify. Here, we're looking to restrict the retrieval to
# [  to triples with a specific predicate, so the subject and object positions
# [  (first and third, respectively) are undef.

my $label		= RDF::Trine::Node::Resource->new('http://www.w3.org/2000/01/rdf-schema#label');
my $iterator	= $model->get_statements(undef, $label, undef);


# Now we'll loop over all the matching statements and print them out:
while (my $statement = $iterator->next) {
	my $thing	= $statement->subject;
	my $label	= $statement->object;
	
	# $thing and $label are RDF::Trine::Node objects. To get a string suitable
	# for printing, use the as_string() method:
	my $thing_string	= $thing->as_string;
	my $label_string	= $label->as_string;
	
	print "$thing_string has label $label_string\n";
}
