=head1 NAME

RDF::Trine::Store::DBIC::Schema - DBIx::Class schema component

=head1 VERSION

This document describes RDF::Trine::Store::DBIC version 1.001


=head1 DESCRIPTION

No user-serviceable parts. See L<RDF::Trine::Store::DBIC>, L<DBIx::Class>.

=cut

use utf8;
package RDF::Trine::Store::DBIC::Schema;

use strict;
use warnings;

use base qw(DBIx::Class::Schema);

__PACKAGE__->mk_group_accessors(simple => 'model_name');

__PACKAGE__->load_classes(qw(Model Resource BNode Literal Statement));

sub model_id {
    my ($self, $name) = @_;
    _half_md5($name || $self->model_name);
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

# deployment filters

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

sub _statement_rs {
    my $self = shift;

    my @seq = qw(s p o);

    my (%nodes, %where, @join);
    my @select = qw(me.subject me.predicate me.object);
    my @as     = @seq;

    if (@_ >= 4) {
        push @seq, 'c';

        @nodes{@seq} = @_;

        # CONTEXT
        if (defined $nodes{c} and not $nodes{c}->is_variable) {
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
    if (defined $nodes{s} and not $nodes{s}->is_variable) {
        $where{subject} = $self->_node_hash($nodes{s});
    }
    else {
        push @join,   qw(subject_resource subject_blank);
        push @select, qw(subject_resource.uri subject_blank.name);
        push @as,     qw(sr sb);
    }

    # PREDICATE
    if (defined $nodes{p} and not $nodes{p}->is_variable) {
        #warn $nodes{p};
        $where{predicate} = $self->_node_hash($nodes{p});
    }
    else {
        push @join,   qw(predicate_resource);
        push @select, qw(predicate_resource.uri);
        push @as,     qw(pr);
    }

    # OBJECT
    if (defined $nodes{o} and not $nodes{o}->is_variable) {
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

    return wantarray ? ($rs, \%nodes, @seq) : $rs;
}

sub get_statements ($;$$$$) {
    my $self = shift;
    my ($rs, $nodes, @seq) = $self->_statement_rs(@_);

    my $stmt_class = 'RDF::Trine::Statement';
    $stmt_class .= '::Quad' if @seq > 3;

    return RDF::Trine::Iterator::Graph->new(
        sub {
          NEXTROW:
            return unless my $rec = $rs->next;

            # the outer loop is (s, p, o [, c])
            my %out;
            for my $k (@seq) {
                if (defined $nodes->{$k} and not $nodes->{$k}->is_variable) {
                    $out{$k} = $nodes->{$k};
                }
                elsif ($rec->get_column($k) == 0) {
                    $out{$k} = RDF::Trine::Node::Nil->new;
                }
                else {
                    # the inner loop is a list of pairs in %SET, each
                    # containing an arrayref of columns from the
                    # SELECT record, and a class name for the RDF
                    # node type.
                    for my $rule (@{$SET{$k}}) {
                        # get the values of the columns associated
                        # with this node type:
                        my @cols = map {
                            my $x = $rec->get_column($_);
                            $x = Encode::decode(utf8 => $x) if defined $x;
                            $x; } @{$rule->[0]};
                        my $class = $rule->[1];

                        # if the first element is undef, there was no
                        # value of this type.
                        next unless defined $cols[0];

                        # instantiate a new node
                        $out{$k} = $class->new(@cols);

                        # ignore everything that follows
                        last;
                    }
                }
            }

            if (grep { not defined $_ } @out{@seq}) {
                # the inner loop exited without creating at least one
                # node, which basically means the database is corrupt.

                # PS this should basically never happen but with this
                # janky database schema it very well might.

                # XXX PROBABLY SHOULD LOG SOMETHING
                warn join ' ', "DUDE CHECK YR DATA:",
                    map { $_ || '!UNDEF!' } @out{@seq};

                %out = ();
                # suck it, dijkstra
                goto NEXTROW;
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

sub _ctx_preamble {
    my ($self, $stmt, $ctx) = @_;

    if ($ctx) {
        throw RDF::Trine::Error::MethodInvocationError
            -text => 'Supply either a quad or a context, not both.'
                if $stmt->isa('RDF::Trine::Statement::Quad');
        $stmt = RDF::Trine::Statement::Quad->new($stmt->nodes, $ctx);
    }

}

sub _insert_node {
    my ($self, $node) = @_;
    my $hash = $self->_node_hash($node);

    # not gonna be fancy with the dispatch table this time
    if ($node->isa('RDF::Trine::Node::Resource')) {
        $self->resultset('Resource')->find_or_create({
            id  => $hash,
            uri => Encode::encode(utf8 => $node->uri_value),
        });
    }
    elsif ($node->isa('RDF::Trine::Node::Blank')) {
        # XXX should probably rename this to Blank
        $self->resultset('BNode')->find_or_create({
            id   => $hash,
            name => Encode::encode(utf8 => $node->blank_identifier),
        });
    }
    elsif ($node->isa('RDF::Trine::Node::Literal')) {
        $self->resultset('Literal')->find_or_create({
            id    => $hash,
            value => Encode::encode(utf8 => $node->literal_value),
        });
    }
    else {
        # noop
    }

    $hash;
}

sub add_statement {
    my $self = shift;
    my $stmt = $self->_ctx_preamble(@_);

    my %stmt;
    for my $name ($stmt->node_names) {
        my $node = $stmt->$name;


        $stmt{$name} = $self->_insert_node($node);
    }

    $self->resultset('Statement')->find_or_create(\%stmt);

    # return something? i dunno.
    $stmt;
}

sub remove_statement {
    my $self = shift;
    my $stmt = $self->_ctx_preamble(@_);

    my %stmt;
    for my $name ($stmt->node_names) {
        my $node = $stmt->$name;

        $stmt{$name} = $self->_node_hash($node);
    }

    $self->resultset('Statement')->search(\%stmt)->delete;

    $stmt;
}

sub count_statements {
    my $self = shift;
    $self->_statement_rs(@_)->count;
}

sub supports {
}

# optional methods

sub init {
    my $self = shift;
#    warn $self->deployment_statements;
    $self->deploy({ filters => [ \&_all_but_statements ] });
    $self->deploy({ filters => [ \&_statements_only ] });
}

1;
