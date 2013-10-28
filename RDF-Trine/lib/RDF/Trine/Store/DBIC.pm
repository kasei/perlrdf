=head1 NAME

RDF::Trine::Store::DBIC - Persistent RDF storage based on DBIx::Class

=head1 VERSION

This document describes RDF::Trine::Store::DBIC version 1.001

=head1 SYNOPSIS

  use RDF::Trine::Store::DBIC;

  my $user = 'me';
  my $pass = 'secret';
  my $modelname = 'mymodel';

  # First, construct a DBI connection to your database
  my $dsn = "DBI:mysql:database=perlrdf";
  my $dbh = DBI->connect( $dsn, $user, $pass );

  # Second, create a new Store object with the database connection and
  # specifying (by name) which model in the Store you want to use
  my $store = RDF::Trine::Store::DBIC->new( $modelname, $dbh );

  # or, pass the credentials in directly:

  $store = RDF::Trine::Store::DBIC->new($modelname, $dsn, $user, $pass);

  # Finally, wrap the Store objec into a Model, and use it to access
  # your data
  my $model = RDF::Trine::Model->new($store);

  # or, do it all from here:
  $model = RDF::Trine::Model->new({
    storetype => 'DBIC',
    name      => $modelname,
    dsn       => $dsn,
    username  => $user,
    password  => $pass,
  );

  print $model->size . " RDF statements in store\n";

=head1 DESCRIPTION

RDF::Trine::Store::DBIC provides a persistent triple-store using the
L<DBIx::Class> module.

=cut

use utf8;
package RDF::Trine::Store::DBIC;

use strict;
use warnings;

use base qw(RDF::Trine::Store);

# modules for doing stuff
use Math::BigInt    try => 'GMP';
use Encode          ();
use Digest::MD5     ();
use Scalar::Util    ();
use DBIx::Connector ();

# nodes
use RDF::Trine::Node::Resource  ();
use RDF::Trine::Node::Blank     ();
use RDF::Trine::Node::Literal   ();
use RDF::Trine::Node::Variable  ();
use RDF::Trine::Node::Nil       ();
# statements
use RDF::Trine::Statement       ();
use RDF::Trine::Statement::Quad ();
# exceptions
use RDF::Trine::Error           ();

# and our baby
use RDF::Trine::Store::DBIC::Schema;

######################################################################

our $VERSION;
BEGIN {
	$VERSION	= "1.001";
	my $class	= __PACKAGE__;
	$RDF::Trine::Store::STORE_CLASSES{ $class }	= $VERSION;
}

######################################################################

# these two are totally cribbed from RDF::Trine::Store::DBI, but i
# changed the names because they aren't specifically mysql

# XXX perhaps some provision to expire this data?

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

my %MD5_MAP;
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

    # return the content, memoized if possible
    return $MD5_MAP{$data} ||= _half_md5($data) . '';
}

=head2 new

=cut

# override the insane constructor with my own insane constructor

sub new {
    my $class = shift;

    #warn Data::Dumper::Dumper(\@_);
    throw RDF::Trine::Error::MethodInvocationError
        -text => 'Constructor must have at least one argument.' unless @_;

    # first, deal with the possibility of being passed a reference
    my %args;
    if (my $ref = ref $_[0]) {
        if (Scalar::Util::blessed($_[0])) {
            if ($_[0]->isa('DBIx::Connector') or $_[0]->isa('DBI::db')) {
                # put either one of these in the dbh slot, because
                # it'll be coalesced down below.
                $args{dbh} = shift;
            }
            else {
                throw RDF::Trine::Error::MethodInvocationError
                    -text => "Don't know what to do with a $ref object.";
            }

            # the next thing on the argument stack is an attribute
            # set; anything else is ignored.
            $args{attributes} = shift if @_;
        }
        elsif ($ref eq 'CODE') {
            $args{dbh}        = shift;
            $args{attributes} = shift if @_;
        }
        elsif ($ref eq 'HASH') {
            %args = %{$_[0]};
        }
        else {
            throw RDF::Trine::Error::MethodInvocationError
                -text => "Don't know what to do with a $ref reference.";
        }
    }
    else {
        # otherwise convert the arglist into a nice hash

        @args{qw(name dsn username password attributes)} = @_;
    }

    # handle attributes first
    if (defined $args{attributes}) {
        throw RDF::Trine::Error::MethodInvocationError
            -text => 'DBI(C) attributes must be a HASH reference'
                unless ref $args{attributes} eq 'HASH';

        # if you pass in an object, the only way to pass in a model
        # name or other parameters is through the attributes.
        $args{name} ||= delete $args{attributes}{name};

        # deal with this being temporary
        $args{temporary} ||= delete $args{attributes}{temporary};
    }
    else {
        # nuke empty attributes out of the args
        delete $args{attributes};
    }

    # now check the name
    throw RDF::Trine::Error::MethodInvocationError
        -text => "Can't instantiate the DBIC store without a model name."
            unless defined $args{name};

    # the next chunk is only if the dbh isn't already defined.
    unless (defined $args{dbh}) {

        # no need to explicitly set the temporary flag for the default
        # dsn, as it will get blown away.
        $args{dsn} ||= 'dbi:SQLite:dbname=:memory:';

        # now fix the dsn
        if (my $ref = ref $args{dsn}) {
            if ($ref eq 'CODE' or Scalar::Util::blessed($args{dsn})) {
                $args{dbh} = delete $args{dsn};
                # don't need these now
                delete @args{qw(username password)};
                # we still keep attributes because they may be for DBIC.
            }
            else {
                # don't know what to do with it
                throw RDF::Trine::Error::MethodInvocationError
                    -text => "Sorry, can't work with a $ref reference.";
            }
        }
        else {
            $args{dbh} = DBIx::Connector->new
                (@args{qw(dsn username password attributes)});
            # don't keep these around
            delete @args{qw(dsn username password)};
        }
    }

    # ok NOW coalesce the dbh
    my $conn = $args{connector}
        = delete $args{dbh} if $args{dbh}->isa('DBIx::Connector');

    #warn Data::Dumper::Dumper(\%args);

    my $self = bless \%args, $class;

    my $schema = $self->{schema} = RDF::Trine::Store::DBIC::Schema->connect
        (sub { $conn->dbh }, $args{attributes});

    $schema->model_name($args{name});

#    $schema->do_setup;

    my $src = $schema->source('Statement');
    $src->name($src->name . _half_md5($schema->model_name));

    $self;
}

=head2 new_with_config

=cut

*_new_with_config = \&new;

=head2 new_with_object

=cut

*_new_with_object = \&new;

=head2 new_with_string

=cut

sub _new_with_string {
    throw RDF::Trine::Error::UnimplementedError
        -text => "Do not use this if you like your DSN strings intact!";
}


sub FOREIGNBUILDARGS {
    my ($class, $args) = @_;

    warn 'FOREIGNBUILDARGS:';
    #warn Data::Dumper::Dumper($args);
    # DO NOT DO ANYTHING IN THIS UNLESS YOU WANT TO SCREW THINGS UP

    my @out;
    if ($args->{connector}) {
        push @out, sub { $args->{connector}->dbh };
    }
    elsif (my $dbh = delete $args->{dbh}) {
        push @out, ref $dbh eq 'CODE' ? $dbh : sub { $dbh };
    }
    else {
        throw RDF::Trine::Error::MethodInvocationError
            -text => 'FOREIGNBUILDARGS must have a dbh already.';
    }

    push @out, delete $args->{attributes} if ref $args->{attributes} eq 'HASH';
    @out;
}

# override connect so that it matches

sub model_id {
    my ($self, $name) = @_;
    my $rec = $self->{schema}->resultset('Model')->find
        ({ name => $name }, { key => 'model_name' });
    return $rec->id if $rec;
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

sub _node_ok {
    my $node = shift;
    return unless defined $node;
    return 1 if ref $node eq 'ARRAY';
    return not $node->is_variable;
}

sub _where_eq_or_in {
    my ($self, $node) = @_;
    if (ref $node eq 'ARRAY') {
        return {
            -in =>
                [map { $self->_node_hash($_) }
                     grep { defined $_ and not $_->is_variable } @{$node}] };
    }
    else {
        return $self->_node_hash($node);
    }
}

sub _statement_rs {
    my $self = shift;

    # make this an arrayref so we can give it extra commands
    my @args = @{shift || []};
    my %omit =  %{shift || {}};

    my (%nodes, %where, @seq, @join, @select, @as);

    @seq = qw(s p o);

    #warn Data::Dumper::Dumper(\@args);

    unless ($omit{s}) {
        push @as,    's';
        push @select, 'me.subject';
    }

    unless ($omit{p}) {
        push @as,    'p';
        push @select, 'me.predicate';
    }

    unless ($omit{o}) {
        push @as,    'o';
        push @select, 'me.object';
    }

    if (@args >= 4) {
        push @seq, 'c';

        @nodes{@seq} = @args;
        push @select, qw(me.context);
        push @as,     qw(c);

        # CONTEXT
        if (_node_ok($nodes{c})) {
#        if (defined $nodes{c} and not $nodes{c}->is_variable) {
            $where{context} = $self->_where_eq_or_in($nodes{c});
        }
        elsif ($omit{c}) {
            # nothing
        }
        else {
            push @join,   qw(context_resource);
            push @select, qw(context_resource.uri);
            push @as,     qw(cr);
        }
    }
            else {
        # this is the only statement that gets repeated. wee-haw.
        @nodes{@seq} = @args;
        
    }

    # SUBJECT
    if (_node_ok($nodes{s})) {
#    if (defined $nodes{s} and not $nodes{s}->is_variable) {
        $where{subject} = $self->_where_eq_or_in($nodes{s});
    }
    elsif ($omit{s}) {
        # nothing
    }
    else {
        push @join,   qw(subject_resource subject_blank);
        push @select, qw(subject_resource.uri subject_blank.name);
        push @as,     qw(sr sb);
    }

    # PREDICATE
    if (_node_ok($nodes{p})) {
#    if (defined $nodes{p} and not $nodes{p}->is_variable) {
        #warn $nodes{p};
        $where{predicate} = $self->_where_eq_or_in($nodes{p});
    }
    elsif ($omit{p}) {
        # nothing
    }
    else {
        push @join,   qw(predicate_resource);
        push @select, qw(predicate_resource.uri);
        push @as,     qw(pr);
    }

    # OBJECT
    if (_node_ok($nodes{o})) {
#    if (defined $nodes{o} and not $nodes{o}->is_variable) {
        $where{object} = $self->_where_eq_or_in($nodes{o});
    }
    elsif ($omit{o}) {
        # nothing
    }
    else {
        push @join,   qw(object_resource object_blank object_literal);
        push @select, qw(object_resource.uri object_blank.name
                         object_literal.value object_literal.language
                         object_literal.datatype);
        # of course, 'or' is OR
        push @as,     qw(ou ob ol lang dt);
    }

    # warn Data::Dumper::Dumper(\%nodes);
    #warn Data::Dumper::Dumper(\@as);

    my $rs = $self->{schema}->resultset('Statement')->search(
        \%where,
        {
            select   => \@select,
            as       => \@as,
            join     => \@join,
            distinct => 1,
        }
    );

    return wantarray ? ($rs, \%nodes, @seq) : $rs;
}

sub _inner_loop {
    my ($k, $rec) = @_;

    # the inner loop is a list of pairs in %SET, each containing an
    # arrayref of columns from the SELECT record, and a class name for
    # the RDF node type.

    for my $rule (@{$SET{$k}}) {
        # get the values of the columns associated
        # with this node type:
        my @cols = map {
            my $x = $rec->get_column($_);
            #warn sprintf('%s => %s', $_, defined $x ? $x : '');
            #$x = Encode::decode(utf8 => $x) if defined $x;
            utf8::decode($x) if defined $x;
            $x; } @{$rule->[0]};
        my $class = $rule->[1];

        # if the first element is undef, there was no
        # value of this type.
        next unless defined $cols[0];

        # instantiate a new node
        return $class->new(@cols);

        # ignore everything that follows
        last;
    }
}

sub get_statements ($;$$$$) {
    my $self = shift;
    my ($rs, $nodes, @seq) = $self->_statement_rs(\@_);

    my $stmt_class = 'RDF::Trine::Statement';
    $stmt_class .= '::Quad' if @seq > 3;

    # reverse-map the node set
    my %rev;
    for my $v (values %$nodes) {
        next unless defined $v;
        if (ref $v eq 'ARRAY') {
            map { $rev{$self->_node_hash($_)} = $_ } @$v;
        }
        elsif (not $v->is_variable) {
            $rev{$self->_node_hash($v)} = $v;
        }
        else {
            # noop
        }
    }

    return RDF::Trine::Iterator::Graph->new(
        sub {
          NEXTROW:
            return unless my $rec = $rs->next;

            # the outer loop is (s, p, o [, c])
            my %out;
            for my $k (@seq) {
                my $hash = $rec->get_column($k);
                if ($rev{$hash}) {
                    $out{$k} = $rev{$hash};
                }
                elsif ($nodes->{$k} and not $nodes->{$k}->is_variable) {
                    $out{$k} = $nodes->{$k};
                }
                elsif ($hash == 0) {
                    $out{$k} = RDF::Trine::Node::Nil->new;
                }
                else {
                    #warn $nodes->{$k};
                    $out{$k} = _inner_loop($k, $rec);
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

    my $rs = $self->{schema}->resultset('Statement');
    #$rs->result_source->name('Statements' . $self->model_id('cardviz'));
    $rs = $rs->search(
        { context => { '!=' => 0 } },
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
            utf8::decode($uri);
            return RDF::Trine::Node::Resource->new($uri);
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

    $stmt;
}

sub _insert_node {
    my ($self, $node) = @_;
    my $hash = $self->_node_hash($node);

    my $schema = $self->{schema};

    # not gonna be fancy with the dispatch table this time
    if ($node->isa('RDF::Trine::Node::Resource')) {
        $schema->resultset('Resource')->find_or_create({
            id  => $hash,
            uri => Encode::encode(utf8 => $node->uri_value),
        });
    }
    elsif ($node->isa('RDF::Trine::Node::Blank')) {
        # XXX should probably rename this to Blank
        $schema->resultset('BNode')->find_or_create({
            id   => $hash,
            name => Encode::encode(utf8 => $node->blank_identifier),
        });
    }
    elsif ($node->isa('RDF::Trine::Node::Literal')) {
        $schema->resultset('Literal')->find_or_create({
            id    => $hash,
            value    => Encode::encode(utf8 => $node->literal_value),
            language => Encode::encode
                (utf8 => $node->literal_value_language || ''),
            datatype => Encode::encode(utf8 => $node->literal_datatype || ''),
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
        #warn $name;
        my $node = $stmt->$name;


        $stmt{$name} = $self->_insert_node($node);
    }

    $stmt{context} ||= 0;

    #warn Data::Dumper::Dumper(\%stmt);

    $self->{schema}->resultset('Statement')->find_or_create(\%stmt);

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

    $stmt{context} ||= 0;

    #warn "REMOVE " . Data::Dumper::Dumper(\%stmt);


    $self->{schema}->resultset('Statement')->search(\%stmt)->delete;

    $stmt;
}

sub count_statements {
    my $self = shift;
    $self->_statement_rs(\@_)->count;
}

sub supports {
}

# optional methods

sub temporary_store ($;$$$$) {
    my $class = shift;
    my $name  = sprintf('model_%x%x%x%x', map { int(rand(16)) } (1..4) );
    my $self  = $class->new($name, @_);
#    $self->_prune->{$name} = 1;
    $self->init;
    $self;
}

sub init {
    shift->{schema}->init;
}

sub _one_node {
    my ($col, $rs) = @_;
    return sub {
        # moar derpstra
      AGAIN:
        return unless my $rec = $rs->next;
        my $node = _inner_loop($col => $rec) or goto AGAIN;
        return $node;
    };
}

sub _subjects {
    my $self = shift;
    my @nodes = (undef, @_);
    my $rs = $self->_statement_rs(\@nodes, { p => 1, o => 1 });

    return wantarray ? map { _inner_loop(s => $_) } $rs->all :
         RDF::Trine::Iterator->new(_one_node(s => $rs));
}

sub _predicates {
    my $self = shift;
    my @nodes = @_;
    splice @nodes, 1, 0, undef;
    # warn Data::Dumper::Dumper(\@nodes);
    my $rs = $self->_statement_rs(\@nodes, { s => 1, o => 1 });

    return wantarray ? map { _inner_loop(p => $_) } $rs->all :
         RDF::Trine::Iterator->new(_one_node(p => $rs));
}

sub _objects {
    my $self = shift;
    my @nodes = @_;
    splice @nodes, 2, 0, undef;
    # warn Data::Dumper::Dumper(\@nodes);
    my $rs = $self->_statement_rs(\@nodes, { s => 1, p => 1 });

    return wantarray ? map { _inner_loop(o => $_) } $rs->all :
         RDF::Trine::Iterator->new(_one_node(o => $rs));
}

1;
