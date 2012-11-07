use utf8;
package RDF::Trine::Store::DBIC::Schema::BNode;

=head1 NAME

RDF::Trine::Store::DBIC::Schema::BNode

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<bnodes>

=cut

__PACKAGE__->table("bnodes");

=head1 ACCESSORS

=head2 id

  data_type: 'numeric'
  is_nullable: 0
  size: [20,0]

=head2 name

  data_type: 'text'
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "numeric", is_nullable => 0, size => [20, 0] },
  "name",
  { data_type => "text", is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint(bnode_name => [qw(name)]);

__PACKAGE__->has_many
    (subject_of => 'RDF::Trine::Store::DBIC::Schema::Statement',
     { 'foreign.subject' => 'self.id' });
__PACKAGE__->has_many
    (object_of => 'RDF::Trine::Store::DBIC::Schema::Statement',
     { 'foreign.object' => 'self.id' });

1;
