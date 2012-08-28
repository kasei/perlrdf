# RDF::Trine::Types
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trine::Types - MooseX::Types for RDF::Trine 

=head1 VERSION

This document describes RDF::Trine::Types version 1.000

=head2 SYNOPSIS

    use RDF::Trine qw(literal)
    use RDF::Trine::Types qw(TrineLiteral TrineNode)

    # type checking
    $val1 = 33;
    $val2 = literal($val1);
    is_TrineLiteral($val1) # 0
    is_TrineLiteral($val2) # 1


    # coercion where available
    my $literal1 = TrineLiteral->coerce(66); # literal(66)
    my $literal2 = TrineLiteral->coerce($literal1); # $literal1 == $literal2

=head2 DESCRIPTION

TODO

=cut
package RDF::Trine::Types;
use strict;
use URI;
use RDF::Trine qw(iri);
use RDF::Trine::Namespace qw(xsd);
use MooseX::Types::URI Uri => { -as => 'MooseX__Types__URI__Uri' };
use MooseX::Types::Moose qw{:all};
use MooseX::Types::Path::Class qw{File Dir};
use MooseX::Types -declare => [
    'TrineNode',
    'TrineBlank',
    'TrineLiteral',
    'TrineResource',

    'TrineLiteralOrTrineResorce',
    'TrineBlankOrUndef',

    'TrineStore',
    'TrineModel',

    'ArrayOfTrineResources',
    'ArrayOfTrineNodes',
    'ArrayOfTrineLiterals',

    'HashOfTrineResources',
    'HashOfTrineNodes',
    'HashOfTrineLiterals',

    'CPAN_URI',
    'UriStr',
    'LanguageTag',
    ];

our ($VERSION);
BEGIN {
	$VERSION	= '1.000';
}

=head2 TYPE CONSTRAINTS

=cut


=head3 TrineNode NOCOERCION

=cut

subtype TrineNode,
    as Object,
    where {$_->isa('RDF::Trine::Node::Blank') || $_->isa('RDF::Trine::Node::Resource')};

=head3 TrineResource 

Coercion delegated to MooseX::Types::URI

=cut

class_type TrineResource, { class => 'RDF::Trine::Node::Resource' };

=head3 TrineLiteral

Coercion from Int, Bool, Num, Str

=cut

class_type TrineLiteral, { class => 'RDF::Trine::Node::Literal' };

=head3 TrineBlank

No Coercion

=cut

class_type TrineBlank, { class => 'RDF::Trine::Node::Blank' };

=head3 TrineModel

No Coercion

=cut

class_type TrineModel, { class => 'RDF::Trine::Model' };

=head3 TrineStore

No Coercion

=cut

class_type TrineStore, { class => 'RDF::Trine::Store' };

=head3 CPAN_URI

A URI as in the URI CPAN module by GAAS

No Coercion

=cut

class_type CPAN_URI, { class => 'URI' };

=head3 TrineBlankOrUndef

Either a Blank Node or undef

No Coercion

=cut

subtype TrineBlankOrUndef, as Maybe[TrineBlank];

=head3 ArrayOfTrineResources

No coercion

=cut

subtype ArrayOfTrineResources, as ArrayRef[TrineResource];

=head3 HashOfTrineResources

No coercion

=cut

subtype HashOfTrineResources, as HashRef[TrineResource];

=head3 ArrayOfTrineLiterals

No coercion

=cut

subtype ArrayOfTrineLiterals, as ArrayRef[TrineLiteral];

=head3 HashOfTrineLiterals

No coercion

=cut

subtype HashOfTrineLiterals, as HashRef[TrineLiteral];

=head3 ArrayOfTrineNodes

No coercion

=cut

subtype ArrayOfTrineNodes, as ArrayRef[TrineNode];

=head3 HashOfTrineNodes

No coercion

=cut

subtype HashOfTrineNodes, as HashRef[TrineNode];

=head3 UriStr

No coercion

=cut

subtype UriStr, as Str;

=head3 LanguageTag

No coercion

=cut

subtype LanguageTag, as Str, where { length $_ };

# coerce( CPAN_URI,
#     from Str, via { if (/^[a-z]+:/) { URI->new($_) },
# );

coerce( TrineBlankOrUndef,
    from Bool, via { return undef unless $_; RDF::Trine::Node::Blank->new },
);

coerce( ArrayOfTrineLiterals,
    from ArrayRef, via { my $u = $_; [map {TrineLiteral->coerce($_)} @$u] },
);


coerce (TrineResource,
    from Str, via { iri( $_ ) },
    from CPAN_URI, via { iri( $_->as_string ) },
);

coerce( ArrayOfTrineResources,
    # from Str, via { [ TrineResource->coerce( $_ ) ] },
    from TrineResource, via { [ $_ ] },
    from ArrayRef, via { my $u = $_; [map {TrineResource->coerce($_)} @$u] },
    from Value, via { [ TrineResource->coerce( $_ ) ] },
);

coerce (TrineNode,
    from TrineBlank, via { $_ },
    from TrineResource, via { $_ },
    from Defined, via {TrineResource->coerce( $_ )},
);

coerce (UriStr,
    from Defined, via { TrineResource->coerce( $_)->uri },
);

coerce( TrineModel,
    from Undef, via { RDF::Trine::Model->temporary_model },
    from UriStr, via { 
        my $m = TrineModel->coerce;
        RDF::Trine::Parser->parse_url_into_model( $_, $m );
        return $m;
    },
);

coerce( TrineStore,
    from Undef, via { RDF::Trine::Store->temporary_store },
    from Defined, via { RDF::Trine::Store->new ( $_ ) },
);
coerce( TrineLiteral,
    from Int, via { RDF::Trine::Node::Literal->new($_, undef, $xsd->int); },
    from Bool, via { RDF::Trine::Node::Literal->new($_, undef, $xsd->boolean); },
    from Num, via { RDF::Trine::Node::Literal->new($_, undef, $xsd->numeric); },
    from Str, via { RDF::Trine::Node::Literal->new($_, undef, $xsd->string); },
    from Value, via { RDF::Trine::Node::Literal->new($_); },
);

for (File, Dir, ScalarRef, HashRef, "Path::Class::File", "Path::Class::Dir"){
    coerce TrineResource,
        from $_,
            via { iri( MooseX__Types__URI__Uri->coerce( $_ ) ) };
};

1;

__END__

=head1 BUGS

Please report any bugs or feature requests to through the GitHub web interface
at L<https://github.com/kasei/perlrdf/issues>.

=head1 AUTHOR

Konstantin Baierer  C<< <kba@cpan.org> >>

=head1 COPYRIGHT

Copyright (c) 2012 Konstantin Baierer. This program is free software; you can
redistribute it and/or modify it under the same terms as Perl itself.

=cut
