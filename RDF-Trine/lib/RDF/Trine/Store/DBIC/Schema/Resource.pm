use utf8;
package RDF::Trine::Store::DBIC::Schema::Resource;

=head1 NAME

RDF::Trine::Store::DBIC::Schema::Resource

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<resources>

=cut

__PACKAGE__->table("resources");

=head1 ACCESSORS

=head2 id

  data_type: 'numeric'
  is_nullable: 0
  size: [20,0]

=head2 uri

  data_type: 'text'
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "numeric", is_nullable => 0, size => [20, 0] },
  "uri",
  { data_type => "text", is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 UNIQUE CONSTRAINTS

=head2 C<resource_uri>

=over 4

=item * L</uri>

=back

=cut

__PACKAGE__->add_unique_constraint("resource_uri", ["uri"]);

__PACKAGE__->has_many
    (subject_of => 'RDF::Trine::Store::DBIC::Schema::Statement',
     { 'foreign.subject' => 'self.id' });
__PACKAGE__->has_many
    (predicate_of => 'RDF::Trine::Store::DBIC::Schema::Statement',
     { 'foreign.predicate' => 'self.id' });
__PACKAGE__->has_many
    (object_of => 'RDF::Trine::Store::DBIC::Schema::Statement',
     { 'foreign.object' => 'self.id' });
__PACKAGE__->has_many
    (context_of => 'RDF::Trine::Store::DBIC::Schema::Statement',
     { 'foreign.context' => 'self.id' });

1;
