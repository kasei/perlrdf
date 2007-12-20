# RDF::Trice::Error
# -------------
# $Revision: 127 $
# $Date: 2006-02-08 14:53:21 -0500 (Wed, 08 Feb 2006) $
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Trice::Error - Error classes for RDF::Trice.

=head1 VERSION

This document describes RDF::Trice::Error version 1.001

=head1 SYNOPSIS

 use RDF::Trice::Error qw(:try);

=head1 DESCRIPTION

RDF::Trice::Error provides an class hierarchy of errors that other RDF::Trice
classes may throw using the L<Error|Error> API. See L<Error> for more information.

=head1 REQUIRES

L<Error|Error>

=cut

package RDF::Trice::Error;

use strict;
use warnings;
use Carp qw(carp croak confess);

use base qw(Error);

######################################################################

our ($REVISION, $VERSION, $debug);
BEGIN {
	$debug		= 0;
	$REVISION	= do { my $REV = (qw$Revision: 127 $)[1]; sprintf("%0.3f", 1 + ($REV/1000)) };
	$VERSION	= 1.001;
}

######################################################################

package RDF::Trice::Error::CompilationError;

use base qw(RDF::Trice::Error);

package RDF::Trice::Error::QuerySyntaxError;

use base qw(RDF::Trice::Error);

package RDF::Trice::Error::MethodInvocationError;

use base qw(RDF::Trice::Error);

package RDF::Trice::Error::SerializationError;

use base qw(RDF::Trice::Error);


# 
# package RDF::Query::Error::ParseError;
# 
# use base qw(RDF::Query::Error);
# 
# package RDF::Query::Error::MethodError;
# 
# use base qw(RDF::Query::Error);
# 
# package RDF::Query::Error::ModelError;
# 
# use base qw(RDF::Query::Error);
# 
# package RDF::Query::Error::QueryPatternError;
# 
# use base qw(RDF::Query::Error::QuerySyntaxError);
# 
# package RDF::Query::Error::SimpleQueryPatternError;
# 
# use base qw(RDF::Query::Error::QueryPatternError);
# 
# package RDF::Query::Error::ComparisonError;
# 
# use base qw(RDF::Query::Error::CompilationError);
# 
# package RDF::Query::Error::FilterEvaluationError;
# 
# use base qw(RDF::Query::Error);
# 
# package RDF::Query::Error::TypeError;
# 
# use base qw(RDF::Query::Error);
# 
# package RDF::Query::Error::ExecutionError;
# 
# use base qw(RDF::Query::Error);


1;

__END__

=head1 AUTHOR

 Gregory Williams <gwilliams@cpan.org>

=cut
