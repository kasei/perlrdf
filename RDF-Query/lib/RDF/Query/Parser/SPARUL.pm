# RDF::Query::Parser::SPARUL
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Parser::SPARUL - SPARQL Update Parser.

=head1 VERSION

This document describes RDF::Query::Parser::SPARUL version 2.200_01, released XX July 2009.

=head1 SYNOPSIS

 use RDF::Query::Parser::SPARUL;
 my $parser	= RDF::Query::Parse::SPARUL->new();
 my $iterator = $parser->parse( $query, $base_uri );

=head1 DESCRIPTION

...

=cut

package RDF::Query::Parser::SPARUL;

use strict;
use warnings;
use base qw(RDF::Query::Parser::SPARQL);
our $VERSION		= '2.200_01';

use URI;
use Data::Dumper;
use RDF::Query::Error qw(:try);
use RDF::Query::Parser;
use RDF::Query::Algebra;
use RDF::Trine::Namespace qw(rdf);
use Scalar::Util qw(blessed looks_like_number reftype);

######################################################################

our ($VERSION);
BEGIN {
	$VERSION	= '2.200_01';
}

######################################################################


# [1] Query ::= Prologue ( SelectQuery | ConstructQuery | DescribeQuery | AskQuery | (Update | Manage)*)
# [1]  SPARQLUpdate  ::=  Prologue ( ( Update | Manage ) )*
sub _Query {
	my $self	= shift;
	$self->__consume_ws_opt;
	$self->_Prologue;
	$self->__consume_ws_opt;
	if ($self->_test(qr/SELECT/i)) {
		$self->_SelectQuery();
	} elsif ($self->_test(qr/CONSTRUCT/i)) {
		$self->_ConstructQuery();
	} elsif ($self->_test(qr/DESCRIBE/i)) {
		$self->_DescribeQuery();
	} elsif ($self->_test(qr/ASK/i)) {
		$self->_AskQuery();
	} elsif ($self->_test(qr/(MODIFY|INSERT|DELETE|LOAD|CLEAR|CREATE|DROP)/)) {
		my @updates;
		while ($self->_Update_test || $self->_Manage_test) {
			if ($self->_Update_test) {
				$self->_Update;
			} else {
				$self->_Manage;
			}
		}
		warn Dumper(\@updates);
	} else {
		my $l		= Log::Log4perl->get_logger("rdf.query");
		if ($l->is_debug) {
			$l->logcluck("Syntax error: Expected query type with input <<$self->{tokens}>>");
		}
		throw RDF::Query::Error::ParseError -text => 'Syntax error: Expected query type';
	}
	
	my $remaining	= $self->{tokens};
	if ($remaining =~ m/\S/) {
		throw RDF::Query::Error::ParseError -text => "Remaining input after query: $remaining";
	}
}

sub _Update_test {
	my $self	= shift;
	return 1 if $self->_test( qr/MODIFY|INSERT|DELETE|LOAD|CLEAR/i );
	return 0;
}

# [2]  Update  ::=  Modify | Insert | Delete | Load | Clear
sub _Update {
	my $self	= shift;
	if ($self->_test(qr/MODIFY/)) {
		$self->_Modify;
	} elsif ($self->_test(qr/INSERT/)) {
		$self->_Insert;
	} elsif ($self->_test(qr/DELETE/)) {
		$self->_Delete;
	} elsif ($self->_test(qr/LOAD/)) {
		$self->_Load;
	} elsif ($self->_test(qr/CLEAR/)) {
		$self->_Clear;
	} else {
		throw RDF::Query::Error::ParseError -text => 'Syntax error: Expected update type';
	}
}

sub _Manage_test {
	my $self	= shift;
	return 1 if $self->_test( qr/CREATE|DROP/i );
	return 0;
}

# [13]  Manage  ::=  Create | Drop
sub _Manage {
	my $self	= shift;
	if ($self->_test(qr/CREATE/)) {
		$self->_Create;
	} elsif ($self->_test(qr/DROP/)) {
		$self->_Drop;
	} else {
		throw RDF::Query::Error::ParseError -text => 'Syntax error: Expected manage type';
	}
}

# [3]  Modify  ::=  'MODIFY' GraphIRI* 'DELETE' ConstructTemplate 'INSERT' ConstructTemplate WhereClause?
sub _Modify {
	my $self	= shift;
	$self->_eat(qr/MODIFY/i);
	$self->__consume_ws;
	while ($self->_test(qr/GRAPH/)) {
		$self->_GraphIRI;
		$self->__consume_ws_opt;
	}
	$self->_eat(qr/DELETE/i);
	$self->__consume_ws;
	$self->_ConstructTemplate;
	$self->__consume_ws_opt;

	$self->_eat(qr/INSERT/i);
	$self->__consume_ws;
	$self->_ConstructTemplate;
	
	$self->__consume_ws_opt;
	if ($self->_WhereClause_test) {
		$self->_WhereClause;
	}
}

# [4]  Delete  ::=  'DELETE' ( DeleteData | DeleteTemplate )
sub _Delete {
	my $self	= shift;
	$self->_eat(qr/MODIFY/i);
	$self->__consume_ws;
	if ($self->_DeleteData_test) {
		$self->_DeleteData;
	} else {
		$self->_DeleteTemplate;
	}
}

# [5]  DeleteData  ::=  'DATA' ( 'FROM'? IRIref )* ConstructTemplate
sub _DeleteData {
	my $self	= shift;
	$self->_eat(qr/DATA/i);
	$self->__consume_ws;
	while ($self->_test(qr/FROM/) or $self->_IRIref_test) {
		if ($self->_test(qr/FROM/)) {
			$self->_eat(qr/FROM/);
			$self->__consume_ws_opt;
		}
		$self->_IRIref;
		$self->__consume_ws_opt;
	}
	$self->_ConstructTemplate;
}

# [6]  DeleteTemplate  ::=  ( 'FROM'? IRIref )* ConstructTemplate WhereClause?
sub _DeleteTemplate {
	my $self	= shift;
	while ($self->_test(qr/FROM/) or $self->_IRIref_test) {
		if ($self->_test(qr/FROM/)) {
			$self->_eat(qr/FROM/);
			$self->__consume_ws_opt;
		}
		$self->_IRIref;
		$self->__consume_ws_opt;
	}
	$self->_ConstructTemplate;
	
	$self->__consume_ws_opt;
	if ($self->_WhereClause_test) {
		$self->_WhereClause;
	}
}

# [7]  Insert  ::=  'INSERT' ( InsertData | InsertTemplate )
sub _Insert {
	my $self	= shift;
	$self->_eat(qr/INSERT/i);
	$self->__consume_ws;
	if ($self->_test(qr/DATA/)) {
		$self->_InsertData;
	} else {
		$self->_InsertTemplate;
	}
}

# [8]  InsertData  ::=  'DATA' ( 'INTO'? IRIref )* ConstructTemplate
sub _InsertData {
	my $self	= shift;
	$self->_eat(qr/DATA/i);
	$self->__consume_ws;
	
	while ($self->_test(qr/INTO/) or $self->_IRIref_test) {
		if ($self->_test(qr/INTO/)) {
			$self->_eat(qr/FROM/);
			$self->__consume_ws_opt;
		}
		$self->_IRIref;
		$self->__consume_ws_opt;
	}
	
	$self->_ConstructTemplate;
}

# [9]  InsertTemplate  ::=  ( 'INTO'? IRIref )* ConstructTemplate WhereClause?
sub _InsertTemplate {
	my $self	= shift;
	while ($self->_test(qr/INTO/) or $self->_IRIref_test) {
		if ($self->_test(qr/INTO/)) {
			$self->_eat(qr/FROM/);
			$self->__consume_ws_opt;
		}
		$self->_IRIref;
		$self->__consume_ws_opt;
	}
	
	$self->_ConstructTemplate;

	$self->__consume_ws_opt;
	if ($self->_WhereClause_test) {
		$self->_WhereClause;
	}
}

# [10]  GraphIRI  ::=  'GRAPH' IRIref
sub _GraphIRI {
	my $self	= shift;
	$self->_eat(qr/GRAPH/i);
	$self->__consume_ws;
	
	$self->_IRIref;
}

# [11]  Load  ::=  'LOAD' IRIref+ ( 'INTO' IRIref )?
sub _Load {
	my $self	= shift;
	$self->_eat(qr/LOAD/i);
	$self->__consume_ws;
	
	do {
		$self->__consume_ws_opt;
		$self->_IRIref;
	} while ($self->_IRIref_test);
	$self->__consume_ws_opt;
	
	if ($self->_test(qr/INTO/)) {
		$self->_eat(qr/INTO/i);
		$self->__consume_ws;
		$self->_IRIref;
	}
}

# [12]  Clear  ::=  'CLEAR' GraphIRI?
sub _Clear {
	my $self	= shift;
	$self->_eat(qr/CLEAR/i);
	$self->__consume_ws;
	
	if ($self->_test(qr/GRAPH/i)) {
		$self->_GraphIRI;
	}
}

# [14]  Create  ::=  'CREATE' 'SILENT'? GraphIRI
sub _Create {
	my $self	= shift;
	$self->_eat(qr/CREATE/i);
	$self->__consume_ws;
	
	if ($self->_test(qr/SILENT/i)) {
		$self->_eat(qr/SILENT/i);
		$self->__consume_ws;
	}
	
	$self->_GraphIRI;
}

# [15]  Drop  ::=  'DROP' 'SILENT'? GraphIRI
sub _Drop {
	my $self	= shift;
	$self->_eat(qr/DROP/i);
	$self->__consume_ws;
	
	if ($self->_test(qr/SILENT/i)) {
		$self->_eat(qr/SILENT/i);
		$self->__consume_ws;
	}
	
	$self->_GraphIRI;
}


1;


__END__

