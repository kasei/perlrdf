use utf8;
package RDF::Trine::Store::DBIC::Schema::Statement;

=head1 NAME

RDF::Trine::Store::DBIC::Schema::Statements5560752892161344011

=cut

use strict;
use warnings;

use Moose;
use namespace::autoclean;
use MooseX::NonMoose;

extends 'DBIx::Class::Core';

=head1 TABLE: C<statements5560752892161344011>

=cut

__PACKAGE__->table("statements");

=head1 ACCESSORS

=head2 subject

  data_type: 'numeric'
  is_nullable: 0
  size: [20,0]

=head2 predicate

  data_type: 'numeric'
  is_nullable: 0
  size: [20,0]

=head2 object

  data_type: 'numeric'
  is_nullable: 0
  size: [20,0]

=head2 context

  data_type: 'numeric'
  default_value: 0
  is_nullable: 0
  size: [20,0]

=cut

__PACKAGE__->add_columns(
  "subject",
  { data_type => "numeric", is_nullable => 0, size => [20, 0] },
  "predicate",
  { data_type => "numeric", is_nullable => 0, size => [20, 0] },
  "object",
  { data_type => "numeric", is_nullable => 0, size => [20, 0] },
  "context",
  {
    data_type => "numeric",
    default_value => 0,
    is_nullable => 0,
    size => [20, 0],
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</subject>

=item * L</predicate>

=item * L</object>

=item * L</context>

=back

=cut

__PACKAGE__->set_primary_key("subject", "predicate", "object", "context");

# s
__PACKAGE__->might_have
    (subject_resource => 'RDF::Trine::Store::DBIC::Schema::Resource',
     { 'foreign.id' => 'self.subject' });
__PACKAGE__->might_have
    (subject_blank => 'RDF::Trine::Store::DBIC::Schema::BNode',
     { 'foreign.id' => 'self.subject' });

# p
__PACKAGE__->might_have
    (predicate_resource => 'RDF::Trine::Store::DBIC::Schema::Resource',
     { 'foreign.id' => 'self.predicate' });

# o
__PACKAGE__->might_have
    (object_resource => 'RDF::Trine::Store::DBIC::Schema::Resource',
     { 'foreign.id' => 'self.object' });
__PACKAGE__->might_have
    (object_blank => 'RDF::Trine::Store::DBIC::Schema::BNode',
     { 'foreign.id' => 'self.object' });
__PACKAGE__->might_have
    (object_literal => 'RDF::Trine::Store::DBIC::Schema::Literal',
     { 'foreign.id' => 'self.object' });

# c
__PACKAGE__->might_have
    (context_resource => 'RDF::Trine::Store::DBIC::Schema::Resource',
     { 'foreign.id' => 'self.context' });


sub name {
    my $self = shift;
    warn 'derp';
    if (ref $self and @_ == 0) {
        return $self->SUPER::name . $self->model_id;
    }
    else {
        $self->SUPER::name(@_);
    }
}

sub model_id {
    my $self   = shift;
    my $schema = $self->schema;
    $schema->model_id($schema->model_name);
}

sub BUILD {
    my $self = shift;
    warn $self->name;
};

no Moose;
__PACKAGE__->meta->make_immutable;

1;
