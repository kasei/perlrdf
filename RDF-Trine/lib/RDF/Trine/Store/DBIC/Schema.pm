use utf8;
package RDF::Trine::Store::DBIC;

use strict;
use warnings;

use Moose;
use MooseX::NonMoose;
use namespace::autoclean;

extends 'DBIx::Class::Schema' => { -constructor_name => 'clone' }; #,
#    'RDF::Trine::Store';

use Encode       ();
use Digest::MD5  ();
use Scalar::Util ();
use Math::BigInt ();

use RDF::Trine;

__PACKAGE__->load_namespaces(
    result_namespace => "Schema",
);

has model_name => (
    is       => 'rw',
    isa      => 'Maybe[Str]',
    init_arg => 'name',
    required => 0,
);

has dbh => (
    is       => 'ro',
    isa      => 'DBI::db',
    required => 0,
);

has dsn => (
    is       => 'ro',
    isa      => 'Maybe[Str]',
    required => 0,
);

has username => (
    is       => 'ro',
    isa      => 'Maybe[Str]',
    required => 0,
);

has password => (
    is       => 'ro',
    isa      => 'Maybe[Str]',
    required => 0,
);

has attributes => (
    is       => 'ro',
    isa      => 'Maybe[HashRef]',
    required => 0,
);

# NOTE: The constructor here is actually 'clone', which means we can
# make our own 'new'.

sub new {
    my $class = shift;
    my %args;
    @args{qw(name dsn username password attributes)} = @_;
    if (Scalar::Util::blessed($args{dsn}) and $args{dsn}->isa('DBI::db')) {
        $args{dbh} = delete $args{dsn};
    }
    $class->clone(\%args);
}

sub _new_with_config {
    my $self = shift;
    $self->clone(shift);
}

# clone basically does what we want here
*_new_with_object = \&_new_with_config;

#sub _new_with_string {
#    Carp::croak('lolol this will break a DBI dsn');
#}

sub FOREIGNBUILDARGS {
    my $class = shift;
    warn 'DUDE WHAT';
    @_;
}

#sub BUILDARGS {
#    warn $_ for @_;
#}

sub BUILD {
    my $self = shift;
    #$self->connection;
    #warn Data::Dumper::Dumper($self);
    if ($self->dbh) {
        $self->connection(sub { $self->dbh }, $self->attributes);
    }
    else {
        $self->connection
            ($self->dsn, $self->username, $self->password, $self->attributes);
    }

    # is that enough?
    my $stmt = $self->source('Statement');
    $stmt->name($stmt->name . $self->model_id($self->model_name));

    #warn $stmt->name;

    $self;
}

#__PACKAGE__->mk_group_accessors(simple => 'model_name');

sub model_id {
    my ($self, $name) = @_;
    my $rec = $self->resultset('Model')->find
        ({ name => $name }, { key => 'model_name' });
    return $rec->id if $rec;
}

# these two are totally cribbed from RDF::Trine::Store::DBI

sub _half_md5 {
    my $data = Encode::encode(utf8 => shift);
    my @data = unpack('C*', Digest::MD5::md5( $data ));
    my $sum  = Math::BigInt->new('0');
    # create a 64-bit integer with the first half of the binary md5 sum.
    for my $count (0..7) {
        my $data = Math::BigInt->new($data[$count]);
        my $part = $data << (8 * $count);
        $sum    += $part;
    }
    # get rid of the extraneous '+' that pops up under perl 5.6
    $sum    =~ s/\D//;
    return $sum;
}

sub _node_hash {
    my ($self, $node) = @_;

    return unless Scalar::Util::blessed($node);
    return 0 if $node->is_nil;

    my $data;
    if ($node->isa('RDF::Trine::Node::Resource')) {
        $data = 'R' . $node->uri_value;
    }
    elsif ($node->isa('RDF::Trine::Node::Blank')) {
        $data = 'B' . $node->blank_identifier;
    }
    elsif ($node->isa('RDF::Trine::Node::Literal')) {
        my $value = $node->literal_value;
        $value    = '' unless defined $value;
        my $lang  = $node->literal_value_language || '';
        my $dt    = $node->literal_datatype       || '';
        $data     = sprintf("L%s<%s>%s", $value, $lang, $dt);
    }
    else {
        return;
    }

    # return the content
    _half_md5($data);
}

sub _all_but_statements {
    my $schema = shift;
    $schema->drop_table($_)
        for grep { $_ =~ /^statements\d+/i } $schema->get_tables;
}

sub _statements_only {
    my $schema = shift;
    for my $t ($schema->get_tables) {
        if ($t !~ /^statements\d+/i) {
            $schema->drop_table($t);
            next;
        }
        my $table = $schema->get_table($t);
        for my $c ($table->get_constraints) {
            $table->drop_constraint($c->name) if $c->type =~ /^foreign/i;
        }
    }
}


# mandatory methods

# this can be static
my %SET = (
    s => [[['sr']           => 'RDF::Trine::Node::Resource'],
          [['sb']           => 'RDF::Trine::Node::Blank']],
    p => [[['pr']           => 'RDF::Trine::Node::Resource']],
    o => [[['ou']           => 'RDF::Trine::Node::Resource'],
          [['ob']           => 'RDF::Trine::Node::Blank'],
          [[qw(ol lang dt)] => 'RDF::Trine::Node::Literal']],
    c => [[['cr']           => 'RDF::Trine::Node::Resource']],
);

sub get_statements ($;$$$$) {
    my $self = shift;

    my @seq = qw(s p o);
    my $stmt_class = 'RDF::Trine::Statement';

    my (%nodes, %where, @join);
    my @select = qw(me.subject me.predicate me.object);
    my @as     = @seq;

    if (@_ >= 4) {
        push @seq, 'c';
        $stmt_class .= '::Quad';

        @nodes{@seq} = @_;

        # CONTEXT
        if (defined $nodes{c}) {
            $where{context} = $self->_node_hash($nodes{c});
        }
        else {
            push @join,   qw(context_resource);
            push @select, qw(me.context context_resource.uri);
            push @as,     qw(c cr);
        }
    }
    else {
        # this is the only statement that gets repeated. wee-haw.
        @nodes{@seq} = @_;
    }

    # SUBJECT
    if (defined $nodes{s}) {
        $where{subject} = $self->_node_hash($nodes{s});
    }
    else {
        push @join,   qw(subject_resource subject_blank);
        push @select, qw(subject_resource.uri subject_blank.name);
        push @as,     qw(sr sb);
    }

    # PREDICATE
    if (defined $nodes{p}) {
        #warn $nodes{p};
        $where{predicate} = $self->_node_hash($nodes{p});
    }
    else {
        push @join,   qw(predicate_resource);
        push @select, qw(predicate_resource.uri);
        push @as,     qw(pr);
    }

    # OBJECT
    if (defined $nodes{o}) {
        $where{object} = $self->_node_hash($nodes{o});
    }
    else {
        push @join,   qw(object_resource object_blank object_literal);
        push @select, qw(object_resource.uri object_blank.name
                         object_literal.value object_literal.language
                         object_literal.datatype);
        # of course, 'or' is OR
        push @as,     qw(ou ob ol lang dt);
    }

    my $rs = $self->resultset('Statement')->search(
        \%where,
        {
            select => \@select,
            as     => \@as,
            join   => \@join,
        }
    );

    return RDF::Trine::Iterator::Graph->new(
        sub {
            return unless my $rec = $rs->next;

            # the outer loop is: s, p, o [, c]

            my %out;
            for my $k (@seq) {
                if (defined $nodes{$k} and not $nodes{$k}->is_variable) {
                    $out{$k} = $nodes{$k};
                }
                elsif ($rec->get_column($k) == 0) {
                    $out{$k} = RDF::Trine::Node::Nil->new;
                }
                else {
                    # the inner loop is a list of pairs in %SET, each
                    # containing an arrayref of columns and a class
                    # name.
                    for my $rule (@{$SET{$k}}) {
                        my @cols = map { $rec->get_column($_) } @{$rule->[0]};
                        my $class = $rule->[1];

                        # if the first element is undef, there was no
                        # value of this type.
                        next unless defined $cols[0];

                        # instantiate a new node
                        $out{$k} = $class->new(@cols);

                        # no more processing
                        last;
                    }
                }
            }

            # hash slice of original sequence
            return $stmt_class->new(@out{@seq});
        }
    );
}

sub get_contexts {
    my $self = shift;

    my $rs = $self->resultset('Statement');
    #$rs->result_source->name('Statements' . $self->model_id('cardviz'));
    $rs = $rs->search(
        {},
        {
            select   => [qw(me.context context_resource.uri)],
            as       => [qw(context uri)],
            join     => [qw(context_resource)],
            distinct => 1,
        }
    );

    # iterator
    return RDF::Trine::Iterator->new(
        sub {
            return unless my $rec = $rs->next;
 
           return RDF::Trine::Node::Nil->new if $rec->context == 0;

            my $uri = $rec->get_column('uri');
            return RDF::Trine::Node::Resource->new
                (Encode::encode(utf8 => $uri));
        }
    );
}

sub add_statement {
    my ($self, $stmt, $ctx) = @_;
    
}

sub remove_statement {
    my ($self, $stmt, $ctx) = @_;

}

sub count_statements {
    my ($self, $s, $p, $o, $c) = @_;
}

sub supports {
}

# optional methods

no Moose;
__PACKAGE__->meta->make_immutable;

1;
