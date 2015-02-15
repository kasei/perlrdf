=encoding utf8

=head1 NAME

RDF::Trine::Store::LanguagePreference - RDF Store proxy for filtering language tagged literals

=head1 VERSION

This document describes RDF::Trine::Store::LanguagePreference version 1.008

=head1 SYNOPSIS

 use RDF::Trine::Store::LanguagePreference;

=head1 DESCRIPTION

RDF::Trine::Store::LanguagePreference provides a RDF::Trine::Store API to
filter the statements made available from some underlying store object based
on a users' language preferences (e.g. coming from an Accept-Language HTTP
header value).

=cut

package RDF::Trine::Store::LanguagePreference;

use strict;
use warnings;
no warnings 'redefine';
use base qw(RDF::Trine::Store);

use Data::Dumper;
use List::Util qw(reduce max);
use Scalar::Util qw(refaddr reftype blessed);
use RDF::Trine::Iterator qw(sgrep);

######################################################################

my @pos_names;
our $VERSION;
BEGIN {
	$VERSION	= "1.008";
	my $class	= __PACKAGE__;
	$RDF::Trine::Store::STORE_CLASSES{ $class }	= $VERSION;
	@pos_names	= qw(subject predicate object context);
}

######################################################################

=head1 METHODS

Beyond the methods documented below, this class inherits methods from the
L<RDF::Trine::Store> class.

=over 4

=item C<< new ( $store, { $lang1 => $q1, $lang2 => $q2, ... } ) >>

Returns a new storage object that will act as a proxy for the C<< $store >> object,
filtering language literals based on the expressed language preferences.

=item C<new_with_config ( $hashref )>

Returns a new storage object configured with a hashref with certain
keys as arguments.

The C<storetype> key must be C<LanguagePreference> for this backend.

The following key must also be used:

=over

=item C<store>

A configuration hash for the underlying store object.

=item C<preferred_languages>

A hash reference mapping language tags to quality values in the range [0, 1].
The referent may be changed between operations to change the set of preferred
languages used in statement matching.

=back

=cut

sub new {
	my $class	= shift;
	my $store	= shift;
	my $pref	= shift;
	my $self	= bless({
		store	=> $store,
		preferred_languages	=> $pref,
	}, $class);
	return $self;
}

=item C<< new_with_config ( \%config ) >>

Returns a new RDF::Trine::Store object based on the supplied configuration hashref.

=cut

sub new_with_config {
	my $proto	= shift;
	my $config	= shift;
	$config->{storetype}	= 'LanguagePreference';
	return $proto->SUPER::new_with_config( $config );
}

sub _new_with_config {
	my $class	= shift;
	my $config	= shift;
	return $class->new( @{ $config }{ qw(store preferred_languages) } );
}

sub _config_meta {
	return {
		required_keys	=> [qw(store preferred_languages)],
		fields			=> {
			store	=> { description => 'Store config', type => 'string' },
			preferred_languages => { description => 'Preferred languages', type => 'hash' },
		}
	}
}


=item C<< language_preferences >>

Returns a hash of the language preference quality values.

=cut

sub language_preferences {
	my $self	= shift;
	return %{ $self->{preferred_languages} };
}

=item C<< language_preference( $lang ) >>

Return the quality value preference for the given language.

=cut

sub language_preference {
	my $self	= shift;
	my $lang	= shift;
	return $self->{preferred_languages}{$lang};
}

=item C<< update_language_preference( $lang => $qvalue ) >>

Update the quality value preference for the given language.

=cut

sub update_language_preference {
	my $self	= shift;
	my $lang	= shift;
	my $q		= shift;
	if ($q == 0) {
		delete $self->{preferred_languages}{$lang};
	} else {
		$self->{preferred_languages}{$lang}	= $q;
	}
}

=item C<< get_statements ( $subject, $predicate, $object [, $context] ) >>

Returns a stream object of all statements matching the specified subject,
predicate and objects. Any of the arguments may be undef to match any value.

=cut

sub get_statements {
	my $self	= shift;
	my @nodes	= @_[0..3];
	my $bound	= 0;
	my %bound;
	
	my $use_quad	= 0;
	if (scalar(@_) >= 4) {
		my $g	= $nodes[3];
		if (blessed($g) and not($g->is_variable) and not($g->is_nil)) {
			$use_quad	= 1;
			$bound++;
			$bound{ 3 }	= $g;
		}
	}
	
	my @var_map	= qw(s p o g);
	my %var_map	= map { $var_map[$_] => $_ } (0 .. $#var_map);
	my @node_map;
	foreach my $i (0 .. $#nodes) {
		if (not(blessed($nodes[$i])) or $nodes[$i]->is_variable) {
			$nodes[$i]	= RDF::Trine::Node::Variable->new( $var_map[ $i ] );
		}
	}
	
	my $cache	= {};
	my $iter	= $self->{store}->get_statements(@nodes);
	return RDF::Trine::Iterator::sgrep(sub {
		return $self->languagePreferenceAllowsStatement($_, $cache);
	}, $iter);
}

=item C<< count_statements ( $subject, $predicate, $object, $context ) >>

Returns a count of all the statements matching the specified subject,
predicate, object, and context. Any of the arguments may be undef to match any
value.

=cut

sub count_statements {
	my $self	= shift;
	my $iter	= $self->get_statements(@_);
	my $count	= 0;
	while ($iter->next) {
		$count++;
	}
	return $count;
}

=item C<< qvalueForLanguage ( $language, \%cache ) >>

Returns the q-value for C<< $language >> based on the current language
preference. C<< %cache >> is used across multiple calls to this method for
performance reasons.

=cut

sub qvalueForLanguage {
	my $self	= shift;
	my $lang	= shift;
	my $cache	= shift || {};
	if (exists $cache->{$lang}) {
		return $cache->{$lang};
	} else {
		my %q;
		foreach my $l (keys %{ $self->{preferred_languages} }) {
			if ($lang =~ /^$l/) {
				my $q	= $self->{preferred_languages}{$l};
				$q{$l}	= $q;
			}
		}
		my $q;
		if (scalar(@{ [ keys %q ] })) {
			my @keys	= sort { length($b) <=> length($a) } keys %q;
			$q	= $q{$keys[0]};
		} else {
			$q	= 0.001;
		}
		$cache->{$lang}	= $q;
		return $q;
	}
}

=item C<< siteQValueForLanguage ( $language ) >>

Returns an implementation-specific q-value preference for the given
C<< $language >>. This method may be overridden by subclasses to control the
default preferred language.

=cut

sub siteQValueForLanguage {
	my $self	= shift;
	my $lang	= shift;
	return ($lang =~ /^en/) ? 1.0 : 0.999;
}

=item C<< availableLanguagesForStatement( $statement ) >>

Returns a list of language tags that are available in the underlying store for
the given statement object. For example, if C<< $statement >> represented the
triple:

 dbpedia:Los_Angeles rdf:label "Los Angeles"@en

and the underlying store contains the triples:

 dbpedia:Los_Angeles rdf:label "Los Angeles"@en
 dbpedia:Los_Angeles rdf:label "ロサンゼルス"@ja
 dbpedia:Los_Angeles rdf:label "Лос-Анджелес"@ru

then the return value would be C<< ('en', 'ja', 'ru') >>.

=cut

sub availableLanguagesForStatement {
	my $self	= shift;
	my $st	= shift;
	my %languages;
	my @nodes	= $st->nodes;
	$nodes[2]	= undef;
	my $iter	= $self->{store}->get_statements(@nodes);
	while (my $q = $iter->next) {
		my $object	= $q->object;
		if ($object->isa('RDF::Trine::Node::Literal') and $object->has_language) {
			my $language	= $object->literal_value_language;
			$languages{$language}++;
        }
    }
    return keys %languages;
}

=item C<< languagePreferenceAllowsStatement ( $statement, \%cache ) >>

Returns true if the C<< $statement >> is allowed by the current language
preference. C<< %cache >> is used across multiple calls to this method for
performance reasons.

=cut

sub languagePreferenceAllowsStatement {
	my $self	= shift;
	my $st		= shift;
	my $cache	= shift;
	my $object	= $st->object;
	if ($object->isa('RDF::Trine::Node::Literal') and $object->has_language) {
		my $language	= $object->literal_value_language;
		my @availableLanguages	= $self->availableLanguagesForStatement($st);
		my %availableValues		= map { $_ => $self->qvalueForLanguage($_, $cache) * $self->siteQValueForLanguage($_) } @availableLanguages;
		my $prefLang	= reduce { $availableValues{$a} > $availableValues{$b} ? $a : $b } keys %availableValues;
		return ($prefLang eq $language);
    } else {
	    return 1;
	}
}


=item C<< supports ( [ $feature ] ) >>

If C<< $feature >> is specified, returns true if the feature is supported by the
store, false otherwise. If C<< $feature >> is not specified, returns a list of
supported features.

=cut

sub supports {
	my $self	= shift;
	return;
}

=begin private

=item C<< can >>

Delegating implementation.

=end private

=cut

sub can {
	my $proto	= shift;
	my $name	= shift;
	my %methods	= map { $_ => 1 } qw(new new_with_config _new_with_config get_statements count_statements);
	return 1 if exists $methods{$name};
	if (ref($proto)) {
		return $proto->{store}->can($name);
	} else {
		return;
	}
}

sub AUTOLOAD {
	my $self	= shift;
	our $AUTOLOAD;
	return if ($AUTOLOAD =~ /:DESTROY$/);
	my ($name)	= ($AUTOLOAD =~ m/^.*:(.*)$/);
	my $store	= $self->{store};
	unless ($store->can($name)) {
		my $class	= ref($store);
		Carp::confess qq[Can't locate object method "$name" via package "$class"];
	}
	return $store->$name(@_);
}

1;

__END__

=back

=head1 BUGS

Please report any bugs or feature requests to through the GitHub web interface
at L<https://github.com/kasei/perlrdf/issues>.

=head1 AUTHOR

Gregory Todd Williams  C<< <gwilliams@cpan.org> >>

=head1 COPYRIGHT

Copyright (c) 2006-2012 Gregory Todd Williams. This
program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
