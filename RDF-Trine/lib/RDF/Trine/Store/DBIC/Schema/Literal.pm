use utf8;
package RDF::Trine::Store::DBIC::Schema::Literal;

=head1 NAME

RDF::Trine::Store::DBIC::Schema::Literal

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<literals>

=cut

__PACKAGE__->table("literals");

=head1 ACCESSORS

=head2 id

  data_type: 'numeric'
  is_nullable: 0
  size: [20,0]

=head2 value

  data_type: 'text'
  is_nullable: 0

=head2 language

  data_type: 'text'
  default_value: (empty string)
  is_nullable: 0

=head2 datatype

  data_type: 'text'
  default_value: (empty string)
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "numeric", is_nullable => 0, size => [20, 0] },
  "value",
  { data_type => "text", is_nullable => 0 },
  "language",
  { data_type => "text", default_value => "", is_nullable => 0 },
  "datatype",
  { data_type => "text", default_value => "", is_nullable => 0 },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 UNIQUE CONSTRAINTS

=head2 C<uq_literal_value>

=over 4

=item * L</value>

=item * L</language>

=item * L</datatype>

=back

=cut

__PACKAGE__->add_unique_constraint("literal_value",
                                   ["value", "language", "datatype"]);

__PACKAGE__->has_many
    (object_of => 'RDF::Trine::Store::DBIC::Schema::Statement',
     { 'foreign.object' => 'self.id' });

1;
