###################################################################################
#
#    This file was generated using Parse::Eyapp version 1.082.
#
# (c) Parse::Yapp Copyright 1998-2001 Francois Desarmenien.
# (c) Parse::Eyapp Copyright 2006 Casiano Rodriguez-Leon. Universidad de La Laguna.
#        Don't edit this file, use source file "lib/RDF/Query/Parser/SPARQL.yp" instead.
#
#             ANY CHANGE MADE HERE WILL BE LOST !
#
###################################################################################
package RDF::Query::Parser::SPARQL;
use strict;

push @RDF::Query::Parser::SPARQL::ISA, 'Parse::Eyapp::Driver';


{ ###########Included /Library/Perl/5.8.8/Parse/Eyapp/Driver.pm file
#
# Module Parse::Eyapp::Driver
#
# This module is part of the Parse::Eyapp package available on your
# nearest CPAN
#
# This module is based on Francois Desarmenien Parse::Yapp module
# (c) Parse::Yapp Copyright 1998-2001 Francois Desarmenien, all rights reserved.
# (c) Parse::Eyapp Copyright 2006 Casiano Rodriguez-Leon, all rights reserved.

package Parse::Eyapp::Driver;

require 5.004;

use strict;

our ( $VERSION, $COMPATIBLE, $FILENAME );

$VERSION = '1.082';
$COMPATIBLE = '0.07';
$FILENAME=__FILE__;

use Carp;

#Known parameters, all starting with YY (leading YY will be discarded)
my(%params)=(YYLEX => 'CODE', 'YYERROR' => 'CODE', YYVERSION => '',
	     YYRULES => 'ARRAY', YYSTATES => 'ARRAY', YYDEBUG => '', 
	     # added by Casiano
	     #YYPREFIX  => '',  # Not allowed at YYParse time but in new
	     YYFILENAME => '', 
       YYBYPASS   => '',
	     YYGRAMMAR  => 'ARRAY', 
	     YYTERMS    => 'HASH',
	     ); 
my (%newparams) = (%params, YYPREFIX => '',);

#Mandatory parameters
my(@params)=('LEX','RULES','STATES');

sub new {
    my($class)=shift;
	my($errst,$nberr,$token,$value,$check,$dotpos);
    my($self)={ ERROR => \&_Error,
				ERRST => \$errst,
				NBERR => \$nberr,
				TOKEN => \$token,
				VALUE => \$value,
				DOTPOS => \$dotpos,
				STACK => [],
				DEBUG => 0,
				PREFIX => "",
				CHECK => \$check };

	_CheckParams( [], \%newparams, \@_, $self );

		exists($$self{VERSION})
	and	$$self{VERSION} < $COMPATIBLE
	and	croak "Eyapp driver version $VERSION ".
			  "incompatible with version $$self{VERSION}:\n".
			  "Please recompile parser module.";

        ref($class)
    and $class=ref($class);

    bless($self,$class);
}

sub YYParse {
    my($self)=shift;
    my($retval);

	_CheckParams( \@params, \%params, \@_, $self );

	if($$self{DEBUG}) {
		_DBLoad();
		$retval = eval '$self->_DBParse()';#Do not create stab entry on compile
        $@ and die $@;
	}
	else {
		$retval = $self->_Parse();
	}
    return $retval;
}

sub YYData {
	my($self)=shift;

		exists($$self{USER})
	or	$$self{USER}={};

	$$self{USER};
	
}

sub YYErrok {
	my($self)=shift;

	${$$self{ERRST}}=0;
    undef;
}

sub YYNberr {
	my($self)=shift;

	${$$self{NBERR}};
}

sub YYRecovering {
	my($self)=shift;

	${$$self{ERRST}} != 0;
}

sub YYAbort {
	my($self)=shift;

	${$$self{CHECK}}='ABORT';
    undef;
}

sub YYAccept {
	my($self)=shift;

	${$$self{CHECK}}='ACCEPT';
    undef;
}

sub YYError {
	my($self)=shift;

	${$$self{CHECK}}='ERROR';
    undef;
}

sub YYSemval {
	my($self)=shift;
	my($index)= $_[0] - ${$$self{DOTPOS}} - 1;

		$index < 0
	and	-$index <= @{$$self{STACK}}
	and	return $$self{STACK}[$index][1];

	undef;	#Invalid index
}

### Casiano methods

sub YYLhs { 
  # returns the syntax variable on
  # the left hand side of the current production
  my $self = shift;

  return $self->{CURRENT_LHS}
}

sub YYRuleindex { 
  # returns the index of the rule
  # counting the super rule as rule 0
  my $self = shift;

  return $self->{CURRENT_RULE}
}

sub YYRightside { 
  # returns the rule
  # counting the super rule as rule 0
  my $self = shift;

  return @{$self->{GRAMMAR}->[$self->{CURRENT_RULE}]->[2]};
}

sub YYIsterm {
  my $self = shift;
  my $symbol = shift;

  return exists ($self->{TERMS}->{$symbol});
}

sub YYIssemantic {
  my $self = shift;
  my $symbol = shift;

  return ($self->{TERMS}->{$symbol});
}


sub YYName {
  my $self = shift;

  return $self->{GRAMMAR}->[$self->{CURRENT_RULE}]->[0];
}

sub YYPrefix {
  my $self = shift;

  $self->{PREFIX} = $_[0] if @_;
  #$self->{PREFIX} .= '::' unless  $self->{PREFIX} =~ /::$/;
  $self->{PREFIX};
}

sub YYFilename {
  my $self = shift;

  $self->{FILENAME} = $_[0] if @_;
  $self->{FILENAME};
}

sub YYBypass {
  my $self = shift;

  $self->{BYPASS} = $_[0] if @_;
  $self->{BYPASS};
}

sub YYBypassrule {
  my $self = shift;

  return $self->{GRAMMAR}->[$self->{CURRENT_RULE}][3];
}

sub YYFirstline {
  my $self = shift;

  $self->{FIRSTLINE} = $_[0] if @_;
  $self->{FIRSTLINE};
}

sub BeANode {
  my $class = shift;

    no strict 'refs';
    push @{$class."::ISA"}, "Parse::Eyapp::Node" unless $class->isa("Parse::Eyapp::Node");
}

#sub BeATranslationScheme {
#  my $class = shift;
#
#    no strict 'refs';
#    push @{$class."::ISA"}, "Parse::Eyapp::TranslationScheme" unless $class->isa("Parse::Eyapp::TranslationScheme");
#}

{
  my $attr =  sub { 
      $_[0]{attr} = $_[1] if @_ > 1;
      $_[0]{attr}
    };

  sub make_node_classes {
    my $self = shift;
    my $prefix = $self->YYPrefix() || '';

    { no strict 'refs';
      *{$prefix."TERMINAL::attr"} = $attr;
    }

    for (@_) {
       BeANode("$prefix$_"); 
    }
  }
}

####################################################################
# Usage      : ????
# Purpose    : Responsible for the %tree directive 
#              On each production the default action becomes:
#              sub { goto &Parse::Eyapp::Driver::YYBuildAST }
#
# Returns    : ????
# Parameters : ????
# Throws     : no exceptions
# Comments   : none
# See Also   : n/a
# To Do      : many things: Optimize this!!!!
sub YYBuildAST { 
  my $self = shift;
  my $PREFIX = $self->YYPrefix();
  my @right = $self->YYRightside(); # Symbols on the right hand side of the production
  my $lhs = $self->YYLhs;
  my $name = $self->YYName();
  my $bypass = $self->YYBypassrule; # Boolean: shall we do bypassing of lonely nodes?
  my $class = "$PREFIX$name";
  my @children;

  my $node = bless {}, $class;

  for(my $i = 0; $i < @right; $i++) {
    $_ = $right[$i]; # The symbol
    my $ch = $_[$i]; # The attribute/reference
    if ($self->YYIssemantic($_)) {
      my $class = $PREFIX.'TERMINAL';
      my $node = bless { token => $_, attr => $ch, children => [] }, $class;
      push @children, $node;
      next;
    }

    if ($self->YYIsterm($_)) {
      next unless UNIVERSAL::can($PREFIX."TERMINAL", "save_attributes");
      TERMINAL::save_attributes($ch, $node);
      next;
    }

    if (UNIVERSAL::isa($ch, $PREFIX."_PAREN")) { # Warning: weak code!!!
      push @children, @{$ch->{children}};
      next;
    }

    # If it is an intermediate semantic action skip it
    next if $_ =~ qr{@}; # intermediate rule
    next unless ref($ch);
    push @children, $ch;
  }

  
  if ($bypass and @children == 1) {
    $node = $children[0]; 
    # Re-bless unless is "an automatically named node", but the characterization of this is 
    bless $node, $class unless $name =~ /${lhs}_\d+$/; # lazy, weak (and wicked).
    return $node;
  }
  $node->{children} = \@children; 
  return $node;
}

sub YYBuildTS { 
  my $self = shift;
  my $PREFIX = $self->YYPrefix();
  my @right = $self->YYRightside(); # Symbols on the right hand side of the production
  my $lhs = $self->YYLhs;
  my $name = $self->YYName();
  my $class;
  my @children;

  for(my $i = 0; $i < @right; $i++) {
    $_ = $right[$i]; # The symbol
    my $ch = $_[$i]; # The attribute/reference

    if ($self->YYIsterm($_)) { 
      $class = $PREFIX.'TERMINAL';
      push @children, bless { token => $_, attr => $ch, children => [] }, $class;
      next;
    }

    if (UNIVERSAL::isa($ch, $PREFIX."_PAREN")) { # Warning: weak code!!!
      push @children, @{$ch->{children}};
      next;
    }

    # Substitute intermediate code node _CODE(CODE()) by CODE()
    if (UNIVERSAL::isa($ch, $PREFIX."_CODE")) { # Warning: weak code!!!
      push @children, $ch->child(0);
      next;
    }

    next unless ref($ch);
    push @children, $ch;
  }

  if (unpack('A1',$lhs) eq '@') { # class has to be _CODE check
          $lhs =~ /^\@[0-9]+\-([0-9]+)$/
      or  croak "In line rule name '$lhs' ill formed: report it as a BUG.\n";
      my $dotpos = $1;
 
      croak "Fatal error building metatree when processing  $lhs -> @right" 
      unless exists($_[$dotpos]) and UNIVERSAL::isa($_[$dotpos], 'CODE') ; 
      push @children, $_[$dotpos];
  }
  else {
    my $code = $_[@right];
    if (UNIVERSAL::isa($code, 'CODE')) {
      push @children, $code; 
    }
    else {
      croak "Fatal error building translation scheme. Code or undef expected" if (defined($code));
    }
  }

  $class = "$PREFIX$name";
  my $node = bless { children => \@children }, $class; 
  $node;
}

# for lists
sub YYActionforT_TX1X2 {
  my $self = shift;
  my $head = shift;
  my $PREFIX = $self->YYPrefix();
  my @right = $self->YYRightside();
  my $class;

  for(my $i = 1; $i < @right; $i++) {
    $_ = $right[$i];
    my $ch = $_[$i-1];
    if ($self->YYIssemantic($_)) {
      $class = $PREFIX.'TERMINAL';
      push @{$head->{children}}, bless { token => $_, attr => $ch, children => [] }, $class;
      
      next;
    }
    next if $self->YYIsterm($_);
    if (ref($ch) eq  $PREFIX."_PAREN") { # Warning: weak code!!!
      push @{$head->{children}}, @{$ch->{children}};
      next;
    }
    next unless ref($ch);
    push @{$head->{children}}, $ch;
  }
  return $head;
}

sub YYActionforT_empty {
  my $self = shift;
  my $PREFIX = $self->YYPrefix();
  my $name = $self->YYName();

  # Allow use of %name
  my $class = $PREFIX.$name;
  my $node = bless { children => [] }, $class;
  #BeANode($class);
  $node;
}

sub YYActionforT_single {
  my $self = shift;
  my $PREFIX = $self->YYPrefix();
  my $name = $self->YYName();
  my @right = $self->YYRightside();
  my $class;

  # Allow use of %name
  my @t;
  for(my $i = 0; $i < @right; $i++) {
    $_ = $right[$i];
    my $ch = $_[$i];
    if ($self->YYIssemantic($_)) {
      $class = $PREFIX.'TERMINAL';
      push @t, bless { token => $_, attr => $ch, children => [] }, $class;
      #BeANode($class);
      next;
    }
    next if $self->YYIsterm($_);
    if (ref($ch) eq  $PREFIX."_PAREN") { # Warning: weak code!!!
      push @t, @{$ch->{children}};
      next;
    }
    next unless ref($ch);
    push @t, $ch;
  }
  $class = $PREFIX.$name;
  my $node = bless { children => \@t }, $class;
  #BeANode($class);
  $node;
}

### end Casiano methods

sub YYCurtok {
	my($self)=shift;

        @_
    and ${$$self{TOKEN}}=$_[0];
    ${$$self{TOKEN}};
}

sub YYCurval {
	my($self)=shift;

        @_
    and ${$$self{VALUE}}=$_[0];
    ${$$self{VALUE}};
}

sub YYExpect {
    my($self)=shift;

    keys %{$self->{STATES}[$self->{STACK}[-1][0]]{ACTIONS}}
}

sub YYLexer {
    my($self)=shift;

	$$self{LEX};
}


#################
# Private stuff #
#################


sub _CheckParams {
	my($mandatory,$checklist,$inarray,$outhash)=@_;
	my($prm,$value);
	my($prmlst)={};

	while(($prm,$value)=splice(@$inarray,0,2)) {
        $prm=uc($prm);
			exists($$checklist{$prm})
		or	croak("Unknow parameter '$prm'");
			ref($value) eq $$checklist{$prm}
		or	croak("Invalid value for parameter '$prm'");
        $prm=unpack('@2A*',$prm);
		$$outhash{$prm}=$value;
	}
	for (@$mandatory) {
			exists($$outhash{$_})
		or	croak("Missing mandatory parameter '".lc($_)."'");
	}
}

sub _Error {
	print "Parse error.\n";
}

sub _DBLoad {
	{
		no strict 'refs';

			exists(${__PACKAGE__.'::'}{_DBParse})#Already loaded ?
		and	return;
	}
	my($fname)=__FILE__;
	my(@drv);
	local $/ = "\n";
	open(DRV,"<$fname") or die "Report this as a BUG: Cannot open $fname";
  local $_;
	while(<DRV>) {
                	/^\s*sub\s+_Parse\s*{\s*$/ .. /^\s*}\s*#\s*_Parse\s*$/
        	and     do {
                	s/^#DBG>//;
                	push(@drv,$_);
        	}
	}
	close(DRV);

	$drv[0]=~s/_P/_DBP/;
	eval join('',@drv);
}

#Note that for loading debugging version of the driver,
#this file will be parsed from 'sub _Parse' up to '}#_Parse' inclusive.
#So, DO NOT remove comment at end of sub !!!
sub _Parse {
    my($self)=shift;

	my($rules,$states,$lex,$error)
     = @$self{ 'RULES', 'STATES', 'LEX', 'ERROR' };
	my($errstatus,$nberror,$token,$value,$stack,$check,$dotpos)
     = @$self{ 'ERRST', 'NBERR', 'TOKEN', 'VALUE', 'STACK', 'CHECK', 'DOTPOS' };

#DBG>	my($debug)=$$self{DEBUG};
#DBG>	my($dbgerror)=0;

#DBG>	my($ShowCurToken) = sub {
#DBG>		my($tok)='>';
#DBG>		for (split('',$$token)) {
#DBG>			$tok.=		(ord($_) < 32 or ord($_) > 126)
#DBG>					?	sprintf('<%02X>',ord($_))
#DBG>					:	$_;
#DBG>		}
#DBG>		$tok.='<';
#DBG>	};

	$$errstatus=0;
	$$nberror=0;
	($$token,$$value)=(undef,undef);
	@$stack=( [ 0, undef ] );
	$$check='';

    while(1) {
        my($actions,$act,$stateno);

        $stateno=$$stack[-1][0];
        $actions=$$states[$stateno];

#DBG>	print STDERR ('-' x 40),"\n";
#DBG>		$debug & 0x2
#DBG>	and	print STDERR "In state $stateno:\n";
#DBG>		$debug & 0x08
#DBG>	and	print STDERR "Stack:[".
#DBG>					 join(',',map { $$_[0] } @$stack).
#DBG>					 "]\n";


        if  (exists($$actions{ACTIONS})) {

				defined($$token)
            or	do {
				($$token,$$value)=&$lex($self);
#DBG>				$debug & 0x01
#DBG>			and	do { 
#DBG>       print STDERR "Need token. Got ".&$ShowCurToken."\n";
#DBG>     };
			};

            $act=   exists($$actions{ACTIONS}{$$token})
                    ?   $$actions{ACTIONS}{$$token}
                    :   exists($$actions{DEFAULT})
                        ?   $$actions{DEFAULT}
                        :   undef;
        }
        else {
            $act=$$actions{DEFAULT};
#DBG>			$debug & 0x01
#DBG>		and	print STDERR "Don't need token.\n";
        }

            defined($act)
        and do {

                $act > 0
            and do {        #shift

#DBG>				$debug & 0x04
#DBG>			and	print STDERR "Shift and go to state $act.\n";

					$$errstatus
				and	do {
					--$$errstatus;

#DBG>					$debug & 0x10
#DBG>				and	$dbgerror
#DBG>				and	$$errstatus == 0
#DBG>				and	do {
#DBG>					print STDERR "**End of Error recovery.\n";
#DBG>					$dbgerror=0;
#DBG>				};
				};


                push(@$stack,[ $act, $$value ]);

					$$token ne ''	#Don't eat the eof
				and	$$token=$$value=undef;
                next;
            };

            #reduce
            my($lhs,$len,$code,@sempar,$semval);
            ($lhs,$len,$code)=@{$$rules[-$act]};

#DBG>			$debug & 0x04
#DBG>		and	$act
#DBG>		#and	print STDERR "Reduce using rule ".-$act." ($lhs,$len): "; # old Parse::Yapp line
#DBG>		and	do { my @rhs = @{$self->{GRAMMAR}->[-$act]->[2]};
#DBG>            @rhs = ( '/* empty */' ) unless @rhs;
#DBG>            my $rhs = "@rhs";
#DBG>            $rhs = substr($rhs, 0, 30).'...' if length($rhs) > 30; # chomp if too large
#DBG>            print STDERR "Reduce using rule ".-$act." ($lhs --> $rhs): "; 
#DBG>          };

                $act
            or  $self->YYAccept();

            $$dotpos=$len;

                unpack('A1',$lhs) eq '@'    #In line rule
            and do {
                    $lhs =~ /^\@[0-9]+\-([0-9]+)$/
                or  die "In line rule name '$lhs' ill formed: ".
                        "report it as a BUG.\n";
                $$dotpos = $1;
            };

            @sempar =       $$dotpos
                        ?   map { $$_[1] } @$stack[ -$$dotpos .. -1 ]
                        :   ();

            $self->{CURRENT_LHS} = $lhs;
            $self->{CURRENT_RULE} = -$act; # count the super-rule?
            $semval = $code ? &$code( $self, @sempar )
                            : @sempar ? $sempar[0] : undef;

            splice(@$stack,-$len,$len);

                $$check eq 'ACCEPT'
            and do {

#DBG>			$debug & 0x04
#DBG>		and	print STDERR "Accept.\n";

				return($semval);
			};

                $$check eq 'ABORT'
            and	do {

#DBG>			$debug & 0x04
#DBG>		and	print STDERR "Abort.\n";

				return(undef);

			};

#DBG>			$debug & 0x04
#DBG>		and	print STDERR "Back to state $$stack[-1][0], then ";

                $$check eq 'ERROR'
            or  do {
#DBG>				$debug & 0x04
#DBG>			and	print STDERR 
#DBG>				    "go to state $$states[$$stack[-1][0]]{GOTOS}{$lhs}.\n";

#DBG>				$debug & 0x10
#DBG>			and	$dbgerror
#DBG>			and	$$errstatus == 0
#DBG>			and	do {
#DBG>				print STDERR "**End of Error recovery.\n";
#DBG>				$dbgerror=0;
#DBG>			};

			    push(@$stack,
                     [ $$states[$$stack[-1][0]]{GOTOS}{$lhs}, $semval ]);
                $$check='';
                next;
            };

#DBG>			$debug & 0x04
#DBG>		and	print STDERR "Forced Error recovery.\n";

            $$check='';

        };

        #Error
            $$errstatus
        or   do {

            $$errstatus = 1;
            &$error($self);
                $$errstatus # if 0, then YYErrok has been called
            or  next;       # so continue parsing

#DBG>			$debug & 0x10
#DBG>		and	do {
#DBG>			print STDERR "**Entering Error recovery.\n";
#DBG>			{ 
#DBG>       local $" = ", "; 
#DBG>       my @expect = map { ">$_<" } $self->YYExpect();
#DBG>       print STDERR "Expecting one of: @expect\n";
#DBG>     };
#DBG>			++$dbgerror;
#DBG>		};

            ++$$nberror;

        };

			$$errstatus == 3	#The next token is not valid: discard it
		and	do {
				$$token eq ''	# End of input: no hope
			and	do {
#DBG>				$debug & 0x10
#DBG>			and	print STDERR "**At eof: aborting.\n";
				return(undef);
			};

#DBG>			$debug & 0x10
#DBG>		and	print STDERR "**Discard invalid token ".&$ShowCurToken.".\n";

			$$token=$$value=undef;
		};

        $$errstatus=3;

		while(	  @$stack
			  and (		not exists($$states[$$stack[-1][0]]{ACTIONS})
			        or  not exists($$states[$$stack[-1][0]]{ACTIONS}{error})
					or	$$states[$$stack[-1][0]]{ACTIONS}{error} <= 0)) {

#DBG>			$debug & 0x10
#DBG>		and	print STDERR "**Pop state $$stack[-1][0].\n";

			pop(@$stack);
		}

			@$stack
		or	do {

#DBG>			$debug & 0x10
#DBG>		and	print STDERR "**No state left on stack: aborting.\n";

			return(undef);
		};

		#shift the error token

#DBG>			$debug & 0x10
#DBG>		and	print STDERR "**Shift \$error token and go to state ".
#DBG>						 $$states[$$stack[-1][0]]{ACTIONS}{error}.
#DBG>						 ".\n";

		push(@$stack, [ $$states[$$stack[-1][0]]{ACTIONS}{error}, undef ]);

    }

    #never reached
	croak("Error in driver logic. Please, report it as a BUG");

}#_Parse
#DO NOT remove comment

1;


} ###########End of include /Library/Perl/5.8.8/Parse/Eyapp/Driver.pm file

{ ###########Included /Library/Perl/5.8.8/Parse/Eyapp/Node.pm file
# (c) Parse::Eyapp Copyright 2006-2007 Casiano Rodriguez-Leon, all rights reserved.
package Parse::Eyapp::Node;
use strict;
use Carp;#use base qw(Exporter);
use List::MoreUtils qw(lastval);
use List::Util qw(first);
use Data::Dumper;

#our @EXPORT_OK = qw(new);

our $FILENAME=__FILE__;

####################################################################
# Usage      : 
# line: %name PROG
#        exp <%name EXP + ';'>
#                 { @{$lhs->{t}} = map { $_->{t}} ($lhs->child(0)->children()); }
# ;
# Returns    : The array of children of the node. When the tree is a
#              translation scheme the CODE references are also included
# Parameters : the node (method)
# See Also   : Children

sub children {
  my $self = CORE::shift;
  
  return () unless UNIVERSAL::can($self, 'children');
  @{$self->{children}} = @_ if @_;
  @{$self->{children}}
}

####################################################################
# Usage      :  line: %name PROG
#                        (exp) <%name EXP + ';'>
#                          { @{$lhs->{t}} = map { $_->{t}} ($_[1]->Children()); }
#
# Returns    : The true children of the node, excluding CODE CHILDREN
# Parameters : The Node object

sub Children {
  my $self = CORE::shift;
  
  return () unless UNIVERSAL::can($self, 'children');

  @{$self->{children}} = @_ if @_;
  grep { !UNIVERSAL::isa($_, 'CODE') } @{$self->{children}}
}

####################################################################
# Returns    : Last non CODE child
# Parameters : the node object

sub Last_child {
  my $self = CORE::shift;

  return unless UNIVERSAL::can($self, 'children') and @{$self->{children}};
  my $i = -1;
  $i-- while defined($self->{children}->[$i]) and UNIVERSAL::isa($self->{children}->[$i], 'CODE');
  return  $self->{children}->[$i];
}

sub last_child {
  my $self = CORE::shift;

  return unless UNIVERSAL::can($self, 'children') and @{$self->{children}};
  ${$self->{children}}[-1];
}

####################################################################
# Usage      :  $node->child($i)
#  my $transform = Parse::Eyapp::Treeregexp->new( STRING => q{
#     commutative_add: PLUS($x, ., $y, .)
#       => { my $t = $x; $_[0]->child(0, $y); $_[0]->child(2, $t)}
#  }
# Purpose    : Setter-getter to modify a specific child of a node
# Returns    : Child with index $i. Returns undef if the child does not exists
# Parameters : Method: the node and the index of the child. The new value is used 
#              as a setter.
# Throws     : Croaks if the index parameter is not provided
sub child {
  my ($self, $index, $value) = @_;
  
  #croak "$self is not a Parse::Eyapp::Node" unless $self->isa('Parse::Eyapp::Node');
  return undef unless  UNIVERSAL::can($self, 'child');
  croak "Index not provided" unless defined($index);
  $self->{children}[$index] = $value if defined($value);
  $self->{children}[$index];
}

sub descendant {
  my $self = shift;
  my $coord = shift;

  my @pos = split /\./, $coord;
  my $t = $self;
  my $x = shift(@pos); # discard the first empty dot
  for (@pos) {
      croak "Error computing descendant: $_ is not a number\n" 
    unless m{\d+} and $_ < $t->children;
    $t = $t->child($_);
  }
  return $t;
}

####################################################################
# Usage      : $node->s(@transformationlist);
# Example    : The following example simplifies arithmetic expressions
# using method "s":
# > cat Timeszero.trg
# /* Operator "and" has higher priority than comma "," */
# whatever_times_zero: TIMES(@b, NUM($x) and { $x->{attr} == 0 }) => { $_[0] = $NUM }
#
# > treereg Timeszero
# > cat arrays.pl
#  !/usr/bin/perl -w
#  use strict;
#  use Rule6;
#  use Parse::Eyapp::Treeregexp;
#  use Timeszero;
#
#  my $parser = new Rule6();
#  my $t = $parser->Run;
#  $t->s(@Timeszero::all);
#
#
# Returns    : Nothing
# Parameters : The object (is a method) and the list of transformations to apply.
#              The list may be a list of Parse::Eyapp:YATW objects and/or CODE
#              references
# Throws     : No exceptions
# Comments   : The set of transformations is repeatedly applied to the node
#              until there are no changes.
#              The function may hang if the set of transformations
#              matches forever.
# See Also   : The "s" method for Parse::Eyapp::YATW objects 
#              (i.e. transformation objects)

sub s {
  my @patterns = @_[1..$#_];

  # Make them Parse::Eyapp:YATW objects if they are CODE references
  @patterns = map { ref($_) eq 'CODE'? 
                      Parse::Eyapp::YATW->new(
                        PATTERN => $_,
                        #PATTERN_ARGS => [],
                      )
                      :
                      $_
                  } 
                  @patterns;
  my $changes; 
  do { 
    $changes = 0;
    foreach (@patterns) {
      $_->{CHANGES} = 0;
      $_->s($_[0]);
      $changes += $_->{CHANGES};
    }
  } while ($changes);
}


####################################################################
# Usage      : ????
# Purpose    : bud = Bottom Up Decoration: Decorates the tree with flowers :-)
#              The purpose is to decorate the AST with attributes during
#              the context-dependent analysis, mainly type-checking.
# Returns    : ????
# Parameters : The transformations.
# Throws     : no exceptions
# Comments   : The tree is traversed bottom-up. The set of
#              transformations is applied to each node in the order
#              supplied by the user. As soon as one succeeds
#              no more transformations are applied.
# See Also   : n/a
# To Do      : Avoid closure. Save @patterns inside the object
{
  my @patterns;

  sub bud {
    @patterns = @_[1..$#_];

    @patterns = map { ref($_) eq 'CODE'? 
                        Parse::Eyapp::YATW->new(
                          PATTERN => $_,
                          #PATTERN_ARGS => [],
                        )
                        :
                        $_
                    } 
                    @patterns;
    _bud($_[0], undef, undef);
  }

  sub _bud {
    my $node = $_[0];
    my $index = $_[2];

      # Is an odd leaf. Not actually a Parse::Eyapp::Node. Decorate it and leave
      if (!ref($node) or !UNIVERSAL::can($node, "children"))  {
        for my $p (@patterns) {
          return if $p->pattern->(
            $_[0],  # Node being visited  
            $_[1],  # Father of this node
            $index, # Index of this node in @Father->children
            $p,  # The YATW pattern object   
          );
        }
      };

      # Recursively decorate subtrees
      my $i = 0;
      for (@{$node->{children}}) {
        $_->_bud($_, $_[0], $i);
        $i++;
      }

      # Decorate the node
      #Change YATW object to be the  first argument?
      for my $p (@patterns) {
        return if $p->pattern->($_[0], $_[1], $index, $p); 
      }
  }
} # closure for @patterns

####################################################################
# Usage      : 
# @t = Parse::Eyapp::Node->new( q{TIMES(NUM(TERMINAL), NUM(TERMINAL))}, 
#      sub { 
#        our ($TIMES, @NUM, @TERMINAL);
#        $TIMES->{type}       = "binary operation"; 
#        $NUM[0]->{type}      = "int"; 
#        $NUM[1]->{type}      = "float"; 
#        $TERMINAL[1]->{attr} = 3.5; 
#      },
#    );
# Purpose    : Multi-Constructor
# Returns    : Array of pointers to the objects created
#              in scalar context a pointer to the first node
# Parameters : The class plus the string description and attribute handler

{

my %cache;

  sub m_bless {

    my $key = join "",@_;
    my $class = shift;
    return $cache{$key} if exists $cache{$key};

    my $b = bless { children => \@_}, $class;
    $cache{$key} = $b;

    return $b;
  }
}

sub _bless {
  my $class = shift;

  my $b = bless { children => \@_ }, $class;
  return $b;
}

sub hnew {
  my $blesser = \&m_bless;

  return _new($blesser, @_);
}

sub _new {
  my $blesser = CORE::shift;
  my $class = CORE::shift;
  local $_ = CORE::shift; # string: tree description
  my $handler = CORE::shift if ref($_[0]) eq 'CODE';


  my %classes;
  my $b;
  #TODO: Shall I receive a prefix?

  my (@stack, @index, @results, %results, @place, $open);
  while ($_) {
    #skip white spaces
    s{\A\s*}{};

    # If is a leaf is followed by parenthesis or comma or an ID
    s{\A([A-Za-z_][A-Za-z0-9_]*)\s*([),])} 
     {$1()$2} # ... then add an empty pair of parenthesis
      and do { 
        next; 
       };

    # If is a leaf is followed by an ID
    s{\A([A-Za-z_][A-Za-z0-9_]*)\s+([A-Za-z_])} 
     {$1()$2} # ... then add an empty pair of parenthesis
      and do { 
        next; 
       };

    # If is a leaf at the end
    s{\A([A-Za-z_][A-Za-z0-9_]*)\s*$} 
     {$1()} # ... then add an empty pair of parenthesis
      and do { 
        $classes{$1} = 1;
        next; 
       };

    # Is an identifier
    s{\A([A-Za-z_][A-Za-z0-9_]*)}{} 
      and do { 
        $classes{$1} = 1;
        CORE::push @stack, $1; 
        next; 
      };

    # Open parenthesis: mark the position for when parenthesis closes
    s{\A[(]}{} 
      and do { 
        my $pos = scalar(@stack);
        CORE::push @index, $pos; 
        $place[$pos] = $open++;
      };

    # Skip commas
    s{\A,}{} and next; 

    # Closing parenthesis: time to build a node
    s{\A[)]}{} and do { 
        croak "Syntax error! Closing parenthesis has no left partner!" unless @index;
        my $begin = pop @index; # check if empty!
        my @children = splice(@stack, $begin);
        my $class = pop @stack;
        croak "Syntax error! Any couple of parenthesis must be preceded by an identifier"
          unless (defined($class) and $class =~ m{^[a-zA-Z_]\w*$});

        $b = $blesser->($class, @children);

        CORE::push @stack, $b;
        $results[$place[$begin]] = $b;
        CORE::push @{$results{$class}}, $b;
        next; 
    }; 

    croak "Error building tree $_[0]." unless s{\A\s*}{};
  } # while
  croak "Syntax error! Open parenthesis has no right partner!" if @index;
  { 
    no strict 'refs';
    for (keys(%classes)) {
      push @{$_."::ISA"}, 'Parse::Eyapp::Node' unless $_->isa('Parse::Eyapp::Node');
    }
  }
  if (defined($handler) and UNIVERSAL::isa($handler, "CODE")) {
    $handler->(@results);
  }
  return wantarray? @results : $b;
}

sub new {
  my $blesser = \&_bless;

  _new($blesser, @_);
}

## Used by _subtree_list
#sub compute_hierarchy {
#  my @results = @{shift()};
#
#  # Compute the hierarchy
#  my $b;
#  my @r = @results;
#  while (@results) {
#    $b = pop @results;
#    my $d = $b->{depth};
#    my $f = lastval { $_->{depth} < $d} @results;
#    
#    $b->{father} = $f;
#    $b->{children} = [];
#    unshift @{$f->{children}}, $b;
#  }
#  $_->{father} = undef for @results;
#  bless $_, "Parse::Eyapp::Node::Match" for @r;
#  return  @r;
#}

# Matches

sub m {
  my $self = shift;
  my @patterns = @_ or croak "Expected a pattern!";
  croak "Error in method m of Parse::Eyapp::Node. Expected Parse::Eyapp:YATW patterns"
    unless $a = first { !UNIVERSAL::isa($_, "Parse::Eyapp:YATW") } @_;

  # array context: return all matches
  local $a = 0;
  my %index = map { ("$_", $a++) } @patterns;
  my @stack = (
    Parse::Eyapp::Node::Match->new( 
       node => $self, 
       depth => 0,  
       dewey => "", 
       patterns =>[] 
    ) 
  );
  my @results;
  do {
    my $mn = CORE::shift(@stack);
    my %n = %$mn;

    # See what patterns do match the current $node
    for my $pattern (@patterns) {
      push @{$mn->{patterns}}, $index{$pattern} if $pattern->{PATTERN}($n{node});
    } 
    my $dewey = $n{dewey};
    if (@{$mn->{patterns}}) {
      $mn->{family} = \@patterns;

      # Is at this time that I have to compute the father
      my $f = lastval { $dewey =~ m{^$_->{dewey}}} @results;
      $mn->{father} = $f;
      # ... and children
      unshift @{$f->{children}}, $mn if defined($f);
      CORE::push @results, $mn;
    }
    my $childdepth = $n{depth}+1;
    my $k = -1;
    CORE::unshift @stack, 
          map 
            { 
              $k++; 
              Parse::Eyapp::Node::Match->new(
                node => $_, 
                depth => $childdepth, 
                dewey => "$dewey.$k", 
                patterns => [] 
              ) 
            } $n{node}->children();
  } while (@stack);

  wantarray? @results : $results[0];
}

#sub _subtree_scalar {
#  # scalar context: return iterator
#  my $self = CORE::shift;
#  my @patterns = @_ or croak "Expected a pattern!";
#
#  # %index gives the index of $p in @patterns
#  local $a = 0;
#  my %index = map { ("$_", $a++) } @patterns;
#
#  my @stack = ();
#  my $mn = { node => $self, depth => 0, patterns =>[] };
#  my @results = ();
#
#  return sub {
#     do {
#       # See if current $node matches some patterns
#       my $d = $mn->{depth};
#       my $childdepth = $d+1;
#       # See what patterns do match the current $node
#       for my $pattern (@patterns) {
#         push @{$mn->{patterns}}, $index{$pattern} if $pattern->{PATTERN}($mn->{node});
#       } 
#
#       if (@{$mn->{patterns}}) { # matched
#         CORE::push @results, $mn;
#
#         # Compute the hierarchy
#         my $f = lastval { $_->{depth} < $d} @results;
#         $mn->{father} = $f;
#         $mn->{children} = [];
#         $mn->{family} = \@patterns;
#         unshift @{$f->{children}}, $mn if defined($f);
#         bless $mn, "Parse::Eyapp::Node::Match";
#
#         # push children in the stack
#         CORE::unshift @stack, 
#                   map { { node => $_, depth => $childdepth, patterns => [] } } 
#                                                       $mn->{node}->children();
#         $mn = CORE::shift(@stack);
#         return $results[-1];
#       }
#       # didn't match: push children in the stack
#       CORE::unshift @stack, 
#                  map { { node => $_, depth => $childdepth, patterns => [] } } 
#                                                      $mn->{node}->children();
#       $mn = CORE::shift(@stack);
#     } while ($mn); # May be the stack is empty now, but if $mn then there is a node to process
#     # reset iterator
#     my @stack = ();
#     my $mn = { node => $self, depth => 0, patterns =>[] };
#     return undef;
#   };
#}

# Factorize this!!!!!!!!!!!!!!
#sub m {
#  goto &_subtree_list if (wantarray()); 
#  goto &_subtree_scalar;
#}

####################################################################
# Usage      :   $BLOCK->delete($ASSIGN)
#                $BLOCK->delete(2)
# Purpose    : deletes the specified child of the node
# Returns    : The deleted child
# Parameters : The object plus the index or pointer to the child to be deleted
# Throws     : If the object can't do children or has no children
# See Also   : n/a

sub delete {
  my $self = CORE::shift; # The tree object
  my $child = CORE::shift; # index or pointer

  croak "Parse::Eyapp::Node::delete error, node:\n"
        .Parse::Eyapp::Node::str($self)."\ndoes not have children" 
    unless UNIVERSAL::can($self, 'children') and ($self->children()>0);
  if (ref($child)) {
    my $i = 0;
    for ($self->children()) {
      last if $_ == $child;
      $i++;
    }
    if ($i == $self->children()) {
      warn "Parse::Eyapp::Node::delete warning: node:\n".Parse::Eyapp::Node::str($self)
           ."\ndoes not have a child like:\n"
           .Parse::Eyapp::Node::str($child)
           ."\nThe node was not deleted!\n";
      return $child;
    }
    splice(@{$self->{children}}, $i, 1);
    return $child;
  }
  my $numchildren = $self->children();
  croak "Parse::Eyapp::Node::delete error: expected an index between 0 and ".
        ($numchildren-1).". Got $child" unless ($child =~ /\d+/ and $child < $numchildren);
  splice(@{$self->{children}}, $child, 1);
  return $child;
}

####################################################################
# Usage      : $BLOCK->shift
# Purpose    : deletes the first child of the node
# Returns    : The deleted child
# Parameters : The object 
# Throws     : If the object can't do children 
# See Also   : n/a

sub shift {
  my $self = CORE::shift; # The tree object

  croak "Parse::Eyapp::Node::shift error, node:\n"
       .Parse::Eyapp::Node->str($self)."\ndoes not have children" 
    unless UNIVERSAL::can($self, 'children');

  return CORE::shift(@{$self->{children}});
}

sub unshift {
  my $self = CORE::shift; # The tree object
  my $node = CORE::shift; # node to insert

  CORE::unshift @{$self->{children}}, $node;
}

sub push {
  my $self = CORE::shift; # The tree object
  my $node = CORE::shift; # node to insert

  CORE::push @{$self->{children}}, $node;
}

sub insert_before {
  my $self = CORE::shift; # The tree object
  my $child = CORE::shift; # index or pointer
  my $node = CORE::shift; # node to insert

  croak "Parse::Eyapp::Node::insert_before error, node:\n"
        .Parse::Eyapp::Node::str($self)."\ndoes not have children" 
    unless UNIVERSAL::can($self, 'children') and ($self->children()>0);

  if (ref($child)) {
    my $i = 0;
    for ($self->children()) {
      last if $_ == $child;
      $i++;
    }
    if ($i == $self->children()) {
      warn "Parse::Eyapp::Node::insert_before warning: node:\n"
           .Parse::Eyapp::Node::str($self)
           ."\ndoes not have a child like:\n"
           .Parse::Eyapp::Node::str($child)."\nThe node was not inserted!\n";
      return $child;
    }
    splice(@{$self->{children}}, $i, 0, $node);
    return $node;
  }
  my $numchildren = $self->children();
  croak "Parse::Eyapp::Node::insert_before error: expected an index between 0 and ".
        ($numchildren-1).". Got $child" unless ($child =~ /\d+/ and $child < $numchildren);
  splice(@{$self->{children}}, $child, 0, $node);
  return $child;
}

sub insert_after {
  my $self = CORE::shift; # The tree object
  my $child = CORE::shift; # index or pointer
  my $node = CORE::shift; # node to insert

  croak "Parse::Eyapp::Node::insert_after error, node:\n"
        .Parse::Eyapp::Node::str($self)."\ndoes not have children" 
    unless UNIVERSAL::can($self, 'children') and ($self->children()>0);

  if (ref($child)) {
    my $i = 0;
    for ($self->children()) {
      last if $_ == $child;
      $i++;
    }
    if ($i == $self->children()) {
      warn "Parse::Eyapp::Node::insert_after warning: node:\n"
           .Parse::Eyapp::Node::str($self).
           "\ndoes not have a child like:\n"
           .Parse::Eyapp::Node::str($child)."\nThe node was not inserted!\n";
      return $child;
    }
    splice(@{$self->{children}}, $i+1, 0, $node);
    return $node;
  }
  my $numchildren = $self->children();
  croak "Parse::Eyapp::Node::insert_after error: expected an index between 0 and ".
        ($numchildren-1).". Got $child" unless ($child =~ /\d+/ and $child < $numchildren);
  splice(@{$self->{children}}, $child+1, 0, $node);
  return $child;
}

{ # $match closure

  my $match;

  sub clean_tree {
    $match = pop;
    croak "clean tree: a node and code reference expected" unless (ref($match) eq 'CODE') and (@_ > 0);
    $_[0]->_clean_tree();
  }

  sub _clean_tree {
    my @children;
    
    for ($_[0]->children()) {
      next if (!defined($_) or $match->($_));
      
      $_->_clean_tree();
      CORE::push @children, $_;
    }
    $_[0]->{children} = \@children; # Bad code
  }
} # $match closure

####################################################################
# Usage      : $t->str 
# Returns    : Returns a string describing the Parse::Eyapp::Node as a term
#              i.e., s.t. like: 'PROGRAM(FUNCTION(RETURN(TERMINAL,VAR(TERMINAL))))'
our @PREFIXES = qw(Parse::Eyapp::Node::);
our $INDENT = 0; # 0 = compact, 1 = indent, 2 = indent and include Types in closing parenthesis
our $STRSEP = ',';
our $DELIMITER = '[';
our $FOOTNOTE_HEADER = "\n---------------------------\n";
our $FOOTNOTE_SEP = ")\n";
our $FOOTNOTE_LEFT = '^{';
our $FOOTNOTE_RIGHT = '}';
our $LINESEP = 4;

my %match_del = (
  '[' => ']',
  '{' => '}',
  '(' => ')',
  '<' => '>'
);

my $pair;
my $footnotes = '';
my $footnote_label;

sub str {

  my @terms;

  CORE::shift unless ref($_[0]);
  for (@_) {
    $footnote_label = 0;
    $footnotes = '';
    if (defined($DELIMITER) and exists($match_del{$DELIMITER})) {
      $pair = $match_del{$DELIMITER};
    }
    else {
      $DELIMITER = $pair = '';
    }
    CORE::push @terms,  _str($_).$footnotes;
  }
  return wantarray? @terms : $terms[0];
}  

sub _str {
  my $self = CORE::shift;          # root of the subtree
  my $indent = (CORE::shift or 0); # current depth in spaces " "

  my @children = Parse::Eyapp::Node::children($self);
  my @t;

  my $fn = $footnote_label;
  if (UNIVERSAL::can($self, 'footnote')) {
    $footnotes .= $FOOTNOTE_HEADER.$footnote_label++.$FOOTNOTE_SEP.$self->footnote;
  }

  # recursively visit nodes
  for (@children) {
    CORE::push @t, Parse::Eyapp::Node::_str($_, $indent+2) if defined($_);
  }
  local $" = $STRSEP;
  my $class = type($self);
  $class =~ s/^$_// for @PREFIXES; 
  $class .= $DELIMITER.$self->info.$pair if UNIVERSAL::can($self, 'info');
  if (UNIVERSAL::can($self, 'footnote')) {
   $class .= $FOOTNOTE_LEFT.$fn.$FOOTNOTE_RIGHT;
  }

  if ($INDENT) {
    my $w = " "x$indent;
    $class = "\n$w$class";
    $class .= "(@t\n$w)" if @children;
    $class .= " # ".type($self) if ($INDENT > 1) and ($class =~ tr/\n/\n/>$LINESEP);
  }
  else {
    $class .= "(@t)" if @children;
  }
  return $class;
}

#use overload q{""} => \&stringify;

sub translation_scheme {
  my $self = CORE::shift; # root of the subtree
  my @children = $self->children();
  for (@children) {
    if (ref($_) eq 'CODE') {
      $_->($self, $self->Children);
    }
    elsif (defined($_)) {
      translation_scheme($_);
    }
  }
}

 sub type {
   my $type = ref($_[0]);

   if ($type) {
     if (defined($_[1])) {
       $type = $_[1];
       Parse::Eyapp::Driver::BeANode($type);
       bless $_[0], $type;
     }
     return $type 
   }
   return 'Parse::Eyapp::Node::STRING';
 }
1;

package Parse::Eyapp::Node::Match;
our @ISA = qw(Parse::Eyapp::Node);

# A Parse::Eyapp::Node::Match object is a reference
# to a tree of Parse::Eyapp::Nodes that has been used
# in a tree matching regexp. You can think of them
# as the equivalent of $1 $2, ... in treeregexeps

# The depth of the Parse::Eyapp::Node being referenced

sub new {
  my $class = shift;

  my $matchnode = { @_ };
  $matchnode->{children} = [];
  bless $matchnode, $class;
}

sub depth {
  my $self = shift;

  return $self->{depth};
}

# The coordinates of the Parse::Eyapp::Node being referenced
sub coord {
  my $self = shift;

  return $self->{dewey};
}


# The Parse::Eyapp::Node being referenced
sub node {
  my $self = shift;

  return $self->{node};
}

# The Parse::Eyapp::Node:Match that references
# the nearest ancestor of $self->{node} that matched
sub father {
  my $self = shift;

  return $self->{father};
}
  
# The patterns that matched with $self->{node}
# Indexes
sub patterns {
  my $self = shift;

  @{$self->{patterns}} = @_ if @_;
  return @{$self->{patterns}};
}
  
# The original list of patterns that produced this match
sub family {
  my $self = shift;

  @{$self->{family}} = @_ if @_;
  return @{$self->{family}};
}
  
# The names of the patterns that matched
sub names {
  my $self = shift;

  my @indexes = $self->patterns;
  my @family = $self->family;

  return map { $_->{NAME} or "Unknown" } @family[@indexes];
}
  
sub info {
  my $self = shift;

  my $node = $self->node;
  my @names = $self->names;
  my $nodeinfo;
  if (UNIVERSAL::can($node, 'info')) {
    $nodeinfo = ":".$node->info;
  }
  else {
    $nodeinfo = "";
  }
  return "[".ref($self->node).":".$self->depth.":@names$nodeinfo]"
}

1;



} ###########End of include /Library/Perl/5.8.8/Parse/Eyapp/Node.pm file

{ ###########Included /Library/Perl/5.8.8/Parse/Eyapp/YATW.pm file
# (c) Parse::Eyapp Copyright 2006 Casiano Rodriguez-Leon, all rights reserved.
package Parse::Eyapp::YATW;
use strict;
use warnings;
use Carp;
use Data::Dumper;
use List::Util qw(first);
use List::MoreUtils qw(lastval);
#use Parse::Eyapp::Base qw( valid_keys invalid_keys );

sub valid_keys {
  my %valid_args = @_;

  my @valid_args = keys(%valid_args); 
  local $" = ", "; 
  return "@valid_args" 
}

sub invalid_keys {
  my $valid_args = shift;
  my $args = shift;

  return (first { !exists($valid_args->{$_}) } keys(%$args));
}


our $VERSION = $Parse::Eyapp::Driver::VERSION;

our $FILENAME=__FILE__;

# TODO: Check args. Typical args:
# 'CHANGES' => 0,
# 'PATTERN' => sub { "DUMMY" },
# 'NAME' => 'fold',
# 'PATTERN_ARGS' => [],
# 'PENDING_TASKS' => {},
# 'NODE' => []

my %_new_yatw = (
  PATTERN => 'CODE',
  NAME => 'STRING',
);

my $validkeys = valid_keys(%_new_yatw); 

sub new {
  my $class = shift;
  my %args = @_;

  croak "Error. Expected a code reference when building a tree walker. " unless (ref($args{PATTERN}) eq 'CODE');
  if (defined($a = invalid_keys(\%_new_yatw, \%args))) {
    croak("Parse::Eyapp::YATW::new Error!: unknown argument $a. Valid arguments are: $validkeys")
  }


  # obsolete, I have to delete this
  #$args{PATTERN_ARGS} = [] unless (ref($args{PATTERN_ARGS}) eq 'ARRAY'); 

  # Internal fields

  # Tell us if the node has changed after the visit
  $args{CHANGES} = 0;
  
  # PENDING_TASKS is a queue storing the tasks waiting for a "safe time/node" to do them 
  # Usually that time occurs when visiting the father of the node who generated the job 
  # (when asap criteria is applied).
  # Keys are node references. Values are array references. Each entry defines:
  #  [ the task kind, the node where to do the job, and info related to the particular job ]
  # Example: @{$self->{PENDING_TASKS}{$father}}, ['insert_before', $node, ${$self->{NODE}}[0] ];
  $args{PENDING_TASKS} = {};

  # NODE is a stack storing the ancestor of the node being visited
  # Example: my $ancestor = ${$self->{NODE}}[$k]; when k=1 is the father, k=2 the grandfather, etc.
  # Example: CORE::unshift @{$self->{NODE}}, $_[0]; Finished the visit so take it out
  $args{NODE} = [];

  bless \%args, $class;
}

sub buildpatterns {
  my $class = shift;
  
  my @family;
  while (my ($n, $p) = splice(@_, 0,2)) {
    push @family, Parse::Eyapp::YATW->new(NAME => $n, PATTERN => $p);
  }
  return wantarray? @family : $family[0];
}

####################################################################
# Usage      : @r = $b{$_}->m($t)
#              See Simple4.eyp and m_yatw.pl in the examples directory
# Returns    : Returns an array of nodes matching the treeregexp
#              The set of nodes is a Parse::Eyapp::Node::Match tree 
#              showing the relation between the matches
# Parameters : The tree (and the object of course)
# depth is no longer used: eliminate
sub m {
  my $p = shift(); # pattern YATW object
  my $t = shift;   # tree
  my $pattern = $p->{PATTERN}; # CODE ref

  # References to the found nodes are stored in @stack
  my @stack = ( Parse::Eyapp::Node::Match->new(node=>$t, depth=>0, dewey => "") ); 
  my @results;
  do {
    my $n = CORE::shift(@stack);
    my %n = %$n;

    my $dewey = $n->{dewey};
    my $d = $n->{depth};
    if ($pattern->($n{node})) {
      $n->{family} = [ $p ];
      $n->{patterns} = [ 0 ];

      # Is at this time that I have to compute the father
      my $f = lastval { $dewey =~ m{^$_->{dewey}}} @results;
      $n->{father} = $f;
      # ... and children
      unshift @{$f->{children}}, $n if defined($f);
      push @results, $n;
    }
    my $k = 0;
    CORE::unshift @stack, 
       map { 
              local $a;
              $a = Parse::Eyapp::Node::Match->new(node=>$_, depth=>$d+1, dewey=>"$dewey.$k" );
              $k++;
              $a;
           } $n{node}->children();
  } while (@stack);

  return wantarray? @results : $results[0];
}

######################### getter-setter for YATW objects ###########################

sub pattern {
  my $self = shift;
  $self->{PATTERN} = shift if (@_);
  return $self->{PATTERN};
}

sub name {
  my $self = shift;
  $self->{NAME} = shift if (@_);
  return $self->{NAME};
}

#sub pattern_args {
#  my $self = shift;
#
#  $self->{PATTERN_ARGS} = @_ if @_;
#  return @{$self->{PATTERN_ARGS}};
#}

########################## PENDING TASKS management ################################

# Purpose    : Deletes the node that matched from the list of children of its father. 
sub delete {
  my $self = shift;

  bless $self->{NODE}[0], 'Parse::Eyapp::Node::DELETE';
}
  
sub make_delete_effective {
  my $self = shift;
  my $node = shift;

  my $i = -1+$node->children;
  while ($i >= 0) {
    if (UNIVERSAL::isa($node->child($i), 'Parse::Eyapp::Node::DELETE')) {
      $self->{CHANGES}++ if splice @{$node->{children}}, $i, 1;
    }
    $i--;
  }
}

####################################################################
# Usage      :    my $b = Parse::Eyapp::Node->new( 'NUM(TERMINAL)', sub { $_[1]->{attr} = 4 });
#                 $yatw_pattern->unshift($b); 
# Parameters : YATW object, node to insert, 
#              ancestor offset: 0 = root of the tree that matched, 1 = father, 2 = granfather, etc.

sub unshift {
  my ($self, $node, $k) = @_;
  $k = 1 unless defined($k); # father by default

  my $ancestor = ${$self->{NODE}}[$k];
  croak "unshift: does not exist ancestor $k of node ".Dumper(${$self->{NODE}}[0]) unless defined($ancestor);

  # Stringification of $ancestor. Hope it works
                                            # operation, node to insert, 
  push @{$self->{PENDING_TASKS}{$ancestor}}, ['unshift', $node ];
}

sub insert_before {
  my ($self, $node) = @_;

  my $father = ${$self->{NODE}}[1];
  croak "insert_before: does not exist father of node ".Dumper(${$self->{NODE}}[0]) unless defined($father);

                                           # operation, node to insert, before this node 
  push @{$self->{PENDING_TASKS}{$father}}, ['insert_before', $node, ${$self->{NODE}}[0] ];
}

sub _delayed_insert_before {
  my ($father, $node, $before) = @_;

  my $i = 0;
  for ($father->children()) {
    last if ($_ == $before);
    $i++;
  }
  splice @{$father->{children}}, $i, 0, $node;
}

sub do_pending_tasks {
  my $self = shift;
  my $node = shift;

  my $mytasks = $self->{PENDING_TASKS}{$node};
  while ($mytasks and (my $job = shift @{$mytasks})) {
    my @args = @$job;
    my $task = shift @args;

    # change this for a jump table
    if ($task eq 'unshift') {
      CORE::unshift(@{$node->{children}}, @args);
      $self->{CHANGES}++;
    }
    elsif ($task eq 'insert_before') {
      _delayed_insert_before($node, @args);
      $self->{CHANGES}++;
    }
  }
}

####################################################################
# Parameters : pattern, node, father of the node, index of the child in the children array
# YATW object. Probably too many 
sub s {
  my $self = shift;
  my $node = $_[0] or croak("Error. Method __PACKAGE__::s requires a node");
  CORE::unshift @{$self->{NODE}}, $_[0];
  # father is $_[1]
  my $index = $_[2];

  # If is not a reference or can't children then simply check the matching and leave
  if (!ref($node) or !UNIVERSAL::can($node, "children"))  {
                                         
    $self->{CHANGES}++ if $self->pattern->(
      $_[0],  # Node being visited  
      $_[1],  # Father of this node
      $index, # Index of this node in @Father->children
      $self,  # The YATW pattern object   
    );
    return;
  };
  
  # Else, is not a leaf and is a regular Parse::Eyapp::Node
  # Recursively transform subtrees
  my $i = 0;
  for (@{$node->{children}}) {
    $self->s($_, $_[0], $i);
    $i++;
  }
  
  my $number_of_changes = $self->{CHANGES};
  # Now is safe to delete children nodes that are no longer needed
  $self->make_delete_effective($node);

  # Safely do pending jobs for this node
  $self->do_pending_tasks($node);

  #node , father, childindex, and ... 
  #Change YATW object to be the  first argument?
  if ($self->pattern->($_[0], $_[1], $index, $self)) {
    $self->{CHANGES}++;
  }
  shift @{$self->{NODE}};
}

1;


} ###########End of include /Library/Perl/5.8.8/Parse/Eyapp/YATW.pm file



#line 1984 lib/RDF/Query/Parser/SPARQL.pm

my $warnmessage =<< "EOFWARN";
Warning!: Did you changed the \@RDF::Query::Parser::SPARQL::ISA variable inside the header section of the eyapp program?
EOFWARN

sub new {
        my($class)=shift;
        ref($class)
    and $class=ref($class);

    warn $warnmessage unless __PACKAGE__->isa('Parse::Eyapp::Driver'); 
    my($self)=$class->SUPER::new( yyversion => '1.082',
                                  yyGRAMMAR  =>
[
  [ _SUPERSTART => '$start', [ 'Query', '$end' ], 0 ],
  [ Query_1 => 'Query', [ 'Prologue', 'SelectQuery' ], 0 ],
  [ Query_2 => 'Query', [ 'Prologue', 'ConstructQuery' ], 0 ],
  [ Query_3 => 'Query', [ 'Prologue', 'DescribeQuery' ], 0 ],
  [ Query_4 => 'Query', [ 'Prologue', 'AskQuery' ], 0 ],
  [ _OPTIONAL => 'OPTIONAL-1', [ 'BaseDecl' ], 0 ],
  [ _OPTIONAL => 'OPTIONAL-1', [  ], 0 ],
  [ _STAR_LIST_2 => 'STAR-2', [ 'STAR-2', 'PrefixDecl' ], 0 ],
  [ _STAR_LIST_2 => 'STAR-2', [  ], 0 ],
  [ Prologue_9 => 'Prologue', [ 'OPTIONAL-1', 'STAR-2' ], 0 ],
  [ BaseDecl_10 => 'BaseDecl', [ 'BASE', 'IRI_REF' ], 0 ],
  [ PrefixDecl_11 => 'PrefixDecl', [ 'PREFIX', 'PNAME_NS', 'IRI_REF' ], 0 ],
  [ _OPTIONAL => 'OPTIONAL-3', [ 'SelectModifier' ], 0 ],
  [ _OPTIONAL => 'OPTIONAL-3', [  ], 0 ],
  [ _STAR_LIST_4 => 'STAR-4', [ 'STAR-4', 'DatasetClause' ], 0 ],
  [ _STAR_LIST_4 => 'STAR-4', [  ], 0 ],
  [ SelectQuery_16 => 'SelectQuery', [ 'SELECT', 'OPTIONAL-3', 'SelectVars', 'STAR-4', 'WhereClause', 'SolutionModifier' ], 0 ],
  [ SelectModifier_17 => 'SelectModifier', [ 'DISTINCT' ], 0 ],
  [ SelectModifier_18 => 'SelectModifier', [ 'REDUCED' ], 0 ],
  [ _PLUS_LIST => 'PLUS-5', [ 'PLUS-5', 'Var' ], 0 ],
  [ _PLUS_LIST => 'PLUS-5', [ 'Var' ], 0 ],
  [ SelectVars_21 => 'SelectVars', [ 'PLUS-5' ], 0 ],
  [ SelectVars_22 => 'SelectVars', [ '*' ], 0 ],
  [ _STAR_LIST_6 => 'STAR-6', [ 'STAR-6', 'DatasetClause' ], 0 ],
  [ _STAR_LIST_6 => 'STAR-6', [  ], 0 ],
  [ ConstructQuery_25 => 'ConstructQuery', [ 'CONSTRUCT', 'ConstructTemplate', 'STAR-6', 'WhereClause', 'SolutionModifier' ], 0 ],
  [ _STAR_LIST_7 => 'STAR-7', [ 'STAR-7', 'DatasetClause' ], 0 ],
  [ _STAR_LIST_7 => 'STAR-7', [  ], 0 ],
  [ _OPTIONAL => 'OPTIONAL-8', [ 'WhereClause' ], 0 ],
  [ _OPTIONAL => 'OPTIONAL-8', [  ], 0 ],
  [ DescribeQuery_30 => 'DescribeQuery', [ 'DESCRIBE', 'DescribeVars', 'STAR-7', 'OPTIONAL-8', 'SolutionModifier' ], 0 ],
  [ _PLUS_LIST => 'PLUS-9', [ 'PLUS-9', 'VarOrIRIref' ], 0 ],
  [ _PLUS_LIST => 'PLUS-9', [ 'VarOrIRIref' ], 0 ],
  [ DescribeVars_33 => 'DescribeVars', [ 'PLUS-9' ], 0 ],
  [ DescribeVars_34 => 'DescribeVars', [ '*' ], 0 ],
  [ _STAR_LIST_10 => 'STAR-10', [ 'STAR-10', 'DatasetClause' ], 0 ],
  [ _STAR_LIST_10 => 'STAR-10', [  ], 0 ],
  [ AskQuery_37 => 'AskQuery', [ 'ASK', 'STAR-10', 'WhereClause' ], 0 ],
  [ DatasetClause_38 => 'DatasetClause', [ 'FROM', 'DefaultGraphClause' ], 0 ],
  [ DatasetClause_39 => 'DatasetClause', [ 'FROM NAMED', 'NamedGraphClause' ], 0 ],
  [ DefaultGraphClause_40 => 'DefaultGraphClause', [ 'SourceSelector' ], 0 ],
  [ NamedGraphClause_41 => 'NamedGraphClause', [ 'SourceSelector' ], 0 ],
  [ SourceSelector_42 => 'SourceSelector', [ 'IRIref' ], 0 ],
  [ _OPTIONAL => 'OPTIONAL-11', [ 'WHERE' ], 0 ],
  [ _OPTIONAL => 'OPTIONAL-11', [  ], 0 ],
  [ WhereClause_45 => 'WhereClause', [ 'OPTIONAL-11', 'GroupGraphPattern' ], 0 ],
  [ _OPTIONAL => 'OPTIONAL-12', [ 'OrderClause' ], 0 ],
  [ _OPTIONAL => 'OPTIONAL-12', [  ], 0 ],
  [ _OPTIONAL => 'OPTIONAL-13', [ 'LimitOffsetClauses' ], 0 ],
  [ _OPTIONAL => 'OPTIONAL-13', [  ], 0 ],
  [ SolutionModifier_50 => 'SolutionModifier', [ 'OPTIONAL-12', 'OPTIONAL-13' ], 0 ],
  [ _OPTIONAL => 'OPTIONAL-14', [ 'OffsetClause' ], 0 ],
  [ _OPTIONAL => 'OPTIONAL-14', [  ], 0 ],
  [ _OPTIONAL => 'OPTIONAL-15', [ 'LimitClause' ], 0 ],
  [ _OPTIONAL => 'OPTIONAL-15', [  ], 0 ],
  [ LimitOffsetClauses_55 => 'LimitOffsetClauses', [ 'LimitClause', 'OPTIONAL-14' ], 0 ],
  [ LimitOffsetClauses_56 => 'LimitOffsetClauses', [ 'OffsetClause', 'OPTIONAL-15' ], 0 ],
  [ _PLUS_LIST => 'PLUS-16', [ 'PLUS-16', 'OrderCondition' ], 0 ],
  [ _PLUS_LIST => 'PLUS-16', [ 'OrderCondition' ], 0 ],
  [ OrderClause_59 => 'OrderClause', [ 'ORDER BY', 'PLUS-16' ], 0 ],
  [ OrderCondition_60 => 'OrderCondition', [ 'OrderDirection', 'BrackettedExpression' ], 0 ],
  [ OrderCondition_61 => 'OrderCondition', [ 'Constraint' ], 0 ],
  [ OrderCondition_62 => 'OrderCondition', [ 'Var' ], 0 ],
  [ OrderDirection_63 => 'OrderDirection', [ 'ASC' ], 0 ],
  [ OrderDirection_64 => 'OrderDirection', [ 'DESC' ], 0 ],
  [ LimitClause_65 => 'LimitClause', [ 'LIMIT', 'INTEGER' ], 0 ],
  [ OffsetClause_66 => 'OffsetClause', [ 'OFFSET', 'INTEGER' ], 0 ],
  [ _OPTIONAL => 'OPTIONAL-17', [ 'TriplesBlock' ], 0 ],
  [ _OPTIONAL => 'OPTIONAL-17', [  ], 0 ],
  [ _OPTIONAL => 'OPTIONAL-18', [ '.' ], 0 ],
  [ _OPTIONAL => 'OPTIONAL-18', [  ], 0 ],
  [ _OPTIONAL => 'OPTIONAL-19', [ 'TriplesBlock' ], 0 ],
  [ _OPTIONAL => 'OPTIONAL-19', [  ], 0 ],
  [ _PAREN => 'PAREN-20', [ 'GGPAtom', 'OPTIONAL-18', 'OPTIONAL-19' ], 0 ],
  [ _STAR_LIST_21 => 'STAR-21', [ 'STAR-21', 'PAREN-20' ], 0 ],
  [ _STAR_LIST_21 => 'STAR-21', [  ], 0 ],
  [ GroupGraphPattern_76 => 'GroupGraphPattern', [ '{', 'OPTIONAL-17', 'STAR-21', '}' ], 0 ],
  [ GGPAtom_77 => 'GGPAtom', [ 'GraphPatternNotTriples' ], 0 ],
  [ GGPAtom_78 => 'GGPAtom', [ 'Filter' ], 0 ],
  [ _OPTIONAL => 'OPTIONAL-22', [ 'TriplesBlock' ], 0 ],
  [ _OPTIONAL => 'OPTIONAL-22', [  ], 0 ],
  [ _PAREN => 'PAREN-23', [ '.', 'OPTIONAL-22' ], 0 ],
  [ _OPTIONAL => 'OPTIONAL-24', [ 'PAREN-23' ], 0 ],
  [ _OPTIONAL => 'OPTIONAL-24', [  ], 0 ],
  [ TriplesBlock_84 => 'TriplesBlock', [ 'TriplesSameSubject', 'OPTIONAL-24' ], 0 ],
  [ GraphPatternNotTriples_85 => 'GraphPatternNotTriples', [ 'OptionalGraphPattern' ], 0 ],
  [ GraphPatternNotTriples_86 => 'GraphPatternNotTriples', [ 'GroupOrUnionGraphPattern' ], 0 ],
  [ GraphPatternNotTriples_87 => 'GraphPatternNotTriples', [ 'GraphGraphPattern' ], 0 ],
  [ OptionalGraphPattern_88 => 'OptionalGraphPattern', [ 'OPTIONAL', 'GroupGraphPattern' ], 0 ],
  [ GraphGraphPattern_89 => 'GraphGraphPattern', [ 'GRAPH', 'VarOrIRIref', 'GroupGraphPattern' ], 0 ],
  [ _PAREN => 'PAREN-25', [ 'UNION', 'GroupGraphPattern' ], 0 ],
  [ _STAR_LIST_26 => 'STAR-26', [ 'STAR-26', 'PAREN-25' ], 0 ],
  [ _STAR_LIST_26 => 'STAR-26', [  ], 0 ],
  [ GroupOrUnionGraphPattern_93 => 'GroupOrUnionGraphPattern', [ 'GroupGraphPattern', 'STAR-26' ], 0 ],
  [ Filter_94 => 'Filter', [ 'FILTER', 'Constraint' ], 0 ],
  [ Constraint_95 => 'Constraint', [ 'BrackettedExpression' ], 0 ],
  [ Constraint_96 => 'Constraint', [ 'BuiltInCall' ], 0 ],
  [ Constraint_97 => 'Constraint', [ 'FunctionCall' ], 0 ],
  [ FunctionCall_98 => 'FunctionCall', [ 'IRIref', 'ArgList' ], 0 ],
  [ _PAREN => 'PAREN-27', [ ',', 'Expression' ], 0 ],
  [ _STAR_LIST_28 => 'STAR-28', [ 'STAR-28', 'PAREN-27' ], 0 ],
  [ _STAR_LIST_28 => 'STAR-28', [  ], 0 ],
  [ ArgList_102 => 'ArgList', [ '(', 'Expression', 'STAR-28', ')' ], 0 ],
  [ ArgList_103 => 'ArgList', [ 'NIL' ], 0 ],
  [ _OPTIONAL => 'OPTIONAL-29', [ 'ConstructTriples' ], 0 ],
  [ _OPTIONAL => 'OPTIONAL-29', [  ], 0 ],
  [ ConstructTemplate_106 => 'ConstructTemplate', [ '{', 'OPTIONAL-29', '}' ], 0 ],
  [ _OPTIONAL => 'OPTIONAL-30', [ 'ConstructTriples' ], 0 ],
  [ _OPTIONAL => 'OPTIONAL-30', [  ], 0 ],
  [ _PAREN => 'PAREN-31', [ '.', 'OPTIONAL-30' ], 0 ],
  [ _OPTIONAL => 'OPTIONAL-32', [ 'PAREN-31' ], 0 ],
  [ _OPTIONAL => 'OPTIONAL-32', [  ], 0 ],
  [ ConstructTriples_112 => 'ConstructTriples', [ 'TriplesSameSubject', 'OPTIONAL-32' ], 0 ],
  [ TriplesSameSubject_113 => 'TriplesSameSubject', [ 'VarOrTerm', 'PropertyListNotEmpty' ], 0 ],
  [ TriplesSameSubject_114 => 'TriplesSameSubject', [ 'TriplesNode', 'PropertyList' ], 0 ],
  [ _PAREN => 'PAREN-33', [ 'Verb', 'ObjectList' ], 0 ],
  [ _OPTIONAL => 'OPTIONAL-34', [ 'PAREN-33' ], 0 ],
  [ _OPTIONAL => 'OPTIONAL-34', [  ], 0 ],
  [ _PAREN => 'PAREN-35', [ ';', 'OPTIONAL-34' ], 0 ],
  [ _STAR_LIST_36 => 'STAR-36', [ 'STAR-36', 'PAREN-35' ], 0 ],
  [ _STAR_LIST_36 => 'STAR-36', [  ], 0 ],
  [ PropertyListNotEmpty_121 => 'PropertyListNotEmpty', [ 'Verb', 'ObjectList', 'STAR-36' ], 0 ],
  [ _OPTIONAL => 'OPTIONAL-37', [ 'PropertyListNotEmpty' ], 0 ],
  [ _OPTIONAL => 'OPTIONAL-37', [  ], 0 ],
  [ PropertyList_124 => 'PropertyList', [ 'OPTIONAL-37' ], 0 ],
  [ _PAREN => 'PAREN-38', [ ',', 'Object' ], 0 ],
  [ _STAR_LIST_39 => 'STAR-39', [ 'STAR-39', 'PAREN-38' ], 0 ],
  [ _STAR_LIST_39 => 'STAR-39', [  ], 0 ],
  [ ObjectList_128 => 'ObjectList', [ 'Object', 'STAR-39' ], 0 ],
  [ Object_129 => 'Object', [ 'GraphNode' ], 0 ],
  [ Verb_130 => 'Verb', [ 'VarOrIRIref' ], 0 ],
  [ Verb_131 => 'Verb', [ 'a' ], 0 ],
  [ TriplesNode_132 => 'TriplesNode', [ 'Collection' ], 0 ],
  [ TriplesNode_133 => 'TriplesNode', [ 'BlankNodePropertyList' ], 0 ],
  [ BlankNodePropertyList_134 => 'BlankNodePropertyList', [ '[', 'PropertyListNotEmpty', ']' ], 0 ],
  [ _PLUS_LIST => 'PLUS-40', [ 'PLUS-40', 'GraphNode' ], 0 ],
  [ _PLUS_LIST => 'PLUS-40', [ 'GraphNode' ], 0 ],
  [ Collection_137 => 'Collection', [ '(', 'PLUS-40', ')' ], 0 ],
  [ GraphNode_138 => 'GraphNode', [ 'VarOrTerm' ], 0 ],
  [ GraphNode_139 => 'GraphNode', [ 'TriplesNode' ], 0 ],
  [ VarOrTerm_140 => 'VarOrTerm', [ 'Var' ], 0 ],
  [ VarOrTerm_141 => 'VarOrTerm', [ 'GraphTerm' ], 0 ],
  [ VarOrIRIref_142 => 'VarOrIRIref', [ 'Var' ], 0 ],
  [ VarOrIRIref_143 => 'VarOrIRIref', [ 'IRIref' ], 0 ],
  [ Var_144 => 'Var', [ 'VAR1' ], 0 ],
  [ Var_145 => 'Var', [ 'VAR2' ], 0 ],
  [ GraphTerm_146 => 'GraphTerm', [ 'IRIref' ], 0 ],
  [ GraphTerm_147 => 'GraphTerm', [ 'RDFLiteral' ], 0 ],
  [ GraphTerm_148 => 'GraphTerm', [ 'NumericLiteral' ], 0 ],
  [ GraphTerm_149 => 'GraphTerm', [ 'BooleanLiteral' ], 0 ],
  [ GraphTerm_150 => 'GraphTerm', [ 'BlankNode' ], 0 ],
  [ GraphTerm_151 => 'GraphTerm', [ 'NIL' ], 0 ],
  [ Expression_152 => 'Expression', [ 'ConditionalOrExpression' ], 0 ],
  [ _PAREN => 'PAREN-41', [ '||', 'ConditionalAndExpression' ], 0 ],
  [ _STAR_LIST_42 => 'STAR-42', [ 'STAR-42', 'PAREN-41' ], 0 ],
  [ _STAR_LIST_42 => 'STAR-42', [  ], 0 ],
  [ ConditionalOrExpression_156 => 'ConditionalOrExpression', [ 'ConditionalAndExpression', 'STAR-42' ], 0 ],
  [ _PAREN => 'PAREN-43', [ '&&', 'ValueLogical' ], 0 ],
  [ _STAR_LIST_44 => 'STAR-44', [ 'STAR-44', 'PAREN-43' ], 0 ],
  [ _STAR_LIST_44 => 'STAR-44', [  ], 0 ],
  [ ConditionalAndExpression_160 => 'ConditionalAndExpression', [ 'ValueLogical', 'STAR-44' ], 0 ],
  [ ValueLogical_161 => 'ValueLogical', [ 'RelationalExpression' ], 0 ],
  [ _OPTIONAL => 'OPTIONAL-45', [ 'RelationalExpressionExtra' ], 0 ],
  [ _OPTIONAL => 'OPTIONAL-45', [  ], 0 ],
  [ RelationalExpression_164 => 'RelationalExpression', [ 'NumericExpression', 'OPTIONAL-45' ], 0 ],
  [ RelationalExpressionExtra_165 => 'RelationalExpressionExtra', [ '=', 'NumericExpression' ], 0 ],
  [ RelationalExpressionExtra_166 => 'RelationalExpressionExtra', [ '!=', 'NumericExpression' ], 0 ],
  [ RelationalExpressionExtra_167 => 'RelationalExpressionExtra', [ '<', 'NumericExpression' ], 0 ],
  [ RelationalExpressionExtra_168 => 'RelationalExpressionExtra', [ '>', 'NumericExpression' ], 0 ],
  [ RelationalExpressionExtra_169 => 'RelationalExpressionExtra', [ '<=', 'NumericExpression' ], 0 ],
  [ RelationalExpressionExtra_170 => 'RelationalExpressionExtra', [ '>=', 'NumericExpression' ], 0 ],
  [ NumericExpression_171 => 'NumericExpression', [ 'AdditiveExpression' ], 0 ],
  [ _STAR_LIST_46 => 'STAR-46', [ 'STAR-46', 'AdditiveExpressionExtra' ], 0 ],
  [ _STAR_LIST_46 => 'STAR-46', [  ], 0 ],
  [ AdditiveExpression_174 => 'AdditiveExpression', [ 'MultiplicativeExpression', 'STAR-46' ], 0 ],
  [ AdditiveExpressionExtra_175 => 'AdditiveExpressionExtra', [ '+', 'MultiplicativeExpression' ], 0 ],
  [ AdditiveExpressionExtra_176 => 'AdditiveExpressionExtra', [ '-', 'MultiplicativeExpression' ], 0 ],
  [ AdditiveExpressionExtra_177 => 'AdditiveExpressionExtra', [ 'NumericLiteralPositive' ], 0 ],
  [ AdditiveExpressionExtra_178 => 'AdditiveExpressionExtra', [ 'NumericLiteralNegative' ], 0 ],
  [ _STAR_LIST_47 => 'STAR-47', [ 'STAR-47', 'MultiplicativeExpressionExtra' ], 0 ],
  [ _STAR_LIST_47 => 'STAR-47', [  ], 0 ],
  [ MultiplicativeExpression_181 => 'MultiplicativeExpression', [ 'UnaryExpression', 'STAR-47' ], 0 ],
  [ MultiplicativeExpressionExtra_182 => 'MultiplicativeExpressionExtra', [ '*', 'UnaryExpression' ], 0 ],
  [ MultiplicativeExpressionExtra_183 => 'MultiplicativeExpressionExtra', [ '/', 'UnaryExpression' ], 0 ],
  [ UnaryExpression_184 => 'UnaryExpression', [ '!', 'PrimaryExpression' ], 0 ],
  [ UnaryExpression_185 => 'UnaryExpression', [ '+', 'PrimaryExpression' ], 0 ],
  [ UnaryExpression_186 => 'UnaryExpression', [ '-', 'PrimaryExpression' ], 0 ],
  [ UnaryExpression_187 => 'UnaryExpression', [ 'PrimaryExpression' ], 0 ],
  [ PrimaryExpression_188 => 'PrimaryExpression', [ 'BrackettedExpression' ], 0 ],
  [ PrimaryExpression_189 => 'PrimaryExpression', [ 'BuiltInCall' ], 0 ],
  [ PrimaryExpression_190 => 'PrimaryExpression', [ 'IRIrefOrFunction' ], 0 ],
  [ PrimaryExpression_191 => 'PrimaryExpression', [ 'RDFLiteral' ], 0 ],
  [ PrimaryExpression_192 => 'PrimaryExpression', [ 'NumericLiteral' ], 0 ],
  [ PrimaryExpression_193 => 'PrimaryExpression', [ 'BooleanLiteral' ], 0 ],
  [ PrimaryExpression_194 => 'PrimaryExpression', [ 'Var' ], 0 ],
  [ BrackettedExpression_195 => 'BrackettedExpression', [ '(', 'Expression', ')' ], 0 ],
  [ BuiltInCall_196 => 'BuiltInCall', [ 'STR', '(', 'Expression', ')' ], 0 ],
  [ BuiltInCall_197 => 'BuiltInCall', [ 'LANG', '(', 'Expression', ')' ], 0 ],
  [ BuiltInCall_198 => 'BuiltInCall', [ 'LANGMATCHES', '(', 'Expression', ',', 'Expression', ')' ], 0 ],
  [ BuiltInCall_199 => 'BuiltInCall', [ 'DATATYPE', '(', 'Expression', ')' ], 0 ],
  [ BuiltInCall_200 => 'BuiltInCall', [ 'BOUND', '(', 'Var', ')' ], 0 ],
  [ BuiltInCall_201 => 'BuiltInCall', [ 'SAMETERM', '(', 'Expression', ',', 'Expression', ')' ], 0 ],
  [ BuiltInCall_202 => 'BuiltInCall', [ 'ISIRI', '(', 'Expression', ')' ], 0 ],
  [ BuiltInCall_203 => 'BuiltInCall', [ 'ISURI', '(', 'Expression', ')' ], 0 ],
  [ BuiltInCall_204 => 'BuiltInCall', [ 'ISBLANK', '(', 'Expression', ')' ], 0 ],
  [ BuiltInCall_205 => 'BuiltInCall', [ 'ISLITERAL', '(', 'Expression', ')' ], 0 ],
  [ BuiltInCall_206 => 'BuiltInCall', [ 'RegexExpression' ], 0 ],
  [ _PAREN => 'PAREN-48', [ ',', 'Expression' ], 0 ],
  [ _OPTIONAL => 'OPTIONAL-49', [ 'PAREN-48' ], 0 ],
  [ _OPTIONAL => 'OPTIONAL-49', [  ], 0 ],
  [ RegexExpression_210 => 'RegexExpression', [ 'REGEX', '(', 'Expression', ',', 'Expression', 'OPTIONAL-49', ')' ], 0 ],
  [ _OPTIONAL => 'OPTIONAL-50', [ 'ArgList' ], 0 ],
  [ _OPTIONAL => 'OPTIONAL-50', [  ], 0 ],
  [ IRIrefOrFunction_213 => 'IRIrefOrFunction', [ 'IRIref', 'OPTIONAL-50' ], 0 ],
  [ _OPTIONAL => 'OPTIONAL-51', [ 'LiteralExtra' ], 0 ],
  [ _OPTIONAL => 'OPTIONAL-51', [  ], 0 ],
  [ RDFLiteral_216 => 'RDFLiteral', [ 'STRING', 'OPTIONAL-51' ], 0 ],
  [ LiteralExtra_217 => 'LiteralExtra', [ 'LANGTAG' ], 0 ],
  [ LiteralExtra_218 => 'LiteralExtra', [ '^^', 'IRIref' ], 0 ],
  [ NumericLiteral_219 => 'NumericLiteral', [ 'NumericLiteralUnsigned' ], 0 ],
  [ NumericLiteral_220 => 'NumericLiteral', [ 'NumericLiteralPositive' ], 0 ],
  [ NumericLiteral_221 => 'NumericLiteral', [ 'NumericLiteralNegative' ], 0 ],
  [ NumericLiteralUnsigned_222 => 'NumericLiteralUnsigned', [ 'INTEGER' ], 0 ],
  [ NumericLiteralUnsigned_223 => 'NumericLiteralUnsigned', [ 'DECIMAL' ], 0 ],
  [ NumericLiteralUnsigned_224 => 'NumericLiteralUnsigned', [ 'DOUBLE' ], 0 ],
  [ NumericLiteralPositive_225 => 'NumericLiteralPositive', [ 'INTEGER_POSITIVE' ], 0 ],
  [ NumericLiteralPositive_226 => 'NumericLiteralPositive', [ 'DECIMAL_POSITIVE' ], 0 ],
  [ NumericLiteralPositive_227 => 'NumericLiteralPositive', [ 'DOUBLE_POSITIVE' ], 0 ],
  [ NumericLiteralNegative_228 => 'NumericLiteralNegative', [ 'INTEGER_NEGATIVE' ], 0 ],
  [ NumericLiteralNegative_229 => 'NumericLiteralNegative', [ 'DECIMAL_NEGATIVE' ], 0 ],
  [ NumericLiteralNegative_230 => 'NumericLiteralNegative', [ 'DOUBLE_NEGATIVE' ], 0 ],
  [ BooleanLiteral_231 => 'BooleanLiteral', [ 'TRUE' ], 0 ],
  [ BooleanLiteral_232 => 'BooleanLiteral', [ 'FALSE' ], 0 ],
  [ IRIref_233 => 'IRIref', [ 'IRI_REF' ], 0 ],
  [ IRIref_234 => 'IRIref', [ 'PrefixedName' ], 0 ],
  [ PrefixedName_235 => 'PrefixedName', [ 'PNAME_LN' ], 0 ],
  [ PrefixedName_236 => 'PrefixedName', [ 'PNAME_NS' ], 0 ],
  [ BlankNode_237 => 'BlankNode', [ 'BLANK_NODE_LABEL' ], 0 ],
  [ BlankNode_238 => 'BlankNode', [ 'ANON' ], 0 ],
  [ IRI_REF_239 => 'IRI_REF', [ 'URI' ], 0 ],
  [ PNAME_NS_240 => 'PNAME_NS', [ 'NAME', ':' ], 0 ],
  [ PNAME_NS_241 => 'PNAME_NS', [ ':' ], 0 ],
  [ PNAME_LN_242 => 'PNAME_LN', [ 'PNAME_NS', 'PN_LOCAL' ], 0 ],
  [ BLANK_NODE_LABEL_243 => 'BLANK_NODE_LABEL', [ '_:', 'PN_LOCAL' ], 0 ],
  [ PN_LOCAL_244 => 'PN_LOCAL', [ 'VARNAME', 'PN_LOCAL_EXTRA' ], 0 ],
  [ PN_LOCAL_245 => 'PN_LOCAL', [ 'INTEGER', 'VARNAME', 'PN_LOCAL_EXTRA' ], 0 ],
  [ PN_LOCAL_246 => 'PN_LOCAL', [ 'INTEGER', 'VARNAME' ], 0 ],
  [ PN_LOCAL_247 => 'PN_LOCAL', [ 'VARNAME' ], 0 ],
  [ PN_LOCAL_EXTRA_248 => 'PN_LOCAL_EXTRA', [ 'INTEGER_NO_WS' ], 0 ],
  [ PN_LOCAL_EXTRA_249 => 'PN_LOCAL_EXTRA', [ '-', 'NAME' ], 0 ],
  [ PN_LOCAL_EXTRA_250 => 'PN_LOCAL_EXTRA', [ '_', 'NAME' ], 0 ],
  [ VAR1_251 => 'VAR1', [ '?', 'VARNAME' ], 0 ],
  [ VAR2_252 => 'VAR2', [ '$', 'VARNAME' ], 0 ],
  [ _PLUS_LIST => 'PLUS-52', [ 'PLUS-52', 'NAME' ], 0 ],
  [ _PLUS_LIST => 'PLUS-52', [ 'NAME' ], 0 ],
  [ _PAREN => 'PAREN-53', [ '-', 'PLUS-52' ], 0 ],
  [ _STAR_LIST_54 => 'STAR-54', [ 'STAR-54', 'PAREN-53' ], 0 ],
  [ _STAR_LIST_54 => 'STAR-54', [  ], 0 ],
  [ LANGTAG_258 => 'LANGTAG', [ '@', 'NAME', 'STAR-54' ], 0 ],
  [ INTEGER_POSITIVE_259 => 'INTEGER_POSITIVE', [ '+', 'INTEGER' ], 0 ],
  [ DOUBLE_POSITIVE_260 => 'DOUBLE_POSITIVE', [ '+', 'DOUBLE' ], 0 ],
  [ DECIMAL_POSITIVE_261 => 'DECIMAL_POSITIVE', [ '+', 'DECIMAL' ], 0 ],
  [ VARNAME_262 => 'VARNAME', [ 'NAME' ], 0 ],
  [ VARNAME_263 => 'VARNAME', [ 'a' ], 0 ],
  [ VARNAME_264 => 'VARNAME', [ 'ASC' ], 0 ],
  [ VARNAME_265 => 'VARNAME', [ 'ASK' ], 0 ],
  [ VARNAME_266 => 'VARNAME', [ 'BASE' ], 0 ],
  [ VARNAME_267 => 'VARNAME', [ 'BOUND' ], 0 ],
  [ VARNAME_268 => 'VARNAME', [ 'CONSTRUCT' ], 0 ],
  [ VARNAME_269 => 'VARNAME', [ 'DATATYPE' ], 0 ],
  [ VARNAME_270 => 'VARNAME', [ 'DESCRIBE' ], 0 ],
  [ VARNAME_271 => 'VARNAME', [ 'DESC' ], 0 ],
  [ VARNAME_272 => 'VARNAME', [ 'DISTINCT' ], 0 ],
  [ VARNAME_273 => 'VARNAME', [ 'FILTER' ], 0 ],
  [ VARNAME_274 => 'VARNAME', [ 'FROM' ], 0 ],
  [ VARNAME_275 => 'VARNAME', [ 'GRAPH' ], 0 ],
  [ VARNAME_276 => 'VARNAME', [ 'LANGMATCHES' ], 0 ],
  [ VARNAME_277 => 'VARNAME', [ 'LANG' ], 0 ],
  [ VARNAME_278 => 'VARNAME', [ 'LIMIT' ], 0 ],
  [ VARNAME_279 => 'VARNAME', [ 'NAMED' ], 0 ],
  [ VARNAME_280 => 'VARNAME', [ 'OFFSET' ], 0 ],
  [ VARNAME_281 => 'VARNAME', [ 'OPTIONAL' ], 0 ],
  [ VARNAME_282 => 'VARNAME', [ 'PREFIX' ], 0 ],
  [ VARNAME_283 => 'VARNAME', [ 'REDUCED' ], 0 ],
  [ VARNAME_284 => 'VARNAME', [ 'REGEX' ], 0 ],
  [ VARNAME_285 => 'VARNAME', [ 'SELECT' ], 0 ],
  [ VARNAME_286 => 'VARNAME', [ 'STR' ], 0 ],
  [ VARNAME_287 => 'VARNAME', [ 'UNION' ], 0 ],
  [ VARNAME_288 => 'VARNAME', [ 'WHERE' ], 0 ],
  [ VARNAME_289 => 'VARNAME', [ 'ISBLANK' ], 0 ],
  [ VARNAME_290 => 'VARNAME', [ 'ISIRI' ], 0 ],
  [ VARNAME_291 => 'VARNAME', [ 'ISLITERAL' ], 0 ],
  [ VARNAME_292 => 'VARNAME', [ 'ISURI' ], 0 ],
  [ VARNAME_293 => 'VARNAME', [ 'SAMETERM' ], 0 ],
  [ VARNAME_294 => 'VARNAME', [ 'TRUE' ], 0 ],
  [ VARNAME_295 => 'VARNAME', [ 'FALSE' ], 0 ],
  [ _STAR_LIST_55 => 'STAR-55', [ 'STAR-55', 'WS' ], 0 ],
  [ _STAR_LIST_55 => 'STAR-55', [  ], 0 ],
  [ NIL_298 => 'NIL', [ '(', 'STAR-55', ')' ], 0 ],
  [ _STAR_LIST_56 => 'STAR-56', [ 'STAR-56', 'WS' ], 0 ],
  [ _STAR_LIST_56 => 'STAR-56', [  ], 0 ],
  [ ANON_301 => 'ANON', [ '[', 'STAR-56', ']' ], 0 ],
  [ INTEGER_302 => 'INTEGER', [ 'INTEGER_WS' ], 0 ],
  [ INTEGER_303 => 'INTEGER', [ 'INTEGER_NO_WS' ], 0 ],
],
                                  yyTERMS  =>
{ '$end' => 0, '!' => 0, '!=' => 0, '$' => 0, '&&' => 0, '(' => 0, ')' => 0, '*' => 0, '+' => 0, ',' => 0, '-' => 0, '.' => 0, '/' => 0, ':' => 0, ';' => 0, '<' => 0, '<=' => 0, '=' => 0, '>' => 0, '>=' => 0, '?' => 0, '@' => 0, 'ASC' => 0, 'ASK' => 0, 'BASE' => 0, 'CONSTRUCT' => 0, 'DESC' => 0, 'DESCRIBE' => 0, 'DISTINCT' => 0, 'FALSE' => 0, 'FILTER' => 0, 'FROM NAMED' => 0, 'FROM' => 0, 'GRAPH' => 0, 'LIMIT' => 0, 'OFFSET' => 0, 'OPTIONAL' => 0, 'ORDER BY' => 0, 'PREFIX' => 0, 'REDUCED' => 0, 'REGEX' => 0, 'SELECT' => 0, 'TRUE' => 0, 'UNION' => 0, 'WHERE' => 0, '[' => 0, ']' => 0, '^^' => 0, '_' => 0, '_:' => 0, 'a' => 0, '{' => 0, '||' => 0, '}' => 0, ASC => 1, ASK => 1, BASE => 1, BOUND => 1, CONSTRUCT => 1, DATATYPE => 1, DECIMAL => 1, DECIMAL_NEGATIVE => 1, DESC => 1, DESCRIBE => 1, DISTINCT => 1, DOUBLE => 1, DOUBLE_NEGATIVE => 1, FALSE => 1, FILTER => 1, FROM => 1, GRAPH => 1, INTEGER_NEGATIVE => 1, INTEGER_NO_WS => 1, INTEGER_WS => 1, ISBLANK => 1, ISIRI => 1, ISLITERAL => 1, ISURI => 1, LANG => 1, LANGMATCHES => 1, LIMIT => 1, NAME => 1, NAMED => 1, OFFSET => 1, OPTIONAL => 1, PREFIX => 1, REDUCED => 1, REGEX => 1, SAMETERM => 1, SELECT => 1, STR => 1, STRING => 1, TRUE => 1, UNION => 1, URI => 1, WHERE => 1, WS => 1, a => 1 },
                                  yyFILENAME  => "lib/RDF/Query/Parser/SPARQL.yp",
                                  yystates =>
[
	{#State 0
		ACTIONS => {
			"BASE" => 1
		},
		DEFAULT => -6,
		GOTOS => {
			'Query' => 3,
			'Prologue' => 2,
			'BaseDecl' => 4,
			'OPTIONAL-1' => 5
		}
	},
	{#State 1
		ACTIONS => {
			'URI' => 6
		},
		GOTOS => {
			'IRI_REF' => 7
		}
	},
	{#State 2
		ACTIONS => {
			"SELECT" => 8,
			"DESCRIBE" => 12,
			"CONSTRUCT" => 15,
			"ASK" => 10
		},
		GOTOS => {
			'DescribeQuery' => 11,
			'AskQuery' => 9,
			'SelectQuery' => 13,
			'ConstructQuery' => 14
		}
	},
	{#State 3
		ACTIONS => {
			'' => 16
		}
	},
	{#State 4
		DEFAULT => -5
	},
	{#State 5
		DEFAULT => -8,
		GOTOS => {
			'STAR-2' => 17
		}
	},
	{#State 6
		DEFAULT => -239
	},
	{#State 7
		DEFAULT => -10
	},
	{#State 8
		ACTIONS => {
			"REDUCED" => 18,
			"DISTINCT" => 19
		},
		DEFAULT => -13,
		GOTOS => {
			'SelectModifier' => 20,
			'OPTIONAL-3' => 21
		}
	},
	{#State 9
		DEFAULT => -4
	},
	{#State 10
		DEFAULT => -36,
		GOTOS => {
			'STAR-10' => 22
		}
	},
	{#State 11
		DEFAULT => -3
	},
	{#State 12
		ACTIONS => {
			":" => 23,
			'NAME' => 31,
			'URI' => 6,
			"?" => 32,
			"*" => 26,
			"\$" => 27
		},
		GOTOS => {
			'DescribeVars' => 24,
			'PLUS-9' => 33,
			'PrefixedName' => 34,
			'VAR1' => 25,
			'PNAME_LN' => 35,
			'IRI_REF' => 28,
			'PNAME_NS' => 36,
			'IRIref' => 38,
			'VarOrIRIref' => 37,
			'VAR2' => 29,
			'Var' => 30
		}
	},
	{#State 13
		DEFAULT => -1
	},
	{#State 14
		DEFAULT => -2
	},
	{#State 15
		ACTIONS => {
			"{" => 39
		},
		GOTOS => {
			'ConstructTemplate' => 40
		}
	},
	{#State 16
		DEFAULT => 0
	},
	{#State 17
		ACTIONS => {
			"PREFIX" => 42
		},
		DEFAULT => -9,
		GOTOS => {
			'PrefixDecl' => 41
		}
	},
	{#State 18
		DEFAULT => -18
	},
	{#State 19
		DEFAULT => -17
	},
	{#State 20
		DEFAULT => -12
	},
	{#State 21
		ACTIONS => {
			"?" => 32,
			"*" => 44,
			"\$" => 27
		},
		GOTOS => {
			'PLUS-5' => 46,
			'VAR1' => 25,
			'SelectVars' => 43,
			'Var' => 45,
			'VAR2' => 29
		}
	},
	{#State 22
		ACTIONS => {
			"FROM" => 49,
			"WHERE" => 47,
			"FROM NAMED" => 48
		},
		DEFAULT => -44,
		GOTOS => {
			'OPTIONAL-11' => 50,
			'WhereClause' => 52,
			'DatasetClause' => 51
		}
	},
	{#State 23
		DEFAULT => -241
	},
	{#State 24
		DEFAULT => -27,
		GOTOS => {
			'STAR-7' => 53
		}
	},
	{#State 25
		DEFAULT => -144
	},
	{#State 26
		DEFAULT => -34
	},
	{#State 27
		ACTIONS => {
			'BASE' => 72,
			'TRUE' => 71,
			'LANGMATCHES' => 54,
			'OFFSET' => 73,
			'a' => 56,
			'NAMED' => 55,
			'DATATYPE' => 57,
			'ISIRI' => 74,
			'ISLITERAL' => 58,
			'UNION' => 76,
			'ASC' => 75,
			'ISBLANK' => 78,
			'FILTER' => 77,
			'FALSE' => 60,
			'SAMETERM' => 61,
			'LANG' => 62,
			'DISTINCT' => 79,
			'CONSTRUCT' => 64,
			'LIMIT' => 63,
			'STR' => 80,
			'DESC' => 82,
			'NAME' => 81,
			'REDUCED' => 83,
			'REGEX' => 65,
			'ASK' => 66,
			'PREFIX' => 67,
			'BOUND' => 84,
			'FROM' => 68,
			'WHERE' => 85,
			'GRAPH' => 86,
			'DESCRIBE' => 87,
			'SELECT' => 69,
			'ISURI' => 88,
			'OPTIONAL' => 70
		},
		GOTOS => {
			'VARNAME' => 59
		}
	},
	{#State 28
		DEFAULT => -233
	},
	{#State 29
		DEFAULT => -145
	},
	{#State 30
		DEFAULT => -142
	},
	{#State 31
		ACTIONS => {
			":" => 89
		}
	},
	{#State 32
		ACTIONS => {
			'BASE' => 72,
			'TRUE' => 71,
			'LANGMATCHES' => 54,
			'OFFSET' => 73,
			'a' => 56,
			'NAMED' => 55,
			'DATATYPE' => 57,
			'ISIRI' => 74,
			'ISLITERAL' => 58,
			'ASC' => 75,
			'UNION' => 76,
			'FILTER' => 77,
			'ISBLANK' => 78,
			'FALSE' => 60,
			'SAMETERM' => 61,
			'LANG' => 62,
			'DISTINCT' => 79,
			'CONSTRUCT' => 64,
			'LIMIT' => 63,
			'STR' => 80,
			'NAME' => 81,
			'DESC' => 82,
			'REDUCED' => 83,
			'REGEX' => 65,
			'ASK' => 66,
			'PREFIX' => 67,
			'BOUND' => 84,
			'FROM' => 68,
			'WHERE' => 85,
			'GRAPH' => 86,
			'DESCRIBE' => 87,
			'SELECT' => 69,
			'ISURI' => 88,
			'OPTIONAL' => 70
		},
		GOTOS => {
			'VARNAME' => 90
		}
	},
	{#State 33
		ACTIONS => {
			":" => 23,
			'URI' => 6,
			'NAME' => 31,
			"?" => 32,
			"\$" => 27
		},
		DEFAULT => -33,
		GOTOS => {
			'PrefixedName' => 34,
			'VAR1' => 25,
			'PNAME_LN' => 35,
			'IRI_REF' => 28,
			'PNAME_NS' => 36,
			'IRIref' => 38,
			'VarOrIRIref' => 91,
			'VAR2' => 29,
			'Var' => 30
		}
	},
	{#State 34
		DEFAULT => -234
	},
	{#State 35
		DEFAULT => -235
	},
	{#State 36
		ACTIONS => {
			'NAMED' => 55,
			'DATATYPE' => 57,
			'ISLITERAL' => 58,
			'INTEGER_NO_WS' => 94,
			'REGEX' => 65,
			'ASK' => 66,
			'FROM' => 68,
			'OPTIONAL' => 70,
			'TRUE' => 71,
			'BASE' => 72,
			'OFFSET' => 73,
			'UNION' => 76,
			'ISBLANK' => 78,
			'FILTER' => 77,
			'STR' => 80,
			'DESC' => 82,
			'NAME' => 81,
			'WHERE' => 85,
			'DESCRIBE' => 87,
			'ISURI' => 88,
			'LANGMATCHES' => 54,
			'a' => 56,
			'SAMETERM' => 61,
			'FALSE' => 60,
			'LANG' => 62,
			'LIMIT' => 63,
			'CONSTRUCT' => 64,
			'PREFIX' => 67,
			'SELECT' => 69,
			'ISIRI' => 74,
			'INTEGER_WS' => 95,
			'ASC' => 75,
			'DISTINCT' => 79,
			'REDUCED' => 83,
			'BOUND' => 84,
			'GRAPH' => 86
		},
		DEFAULT => -236,
		GOTOS => {
			'INTEGER' => 93,
			'VARNAME' => 92,
			'PN_LOCAL' => 96
		}
	},
	{#State 37
		DEFAULT => -32
	},
	{#State 38
		DEFAULT => -143
	},
	{#State 39
		ACTIONS => {
			":" => 23,
			"+" => 116,
			'STRING' => 118,
			'INTEGER_WS' => 95,
			'INTEGER_NEGATIVE' => 98,
			"\$" => 27,
			'DECIMAL' => 99,
			"[" => 100,
			'DECIMAL_NEGATIVE' => 122,
			'DOUBLE' => 124,
			'INTEGER_NO_WS' => 94,
			"TRUE" => 104,
			'NAME' => 31,
			'URI' => 6,
			"?" => 32,
			"FALSE" => 125,
			'DOUBLE_NEGATIVE' => 108,
			"(" => 109,
			"_:" => 132
		},
		DEFAULT => -105,
		GOTOS => {
			'BooleanLiteral' => 97,
			'NumericLiteralPositive' => 114,
			'DOUBLE_POSITIVE' => 115,
			'NumericLiteralNegative' => 117,
			'NumericLiteralUnsigned' => 119,
			'NIL' => 120,
			'VAR1' => 25,
			'TriplesSameSubject' => 121,
			'IRI_REF' => 28,
			'NumericLiteral' => 101,
			'VAR2' => 29,
			'Var' => 102,
			'VarOrTerm' => 123,
			'INTEGER' => 103,
			'INTEGER_POSITIVE' => 126,
			'ANON' => 105,
			'TriplesNode' => 129,
			'GraphTerm' => 128,
			'BLANK_NODE_LABEL' => 127,
			'PrefixedName' => 34,
			'DECIMAL_POSITIVE' => 106,
			'OPTIONAL-29' => 107,
			'PNAME_LN' => 35,
			'BlankNode' => 130,
			'PNAME_NS' => 36,
			'ConstructTriples' => 110,
			'IRIref' => 111,
			'BlankNodePropertyList' => 112,
			'Collection' => 113,
			'RDFLiteral' => 131
		}
	},
	{#State 40
		DEFAULT => -24,
		GOTOS => {
			'STAR-6' => 133
		}
	},
	{#State 41
		DEFAULT => -7
	},
	{#State 42
		ACTIONS => {
			":" => 23,
			'NAME' => 31
		},
		GOTOS => {
			'PNAME_NS' => 134
		}
	},
	{#State 43
		DEFAULT => -15,
		GOTOS => {
			'STAR-4' => 135
		}
	},
	{#State 44
		DEFAULT => -22
	},
	{#State 45
		DEFAULT => -20
	},
	{#State 46
		ACTIONS => {
			"?" => 32,
			"\$" => 27
		},
		DEFAULT => -21,
		GOTOS => {
			'VAR1' => 25,
			'Var' => 136,
			'VAR2' => 29
		}
	},
	{#State 47
		DEFAULT => -43
	},
	{#State 48
		ACTIONS => {
			":" => 23,
			'URI' => 6,
			'NAME' => 31
		},
		GOTOS => {
			'NamedGraphClause' => 139,
			'PNAME_LN' => 35,
			'PNAME_NS' => 36,
			'IRI_REF' => 28,
			'IRIref' => 138,
			'SourceSelector' => 137,
			'PrefixedName' => 34
		}
	},
	{#State 49
		ACTIONS => {
			":" => 23,
			'URI' => 6,
			'NAME' => 31
		},
		GOTOS => {
			'PNAME_LN' => 35,
			'PNAME_NS' => 36,
			'IRI_REF' => 28,
			'DefaultGraphClause' => 141,
			'IRIref' => 138,
			'SourceSelector' => 140,
			'PrefixedName' => 34
		}
	},
	{#State 50
		ACTIONS => {
			"{" => 143
		},
		GOTOS => {
			'GroupGraphPattern' => 142
		}
	},
	{#State 51
		DEFAULT => -35
	},
	{#State 52
		DEFAULT => -37
	},
	{#State 53
		ACTIONS => {
			"{" => -44,
			"WHERE" => 47,
			"FROM NAMED" => 48,
			"FROM" => 49
		},
		DEFAULT => -29,
		GOTOS => {
			'OPTIONAL-8' => 146,
			'OPTIONAL-11' => 50,
			'DatasetClause' => 145,
			'WhereClause' => 144
		}
	},
	{#State 54
		DEFAULT => -276
	},
	{#State 55
		DEFAULT => -279
	},
	{#State 56
		DEFAULT => -263
	},
	{#State 57
		DEFAULT => -269
	},
	{#State 58
		DEFAULT => -291
	},
	{#State 59
		DEFAULT => -252
	},
	{#State 60
		DEFAULT => -295
	},
	{#State 61
		DEFAULT => -293
	},
	{#State 62
		DEFAULT => -277
	},
	{#State 63
		DEFAULT => -278
	},
	{#State 64
		DEFAULT => -268
	},
	{#State 65
		DEFAULT => -284
	},
	{#State 66
		DEFAULT => -265
	},
	{#State 67
		DEFAULT => -282
	},
	{#State 68
		DEFAULT => -274
	},
	{#State 69
		DEFAULT => -285
	},
	{#State 70
		DEFAULT => -281
	},
	{#State 71
		DEFAULT => -294
	},
	{#State 72
		DEFAULT => -266
	},
	{#State 73
		DEFAULT => -280
	},
	{#State 74
		DEFAULT => -290
	},
	{#State 75
		DEFAULT => -264
	},
	{#State 76
		DEFAULT => -287
	},
	{#State 77
		DEFAULT => -273
	},
	{#State 78
		DEFAULT => -289
	},
	{#State 79
		DEFAULT => -272
	},
	{#State 80
		DEFAULT => -286
	},
	{#State 81
		DEFAULT => -262
	},
	{#State 82
		DEFAULT => -271
	},
	{#State 83
		DEFAULT => -283
	},
	{#State 84
		DEFAULT => -267
	},
	{#State 85
		DEFAULT => -288
	},
	{#State 86
		DEFAULT => -275
	},
	{#State 87
		DEFAULT => -270
	},
	{#State 88
		DEFAULT => -292
	},
	{#State 89
		DEFAULT => -240
	},
	{#State 90
		DEFAULT => -251
	},
	{#State 91
		DEFAULT => -31
	},
	{#State 92
		ACTIONS => {
			"-" => 147,
			'INTEGER_NO_WS' => 148,
			"_" => 150
		},
		DEFAULT => -247,
		GOTOS => {
			'PN_LOCAL_EXTRA' => 149
		}
	},
	{#State 93
		ACTIONS => {
			'BASE' => 72,
			'TRUE' => 71,
			'LANGMATCHES' => 54,
			'OFFSET' => 73,
			'a' => 56,
			'NAMED' => 55,
			'DATATYPE' => 57,
			'ISIRI' => 74,
			'ISLITERAL' => 58,
			'ASC' => 75,
			'UNION' => 76,
			'FILTER' => 77,
			'ISBLANK' => 78,
			'FALSE' => 60,
			'SAMETERM' => 61,
			'LANG' => 62,
			'DISTINCT' => 79,
			'CONSTRUCT' => 64,
			'LIMIT' => 63,
			'STR' => 80,
			'NAME' => 81,
			'DESC' => 82,
			'REDUCED' => 83,
			'REGEX' => 65,
			'ASK' => 66,
			'PREFIX' => 67,
			'BOUND' => 84,
			'FROM' => 68,
			'WHERE' => 85,
			'GRAPH' => 86,
			'DESCRIBE' => 87,
			'SELECT' => 69,
			'ISURI' => 88,
			'OPTIONAL' => 70
		},
		GOTOS => {
			'VARNAME' => 151
		}
	},
	{#State 94
		DEFAULT => -303
	},
	{#State 95
		DEFAULT => -302
	},
	{#State 96
		DEFAULT => -242
	},
	{#State 97
		DEFAULT => -149
	},
	{#State 98
		DEFAULT => -228
	},
	{#State 99
		DEFAULT => -223
	},
	{#State 100
		ACTIONS => {
			":" => 23,
			'URI' => 6,
			'NAME' => 31,
			"?" => 32,
			"a" => 153,
			"\$" => 27
		},
		DEFAULT => -300,
		GOTOS => {
			'STAR-56' => 156,
			'Verb' => 154,
			'PrefixedName' => 34,
			'VAR1' => 25,
			'PropertyListNotEmpty' => 152,
			'PNAME_LN' => 35,
			'PNAME_NS' => 36,
			'IRI_REF' => 28,
			'IRIref' => 38,
			'VarOrIRIref' => 155,
			'VAR2' => 29,
			'Var' => 30
		}
	},
	{#State 101
		DEFAULT => -148
	},
	{#State 102
		DEFAULT => -140
	},
	{#State 103
		DEFAULT => -222
	},
	{#State 104
		DEFAULT => -231
	},
	{#State 105
		DEFAULT => -238
	},
	{#State 106
		DEFAULT => -226
	},
	{#State 107
		ACTIONS => {
			"}" => 157
		}
	},
	{#State 108
		DEFAULT => -230
	},
	{#State 109
		ACTIONS => {
			":" => 23,
			"+" => 116,
			'STRING' => 118,
			'INTEGER_WS' => 95,
			'INTEGER_NEGATIVE' => 98,
			"\$" => 27,
			'DECIMAL' => 99,
			"[" => 100,
			'DECIMAL_NEGATIVE' => 122,
			'DOUBLE' => 124,
			'INTEGER_NO_WS' => 94,
			"TRUE" => 104,
			'NAME' => 31,
			'URI' => 6,
			"?" => 32,
			"FALSE" => 125,
			'DOUBLE_NEGATIVE' => 108,
			"(" => 109,
			"_:" => 132
		},
		DEFAULT => -297,
		GOTOS => {
			'GraphNode' => 158,
			'BooleanLiteral' => 97,
			'NumericLiteralPositive' => 114,
			'DOUBLE_POSITIVE' => 115,
			'NumericLiteralNegative' => 117,
			'NumericLiteralUnsigned' => 119,
			'NIL' => 120,
			'VAR1' => 25,
			'IRI_REF' => 28,
			'NumericLiteral' => 101,
			'VAR2' => 29,
			'Var' => 102,
			'STAR-55' => 160,
			'VarOrTerm' => 159,
			'INTEGER' => 103,
			'PLUS-40' => 161,
			'INTEGER_POSITIVE' => 126,
			'ANON' => 105,
			'TriplesNode' => 162,
			'GraphTerm' => 128,
			'BLANK_NODE_LABEL' => 127,
			'PrefixedName' => 34,
			'DECIMAL_POSITIVE' => 106,
			'PNAME_LN' => 35,
			'BlankNode' => 130,
			'PNAME_NS' => 36,
			'IRIref' => 111,
			'BlankNodePropertyList' => 112,
			'Collection' => 113,
			'RDFLiteral' => 131
		}
	},
	{#State 110
		DEFAULT => -104
	},
	{#State 111
		DEFAULT => -146
	},
	{#State 112
		DEFAULT => -133
	},
	{#State 113
		DEFAULT => -132
	},
	{#State 114
		DEFAULT => -220
	},
	{#State 115
		DEFAULT => -227
	},
	{#State 116
		ACTIONS => {
			'DOUBLE' => 165,
			'INTEGER_NO_WS' => 94,
			'DECIMAL' => 163,
			'INTEGER_WS' => 95
		},
		GOTOS => {
			'INTEGER' => 164
		}
	},
	{#State 117
		DEFAULT => -221
	},
	{#State 118
		ACTIONS => {
			"\@" => 167,
			"^^" => 170
		},
		DEFAULT => -215,
		GOTOS => {
			'OPTIONAL-51' => 169,
			'LiteralExtra' => 166,
			'LANGTAG' => 168
		}
	},
	{#State 119
		DEFAULT => -219
	},
	{#State 120
		DEFAULT => -151
	},
	{#State 121
		ACTIONS => {
			"." => 173
		},
		DEFAULT => -111,
		GOTOS => {
			'OPTIONAL-32' => 171,
			'PAREN-31' => 172
		}
	},
	{#State 122
		DEFAULT => -229
	},
	{#State 123
		ACTIONS => {
			":" => 23,
			'URI' => 6,
			'NAME' => 31,
			"?" => 32,
			"a" => 153,
			"\$" => 27
		},
		GOTOS => {
			'Verb' => 154,
			'PrefixedName' => 34,
			'VAR1' => 25,
			'PropertyListNotEmpty' => 174,
			'PNAME_LN' => 35,
			'PNAME_NS' => 36,
			'IRI_REF' => 28,
			'IRIref' => 38,
			'VarOrIRIref' => 155,
			'VAR2' => 29,
			'Var' => 30
		}
	},
	{#State 124
		DEFAULT => -224
	},
	{#State 125
		DEFAULT => -232
	},
	{#State 126
		DEFAULT => -225
	},
	{#State 127
		DEFAULT => -237
	},
	{#State 128
		DEFAULT => -141
	},
	{#State 129
		ACTIONS => {
			":" => 23,
			'URI' => 6,
			'NAME' => 31,
			"?" => 32,
			"a" => 153,
			"\$" => 27
		},
		DEFAULT => -123,
		GOTOS => {
			'Verb' => 154,
			'PrefixedName' => 34,
			'VAR1' => 25,
			'PropertyListNotEmpty' => 175,
			'PNAME_LN' => 35,
			'PNAME_NS' => 36,
			'IRI_REF' => 28,
			'PropertyList' => 176,
			'OPTIONAL-37' => 177,
			'IRIref' => 38,
			'VarOrIRIref' => 155,
			'VAR2' => 29,
			'Var' => 30
		}
	},
	{#State 130
		DEFAULT => -150
	},
	{#State 131
		DEFAULT => -147
	},
	{#State 132
		ACTIONS => {
			'BASE' => 72,
			'TRUE' => 71,
			'LANGMATCHES' => 54,
			'OFFSET' => 73,
			'a' => 56,
			'NAMED' => 55,
			'DATATYPE' => 57,
			'ISIRI' => 74,
			'ISLITERAL' => 58,
			'INTEGER_WS' => 95,
			'ASC' => 75,
			'UNION' => 76,
			'FILTER' => 77,
			'ISBLANK' => 78,
			'FALSE' => 60,
			'SAMETERM' => 61,
			'LANG' => 62,
			'DISTINCT' => 79,
			'CONSTRUCT' => 64,
			'LIMIT' => 63,
			'STR' => 80,
			'NAME' => 81,
			'DESC' => 82,
			'INTEGER_NO_WS' => 94,
			'REDUCED' => 83,
			'REGEX' => 65,
			'ASK' => 66,
			'PREFIX' => 67,
			'BOUND' => 84,
			'FROM' => 68,
			'WHERE' => 85,
			'GRAPH' => 86,
			'DESCRIBE' => 87,
			'SELECT' => 69,
			'ISURI' => 88,
			'OPTIONAL' => 70
		},
		GOTOS => {
			'INTEGER' => 93,
			'VARNAME' => 92,
			'PN_LOCAL' => 178
		}
	},
	{#State 133
		ACTIONS => {
			"FROM" => 49,
			"WHERE" => 47,
			"FROM NAMED" => 48
		},
		DEFAULT => -44,
		GOTOS => {
			'OPTIONAL-11' => 50,
			'WhereClause' => 180,
			'DatasetClause' => 179
		}
	},
	{#State 134
		ACTIONS => {
			'URI' => 6
		},
		GOTOS => {
			'IRI_REF' => 181
		}
	},
	{#State 135
		ACTIONS => {
			"FROM" => 49,
			"WHERE" => 47,
			"FROM NAMED" => 48
		},
		DEFAULT => -44,
		GOTOS => {
			'OPTIONAL-11' => 50,
			'WhereClause' => 183,
			'DatasetClause' => 182
		}
	},
	{#State 136
		DEFAULT => -19
	},
	{#State 137
		DEFAULT => -41
	},
	{#State 138
		DEFAULT => -42
	},
	{#State 139
		DEFAULT => -39
	},
	{#State 140
		DEFAULT => -40
	},
	{#State 141
		DEFAULT => -38
	},
	{#State 142
		DEFAULT => -45
	},
	{#State 143
		ACTIONS => {
			":" => 23,
			"+" => 116,
			'STRING' => 118,
			'INTEGER_WS' => 95,
			'INTEGER_NEGATIVE' => 98,
			"\$" => 27,
			'DECIMAL' => 99,
			"[" => 100,
			'DECIMAL_NEGATIVE' => 122,
			'DOUBLE' => 124,
			'INTEGER_NO_WS' => 94,
			"TRUE" => 104,
			'NAME' => 31,
			'URI' => 6,
			"?" => 32,
			"FALSE" => 125,
			'DOUBLE_NEGATIVE' => 108,
			"(" => 109,
			"_:" => 132
		},
		DEFAULT => -68,
		GOTOS => {
			'BooleanLiteral' => 97,
			'NumericLiteralPositive' => 114,
			'DOUBLE_POSITIVE' => 115,
			'NumericLiteralNegative' => 117,
			'NumericLiteralUnsigned' => 119,
			'NIL' => 120,
			'VAR1' => 25,
			'TriplesSameSubject' => 186,
			'IRI_REF' => 28,
			'TriplesBlock' => 184,
			'NumericLiteral' => 101,
			'VAR2' => 29,
			'Var' => 102,
			'VarOrTerm' => 123,
			'INTEGER' => 103,
			'INTEGER_POSITIVE' => 126,
			'ANON' => 105,
			'TriplesNode' => 129,
			'GraphTerm' => 128,
			'BLANK_NODE_LABEL' => 127,
			'PrefixedName' => 34,
			'DECIMAL_POSITIVE' => 106,
			'PNAME_LN' => 35,
			'BlankNode' => 130,
			'PNAME_NS' => 36,
			'IRIref' => 111,
			'BlankNodePropertyList' => 112,
			'Collection' => 113,
			'OPTIONAL-17' => 185,
			'RDFLiteral' => 131
		}
	},
	{#State 144
		DEFAULT => -28
	},
	{#State 145
		DEFAULT => -26
	},
	{#State 146
		ACTIONS => {
			"ORDER BY" => 187
		},
		DEFAULT => -47,
		GOTOS => {
			'SolutionModifier' => 189,
			'OrderClause' => 190,
			'OPTIONAL-12' => 188
		}
	},
	{#State 147
		ACTIONS => {
			'NAME' => 191
		}
	},
	{#State 148
		DEFAULT => -248
	},
	{#State 149
		DEFAULT => -244
	},
	{#State 150
		ACTIONS => {
			'NAME' => 192
		}
	},
	{#State 151
		ACTIONS => {
			"-" => 147,
			'INTEGER_NO_WS' => 148,
			"_" => 150
		},
		DEFAULT => -246,
		GOTOS => {
			'PN_LOCAL_EXTRA' => 193
		}
	},
	{#State 152
		ACTIONS => {
			"]" => 194
		}
	},
	{#State 153
		DEFAULT => -131
	},
	{#State 154
		ACTIONS => {
			":" => 23,
			"+" => 116,
			'STRING' => 118,
			'INTEGER_WS' => 95,
			'INTEGER_NEGATIVE' => 98,
			"\$" => 27,
			'DECIMAL' => 99,
			"[" => 100,
			'DECIMAL_NEGATIVE' => 122,
			'INTEGER_NO_WS' => 94,
			"TRUE" => 104,
			'NAME' => 31,
			'URI' => 6,
			'DOUBLE' => 124,
			"?" => 32,
			"FALSE" => 125,
			'DOUBLE_NEGATIVE' => 108,
			"(" => 109,
			"_:" => 132
		},
		GOTOS => {
			'GraphNode' => 196,
			'BooleanLiteral' => 97,
			'NumericLiteralPositive' => 114,
			'DOUBLE_POSITIVE' => 115,
			'NumericLiteralNegative' => 117,
			'NumericLiteralUnsigned' => 119,
			'NIL' => 120,
			'VAR1' => 25,
			'IRI_REF' => 28,
			'Object' => 197,
			'NumericLiteral' => 101,
			'VAR2' => 29,
			'Var' => 102,
			'VarOrTerm' => 159,
			'INTEGER' => 103,
			'ObjectList' => 195,
			'INTEGER_POSITIVE' => 126,
			'ANON' => 105,
			'TriplesNode' => 162,
			'GraphTerm' => 128,
			'BLANK_NODE_LABEL' => 127,
			'PrefixedName' => 34,
			'DECIMAL_POSITIVE' => 106,
			'PNAME_LN' => 35,
			'BlankNode' => 130,
			'PNAME_NS' => 36,
			'IRIref' => 111,
			'BlankNodePropertyList' => 112,
			'Collection' => 113,
			'RDFLiteral' => 131
		}
	},
	{#State 155
		DEFAULT => -130
	},
	{#State 156
		ACTIONS => {
			'WS' => 199,
			"]" => 198
		}
	},
	{#State 157
		DEFAULT => -106
	},
	{#State 158
		DEFAULT => -136
	},
	{#State 159
		DEFAULT => -138
	},
	{#State 160
		ACTIONS => {
			'WS' => 200,
			")" => 201
		}
	},
	{#State 161
		ACTIONS => {
			":" => 23,
			"+" => 116,
			'STRING' => 118,
			'INTEGER_WS' => 95,
			'INTEGER_NEGATIVE' => 98,
			"\$" => 27,
			'DECIMAL' => 99,
			"[" => 100,
			")" => 203,
			'DECIMAL_NEGATIVE' => 122,
			'DOUBLE' => 124,
			'INTEGER_NO_WS' => 94,
			"TRUE" => 104,
			'NAME' => 31,
			'URI' => 6,
			"?" => 32,
			"FALSE" => 125,
			'DOUBLE_NEGATIVE' => 108,
			"(" => 109,
			"_:" => 132
		},
		GOTOS => {
			'GraphNode' => 202,
			'BooleanLiteral' => 97,
			'NumericLiteralPositive' => 114,
			'DOUBLE_POSITIVE' => 115,
			'NumericLiteralNegative' => 117,
			'NumericLiteralUnsigned' => 119,
			'NIL' => 120,
			'VAR1' => 25,
			'IRI_REF' => 28,
			'NumericLiteral' => 101,
			'VAR2' => 29,
			'Var' => 102,
			'VarOrTerm' => 159,
			'INTEGER' => 103,
			'INTEGER_POSITIVE' => 126,
			'ANON' => 105,
			'TriplesNode' => 162,
			'GraphTerm' => 128,
			'BLANK_NODE_LABEL' => 127,
			'PrefixedName' => 34,
			'DECIMAL_POSITIVE' => 106,
			'PNAME_LN' => 35,
			'BlankNode' => 130,
			'PNAME_NS' => 36,
			'IRIref' => 111,
			'BlankNodePropertyList' => 112,
			'Collection' => 113,
			'RDFLiteral' => 131
		}
	},
	{#State 162
		DEFAULT => -139
	},
	{#State 163
		DEFAULT => -261
	},
	{#State 164
		DEFAULT => -259
	},
	{#State 165
		DEFAULT => -260
	},
	{#State 166
		DEFAULT => -214
	},
	{#State 167
		ACTIONS => {
			'NAME' => 204
		}
	},
	{#State 168
		DEFAULT => -217
	},
	{#State 169
		DEFAULT => -216
	},
	{#State 170
		ACTIONS => {
			":" => 23,
			'URI' => 6,
			'NAME' => 31
		},
		GOTOS => {
			'PNAME_LN' => 35,
			'PNAME_NS' => 36,
			'IRI_REF' => 28,
			'IRIref' => 205,
			'PrefixedName' => 34
		}
	},
	{#State 171
		DEFAULT => -112
	},
	{#State 172
		DEFAULT => -110
	},
	{#State 173
		ACTIONS => {
			":" => 23,
			"+" => 116,
			'STRING' => 118,
			'INTEGER_WS' => 95,
			'INTEGER_NEGATIVE' => 98,
			"\$" => 27,
			'DECIMAL' => 99,
			"[" => 100,
			'DECIMAL_NEGATIVE' => 122,
			'DOUBLE' => 124,
			'INTEGER_NO_WS' => 94,
			"TRUE" => 104,
			'NAME' => 31,
			'URI' => 6,
			"?" => 32,
			"FALSE" => 125,
			'DOUBLE_NEGATIVE' => 108,
			"(" => 109,
			"_:" => 132
		},
		DEFAULT => -108,
		GOTOS => {
			'BooleanLiteral' => 97,
			'NumericLiteralPositive' => 114,
			'DOUBLE_POSITIVE' => 115,
			'NumericLiteralNegative' => 117,
			'NumericLiteralUnsigned' => 119,
			'NIL' => 120,
			'VAR1' => 25,
			'TriplesSameSubject' => 121,
			'IRI_REF' => 28,
			'NumericLiteral' => 101,
			'VAR2' => 29,
			'Var' => 102,
			'OPTIONAL-30' => 207,
			'VarOrTerm' => 123,
			'INTEGER' => 103,
			'INTEGER_POSITIVE' => 126,
			'ANON' => 105,
			'TriplesNode' => 129,
			'GraphTerm' => 128,
			'BLANK_NODE_LABEL' => 127,
			'PrefixedName' => 34,
			'DECIMAL_POSITIVE' => 106,
			'PNAME_LN' => 35,
			'BlankNode' => 130,
			'PNAME_NS' => 36,
			'ConstructTriples' => 206,
			'IRIref' => 111,
			'BlankNodePropertyList' => 112,
			'Collection' => 113,
			'RDFLiteral' => 131
		}
	},
	{#State 174
		DEFAULT => -113
	},
	{#State 175
		DEFAULT => -122
	},
	{#State 176
		DEFAULT => -114
	},
	{#State 177
		DEFAULT => -124
	},
	{#State 178
		DEFAULT => -243
	},
	{#State 179
		DEFAULT => -23
	},
	{#State 180
		ACTIONS => {
			"ORDER BY" => 187
		},
		DEFAULT => -47,
		GOTOS => {
			'SolutionModifier' => 208,
			'OrderClause' => 190,
			'OPTIONAL-12' => 188
		}
	},
	{#State 181
		DEFAULT => -11
	},
	{#State 182
		DEFAULT => -14
	},
	{#State 183
		ACTIONS => {
			"ORDER BY" => 187
		},
		DEFAULT => -47,
		GOTOS => {
			'SolutionModifier' => 209,
			'OrderClause' => 190,
			'OPTIONAL-12' => 188
		}
	},
	{#State 184
		DEFAULT => -67
	},
	{#State 185
		DEFAULT => -75,
		GOTOS => {
			'STAR-21' => 210
		}
	},
	{#State 186
		ACTIONS => {
			"." => 212
		},
		DEFAULT => -83,
		GOTOS => {
			'OPTIONAL-24' => 211,
			'PAREN-23' => 213
		}
	},
	{#State 187
		ACTIONS => {
			":" => 23,
			'LANGMATCHES' => 214,
			'DATATYPE' => 215,
			'ISIRI' => 227,
			'ISLITERAL' => 217,
			"ASC" => 229,
			'ISBLANK' => 231,
			"\$" => 27,
			'SAMETERM' => 219,
			'LANG' => 220,
			'STR' => 232,
			"DESC" => 233,
			'NAME' => 31,
			'URI' => 6,
			"?" => 32,
			'BOUND' => 234,
			"(" => 223,
			'ISURI' => 236,
			"REGEX" => 237
		},
		GOTOS => {
			'RegexExpression' => 226,
			'OrderDirection' => 216,
			'PLUS-16' => 218,
			'VAR1' => 25,
			'Constraint' => 230,
			'FunctionCall' => 228,
			'IRI_REF' => 28,
			'VAR2' => 29,
			'Var' => 221,
			'BrackettedExpression' => 222,
			'PrefixedName' => 34,
			'BuiltInCall' => 224,
			'PNAME_LN' => 35,
			'PNAME_NS' => 36,
			'OrderCondition' => 235,
			'IRIref' => 225
		}
	},
	{#State 188
		ACTIONS => {
			"LIMIT" => 238,
			"OFFSET" => 239
		},
		DEFAULT => -49,
		GOTOS => {
			'LimitOffsetClauses' => 242,
			'LimitClause' => 243,
			'OPTIONAL-13' => 240,
			'OffsetClause' => 241
		}
	},
	{#State 189
		DEFAULT => -30
	},
	{#State 190
		DEFAULT => -46
	},
	{#State 191
		DEFAULT => -249
	},
	{#State 192
		DEFAULT => -250
	},
	{#State 193
		DEFAULT => -245
	},
	{#State 194
		DEFAULT => -134
	},
	{#State 195
		DEFAULT => -120,
		GOTOS => {
			'STAR-36' => 244
		}
	},
	{#State 196
		DEFAULT => -129
	},
	{#State 197
		DEFAULT => -127,
		GOTOS => {
			'STAR-39' => 245
		}
	},
	{#State 198
		DEFAULT => -301
	},
	{#State 199
		DEFAULT => -299
	},
	{#State 200
		DEFAULT => -296
	},
	{#State 201
		DEFAULT => -298
	},
	{#State 202
		DEFAULT => -135
	},
	{#State 203
		DEFAULT => -137
	},
	{#State 204
		DEFAULT => -257,
		GOTOS => {
			'STAR-54' => 246
		}
	},
	{#State 205
		DEFAULT => -218
	},
	{#State 206
		DEFAULT => -107
	},
	{#State 207
		DEFAULT => -109
	},
	{#State 208
		DEFAULT => -25
	},
	{#State 209
		DEFAULT => -16
	},
	{#State 210
		ACTIONS => {
			"GRAPH" => 251,
			"}" => 247,
			"{" => 143,
			"OPTIONAL" => 258,
			"FILTER" => 254
		},
		GOTOS => {
			'Filter' => 256,
			'PAREN-20' => 253,
			'GroupGraphPattern' => 250,
			'OptionalGraphPattern' => 248,
			'GGPAtom' => 252,
			'GroupOrUnionGraphPattern' => 257,
			'GraphPatternNotTriples' => 249,
			'GraphGraphPattern' => 255
		}
	},
	{#State 211
		DEFAULT => -84
	},
	{#State 212
		ACTIONS => {
			":" => 23,
			"+" => 116,
			'STRING' => 118,
			'INTEGER_WS' => 95,
			'INTEGER_NEGATIVE' => 98,
			"\$" => 27,
			'DECIMAL' => 99,
			"[" => 100,
			'DECIMAL_NEGATIVE' => 122,
			'DOUBLE' => 124,
			'INTEGER_NO_WS' => 94,
			"TRUE" => 104,
			'NAME' => 31,
			'URI' => 6,
			"?" => 32,
			"FALSE" => 125,
			'DOUBLE_NEGATIVE' => 108,
			"(" => 109,
			"_:" => 132
		},
		DEFAULT => -80,
		GOTOS => {
			'BooleanLiteral' => 97,
			'NumericLiteralPositive' => 114,
			'DOUBLE_POSITIVE' => 115,
			'NumericLiteralNegative' => 117,
			'NumericLiteralUnsigned' => 119,
			'NIL' => 120,
			'VAR1' => 25,
			'OPTIONAL-22' => 259,
			'TriplesSameSubject' => 186,
			'IRI_REF' => 28,
			'TriplesBlock' => 260,
			'NumericLiteral' => 101,
			'VAR2' => 29,
			'Var' => 102,
			'VarOrTerm' => 123,
			'INTEGER' => 103,
			'INTEGER_POSITIVE' => 126,
			'ANON' => 105,
			'TriplesNode' => 129,
			'GraphTerm' => 128,
			'BLANK_NODE_LABEL' => 127,
			'PrefixedName' => 34,
			'DECIMAL_POSITIVE' => 106,
			'PNAME_LN' => 35,
			'BlankNode' => 130,
			'PNAME_NS' => 36,
			'IRIref' => 111,
			'BlankNodePropertyList' => 112,
			'Collection' => 113,
			'RDFLiteral' => 131
		}
	},
	{#State 213
		DEFAULT => -82
	},
	{#State 214
		ACTIONS => {
			"(" => 261
		}
	},
	{#State 215
		ACTIONS => {
			"(" => 262
		}
	},
	{#State 216
		ACTIONS => {
			"(" => 223
		},
		GOTOS => {
			'BrackettedExpression' => 263
		}
	},
	{#State 217
		ACTIONS => {
			"(" => 264
		}
	},
	{#State 218
		ACTIONS => {
			":" => 23,
			'LANGMATCHES' => 214,
			'DATATYPE' => 215,
			'ISIRI' => 227,
			'ISLITERAL' => 217,
			"ASC" => 229,
			'ISBLANK' => 231,
			"\$" => 27,
			'SAMETERM' => 219,
			'LANG' => 220,
			'STR' => 232,
			"DESC" => 233,
			'NAME' => 31,
			'URI' => 6,
			"?" => 32,
			'BOUND' => 234,
			"(" => 223,
			'ISURI' => 236,
			"REGEX" => 237
		},
		DEFAULT => -59,
		GOTOS => {
			'RegexExpression' => 226,
			'OrderDirection' => 216,
			'BrackettedExpression' => 222,
			'PrefixedName' => 34,
			'VAR1' => 25,
			'Constraint' => 230,
			'FunctionCall' => 228,
			'PNAME_LN' => 35,
			'BuiltInCall' => 224,
			'OrderCondition' => 265,
			'PNAME_NS' => 36,
			'IRI_REF' => 28,
			'IRIref' => 225,
			'VAR2' => 29,
			'Var' => 221
		}
	},
	{#State 219
		ACTIONS => {
			"(" => 266
		}
	},
	{#State 220
		ACTIONS => {
			"(" => 267
		}
	},
	{#State 221
		DEFAULT => -62
	},
	{#State 222
		DEFAULT => -95
	},
	{#State 223
		ACTIONS => {
			"-" => 269,
			":" => 23,
			'LANGMATCHES' => 214,
			"+" => 283,
			'DATATYPE' => 215,
			'ISIRI' => 227,
			'ISLITERAL' => 217,
			'STRING' => 118,
			'INTEGER_WS' => 95,
			'INTEGER_NEGATIVE' => 98,
			"!" => 273,
			'ISBLANK' => 231,
			'SAMETERM' => 219,
			"\$" => 27,
			'DECIMAL' => 99,
			'LANG' => 220,
			'DECIMAL_NEGATIVE' => 122,
			'STR' => 232,
			'DOUBLE' => 124,
			'URI' => 6,
			'NAME' => 31,
			'INTEGER_NO_WS' => 94,
			"TRUE" => 104,
			"?" => 32,
			"FALSE" => 125,
			'BOUND' => 234,
			'DOUBLE_NEGATIVE' => 108,
			"(" => 223,
			'ISURI' => 236,
			"REGEX" => 237
		},
		GOTOS => {
			'BooleanLiteral' => 268,
			'RegexExpression' => 226,
			'NumericLiteralPositive' => 114,
			'DOUBLE_POSITIVE' => 115,
			'RelationalExpression' => 270,
			'ValueLogical' => 271,
			'MultiplicativeExpression' => 272,
			'NumericLiteralNegative' => 117,
			'NumericLiteralUnsigned' => 119,
			'VAR1' => 25,
			'IRI_REF' => 28,
			'NumericLiteral' => 274,
			'IRIrefOrFunction' => 275,
			'NumericExpression' => 276,
			'ConditionalOrExpression' => 284,
			'VAR2' => 29,
			'Var' => 277,
			'INTEGER' => 103,
			'Expression' => 285,
			'BrackettedExpression' => 278,
			'INTEGER_POSITIVE' => 126,
			'PrefixedName' => 34,
			'DECIMAL_POSITIVE' => 106,
			'ConditionalAndExpression' => 286,
			'PrimaryExpression' => 279,
			'PNAME_LN' => 35,
			'BuiltInCall' => 280,
			'PNAME_NS' => 36,
			'UnaryExpression' => 281,
			'AdditiveExpression' => 287,
			'IRIref' => 282,
			'RDFLiteral' => 288
		}
	},
	{#State 224
		DEFAULT => -96
	},
	{#State 225
		ACTIONS => {
			"(" => 290
		},
		GOTOS => {
			'NIL' => 291,
			'ArgList' => 289
		}
	},
	{#State 226
		DEFAULT => -206
	},
	{#State 227
		ACTIONS => {
			"(" => 292
		}
	},
	{#State 228
		DEFAULT => -97
	},
	{#State 229
		DEFAULT => -63
	},
	{#State 230
		DEFAULT => -61
	},
	{#State 231
		ACTIONS => {
			"(" => 293
		}
	},
	{#State 232
		ACTIONS => {
			"(" => 294
		}
	},
	{#State 233
		DEFAULT => -64
	},
	{#State 234
		ACTIONS => {
			"(" => 295
		}
	},
	{#State 235
		DEFAULT => -58
	},
	{#State 236
		ACTIONS => {
			"(" => 296
		}
	},
	{#State 237
		ACTIONS => {
			"(" => 297
		}
	},
	{#State 238
		ACTIONS => {
			'INTEGER_NO_WS' => 94,
			'INTEGER_WS' => 95
		},
		GOTOS => {
			'INTEGER' => 298
		}
	},
	{#State 239
		ACTIONS => {
			'INTEGER_NO_WS' => 94,
			'INTEGER_WS' => 95
		},
		GOTOS => {
			'INTEGER' => 299
		}
	},
	{#State 240
		DEFAULT => -50
	},
	{#State 241
		ACTIONS => {
			"LIMIT" => 238
		},
		DEFAULT => -54,
		GOTOS => {
			'LimitClause' => 301,
			'OPTIONAL-15' => 300
		}
	},
	{#State 242
		DEFAULT => -48
	},
	{#State 243
		ACTIONS => {
			"OFFSET" => 239
		},
		DEFAULT => -52,
		GOTOS => {
			'OPTIONAL-14' => 303,
			'OffsetClause' => 302
		}
	},
	{#State 244
		ACTIONS => {
			";" => 305
		},
		DEFAULT => -121,
		GOTOS => {
			'PAREN-35' => 304
		}
	},
	{#State 245
		ACTIONS => {
			"," => 306
		},
		DEFAULT => -128,
		GOTOS => {
			'PAREN-38' => 307
		}
	},
	{#State 246
		ACTIONS => {
			"-" => 308
		},
		DEFAULT => -258,
		GOTOS => {
			'PAREN-53' => 309
		}
	},
	{#State 247
		DEFAULT => -76
	},
	{#State 248
		DEFAULT => -85
	},
	{#State 249
		DEFAULT => -77
	},
	{#State 250
		DEFAULT => -92,
		GOTOS => {
			'STAR-26' => 310
		}
	},
	{#State 251
		ACTIONS => {
			":" => 23,
			'URI' => 6,
			'NAME' => 31,
			"?" => 32,
			"\$" => 27
		},
		GOTOS => {
			'PrefixedName' => 34,
			'VAR1' => 25,
			'PNAME_LN' => 35,
			'IRI_REF' => 28,
			'PNAME_NS' => 36,
			'IRIref' => 38,
			'VarOrIRIref' => 311,
			'VAR2' => 29,
			'Var' => 30
		}
	},
	{#State 252
		ACTIONS => {
			"." => 312
		},
		DEFAULT => -70,
		GOTOS => {
			'OPTIONAL-18' => 313
		}
	},
	{#State 253
		DEFAULT => -74
	},
	{#State 254
		ACTIONS => {
			'STR' => 232,
			":" => 23,
			'URI' => 6,
			'NAME' => 31,
			'LANGMATCHES' => 214,
			'DATATYPE' => 215,
			'ISIRI' => 227,
			'ISLITERAL' => 217,
			'BOUND' => 234,
			"(" => 223,
			'SAMETERM' => 219,
			'ISBLANK' => 231,
			'ISURI' => 236,
			'LANG' => 220,
			"REGEX" => 237
		},
		GOTOS => {
			'RegexExpression' => 226,
			'BrackettedExpression' => 222,
			'PrefixedName' => 34,
			'PNAME_LN' => 35,
			'BuiltInCall' => 224,
			'FunctionCall' => 228,
			'Constraint' => 314,
			'PNAME_NS' => 36,
			'IRI_REF' => 28,
			'IRIref' => 225
		}
	},
	{#State 255
		DEFAULT => -87
	},
	{#State 256
		DEFAULT => -78
	},
	{#State 257
		DEFAULT => -86
	},
	{#State 258
		ACTIONS => {
			"{" => 143
		},
		GOTOS => {
			'GroupGraphPattern' => 315
		}
	},
	{#State 259
		DEFAULT => -81
	},
	{#State 260
		DEFAULT => -79
	},
	{#State 261
		ACTIONS => {
			"-" => 269,
			":" => 23,
			'LANGMATCHES' => 214,
			"+" => 283,
			'DATATYPE' => 215,
			'ISIRI' => 227,
			'ISLITERAL' => 217,
			'STRING' => 118,
			'INTEGER_WS' => 95,
			'INTEGER_NEGATIVE' => 98,
			"!" => 273,
			'ISBLANK' => 231,
			'SAMETERM' => 219,
			"\$" => 27,
			'DECIMAL' => 99,
			'LANG' => 220,
			'DECIMAL_NEGATIVE' => 122,
			'STR' => 232,
			'DOUBLE' => 124,
			'URI' => 6,
			'NAME' => 31,
			'INTEGER_NO_WS' => 94,
			"TRUE" => 104,
			"?" => 32,
			"FALSE" => 125,
			'BOUND' => 234,
			'DOUBLE_NEGATIVE' => 108,
			"(" => 223,
			'ISURI' => 236,
			"REGEX" => 237
		},
		GOTOS => {
			'BooleanLiteral' => 268,
			'RegexExpression' => 226,
			'NumericLiteralPositive' => 114,
			'DOUBLE_POSITIVE' => 115,
			'RelationalExpression' => 270,
			'ValueLogical' => 271,
			'MultiplicativeExpression' => 272,
			'NumericLiteralNegative' => 117,
			'NumericLiteralUnsigned' => 119,
			'VAR1' => 25,
			'IRI_REF' => 28,
			'NumericLiteral' => 274,
			'IRIrefOrFunction' => 275,
			'NumericExpression' => 276,
			'ConditionalOrExpression' => 284,
			'VAR2' => 29,
			'Var' => 277,
			'INTEGER' => 103,
			'Expression' => 316,
			'BrackettedExpression' => 278,
			'INTEGER_POSITIVE' => 126,
			'PrefixedName' => 34,
			'DECIMAL_POSITIVE' => 106,
			'ConditionalAndExpression' => 286,
			'PrimaryExpression' => 279,
			'PNAME_LN' => 35,
			'BuiltInCall' => 280,
			'PNAME_NS' => 36,
			'UnaryExpression' => 281,
			'AdditiveExpression' => 287,
			'IRIref' => 282,
			'RDFLiteral' => 288
		}
	},
	{#State 262
		ACTIONS => {
			"-" => 269,
			":" => 23,
			'LANGMATCHES' => 214,
			"+" => 283,
			'DATATYPE' => 215,
			'ISIRI' => 227,
			'ISLITERAL' => 217,
			'STRING' => 118,
			'INTEGER_WS' => 95,
			'INTEGER_NEGATIVE' => 98,
			"!" => 273,
			'ISBLANK' => 231,
			'SAMETERM' => 219,
			"\$" => 27,
			'DECIMAL' => 99,
			'LANG' => 220,
			'DECIMAL_NEGATIVE' => 122,
			'STR' => 232,
			'DOUBLE' => 124,
			'URI' => 6,
			'NAME' => 31,
			'INTEGER_NO_WS' => 94,
			"TRUE" => 104,
			"?" => 32,
			"FALSE" => 125,
			'BOUND' => 234,
			'DOUBLE_NEGATIVE' => 108,
			"(" => 223,
			'ISURI' => 236,
			"REGEX" => 237
		},
		GOTOS => {
			'BooleanLiteral' => 268,
			'RegexExpression' => 226,
			'NumericLiteralPositive' => 114,
			'DOUBLE_POSITIVE' => 115,
			'RelationalExpression' => 270,
			'ValueLogical' => 271,
			'MultiplicativeExpression' => 272,
			'NumericLiteralNegative' => 117,
			'NumericLiteralUnsigned' => 119,
			'VAR1' => 25,
			'IRI_REF' => 28,
			'NumericLiteral' => 274,
			'IRIrefOrFunction' => 275,
			'NumericExpression' => 276,
			'ConditionalOrExpression' => 284,
			'VAR2' => 29,
			'Var' => 277,
			'INTEGER' => 103,
			'Expression' => 317,
			'BrackettedExpression' => 278,
			'INTEGER_POSITIVE' => 126,
			'PrefixedName' => 34,
			'DECIMAL_POSITIVE' => 106,
			'ConditionalAndExpression' => 286,
			'PrimaryExpression' => 279,
			'PNAME_LN' => 35,
			'BuiltInCall' => 280,
			'PNAME_NS' => 36,
			'UnaryExpression' => 281,
			'AdditiveExpression' => 287,
			'IRIref' => 282,
			'RDFLiteral' => 288
		}
	},
	{#State 263
		DEFAULT => -60
	},
	{#State 264
		ACTIONS => {
			"-" => 269,
			":" => 23,
			'LANGMATCHES' => 214,
			"+" => 283,
			'DATATYPE' => 215,
			'ISIRI' => 227,
			'ISLITERAL' => 217,
			'STRING' => 118,
			'INTEGER_WS' => 95,
			'INTEGER_NEGATIVE' => 98,
			"!" => 273,
			'ISBLANK' => 231,
			'SAMETERM' => 219,
			"\$" => 27,
			'DECIMAL' => 99,
			'LANG' => 220,
			'DECIMAL_NEGATIVE' => 122,
			'STR' => 232,
			'DOUBLE' => 124,
			'URI' => 6,
			'NAME' => 31,
			'INTEGER_NO_WS' => 94,
			"TRUE" => 104,
			"?" => 32,
			"FALSE" => 125,
			'BOUND' => 234,
			'DOUBLE_NEGATIVE' => 108,
			"(" => 223,
			'ISURI' => 236,
			"REGEX" => 237
		},
		GOTOS => {
			'BooleanLiteral' => 268,
			'RegexExpression' => 226,
			'NumericLiteralPositive' => 114,
			'DOUBLE_POSITIVE' => 115,
			'RelationalExpression' => 270,
			'ValueLogical' => 271,
			'MultiplicativeExpression' => 272,
			'NumericLiteralNegative' => 117,
			'NumericLiteralUnsigned' => 119,
			'VAR1' => 25,
			'IRI_REF' => 28,
			'NumericLiteral' => 274,
			'IRIrefOrFunction' => 275,
			'NumericExpression' => 276,
			'ConditionalOrExpression' => 284,
			'VAR2' => 29,
			'Var' => 277,
			'INTEGER' => 103,
			'Expression' => 318,
			'BrackettedExpression' => 278,
			'INTEGER_POSITIVE' => 126,
			'PrefixedName' => 34,
			'DECIMAL_POSITIVE' => 106,
			'ConditionalAndExpression' => 286,
			'PrimaryExpression' => 279,
			'PNAME_LN' => 35,
			'BuiltInCall' => 280,
			'PNAME_NS' => 36,
			'UnaryExpression' => 281,
			'AdditiveExpression' => 287,
			'IRIref' => 282,
			'RDFLiteral' => 288
		}
	},
	{#State 265
		DEFAULT => -57
	},
	{#State 266
		ACTIONS => {
			"-" => 269,
			":" => 23,
			'LANGMATCHES' => 214,
			"+" => 283,
			'DATATYPE' => 215,
			'ISIRI' => 227,
			'ISLITERAL' => 217,
			'STRING' => 118,
			'INTEGER_WS' => 95,
			'INTEGER_NEGATIVE' => 98,
			"!" => 273,
			'ISBLANK' => 231,
			'SAMETERM' => 219,
			"\$" => 27,
			'DECIMAL' => 99,
			'LANG' => 220,
			'DECIMAL_NEGATIVE' => 122,
			'STR' => 232,
			'DOUBLE' => 124,
			'URI' => 6,
			'NAME' => 31,
			'INTEGER_NO_WS' => 94,
			"TRUE" => 104,
			"?" => 32,
			"FALSE" => 125,
			'BOUND' => 234,
			'DOUBLE_NEGATIVE' => 108,
			"(" => 223,
			'ISURI' => 236,
			"REGEX" => 237
		},
		GOTOS => {
			'BooleanLiteral' => 268,
			'RegexExpression' => 226,
			'NumericLiteralPositive' => 114,
			'DOUBLE_POSITIVE' => 115,
			'RelationalExpression' => 270,
			'ValueLogical' => 271,
			'MultiplicativeExpression' => 272,
			'NumericLiteralNegative' => 117,
			'NumericLiteralUnsigned' => 119,
			'VAR1' => 25,
			'IRI_REF' => 28,
			'NumericLiteral' => 274,
			'IRIrefOrFunction' => 275,
			'NumericExpression' => 276,
			'ConditionalOrExpression' => 284,
			'VAR2' => 29,
			'Var' => 277,
			'INTEGER' => 103,
			'Expression' => 319,
			'BrackettedExpression' => 278,
			'INTEGER_POSITIVE' => 126,
			'PrefixedName' => 34,
			'DECIMAL_POSITIVE' => 106,
			'ConditionalAndExpression' => 286,
			'PrimaryExpression' => 279,
			'PNAME_LN' => 35,
			'BuiltInCall' => 280,
			'PNAME_NS' => 36,
			'UnaryExpression' => 281,
			'AdditiveExpression' => 287,
			'IRIref' => 282,
			'RDFLiteral' => 288
		}
	},
	{#State 267
		ACTIONS => {
			"-" => 269,
			":" => 23,
			'LANGMATCHES' => 214,
			"+" => 283,
			'DATATYPE' => 215,
			'ISIRI' => 227,
			'ISLITERAL' => 217,
			'STRING' => 118,
			'INTEGER_WS' => 95,
			'INTEGER_NEGATIVE' => 98,
			"!" => 273,
			'ISBLANK' => 231,
			'SAMETERM' => 219,
			"\$" => 27,
			'DECIMAL' => 99,
			'LANG' => 220,
			'DECIMAL_NEGATIVE' => 122,
			'STR' => 232,
			'DOUBLE' => 124,
			'URI' => 6,
			'NAME' => 31,
			'INTEGER_NO_WS' => 94,
			"TRUE" => 104,
			"?" => 32,
			"FALSE" => 125,
			'BOUND' => 234,
			'DOUBLE_NEGATIVE' => 108,
			"(" => 223,
			'ISURI' => 236,
			"REGEX" => 237
		},
		GOTOS => {
			'BooleanLiteral' => 268,
			'RegexExpression' => 226,
			'NumericLiteralPositive' => 114,
			'DOUBLE_POSITIVE' => 115,
			'RelationalExpression' => 270,
			'ValueLogical' => 271,
			'MultiplicativeExpression' => 272,
			'NumericLiteralNegative' => 117,
			'NumericLiteralUnsigned' => 119,
			'VAR1' => 25,
			'IRI_REF' => 28,
			'NumericLiteral' => 274,
			'IRIrefOrFunction' => 275,
			'NumericExpression' => 276,
			'ConditionalOrExpression' => 284,
			'VAR2' => 29,
			'Var' => 277,
			'INTEGER' => 103,
			'Expression' => 320,
			'BrackettedExpression' => 278,
			'INTEGER_POSITIVE' => 126,
			'PrefixedName' => 34,
			'DECIMAL_POSITIVE' => 106,
			'ConditionalAndExpression' => 286,
			'PrimaryExpression' => 279,
			'PNAME_LN' => 35,
			'BuiltInCall' => 280,
			'PNAME_NS' => 36,
			'UnaryExpression' => 281,
			'AdditiveExpression' => 287,
			'IRIref' => 282,
			'RDFLiteral' => 288
		}
	},
	{#State 268
		DEFAULT => -193
	},
	{#State 269
		ACTIONS => {
			":" => 23,
			'LANGMATCHES' => 214,
			"+" => 116,
			'DATATYPE' => 215,
			'ISIRI' => 227,
			'ISLITERAL' => 217,
			'STRING' => 118,
			'INTEGER_WS' => 95,
			'INTEGER_NEGATIVE' => 98,
			'ISBLANK' => 231,
			"\$" => 27,
			'SAMETERM' => 219,
			'DECIMAL' => 99,
			'LANG' => 220,
			'DECIMAL_NEGATIVE' => 122,
			'STR' => 232,
			'DOUBLE' => 124,
			'URI' => 6,
			'NAME' => 31,
			'INTEGER_NO_WS' => 94,
			"TRUE" => 104,
			"?" => 32,
			"FALSE" => 125,
			'BOUND' => 234,
			'DOUBLE_NEGATIVE' => 108,
			"(" => 223,
			'ISURI' => 236,
			"REGEX" => 237
		},
		GOTOS => {
			'BooleanLiteral' => 268,
			'RegexExpression' => 226,
			'NumericLiteralPositive' => 114,
			'DOUBLE_POSITIVE' => 115,
			'NumericLiteralNegative' => 117,
			'NumericLiteralUnsigned' => 119,
			'VAR1' => 25,
			'IRI_REF' => 28,
			'NumericLiteral' => 274,
			'IRIrefOrFunction' => 275,
			'Var' => 277,
			'VAR2' => 29,
			'INTEGER' => 103,
			'BrackettedExpression' => 278,
			'INTEGER_POSITIVE' => 126,
			'PrefixedName' => 34,
			'DECIMAL_POSITIVE' => 106,
			'PrimaryExpression' => 321,
			'PNAME_LN' => 35,
			'BuiltInCall' => 280,
			'PNAME_NS' => 36,
			'IRIref' => 282,
			'RDFLiteral' => 288
		}
	},
	{#State 270
		DEFAULT => -161
	},
	{#State 271
		DEFAULT => -159,
		GOTOS => {
			'STAR-44' => 322
		}
	},
	{#State 272
		DEFAULT => -173,
		GOTOS => {
			'STAR-46' => 323
		}
	},
	{#State 273
		ACTIONS => {
			":" => 23,
			'LANGMATCHES' => 214,
			"+" => 116,
			'DATATYPE' => 215,
			'ISIRI' => 227,
			'ISLITERAL' => 217,
			'STRING' => 118,
			'INTEGER_WS' => 95,
			'INTEGER_NEGATIVE' => 98,
			'ISBLANK' => 231,
			"\$" => 27,
			'SAMETERM' => 219,
			'DECIMAL' => 99,
			'LANG' => 220,
			'DECIMAL_NEGATIVE' => 122,
			'STR' => 232,
			'DOUBLE' => 124,
			'URI' => 6,
			'NAME' => 31,
			'INTEGER_NO_WS' => 94,
			"TRUE" => 104,
			"?" => 32,
			"FALSE" => 125,
			'BOUND' => 234,
			'DOUBLE_NEGATIVE' => 108,
			"(" => 223,
			'ISURI' => 236,
			"REGEX" => 237
		},
		GOTOS => {
			'BooleanLiteral' => 268,
			'RegexExpression' => 226,
			'NumericLiteralPositive' => 114,
			'DOUBLE_POSITIVE' => 115,
			'NumericLiteralNegative' => 117,
			'NumericLiteralUnsigned' => 119,
			'VAR1' => 25,
			'IRI_REF' => 28,
			'NumericLiteral' => 274,
			'IRIrefOrFunction' => 275,
			'Var' => 277,
			'VAR2' => 29,
			'INTEGER' => 103,
			'BrackettedExpression' => 278,
			'INTEGER_POSITIVE' => 126,
			'PrefixedName' => 34,
			'DECIMAL_POSITIVE' => 106,
			'PrimaryExpression' => 324,
			'PNAME_LN' => 35,
			'BuiltInCall' => 280,
			'PNAME_NS' => 36,
			'IRIref' => 282,
			'RDFLiteral' => 288
		}
	},
	{#State 274
		DEFAULT => -192
	},
	{#State 275
		DEFAULT => -190
	},
	{#State 276
		ACTIONS => {
			"!=" => 331,
			"<" => 325,
			"=" => 332,
			">=" => 327,
			"<=" => 328,
			">" => 329
		},
		DEFAULT => -163,
		GOTOS => {
			'OPTIONAL-45' => 330,
			'RelationalExpressionExtra' => 326
		}
	},
	{#State 277
		DEFAULT => -194
	},
	{#State 278
		DEFAULT => -188
	},
	{#State 279
		DEFAULT => -187
	},
	{#State 280
		DEFAULT => -189
	},
	{#State 281
		DEFAULT => -180,
		GOTOS => {
			'STAR-47' => 333
		}
	},
	{#State 282
		ACTIONS => {
			"(" => 290
		},
		DEFAULT => -212,
		GOTOS => {
			'NIL' => 291,
			'ArgList' => 334,
			'OPTIONAL-50' => 335
		}
	},
	{#State 283
		ACTIONS => {
			":" => 23,
			'LANGMATCHES' => 214,
			"+" => 116,
			'DATATYPE' => 215,
			'ISIRI' => 227,
			'ISLITERAL' => 217,
			'STRING' => 118,
			'INTEGER_WS' => 95,
			'INTEGER_NEGATIVE' => 98,
			'ISBLANK' => 231,
			"\$" => 27,
			'SAMETERM' => 219,
			'DECIMAL' => 336,
			'LANG' => 220,
			'DECIMAL_NEGATIVE' => 122,
			'STR' => 232,
			'DOUBLE' => 339,
			'URI' => 6,
			'NAME' => 31,
			'INTEGER_NO_WS' => 94,
			"TRUE" => 104,
			"?" => 32,
			"FALSE" => 125,
			'BOUND' => 234,
			'DOUBLE_NEGATIVE' => 108,
			"(" => 223,
			'ISURI' => 236,
			"REGEX" => 237
		},
		GOTOS => {
			'BooleanLiteral' => 268,
			'RegexExpression' => 226,
			'NumericLiteralPositive' => 114,
			'DOUBLE_POSITIVE' => 115,
			'NumericLiteralNegative' => 117,
			'NumericLiteralUnsigned' => 119,
			'VAR1' => 25,
			'IRI_REF' => 28,
			'NumericLiteral' => 274,
			'IRIrefOrFunction' => 275,
			'Var' => 277,
			'VAR2' => 29,
			'INTEGER' => 337,
			'BrackettedExpression' => 278,
			'INTEGER_POSITIVE' => 126,
			'PrefixedName' => 34,
			'DECIMAL_POSITIVE' => 106,
			'PrimaryExpression' => 338,
			'PNAME_LN' => 35,
			'BuiltInCall' => 280,
			'PNAME_NS' => 36,
			'IRIref' => 282,
			'RDFLiteral' => 288
		}
	},
	{#State 284
		DEFAULT => -152
	},
	{#State 285
		ACTIONS => {
			")" => 340
		}
	},
	{#State 286
		DEFAULT => -155,
		GOTOS => {
			'STAR-42' => 341
		}
	},
	{#State 287
		DEFAULT => -171
	},
	{#State 288
		DEFAULT => -191
	},
	{#State 289
		DEFAULT => -98
	},
	{#State 290
		ACTIONS => {
			"-" => 269,
			":" => 23,
			'LANGMATCHES' => 214,
			'DATATYPE' => 215,
			'ISLITERAL' => 217,
			'INTEGER_NEGATIVE' => 98,
			"!" => 273,
			'SAMETERM' => 219,
			"\$" => 27,
			'DECIMAL' => 99,
			'LANG' => 220,
			'INTEGER_NO_WS' => 94,
			"TRUE" => 104,
			'DOUBLE_NEGATIVE' => 108,
			"(" => 223,
			"+" => 283,
			'ISIRI' => 227,
			'INTEGER_WS' => 95,
			'STRING' => 118,
			'ISBLANK' => 231,
			'DECIMAL_NEGATIVE' => 122,
			'STR' => 232,
			'NAME' => 31,
			'URI' => 6,
			'DOUBLE' => 124,
			"?" => 32,
			"FALSE" => 125,
			'BOUND' => 234,
			'ISURI' => 236,
			"REGEX" => 237
		},
		DEFAULT => -297,
		GOTOS => {
			'BooleanLiteral' => 268,
			'RelationalExpression' => 270,
			'ValueLogical' => 271,
			'MultiplicativeExpression' => 272,
			'VAR1' => 25,
			'NumericLiteral' => 274,
			'IRIrefOrFunction' => 275,
			'NumericExpression' => 276,
			'VAR2' => 29,
			'Var' => 277,
			'INTEGER' => 103,
			'BrackettedExpression' => 278,
			'PrefixedName' => 34,
			'DECIMAL_POSITIVE' => 106,
			'PrimaryExpression' => 279,
			'PNAME_LN' => 35,
			'BuiltInCall' => 280,
			'UnaryExpression' => 281,
			'IRIref' => 282,
			'NumericLiteralPositive' => 114,
			'RegexExpression' => 226,
			'DOUBLE_POSITIVE' => 115,
			'NumericLiteralNegative' => 117,
			'NumericLiteralUnsigned' => 119,
			'IRI_REF' => 28,
			'ConditionalOrExpression' => 284,
			'STAR-55' => 160,
			'Expression' => 342,
			'INTEGER_POSITIVE' => 126,
			'ConditionalAndExpression' => 286,
			'PNAME_NS' => 36,
			'AdditiveExpression' => 287,
			'RDFLiteral' => 288
		}
	},
	{#State 291
		DEFAULT => -103
	},
	{#State 292
		ACTIONS => {
			"-" => 269,
			":" => 23,
			'LANGMATCHES' => 214,
			"+" => 283,
			'DATATYPE' => 215,
			'ISIRI' => 227,
			'ISLITERAL' => 217,
			'STRING' => 118,
			'INTEGER_WS' => 95,
			'INTEGER_NEGATIVE' => 98,
			"!" => 273,
			'ISBLANK' => 231,
			'SAMETERM' => 219,
			"\$" => 27,
			'DECIMAL' => 99,
			'LANG' => 220,
			'DECIMAL_NEGATIVE' => 122,
			'STR' => 232,
			'DOUBLE' => 124,
			'URI' => 6,
			'NAME' => 31,
			'INTEGER_NO_WS' => 94,
			"TRUE" => 104,
			"?" => 32,
			"FALSE" => 125,
			'BOUND' => 234,
			'DOUBLE_NEGATIVE' => 108,
			"(" => 223,
			'ISURI' => 236,
			"REGEX" => 237
		},
		GOTOS => {
			'BooleanLiteral' => 268,
			'RegexExpression' => 226,
			'NumericLiteralPositive' => 114,
			'DOUBLE_POSITIVE' => 115,
			'RelationalExpression' => 270,
			'ValueLogical' => 271,
			'MultiplicativeExpression' => 272,
			'NumericLiteralNegative' => 117,
			'NumericLiteralUnsigned' => 119,
			'VAR1' => 25,
			'IRI_REF' => 28,
			'NumericLiteral' => 274,
			'IRIrefOrFunction' => 275,
			'NumericExpression' => 276,
			'ConditionalOrExpression' => 284,
			'VAR2' => 29,
			'Var' => 277,
			'INTEGER' => 103,
			'Expression' => 343,
			'BrackettedExpression' => 278,
			'INTEGER_POSITIVE' => 126,
			'PrefixedName' => 34,
			'DECIMAL_POSITIVE' => 106,
			'ConditionalAndExpression' => 286,
			'PrimaryExpression' => 279,
			'PNAME_LN' => 35,
			'BuiltInCall' => 280,
			'PNAME_NS' => 36,
			'UnaryExpression' => 281,
			'AdditiveExpression' => 287,
			'IRIref' => 282,
			'RDFLiteral' => 288
		}
	},
	{#State 293
		ACTIONS => {
			"-" => 269,
			":" => 23,
			'LANGMATCHES' => 214,
			"+" => 283,
			'DATATYPE' => 215,
			'ISIRI' => 227,
			'ISLITERAL' => 217,
			'STRING' => 118,
			'INTEGER_WS' => 95,
			'INTEGER_NEGATIVE' => 98,
			"!" => 273,
			'ISBLANK' => 231,
			'SAMETERM' => 219,
			"\$" => 27,
			'DECIMAL' => 99,
			'LANG' => 220,
			'DECIMAL_NEGATIVE' => 122,
			'STR' => 232,
			'DOUBLE' => 124,
			'URI' => 6,
			'NAME' => 31,
			'INTEGER_NO_WS' => 94,
			"TRUE" => 104,
			"?" => 32,
			"FALSE" => 125,
			'BOUND' => 234,
			'DOUBLE_NEGATIVE' => 108,
			"(" => 223,
			'ISURI' => 236,
			"REGEX" => 237
		},
		GOTOS => {
			'BooleanLiteral' => 268,
			'RegexExpression' => 226,
			'NumericLiteralPositive' => 114,
			'DOUBLE_POSITIVE' => 115,
			'RelationalExpression' => 270,
			'ValueLogical' => 271,
			'MultiplicativeExpression' => 272,
			'NumericLiteralNegative' => 117,
			'NumericLiteralUnsigned' => 119,
			'VAR1' => 25,
			'IRI_REF' => 28,
			'NumericLiteral' => 274,
			'IRIrefOrFunction' => 275,
			'NumericExpression' => 276,
			'ConditionalOrExpression' => 284,
			'VAR2' => 29,
			'Var' => 277,
			'INTEGER' => 103,
			'Expression' => 344,
			'BrackettedExpression' => 278,
			'INTEGER_POSITIVE' => 126,
			'PrefixedName' => 34,
			'DECIMAL_POSITIVE' => 106,
			'ConditionalAndExpression' => 286,
			'PrimaryExpression' => 279,
			'PNAME_LN' => 35,
			'BuiltInCall' => 280,
			'PNAME_NS' => 36,
			'UnaryExpression' => 281,
			'AdditiveExpression' => 287,
			'IRIref' => 282,
			'RDFLiteral' => 288
		}
	},
	{#State 294
		ACTIONS => {
			"-" => 269,
			":" => 23,
			'LANGMATCHES' => 214,
			"+" => 283,
			'DATATYPE' => 215,
			'ISIRI' => 227,
			'ISLITERAL' => 217,
			'STRING' => 118,
			'INTEGER_WS' => 95,
			'INTEGER_NEGATIVE' => 98,
			"!" => 273,
			'ISBLANK' => 231,
			'SAMETERM' => 219,
			"\$" => 27,
			'DECIMAL' => 99,
			'LANG' => 220,
			'DECIMAL_NEGATIVE' => 122,
			'STR' => 232,
			'DOUBLE' => 124,
			'URI' => 6,
			'NAME' => 31,
			'INTEGER_NO_WS' => 94,
			"TRUE" => 104,
			"?" => 32,
			"FALSE" => 125,
			'BOUND' => 234,
			'DOUBLE_NEGATIVE' => 108,
			"(" => 223,
			'ISURI' => 236,
			"REGEX" => 237
		},
		GOTOS => {
			'BooleanLiteral' => 268,
			'RegexExpression' => 226,
			'NumericLiteralPositive' => 114,
			'DOUBLE_POSITIVE' => 115,
			'RelationalExpression' => 270,
			'ValueLogical' => 271,
			'MultiplicativeExpression' => 272,
			'NumericLiteralNegative' => 117,
			'NumericLiteralUnsigned' => 119,
			'VAR1' => 25,
			'IRI_REF' => 28,
			'NumericLiteral' => 274,
			'IRIrefOrFunction' => 275,
			'NumericExpression' => 276,
			'ConditionalOrExpression' => 284,
			'VAR2' => 29,
			'Var' => 277,
			'INTEGER' => 103,
			'Expression' => 345,
			'BrackettedExpression' => 278,
			'INTEGER_POSITIVE' => 126,
			'PrefixedName' => 34,
			'DECIMAL_POSITIVE' => 106,
			'ConditionalAndExpression' => 286,
			'PrimaryExpression' => 279,
			'PNAME_LN' => 35,
			'BuiltInCall' => 280,
			'PNAME_NS' => 36,
			'UnaryExpression' => 281,
			'AdditiveExpression' => 287,
			'IRIref' => 282,
			'RDFLiteral' => 288
		}
	},
	{#State 295
		ACTIONS => {
			"?" => 32,
			"\$" => 27
		},
		GOTOS => {
			'VAR1' => 25,
			'Var' => 346,
			'VAR2' => 29
		}
	},
	{#State 296
		ACTIONS => {
			"-" => 269,
			":" => 23,
			'LANGMATCHES' => 214,
			"+" => 283,
			'DATATYPE' => 215,
			'ISIRI' => 227,
			'ISLITERAL' => 217,
			'STRING' => 118,
			'INTEGER_WS' => 95,
			'INTEGER_NEGATIVE' => 98,
			"!" => 273,
			'ISBLANK' => 231,
			'SAMETERM' => 219,
			"\$" => 27,
			'DECIMAL' => 99,
			'LANG' => 220,
			'DECIMAL_NEGATIVE' => 122,
			'STR' => 232,
			'DOUBLE' => 124,
			'URI' => 6,
			'NAME' => 31,
			'INTEGER_NO_WS' => 94,
			"TRUE" => 104,
			"?" => 32,
			"FALSE" => 125,
			'BOUND' => 234,
			'DOUBLE_NEGATIVE' => 108,
			"(" => 223,
			'ISURI' => 236,
			"REGEX" => 237
		},
		GOTOS => {
			'BooleanLiteral' => 268,
			'RegexExpression' => 226,
			'NumericLiteralPositive' => 114,
			'DOUBLE_POSITIVE' => 115,
			'RelationalExpression' => 270,
			'ValueLogical' => 271,
			'MultiplicativeExpression' => 272,
			'NumericLiteralNegative' => 117,
			'NumericLiteralUnsigned' => 119,
			'VAR1' => 25,
			'IRI_REF' => 28,
			'NumericLiteral' => 274,
			'IRIrefOrFunction' => 275,
			'NumericExpression' => 276,
			'ConditionalOrExpression' => 284,
			'VAR2' => 29,
			'Var' => 277,
			'INTEGER' => 103,
			'Expression' => 347,
			'BrackettedExpression' => 278,
			'INTEGER_POSITIVE' => 126,
			'PrefixedName' => 34,
			'DECIMAL_POSITIVE' => 106,
			'ConditionalAndExpression' => 286,
			'PrimaryExpression' => 279,
			'PNAME_LN' => 35,
			'BuiltInCall' => 280,
			'PNAME_NS' => 36,
			'UnaryExpression' => 281,
			'AdditiveExpression' => 287,
			'IRIref' => 282,
			'RDFLiteral' => 288
		}
	},
	{#State 297
		ACTIONS => {
			"-" => 269,
			":" => 23,
			'LANGMATCHES' => 214,
			"+" => 283,
			'DATATYPE' => 215,
			'ISIRI' => 227,
			'ISLITERAL' => 217,
			'STRING' => 118,
			'INTEGER_WS' => 95,
			'INTEGER_NEGATIVE' => 98,
			"!" => 273,
			'ISBLANK' => 231,
			'SAMETERM' => 219,
			"\$" => 27,
			'DECIMAL' => 99,
			'LANG' => 220,
			'DECIMAL_NEGATIVE' => 122,
			'STR' => 232,
			'DOUBLE' => 124,
			'URI' => 6,
			'NAME' => 31,
			'INTEGER_NO_WS' => 94,
			"TRUE" => 104,
			"?" => 32,
			"FALSE" => 125,
			'BOUND' => 234,
			'DOUBLE_NEGATIVE' => 108,
			"(" => 223,
			'ISURI' => 236,
			"REGEX" => 237
		},
		GOTOS => {
			'BooleanLiteral' => 268,
			'RegexExpression' => 226,
			'NumericLiteralPositive' => 114,
			'DOUBLE_POSITIVE' => 115,
			'RelationalExpression' => 270,
			'ValueLogical' => 271,
			'MultiplicativeExpression' => 272,
			'NumericLiteralNegative' => 117,
			'NumericLiteralUnsigned' => 119,
			'VAR1' => 25,
			'IRI_REF' => 28,
			'NumericLiteral' => 274,
			'IRIrefOrFunction' => 275,
			'NumericExpression' => 276,
			'ConditionalOrExpression' => 284,
			'VAR2' => 29,
			'Var' => 277,
			'INTEGER' => 103,
			'Expression' => 348,
			'BrackettedExpression' => 278,
			'INTEGER_POSITIVE' => 126,
			'PrefixedName' => 34,
			'DECIMAL_POSITIVE' => 106,
			'ConditionalAndExpression' => 286,
			'PrimaryExpression' => 279,
			'PNAME_LN' => 35,
			'BuiltInCall' => 280,
			'PNAME_NS' => 36,
			'UnaryExpression' => 281,
			'AdditiveExpression' => 287,
			'IRIref' => 282,
			'RDFLiteral' => 288
		}
	},
	{#State 298
		DEFAULT => -65
	},
	{#State 299
		DEFAULT => -66
	},
	{#State 300
		DEFAULT => -56
	},
	{#State 301
		DEFAULT => -53
	},
	{#State 302
		DEFAULT => -51
	},
	{#State 303
		DEFAULT => -55
	},
	{#State 304
		DEFAULT => -119
	},
	{#State 305
		ACTIONS => {
			":" => 23,
			'URI' => 6,
			'NAME' => 31,
			"?" => 32,
			"a" => 153,
			"\$" => 27
		},
		DEFAULT => -117,
		GOTOS => {
			'OPTIONAL-34' => 351,
			'Verb' => 350,
			'PrefixedName' => 34,
			'PAREN-33' => 349,
			'VAR1' => 25,
			'PNAME_LN' => 35,
			'PNAME_NS' => 36,
			'IRI_REF' => 28,
			'IRIref' => 38,
			'VarOrIRIref' => 155,
			'VAR2' => 29,
			'Var' => 30
		}
	},
	{#State 306
		ACTIONS => {
			":" => 23,
			"+" => 116,
			'STRING' => 118,
			'INTEGER_WS' => 95,
			'INTEGER_NEGATIVE' => 98,
			"\$" => 27,
			'DECIMAL' => 99,
			"[" => 100,
			'DECIMAL_NEGATIVE' => 122,
			'INTEGER_NO_WS' => 94,
			"TRUE" => 104,
			'NAME' => 31,
			'URI' => 6,
			'DOUBLE' => 124,
			"?" => 32,
			"FALSE" => 125,
			'DOUBLE_NEGATIVE' => 108,
			"(" => 109,
			"_:" => 132
		},
		GOTOS => {
			'GraphNode' => 196,
			'BooleanLiteral' => 97,
			'NumericLiteralPositive' => 114,
			'DOUBLE_POSITIVE' => 115,
			'NumericLiteralNegative' => 117,
			'NumericLiteralUnsigned' => 119,
			'NIL' => 120,
			'VAR1' => 25,
			'IRI_REF' => 28,
			'Object' => 352,
			'NumericLiteral' => 101,
			'VAR2' => 29,
			'Var' => 102,
			'VarOrTerm' => 159,
			'INTEGER' => 103,
			'INTEGER_POSITIVE' => 126,
			'ANON' => 105,
			'TriplesNode' => 162,
			'GraphTerm' => 128,
			'BLANK_NODE_LABEL' => 127,
			'PrefixedName' => 34,
			'DECIMAL_POSITIVE' => 106,
			'PNAME_LN' => 35,
			'BlankNode' => 130,
			'PNAME_NS' => 36,
			'IRIref' => 111,
			'BlankNodePropertyList' => 112,
			'Collection' => 113,
			'RDFLiteral' => 131
		}
	},
	{#State 307
		DEFAULT => -126
	},
	{#State 308
		ACTIONS => {
			'NAME' => 354
		},
		GOTOS => {
			'PLUS-52' => 353
		}
	},
	{#State 309
		DEFAULT => -256
	},
	{#State 310
		ACTIONS => {
			"UNION" => 355
		},
		DEFAULT => -93,
		GOTOS => {
			'PAREN-25' => 356
		}
	},
	{#State 311
		ACTIONS => {
			"{" => 143
		},
		GOTOS => {
			'GroupGraphPattern' => 357
		}
	},
	{#State 312
		DEFAULT => -69
	},
	{#State 313
		ACTIONS => {
			":" => 23,
			"+" => 116,
			'STRING' => 118,
			'INTEGER_WS' => 95,
			'INTEGER_NEGATIVE' => 98,
			"\$" => 27,
			'DECIMAL' => 99,
			"[" => 100,
			'DECIMAL_NEGATIVE' => 122,
			'DOUBLE' => 124,
			'INTEGER_NO_WS' => 94,
			"TRUE" => 104,
			'NAME' => 31,
			'URI' => 6,
			"?" => 32,
			"FALSE" => 125,
			'DOUBLE_NEGATIVE' => 108,
			"(" => 109,
			"_:" => 132
		},
		DEFAULT => -72,
		GOTOS => {
			'BooleanLiteral' => 97,
			'OPTIONAL-19' => 359,
			'NumericLiteralPositive' => 114,
			'DOUBLE_POSITIVE' => 115,
			'NumericLiteralNegative' => 117,
			'NumericLiteralUnsigned' => 119,
			'NIL' => 120,
			'VAR1' => 25,
			'TriplesSameSubject' => 186,
			'IRI_REF' => 28,
			'TriplesBlock' => 358,
			'NumericLiteral' => 101,
			'VAR2' => 29,
			'Var' => 102,
			'VarOrTerm' => 123,
			'INTEGER' => 103,
			'INTEGER_POSITIVE' => 126,
			'ANON' => 105,
			'TriplesNode' => 129,
			'GraphTerm' => 128,
			'BLANK_NODE_LABEL' => 127,
			'PrefixedName' => 34,
			'DECIMAL_POSITIVE' => 106,
			'PNAME_LN' => 35,
			'BlankNode' => 130,
			'PNAME_NS' => 36,
			'IRIref' => 111,
			'BlankNodePropertyList' => 112,
			'Collection' => 113,
			'RDFLiteral' => 131
		}
	},
	{#State 314
		DEFAULT => -94
	},
	{#State 315
		DEFAULT => -88
	},
	{#State 316
		ACTIONS => {
			"," => 360
		}
	},
	{#State 317
		ACTIONS => {
			")" => 361
		}
	},
	{#State 318
		ACTIONS => {
			")" => 362
		}
	},
	{#State 319
		ACTIONS => {
			"," => 363
		}
	},
	{#State 320
		ACTIONS => {
			")" => 364
		}
	},
	{#State 321
		DEFAULT => -186
	},
	{#State 322
		ACTIONS => {
			"&&" => 365
		},
		DEFAULT => -160,
		GOTOS => {
			'PAREN-43' => 366
		}
	},
	{#State 323
		ACTIONS => {
			"-" => 367,
			"+" => 370,
			'INTEGER_NEGATIVE' => 98,
			'DECIMAL_NEGATIVE' => 122,
			'DOUBLE_NEGATIVE' => 108
		},
		DEFAULT => -174,
		GOTOS => {
			'NumericLiteralPositive' => 369,
			'DOUBLE_POSITIVE' => 115,
			'AdditiveExpressionExtra' => 368,
			'INTEGER_POSITIVE' => 126,
			'NumericLiteralNegative' => 371,
			'DECIMAL_POSITIVE' => 106
		}
	},
	{#State 324
		DEFAULT => -184
	},
	{#State 325
		ACTIONS => {
			"-" => 269,
			":" => 23,
			'LANGMATCHES' => 214,
			"+" => 283,
			'DATATYPE' => 215,
			'ISIRI' => 227,
			'ISLITERAL' => 217,
			'STRING' => 118,
			'INTEGER_WS' => 95,
			'INTEGER_NEGATIVE' => 98,
			"!" => 273,
			'ISBLANK' => 231,
			'SAMETERM' => 219,
			"\$" => 27,
			'DECIMAL' => 99,
			'LANG' => 220,
			'DECIMAL_NEGATIVE' => 122,
			'STR' => 232,
			'DOUBLE' => 124,
			'URI' => 6,
			'NAME' => 31,
			'INTEGER_NO_WS' => 94,
			"TRUE" => 104,
			"?" => 32,
			"FALSE" => 125,
			'BOUND' => 234,
			'DOUBLE_NEGATIVE' => 108,
			"(" => 223,
			'ISURI' => 236,
			"REGEX" => 237
		},
		GOTOS => {
			'BooleanLiteral' => 268,
			'RegexExpression' => 226,
			'NumericLiteralPositive' => 114,
			'DOUBLE_POSITIVE' => 115,
			'MultiplicativeExpression' => 272,
			'NumericLiteralNegative' => 117,
			'NumericLiteralUnsigned' => 119,
			'VAR1' => 25,
			'IRI_REF' => 28,
			'NumericLiteral' => 274,
			'IRIrefOrFunction' => 275,
			'NumericExpression' => 372,
			'Var' => 277,
			'VAR2' => 29,
			'INTEGER' => 103,
			'BrackettedExpression' => 278,
			'INTEGER_POSITIVE' => 126,
			'PrefixedName' => 34,
			'DECIMAL_POSITIVE' => 106,
			'PrimaryExpression' => 279,
			'PNAME_LN' => 35,
			'BuiltInCall' => 280,
			'PNAME_NS' => 36,
			'UnaryExpression' => 281,
			'AdditiveExpression' => 287,
			'IRIref' => 282,
			'RDFLiteral' => 288
		}
	},
	{#State 326
		DEFAULT => -162
	},
	{#State 327
		ACTIONS => {
			"-" => 269,
			":" => 23,
			'LANGMATCHES' => 214,
			"+" => 283,
			'DATATYPE' => 215,
			'ISIRI' => 227,
			'ISLITERAL' => 217,
			'STRING' => 118,
			'INTEGER_WS' => 95,
			'INTEGER_NEGATIVE' => 98,
			"!" => 273,
			'ISBLANK' => 231,
			'SAMETERM' => 219,
			"\$" => 27,
			'DECIMAL' => 99,
			'LANG' => 220,
			'DECIMAL_NEGATIVE' => 122,
			'STR' => 232,
			'DOUBLE' => 124,
			'URI' => 6,
			'NAME' => 31,
			'INTEGER_NO_WS' => 94,
			"TRUE" => 104,
			"?" => 32,
			"FALSE" => 125,
			'BOUND' => 234,
			'DOUBLE_NEGATIVE' => 108,
			"(" => 223,
			'ISURI' => 236,
			"REGEX" => 237
		},
		GOTOS => {
			'BooleanLiteral' => 268,
			'RegexExpression' => 226,
			'NumericLiteralPositive' => 114,
			'DOUBLE_POSITIVE' => 115,
			'MultiplicativeExpression' => 272,
			'NumericLiteralNegative' => 117,
			'NumericLiteralUnsigned' => 119,
			'VAR1' => 25,
			'IRI_REF' => 28,
			'NumericLiteral' => 274,
			'IRIrefOrFunction' => 275,
			'NumericExpression' => 373,
			'Var' => 277,
			'VAR2' => 29,
			'INTEGER' => 103,
			'BrackettedExpression' => 278,
			'INTEGER_POSITIVE' => 126,
			'PrefixedName' => 34,
			'DECIMAL_POSITIVE' => 106,
			'PrimaryExpression' => 279,
			'PNAME_LN' => 35,
			'BuiltInCall' => 280,
			'PNAME_NS' => 36,
			'UnaryExpression' => 281,
			'AdditiveExpression' => 287,
			'IRIref' => 282,
			'RDFLiteral' => 288
		}
	},
	{#State 328
		ACTIONS => {
			"-" => 269,
			":" => 23,
			'LANGMATCHES' => 214,
			"+" => 283,
			'DATATYPE' => 215,
			'ISIRI' => 227,
			'ISLITERAL' => 217,
			'STRING' => 118,
			'INTEGER_WS' => 95,
			'INTEGER_NEGATIVE' => 98,
			"!" => 273,
			'ISBLANK' => 231,
			'SAMETERM' => 219,
			"\$" => 27,
			'DECIMAL' => 99,
			'LANG' => 220,
			'DECIMAL_NEGATIVE' => 122,
			'STR' => 232,
			'DOUBLE' => 124,
			'URI' => 6,
			'NAME' => 31,
			'INTEGER_NO_WS' => 94,
			"TRUE" => 104,
			"?" => 32,
			"FALSE" => 125,
			'BOUND' => 234,
			'DOUBLE_NEGATIVE' => 108,
			"(" => 223,
			'ISURI' => 236,
			"REGEX" => 237
		},
		GOTOS => {
			'BooleanLiteral' => 268,
			'RegexExpression' => 226,
			'NumericLiteralPositive' => 114,
			'DOUBLE_POSITIVE' => 115,
			'MultiplicativeExpression' => 272,
			'NumericLiteralNegative' => 117,
			'NumericLiteralUnsigned' => 119,
			'VAR1' => 25,
			'IRI_REF' => 28,
			'NumericLiteral' => 274,
			'IRIrefOrFunction' => 275,
			'NumericExpression' => 374,
			'Var' => 277,
			'VAR2' => 29,
			'INTEGER' => 103,
			'BrackettedExpression' => 278,
			'INTEGER_POSITIVE' => 126,
			'PrefixedName' => 34,
			'DECIMAL_POSITIVE' => 106,
			'PrimaryExpression' => 279,
			'PNAME_LN' => 35,
			'BuiltInCall' => 280,
			'PNAME_NS' => 36,
			'UnaryExpression' => 281,
			'AdditiveExpression' => 287,
			'IRIref' => 282,
			'RDFLiteral' => 288
		}
	},
	{#State 329
		ACTIONS => {
			"-" => 269,
			":" => 23,
			'LANGMATCHES' => 214,
			"+" => 283,
			'DATATYPE' => 215,
			'ISIRI' => 227,
			'ISLITERAL' => 217,
			'STRING' => 118,
			'INTEGER_WS' => 95,
			'INTEGER_NEGATIVE' => 98,
			"!" => 273,
			'ISBLANK' => 231,
			'SAMETERM' => 219,
			"\$" => 27,
			'DECIMAL' => 99,
			'LANG' => 220,
			'DECIMAL_NEGATIVE' => 122,
			'STR' => 232,
			'DOUBLE' => 124,
			'URI' => 6,
			'NAME' => 31,
			'INTEGER_NO_WS' => 94,
			"TRUE" => 104,
			"?" => 32,
			"FALSE" => 125,
			'BOUND' => 234,
			'DOUBLE_NEGATIVE' => 108,
			"(" => 223,
			'ISURI' => 236,
			"REGEX" => 237
		},
		GOTOS => {
			'BooleanLiteral' => 268,
			'RegexExpression' => 226,
			'NumericLiteralPositive' => 114,
			'DOUBLE_POSITIVE' => 115,
			'MultiplicativeExpression' => 272,
			'NumericLiteralNegative' => 117,
			'NumericLiteralUnsigned' => 119,
			'VAR1' => 25,
			'IRI_REF' => 28,
			'NumericLiteral' => 274,
			'IRIrefOrFunction' => 275,
			'NumericExpression' => 375,
			'Var' => 277,
			'VAR2' => 29,
			'INTEGER' => 103,
			'BrackettedExpression' => 278,
			'INTEGER_POSITIVE' => 126,
			'PrefixedName' => 34,
			'DECIMAL_POSITIVE' => 106,
			'PrimaryExpression' => 279,
			'PNAME_LN' => 35,
			'BuiltInCall' => 280,
			'PNAME_NS' => 36,
			'UnaryExpression' => 281,
			'AdditiveExpression' => 287,
			'IRIref' => 282,
			'RDFLiteral' => 288
		}
	},
	{#State 330
		DEFAULT => -164
	},
	{#State 331
		ACTIONS => {
			"-" => 269,
			":" => 23,
			'LANGMATCHES' => 214,
			"+" => 283,
			'DATATYPE' => 215,
			'ISIRI' => 227,
			'ISLITERAL' => 217,
			'STRING' => 118,
			'INTEGER_WS' => 95,
			'INTEGER_NEGATIVE' => 98,
			"!" => 273,
			'ISBLANK' => 231,
			'SAMETERM' => 219,
			"\$" => 27,
			'DECIMAL' => 99,
			'LANG' => 220,
			'DECIMAL_NEGATIVE' => 122,
			'STR' => 232,
			'DOUBLE' => 124,
			'URI' => 6,
			'NAME' => 31,
			'INTEGER_NO_WS' => 94,
			"TRUE" => 104,
			"?" => 32,
			"FALSE" => 125,
			'BOUND' => 234,
			'DOUBLE_NEGATIVE' => 108,
			"(" => 223,
			'ISURI' => 236,
			"REGEX" => 237
		},
		GOTOS => {
			'BooleanLiteral' => 268,
			'RegexExpression' => 226,
			'NumericLiteralPositive' => 114,
			'DOUBLE_POSITIVE' => 115,
			'MultiplicativeExpression' => 272,
			'NumericLiteralNegative' => 117,
			'NumericLiteralUnsigned' => 119,
			'VAR1' => 25,
			'IRI_REF' => 28,
			'NumericLiteral' => 274,
			'IRIrefOrFunction' => 275,
			'NumericExpression' => 376,
			'Var' => 277,
			'VAR2' => 29,
			'INTEGER' => 103,
			'BrackettedExpression' => 278,
			'INTEGER_POSITIVE' => 126,
			'PrefixedName' => 34,
			'DECIMAL_POSITIVE' => 106,
			'PrimaryExpression' => 279,
			'PNAME_LN' => 35,
			'BuiltInCall' => 280,
			'PNAME_NS' => 36,
			'UnaryExpression' => 281,
			'AdditiveExpression' => 287,
			'IRIref' => 282,
			'RDFLiteral' => 288
		}
	},
	{#State 332
		ACTIONS => {
			"-" => 269,
			":" => 23,
			'LANGMATCHES' => 214,
			"+" => 283,
			'DATATYPE' => 215,
			'ISIRI' => 227,
			'ISLITERAL' => 217,
			'STRING' => 118,
			'INTEGER_WS' => 95,
			'INTEGER_NEGATIVE' => 98,
			"!" => 273,
			'ISBLANK' => 231,
			'SAMETERM' => 219,
			"\$" => 27,
			'DECIMAL' => 99,
			'LANG' => 220,
			'DECIMAL_NEGATIVE' => 122,
			'STR' => 232,
			'DOUBLE' => 124,
			'URI' => 6,
			'NAME' => 31,
			'INTEGER_NO_WS' => 94,
			"TRUE" => 104,
			"?" => 32,
			"FALSE" => 125,
			'BOUND' => 234,
			'DOUBLE_NEGATIVE' => 108,
			"(" => 223,
			'ISURI' => 236,
			"REGEX" => 237
		},
		GOTOS => {
			'BooleanLiteral' => 268,
			'RegexExpression' => 226,
			'NumericLiteralPositive' => 114,
			'DOUBLE_POSITIVE' => 115,
			'MultiplicativeExpression' => 272,
			'NumericLiteralNegative' => 117,
			'NumericLiteralUnsigned' => 119,
			'VAR1' => 25,
			'IRI_REF' => 28,
			'NumericLiteral' => 274,
			'IRIrefOrFunction' => 275,
			'NumericExpression' => 377,
			'Var' => 277,
			'VAR2' => 29,
			'INTEGER' => 103,
			'BrackettedExpression' => 278,
			'INTEGER_POSITIVE' => 126,
			'PrefixedName' => 34,
			'DECIMAL_POSITIVE' => 106,
			'PrimaryExpression' => 279,
			'PNAME_LN' => 35,
			'BuiltInCall' => 280,
			'PNAME_NS' => 36,
			'UnaryExpression' => 281,
			'AdditiveExpression' => 287,
			'IRIref' => 282,
			'RDFLiteral' => 288
		}
	},
	{#State 333
		ACTIONS => {
			"*" => 378,
			"/" => 380
		},
		DEFAULT => -181,
		GOTOS => {
			'MultiplicativeExpressionExtra' => 379
		}
	},
	{#State 334
		DEFAULT => -211
	},
	{#State 335
		DEFAULT => -213
	},
	{#State 336
		DEFAULT => -223
	},
	{#State 337
		DEFAULT => -222
	},
	{#State 338
		DEFAULT => -185
	},
	{#State 339
		DEFAULT => -224
	},
	{#State 340
		DEFAULT => -195
	},
	{#State 341
		ACTIONS => {
			"||" => 382
		},
		DEFAULT => -156,
		GOTOS => {
			'PAREN-41' => 381
		}
	},
	{#State 342
		DEFAULT => -101,
		GOTOS => {
			'STAR-28' => 383
		}
	},
	{#State 343
		ACTIONS => {
			")" => 384
		}
	},
	{#State 344
		ACTIONS => {
			")" => 385
		}
	},
	{#State 345
		ACTIONS => {
			")" => 386
		}
	},
	{#State 346
		ACTIONS => {
			")" => 387
		}
	},
	{#State 347
		ACTIONS => {
			")" => 388
		}
	},
	{#State 348
		ACTIONS => {
			"," => 389
		}
	},
	{#State 349
		DEFAULT => -116
	},
	{#State 350
		ACTIONS => {
			":" => 23,
			"+" => 116,
			'STRING' => 118,
			'INTEGER_WS' => 95,
			'INTEGER_NEGATIVE' => 98,
			"\$" => 27,
			'DECIMAL' => 99,
			"[" => 100,
			'DECIMAL_NEGATIVE' => 122,
			'INTEGER_NO_WS' => 94,
			"TRUE" => 104,
			'NAME' => 31,
			'URI' => 6,
			'DOUBLE' => 124,
			"?" => 32,
			"FALSE" => 125,
			'DOUBLE_NEGATIVE' => 108,
			"(" => 109,
			"_:" => 132
		},
		GOTOS => {
			'GraphNode' => 196,
			'BooleanLiteral' => 97,
			'NumericLiteralPositive' => 114,
			'DOUBLE_POSITIVE' => 115,
			'NumericLiteralNegative' => 117,
			'NumericLiteralUnsigned' => 119,
			'NIL' => 120,
			'VAR1' => 25,
			'IRI_REF' => 28,
			'Object' => 197,
			'NumericLiteral' => 101,
			'VAR2' => 29,
			'Var' => 102,
			'VarOrTerm' => 159,
			'INTEGER' => 103,
			'ObjectList' => 390,
			'INTEGER_POSITIVE' => 126,
			'ANON' => 105,
			'TriplesNode' => 162,
			'GraphTerm' => 128,
			'BLANK_NODE_LABEL' => 127,
			'PrefixedName' => 34,
			'DECIMAL_POSITIVE' => 106,
			'PNAME_LN' => 35,
			'BlankNode' => 130,
			'PNAME_NS' => 36,
			'IRIref' => 111,
			'BlankNodePropertyList' => 112,
			'Collection' => 113,
			'RDFLiteral' => 131
		}
	},
	{#State 351
		DEFAULT => -118
	},
	{#State 352
		DEFAULT => -125
	},
	{#State 353
		ACTIONS => {
			'NAME' => 391
		},
		DEFAULT => -255
	},
	{#State 354
		DEFAULT => -254
	},
	{#State 355
		ACTIONS => {
			"{" => 143
		},
		GOTOS => {
			'GroupGraphPattern' => 392
		}
	},
	{#State 356
		DEFAULT => -91
	},
	{#State 357
		DEFAULT => -89
	},
	{#State 358
		DEFAULT => -71
	},
	{#State 359
		DEFAULT => -73
	},
	{#State 360
		ACTIONS => {
			"-" => 269,
			":" => 23,
			'LANGMATCHES' => 214,
			"+" => 283,
			'DATATYPE' => 215,
			'ISIRI' => 227,
			'ISLITERAL' => 217,
			'STRING' => 118,
			'INTEGER_WS' => 95,
			'INTEGER_NEGATIVE' => 98,
			"!" => 273,
			'ISBLANK' => 231,
			'SAMETERM' => 219,
			"\$" => 27,
			'DECIMAL' => 99,
			'LANG' => 220,
			'DECIMAL_NEGATIVE' => 122,
			'STR' => 232,
			'DOUBLE' => 124,
			'URI' => 6,
			'NAME' => 31,
			'INTEGER_NO_WS' => 94,
			"TRUE" => 104,
			"?" => 32,
			"FALSE" => 125,
			'BOUND' => 234,
			'DOUBLE_NEGATIVE' => 108,
			"(" => 223,
			'ISURI' => 236,
			"REGEX" => 237
		},
		GOTOS => {
			'BooleanLiteral' => 268,
			'RegexExpression' => 226,
			'NumericLiteralPositive' => 114,
			'DOUBLE_POSITIVE' => 115,
			'RelationalExpression' => 270,
			'ValueLogical' => 271,
			'MultiplicativeExpression' => 272,
			'NumericLiteralNegative' => 117,
			'NumericLiteralUnsigned' => 119,
			'VAR1' => 25,
			'IRI_REF' => 28,
			'NumericLiteral' => 274,
			'IRIrefOrFunction' => 275,
			'NumericExpression' => 276,
			'ConditionalOrExpression' => 284,
			'VAR2' => 29,
			'Var' => 277,
			'INTEGER' => 103,
			'Expression' => 393,
			'BrackettedExpression' => 278,
			'INTEGER_POSITIVE' => 126,
			'PrefixedName' => 34,
			'DECIMAL_POSITIVE' => 106,
			'ConditionalAndExpression' => 286,
			'PrimaryExpression' => 279,
			'PNAME_LN' => 35,
			'BuiltInCall' => 280,
			'PNAME_NS' => 36,
			'UnaryExpression' => 281,
			'AdditiveExpression' => 287,
			'IRIref' => 282,
			'RDFLiteral' => 288
		}
	},
	{#State 361
		DEFAULT => -199
	},
	{#State 362
		DEFAULT => -205
	},
	{#State 363
		ACTIONS => {
			"-" => 269,
			":" => 23,
			'LANGMATCHES' => 214,
			"+" => 283,
			'DATATYPE' => 215,
			'ISIRI' => 227,
			'ISLITERAL' => 217,
			'STRING' => 118,
			'INTEGER_WS' => 95,
			'INTEGER_NEGATIVE' => 98,
			"!" => 273,
			'ISBLANK' => 231,
			'SAMETERM' => 219,
			"\$" => 27,
			'DECIMAL' => 99,
			'LANG' => 220,
			'DECIMAL_NEGATIVE' => 122,
			'STR' => 232,
			'DOUBLE' => 124,
			'URI' => 6,
			'NAME' => 31,
			'INTEGER_NO_WS' => 94,
			"TRUE" => 104,
			"?" => 32,
			"FALSE" => 125,
			'BOUND' => 234,
			'DOUBLE_NEGATIVE' => 108,
			"(" => 223,
			'ISURI' => 236,
			"REGEX" => 237
		},
		GOTOS => {
			'BooleanLiteral' => 268,
			'RegexExpression' => 226,
			'NumericLiteralPositive' => 114,
			'DOUBLE_POSITIVE' => 115,
			'RelationalExpression' => 270,
			'ValueLogical' => 271,
			'MultiplicativeExpression' => 272,
			'NumericLiteralNegative' => 117,
			'NumericLiteralUnsigned' => 119,
			'VAR1' => 25,
			'IRI_REF' => 28,
			'NumericLiteral' => 274,
			'IRIrefOrFunction' => 275,
			'NumericExpression' => 276,
			'ConditionalOrExpression' => 284,
			'VAR2' => 29,
			'Var' => 277,
			'INTEGER' => 103,
			'Expression' => 394,
			'BrackettedExpression' => 278,
			'INTEGER_POSITIVE' => 126,
			'PrefixedName' => 34,
			'DECIMAL_POSITIVE' => 106,
			'ConditionalAndExpression' => 286,
			'PrimaryExpression' => 279,
			'PNAME_LN' => 35,
			'BuiltInCall' => 280,
			'PNAME_NS' => 36,
			'UnaryExpression' => 281,
			'AdditiveExpression' => 287,
			'IRIref' => 282,
			'RDFLiteral' => 288
		}
	},
	{#State 364
		DEFAULT => -197
	},
	{#State 365
		ACTIONS => {
			"-" => 269,
			":" => 23,
			'LANGMATCHES' => 214,
			"+" => 283,
			'DATATYPE' => 215,
			'ISIRI' => 227,
			'ISLITERAL' => 217,
			'STRING' => 118,
			'INTEGER_WS' => 95,
			'INTEGER_NEGATIVE' => 98,
			"!" => 273,
			'ISBLANK' => 231,
			'SAMETERM' => 219,
			"\$" => 27,
			'DECIMAL' => 99,
			'LANG' => 220,
			'DECIMAL_NEGATIVE' => 122,
			'STR' => 232,
			'DOUBLE' => 124,
			'URI' => 6,
			'NAME' => 31,
			'INTEGER_NO_WS' => 94,
			"TRUE" => 104,
			"?" => 32,
			"FALSE" => 125,
			'BOUND' => 234,
			'DOUBLE_NEGATIVE' => 108,
			"(" => 223,
			'ISURI' => 236,
			"REGEX" => 237
		},
		GOTOS => {
			'BooleanLiteral' => 268,
			'RegexExpression' => 226,
			'NumericLiteralPositive' => 114,
			'DOUBLE_POSITIVE' => 115,
			'RelationalExpression' => 270,
			'ValueLogical' => 395,
			'MultiplicativeExpression' => 272,
			'NumericLiteralNegative' => 117,
			'NumericLiteralUnsigned' => 119,
			'VAR1' => 25,
			'IRI_REF' => 28,
			'NumericLiteral' => 274,
			'IRIrefOrFunction' => 275,
			'NumericExpression' => 276,
			'VAR2' => 29,
			'Var' => 277,
			'INTEGER' => 103,
			'BrackettedExpression' => 278,
			'INTEGER_POSITIVE' => 126,
			'PrefixedName' => 34,
			'DECIMAL_POSITIVE' => 106,
			'PrimaryExpression' => 279,
			'PNAME_LN' => 35,
			'BuiltInCall' => 280,
			'PNAME_NS' => 36,
			'UnaryExpression' => 281,
			'AdditiveExpression' => 287,
			'IRIref' => 282,
			'RDFLiteral' => 288
		}
	},
	{#State 366
		DEFAULT => -158
	},
	{#State 367
		ACTIONS => {
			"-" => 269,
			":" => 23,
			'LANGMATCHES' => 214,
			"+" => 283,
			'DATATYPE' => 215,
			'ISIRI' => 227,
			'ISLITERAL' => 217,
			'STRING' => 118,
			'INTEGER_WS' => 95,
			'INTEGER_NEGATIVE' => 98,
			"!" => 273,
			'ISBLANK' => 231,
			'SAMETERM' => 219,
			"\$" => 27,
			'DECIMAL' => 99,
			'LANG' => 220,
			'DECIMAL_NEGATIVE' => 122,
			'STR' => 232,
			'DOUBLE' => 124,
			'URI' => 6,
			'NAME' => 31,
			'INTEGER_NO_WS' => 94,
			"TRUE" => 104,
			"?" => 32,
			"FALSE" => 125,
			'BOUND' => 234,
			'DOUBLE_NEGATIVE' => 108,
			"(" => 223,
			'ISURI' => 236,
			"REGEX" => 237
		},
		GOTOS => {
			'BooleanLiteral' => 268,
			'RegexExpression' => 226,
			'NumericLiteralPositive' => 114,
			'DOUBLE_POSITIVE' => 115,
			'MultiplicativeExpression' => 396,
			'NumericLiteralNegative' => 117,
			'NumericLiteralUnsigned' => 119,
			'VAR1' => 25,
			'IRI_REF' => 28,
			'NumericLiteral' => 274,
			'IRIrefOrFunction' => 275,
			'Var' => 277,
			'VAR2' => 29,
			'INTEGER' => 103,
			'BrackettedExpression' => 278,
			'INTEGER_POSITIVE' => 126,
			'PrefixedName' => 34,
			'DECIMAL_POSITIVE' => 106,
			'PrimaryExpression' => 279,
			'PNAME_LN' => 35,
			'BuiltInCall' => 280,
			'PNAME_NS' => 36,
			'UnaryExpression' => 281,
			'IRIref' => 282,
			'RDFLiteral' => 288
		}
	},
	{#State 368
		DEFAULT => -172
	},
	{#State 369
		DEFAULT => -177
	},
	{#State 370
		ACTIONS => {
			"-" => 269,
			":" => 23,
			'LANGMATCHES' => 214,
			"+" => 283,
			'DATATYPE' => 215,
			'ISIRI' => 227,
			'ISLITERAL' => 217,
			'STRING' => 118,
			'INTEGER_WS' => 95,
			'INTEGER_NEGATIVE' => 98,
			"!" => 273,
			'ISBLANK' => 231,
			'SAMETERM' => 219,
			"\$" => 27,
			'DECIMAL' => 336,
			'LANG' => 220,
			'DECIMAL_NEGATIVE' => 122,
			'STR' => 232,
			'DOUBLE' => 339,
			'URI' => 6,
			'NAME' => 31,
			'INTEGER_NO_WS' => 94,
			"TRUE" => 104,
			"?" => 32,
			"FALSE" => 125,
			'BOUND' => 234,
			'DOUBLE_NEGATIVE' => 108,
			"(" => 223,
			'ISURI' => 236,
			"REGEX" => 237
		},
		GOTOS => {
			'BooleanLiteral' => 268,
			'RegexExpression' => 226,
			'NumericLiteralPositive' => 114,
			'DOUBLE_POSITIVE' => 115,
			'MultiplicativeExpression' => 397,
			'NumericLiteralNegative' => 117,
			'NumericLiteralUnsigned' => 119,
			'VAR1' => 25,
			'IRI_REF' => 28,
			'NumericLiteral' => 274,
			'IRIrefOrFunction' => 275,
			'Var' => 277,
			'VAR2' => 29,
			'INTEGER' => 337,
			'BrackettedExpression' => 278,
			'INTEGER_POSITIVE' => 126,
			'PrefixedName' => 34,
			'DECIMAL_POSITIVE' => 106,
			'PrimaryExpression' => 279,
			'PNAME_LN' => 35,
			'BuiltInCall' => 280,
			'PNAME_NS' => 36,
			'UnaryExpression' => 281,
			'IRIref' => 282,
			'RDFLiteral' => 288
		}
	},
	{#State 371
		DEFAULT => -178
	},
	{#State 372
		DEFAULT => -167
	},
	{#State 373
		DEFAULT => -170
	},
	{#State 374
		DEFAULT => -169
	},
	{#State 375
		DEFAULT => -168
	},
	{#State 376
		DEFAULT => -166
	},
	{#State 377
		DEFAULT => -165
	},
	{#State 378
		ACTIONS => {
			"-" => 269,
			":" => 23,
			'LANGMATCHES' => 214,
			"+" => 283,
			'DATATYPE' => 215,
			'ISIRI' => 227,
			'ISLITERAL' => 217,
			'STRING' => 118,
			'INTEGER_WS' => 95,
			'INTEGER_NEGATIVE' => 98,
			"!" => 273,
			'ISBLANK' => 231,
			'SAMETERM' => 219,
			"\$" => 27,
			'DECIMAL' => 99,
			'LANG' => 220,
			'DECIMAL_NEGATIVE' => 122,
			'STR' => 232,
			'DOUBLE' => 124,
			'URI' => 6,
			'NAME' => 31,
			'INTEGER_NO_WS' => 94,
			"TRUE" => 104,
			"?" => 32,
			"FALSE" => 125,
			'BOUND' => 234,
			'DOUBLE_NEGATIVE' => 108,
			"(" => 223,
			'ISURI' => 236,
			"REGEX" => 237
		},
		GOTOS => {
			'BooleanLiteral' => 268,
			'RegexExpression' => 226,
			'NumericLiteralPositive' => 114,
			'DOUBLE_POSITIVE' => 115,
			'NumericLiteralNegative' => 117,
			'NumericLiteralUnsigned' => 119,
			'VAR1' => 25,
			'IRI_REF' => 28,
			'NumericLiteral' => 274,
			'IRIrefOrFunction' => 275,
			'Var' => 277,
			'VAR2' => 29,
			'INTEGER' => 103,
			'BrackettedExpression' => 278,
			'INTEGER_POSITIVE' => 126,
			'PrefixedName' => 34,
			'DECIMAL_POSITIVE' => 106,
			'PrimaryExpression' => 279,
			'PNAME_LN' => 35,
			'BuiltInCall' => 280,
			'PNAME_NS' => 36,
			'UnaryExpression' => 398,
			'IRIref' => 282,
			'RDFLiteral' => 288
		}
	},
	{#State 379
		DEFAULT => -179
	},
	{#State 380
		ACTIONS => {
			"-" => 269,
			":" => 23,
			'LANGMATCHES' => 214,
			"+" => 283,
			'DATATYPE' => 215,
			'ISIRI' => 227,
			'ISLITERAL' => 217,
			'STRING' => 118,
			'INTEGER_WS' => 95,
			'INTEGER_NEGATIVE' => 98,
			"!" => 273,
			'ISBLANK' => 231,
			'SAMETERM' => 219,
			"\$" => 27,
			'DECIMAL' => 99,
			'LANG' => 220,
			'DECIMAL_NEGATIVE' => 122,
			'STR' => 232,
			'DOUBLE' => 124,
			'URI' => 6,
			'NAME' => 31,
			'INTEGER_NO_WS' => 94,
			"TRUE" => 104,
			"?" => 32,
			"FALSE" => 125,
			'BOUND' => 234,
			'DOUBLE_NEGATIVE' => 108,
			"(" => 223,
			'ISURI' => 236,
			"REGEX" => 237
		},
		GOTOS => {
			'BooleanLiteral' => 268,
			'RegexExpression' => 226,
			'NumericLiteralPositive' => 114,
			'DOUBLE_POSITIVE' => 115,
			'NumericLiteralNegative' => 117,
			'NumericLiteralUnsigned' => 119,
			'VAR1' => 25,
			'IRI_REF' => 28,
			'NumericLiteral' => 274,
			'IRIrefOrFunction' => 275,
			'Var' => 277,
			'VAR2' => 29,
			'INTEGER' => 103,
			'BrackettedExpression' => 278,
			'INTEGER_POSITIVE' => 126,
			'PrefixedName' => 34,
			'DECIMAL_POSITIVE' => 106,
			'PrimaryExpression' => 279,
			'PNAME_LN' => 35,
			'BuiltInCall' => 280,
			'PNAME_NS' => 36,
			'UnaryExpression' => 399,
			'IRIref' => 282,
			'RDFLiteral' => 288
		}
	},
	{#State 381
		DEFAULT => -154
	},
	{#State 382
		ACTIONS => {
			"-" => 269,
			":" => 23,
			'LANGMATCHES' => 214,
			"+" => 283,
			'DATATYPE' => 215,
			'ISIRI' => 227,
			'ISLITERAL' => 217,
			'STRING' => 118,
			'INTEGER_WS' => 95,
			'INTEGER_NEGATIVE' => 98,
			"!" => 273,
			'ISBLANK' => 231,
			'SAMETERM' => 219,
			"\$" => 27,
			'DECIMAL' => 99,
			'LANG' => 220,
			'DECIMAL_NEGATIVE' => 122,
			'STR' => 232,
			'DOUBLE' => 124,
			'URI' => 6,
			'NAME' => 31,
			'INTEGER_NO_WS' => 94,
			"TRUE" => 104,
			"?" => 32,
			"FALSE" => 125,
			'BOUND' => 234,
			'DOUBLE_NEGATIVE' => 108,
			"(" => 223,
			'ISURI' => 236,
			"REGEX" => 237
		},
		GOTOS => {
			'BooleanLiteral' => 268,
			'RegexExpression' => 226,
			'NumericLiteralPositive' => 114,
			'DOUBLE_POSITIVE' => 115,
			'RelationalExpression' => 270,
			'ValueLogical' => 271,
			'MultiplicativeExpression' => 272,
			'NumericLiteralNegative' => 117,
			'NumericLiteralUnsigned' => 119,
			'VAR1' => 25,
			'IRI_REF' => 28,
			'NumericLiteral' => 274,
			'IRIrefOrFunction' => 275,
			'NumericExpression' => 276,
			'VAR2' => 29,
			'Var' => 277,
			'INTEGER' => 103,
			'BrackettedExpression' => 278,
			'INTEGER_POSITIVE' => 126,
			'PrefixedName' => 34,
			'DECIMAL_POSITIVE' => 106,
			'ConditionalAndExpression' => 400,
			'PrimaryExpression' => 279,
			'PNAME_LN' => 35,
			'BuiltInCall' => 280,
			'PNAME_NS' => 36,
			'UnaryExpression' => 281,
			'AdditiveExpression' => 287,
			'IRIref' => 282,
			'RDFLiteral' => 288
		}
	},
	{#State 383
		ACTIONS => {
			"," => 402,
			")" => 403
		},
		GOTOS => {
			'PAREN-27' => 401
		}
	},
	{#State 384
		DEFAULT => -202
	},
	{#State 385
		DEFAULT => -204
	},
	{#State 386
		DEFAULT => -196
	},
	{#State 387
		DEFAULT => -200
	},
	{#State 388
		DEFAULT => -203
	},
	{#State 389
		ACTIONS => {
			"-" => 269,
			":" => 23,
			'LANGMATCHES' => 214,
			"+" => 283,
			'DATATYPE' => 215,
			'ISIRI' => 227,
			'ISLITERAL' => 217,
			'STRING' => 118,
			'INTEGER_WS' => 95,
			'INTEGER_NEGATIVE' => 98,
			"!" => 273,
			'ISBLANK' => 231,
			'SAMETERM' => 219,
			"\$" => 27,
			'DECIMAL' => 99,
			'LANG' => 220,
			'DECIMAL_NEGATIVE' => 122,
			'STR' => 232,
			'DOUBLE' => 124,
			'URI' => 6,
			'NAME' => 31,
			'INTEGER_NO_WS' => 94,
			"TRUE" => 104,
			"?" => 32,
			"FALSE" => 125,
			'BOUND' => 234,
			'DOUBLE_NEGATIVE' => 108,
			"(" => 223,
			'ISURI' => 236,
			"REGEX" => 237
		},
		GOTOS => {
			'BooleanLiteral' => 268,
			'RegexExpression' => 226,
			'NumericLiteralPositive' => 114,
			'DOUBLE_POSITIVE' => 115,
			'RelationalExpression' => 270,
			'ValueLogical' => 271,
			'MultiplicativeExpression' => 272,
			'NumericLiteralNegative' => 117,
			'NumericLiteralUnsigned' => 119,
			'VAR1' => 25,
			'IRI_REF' => 28,
			'NumericLiteral' => 274,
			'IRIrefOrFunction' => 275,
			'NumericExpression' => 276,
			'ConditionalOrExpression' => 284,
			'VAR2' => 29,
			'Var' => 277,
			'INTEGER' => 103,
			'Expression' => 404,
			'BrackettedExpression' => 278,
			'INTEGER_POSITIVE' => 126,
			'PrefixedName' => 34,
			'DECIMAL_POSITIVE' => 106,
			'ConditionalAndExpression' => 286,
			'PrimaryExpression' => 279,
			'PNAME_LN' => 35,
			'BuiltInCall' => 280,
			'PNAME_NS' => 36,
			'UnaryExpression' => 281,
			'AdditiveExpression' => 287,
			'IRIref' => 282,
			'RDFLiteral' => 288
		}
	},
	{#State 390
		DEFAULT => -115
	},
	{#State 391
		DEFAULT => -253
	},
	{#State 392
		DEFAULT => -90
	},
	{#State 393
		ACTIONS => {
			")" => 405
		}
	},
	{#State 394
		ACTIONS => {
			")" => 406
		}
	},
	{#State 395
		DEFAULT => -157
	},
	{#State 396
		DEFAULT => -176
	},
	{#State 397
		DEFAULT => -175
	},
	{#State 398
		DEFAULT => -182
	},
	{#State 399
		DEFAULT => -183
	},
	{#State 400
		DEFAULT => -153
	},
	{#State 401
		DEFAULT => -100
	},
	{#State 402
		ACTIONS => {
			"-" => 269,
			":" => 23,
			'LANGMATCHES' => 214,
			"+" => 283,
			'DATATYPE' => 215,
			'ISIRI' => 227,
			'ISLITERAL' => 217,
			'STRING' => 118,
			'INTEGER_WS' => 95,
			'INTEGER_NEGATIVE' => 98,
			"!" => 273,
			'ISBLANK' => 231,
			'SAMETERM' => 219,
			"\$" => 27,
			'DECIMAL' => 99,
			'LANG' => 220,
			'DECIMAL_NEGATIVE' => 122,
			'STR' => 232,
			'DOUBLE' => 124,
			'URI' => 6,
			'NAME' => 31,
			'INTEGER_NO_WS' => 94,
			"TRUE" => 104,
			"?" => 32,
			"FALSE" => 125,
			'BOUND' => 234,
			'DOUBLE_NEGATIVE' => 108,
			"(" => 223,
			'ISURI' => 236,
			"REGEX" => 237
		},
		GOTOS => {
			'BooleanLiteral' => 268,
			'RegexExpression' => 226,
			'NumericLiteralPositive' => 114,
			'DOUBLE_POSITIVE' => 115,
			'RelationalExpression' => 270,
			'ValueLogical' => 271,
			'MultiplicativeExpression' => 272,
			'NumericLiteralNegative' => 117,
			'NumericLiteralUnsigned' => 119,
			'VAR1' => 25,
			'IRI_REF' => 28,
			'NumericLiteral' => 274,
			'IRIrefOrFunction' => 275,
			'NumericExpression' => 276,
			'ConditionalOrExpression' => 284,
			'VAR2' => 29,
			'Var' => 277,
			'INTEGER' => 103,
			'Expression' => 407,
			'BrackettedExpression' => 278,
			'INTEGER_POSITIVE' => 126,
			'PrefixedName' => 34,
			'DECIMAL_POSITIVE' => 106,
			'ConditionalAndExpression' => 286,
			'PrimaryExpression' => 279,
			'PNAME_LN' => 35,
			'BuiltInCall' => 280,
			'PNAME_NS' => 36,
			'UnaryExpression' => 281,
			'AdditiveExpression' => 287,
			'IRIref' => 282,
			'RDFLiteral' => 288
		}
	},
	{#State 403
		DEFAULT => -102
	},
	{#State 404
		ACTIONS => {
			"," => 408
		},
		DEFAULT => -209,
		GOTOS => {
			'OPTIONAL-49' => 409,
			'PAREN-48' => 410
		}
	},
	{#State 405
		DEFAULT => -198
	},
	{#State 406
		DEFAULT => -201
	},
	{#State 407
		DEFAULT => -99
	},
	{#State 408
		ACTIONS => {
			"-" => 269,
			":" => 23,
			'LANGMATCHES' => 214,
			"+" => 283,
			'DATATYPE' => 215,
			'ISIRI' => 227,
			'ISLITERAL' => 217,
			'STRING' => 118,
			'INTEGER_WS' => 95,
			'INTEGER_NEGATIVE' => 98,
			"!" => 273,
			'ISBLANK' => 231,
			'SAMETERM' => 219,
			"\$" => 27,
			'DECIMAL' => 99,
			'LANG' => 220,
			'DECIMAL_NEGATIVE' => 122,
			'STR' => 232,
			'DOUBLE' => 124,
			'URI' => 6,
			'NAME' => 31,
			'INTEGER_NO_WS' => 94,
			"TRUE" => 104,
			"?" => 32,
			"FALSE" => 125,
			'BOUND' => 234,
			'DOUBLE_NEGATIVE' => 108,
			"(" => 223,
			'ISURI' => 236,
			"REGEX" => 237
		},
		GOTOS => {
			'BooleanLiteral' => 268,
			'RegexExpression' => 226,
			'NumericLiteralPositive' => 114,
			'DOUBLE_POSITIVE' => 115,
			'RelationalExpression' => 270,
			'ValueLogical' => 271,
			'MultiplicativeExpression' => 272,
			'NumericLiteralNegative' => 117,
			'NumericLiteralUnsigned' => 119,
			'VAR1' => 25,
			'IRI_REF' => 28,
			'NumericLiteral' => 274,
			'IRIrefOrFunction' => 275,
			'NumericExpression' => 276,
			'ConditionalOrExpression' => 284,
			'VAR2' => 29,
			'Var' => 277,
			'INTEGER' => 103,
			'Expression' => 411,
			'BrackettedExpression' => 278,
			'INTEGER_POSITIVE' => 126,
			'PrefixedName' => 34,
			'DECIMAL_POSITIVE' => 106,
			'ConditionalAndExpression' => 286,
			'PrimaryExpression' => 279,
			'PNAME_LN' => 35,
			'BuiltInCall' => 280,
			'PNAME_NS' => 36,
			'UnaryExpression' => 281,
			'AdditiveExpression' => 287,
			'IRIref' => 282,
			'RDFLiteral' => 288
		}
	},
	{#State 409
		ACTIONS => {
			")" => 412
		}
	},
	{#State 410
		DEFAULT => -208
	},
	{#State 411
		DEFAULT => -207
	},
	{#State 412
		DEFAULT => -210
	}
],
                                  yyrules  =>
[
	[#Rule _SUPERSTART
		 '$start', 2, undef
#line 7044 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule Query_1
		 'Query', 2,
sub {
#line 4 "lib/RDF/Query/Parser/SPARQL.yp"
 { method => 'SELECT', %{ $_[1] }, %{ $_[2] } } }
#line 7051 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule Query_2
		 'Query', 2,
sub {
#line 5 "lib/RDF/Query/Parser/SPARQL.yp"
 { method => 'CONSTRUCT', %{ $_[1] }, %{ $_[2] } } }
#line 7058 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule Query_3
		 'Query', 2,
sub {
#line 6 "lib/RDF/Query/Parser/SPARQL.yp"
 { method => 'DESCRIBE', %{ $_[1] }, %{ $_[2] } } }
#line 7065 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule Query_4
		 'Query', 2,
sub {
#line 7 "lib/RDF/Query/Parser/SPARQL.yp"
 { method => 'ASK', %{ $_[1] }, %{ $_[2] } } }
#line 7072 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule _OPTIONAL
		 'OPTIONAL-1', 1,
sub {
#line 10 "lib/RDF/Query/Parser/SPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_single }
#line 7079 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule _OPTIONAL
		 'OPTIONAL-1', 0,
sub {
#line 10 "lib/RDF/Query/Parser/SPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_empty }
#line 7086 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule _STAR_LIST_2
		 'STAR-2', 2,
sub {
#line 10 "lib/RDF/Query/Parser/SPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_TX1X2 }
#line 7093 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule _STAR_LIST_2
		 'STAR-2', 0,
sub {
#line 10 "lib/RDF/Query/Parser/SPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_empty }
#line 7100 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule Prologue_9
		 'Prologue', 2,
sub {
#line 10 "lib/RDF/Query/Parser/SPARQL.yp"

										my $ret	= +{
													namespaces	=> { map {%$_} @{$_[2]{children}} },
													map { %$_ } (@{$_[1]{children}})
												};
										$ret;
									}
#line 7113 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule BaseDecl_10
		 'BaseDecl', 2,
sub {
#line 18 "lib/RDF/Query/Parser/SPARQL.yp"
 +{ 'base' => $_[2] } }
#line 7120 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule PrefixDecl_11
		 'PrefixDecl', 3,
sub {
#line 20 "lib/RDF/Query/Parser/SPARQL.yp"
 +{ $_[2] => $_[3][1] } }
#line 7127 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule _OPTIONAL
		 'OPTIONAL-3', 1,
sub {
#line 22 "lib/RDF/Query/Parser/SPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_single }
#line 7134 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule _OPTIONAL
		 'OPTIONAL-3', 0,
sub {
#line 22 "lib/RDF/Query/Parser/SPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_empty }
#line 7141 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule _STAR_LIST_4
		 'STAR-4', 2,
sub {
#line 22 "lib/RDF/Query/Parser/SPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_TX1X2 }
#line 7148 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule _STAR_LIST_4
		 'STAR-4', 0,
sub {
#line 22 "lib/RDF/Query/Parser/SPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_empty }
#line 7155 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule SelectQuery_16
		 'SelectQuery', 6,
sub {
#line 23 "lib/RDF/Query/Parser/SPARQL.yp"

					my $sel_modifier	= $_[2]{children}[0];
					my $sol_modifier	= $_[6];
					
					my $vars			= $_[3];
					if ($vars->[0] eq '*') {
						use List::MoreUtils qw(uniq);
						my @vars	= map { $_[0]->new_variable($_) } uniq( map { $_->referenced_variables } @{ $_[5] } );
						$vars		= \@vars;
					}
					
					my $ret	= +{
						variables	=> $vars,
						sources		=> $_[4]{children},
						triples		=> $_[5],
					};
					
					if (my $o = $sol_modifier->{orderby}){
						$ret->{options}{orderby}	= $o;
					}
					if (my $l = $sol_modifier->{limitoffset}) {
						my %data	= @$l;
						while (my($k,$v) = each(%data)) {
							$ret->{options}{$k}	= $v;
						}
					}
					
					if (ref($sel_modifier) and Scalar::Util::reftype($sel_modifier) eq 'ARRAY') {
						my %data	= @$sel_modifier;
						while (my($k,$v) = each(%data)) {
							$ret->{options}{$k}	= $v;
						}
					}
					
					return $ret;
				}
#line 7197 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule SelectModifier_17
		 'SelectModifier', 1,
sub {
#line 60 "lib/RDF/Query/Parser/SPARQL.yp"
 [ distinct => 1 ] }
#line 7204 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule SelectModifier_18
		 'SelectModifier', 1,
sub {
#line 61 "lib/RDF/Query/Parser/SPARQL.yp"
 [ reduced => 1 ] }
#line 7211 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule _PLUS_LIST
		 'PLUS-5', 2,
sub {
#line 63 "lib/RDF/Query/Parser/SPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_TX1X2 }
#line 7218 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule _PLUS_LIST
		 'PLUS-5', 1,
sub {
#line 63 "lib/RDF/Query/Parser/SPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_single }
#line 7225 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule SelectVars_21
		 'SelectVars', 1,
sub {
#line 63 "lib/RDF/Query/Parser/SPARQL.yp"
 $_[1]{children} }
#line 7232 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule SelectVars_22
		 'SelectVars', 1,
sub {
#line 64 "lib/RDF/Query/Parser/SPARQL.yp"
 ['*'] }
#line 7239 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule _STAR_LIST_6
		 'STAR-6', 2,
sub {
#line 66 "lib/RDF/Query/Parser/SPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_TX1X2 }
#line 7246 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule _STAR_LIST_6
		 'STAR-6', 0,
sub {
#line 66 "lib/RDF/Query/Parser/SPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_empty }
#line 7253 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule ConstructQuery_25
		 'ConstructQuery', 5,
sub {
#line 67 "lib/RDF/Query/Parser/SPARQL.yp"

					my $template	= $_[2];
					my $ret	= +{
						construct_triples	=> $template,
						sources				=> $_[3]{children},
						triples				=> $_[4],
					};
					
					return $ret;
				}
#line 7269 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule _STAR_LIST_7
		 'STAR-7', 2,
sub {
#line 78 "lib/RDF/Query/Parser/SPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_TX1X2 }
#line 7276 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule _STAR_LIST_7
		 'STAR-7', 0,
sub {
#line 78 "lib/RDF/Query/Parser/SPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_empty }
#line 7283 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule _OPTIONAL
		 'OPTIONAL-8', 1,
sub {
#line 78 "lib/RDF/Query/Parser/SPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_single }
#line 7290 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule _OPTIONAL
		 'OPTIONAL-8', 0,
sub {
#line 78 "lib/RDF/Query/Parser/SPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_empty }
#line 7297 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule DescribeQuery_30
		 'DescribeQuery', 5,
sub {
#line 79 "lib/RDF/Query/Parser/SPARQL.yp"

					my $modifier	= $_[5];
					my $ret	= +{
						variables	=> $_[2],
						sources		=> $_[3]{children},
						triples		=> ${ $_[4]{children} || [] }[0],
					};
					$ret->{triples}	= RDF::Query::Algebra::GroupGraphPattern->new() if (not defined($ret->{triples}));
					if (my $o = $modifier->{orderby}){
						$ret->{orderby}	= $o;
					}
					$ret;
				}
#line 7316 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule _PLUS_LIST
		 'PLUS-9', 2,
sub {
#line 92 "lib/RDF/Query/Parser/SPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_TX1X2 }
#line 7323 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule _PLUS_LIST
		 'PLUS-9', 1,
sub {
#line 92 "lib/RDF/Query/Parser/SPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_single }
#line 7330 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule DescribeVars_33
		 'DescribeVars', 1,
sub {
#line 92 "lib/RDF/Query/Parser/SPARQL.yp"
 $_[1]{children} }
#line 7337 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule DescribeVars_34
		 'DescribeVars', 1,
sub {
#line 93 "lib/RDF/Query/Parser/SPARQL.yp"
 '*' }
#line 7344 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule _STAR_LIST_10
		 'STAR-10', 2,
sub {
#line 95 "lib/RDF/Query/Parser/SPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_TX1X2 }
#line 7351 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule _STAR_LIST_10
		 'STAR-10', 0,
sub {
#line 95 "lib/RDF/Query/Parser/SPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_empty }
#line 7358 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule AskQuery_37
		 'AskQuery', 3,
sub {
#line 96 "lib/RDF/Query/Parser/SPARQL.yp"

		my $ret	= +{
			sources		=> $_[2]{children},
			triples		=> $_[3],
			variables	=> [],
		};
		return $ret;
	}
#line 7372 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule DatasetClause_38
		 'DatasetClause', 2,
sub {
#line 105 "lib/RDF/Query/Parser/SPARQL.yp"
 $_[2] }
#line 7379 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule DatasetClause_39
		 'DatasetClause', 2,
sub {
#line 106 "lib/RDF/Query/Parser/SPARQL.yp"
 $_[2] }
#line 7386 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule DefaultGraphClause_40
		 'DefaultGraphClause', 1,
sub {
#line 109 "lib/RDF/Query/Parser/SPARQL.yp"
 $_[1] }
#line 7393 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule NamedGraphClause_41
		 'NamedGraphClause', 1,
sub {
#line 111 "lib/RDF/Query/Parser/SPARQL.yp"
 [ @{ $_[1] }, 'NAMED' ] }
#line 7400 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule SourceSelector_42
		 'SourceSelector', 1,
sub {
#line 113 "lib/RDF/Query/Parser/SPARQL.yp"
 $_[1] }
#line 7407 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule _OPTIONAL
		 'OPTIONAL-11', 1,
sub {
#line 115 "lib/RDF/Query/Parser/SPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_single }
#line 7414 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule _OPTIONAL
		 'OPTIONAL-11', 0,
sub {
#line 115 "lib/RDF/Query/Parser/SPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_empty }
#line 7421 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule WhereClause_45
		 'WhereClause', 2,
sub {
#line 115 "lib/RDF/Query/Parser/SPARQL.yp"

																my $ggp			= $_[2];
																return $ggp;
															}
#line 7431 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule _OPTIONAL
		 'OPTIONAL-12', 1,
sub {
#line 120 "lib/RDF/Query/Parser/SPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_single }
#line 7438 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule _OPTIONAL
		 'OPTIONAL-12', 0,
sub {
#line 120 "lib/RDF/Query/Parser/SPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_empty }
#line 7445 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule _OPTIONAL
		 'OPTIONAL-13', 1,
sub {
#line 120 "lib/RDF/Query/Parser/SPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_single }
#line 7452 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule _OPTIONAL
		 'OPTIONAL-13', 0,
sub {
#line 120 "lib/RDF/Query/Parser/SPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_empty }
#line 7459 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule SolutionModifier_50
		 'SolutionModifier', 2,
sub {
#line 121 "lib/RDF/Query/Parser/SPARQL.yp"

		return +{ orderby => $_[1]{children}[0], limitoffset => $_[2]{children}[0] };
	}
#line 7468 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule _OPTIONAL
		 'OPTIONAL-14', 1,
sub {
#line 125 "lib/RDF/Query/Parser/SPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_single }
#line 7475 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule _OPTIONAL
		 'OPTIONAL-14', 0,
sub {
#line 125 "lib/RDF/Query/Parser/SPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_empty }
#line 7482 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule _OPTIONAL
		 'OPTIONAL-15', 1,
sub {
#line 126 "lib/RDF/Query/Parser/SPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_single }
#line 7489 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule _OPTIONAL
		 'OPTIONAL-15', 0,
sub {
#line 126 "lib/RDF/Query/Parser/SPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_empty }
#line 7496 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule LimitOffsetClauses_55
		 'LimitOffsetClauses', 2,
sub {
#line 125 "lib/RDF/Query/Parser/SPARQL.yp"
 [ @{$_[1]}, @{ $_[2]{children}[0] || [] } ] }
#line 7503 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule LimitOffsetClauses_56
		 'LimitOffsetClauses', 2,
sub {
#line 126 "lib/RDF/Query/Parser/SPARQL.yp"
 [ @{$_[1]}, @{ $_[2]{children}[0] || [] } ] }
#line 7510 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule _PLUS_LIST
		 'PLUS-16', 2,
sub {
#line 129 "lib/RDF/Query/Parser/SPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_TX1X2 }
#line 7517 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule _PLUS_LIST
		 'PLUS-16', 1,
sub {
#line 129 "lib/RDF/Query/Parser/SPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_single }
#line 7524 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule OrderClause_59
		 'OrderClause', 2,
sub {
#line 130 "lib/RDF/Query/Parser/SPARQL.yp"

		my $order	= $_[2]{children};
		return $order;
	}
#line 7534 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule OrderCondition_60
		 'OrderCondition', 2,
sub {
#line 135 "lib/RDF/Query/Parser/SPARQL.yp"
 [ $_[1], $_[2] ] }
#line 7541 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule OrderCondition_61
		 'OrderCondition', 1,
sub {
#line 136 "lib/RDF/Query/Parser/SPARQL.yp"
 [ 'ASC', $_[1] ] }
#line 7548 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule OrderCondition_62
		 'OrderCondition', 1,
sub {
#line 137 "lib/RDF/Query/Parser/SPARQL.yp"
 [ 'ASC', $_[1] ] }
#line 7555 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule OrderDirection_63
		 'OrderDirection', 1,
sub {
#line 139 "lib/RDF/Query/Parser/SPARQL.yp"
 'ASC' }
#line 7562 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule OrderDirection_64
		 'OrderDirection', 1,
sub {
#line 140 "lib/RDF/Query/Parser/SPARQL.yp"
 'DESC' }
#line 7569 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule LimitClause_65
		 'LimitClause', 2,
sub {
#line 143 "lib/RDF/Query/Parser/SPARQL.yp"
 [ limit => $_[2] ] }
#line 7576 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule OffsetClause_66
		 'OffsetClause', 2,
sub {
#line 145 "lib/RDF/Query/Parser/SPARQL.yp"
 [ offset => $_[2] ] }
#line 7583 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule _OPTIONAL
		 'OPTIONAL-17', 1,
sub {
#line 147 "lib/RDF/Query/Parser/SPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_single }
#line 7590 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule _OPTIONAL
		 'OPTIONAL-17', 0,
sub {
#line 147 "lib/RDF/Query/Parser/SPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_empty }
#line 7597 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule _OPTIONAL
		 'OPTIONAL-18', 1,
sub {
#line 147 "lib/RDF/Query/Parser/SPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_single }
#line 7604 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule _OPTIONAL
		 'OPTIONAL-18', 0,
sub {
#line 147 "lib/RDF/Query/Parser/SPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_empty }
#line 7611 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule _OPTIONAL
		 'OPTIONAL-19', 1,
sub {
#line 147 "lib/RDF/Query/Parser/SPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_single }
#line 7618 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule _OPTIONAL
		 'OPTIONAL-19', 0,
sub {
#line 147 "lib/RDF/Query/Parser/SPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_empty }
#line 7625 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule _PAREN
		 'PAREN-20', 3,
sub {
#line 147 "lib/RDF/Query/Parser/SPARQL.yp"
 goto &Parse::Eyapp::Driver::YYBuildAST }
#line 7632 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule _STAR_LIST_21
		 'STAR-21', 2,
sub {
#line 147 "lib/RDF/Query/Parser/SPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_TX1X2 }
#line 7639 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule _STAR_LIST_21
		 'STAR-21', 0,
sub {
#line 147 "lib/RDF/Query/Parser/SPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_empty }
#line 7646 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule GroupGraphPattern_76
		 'GroupGraphPattern', 4,
sub {
#line 148 "lib/RDF/Query/Parser/SPARQL.yp"

						my $self	= $_[0];
						my @ggp	= ( @{ $_[2]{children}[0] || [] } );
						# @ggp has only one element at this point -- a ['BGP', ...]
						
						if (@{ $_[3]{children} }) {
							my $opt				= $_[3]{children};
							
							my $index	= 0;
							for ($index = 0; $index < $#{$opt}; $index += 3) {
								my $ggpatom			= $opt->[ $index ][0];
								my $ggpatom_triples	= $opt->[ $index ][1];
								my $triplesblock	= $opt->[ $index + 2 ]{children}[0];
								
								my @data;
								if (ref($ggpatom) and (reftype($ggpatom) eq 'ARRAY')) {
#									warn Dumper($ggpatom, $ggp[$#ggp]);
									if (
													blessed($ggpatom) and
													($ggpatom->isa('RDF::Query::Algebra::OldFilter')) and
#													($ggpatom->[0] eq 'FILTER') and
													(scalar(@ggp)) and
													blessed($ggp[$#ggp]) and
													($ggp[$#ggp]->isa('RDF::Query::Algebra::BasicGraphPattern')) and
#													($ggp[$#ggp][0] eq 'BGP') and
													(scalar(@{ $triplesblock || [] }))
												) {
										
										my @triples	= $triplesblock->[0]->triples;
										push(@{ $ggp[ $#ggp ] }, @triples );
										undef $triplesblock;
										@data			= ($ggpatom);
									} else {
										@data			= ($ggpatom);
									}
								} else {
									@data			= ($ggpatom);
								}
								
								my @triples;
								if (@$ggpatom_triples) {
									push(@triples, @$ggpatom_triples);
								}
								if (@{ $triplesblock || [] }) {
									push(@data, @{ $triplesblock || [] });
								}
								if (@triples) {
									push(@data, @triples);
								}
								push(@ggp, @data);
							}
						}
						
						my @new_ggp;
						foreach my $data (@ggp) {
							my $type	= (blessed($data)) ? $data->type : $data->[0];
							if ($type eq 'OPTIONAL') {
								my @left		= (scalar(@new_ggp) == 0)
												? RDF::Query::Algebra::GroupGraphPattern->new()
												: @new_ggp;
								my $left		= (scalar(@left) > 1)
												? RDF::Query::Algebra::GroupGraphPattern->new(@left)
												: $left[0];
								@new_ggp		= $self->new_optional( $left, $data->[1] );
							} else {
								push(@new_ggp, $data);
							}
						}
						
						return RDF::Query::Algebra::GroupGraphPattern->new( @new_ggp );
					}
#line 7723 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule GGPAtom_77
		 'GGPAtom', 1,
sub {
#line 220 "lib/RDF/Query/Parser/SPARQL.yp"
 $_[1] }
#line 7730 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule GGPAtom_78
		 'GGPAtom', 1,
sub {
#line 221 "lib/RDF/Query/Parser/SPARQL.yp"

																	my $self	= $_[0];
																	[ $self->new_filter($_[1]), [] ]
																}
#line 7740 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule _OPTIONAL
		 'OPTIONAL-22', 1,
sub {
#line 227 "lib/RDF/Query/Parser/SPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_single }
#line 7747 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule _OPTIONAL
		 'OPTIONAL-22', 0,
sub {
#line 227 "lib/RDF/Query/Parser/SPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_empty }
#line 7754 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule _PAREN
		 'PAREN-23', 2,
sub {
#line 227 "lib/RDF/Query/Parser/SPARQL.yp"
 goto &Parse::Eyapp::Driver::YYBuildAST }
#line 7761 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule _OPTIONAL
		 'OPTIONAL-24', 1,
sub {
#line 227 "lib/RDF/Query/Parser/SPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_single }
#line 7768 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule _OPTIONAL
		 'OPTIONAL-24', 0,
sub {
#line 227 "lib/RDF/Query/Parser/SPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_empty }
#line 7775 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule TriplesBlock_84
		 'TriplesBlock', 2,
sub {
#line 228 "lib/RDF/Query/Parser/SPARQL.yp"

		my $self	= $_[0];
		my @triples	= @{ $_[1] };
		if (@{ $_[2]{children} }) {
			foreach my $child (@{ $_[2]{children} }) {
				foreach my $data (@{ $child->{children} }) {
					my @t	= $data->[0]->triples;
					push(@triples, @t);
				}
			}
		}
		
		return [ RDF::Query::Algebra::BasicGraphPattern->new( @triples ) ];
	}
#line 7795 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule GraphPatternNotTriples_85
		 'GraphPatternNotTriples', 1,
sub {
#line 245 "lib/RDF/Query/Parser/SPARQL.yp"
 [$_[1],[]] }
#line 7802 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule GraphPatternNotTriples_86
		 'GraphPatternNotTriples', 1,
sub {
#line 246 "lib/RDF/Query/Parser/SPARQL.yp"
 [$_[1],[]] }
#line 7809 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule GraphPatternNotTriples_87
		 'GraphPatternNotTriples', 1,
sub {
#line 247 "lib/RDF/Query/Parser/SPARQL.yp"
 [$_[1],[]] }
#line 7816 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule OptionalGraphPattern_88
		 'OptionalGraphPattern', 2,
sub {
#line 250 "lib/RDF/Query/Parser/SPARQL.yp"

																	my $ggp	= $_[2];
																	return ['OPTIONAL', $ggp]
																}
#line 7826 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule GraphGraphPattern_89
		 'GraphGraphPattern', 3,
sub {
#line 255 "lib/RDF/Query/Parser/SPARQL.yp"

																	my $self	= $_[0];
																	my $graph	= $_[2];
																	my $ggp		= $_[3];
																	return $self->new_named_graph( $graph, $ggp );
																}
#line 7838 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule _PAREN
		 'PAREN-25', 2,
sub {
#line 262 "lib/RDF/Query/Parser/SPARQL.yp"
 goto &Parse::Eyapp::Driver::YYBuildAST }
#line 7845 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule _STAR_LIST_26
		 'STAR-26', 2,
sub {
#line 262 "lib/RDF/Query/Parser/SPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_TX1X2 }
#line 7852 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule _STAR_LIST_26
		 'STAR-26', 0,
sub {
#line 262 "lib/RDF/Query/Parser/SPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_empty }
#line 7859 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule GroupOrUnionGraphPattern_93
		 'GroupOrUnionGraphPattern', 2,
sub {
#line 263 "lib/RDF/Query/Parser/SPARQL.yp"

		my $self	= $_[0];
		if (@{ $_[2]{children} }) {
			my $total	= $#{ $_[2]{children} };
			my @ggp		= map { $_[2]{children}[$_] } grep { $_ % 2 == 1 } (0 .. $total);
			my $data	= $_[1];
			while (@ggp) {
				$data	= $self->new_union( $data, shift(@ggp) );
			}
			return $data;
		} else {
			return $_[1];
		}
	}
#line 7879 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule Filter_94
		 'Filter', 2,
sub {
#line 278 "lib/RDF/Query/Parser/SPARQL.yp"

#									warn 'FILTER CONSTRAINT: ' . Dumper($_[2]);
								$_[2]
							}
#line 7889 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule Constraint_95
		 'Constraint', 1,
sub {
#line 283 "lib/RDF/Query/Parser/SPARQL.yp"
 $_[1] }
#line 7896 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule Constraint_96
		 'Constraint', 1,
sub {
#line 284 "lib/RDF/Query/Parser/SPARQL.yp"
 $_[1] }
#line 7903 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule Constraint_97
		 'Constraint', 1,
sub {
#line 285 "lib/RDF/Query/Parser/SPARQL.yp"
 $_[1] }
#line 7910 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule FunctionCall_98
		 'FunctionCall', 2,
sub {
#line 289 "lib/RDF/Query/Parser/SPARQL.yp"

		$_[0]->new_function_expression( $_[1], @{ $_[2] } )
	}
#line 7919 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule _PAREN
		 'PAREN-27', 2,
sub {
#line 293 "lib/RDF/Query/Parser/SPARQL.yp"
 goto &Parse::Eyapp::Driver::YYBuildAST }
#line 7926 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule _STAR_LIST_28
		 'STAR-28', 2,
sub {
#line 293 "lib/RDF/Query/Parser/SPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_TX1X2 }
#line 7933 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule _STAR_LIST_28
		 'STAR-28', 0,
sub {
#line 293 "lib/RDF/Query/Parser/SPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_empty }
#line 7940 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule ArgList_102
		 'ArgList', 4,
sub {
#line 294 "lib/RDF/Query/Parser/SPARQL.yp"

			my $args	= [
				$_[2],
				map { $_ } @{ $_[3]{children} }
			];
			
			$args;
		}
#line 7954 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule ArgList_103
		 'ArgList', 1,
sub {
#line 302 "lib/RDF/Query/Parser/SPARQL.yp"
 [] }
#line 7961 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule _OPTIONAL
		 'OPTIONAL-29', 1,
sub {
#line 304 "lib/RDF/Query/Parser/SPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_single }
#line 7968 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule _OPTIONAL
		 'OPTIONAL-29', 0,
sub {
#line 304 "lib/RDF/Query/Parser/SPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_empty }
#line 7975 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule ConstructTemplate_106
		 'ConstructTemplate', 3,
sub {
#line 305 "lib/RDF/Query/Parser/SPARQL.yp"

	if (@{ $_[2]{children} }) {
		return $_[2]{children}[0];
	} else {
		return {};
	}
}
#line 7988 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule _OPTIONAL
		 'OPTIONAL-30', 1,
sub {
#line 313 "lib/RDF/Query/Parser/SPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_single }
#line 7995 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule _OPTIONAL
		 'OPTIONAL-30', 0,
sub {
#line 313 "lib/RDF/Query/Parser/SPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_empty }
#line 8002 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule _PAREN
		 'PAREN-31', 2,
sub {
#line 313 "lib/RDF/Query/Parser/SPARQL.yp"
 goto &Parse::Eyapp::Driver::YYBuildAST }
#line 8009 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule _OPTIONAL
		 'OPTIONAL-32', 1,
sub {
#line 313 "lib/RDF/Query/Parser/SPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_single }
#line 8016 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule _OPTIONAL
		 'OPTIONAL-32', 0,
sub {
#line 313 "lib/RDF/Query/Parser/SPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_empty }
#line 8023 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule ConstructTriples_112
		 'ConstructTriples', 2,
sub {
#line 314 "lib/RDF/Query/Parser/SPARQL.yp"

		my @triples	= @{ $_[1] };
		if (@{ $_[2]{children} }) {
			my $triples	= $_[2]{children}[0]{children}[0];
			push(@triples, @{ $triples || [] });
		}
		return RDF::Query::Algebra::GroupGraphPattern->new( @triples );
	}
#line 8037 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule TriplesSameSubject_113
		 'TriplesSameSubject', 2,
sub {
#line 323 "lib/RDF/Query/Parser/SPARQL.yp"

															my $self	= $_[0];
															my ($props, $triples)	= @{ $_[2] };
															my $subj	= $_[1];
															
															my @triples;
															push(@triples, map { [ $subj, @{$_} ] } @$props);
															push(@triples, @{ $triples });
															return [map { $self->new_triple(@$_) } @triples];
														}
#line 8053 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule TriplesSameSubject_114
		 'TriplesSameSubject', 2,
sub {
#line 333 "lib/RDF/Query/Parser/SPARQL.yp"

															my $self	= $_[0];
															my ($node, $triples)	= @{ $_[1] };
															my @triples				= @$triples;
															
															my ($props, $prop_triples)	= @{ $_[2] };
															if (@$props) {
																push(@triples, @{ $prop_triples });
																foreach my $child (@$props) {
																	push(@triples, [ $node, @$child ]);
																	
																}
															}
															
															return [map { $self->new_triple(@$_) } @triples];
														}
#line 8075 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule _PAREN
		 'PAREN-33', 2,
sub {
#line 351 "lib/RDF/Query/Parser/SPARQL.yp"
 goto &Parse::Eyapp::Driver::YYBuildAST }
#line 8082 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule _OPTIONAL
		 'OPTIONAL-34', 1,
sub {
#line 351 "lib/RDF/Query/Parser/SPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_single }
#line 8089 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule _OPTIONAL
		 'OPTIONAL-34', 0,
sub {
#line 351 "lib/RDF/Query/Parser/SPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_empty }
#line 8096 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule _PAREN
		 'PAREN-35', 2,
sub {
#line 351 "lib/RDF/Query/Parser/SPARQL.yp"
 goto &Parse::Eyapp::Driver::YYBuildAST }
#line 8103 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule _STAR_LIST_36
		 'STAR-36', 2,
sub {
#line 351 "lib/RDF/Query/Parser/SPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_TX1X2 }
#line 8110 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule _STAR_LIST_36
		 'STAR-36', 0,
sub {
#line 351 "lib/RDF/Query/Parser/SPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_empty }
#line 8117 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule PropertyListNotEmpty_121
		 'PropertyListNotEmpty', 3,
sub {
#line 352 "lib/RDF/Query/Parser/SPARQL.yp"

															my $objectlist	= $_[2];
															my @objects		= @{ $objectlist->[0] };
															my @triples		= @{ $objectlist->[1] };
															
															my $prop = [
																(map { [ $_[1], $_ ] } @objects),
																(map {
																	my $o = $_;
																	my @objects	= (ref($_->{children}[1][0]) and reftype($_->{children}[1][0]) eq 'ARRAY')
																				? @{ $_->{children}[1][0] }
																				: ();
																	push(@triples, @{ $_->{children}[1][1] || [] });
																	map {
																		[
																			$o->{children}[0], $_
																		]
																	} @objects;
																} @{$_[3]{children}})
															];
															return [ $prop, \@triples ];
														}
#line 8145 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule _OPTIONAL
		 'OPTIONAL-37', 1,
sub {
#line 375 "lib/RDF/Query/Parser/SPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_single }
#line 8152 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule _OPTIONAL
		 'OPTIONAL-37', 0,
sub {
#line 375 "lib/RDF/Query/Parser/SPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_empty }
#line 8159 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule PropertyList_124
		 'PropertyList', 1,
sub {
#line 376 "lib/RDF/Query/Parser/SPARQL.yp"

		if (@{ $_[1]{children} }) {
			return $_[1]{children}[0];
		} else {
			return [ [], [] ];
		}
	}
#line 8172 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule _PAREN
		 'PAREN-38', 2,
sub {
#line 384 "lib/RDF/Query/Parser/SPARQL.yp"
 goto &Parse::Eyapp::Driver::YYBuildAST }
#line 8179 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule _STAR_LIST_39
		 'STAR-39', 2,
sub {
#line 384 "lib/RDF/Query/Parser/SPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_TX1X2 }
#line 8186 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule _STAR_LIST_39
		 'STAR-39', 0,
sub {
#line 384 "lib/RDF/Query/Parser/SPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_empty }
#line 8193 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule ObjectList_128
		 'ObjectList', 2,
sub {
#line 385 "lib/RDF/Query/Parser/SPARQL.yp"

		my @objects	= ($_[1][0], map { $_->[0] } @{ $_[2]{children} });
		my @triples	= (@{ $_[1][1] }, map { @{ $_->[1] } } @{ $_[2]{children} });
		my $data	= [ \@objects, \@triples ];
		return $data;
	}
#line 8205 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule Object_129
		 'Object', 1,
sub {
#line 392 "lib/RDF/Query/Parser/SPARQL.yp"
 $_[1] }
#line 8212 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule Verb_130
		 'Verb', 1,
sub {
#line 394 "lib/RDF/Query/Parser/SPARQL.yp"
 $_[1] }
#line 8219 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule Verb_131
		 'Verb', 1,
sub {
#line 395 "lib/RDF/Query/Parser/SPARQL.yp"
 $_[0]->new_uri('http://www.w3.org/1999/02/22-rdf-syntax-ns#type') }
#line 8226 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule TriplesNode_132
		 'TriplesNode', 1,
sub {
#line 398 "lib/RDF/Query/Parser/SPARQL.yp"
 return $_[1] }
#line 8233 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule TriplesNode_133
		 'TriplesNode', 1,
sub {
#line 399 "lib/RDF/Query/Parser/SPARQL.yp"
 return $_[1] }
#line 8240 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule BlankNodePropertyList_134
		 'BlankNodePropertyList', 3,
sub {
#line 403 "lib/RDF/Query/Parser/SPARQL.yp"

		my $node	= $_[0]->new_blank();
		my ($props, $triples)	= @{ $_[2] };
		my @triples	= @$triples;
		
		push(@triples, map { [$node, @$_] } @$props);
		return [ $node, \@triples ];
	}
#line 8254 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule _PLUS_LIST
		 'PLUS-40', 2,
sub {
#line 412 "lib/RDF/Query/Parser/SPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_TX1X2 }
#line 8261 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule _PLUS_LIST
		 'PLUS-40', 1,
sub {
#line 412 "lib/RDF/Query/Parser/SPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_single }
#line 8268 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule Collection_137
		 'Collection', 3,
sub {
#line 413 "lib/RDF/Query/Parser/SPARQL.yp"

		my $self		= $_[0];
		my @children	= @{ $_[2]{children}};
		my @triples;
		
		my $node;
		my $last_node;
		while (my $child = shift(@children)) {
			my $p_first		= $self->new_uri('http://www.w3.org/1999/02/22-rdf-syntax-ns#first');
			my $p_rest		= $self->new_uri('http://www.w3.org/1999/02/22-rdf-syntax-ns#rest');
			my $cur_node	= $self->new_blank();
			if (defined($last_node)) {
				push(@triples, [ $last_node, $p_rest, $cur_node ]);
			}
			
			my ($child_node, $triples)	= @$child;
			push(@triples, [ $cur_node, $p_first, $child_node ]);
			unless (defined($node)) {
				$node	= $cur_node;
			}
			$last_node	= $cur_node;
			push(@triples, @$triples);
		}
		
		my $p_rest		= $self->new_uri('http://www.w3.org/1999/02/22-rdf-syntax-ns#rest');
		my $nil			= $self->new_uri('http://www.w3.org/1999/02/22-rdf-syntax-ns#nil');
		push(@triples, [ $last_node, $p_rest, $nil ]);
		return [ $node, \@triples ];
	}
#line 8303 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule GraphNode_138
		 'GraphNode', 1,
sub {
#line 443 "lib/RDF/Query/Parser/SPARQL.yp"
 [$_[1], []] }
#line 8310 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule GraphNode_139
		 'GraphNode', 1,
sub {
#line 444 "lib/RDF/Query/Parser/SPARQL.yp"
 $_[1] }
#line 8317 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule VarOrTerm_140
		 'VarOrTerm', 1,
sub {
#line 447 "lib/RDF/Query/Parser/SPARQL.yp"
 $_[1] }
#line 8324 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule VarOrTerm_141
		 'VarOrTerm', 1,
sub {
#line 448 "lib/RDF/Query/Parser/SPARQL.yp"
 $_[1] }
#line 8331 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule VarOrIRIref_142
		 'VarOrIRIref', 1,
sub {
#line 451 "lib/RDF/Query/Parser/SPARQL.yp"
 $_[1] }
#line 8338 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule VarOrIRIref_143
		 'VarOrIRIref', 1,
sub {
#line 452 "lib/RDF/Query/Parser/SPARQL.yp"
 $_[1] }
#line 8345 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule Var_144
		 'Var', 1,
sub {
#line 455 "lib/RDF/Query/Parser/SPARQL.yp"
 $_[1] }
#line 8352 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule Var_145
		 'Var', 1,
sub {
#line 456 "lib/RDF/Query/Parser/SPARQL.yp"
 $_[1] }
#line 8359 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule GraphTerm_146
		 'GraphTerm', 1,
sub {
#line 459 "lib/RDF/Query/Parser/SPARQL.yp"
 $_[1] }
#line 8366 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule GraphTerm_147
		 'GraphTerm', 1,
sub {
#line 460 "lib/RDF/Query/Parser/SPARQL.yp"
 $_[1] }
#line 8373 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule GraphTerm_148
		 'GraphTerm', 1,
sub {
#line 461 "lib/RDF/Query/Parser/SPARQL.yp"
 $_[1] }
#line 8380 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule GraphTerm_149
		 'GraphTerm', 1,
sub {
#line 462 "lib/RDF/Query/Parser/SPARQL.yp"
 $_[1] }
#line 8387 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule GraphTerm_150
		 'GraphTerm', 1,
sub {
#line 463 "lib/RDF/Query/Parser/SPARQL.yp"
 $_[1] }
#line 8394 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule GraphTerm_151
		 'GraphTerm', 1,
sub {
#line 464 "lib/RDF/Query/Parser/SPARQL.yp"
 $_[1] }
#line 8401 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule Expression_152
		 'Expression', 1,
sub {
#line 467 "lib/RDF/Query/Parser/SPARQL.yp"
 $_[1] }
#line 8408 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule _PAREN
		 'PAREN-41', 2,
sub {
#line 469 "lib/RDF/Query/Parser/SPARQL.yp"
 goto &Parse::Eyapp::Driver::YYBuildAST }
#line 8415 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule _STAR_LIST_42
		 'STAR-42', 2,
sub {
#line 469 "lib/RDF/Query/Parser/SPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_TX1X2 }
#line 8422 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule _STAR_LIST_42
		 'STAR-42', 0,
sub {
#line 469 "lib/RDF/Query/Parser/SPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_empty }
#line 8429 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule ConditionalOrExpression_156
		 'ConditionalOrExpression', 2,
sub {
#line 470 "lib/RDF/Query/Parser/SPARQL.yp"

		my $expr	= $_[1];
		if (@{ $_[2]{children} }) {
			$expr	= [ '||', $expr, @{ $_[2]{children} } ];
		}
		$expr;
	}
#line 8442 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule _PAREN
		 'PAREN-43', 2,
sub {
#line 478 "lib/RDF/Query/Parser/SPARQL.yp"
 goto &Parse::Eyapp::Driver::YYBuildAST }
#line 8449 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule _STAR_LIST_44
		 'STAR-44', 2,
sub {
#line 478 "lib/RDF/Query/Parser/SPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_TX1X2 }
#line 8456 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule _STAR_LIST_44
		 'STAR-44', 0,
sub {
#line 478 "lib/RDF/Query/Parser/SPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_empty }
#line 8463 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule ConditionalAndExpression_160
		 'ConditionalAndExpression', 2,
sub {
#line 479 "lib/RDF/Query/Parser/SPARQL.yp"

		my $expr	= $_[1];
		if (@{ $_[2]{children} }) {
			$expr	= [ '&&', $expr, @{ $_[2]{children} } ];
		}
		$expr;
	}
#line 8476 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule ValueLogical_161
		 'ValueLogical', 1,
sub {
#line 487 "lib/RDF/Query/Parser/SPARQL.yp"
 $_[1] }
#line 8483 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule _OPTIONAL
		 'OPTIONAL-45', 1,
sub {
#line 489 "lib/RDF/Query/Parser/SPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_single }
#line 8490 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule _OPTIONAL
		 'OPTIONAL-45', 0,
sub {
#line 489 "lib/RDF/Query/Parser/SPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_empty }
#line 8497 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule RelationalExpression_164
		 'RelationalExpression', 2,
sub {
#line 490 "lib/RDF/Query/Parser/SPARQL.yp"

		my $expr	= $_[1];
		if (@{ $_[2]{children} }) {
			my $more	= $_[2]{children}[0];
			$expr	= [ $more->[0], $expr, $more->[1] ];
		}
		$expr;
	}
#line 8511 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule RelationalExpressionExtra_165
		 'RelationalExpressionExtra', 2,
sub {
#line 499 "lib/RDF/Query/Parser/SPARQL.yp"
 [ '==', $_[2] ] }
#line 8518 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule RelationalExpressionExtra_166
		 'RelationalExpressionExtra', 2,
sub {
#line 500 "lib/RDF/Query/Parser/SPARQL.yp"
 [ '!=', $_[2] ] }
#line 8525 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule RelationalExpressionExtra_167
		 'RelationalExpressionExtra', 2,
sub {
#line 501 "lib/RDF/Query/Parser/SPARQL.yp"
 [ '<', $_[2] ] }
#line 8532 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule RelationalExpressionExtra_168
		 'RelationalExpressionExtra', 2,
sub {
#line 502 "lib/RDF/Query/Parser/SPARQL.yp"
 [ '>', $_[2] ] }
#line 8539 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule RelationalExpressionExtra_169
		 'RelationalExpressionExtra', 2,
sub {
#line 503 "lib/RDF/Query/Parser/SPARQL.yp"
 [ '<=', $_[2] ] }
#line 8546 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule RelationalExpressionExtra_170
		 'RelationalExpressionExtra', 2,
sub {
#line 504 "lib/RDF/Query/Parser/SPARQL.yp"
 [ '>=', $_[2] ] }
#line 8553 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule NumericExpression_171
		 'NumericExpression', 1,
sub {
#line 507 "lib/RDF/Query/Parser/SPARQL.yp"
 $_[1] }
#line 8560 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule _STAR_LIST_46
		 'STAR-46', 2,
sub {
#line 509 "lib/RDF/Query/Parser/SPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_TX1X2 }
#line 8567 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule _STAR_LIST_46
		 'STAR-46', 0,
sub {
#line 509 "lib/RDF/Query/Parser/SPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_empty }
#line 8574 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule AdditiveExpression_174
		 'AdditiveExpression', 2,
sub {
#line 510 "lib/RDF/Query/Parser/SPARQL.yp"

		my $expr	= $_[1];
		foreach my $extra (@{ $_[2]{children} }) {
			$expr	= [ $extra->[0], $expr, $extra->[1] ];
		}
		return $expr
	}
#line 8587 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule AdditiveExpressionExtra_175
		 'AdditiveExpressionExtra', 2,
sub {
#line 518 "lib/RDF/Query/Parser/SPARQL.yp"
 ['+',$_[2]] }
#line 8594 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule AdditiveExpressionExtra_176
		 'AdditiveExpressionExtra', 2,
sub {
#line 519 "lib/RDF/Query/Parser/SPARQL.yp"
 ['-',$_[2]] }
#line 8601 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule AdditiveExpressionExtra_177
		 'AdditiveExpressionExtra', 1,
sub {
#line 520 "lib/RDF/Query/Parser/SPARQL.yp"
 $_[1] }
#line 8608 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule AdditiveExpressionExtra_178
		 'AdditiveExpressionExtra', 1,
sub {
#line 521 "lib/RDF/Query/Parser/SPARQL.yp"
 $_[1] }
#line 8615 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule _STAR_LIST_47
		 'STAR-47', 2,
sub {
#line 524 "lib/RDF/Query/Parser/SPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_TX1X2 }
#line 8622 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule _STAR_LIST_47
		 'STAR-47', 0,
sub {
#line 524 "lib/RDF/Query/Parser/SPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_empty }
#line 8629 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule MultiplicativeExpression_181
		 'MultiplicativeExpression', 2,
sub {
#line 525 "lib/RDF/Query/Parser/SPARQL.yp"

		my $expr	= $_[1];
		foreach my $extra (@{ $_[2]{children} }) {
			 $expr	= [ $extra->[0], $expr, $extra->[1] ];
		}
		$expr
}
#line 8642 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule MultiplicativeExpressionExtra_182
		 'MultiplicativeExpressionExtra', 2,
sub {
#line 532 "lib/RDF/Query/Parser/SPARQL.yp"
 [ '*', $_[2] ] }
#line 8649 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule MultiplicativeExpressionExtra_183
		 'MultiplicativeExpressionExtra', 2,
sub {
#line 533 "lib/RDF/Query/Parser/SPARQL.yp"
 [ '/', $_[2] ] }
#line 8656 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule UnaryExpression_184
		 'UnaryExpression', 2,
sub {
#line 535 "lib/RDF/Query/Parser/SPARQL.yp"
 ['!', $_[2]] }
#line 8663 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule UnaryExpression_185
		 'UnaryExpression', 2,
sub {
#line 536 "lib/RDF/Query/Parser/SPARQL.yp"
 $_[2] }
#line 8670 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule UnaryExpression_186
		 'UnaryExpression', 2,
sub {
#line 537 "lib/RDF/Query/Parser/SPARQL.yp"
 ['-', $_[2]] }
#line 8677 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule UnaryExpression_187
		 'UnaryExpression', 1,
sub {
#line 538 "lib/RDF/Query/Parser/SPARQL.yp"
 $_[1] }
#line 8684 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule PrimaryExpression_188
		 'PrimaryExpression', 1,
sub {
#line 541 "lib/RDF/Query/Parser/SPARQL.yp"
 $_[1] }
#line 8691 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule PrimaryExpression_189
		 'PrimaryExpression', 1,
sub {
#line 542 "lib/RDF/Query/Parser/SPARQL.yp"
 $_[1] }
#line 8698 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule PrimaryExpression_190
		 'PrimaryExpression', 1,
sub {
#line 543 "lib/RDF/Query/Parser/SPARQL.yp"
 $_[1] }
#line 8705 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule PrimaryExpression_191
		 'PrimaryExpression', 1,
sub {
#line 544 "lib/RDF/Query/Parser/SPARQL.yp"
 $_[1] }
#line 8712 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule PrimaryExpression_192
		 'PrimaryExpression', 1,
sub {
#line 545 "lib/RDF/Query/Parser/SPARQL.yp"
 $_[1] }
#line 8719 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule PrimaryExpression_193
		 'PrimaryExpression', 1,
sub {
#line 546 "lib/RDF/Query/Parser/SPARQL.yp"
 $_[1] }
#line 8726 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule PrimaryExpression_194
		 'PrimaryExpression', 1,
sub {
#line 547 "lib/RDF/Query/Parser/SPARQL.yp"
 $_[1] }
#line 8733 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule BrackettedExpression_195
		 'BrackettedExpression', 3,
sub {
#line 550 "lib/RDF/Query/Parser/SPARQL.yp"
 $_[2] }
#line 8740 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule BuiltInCall_196
		 'BuiltInCall', 4,
sub {
#line 552 "lib/RDF/Query/Parser/SPARQL.yp"
 $_[0]->new_function_expression( $_[0]->new_uri('sop:str'), $_[3] ) }
#line 8747 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule BuiltInCall_197
		 'BuiltInCall', 4,
sub {
#line 553 "lib/RDF/Query/Parser/SPARQL.yp"
 $_[0]->new_function_expression( $_[0]->new_uri('sparql:lang'), $_[3] ) }
#line 8754 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule BuiltInCall_198
		 'BuiltInCall', 6,
sub {
#line 554 "lib/RDF/Query/Parser/SPARQL.yp"
 $_[0]->new_function_expression( $_[0]->new_uri('sparql:langmatches'), $_[3], $_[5] ) }
#line 8761 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule BuiltInCall_199
		 'BuiltInCall', 4,
sub {
#line 555 "lib/RDF/Query/Parser/SPARQL.yp"
 $_[0]->new_function_expression( $_[0]->new_uri('sparql:datatype'), $_[3] ) }
#line 8768 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule BuiltInCall_200
		 'BuiltInCall', 4,
sub {
#line 556 "lib/RDF/Query/Parser/SPARQL.yp"
 $_[0]->new_function_expression( $_[0]->new_uri('sop:isBound'), $_[3] ) }
#line 8775 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule BuiltInCall_201
		 'BuiltInCall', 6,
sub {
#line 557 "lib/RDF/Query/Parser/SPARQL.yp"
 $_[0]->new_function_expression( $_[0]->new_uri('sparql:sameTerm'), $_[3], $_[5] ) }
#line 8782 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule BuiltInCall_202
		 'BuiltInCall', 4,
sub {
#line 558 "lib/RDF/Query/Parser/SPARQL.yp"
 $_[0]->new_function_expression( $_[0]->new_uri('sop:isIRI'), $_[3] ) }
#line 8789 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule BuiltInCall_203
		 'BuiltInCall', 4,
sub {
#line 559 "lib/RDF/Query/Parser/SPARQL.yp"
 $_[0]->new_function_expression( $_[0]->new_uri('sop:isURI'), $_[3] ) }
#line 8796 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule BuiltInCall_204
		 'BuiltInCall', 4,
sub {
#line 560 "lib/RDF/Query/Parser/SPARQL.yp"
 $_[0]->new_function_expression( $_[0]->new_uri('sop:isBlank'), $_[3] ) }
#line 8803 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule BuiltInCall_205
		 'BuiltInCall', 4,
sub {
#line 561 "lib/RDF/Query/Parser/SPARQL.yp"
 $_[0]->new_function_expression( $_[0]->new_uri('sop:isLiteral'), $_[3] ) }
#line 8810 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule BuiltInCall_206
		 'BuiltInCall', 1,
sub {
#line 562 "lib/RDF/Query/Parser/SPARQL.yp"
 $_[1] }
#line 8817 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule _PAREN
		 'PAREN-48', 2,
sub {
#line 565 "lib/RDF/Query/Parser/SPARQL.yp"
 goto &Parse::Eyapp::Driver::YYBuildAST }
#line 8824 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule _OPTIONAL
		 'OPTIONAL-49', 1,
sub {
#line 565 "lib/RDF/Query/Parser/SPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_single }
#line 8831 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule _OPTIONAL
		 'OPTIONAL-49', 0,
sub {
#line 565 "lib/RDF/Query/Parser/SPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_empty }
#line 8838 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule RegexExpression_210
		 'RegexExpression', 7,
sub {
#line 566 "lib/RDF/Query/Parser/SPARQL.yp"

		my @data	= ('~~', $_[3], $_[5]);
		if (scalar(@{ $_[6]->{children} })) {
			push(@data, $_[6]->{children}[0]);
		}
		return \@data;
	}
#line 8851 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule _OPTIONAL
		 'OPTIONAL-50', 1,
sub {
#line 574 "lib/RDF/Query/Parser/SPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_single }
#line 8858 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule _OPTIONAL
		 'OPTIONAL-50', 0,
sub {
#line 574 "lib/RDF/Query/Parser/SPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_empty }
#line 8865 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule IRIrefOrFunction_213
		 'IRIrefOrFunction', 2,
sub {
#line 575 "lib/RDF/Query/Parser/SPARQL.yp"

		my $self	= $_[0];
		my $uri		= $_[1];
		my $args	= $_[2]{children}[0];
		
		if (defined($args)) {
			return $self->new_function_expression( $uri, @$args )
		} else {
			return $uri;
		}
	}
#line 8882 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule _OPTIONAL
		 'OPTIONAL-51', 1,
sub {
#line 587 "lib/RDF/Query/Parser/SPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_single }
#line 8889 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule _OPTIONAL
		 'OPTIONAL-51', 0,
sub {
#line 587 "lib/RDF/Query/Parser/SPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_empty }
#line 8896 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule RDFLiteral_216
		 'RDFLiteral', 2,
sub {
#line 587 "lib/RDF/Query/Parser/SPARQL.yp"

											my $self	= $_[0];
											my %extra	= @{ $_[2]{children}[0] || [] };
											my $dt		= $extra{datatype};
											my $lang	= $extra{lang};
											if ($dt) {
												$dt		= $dt->uri_value;
											}
											$self->new_literal( $_[1], $lang, $dt );
										}
#line 8912 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule LiteralExtra_217
		 'LiteralExtra', 1,
sub {
#line 598 "lib/RDF/Query/Parser/SPARQL.yp"
 [ lang => $_[1] ] }
#line 8919 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule LiteralExtra_218
		 'LiteralExtra', 2,
sub {
#line 599 "lib/RDF/Query/Parser/SPARQL.yp"
 [ datatype => $_[2] ] }
#line 8926 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule NumericLiteral_219
		 'NumericLiteral', 1,
sub {
#line 602 "lib/RDF/Query/Parser/SPARQL.yp"
 my $self = $_[0]; my ($value, $type) = @{$_[1]}; $self->new_literal( $value, undef, $type ) }
#line 8933 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule NumericLiteral_220
		 'NumericLiteral', 1,
sub {
#line 603 "lib/RDF/Query/Parser/SPARQL.yp"
 my $self = $_[0]; my ($value, $type) = @{$_[1]}; $self->new_literal( $value, undef, $type ) }
#line 8940 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule NumericLiteral_221
		 'NumericLiteral', 1,
sub {
#line 604 "lib/RDF/Query/Parser/SPARQL.yp"
 my $self = $_[0]; my ($value, $type) = @{$_[1]}; $self->new_literal( $value, undef, $type ) }
#line 8947 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule NumericLiteralUnsigned_222
		 'NumericLiteralUnsigned', 1,
sub {
#line 607 "lib/RDF/Query/Parser/SPARQL.yp"
 [$_[1], 'http://www.w3.org/2001/XMLSchema#integer'] }
#line 8954 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule NumericLiteralUnsigned_223
		 'NumericLiteralUnsigned', 1,
sub {
#line 608 "lib/RDF/Query/Parser/SPARQL.yp"
 [$_[1], 'http://www.w3.org/2001/XMLSchema#decimal'] }
#line 8961 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule NumericLiteralUnsigned_224
		 'NumericLiteralUnsigned', 1,
sub {
#line 609 "lib/RDF/Query/Parser/SPARQL.yp"
 [$_[1], 'http://www.w3.org/2001/XMLSchema#double'] }
#line 8968 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule NumericLiteralPositive_225
		 'NumericLiteralPositive', 1,
sub {
#line 613 "lib/RDF/Query/Parser/SPARQL.yp"
 [$_[1], 'http://www.w3.org/2001/XMLSchema#integer'] }
#line 8975 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule NumericLiteralPositive_226
		 'NumericLiteralPositive', 1,
sub {
#line 614 "lib/RDF/Query/Parser/SPARQL.yp"
 [$_[1], 'http://www.w3.org/2001/XMLSchema#decimal'] }
#line 8982 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule NumericLiteralPositive_227
		 'NumericLiteralPositive', 1,
sub {
#line 615 "lib/RDF/Query/Parser/SPARQL.yp"
 [$_[1], 'http://www.w3.org/2001/XMLSchema#double'] }
#line 8989 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule NumericLiteralNegative_228
		 'NumericLiteralNegative', 1,
sub {
#line 619 "lib/RDF/Query/Parser/SPARQL.yp"
 [$_[1], 'http://www.w3.org/2001/XMLSchema#integer'] }
#line 8996 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule NumericLiteralNegative_229
		 'NumericLiteralNegative', 1,
sub {
#line 620 "lib/RDF/Query/Parser/SPARQL.yp"
 [$_[1], 'http://www.w3.org/2001/XMLSchema#decimal'] }
#line 9003 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule NumericLiteralNegative_230
		 'NumericLiteralNegative', 1,
sub {
#line 621 "lib/RDF/Query/Parser/SPARQL.yp"
 [$_[1], 'http://www.w3.org/2001/XMLSchema#double'] }
#line 9010 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule BooleanLiteral_231
		 'BooleanLiteral', 1,
sub {
#line 624 "lib/RDF/Query/Parser/SPARQL.yp"
 $_[0]->new_literal( 'true', undef, 'http://www.w3.org/2001/XMLSchema#boolean' ) }
#line 9017 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule BooleanLiteral_232
		 'BooleanLiteral', 1,
sub {
#line 625 "lib/RDF/Query/Parser/SPARQL.yp"
 $_[0]->new_literal( 'false', undef, 'http://www.w3.org/2001/XMLSchema#boolean' ) }
#line 9024 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule IRIref_233
		 'IRIref', 1,
sub {
#line 630 "lib/RDF/Query/Parser/SPARQL.yp"
 $_[1] }
#line 9031 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule IRIref_234
		 'IRIref', 1,
sub {
#line 631 "lib/RDF/Query/Parser/SPARQL.yp"
 $_[1] }
#line 9038 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule PrefixedName_235
		 'PrefixedName', 1,
sub {
#line 634 "lib/RDF/Query/Parser/SPARQL.yp"
 $_[1] }
#line 9045 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule PrefixedName_236
		 'PrefixedName', 1,
sub {
#line 635 "lib/RDF/Query/Parser/SPARQL.yp"
 $_[0]->new_uri([$_[1],'']) }
#line 9052 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule BlankNode_237
		 'BlankNode', 1,
sub {
#line 638 "lib/RDF/Query/Parser/SPARQL.yp"
 $_[1] }
#line 9059 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule BlankNode_238
		 'BlankNode', 1,
sub {
#line 639 "lib/RDF/Query/Parser/SPARQL.yp"
 $_[1] }
#line 9066 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule IRI_REF_239
		 'IRI_REF', 1,
sub {
#line 642 "lib/RDF/Query/Parser/SPARQL.yp"
 $_[0]->new_uri($_[1]) }
#line 9073 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule PNAME_NS_240
		 'PNAME_NS', 2,
sub {
#line 646 "lib/RDF/Query/Parser/SPARQL.yp"

			return $_[1];
		}
#line 9082 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule PNAME_NS_241
		 'PNAME_NS', 1,
sub {
#line 650 "lib/RDF/Query/Parser/SPARQL.yp"

			return '__DEFAULT__';
		}
#line 9091 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule PNAME_LN_242
		 'PNAME_LN', 2,
sub {
#line 655 "lib/RDF/Query/Parser/SPARQL.yp"

	return $_[0]->new_uri([$_[1], $_[2]]);
}
#line 9100 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule BLANK_NODE_LABEL_243
		 'BLANK_NODE_LABEL', 2,
sub {
#line 659 "lib/RDF/Query/Parser/SPARQL.yp"

											my $self	= $_[0];
											my $name	= $_[2];
#											$self->register_blank_node( $name );
											return $self->new_blank( $name );
										}
#line 9112 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule PN_LOCAL_244
		 'PN_LOCAL', 2,
sub {
#line 667 "lib/RDF/Query/Parser/SPARQL.yp"

			my $name	= $_[1];
			my $extra	= $_[2];
			return join('',$name,$extra);
		}
#line 9123 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule PN_LOCAL_245
		 'PN_LOCAL', 3,
sub {
#line 672 "lib/RDF/Query/Parser/SPARQL.yp"

			my $int		= $_[1];
			my $name	= $_[2];
			my $extra	= $_[3];
			return join('',$int,$name,$extra);
		}
#line 9135 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule PN_LOCAL_246
		 'PN_LOCAL', 2,
sub {
#line 678 "lib/RDF/Query/Parser/SPARQL.yp"

			my $int		= $_[1];
			my $name	= $_[2];
			return join('',$int,$name);
		}
#line 9146 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule PN_LOCAL_247
		 'PN_LOCAL', 1,
sub {
#line 683 "lib/RDF/Query/Parser/SPARQL.yp"
 $_[1] }
#line 9153 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule PN_LOCAL_EXTRA_248
		 'PN_LOCAL_EXTRA', 1,
sub {
#line 686 "lib/RDF/Query/Parser/SPARQL.yp"
 return $_[1] }
#line 9160 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule PN_LOCAL_EXTRA_249
		 'PN_LOCAL_EXTRA', 2,
sub {
#line 687 "lib/RDF/Query/Parser/SPARQL.yp"
 return "-$_[2]" }
#line 9167 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule PN_LOCAL_EXTRA_250
		 'PN_LOCAL_EXTRA', 2,
sub {
#line 688 "lib/RDF/Query/Parser/SPARQL.yp"
 return "_$_[2]" }
#line 9174 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule VAR1_251
		 'VAR1', 2,
sub {
#line 691 "lib/RDF/Query/Parser/SPARQL.yp"
 my $self	= $_[0]; return $self->new_variable($_[2]) }
#line 9181 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule VAR2_252
		 'VAR2', 2,
sub {
#line 693 "lib/RDF/Query/Parser/SPARQL.yp"
 my $self	= $_[0]; return $self->new_variable($_[2]) }
#line 9188 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule _PLUS_LIST
		 'PLUS-52', 2,
sub {
#line 695 "lib/RDF/Query/Parser/SPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_TX1X2 }
#line 9195 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule _PLUS_LIST
		 'PLUS-52', 1,
sub {
#line 695 "lib/RDF/Query/Parser/SPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_single }
#line 9202 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule _PAREN
		 'PAREN-53', 2,
sub {
#line 695 "lib/RDF/Query/Parser/SPARQL.yp"
 goto &Parse::Eyapp::Driver::YYBuildAST }
#line 9209 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule _STAR_LIST_54
		 'STAR-54', 2,
sub {
#line 695 "lib/RDF/Query/Parser/SPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_TX1X2 }
#line 9216 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule _STAR_LIST_54
		 'STAR-54', 0,
sub {
#line 695 "lib/RDF/Query/Parser/SPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_empty }
#line 9223 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule LANGTAG_258
		 'LANGTAG', 3,
sub {
#line 695 "lib/RDF/Query/Parser/SPARQL.yp"
 join('-', $_[2], map { $_->{children}[0]{attr} } @{ $_[3]{children} }) }
#line 9230 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule INTEGER_POSITIVE_259
		 'INTEGER_POSITIVE', 2,
sub {
#line 699 "lib/RDF/Query/Parser/SPARQL.yp"
 '+' . $_[2] }
#line 9237 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule DOUBLE_POSITIVE_260
		 'DOUBLE_POSITIVE', 2,
sub {
#line 700 "lib/RDF/Query/Parser/SPARQL.yp"
 '+' . $_[2] }
#line 9244 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule DECIMAL_POSITIVE_261
		 'DECIMAL_POSITIVE', 2,
sub {
#line 701 "lib/RDF/Query/Parser/SPARQL.yp"
 '+' . $_[2] }
#line 9251 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule VARNAME_262
		 'VARNAME', 1,
sub {
#line 706 "lib/RDF/Query/Parser/SPARQL.yp"
 $_[1] }
#line 9258 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule VARNAME_263
		 'VARNAME', 1,
sub {
#line 707 "lib/RDF/Query/Parser/SPARQL.yp"
 $_[1] }
#line 9265 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule VARNAME_264
		 'VARNAME', 1,
sub {
#line 708 "lib/RDF/Query/Parser/SPARQL.yp"
 $_[1] }
#line 9272 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule VARNAME_265
		 'VARNAME', 1,
sub {
#line 709 "lib/RDF/Query/Parser/SPARQL.yp"
 $_[1] }
#line 9279 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule VARNAME_266
		 'VARNAME', 1,
sub {
#line 710 "lib/RDF/Query/Parser/SPARQL.yp"
 $_[1] }
#line 9286 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule VARNAME_267
		 'VARNAME', 1,
sub {
#line 711 "lib/RDF/Query/Parser/SPARQL.yp"
 $_[1] }
#line 9293 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule VARNAME_268
		 'VARNAME', 1,
sub {
#line 712 "lib/RDF/Query/Parser/SPARQL.yp"
 $_[1] }
#line 9300 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule VARNAME_269
		 'VARNAME', 1,
sub {
#line 713 "lib/RDF/Query/Parser/SPARQL.yp"
 $_[1] }
#line 9307 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule VARNAME_270
		 'VARNAME', 1,
sub {
#line 714 "lib/RDF/Query/Parser/SPARQL.yp"
 $_[1] }
#line 9314 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule VARNAME_271
		 'VARNAME', 1,
sub {
#line 715 "lib/RDF/Query/Parser/SPARQL.yp"
 $_[1] }
#line 9321 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule VARNAME_272
		 'VARNAME', 1,
sub {
#line 716 "lib/RDF/Query/Parser/SPARQL.yp"
 $_[1] }
#line 9328 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule VARNAME_273
		 'VARNAME', 1,
sub {
#line 717 "lib/RDF/Query/Parser/SPARQL.yp"
 $_[1] }
#line 9335 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule VARNAME_274
		 'VARNAME', 1,
sub {
#line 718 "lib/RDF/Query/Parser/SPARQL.yp"
 $_[1] }
#line 9342 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule VARNAME_275
		 'VARNAME', 1,
sub {
#line 719 "lib/RDF/Query/Parser/SPARQL.yp"
 $_[1] }
#line 9349 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule VARNAME_276
		 'VARNAME', 1,
sub {
#line 720 "lib/RDF/Query/Parser/SPARQL.yp"
 $_[1] }
#line 9356 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule VARNAME_277
		 'VARNAME', 1,
sub {
#line 721 "lib/RDF/Query/Parser/SPARQL.yp"
 $_[1] }
#line 9363 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule VARNAME_278
		 'VARNAME', 1,
sub {
#line 722 "lib/RDF/Query/Parser/SPARQL.yp"
 $_[1] }
#line 9370 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule VARNAME_279
		 'VARNAME', 1,
sub {
#line 723 "lib/RDF/Query/Parser/SPARQL.yp"
 $_[1] }
#line 9377 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule VARNAME_280
		 'VARNAME', 1,
sub {
#line 724 "lib/RDF/Query/Parser/SPARQL.yp"
 $_[1] }
#line 9384 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule VARNAME_281
		 'VARNAME', 1,
sub {
#line 725 "lib/RDF/Query/Parser/SPARQL.yp"
 $_[1] }
#line 9391 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule VARNAME_282
		 'VARNAME', 1,
sub {
#line 726 "lib/RDF/Query/Parser/SPARQL.yp"
 $_[1] }
#line 9398 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule VARNAME_283
		 'VARNAME', 1,
sub {
#line 727 "lib/RDF/Query/Parser/SPARQL.yp"
 $_[1] }
#line 9405 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule VARNAME_284
		 'VARNAME', 1,
sub {
#line 728 "lib/RDF/Query/Parser/SPARQL.yp"
 $_[1] }
#line 9412 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule VARNAME_285
		 'VARNAME', 1,
sub {
#line 729 "lib/RDF/Query/Parser/SPARQL.yp"
 $_[1] }
#line 9419 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule VARNAME_286
		 'VARNAME', 1,
sub {
#line 730 "lib/RDF/Query/Parser/SPARQL.yp"
 $_[1] }
#line 9426 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule VARNAME_287
		 'VARNAME', 1,
sub {
#line 731 "lib/RDF/Query/Parser/SPARQL.yp"
 $_[1] }
#line 9433 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule VARNAME_288
		 'VARNAME', 1,
sub {
#line 732 "lib/RDF/Query/Parser/SPARQL.yp"
 $_[1] }
#line 9440 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule VARNAME_289
		 'VARNAME', 1,
sub {
#line 733 "lib/RDF/Query/Parser/SPARQL.yp"
 $_[1] }
#line 9447 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule VARNAME_290
		 'VARNAME', 1,
sub {
#line 734 "lib/RDF/Query/Parser/SPARQL.yp"
 $_[1] }
#line 9454 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule VARNAME_291
		 'VARNAME', 1,
sub {
#line 735 "lib/RDF/Query/Parser/SPARQL.yp"
 $_[1] }
#line 9461 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule VARNAME_292
		 'VARNAME', 1,
sub {
#line 736 "lib/RDF/Query/Parser/SPARQL.yp"
 $_[1] }
#line 9468 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule VARNAME_293
		 'VARNAME', 1,
sub {
#line 737 "lib/RDF/Query/Parser/SPARQL.yp"
 $_[1] }
#line 9475 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule VARNAME_294
		 'VARNAME', 1,
sub {
#line 738 "lib/RDF/Query/Parser/SPARQL.yp"
 $_[1] }
#line 9482 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule VARNAME_295
		 'VARNAME', 1,
sub {
#line 739 "lib/RDF/Query/Parser/SPARQL.yp"
 $_[1] }
#line 9489 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule _STAR_LIST_55
		 'STAR-55', 2,
sub {
#line 742 "lib/RDF/Query/Parser/SPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_TX1X2 }
#line 9496 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule _STAR_LIST_55
		 'STAR-55', 0,
sub {
#line 742 "lib/RDF/Query/Parser/SPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_empty }
#line 9503 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule NIL_298
		 'NIL', 3,
sub {
#line 742 "lib/RDF/Query/Parser/SPARQL.yp"
 $_[0]->new_uri('http://www.w3.org/1999/02/22-rdf-syntax-ns#nil') }
#line 9510 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule _STAR_LIST_56
		 'STAR-56', 2,
sub {
#line 744 "lib/RDF/Query/Parser/SPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_TX1X2 }
#line 9517 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule _STAR_LIST_56
		 'STAR-56', 0,
sub {
#line 744 "lib/RDF/Query/Parser/SPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_empty }
#line 9524 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule ANON_301
		 'ANON', 3,
sub {
#line 744 "lib/RDF/Query/Parser/SPARQL.yp"
 $_[0]->new_blank() }
#line 9531 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule INTEGER_302
		 'INTEGER', 1,
sub {
#line 748 "lib/RDF/Query/Parser/SPARQL.yp"
 $_[1] }
#line 9538 lib/RDF/Query/Parser/SPARQL.pm
	],
	[#Rule INTEGER_303
		 'INTEGER', 1,
sub {
#line 749 "lib/RDF/Query/Parser/SPARQL.yp"
 $_[1] }
#line 9545 lib/RDF/Query/Parser/SPARQL.pm
	]
],
#line 9548 lib/RDF/Query/Parser/SPARQL.pm
                                  yybypass => 0,
                                  @_,);
    bless($self,$class);

    $self->make_node_classes( qw{TERMINAL _OPTIONAL _STAR_LIST _PLUS_LIST 
         _SUPERSTART
         Query_1
         Query_2
         Query_3
         Query_4
         _STAR_LIST_2
         Prologue_9
         BaseDecl_10
         PrefixDecl_11
         _STAR_LIST_4
         SelectQuery_16
         SelectModifier_17
         SelectModifier_18
         SelectVars_21
         SelectVars_22
         _STAR_LIST_6
         ConstructQuery_25
         _STAR_LIST_7
         DescribeQuery_30
         DescribeVars_33
         DescribeVars_34
         _STAR_LIST_10
         AskQuery_37
         DatasetClause_38
         DatasetClause_39
         DefaultGraphClause_40
         NamedGraphClause_41
         SourceSelector_42
         WhereClause_45
         SolutionModifier_50
         LimitOffsetClauses_55
         LimitOffsetClauses_56
         OrderClause_59
         OrderCondition_60
         OrderCondition_61
         OrderCondition_62
         OrderDirection_63
         OrderDirection_64
         LimitClause_65
         OffsetClause_66
         _PAREN
         _STAR_LIST_21
         GroupGraphPattern_76
         GGPAtom_77
         GGPAtom_78
         TriplesBlock_84
         GraphPatternNotTriples_85
         GraphPatternNotTriples_86
         GraphPatternNotTriples_87
         OptionalGraphPattern_88
         GraphGraphPattern_89
         _STAR_LIST_26
         GroupOrUnionGraphPattern_93
         Filter_94
         Constraint_95
         Constraint_96
         Constraint_97
         FunctionCall_98
         _STAR_LIST_28
         ArgList_102
         ArgList_103
         ConstructTemplate_106
         ConstructTriples_112
         TriplesSameSubject_113
         TriplesSameSubject_114
         _STAR_LIST_36
         PropertyListNotEmpty_121
         PropertyList_124
         _STAR_LIST_39
         ObjectList_128
         Object_129
         Verb_130
         Verb_131
         TriplesNode_132
         TriplesNode_133
         BlankNodePropertyList_134
         Collection_137
         GraphNode_138
         GraphNode_139
         VarOrTerm_140
         VarOrTerm_141
         VarOrIRIref_142
         VarOrIRIref_143
         Var_144
         Var_145
         GraphTerm_146
         GraphTerm_147
         GraphTerm_148
         GraphTerm_149
         GraphTerm_150
         GraphTerm_151
         Expression_152
         _STAR_LIST_42
         ConditionalOrExpression_156
         _STAR_LIST_44
         ConditionalAndExpression_160
         ValueLogical_161
         RelationalExpression_164
         RelationalExpressionExtra_165
         RelationalExpressionExtra_166
         RelationalExpressionExtra_167
         RelationalExpressionExtra_168
         RelationalExpressionExtra_169
         RelationalExpressionExtra_170
         NumericExpression_171
         _STAR_LIST_46
         AdditiveExpression_174
         AdditiveExpressionExtra_175
         AdditiveExpressionExtra_176
         AdditiveExpressionExtra_177
         AdditiveExpressionExtra_178
         _STAR_LIST_47
         MultiplicativeExpression_181
         MultiplicativeExpressionExtra_182
         MultiplicativeExpressionExtra_183
         UnaryExpression_184
         UnaryExpression_185
         UnaryExpression_186
         UnaryExpression_187
         PrimaryExpression_188
         PrimaryExpression_189
         PrimaryExpression_190
         PrimaryExpression_191
         PrimaryExpression_192
         PrimaryExpression_193
         PrimaryExpression_194
         BrackettedExpression_195
         BuiltInCall_196
         BuiltInCall_197
         BuiltInCall_198
         BuiltInCall_199
         BuiltInCall_200
         BuiltInCall_201
         BuiltInCall_202
         BuiltInCall_203
         BuiltInCall_204
         BuiltInCall_205
         BuiltInCall_206
         RegexExpression_210
         IRIrefOrFunction_213
         RDFLiteral_216
         LiteralExtra_217
         LiteralExtra_218
         NumericLiteral_219
         NumericLiteral_220
         NumericLiteral_221
         NumericLiteralUnsigned_222
         NumericLiteralUnsigned_223
         NumericLiteralUnsigned_224
         NumericLiteralPositive_225
         NumericLiteralPositive_226
         NumericLiteralPositive_227
         NumericLiteralNegative_228
         NumericLiteralNegative_229
         NumericLiteralNegative_230
         BooleanLiteral_231
         BooleanLiteral_232
         IRIref_233
         IRIref_234
         PrefixedName_235
         PrefixedName_236
         BlankNode_237
         BlankNode_238
         IRI_REF_239
         PNAME_NS_240
         PNAME_NS_241
         PNAME_LN_242
         BLANK_NODE_LABEL_243
         PN_LOCAL_244
         PN_LOCAL_245
         PN_LOCAL_246
         PN_LOCAL_247
         PN_LOCAL_EXTRA_248
         PN_LOCAL_EXTRA_249
         PN_LOCAL_EXTRA_250
         VAR1_251
         VAR2_252
         _STAR_LIST_54
         LANGTAG_258
         INTEGER_POSITIVE_259
         DOUBLE_POSITIVE_260
         DECIMAL_POSITIVE_261
         VARNAME_262
         VARNAME_263
         VARNAME_264
         VARNAME_265
         VARNAME_266
         VARNAME_267
         VARNAME_268
         VARNAME_269
         VARNAME_270
         VARNAME_271
         VARNAME_272
         VARNAME_273
         VARNAME_274
         VARNAME_275
         VARNAME_276
         VARNAME_277
         VARNAME_278
         VARNAME_279
         VARNAME_280
         VARNAME_281
         VARNAME_282
         VARNAME_283
         VARNAME_284
         VARNAME_285
         VARNAME_286
         VARNAME_287
         VARNAME_288
         VARNAME_289
         VARNAME_290
         VARNAME_291
         VARNAME_292
         VARNAME_293
         VARNAME_294
         VARNAME_295
         _STAR_LIST_55
         NIL_298
         _STAR_LIST_56
         ANON_301
         INTEGER_302
         INTEGER_303} );
    $self;
}

#line 762 "lib/RDF/Query/Parser/SPARQL.yp"


# RDF::Query::Parser::SPARQL
# -------------
# $Revision: 194 $
# $Date: 2007-04-18 22:26:36 -0400 (Wed, 18 Apr 2007) $
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Parser::SPARQL - A SPARQL parser for RDF::Query

=cut

package RDF::Query::Parser::SPARQL;

use strict;
use warnings;
use base qw(RDF::Query::Parser);

use RDF::Query::Algebra;
use RDF::Query::Error qw(:try);

use Data::Dumper;
use Carp qw(carp croak confess);
use Unicode::Normalize qw(normalize compose);
use Scalar::Util qw(reftype blessed);

######################################################################

our ($VERSION, $debug, $lang, $languri);
BEGIN {
	$debug		= 0 || $RDF::Query::Parser::debug;
	$VERSION	= $RDF::Query::VERSION;
	$lang		= 'sparql';
	$languri	= 'http://www.w3.org/TR/rdf-sparql-query/';
}


######################################################################

=head1 METHODS

=over 4

=cut

our %EXPECT_DESC	= (
	'{'			=> 'GroupGraphPattern or ConstuctTemplate',
	'('			=> 'ArgList, Collection, BrackettedExpression or NIL',
	map { $_ => $_ } qw(SELECT ASK DESCRIBE CONSTRUCT FILTER GRAPH OPTIONAL),
);


=item C<< new () >>

Returns a new SPARQL parser object.

=begin private

=item C<< Run >>

Internal Parse::Eyapp method.

=end private



=item C<< parse ( $query ) >>

Parses the supplied SPARQL query string, returning a parse tree.

=cut

sub parse {
	my $self	= shift;
	my $_query	= shift;
	my $query	= normalize('C', $_query);
	undef $self->{error};
	undef $self->{__registered_blank_nodes};
	$self->YYData->{INPUT} = $query;
	$self->{blank_ids}		= 1;
	my $t = eval { $self->Run };                    # Parse it!
	
	if ($@) {
#		warn $@;	# XXX
		return;
	} else {
		my $ok;
		try {
			$t->{triples}->check_duplicate_blanks;
			my $base	= (exists($t->{base})) ? $t->{base} : undef;
			$t->{triples}	= $t->{triples}->qualify_uris( $t->{'namespaces'}, $base );
			if (exists($t->{construct_triples})) {
				$t->{construct_triples}	= $t->{construct_triples}->qualify_uris( $t->{'namespaces'}, $base );
			}
			$ok	= 1;
		} catch RDF::Query::Error with {
			my $e	= shift;
			$self->set_error( "Syntax error; " . $e->{'-text'} );
			$ok	= 0;
		};
		
		if ($ok) {
			return $t;
		} else {
			return;
		}
	}
}

=item C<< error >>

Returns the latest parse error string.

=cut

sub error {
	my $self	= shift;
	if (defined($self->{error})) {
		return $self->{error};
	} else {
		return;
	}
}


{
my $last;
sub _Lexer {
	my $self	= shift;
	my ($type,$value)	= __Lexer( $self, $last );
#	warn "$type\t=> $value\n";
#	warn "pos => " . pos($self->YYData->{INPUT}) . "\n";
#	warn "len => " . length($self->YYData->{INPUT}) . "\n";
	$last	= [$type,$value];
	no warnings 'uninitialized';
	return ($type,"$value");
}
}

sub __new_value {
	my $parser	= shift;
	my $value	= shift;
	my $ws		= shift;
	return $value;
#		return RDF::Query::Parser::SPARQL::Value->new( $token, $value );
}

sub _literal_escape {
	my $value	= shift;
	for ($value) {
		s/\\t/\t/g;
		s/\\n/\n/g;
		s/\\r/\r/g;
		s/\\b/\b/g;
		s/\\f/\f/g;
		s/\\"/"/g;
		s/\\'/'/g;
		s/\\\\/\\/g;
	}
	return $value;
}

sub __Lexer {
	my $parser	= shift;
	my $last	= shift;
	my $lasttok	= $last->[0];
	
	for ($parser->YYData->{INPUT}) {
		my $index	= pos($_) || -1;
		return if ($index == length($parser->YYData->{INPUT}));
		
		my $ws	= 0;
#		warn "lexing at: " . substr($_,$index,20) . " ...\n";
		while (m{\G\s+}gc or m{\G#(.*)}gc) {	# WS and comments
			$ws	= 1;
		}
			
#		m{\G(\s*|#(.*))}gc and return('WS',$1);	# WS and comments
		
		m{\G(
				ASC\b
			|	ASK\b
			|	BASE\b
			|	BOUND\b
			|	CONSTRUCT\b
			|	DATATYPE\b
			|	DESCRIBE\b
			|	DESC\b
			|	DISTINCT\b
			|	FILTER\b
			|	FROM[ ]NAMED\b
			|	FROM\b
			|	GRAPH\b
			|	LANGMATCHES\b
			|	LANG\b
			|	LIMIT\b
			|	NAMED\b
			|	OFFSET\b
			|	OPTIONAL\b
			|	ORDER[ ]BY\b
			|	PREFIX\b
			|	REDUCED\b
			|	REGEX\b
			|	SELECT\b
			|	STR\b
			|	UNION\b
			|	WHERE\b
			|	isBLANK\b
			|	isIRI\b
			|	isLITERAL\b
			|	isURI\b
			|	sameTerm\b
			|	true\b
			|	false\b
		)}xigc and return(uc($1), $parser->__new_value( $1, $ws ));
		m{\G(
				a(?=(\s|[#]))\b
		
		)}xgc and return($1,$parser->__new_value( $1, $ws ));
		
		
		m{\G'''((?:('|'')?(\\([tbnrf\\"'])|[^'\x92]))*)'''}gc and return('STRING',$parser->__new_value( _literal_escape($1), $ws ));
		m{\G"""((?:(?:"|"")?(?:\\(?:[tbnrf\\"'])|[^"\x92]))*)"""}gc and return('STRING',$parser->__new_value( _literal_escape($1), $ws ));
		m{\G'((([^\x27\x5C\x0A\x0D])|\\([tbnrf\\"']))*)'}gc and return('STRING',$parser->__new_value( _literal_escape($1), $ws ));
		m{\G"((([^\x22\x5C\x0A\x0D])|\\([tbnrf\\"']))*)"}gc and return('STRING',$parser->__new_value( _literal_escape($1), $ws ));
		
		
		m{\G<([^<>"{}|^`\x92]*)>}gc and return('URI',$parser->__new_value( $1, $ws ));
		
		m{\G(
				!=
			|	&&
			|	<=
			|	>=
			|	\Q||\E
			|	\Q^^\E
			|	_:
		)}xgc and return($1,$parser->__new_value( $1, $ws ));
		
		m{\G([_A-Za-z][._A-Za-z0-9]*)}gc and return('NAME',$parser->__new_value( $1, $ws ));
		m{\G([_A-Za-z\x{00C0}-\x{00D6}\x{00D8}-\x{00F6}\x{00F8}-\x{02FF}\x{0300}-\x{36F}\x{0370}-\x{037D}\x{037F}-\x{1FFF}\x{200C}-\x{200D}\x{203F}-\x{2040}\x{2070}-\x{218F}\x{2C00}-\x{2FEF}\x{3001}-\x{D7FF}\x{F900}-\x{FDCF}\x{FDF0}-\x{FFFD}\x{10000}-\x{EFFFF}]+)}gc and return('NAME',$parser->__new_value( $1, $ws ));
		m{\G([_A-Za-z\x{00C0}-\x{00D6}\x{00D8}-\x{00F6}\x{00F8}-\x{02FF}\x{0370}-\x{037D}\x{037F}-\x{1FFF}\x{200C}-\x{200D}\x{2070}-\x{218F}\x{2C00}-\x{2FEF}\x{3001}-\x{D7FF}\x{F900}-\x{FDCF}\x{FDF0}-\x{FFFD}\x{10000}-\x{EFFFF}]+)}gc and return('NAME',$parser->__new_value( $1, $ws ));
		
		m{\G([-]?(\d+)?[.](\d+)[eE][+-]?[0-9]+)}gc and return('DOUBLE',$parser->__new_value( $1, $ws ));
		m{\G([-]?\d+[eE][+-]?[0-9]+)}gc and return('DOUBLE',$parser->__new_value( $1, $ws ));
		m{\G([-]?(\d+[.]\d*|[.]\d+))}gc and return('DECIMAL',$parser->__new_value( $1, $ws ));
		if ($ws) {
			m{\G([-]?\d+)}gc and return('INTEGER_WS',$parser->__new_value( $1, $ws ));
		} else {
			m{\G([-]?\d+)}gc and return('INTEGER_NO_WS',$parser->__new_value( $1, $ws ));
		}
		
		
		m{\G([@!$()*+,./:;<=>?\{\}\[\]\\-])}gc and return($1,$parser->__new_value( $1, $ws ));
		
		my $p	= pos();
		my $l	= length();
		if ($p < $l) {
			warn "uh oh! input = '" . substr($_, $p, 10) . "'";
			warn "hex dump: " . join(' ', map { sprintf('%x', ord($_)) } split(//, substr($_,$p,10)));
		}
		return ('', undef);
	}
};

sub Run {
	my($self)=shift;
	for ($self->YYData->{INPUT}) {
		s/\\u([0-9a-fA-F]{4})/chr(hex($1))/ge;
		s/\\U([0-9a-fA-F]{8})/chr(hex($1))/ge;
	}
	$self->YYParse(
		yylex	=> \&_Lexer,
		yyerror	=> \&_Error,
		yydebug	=> 0,#0x01 | 0x04, #0x01 | 0x04,	# XXX
	);
}

sub _Error {
	my $parser	= shift;
	my($token)=$parser->YYCurval;
	my($what)	= $token ? "input: '$token'" : "end of input";
	my @expected = $parser->YYExpect();
	
	my $error;
	if (scalar(@expected) == 1 and $expected[0] eq '') {
		$error	= "Syntax error; Remaining input";
	} else {
		our %EXPECT_DESC;
		if (exists $EXPECT_DESC{ $expected[0] }) {
			my @expect	= @EXPECT_DESC{ @expected };
			if (@expect > 1) {
				my $a	= pop(@expect);
				my $b	= pop(@expect);
				no warnings 'uninitialized';
				push(@expect, "$a or $b");
			}
			
			my $expect	= join(', ', @expect);
			if ($expect eq 'DESCRIBE, ASK, CONSTRUCT or SELECT') {
				$expect	= 'query type';
			}
			$error	= "Syntax error; Expecting $expect near $what";
		} else {
			use utf8;
			$error	= "Syntax error; Expected one of the following terminals (near $what): " . join(', ', map {"«$_»"} @expected);
		}
	}
	
	$parser->{error}	= $error;
	Carp::confess $error;
}



1;

__END__

=back

=head1 AUTHOR

 Gregory Williams <gwilliams@cpan.org>

=cut


#line 10110 lib/RDF/Query/Parser/SPARQL.pm

1;
