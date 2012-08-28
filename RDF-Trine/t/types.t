use Test::More tests => 1;
use Test::Moose;
use Data::Dumper;

use strict;
use warnings;

use RDF::Trine qw(iri blank literal variable);
use RDF::Trine::Namespace qw(xsd);

#use_ok 'RDF::Trine::Types';

{
    use RDF::Trine::Types qw(TrineLiteral);
    my $int = 23;
    my $str = '23';
    my $literal_int = literal($int, undef, $xsd->int);
    my $coerced_int = TrineLiteral->coerce($int);
    my $coerced_literal_int = TrineLiteral->coerce($int);
    is_deeply $literal_int, $coerced_literal_int, 'Literal coercion for int';
#    warn Dumper $literal_num;
#    warn Dumper $coerced_literal_num;
    # my $coerced_str = literal($str);
}
