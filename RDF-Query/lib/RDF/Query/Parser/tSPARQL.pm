###################################################################################
#
#    This file was generated using Parse::Eyapp version 1.082.
#
# (c) Parse::Yapp Copyright 1998-2001 Francois Desarmenien.
# (c) Parse::Eyapp Copyright 2006 Casiano Rodriguez-Leon. Universidad de La Laguna.
#        Don't edit this file, use source file "lib/RDF/Query/Parser/tSPARQL.yp" instead.
#
#             ANY CHANGE MADE HERE WILL BE LOST !
#
###################################################################################
package RDF::Query::Parser::tSPARQL;
use strict;
no warnings 'ambiguous';
no warnings 'redefine';

push @RDF::Query::Parser::tSPARQL::ISA, 'Parse::Eyapp::Driver';


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
no warnings 'ambiguous';
no warnings 'redefine';
no warnings 'uninitialized';

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
no warnings 'ambiguous';
no warnings 'redefine';
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
no warnings 'ambiguous';
no warnings 'redefine';
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
no warnings 'ambiguous';
no warnings 'redefine';
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



#line 1984 lib/RDF/Query/Parser/tSPARQL.pm

my $warnmessage =<< "EOFWARN";
Warning!: Did you changed the \@RDF::Query::Parser::tSPARQL::ISA variable inside the header section of the eyapp program?
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
  [ GraphPatternNotTriples_88 => 'GraphPatternNotTriples', [ 'TimeGraphPattern' ], 0 ],
  [ TimeGraphPattern_89 => 'TimeGraphPattern', [ 'TIME', 'GraphNode', 'GroupGraphPattern' ], 0 ],
  [ OptionalGraphPattern_90 => 'OptionalGraphPattern', [ 'OPTIONAL', 'GroupGraphPattern' ], 0 ],
  [ GraphGraphPattern_91 => 'GraphGraphPattern', [ 'GRAPH', 'VarOrIRIref', 'GroupGraphPattern' ], 0 ],
  [ _PAREN => 'PAREN-25', [ 'UNION', 'GroupGraphPattern' ], 0 ],
  [ _STAR_LIST_26 => 'STAR-26', [ 'STAR-26', 'PAREN-25' ], 0 ],
  [ _STAR_LIST_26 => 'STAR-26', [  ], 0 ],
  [ GroupOrUnionGraphPattern_95 => 'GroupOrUnionGraphPattern', [ 'GroupGraphPattern', 'STAR-26' ], 0 ],
  [ Filter_96 => 'Filter', [ 'FILTER', 'Constraint' ], 0 ],
  [ Constraint_97 => 'Constraint', [ 'BrackettedExpression' ], 0 ],
  [ Constraint_98 => 'Constraint', [ 'BuiltInCall' ], 0 ],
  [ Constraint_99 => 'Constraint', [ 'FunctionCall' ], 0 ],
  [ FunctionCall_100 => 'FunctionCall', [ 'IRIref', 'ArgList' ], 0 ],
  [ _PAREN => 'PAREN-27', [ ',', 'Expression' ], 0 ],
  [ _STAR_LIST_28 => 'STAR-28', [ 'STAR-28', 'PAREN-27' ], 0 ],
  [ _STAR_LIST_28 => 'STAR-28', [  ], 0 ],
  [ ArgList_104 => 'ArgList', [ '(', 'Expression', 'STAR-28', ')' ], 0 ],
  [ ArgList_105 => 'ArgList', [ 'NIL' ], 0 ],
  [ _OPTIONAL => 'OPTIONAL-29', [ 'ConstructTriples' ], 0 ],
  [ _OPTIONAL => 'OPTIONAL-29', [  ], 0 ],
  [ ConstructTemplate_108 => 'ConstructTemplate', [ '{', 'OPTIONAL-29', '}' ], 0 ],
  [ _OPTIONAL => 'OPTIONAL-30', [ 'ConstructTriples' ], 0 ],
  [ _OPTIONAL => 'OPTIONAL-30', [  ], 0 ],
  [ _PAREN => 'PAREN-31', [ '.', 'OPTIONAL-30' ], 0 ],
  [ _OPTIONAL => 'OPTIONAL-32', [ 'PAREN-31' ], 0 ],
  [ _OPTIONAL => 'OPTIONAL-32', [  ], 0 ],
  [ ConstructTriples_114 => 'ConstructTriples', [ 'TriplesSameSubject', 'OPTIONAL-32' ], 0 ],
  [ TriplesSameSubject_115 => 'TriplesSameSubject', [ 'VarOrTerm', 'PropertyListNotEmpty' ], 0 ],
  [ TriplesSameSubject_116 => 'TriplesSameSubject', [ 'TriplesNode', 'PropertyList' ], 0 ],
  [ _PAREN => 'PAREN-33', [ 'Verb', 'ObjectList' ], 0 ],
  [ _OPTIONAL => 'OPTIONAL-34', [ 'PAREN-33' ], 0 ],
  [ _OPTIONAL => 'OPTIONAL-34', [  ], 0 ],
  [ _PAREN => 'PAREN-35', [ ';', 'OPTIONAL-34' ], 0 ],
  [ _STAR_LIST_36 => 'STAR-36', [ 'STAR-36', 'PAREN-35' ], 0 ],
  [ _STAR_LIST_36 => 'STAR-36', [  ], 0 ],
  [ PropertyListNotEmpty_123 => 'PropertyListNotEmpty', [ 'Verb', 'ObjectList', 'STAR-36' ], 0 ],
  [ _OPTIONAL => 'OPTIONAL-37', [ 'PropertyListNotEmpty' ], 0 ],
  [ _OPTIONAL => 'OPTIONAL-37', [  ], 0 ],
  [ PropertyList_126 => 'PropertyList', [ 'OPTIONAL-37' ], 0 ],
  [ _PAREN => 'PAREN-38', [ ',', 'Object' ], 0 ],
  [ _STAR_LIST_39 => 'STAR-39', [ 'STAR-39', 'PAREN-38' ], 0 ],
  [ _STAR_LIST_39 => 'STAR-39', [  ], 0 ],
  [ ObjectList_130 => 'ObjectList', [ 'Object', 'STAR-39' ], 0 ],
  [ Object_131 => 'Object', [ 'GraphNode' ], 0 ],
  [ Verb_132 => 'Verb', [ 'VarOrIRIref' ], 0 ],
  [ Verb_133 => 'Verb', [ 'a' ], 0 ],
  [ TriplesNode_134 => 'TriplesNode', [ 'Collection' ], 0 ],
  [ TriplesNode_135 => 'TriplesNode', [ 'BlankNodePropertyList' ], 0 ],
  [ BlankNodePropertyList_136 => 'BlankNodePropertyList', [ '[', 'PropertyListNotEmpty', ']' ], 0 ],
  [ _PLUS_LIST => 'PLUS-40', [ 'PLUS-40', 'GraphNode' ], 0 ],
  [ _PLUS_LIST => 'PLUS-40', [ 'GraphNode' ], 0 ],
  [ Collection_139 => 'Collection', [ '(', 'PLUS-40', ')' ], 0 ],
  [ GraphNode_140 => 'GraphNode', [ 'VarOrTerm' ], 0 ],
  [ GraphNode_141 => 'GraphNode', [ 'TriplesNode' ], 0 ],
  [ VarOrTerm_142 => 'VarOrTerm', [ 'Var' ], 0 ],
  [ VarOrTerm_143 => 'VarOrTerm', [ 'GraphTerm' ], 0 ],
  [ VarOrIRIref_144 => 'VarOrIRIref', [ 'Var' ], 0 ],
  [ VarOrIRIref_145 => 'VarOrIRIref', [ 'IRIref' ], 0 ],
  [ Var_146 => 'Var', [ 'VAR1' ], 0 ],
  [ Var_147 => 'Var', [ 'VAR2' ], 0 ],
  [ GraphTerm_148 => 'GraphTerm', [ 'IRIref' ], 0 ],
  [ GraphTerm_149 => 'GraphTerm', [ 'RDFLiteral' ], 0 ],
  [ GraphTerm_150 => 'GraphTerm', [ 'NumericLiteral' ], 0 ],
  [ GraphTerm_151 => 'GraphTerm', [ 'BooleanLiteral' ], 0 ],
  [ GraphTerm_152 => 'GraphTerm', [ 'BlankNode' ], 0 ],
  [ GraphTerm_153 => 'GraphTerm', [ 'NIL' ], 0 ],
  [ Expression_154 => 'Expression', [ 'ConditionalOrExpression' ], 0 ],
  [ _PAREN => 'PAREN-41', [ '||', 'ConditionalAndExpression' ], 0 ],
  [ _STAR_LIST_42 => 'STAR-42', [ 'STAR-42', 'PAREN-41' ], 0 ],
  [ _STAR_LIST_42 => 'STAR-42', [  ], 0 ],
  [ ConditionalOrExpression_158 => 'ConditionalOrExpression', [ 'ConditionalAndExpression', 'STAR-42' ], 0 ],
  [ _PAREN => 'PAREN-43', [ '&&', 'ValueLogical' ], 0 ],
  [ _STAR_LIST_44 => 'STAR-44', [ 'STAR-44', 'PAREN-43' ], 0 ],
  [ _STAR_LIST_44 => 'STAR-44', [  ], 0 ],
  [ ConditionalAndExpression_162 => 'ConditionalAndExpression', [ 'ValueLogical', 'STAR-44' ], 0 ],
  [ ValueLogical_163 => 'ValueLogical', [ 'RelationalExpression' ], 0 ],
  [ _OPTIONAL => 'OPTIONAL-45', [ 'RelationalExpressionExtra' ], 0 ],
  [ _OPTIONAL => 'OPTIONAL-45', [  ], 0 ],
  [ RelationalExpression_166 => 'RelationalExpression', [ 'NumericExpression', 'OPTIONAL-45' ], 0 ],
  [ RelationalExpressionExtra_167 => 'RelationalExpressionExtra', [ '=', 'NumericExpression' ], 0 ],
  [ RelationalExpressionExtra_168 => 'RelationalExpressionExtra', [ '!=', 'NumericExpression' ], 0 ],
  [ RelationalExpressionExtra_169 => 'RelationalExpressionExtra', [ '<', 'NumericExpression' ], 0 ],
  [ RelationalExpressionExtra_170 => 'RelationalExpressionExtra', [ '>', 'NumericExpression' ], 0 ],
  [ RelationalExpressionExtra_171 => 'RelationalExpressionExtra', [ '<=', 'NumericExpression' ], 0 ],
  [ RelationalExpressionExtra_172 => 'RelationalExpressionExtra', [ '>=', 'NumericExpression' ], 0 ],
  [ NumericExpression_173 => 'NumericExpression', [ 'AdditiveExpression' ], 0 ],
  [ _STAR_LIST_46 => 'STAR-46', [ 'STAR-46', 'AdditiveExpressionExtra' ], 0 ],
  [ _STAR_LIST_46 => 'STAR-46', [  ], 0 ],
  [ AdditiveExpression_176 => 'AdditiveExpression', [ 'MultiplicativeExpression', 'STAR-46' ], 0 ],
  [ AdditiveExpressionExtra_177 => 'AdditiveExpressionExtra', [ '+', 'MultiplicativeExpression' ], 0 ],
  [ AdditiveExpressionExtra_178 => 'AdditiveExpressionExtra', [ '-', 'MultiplicativeExpression' ], 0 ],
  [ AdditiveExpressionExtra_179 => 'AdditiveExpressionExtra', [ 'NumericLiteralPositive' ], 0 ],
  [ AdditiveExpressionExtra_180 => 'AdditiveExpressionExtra', [ 'NumericLiteralNegative' ], 0 ],
  [ _STAR_LIST_47 => 'STAR-47', [ 'STAR-47', 'MultiplicativeExpressionExtra' ], 0 ],
  [ _STAR_LIST_47 => 'STAR-47', [  ], 0 ],
  [ MultiplicativeExpression_183 => 'MultiplicativeExpression', [ 'UnaryExpression', 'STAR-47' ], 0 ],
  [ MultiplicativeExpressionExtra_184 => 'MultiplicativeExpressionExtra', [ '*', 'UnaryExpression' ], 0 ],
  [ MultiplicativeExpressionExtra_185 => 'MultiplicativeExpressionExtra', [ '/', 'UnaryExpression' ], 0 ],
  [ UnaryExpression_186 => 'UnaryExpression', [ '!', 'PrimaryExpression' ], 0 ],
  [ UnaryExpression_187 => 'UnaryExpression', [ '+', 'PrimaryExpression' ], 0 ],
  [ UnaryExpression_188 => 'UnaryExpression', [ '-', 'PrimaryExpression' ], 0 ],
  [ UnaryExpression_189 => 'UnaryExpression', [ 'PrimaryExpression' ], 0 ],
  [ PrimaryExpression_190 => 'PrimaryExpression', [ 'BrackettedExpression' ], 0 ],
  [ PrimaryExpression_191 => 'PrimaryExpression', [ 'BuiltInCall' ], 0 ],
  [ PrimaryExpression_192 => 'PrimaryExpression', [ 'IRIrefOrFunction' ], 0 ],
  [ PrimaryExpression_193 => 'PrimaryExpression', [ 'RDFLiteral' ], 0 ],
  [ PrimaryExpression_194 => 'PrimaryExpression', [ 'NumericLiteral' ], 0 ],
  [ PrimaryExpression_195 => 'PrimaryExpression', [ 'BooleanLiteral' ], 0 ],
  [ PrimaryExpression_196 => 'PrimaryExpression', [ 'Var' ], 0 ],
  [ BrackettedExpression_197 => 'BrackettedExpression', [ '(', 'Expression', ')' ], 0 ],
  [ BuiltInCall_198 => 'BuiltInCall', [ 'STR', '(', 'Expression', ')' ], 0 ],
  [ BuiltInCall_199 => 'BuiltInCall', [ 'LANG', '(', 'Expression', ')' ], 0 ],
  [ BuiltInCall_200 => 'BuiltInCall', [ 'LANGMATCHES', '(', 'Expression', ',', 'Expression', ')' ], 0 ],
  [ BuiltInCall_201 => 'BuiltInCall', [ 'DATATYPE', '(', 'Expression', ')' ], 0 ],
  [ BuiltInCall_202 => 'BuiltInCall', [ 'BOUND', '(', 'Var', ')' ], 0 ],
  [ BuiltInCall_203 => 'BuiltInCall', [ 'SAMETERM', '(', 'Expression', ',', 'Expression', ')' ], 0 ],
  [ BuiltInCall_204 => 'BuiltInCall', [ 'ISIRI', '(', 'Expression', ')' ], 0 ],
  [ BuiltInCall_205 => 'BuiltInCall', [ 'ISURI', '(', 'Expression', ')' ], 0 ],
  [ BuiltInCall_206 => 'BuiltInCall', [ 'ISBLANK', '(', 'Expression', ')' ], 0 ],
  [ BuiltInCall_207 => 'BuiltInCall', [ 'ISLITERAL', '(', 'Expression', ')' ], 0 ],
  [ BuiltInCall_208 => 'BuiltInCall', [ 'RegexExpression' ], 0 ],
  [ _PAREN => 'PAREN-48', [ ',', 'Expression' ], 0 ],
  [ _OPTIONAL => 'OPTIONAL-49', [ 'PAREN-48' ], 0 ],
  [ _OPTIONAL => 'OPTIONAL-49', [  ], 0 ],
  [ RegexExpression_212 => 'RegexExpression', [ 'REGEX', '(', 'Expression', ',', 'Expression', 'OPTIONAL-49', ')' ], 0 ],
  [ _OPTIONAL => 'OPTIONAL-50', [ 'ArgList' ], 0 ],
  [ _OPTIONAL => 'OPTIONAL-50', [  ], 0 ],
  [ IRIrefOrFunction_215 => 'IRIrefOrFunction', [ 'IRIref', 'OPTIONAL-50' ], 0 ],
  [ _OPTIONAL => 'OPTIONAL-51', [ 'LiteralExtra' ], 0 ],
  [ _OPTIONAL => 'OPTIONAL-51', [  ], 0 ],
  [ RDFLiteral_218 => 'RDFLiteral', [ 'STRING', 'OPTIONAL-51' ], 0 ],
  [ LiteralExtra_219 => 'LiteralExtra', [ 'LANGTAG' ], 0 ],
  [ LiteralExtra_220 => 'LiteralExtra', [ '^^', 'IRIref' ], 0 ],
  [ NumericLiteral_221 => 'NumericLiteral', [ 'NumericLiteralUnsigned' ], 0 ],
  [ NumericLiteral_222 => 'NumericLiteral', [ 'NumericLiteralPositive' ], 0 ],
  [ NumericLiteral_223 => 'NumericLiteral', [ 'NumericLiteralNegative' ], 0 ],
  [ NumericLiteralUnsigned_224 => 'NumericLiteralUnsigned', [ 'INTEGER' ], 0 ],
  [ NumericLiteralUnsigned_225 => 'NumericLiteralUnsigned', [ 'DECIMAL' ], 0 ],
  [ NumericLiteralUnsigned_226 => 'NumericLiteralUnsigned', [ 'DOUBLE' ], 0 ],
  [ NumericLiteralPositive_227 => 'NumericLiteralPositive', [ 'INTEGER_POSITIVE' ], 0 ],
  [ NumericLiteralPositive_228 => 'NumericLiteralPositive', [ 'DECIMAL_POSITIVE' ], 0 ],
  [ NumericLiteralPositive_229 => 'NumericLiteralPositive', [ 'DOUBLE_POSITIVE' ], 0 ],
  [ NumericLiteralNegative_230 => 'NumericLiteralNegative', [ 'INTEGER_NEGATIVE' ], 0 ],
  [ NumericLiteralNegative_231 => 'NumericLiteralNegative', [ 'DECIMAL_NEGATIVE' ], 0 ],
  [ NumericLiteralNegative_232 => 'NumericLiteralNegative', [ 'DOUBLE_NEGATIVE' ], 0 ],
  [ BooleanLiteral_233 => 'BooleanLiteral', [ 'TRUE' ], 0 ],
  [ BooleanLiteral_234 => 'BooleanLiteral', [ 'FALSE' ], 0 ],
  [ IRIref_235 => 'IRIref', [ 'IRI_REF' ], 0 ],
  [ IRIref_236 => 'IRIref', [ 'PrefixedName' ], 0 ],
  [ PrefixedName_237 => 'PrefixedName', [ 'PNAME_LN' ], 0 ],
  [ PrefixedName_238 => 'PrefixedName', [ 'PNAME_NS' ], 0 ],
  [ BlankNode_239 => 'BlankNode', [ 'BLANK_NODE_LABEL' ], 0 ],
  [ BlankNode_240 => 'BlankNode', [ 'ANON' ], 0 ],
  [ IRI_REF_241 => 'IRI_REF', [ 'URI' ], 0 ],
  [ PNAME_NS_242 => 'PNAME_NS', [ 'NAME', ':' ], 0 ],
  [ PNAME_NS_243 => 'PNAME_NS', [ ':' ], 0 ],
  [ PNAME_LN_244 => 'PNAME_LN', [ 'PNAME_NS', 'PN_LOCAL' ], 0 ],
  [ BLANK_NODE_LABEL_245 => 'BLANK_NODE_LABEL', [ '_:', 'PN_LOCAL' ], 0 ],
  [ PN_LOCAL_246 => 'PN_LOCAL', [ 'VARNAME', 'PN_LOCAL_EXTRA' ], 0 ],
  [ PN_LOCAL_247 => 'PN_LOCAL', [ 'INTEGER', 'VARNAME', 'PN_LOCAL_EXTRA' ], 0 ],
  [ PN_LOCAL_248 => 'PN_LOCAL', [ 'INTEGER', 'VARNAME' ], 0 ],
  [ PN_LOCAL_249 => 'PN_LOCAL', [ 'VARNAME' ], 0 ],
  [ PN_LOCAL_EXTRA_250 => 'PN_LOCAL_EXTRA', [ 'INTEGER_NO_WS' ], 0 ],
  [ PN_LOCAL_EXTRA_251 => 'PN_LOCAL_EXTRA', [ '-', 'NAME' ], 0 ],
  [ PN_LOCAL_EXTRA_252 => 'PN_LOCAL_EXTRA', [ '_', 'NAME' ], 0 ],
  [ VAR1_253 => 'VAR1', [ '?', 'VARNAME' ], 0 ],
  [ VAR2_254 => 'VAR2', [ '$', 'VARNAME' ], 0 ],
  [ _PLUS_LIST => 'PLUS-52', [ 'PLUS-52', 'NAME' ], 0 ],
  [ _PLUS_LIST => 'PLUS-52', [ 'NAME' ], 0 ],
  [ _PAREN => 'PAREN-53', [ '-', 'PLUS-52' ], 0 ],
  [ _STAR_LIST_54 => 'STAR-54', [ 'STAR-54', 'PAREN-53' ], 0 ],
  [ _STAR_LIST_54 => 'STAR-54', [  ], 0 ],
  [ LANGTAG_260 => 'LANGTAG', [ '@', 'NAME', 'STAR-54' ], 0 ],
  [ INTEGER_POSITIVE_261 => 'INTEGER_POSITIVE', [ '+', 'INTEGER' ], 0 ],
  [ DOUBLE_POSITIVE_262 => 'DOUBLE_POSITIVE', [ '+', 'DOUBLE' ], 0 ],
  [ DECIMAL_POSITIVE_263 => 'DECIMAL_POSITIVE', [ '+', 'DECIMAL' ], 0 ],
  [ VARNAME_264 => 'VARNAME', [ 'NAME' ], 0 ],
  [ VARNAME_265 => 'VARNAME', [ 'a' ], 0 ],
  [ VARNAME_266 => 'VARNAME', [ 'ASC' ], 0 ],
  [ VARNAME_267 => 'VARNAME', [ 'ASK' ], 0 ],
  [ VARNAME_268 => 'VARNAME', [ 'BASE' ], 0 ],
  [ VARNAME_269 => 'VARNAME', [ 'BOUND' ], 0 ],
  [ VARNAME_270 => 'VARNAME', [ 'CONSTRUCT' ], 0 ],
  [ VARNAME_271 => 'VARNAME', [ 'DATATYPE' ], 0 ],
  [ VARNAME_272 => 'VARNAME', [ 'DESCRIBE' ], 0 ],
  [ VARNAME_273 => 'VARNAME', [ 'DESC' ], 0 ],
  [ VARNAME_274 => 'VARNAME', [ 'DISTINCT' ], 0 ],
  [ VARNAME_275 => 'VARNAME', [ 'FILTER' ], 0 ],
  [ VARNAME_276 => 'VARNAME', [ 'FROM' ], 0 ],
  [ VARNAME_277 => 'VARNAME', [ 'GRAPH' ], 0 ],
  [ VARNAME_278 => 'VARNAME', [ 'LANGMATCHES' ], 0 ],
  [ VARNAME_279 => 'VARNAME', [ 'LANG' ], 0 ],
  [ VARNAME_280 => 'VARNAME', [ 'LIMIT' ], 0 ],
  [ VARNAME_281 => 'VARNAME', [ 'NAMED' ], 0 ],
  [ VARNAME_282 => 'VARNAME', [ 'OFFSET' ], 0 ],
  [ VARNAME_283 => 'VARNAME', [ 'OPTIONAL' ], 0 ],
  [ VARNAME_284 => 'VARNAME', [ 'PREFIX' ], 0 ],
  [ VARNAME_285 => 'VARNAME', [ 'REDUCED' ], 0 ],
  [ VARNAME_286 => 'VARNAME', [ 'REGEX' ], 0 ],
  [ VARNAME_287 => 'VARNAME', [ 'SELECT' ], 0 ],
  [ VARNAME_288 => 'VARNAME', [ 'STR' ], 0 ],
  [ VARNAME_289 => 'VARNAME', [ 'TIME' ], 0 ],
  [ VARNAME_290 => 'VARNAME', [ 'UNION' ], 0 ],
  [ VARNAME_291 => 'VARNAME', [ 'WHERE' ], 0 ],
  [ VARNAME_292 => 'VARNAME', [ 'ISBLANK' ], 0 ],
  [ VARNAME_293 => 'VARNAME', [ 'ISIRI' ], 0 ],
  [ VARNAME_294 => 'VARNAME', [ 'ISLITERAL' ], 0 ],
  [ VARNAME_295 => 'VARNAME', [ 'ISURI' ], 0 ],
  [ VARNAME_296 => 'VARNAME', [ 'SAMETERM' ], 0 ],
  [ VARNAME_297 => 'VARNAME', [ 'TRUE' ], 0 ],
  [ VARNAME_298 => 'VARNAME', [ 'FALSE' ], 0 ],
  [ _STAR_LIST_55 => 'STAR-55', [ 'STAR-55', 'WS' ], 0 ],
  [ _STAR_LIST_55 => 'STAR-55', [  ], 0 ],
  [ NIL_301 => 'NIL', [ '(', 'STAR-55', ')' ], 0 ],
  [ _STAR_LIST_56 => 'STAR-56', [ 'STAR-56', 'WS' ], 0 ],
  [ _STAR_LIST_56 => 'STAR-56', [  ], 0 ],
  [ ANON_304 => 'ANON', [ '[', 'STAR-56', ']' ], 0 ],
  [ INTEGER_305 => 'INTEGER', [ 'INTEGER_WS' ], 0 ],
  [ INTEGER_306 => 'INTEGER', [ 'INTEGER_NO_WS' ], 0 ],
],
                                  yyTERMS  =>
{ '$end' => 0, '!' => 0, '!=' => 0, '$' => 0, '&&' => 0, '(' => 0, ')' => 0, '*' => 0, '+' => 0, ',' => 0, '-' => 0, '.' => 0, '/' => 0, ':' => 0, ';' => 0, '<' => 0, '<=' => 0, '=' => 0, '>' => 0, '>=' => 0, '?' => 0, '@' => 0, 'ASC' => 0, 'ASK' => 0, 'BASE' => 0, 'CONSTRUCT' => 0, 'DESC' => 0, 'DESCRIBE' => 0, 'DISTINCT' => 0, 'FALSE' => 0, 'FILTER' => 0, 'FROM NAMED' => 0, 'FROM' => 0, 'GRAPH' => 0, 'LIMIT' => 0, 'OFFSET' => 0, 'OPTIONAL' => 0, 'ORDER BY' => 0, 'PREFIX' => 0, 'REDUCED' => 0, 'REGEX' => 0, 'SELECT' => 0, 'TIME' => 0, 'TRUE' => 0, 'UNION' => 0, 'WHERE' => 0, '[' => 0, ']' => 0, '^^' => 0, '_' => 0, '_:' => 0, 'a' => 0, '{' => 0, '||' => 0, '}' => 0, ASC => 1, ASK => 1, BASE => 1, BOUND => 1, CONSTRUCT => 1, DATATYPE => 1, DECIMAL => 1, DECIMAL_NEGATIVE => 1, DESC => 1, DESCRIBE => 1, DISTINCT => 1, DOUBLE => 1, DOUBLE_NEGATIVE => 1, FALSE => 1, FILTER => 1, FROM => 1, GRAPH => 1, INTEGER_NEGATIVE => 1, INTEGER_NO_WS => 1, INTEGER_WS => 1, ISBLANK => 1, ISIRI => 1, ISLITERAL => 1, ISURI => 1, LANG => 1, LANGMATCHES => 1, LIMIT => 1, NAME => 1, NAMED => 1, OFFSET => 1, OPTIONAL => 1, PREFIX => 1, REDUCED => 1, REGEX => 1, SAMETERM => 1, SELECT => 1, STR => 1, STRING => 1, TIME => 1, TRUE => 1, UNION => 1, URI => 1, WHERE => 1, WS => 1, a => 1 },
                                  yyFILENAME  => "lib/RDF/Query/Parser/tSPARQL.yp",
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
		DEFAULT => -241
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
		DEFAULT => -243
	},
	{#State 24
		DEFAULT => -27,
		GOTOS => {
			'STAR-7' => 53
		}
	},
	{#State 25
		DEFAULT => -146
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
			'TIME' => 83,
			'REDUCED' => 84,
			'REGEX' => 65,
			'ASK' => 66,
			'PREFIX' => 67,
			'BOUND' => 85,
			'FROM' => 68,
			'WHERE' => 86,
			'GRAPH' => 87,
			'DESCRIBE' => 88,
			'SELECT' => 69,
			'ISURI' => 89,
			'OPTIONAL' => 70
		},
		GOTOS => {
			'VARNAME' => 59
		}
	},
	{#State 28
		DEFAULT => -235
	},
	{#State 29
		DEFAULT => -147
	},
	{#State 30
		DEFAULT => -144
	},
	{#State 31
		ACTIONS => {
			":" => 90
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
			'TIME' => 83,
			'REDUCED' => 84,
			'REGEX' => 65,
			'ASK' => 66,
			'PREFIX' => 67,
			'BOUND' => 85,
			'FROM' => 68,
			'WHERE' => 86,
			'GRAPH' => 87,
			'DESCRIBE' => 88,
			'SELECT' => 69,
			'ISURI' => 89,
			'OPTIONAL' => 70
		},
		GOTOS => {
			'VARNAME' => 91
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
			'VarOrIRIref' => 92,
			'VAR2' => 29,
			'Var' => 30
		}
	},
	{#State 34
		DEFAULT => -236
	},
	{#State 35
		DEFAULT => -237
	},
	{#State 36
		ACTIONS => {
			'NAMED' => 55,
			'DATATYPE' => 57,
			'ISLITERAL' => 58,
			'INTEGER_NO_WS' => 95,
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
			'TIME' => 83,
			'WHERE' => 86,
			'DESCRIBE' => 88,
			'ISURI' => 89,
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
			'INTEGER_WS' => 96,
			'ASC' => 75,
			'DISTINCT' => 79,
			'REDUCED' => 84,
			'BOUND' => 85,
			'GRAPH' => 87
		},
		DEFAULT => -238,
		GOTOS => {
			'INTEGER' => 94,
			'VARNAME' => 93,
			'PN_LOCAL' => 97
		}
	},
	{#State 37
		DEFAULT => -32
	},
	{#State 38
		DEFAULT => -145
	},
	{#State 39
		ACTIONS => {
			":" => 23,
			"+" => 117,
			'STRING' => 119,
			'INTEGER_WS' => 96,
			'INTEGER_NEGATIVE' => 99,
			"\$" => 27,
			'DECIMAL' => 100,
			"[" => 101,
			'DECIMAL_NEGATIVE' => 123,
			'DOUBLE' => 125,
			'INTEGER_NO_WS' => 95,
			"TRUE" => 105,
			'NAME' => 31,
			'URI' => 6,
			"?" => 32,
			"FALSE" => 126,
			'DOUBLE_NEGATIVE' => 109,
			"(" => 110,
			"_:" => 133
		},
		DEFAULT => -107,
		GOTOS => {
			'BooleanLiteral' => 98,
			'NumericLiteralPositive' => 115,
			'DOUBLE_POSITIVE' => 116,
			'NumericLiteralNegative' => 118,
			'NumericLiteralUnsigned' => 120,
			'NIL' => 121,
			'VAR1' => 25,
			'TriplesSameSubject' => 122,
			'IRI_REF' => 28,
			'NumericLiteral' => 102,
			'VAR2' => 29,
			'Var' => 103,
			'VarOrTerm' => 124,
			'INTEGER' => 104,
			'INTEGER_POSITIVE' => 127,
			'ANON' => 106,
			'TriplesNode' => 130,
			'GraphTerm' => 129,
			'BLANK_NODE_LABEL' => 128,
			'PrefixedName' => 34,
			'DECIMAL_POSITIVE' => 107,
			'OPTIONAL-29' => 108,
			'PNAME_LN' => 35,
			'BlankNode' => 131,
			'PNAME_NS' => 36,
			'ConstructTriples' => 111,
			'IRIref' => 112,
			'BlankNodePropertyList' => 113,
			'Collection' => 114,
			'RDFLiteral' => 132
		}
	},
	{#State 40
		DEFAULT => -24,
		GOTOS => {
			'STAR-6' => 134
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
			'PNAME_NS' => 135
		}
	},
	{#State 43
		DEFAULT => -15,
		GOTOS => {
			'STAR-4' => 136
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
			'Var' => 137,
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
			'NamedGraphClause' => 140,
			'PNAME_LN' => 35,
			'PNAME_NS' => 36,
			'IRI_REF' => 28,
			'IRIref' => 139,
			'SourceSelector' => 138,
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
			'DefaultGraphClause' => 142,
			'IRIref' => 139,
			'SourceSelector' => 141,
			'PrefixedName' => 34
		}
	},
	{#State 50
		ACTIONS => {
			"{" => 144
		},
		GOTOS => {
			'GroupGraphPattern' => 143
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
			'OPTIONAL-8' => 147,
			'OPTIONAL-11' => 50,
			'DatasetClause' => 146,
			'WhereClause' => 145
		}
	},
	{#State 54
		DEFAULT => -278
	},
	{#State 55
		DEFAULT => -281
	},
	{#State 56
		DEFAULT => -265
	},
	{#State 57
		DEFAULT => -271
	},
	{#State 58
		DEFAULT => -294
	},
	{#State 59
		DEFAULT => -254
	},
	{#State 60
		DEFAULT => -298
	},
	{#State 61
		DEFAULT => -296
	},
	{#State 62
		DEFAULT => -279
	},
	{#State 63
		DEFAULT => -280
	},
	{#State 64
		DEFAULT => -270
	},
	{#State 65
		DEFAULT => -286
	},
	{#State 66
		DEFAULT => -267
	},
	{#State 67
		DEFAULT => -284
	},
	{#State 68
		DEFAULT => -276
	},
	{#State 69
		DEFAULT => -287
	},
	{#State 70
		DEFAULT => -283
	},
	{#State 71
		DEFAULT => -297
	},
	{#State 72
		DEFAULT => -268
	},
	{#State 73
		DEFAULT => -282
	},
	{#State 74
		DEFAULT => -293
	},
	{#State 75
		DEFAULT => -266
	},
	{#State 76
		DEFAULT => -290
	},
	{#State 77
		DEFAULT => -275
	},
	{#State 78
		DEFAULT => -292
	},
	{#State 79
		DEFAULT => -274
	},
	{#State 80
		DEFAULT => -288
	},
	{#State 81
		DEFAULT => -264
	},
	{#State 82
		DEFAULT => -273
	},
	{#State 83
		DEFAULT => -289
	},
	{#State 84
		DEFAULT => -285
	},
	{#State 85
		DEFAULT => -269
	},
	{#State 86
		DEFAULT => -291
	},
	{#State 87
		DEFAULT => -277
	},
	{#State 88
		DEFAULT => -272
	},
	{#State 89
		DEFAULT => -295
	},
	{#State 90
		DEFAULT => -242
	},
	{#State 91
		DEFAULT => -253
	},
	{#State 92
		DEFAULT => -31
	},
	{#State 93
		ACTIONS => {
			"-" => 148,
			'INTEGER_NO_WS' => 149,
			"_" => 151
		},
		DEFAULT => -249,
		GOTOS => {
			'PN_LOCAL_EXTRA' => 150
		}
	},
	{#State 94
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
			'TIME' => 83,
			'REDUCED' => 84,
			'REGEX' => 65,
			'ASK' => 66,
			'PREFIX' => 67,
			'BOUND' => 85,
			'FROM' => 68,
			'WHERE' => 86,
			'GRAPH' => 87,
			'DESCRIBE' => 88,
			'SELECT' => 69,
			'ISURI' => 89,
			'OPTIONAL' => 70
		},
		GOTOS => {
			'VARNAME' => 152
		}
	},
	{#State 95
		DEFAULT => -306
	},
	{#State 96
		DEFAULT => -305
	},
	{#State 97
		DEFAULT => -244
	},
	{#State 98
		DEFAULT => -151
	},
	{#State 99
		DEFAULT => -230
	},
	{#State 100
		DEFAULT => -225
	},
	{#State 101
		ACTIONS => {
			":" => 23,
			'URI' => 6,
			'NAME' => 31,
			"?" => 32,
			"a" => 154,
			"\$" => 27
		},
		DEFAULT => -303,
		GOTOS => {
			'STAR-56' => 157,
			'Verb' => 155,
			'PrefixedName' => 34,
			'VAR1' => 25,
			'PropertyListNotEmpty' => 153,
			'PNAME_LN' => 35,
			'PNAME_NS' => 36,
			'IRI_REF' => 28,
			'IRIref' => 38,
			'VarOrIRIref' => 156,
			'VAR2' => 29,
			'Var' => 30
		}
	},
	{#State 102
		DEFAULT => -150
	},
	{#State 103
		DEFAULT => -142
	},
	{#State 104
		DEFAULT => -224
	},
	{#State 105
		DEFAULT => -233
	},
	{#State 106
		DEFAULT => -240
	},
	{#State 107
		DEFAULT => -228
	},
	{#State 108
		ACTIONS => {
			"}" => 158
		}
	},
	{#State 109
		DEFAULT => -232
	},
	{#State 110
		ACTIONS => {
			":" => 23,
			"+" => 117,
			'STRING' => 119,
			'INTEGER_WS' => 96,
			'INTEGER_NEGATIVE' => 99,
			"\$" => 27,
			'DECIMAL' => 100,
			"[" => 101,
			'DECIMAL_NEGATIVE' => 123,
			'DOUBLE' => 125,
			'INTEGER_NO_WS' => 95,
			"TRUE" => 105,
			'NAME' => 31,
			'URI' => 6,
			"?" => 32,
			"FALSE" => 126,
			'DOUBLE_NEGATIVE' => 109,
			"(" => 110,
			"_:" => 133
		},
		DEFAULT => -300,
		GOTOS => {
			'GraphNode' => 159,
			'BooleanLiteral' => 98,
			'NumericLiteralPositive' => 115,
			'DOUBLE_POSITIVE' => 116,
			'NumericLiteralNegative' => 118,
			'NumericLiteralUnsigned' => 120,
			'NIL' => 121,
			'VAR1' => 25,
			'IRI_REF' => 28,
			'NumericLiteral' => 102,
			'VAR2' => 29,
			'Var' => 103,
			'STAR-55' => 161,
			'VarOrTerm' => 160,
			'INTEGER' => 104,
			'PLUS-40' => 162,
			'INTEGER_POSITIVE' => 127,
			'ANON' => 106,
			'TriplesNode' => 163,
			'GraphTerm' => 129,
			'BLANK_NODE_LABEL' => 128,
			'PrefixedName' => 34,
			'DECIMAL_POSITIVE' => 107,
			'PNAME_LN' => 35,
			'BlankNode' => 131,
			'PNAME_NS' => 36,
			'IRIref' => 112,
			'BlankNodePropertyList' => 113,
			'Collection' => 114,
			'RDFLiteral' => 132
		}
	},
	{#State 111
		DEFAULT => -106
	},
	{#State 112
		DEFAULT => -148
	},
	{#State 113
		DEFAULT => -135
	},
	{#State 114
		DEFAULT => -134
	},
	{#State 115
		DEFAULT => -222
	},
	{#State 116
		DEFAULT => -229
	},
	{#State 117
		ACTIONS => {
			'DOUBLE' => 166,
			'INTEGER_NO_WS' => 95,
			'DECIMAL' => 164,
			'INTEGER_WS' => 96
		},
		GOTOS => {
			'INTEGER' => 165
		}
	},
	{#State 118
		DEFAULT => -223
	},
	{#State 119
		ACTIONS => {
			"\@" => 168,
			"^^" => 171
		},
		DEFAULT => -217,
		GOTOS => {
			'OPTIONAL-51' => 170,
			'LiteralExtra' => 167,
			'LANGTAG' => 169
		}
	},
	{#State 120
		DEFAULT => -221
	},
	{#State 121
		DEFAULT => -153
	},
	{#State 122
		ACTIONS => {
			"." => 174
		},
		DEFAULT => -113,
		GOTOS => {
			'OPTIONAL-32' => 172,
			'PAREN-31' => 173
		}
	},
	{#State 123
		DEFAULT => -231
	},
	{#State 124
		ACTIONS => {
			":" => 23,
			'URI' => 6,
			'NAME' => 31,
			"?" => 32,
			"a" => 154,
			"\$" => 27
		},
		GOTOS => {
			'Verb' => 155,
			'PrefixedName' => 34,
			'VAR1' => 25,
			'PropertyListNotEmpty' => 175,
			'PNAME_LN' => 35,
			'PNAME_NS' => 36,
			'IRI_REF' => 28,
			'IRIref' => 38,
			'VarOrIRIref' => 156,
			'VAR2' => 29,
			'Var' => 30
		}
	},
	{#State 125
		DEFAULT => -226
	},
	{#State 126
		DEFAULT => -234
	},
	{#State 127
		DEFAULT => -227
	},
	{#State 128
		DEFAULT => -239
	},
	{#State 129
		DEFAULT => -143
	},
	{#State 130
		ACTIONS => {
			":" => 23,
			'URI' => 6,
			'NAME' => 31,
			"?" => 32,
			"a" => 154,
			"\$" => 27
		},
		DEFAULT => -125,
		GOTOS => {
			'Verb' => 155,
			'PrefixedName' => 34,
			'VAR1' => 25,
			'PropertyListNotEmpty' => 176,
			'PNAME_LN' => 35,
			'PNAME_NS' => 36,
			'IRI_REF' => 28,
			'PropertyList' => 177,
			'OPTIONAL-37' => 178,
			'IRIref' => 38,
			'VarOrIRIref' => 156,
			'VAR2' => 29,
			'Var' => 30
		}
	},
	{#State 131
		DEFAULT => -152
	},
	{#State 132
		DEFAULT => -149
	},
	{#State 133
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
			'INTEGER_WS' => 96,
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
			'INTEGER_NO_WS' => 95,
			'TIME' => 83,
			'REDUCED' => 84,
			'REGEX' => 65,
			'ASK' => 66,
			'PREFIX' => 67,
			'BOUND' => 85,
			'FROM' => 68,
			'WHERE' => 86,
			'GRAPH' => 87,
			'DESCRIBE' => 88,
			'SELECT' => 69,
			'ISURI' => 89,
			'OPTIONAL' => 70
		},
		GOTOS => {
			'INTEGER' => 94,
			'VARNAME' => 93,
			'PN_LOCAL' => 179
		}
	},
	{#State 134
		ACTIONS => {
			"FROM" => 49,
			"WHERE" => 47,
			"FROM NAMED" => 48
		},
		DEFAULT => -44,
		GOTOS => {
			'OPTIONAL-11' => 50,
			'WhereClause' => 181,
			'DatasetClause' => 180
		}
	},
	{#State 135
		ACTIONS => {
			'URI' => 6
		},
		GOTOS => {
			'IRI_REF' => 182
		}
	},
	{#State 136
		ACTIONS => {
			"FROM" => 49,
			"WHERE" => 47,
			"FROM NAMED" => 48
		},
		DEFAULT => -44,
		GOTOS => {
			'OPTIONAL-11' => 50,
			'WhereClause' => 184,
			'DatasetClause' => 183
		}
	},
	{#State 137
		DEFAULT => -19
	},
	{#State 138
		DEFAULT => -41
	},
	{#State 139
		DEFAULT => -42
	},
	{#State 140
		DEFAULT => -39
	},
	{#State 141
		DEFAULT => -40
	},
	{#State 142
		DEFAULT => -38
	},
	{#State 143
		DEFAULT => -45
	},
	{#State 144
		ACTIONS => {
			":" => 23,
			"+" => 117,
			'STRING' => 119,
			'INTEGER_WS' => 96,
			'INTEGER_NEGATIVE' => 99,
			"\$" => 27,
			'DECIMAL' => 100,
			"[" => 101,
			'DECIMAL_NEGATIVE' => 123,
			'DOUBLE' => 125,
			'INTEGER_NO_WS' => 95,
			"TRUE" => 105,
			'NAME' => 31,
			'URI' => 6,
			"?" => 32,
			"FALSE" => 126,
			'DOUBLE_NEGATIVE' => 109,
			"(" => 110,
			"_:" => 133
		},
		DEFAULT => -68,
		GOTOS => {
			'BooleanLiteral' => 98,
			'NumericLiteralPositive' => 115,
			'DOUBLE_POSITIVE' => 116,
			'NumericLiteralNegative' => 118,
			'NumericLiteralUnsigned' => 120,
			'NIL' => 121,
			'VAR1' => 25,
			'TriplesSameSubject' => 187,
			'IRI_REF' => 28,
			'TriplesBlock' => 185,
			'NumericLiteral' => 102,
			'VAR2' => 29,
			'Var' => 103,
			'VarOrTerm' => 124,
			'INTEGER' => 104,
			'INTEGER_POSITIVE' => 127,
			'ANON' => 106,
			'TriplesNode' => 130,
			'GraphTerm' => 129,
			'BLANK_NODE_LABEL' => 128,
			'PrefixedName' => 34,
			'DECIMAL_POSITIVE' => 107,
			'PNAME_LN' => 35,
			'BlankNode' => 131,
			'PNAME_NS' => 36,
			'IRIref' => 112,
			'BlankNodePropertyList' => 113,
			'Collection' => 114,
			'OPTIONAL-17' => 186,
			'RDFLiteral' => 132
		}
	},
	{#State 145
		DEFAULT => -28
	},
	{#State 146
		DEFAULT => -26
	},
	{#State 147
		ACTIONS => {
			"ORDER BY" => 188
		},
		DEFAULT => -47,
		GOTOS => {
			'SolutionModifier' => 190,
			'OrderClause' => 191,
			'OPTIONAL-12' => 189
		}
	},
	{#State 148
		ACTIONS => {
			'NAME' => 192
		}
	},
	{#State 149
		DEFAULT => -250
	},
	{#State 150
		DEFAULT => -246
	},
	{#State 151
		ACTIONS => {
			'NAME' => 193
		}
	},
	{#State 152
		ACTIONS => {
			"-" => 148,
			'INTEGER_NO_WS' => 149,
			"_" => 151
		},
		DEFAULT => -248,
		GOTOS => {
			'PN_LOCAL_EXTRA' => 194
		}
	},
	{#State 153
		ACTIONS => {
			"]" => 195
		}
	},
	{#State 154
		DEFAULT => -133
	},
	{#State 155
		ACTIONS => {
			":" => 23,
			"+" => 117,
			'STRING' => 119,
			'INTEGER_WS' => 96,
			'INTEGER_NEGATIVE' => 99,
			"\$" => 27,
			'DECIMAL' => 100,
			"[" => 101,
			'DECIMAL_NEGATIVE' => 123,
			'INTEGER_NO_WS' => 95,
			"TRUE" => 105,
			'NAME' => 31,
			'URI' => 6,
			'DOUBLE' => 125,
			"?" => 32,
			"FALSE" => 126,
			'DOUBLE_NEGATIVE' => 109,
			"(" => 110,
			"_:" => 133
		},
		GOTOS => {
			'GraphNode' => 197,
			'BooleanLiteral' => 98,
			'NumericLiteralPositive' => 115,
			'DOUBLE_POSITIVE' => 116,
			'NumericLiteralNegative' => 118,
			'NumericLiteralUnsigned' => 120,
			'NIL' => 121,
			'VAR1' => 25,
			'IRI_REF' => 28,
			'Object' => 198,
			'NumericLiteral' => 102,
			'VAR2' => 29,
			'Var' => 103,
			'VarOrTerm' => 160,
			'INTEGER' => 104,
			'ObjectList' => 196,
			'INTEGER_POSITIVE' => 127,
			'ANON' => 106,
			'TriplesNode' => 163,
			'GraphTerm' => 129,
			'BLANK_NODE_LABEL' => 128,
			'PrefixedName' => 34,
			'DECIMAL_POSITIVE' => 107,
			'PNAME_LN' => 35,
			'BlankNode' => 131,
			'PNAME_NS' => 36,
			'IRIref' => 112,
			'BlankNodePropertyList' => 113,
			'Collection' => 114,
			'RDFLiteral' => 132
		}
	},
	{#State 156
		DEFAULT => -132
	},
	{#State 157
		ACTIONS => {
			'WS' => 200,
			"]" => 199
		}
	},
	{#State 158
		DEFAULT => -108
	},
	{#State 159
		DEFAULT => -138
	},
	{#State 160
		DEFAULT => -140
	},
	{#State 161
		ACTIONS => {
			'WS' => 201,
			")" => 202
		}
	},
	{#State 162
		ACTIONS => {
			":" => 23,
			"+" => 117,
			'STRING' => 119,
			'INTEGER_WS' => 96,
			'INTEGER_NEGATIVE' => 99,
			"\$" => 27,
			'DECIMAL' => 100,
			"[" => 101,
			")" => 204,
			'DECIMAL_NEGATIVE' => 123,
			'DOUBLE' => 125,
			'INTEGER_NO_WS' => 95,
			"TRUE" => 105,
			'NAME' => 31,
			'URI' => 6,
			"?" => 32,
			"FALSE" => 126,
			'DOUBLE_NEGATIVE' => 109,
			"(" => 110,
			"_:" => 133
		},
		GOTOS => {
			'GraphNode' => 203,
			'BooleanLiteral' => 98,
			'NumericLiteralPositive' => 115,
			'DOUBLE_POSITIVE' => 116,
			'NumericLiteralNegative' => 118,
			'NumericLiteralUnsigned' => 120,
			'NIL' => 121,
			'VAR1' => 25,
			'IRI_REF' => 28,
			'NumericLiteral' => 102,
			'VAR2' => 29,
			'Var' => 103,
			'VarOrTerm' => 160,
			'INTEGER' => 104,
			'INTEGER_POSITIVE' => 127,
			'ANON' => 106,
			'TriplesNode' => 163,
			'GraphTerm' => 129,
			'BLANK_NODE_LABEL' => 128,
			'PrefixedName' => 34,
			'DECIMAL_POSITIVE' => 107,
			'PNAME_LN' => 35,
			'BlankNode' => 131,
			'PNAME_NS' => 36,
			'IRIref' => 112,
			'BlankNodePropertyList' => 113,
			'Collection' => 114,
			'RDFLiteral' => 132
		}
	},
	{#State 163
		DEFAULT => -141
	},
	{#State 164
		DEFAULT => -263
	},
	{#State 165
		DEFAULT => -261
	},
	{#State 166
		DEFAULT => -262
	},
	{#State 167
		DEFAULT => -216
	},
	{#State 168
		ACTIONS => {
			'NAME' => 205
		}
	},
	{#State 169
		DEFAULT => -219
	},
	{#State 170
		DEFAULT => -218
	},
	{#State 171
		ACTIONS => {
			":" => 23,
			'URI' => 6,
			'NAME' => 31
		},
		GOTOS => {
			'PNAME_LN' => 35,
			'PNAME_NS' => 36,
			'IRI_REF' => 28,
			'IRIref' => 206,
			'PrefixedName' => 34
		}
	},
	{#State 172
		DEFAULT => -114
	},
	{#State 173
		DEFAULT => -112
	},
	{#State 174
		ACTIONS => {
			":" => 23,
			"+" => 117,
			'STRING' => 119,
			'INTEGER_WS' => 96,
			'INTEGER_NEGATIVE' => 99,
			"\$" => 27,
			'DECIMAL' => 100,
			"[" => 101,
			'DECIMAL_NEGATIVE' => 123,
			'DOUBLE' => 125,
			'INTEGER_NO_WS' => 95,
			"TRUE" => 105,
			'NAME' => 31,
			'URI' => 6,
			"?" => 32,
			"FALSE" => 126,
			'DOUBLE_NEGATIVE' => 109,
			"(" => 110,
			"_:" => 133
		},
		DEFAULT => -110,
		GOTOS => {
			'BooleanLiteral' => 98,
			'NumericLiteralPositive' => 115,
			'DOUBLE_POSITIVE' => 116,
			'NumericLiteralNegative' => 118,
			'NumericLiteralUnsigned' => 120,
			'NIL' => 121,
			'VAR1' => 25,
			'TriplesSameSubject' => 122,
			'IRI_REF' => 28,
			'NumericLiteral' => 102,
			'VAR2' => 29,
			'Var' => 103,
			'OPTIONAL-30' => 208,
			'VarOrTerm' => 124,
			'INTEGER' => 104,
			'INTEGER_POSITIVE' => 127,
			'ANON' => 106,
			'TriplesNode' => 130,
			'GraphTerm' => 129,
			'BLANK_NODE_LABEL' => 128,
			'PrefixedName' => 34,
			'DECIMAL_POSITIVE' => 107,
			'PNAME_LN' => 35,
			'BlankNode' => 131,
			'PNAME_NS' => 36,
			'ConstructTriples' => 207,
			'IRIref' => 112,
			'BlankNodePropertyList' => 113,
			'Collection' => 114,
			'RDFLiteral' => 132
		}
	},
	{#State 175
		DEFAULT => -115
	},
	{#State 176
		DEFAULT => -124
	},
	{#State 177
		DEFAULT => -116
	},
	{#State 178
		DEFAULT => -126
	},
	{#State 179
		DEFAULT => -245
	},
	{#State 180
		DEFAULT => -23
	},
	{#State 181
		ACTIONS => {
			"ORDER BY" => 188
		},
		DEFAULT => -47,
		GOTOS => {
			'SolutionModifier' => 209,
			'OrderClause' => 191,
			'OPTIONAL-12' => 189
		}
	},
	{#State 182
		DEFAULT => -11
	},
	{#State 183
		DEFAULT => -14
	},
	{#State 184
		ACTIONS => {
			"ORDER BY" => 188
		},
		DEFAULT => -47,
		GOTOS => {
			'SolutionModifier' => 210,
			'OrderClause' => 191,
			'OPTIONAL-12' => 189
		}
	},
	{#State 185
		DEFAULT => -67
	},
	{#State 186
		DEFAULT => -75,
		GOTOS => {
			'STAR-21' => 211
		}
	},
	{#State 187
		ACTIONS => {
			"." => 213
		},
		DEFAULT => -83,
		GOTOS => {
			'OPTIONAL-24' => 212,
			'PAREN-23' => 214
		}
	},
	{#State 188
		ACTIONS => {
			":" => 23,
			'LANGMATCHES' => 215,
			'DATATYPE' => 216,
			'ISIRI' => 228,
			'ISLITERAL' => 218,
			"ASC" => 230,
			'ISBLANK' => 232,
			"\$" => 27,
			'SAMETERM' => 220,
			'LANG' => 221,
			'STR' => 233,
			"DESC" => 234,
			'NAME' => 31,
			'URI' => 6,
			"?" => 32,
			'BOUND' => 235,
			"(" => 224,
			'ISURI' => 237,
			"REGEX" => 238
		},
		GOTOS => {
			'RegexExpression' => 227,
			'OrderDirection' => 217,
			'PLUS-16' => 219,
			'VAR1' => 25,
			'Constraint' => 231,
			'FunctionCall' => 229,
			'IRI_REF' => 28,
			'VAR2' => 29,
			'Var' => 222,
			'BrackettedExpression' => 223,
			'PrefixedName' => 34,
			'BuiltInCall' => 225,
			'PNAME_LN' => 35,
			'PNAME_NS' => 36,
			'OrderCondition' => 236,
			'IRIref' => 226
		}
	},
	{#State 189
		ACTIONS => {
			"LIMIT" => 239,
			"OFFSET" => 240
		},
		DEFAULT => -49,
		GOTOS => {
			'LimitOffsetClauses' => 243,
			'LimitClause' => 244,
			'OPTIONAL-13' => 241,
			'OffsetClause' => 242
		}
	},
	{#State 190
		DEFAULT => -30
	},
	{#State 191
		DEFAULT => -46
	},
	{#State 192
		DEFAULT => -251
	},
	{#State 193
		DEFAULT => -252
	},
	{#State 194
		DEFAULT => -247
	},
	{#State 195
		DEFAULT => -136
	},
	{#State 196
		DEFAULT => -122,
		GOTOS => {
			'STAR-36' => 245
		}
	},
	{#State 197
		DEFAULT => -131
	},
	{#State 198
		DEFAULT => -129,
		GOTOS => {
			'STAR-39' => 246
		}
	},
	{#State 199
		DEFAULT => -304
	},
	{#State 200
		DEFAULT => -302
	},
	{#State 201
		DEFAULT => -299
	},
	{#State 202
		DEFAULT => -301
	},
	{#State 203
		DEFAULT => -137
	},
	{#State 204
		DEFAULT => -139
	},
	{#State 205
		DEFAULT => -259,
		GOTOS => {
			'STAR-54' => 247
		}
	},
	{#State 206
		DEFAULT => -220
	},
	{#State 207
		DEFAULT => -109
	},
	{#State 208
		DEFAULT => -111
	},
	{#State 209
		DEFAULT => -25
	},
	{#State 210
		DEFAULT => -16
	},
	{#State 211
		ACTIONS => {
			"GRAPH" => 252,
			"}" => 248,
			"{" => 144,
			"TIME" => 259,
			"OPTIONAL" => 261,
			"FILTER" => 255
		},
		GOTOS => {
			'PAREN-20' => 254,
			'GroupGraphPattern' => 251,
			'OptionalGraphPattern' => 249,
			'GraphPatternNotTriples' => 250,
			'GraphGraphPattern' => 257,
			'TimeGraphPattern' => 256,
			'Filter' => 258,
			'GGPAtom' => 253,
			'GroupOrUnionGraphPattern' => 260
		}
	},
	{#State 212
		DEFAULT => -84
	},
	{#State 213
		ACTIONS => {
			":" => 23,
			"+" => 117,
			'STRING' => 119,
			'INTEGER_WS' => 96,
			'INTEGER_NEGATIVE' => 99,
			"\$" => 27,
			'DECIMAL' => 100,
			"[" => 101,
			'DECIMAL_NEGATIVE' => 123,
			'DOUBLE' => 125,
			'INTEGER_NO_WS' => 95,
			"TRUE" => 105,
			'NAME' => 31,
			'URI' => 6,
			"?" => 32,
			"FALSE" => 126,
			'DOUBLE_NEGATIVE' => 109,
			"(" => 110,
			"_:" => 133
		},
		DEFAULT => -80,
		GOTOS => {
			'BooleanLiteral' => 98,
			'NumericLiteralPositive' => 115,
			'DOUBLE_POSITIVE' => 116,
			'NumericLiteralNegative' => 118,
			'NumericLiteralUnsigned' => 120,
			'NIL' => 121,
			'VAR1' => 25,
			'OPTIONAL-22' => 262,
			'TriplesSameSubject' => 187,
			'IRI_REF' => 28,
			'TriplesBlock' => 263,
			'NumericLiteral' => 102,
			'VAR2' => 29,
			'Var' => 103,
			'VarOrTerm' => 124,
			'INTEGER' => 104,
			'INTEGER_POSITIVE' => 127,
			'ANON' => 106,
			'TriplesNode' => 130,
			'GraphTerm' => 129,
			'BLANK_NODE_LABEL' => 128,
			'PrefixedName' => 34,
			'DECIMAL_POSITIVE' => 107,
			'PNAME_LN' => 35,
			'BlankNode' => 131,
			'PNAME_NS' => 36,
			'IRIref' => 112,
			'BlankNodePropertyList' => 113,
			'Collection' => 114,
			'RDFLiteral' => 132
		}
	},
	{#State 214
		DEFAULT => -82
	},
	{#State 215
		ACTIONS => {
			"(" => 264
		}
	},
	{#State 216
		ACTIONS => {
			"(" => 265
		}
	},
	{#State 217
		ACTIONS => {
			"(" => 224
		},
		GOTOS => {
			'BrackettedExpression' => 266
		}
	},
	{#State 218
		ACTIONS => {
			"(" => 267
		}
	},
	{#State 219
		ACTIONS => {
			":" => 23,
			'LANGMATCHES' => 215,
			'DATATYPE' => 216,
			'ISIRI' => 228,
			'ISLITERAL' => 218,
			"ASC" => 230,
			'ISBLANK' => 232,
			"\$" => 27,
			'SAMETERM' => 220,
			'LANG' => 221,
			'STR' => 233,
			"DESC" => 234,
			'NAME' => 31,
			'URI' => 6,
			"?" => 32,
			'BOUND' => 235,
			"(" => 224,
			'ISURI' => 237,
			"REGEX" => 238
		},
		DEFAULT => -59,
		GOTOS => {
			'RegexExpression' => 227,
			'OrderDirection' => 217,
			'BrackettedExpression' => 223,
			'PrefixedName' => 34,
			'VAR1' => 25,
			'Constraint' => 231,
			'FunctionCall' => 229,
			'PNAME_LN' => 35,
			'BuiltInCall' => 225,
			'OrderCondition' => 268,
			'PNAME_NS' => 36,
			'IRI_REF' => 28,
			'IRIref' => 226,
			'VAR2' => 29,
			'Var' => 222
		}
	},
	{#State 220
		ACTIONS => {
			"(" => 269
		}
	},
	{#State 221
		ACTIONS => {
			"(" => 270
		}
	},
	{#State 222
		DEFAULT => -62
	},
	{#State 223
		DEFAULT => -97
	},
	{#State 224
		ACTIONS => {
			"-" => 272,
			":" => 23,
			'LANGMATCHES' => 215,
			"+" => 286,
			'DATATYPE' => 216,
			'ISIRI' => 228,
			'ISLITERAL' => 218,
			'STRING' => 119,
			'INTEGER_WS' => 96,
			'INTEGER_NEGATIVE' => 99,
			"!" => 276,
			'ISBLANK' => 232,
			'SAMETERM' => 220,
			"\$" => 27,
			'DECIMAL' => 100,
			'LANG' => 221,
			'DECIMAL_NEGATIVE' => 123,
			'STR' => 233,
			'DOUBLE' => 125,
			'URI' => 6,
			'NAME' => 31,
			'INTEGER_NO_WS' => 95,
			"TRUE" => 105,
			"?" => 32,
			"FALSE" => 126,
			'BOUND' => 235,
			'DOUBLE_NEGATIVE' => 109,
			"(" => 224,
			'ISURI' => 237,
			"REGEX" => 238
		},
		GOTOS => {
			'BooleanLiteral' => 271,
			'RegexExpression' => 227,
			'NumericLiteralPositive' => 115,
			'DOUBLE_POSITIVE' => 116,
			'RelationalExpression' => 273,
			'ValueLogical' => 274,
			'MultiplicativeExpression' => 275,
			'NumericLiteralNegative' => 118,
			'NumericLiteralUnsigned' => 120,
			'VAR1' => 25,
			'IRI_REF' => 28,
			'NumericLiteral' => 277,
			'IRIrefOrFunction' => 278,
			'NumericExpression' => 279,
			'ConditionalOrExpression' => 287,
			'VAR2' => 29,
			'Var' => 280,
			'INTEGER' => 104,
			'Expression' => 288,
			'BrackettedExpression' => 281,
			'INTEGER_POSITIVE' => 127,
			'PrefixedName' => 34,
			'DECIMAL_POSITIVE' => 107,
			'ConditionalAndExpression' => 289,
			'PrimaryExpression' => 282,
			'PNAME_LN' => 35,
			'BuiltInCall' => 283,
			'PNAME_NS' => 36,
			'UnaryExpression' => 284,
			'AdditiveExpression' => 290,
			'IRIref' => 285,
			'RDFLiteral' => 291
		}
	},
	{#State 225
		DEFAULT => -98
	},
	{#State 226
		ACTIONS => {
			"(" => 293
		},
		GOTOS => {
			'NIL' => 294,
			'ArgList' => 292
		}
	},
	{#State 227
		DEFAULT => -208
	},
	{#State 228
		ACTIONS => {
			"(" => 295
		}
	},
	{#State 229
		DEFAULT => -99
	},
	{#State 230
		DEFAULT => -63
	},
	{#State 231
		DEFAULT => -61
	},
	{#State 232
		ACTIONS => {
			"(" => 296
		}
	},
	{#State 233
		ACTIONS => {
			"(" => 297
		}
	},
	{#State 234
		DEFAULT => -64
	},
	{#State 235
		ACTIONS => {
			"(" => 298
		}
	},
	{#State 236
		DEFAULT => -58
	},
	{#State 237
		ACTIONS => {
			"(" => 299
		}
	},
	{#State 238
		ACTIONS => {
			"(" => 300
		}
	},
	{#State 239
		ACTIONS => {
			'INTEGER_NO_WS' => 95,
			'INTEGER_WS' => 96
		},
		GOTOS => {
			'INTEGER' => 301
		}
	},
	{#State 240
		ACTIONS => {
			'INTEGER_NO_WS' => 95,
			'INTEGER_WS' => 96
		},
		GOTOS => {
			'INTEGER' => 302
		}
	},
	{#State 241
		DEFAULT => -50
	},
	{#State 242
		ACTIONS => {
			"LIMIT" => 239
		},
		DEFAULT => -54,
		GOTOS => {
			'LimitClause' => 304,
			'OPTIONAL-15' => 303
		}
	},
	{#State 243
		DEFAULT => -48
	},
	{#State 244
		ACTIONS => {
			"OFFSET" => 240
		},
		DEFAULT => -52,
		GOTOS => {
			'OPTIONAL-14' => 306,
			'OffsetClause' => 305
		}
	},
	{#State 245
		ACTIONS => {
			";" => 308
		},
		DEFAULT => -123,
		GOTOS => {
			'PAREN-35' => 307
		}
	},
	{#State 246
		ACTIONS => {
			"," => 309
		},
		DEFAULT => -130,
		GOTOS => {
			'PAREN-38' => 310
		}
	},
	{#State 247
		ACTIONS => {
			"-" => 311
		},
		DEFAULT => -260,
		GOTOS => {
			'PAREN-53' => 312
		}
	},
	{#State 248
		DEFAULT => -76
	},
	{#State 249
		DEFAULT => -85
	},
	{#State 250
		DEFAULT => -77
	},
	{#State 251
		DEFAULT => -94,
		GOTOS => {
			'STAR-26' => 313
		}
	},
	{#State 252
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
			'VarOrIRIref' => 314,
			'VAR2' => 29,
			'Var' => 30
		}
	},
	{#State 253
		ACTIONS => {
			"." => 315
		},
		DEFAULT => -70,
		GOTOS => {
			'OPTIONAL-18' => 316
		}
	},
	{#State 254
		DEFAULT => -74
	},
	{#State 255
		ACTIONS => {
			'STR' => 233,
			":" => 23,
			'URI' => 6,
			'NAME' => 31,
			'LANGMATCHES' => 215,
			'DATATYPE' => 216,
			'ISIRI' => 228,
			'ISLITERAL' => 218,
			'BOUND' => 235,
			"(" => 224,
			'SAMETERM' => 220,
			'ISBLANK' => 232,
			'ISURI' => 237,
			'LANG' => 221,
			"REGEX" => 238
		},
		GOTOS => {
			'RegexExpression' => 227,
			'BrackettedExpression' => 223,
			'PrefixedName' => 34,
			'PNAME_LN' => 35,
			'BuiltInCall' => 225,
			'FunctionCall' => 229,
			'Constraint' => 317,
			'PNAME_NS' => 36,
			'IRI_REF' => 28,
			'IRIref' => 226
		}
	},
	{#State 256
		DEFAULT => -88
	},
	{#State 257
		DEFAULT => -87
	},
	{#State 258
		DEFAULT => -78
	},
	{#State 259
		ACTIONS => {
			":" => 23,
			"+" => 117,
			'STRING' => 119,
			'INTEGER_WS' => 96,
			'INTEGER_NEGATIVE' => 99,
			"\$" => 27,
			'DECIMAL' => 100,
			"[" => 101,
			'DECIMAL_NEGATIVE' => 123,
			'INTEGER_NO_WS' => 95,
			"TRUE" => 105,
			'NAME' => 31,
			'URI' => 6,
			'DOUBLE' => 125,
			"?" => 32,
			"FALSE" => 126,
			'DOUBLE_NEGATIVE' => 109,
			"(" => 110,
			"_:" => 133
		},
		GOTOS => {
			'GraphNode' => 318,
			'BooleanLiteral' => 98,
			'NumericLiteralPositive' => 115,
			'DOUBLE_POSITIVE' => 116,
			'NumericLiteralNegative' => 118,
			'NumericLiteralUnsigned' => 120,
			'NIL' => 121,
			'VAR1' => 25,
			'IRI_REF' => 28,
			'NumericLiteral' => 102,
			'VAR2' => 29,
			'Var' => 103,
			'VarOrTerm' => 160,
			'INTEGER' => 104,
			'INTEGER_POSITIVE' => 127,
			'ANON' => 106,
			'TriplesNode' => 163,
			'GraphTerm' => 129,
			'BLANK_NODE_LABEL' => 128,
			'PrefixedName' => 34,
			'DECIMAL_POSITIVE' => 107,
			'PNAME_LN' => 35,
			'BlankNode' => 131,
			'PNAME_NS' => 36,
			'IRIref' => 112,
			'BlankNodePropertyList' => 113,
			'Collection' => 114,
			'RDFLiteral' => 132
		}
	},
	{#State 260
		DEFAULT => -86
	},
	{#State 261
		ACTIONS => {
			"{" => 144
		},
		GOTOS => {
			'GroupGraphPattern' => 319
		}
	},
	{#State 262
		DEFAULT => -81
	},
	{#State 263
		DEFAULT => -79
	},
	{#State 264
		ACTIONS => {
			"-" => 272,
			":" => 23,
			'LANGMATCHES' => 215,
			"+" => 286,
			'DATATYPE' => 216,
			'ISIRI' => 228,
			'ISLITERAL' => 218,
			'STRING' => 119,
			'INTEGER_WS' => 96,
			'INTEGER_NEGATIVE' => 99,
			"!" => 276,
			'ISBLANK' => 232,
			'SAMETERM' => 220,
			"\$" => 27,
			'DECIMAL' => 100,
			'LANG' => 221,
			'DECIMAL_NEGATIVE' => 123,
			'STR' => 233,
			'DOUBLE' => 125,
			'URI' => 6,
			'NAME' => 31,
			'INTEGER_NO_WS' => 95,
			"TRUE" => 105,
			"?" => 32,
			"FALSE" => 126,
			'BOUND' => 235,
			'DOUBLE_NEGATIVE' => 109,
			"(" => 224,
			'ISURI' => 237,
			"REGEX" => 238
		},
		GOTOS => {
			'BooleanLiteral' => 271,
			'RegexExpression' => 227,
			'NumericLiteralPositive' => 115,
			'DOUBLE_POSITIVE' => 116,
			'RelationalExpression' => 273,
			'ValueLogical' => 274,
			'MultiplicativeExpression' => 275,
			'NumericLiteralNegative' => 118,
			'NumericLiteralUnsigned' => 120,
			'VAR1' => 25,
			'IRI_REF' => 28,
			'NumericLiteral' => 277,
			'IRIrefOrFunction' => 278,
			'NumericExpression' => 279,
			'ConditionalOrExpression' => 287,
			'VAR2' => 29,
			'Var' => 280,
			'INTEGER' => 104,
			'Expression' => 320,
			'BrackettedExpression' => 281,
			'INTEGER_POSITIVE' => 127,
			'PrefixedName' => 34,
			'DECIMAL_POSITIVE' => 107,
			'ConditionalAndExpression' => 289,
			'PrimaryExpression' => 282,
			'PNAME_LN' => 35,
			'BuiltInCall' => 283,
			'PNAME_NS' => 36,
			'UnaryExpression' => 284,
			'AdditiveExpression' => 290,
			'IRIref' => 285,
			'RDFLiteral' => 291
		}
	},
	{#State 265
		ACTIONS => {
			"-" => 272,
			":" => 23,
			'LANGMATCHES' => 215,
			"+" => 286,
			'DATATYPE' => 216,
			'ISIRI' => 228,
			'ISLITERAL' => 218,
			'STRING' => 119,
			'INTEGER_WS' => 96,
			'INTEGER_NEGATIVE' => 99,
			"!" => 276,
			'ISBLANK' => 232,
			'SAMETERM' => 220,
			"\$" => 27,
			'DECIMAL' => 100,
			'LANG' => 221,
			'DECIMAL_NEGATIVE' => 123,
			'STR' => 233,
			'DOUBLE' => 125,
			'URI' => 6,
			'NAME' => 31,
			'INTEGER_NO_WS' => 95,
			"TRUE" => 105,
			"?" => 32,
			"FALSE" => 126,
			'BOUND' => 235,
			'DOUBLE_NEGATIVE' => 109,
			"(" => 224,
			'ISURI' => 237,
			"REGEX" => 238
		},
		GOTOS => {
			'BooleanLiteral' => 271,
			'RegexExpression' => 227,
			'NumericLiteralPositive' => 115,
			'DOUBLE_POSITIVE' => 116,
			'RelationalExpression' => 273,
			'ValueLogical' => 274,
			'MultiplicativeExpression' => 275,
			'NumericLiteralNegative' => 118,
			'NumericLiteralUnsigned' => 120,
			'VAR1' => 25,
			'IRI_REF' => 28,
			'NumericLiteral' => 277,
			'IRIrefOrFunction' => 278,
			'NumericExpression' => 279,
			'ConditionalOrExpression' => 287,
			'VAR2' => 29,
			'Var' => 280,
			'INTEGER' => 104,
			'Expression' => 321,
			'BrackettedExpression' => 281,
			'INTEGER_POSITIVE' => 127,
			'PrefixedName' => 34,
			'DECIMAL_POSITIVE' => 107,
			'ConditionalAndExpression' => 289,
			'PrimaryExpression' => 282,
			'PNAME_LN' => 35,
			'BuiltInCall' => 283,
			'PNAME_NS' => 36,
			'UnaryExpression' => 284,
			'AdditiveExpression' => 290,
			'IRIref' => 285,
			'RDFLiteral' => 291
		}
	},
	{#State 266
		DEFAULT => -60
	},
	{#State 267
		ACTIONS => {
			"-" => 272,
			":" => 23,
			'LANGMATCHES' => 215,
			"+" => 286,
			'DATATYPE' => 216,
			'ISIRI' => 228,
			'ISLITERAL' => 218,
			'STRING' => 119,
			'INTEGER_WS' => 96,
			'INTEGER_NEGATIVE' => 99,
			"!" => 276,
			'ISBLANK' => 232,
			'SAMETERM' => 220,
			"\$" => 27,
			'DECIMAL' => 100,
			'LANG' => 221,
			'DECIMAL_NEGATIVE' => 123,
			'STR' => 233,
			'DOUBLE' => 125,
			'URI' => 6,
			'NAME' => 31,
			'INTEGER_NO_WS' => 95,
			"TRUE" => 105,
			"?" => 32,
			"FALSE" => 126,
			'BOUND' => 235,
			'DOUBLE_NEGATIVE' => 109,
			"(" => 224,
			'ISURI' => 237,
			"REGEX" => 238
		},
		GOTOS => {
			'BooleanLiteral' => 271,
			'RegexExpression' => 227,
			'NumericLiteralPositive' => 115,
			'DOUBLE_POSITIVE' => 116,
			'RelationalExpression' => 273,
			'ValueLogical' => 274,
			'MultiplicativeExpression' => 275,
			'NumericLiteralNegative' => 118,
			'NumericLiteralUnsigned' => 120,
			'VAR1' => 25,
			'IRI_REF' => 28,
			'NumericLiteral' => 277,
			'IRIrefOrFunction' => 278,
			'NumericExpression' => 279,
			'ConditionalOrExpression' => 287,
			'VAR2' => 29,
			'Var' => 280,
			'INTEGER' => 104,
			'Expression' => 322,
			'BrackettedExpression' => 281,
			'INTEGER_POSITIVE' => 127,
			'PrefixedName' => 34,
			'DECIMAL_POSITIVE' => 107,
			'ConditionalAndExpression' => 289,
			'PrimaryExpression' => 282,
			'PNAME_LN' => 35,
			'BuiltInCall' => 283,
			'PNAME_NS' => 36,
			'UnaryExpression' => 284,
			'AdditiveExpression' => 290,
			'IRIref' => 285,
			'RDFLiteral' => 291
		}
	},
	{#State 268
		DEFAULT => -57
	},
	{#State 269
		ACTIONS => {
			"-" => 272,
			":" => 23,
			'LANGMATCHES' => 215,
			"+" => 286,
			'DATATYPE' => 216,
			'ISIRI' => 228,
			'ISLITERAL' => 218,
			'STRING' => 119,
			'INTEGER_WS' => 96,
			'INTEGER_NEGATIVE' => 99,
			"!" => 276,
			'ISBLANK' => 232,
			'SAMETERM' => 220,
			"\$" => 27,
			'DECIMAL' => 100,
			'LANG' => 221,
			'DECIMAL_NEGATIVE' => 123,
			'STR' => 233,
			'DOUBLE' => 125,
			'URI' => 6,
			'NAME' => 31,
			'INTEGER_NO_WS' => 95,
			"TRUE" => 105,
			"?" => 32,
			"FALSE" => 126,
			'BOUND' => 235,
			'DOUBLE_NEGATIVE' => 109,
			"(" => 224,
			'ISURI' => 237,
			"REGEX" => 238
		},
		GOTOS => {
			'BooleanLiteral' => 271,
			'RegexExpression' => 227,
			'NumericLiteralPositive' => 115,
			'DOUBLE_POSITIVE' => 116,
			'RelationalExpression' => 273,
			'ValueLogical' => 274,
			'MultiplicativeExpression' => 275,
			'NumericLiteralNegative' => 118,
			'NumericLiteralUnsigned' => 120,
			'VAR1' => 25,
			'IRI_REF' => 28,
			'NumericLiteral' => 277,
			'IRIrefOrFunction' => 278,
			'NumericExpression' => 279,
			'ConditionalOrExpression' => 287,
			'VAR2' => 29,
			'Var' => 280,
			'INTEGER' => 104,
			'Expression' => 323,
			'BrackettedExpression' => 281,
			'INTEGER_POSITIVE' => 127,
			'PrefixedName' => 34,
			'DECIMAL_POSITIVE' => 107,
			'ConditionalAndExpression' => 289,
			'PrimaryExpression' => 282,
			'PNAME_LN' => 35,
			'BuiltInCall' => 283,
			'PNAME_NS' => 36,
			'UnaryExpression' => 284,
			'AdditiveExpression' => 290,
			'IRIref' => 285,
			'RDFLiteral' => 291
		}
	},
	{#State 270
		ACTIONS => {
			"-" => 272,
			":" => 23,
			'LANGMATCHES' => 215,
			"+" => 286,
			'DATATYPE' => 216,
			'ISIRI' => 228,
			'ISLITERAL' => 218,
			'STRING' => 119,
			'INTEGER_WS' => 96,
			'INTEGER_NEGATIVE' => 99,
			"!" => 276,
			'ISBLANK' => 232,
			'SAMETERM' => 220,
			"\$" => 27,
			'DECIMAL' => 100,
			'LANG' => 221,
			'DECIMAL_NEGATIVE' => 123,
			'STR' => 233,
			'DOUBLE' => 125,
			'URI' => 6,
			'NAME' => 31,
			'INTEGER_NO_WS' => 95,
			"TRUE" => 105,
			"?" => 32,
			"FALSE" => 126,
			'BOUND' => 235,
			'DOUBLE_NEGATIVE' => 109,
			"(" => 224,
			'ISURI' => 237,
			"REGEX" => 238
		},
		GOTOS => {
			'BooleanLiteral' => 271,
			'RegexExpression' => 227,
			'NumericLiteralPositive' => 115,
			'DOUBLE_POSITIVE' => 116,
			'RelationalExpression' => 273,
			'ValueLogical' => 274,
			'MultiplicativeExpression' => 275,
			'NumericLiteralNegative' => 118,
			'NumericLiteralUnsigned' => 120,
			'VAR1' => 25,
			'IRI_REF' => 28,
			'NumericLiteral' => 277,
			'IRIrefOrFunction' => 278,
			'NumericExpression' => 279,
			'ConditionalOrExpression' => 287,
			'VAR2' => 29,
			'Var' => 280,
			'INTEGER' => 104,
			'Expression' => 324,
			'BrackettedExpression' => 281,
			'INTEGER_POSITIVE' => 127,
			'PrefixedName' => 34,
			'DECIMAL_POSITIVE' => 107,
			'ConditionalAndExpression' => 289,
			'PrimaryExpression' => 282,
			'PNAME_LN' => 35,
			'BuiltInCall' => 283,
			'PNAME_NS' => 36,
			'UnaryExpression' => 284,
			'AdditiveExpression' => 290,
			'IRIref' => 285,
			'RDFLiteral' => 291
		}
	},
	{#State 271
		DEFAULT => -195
	},
	{#State 272
		ACTIONS => {
			":" => 23,
			'LANGMATCHES' => 215,
			"+" => 117,
			'DATATYPE' => 216,
			'ISIRI' => 228,
			'ISLITERAL' => 218,
			'STRING' => 119,
			'INTEGER_WS' => 96,
			'INTEGER_NEGATIVE' => 99,
			'ISBLANK' => 232,
			"\$" => 27,
			'SAMETERM' => 220,
			'DECIMAL' => 100,
			'LANG' => 221,
			'DECIMAL_NEGATIVE' => 123,
			'STR' => 233,
			'DOUBLE' => 125,
			'URI' => 6,
			'NAME' => 31,
			'INTEGER_NO_WS' => 95,
			"TRUE" => 105,
			"?" => 32,
			"FALSE" => 126,
			'BOUND' => 235,
			'DOUBLE_NEGATIVE' => 109,
			"(" => 224,
			'ISURI' => 237,
			"REGEX" => 238
		},
		GOTOS => {
			'BooleanLiteral' => 271,
			'RegexExpression' => 227,
			'NumericLiteralPositive' => 115,
			'DOUBLE_POSITIVE' => 116,
			'NumericLiteralNegative' => 118,
			'NumericLiteralUnsigned' => 120,
			'VAR1' => 25,
			'IRI_REF' => 28,
			'NumericLiteral' => 277,
			'IRIrefOrFunction' => 278,
			'Var' => 280,
			'VAR2' => 29,
			'INTEGER' => 104,
			'BrackettedExpression' => 281,
			'INTEGER_POSITIVE' => 127,
			'PrefixedName' => 34,
			'DECIMAL_POSITIVE' => 107,
			'PrimaryExpression' => 325,
			'PNAME_LN' => 35,
			'BuiltInCall' => 283,
			'PNAME_NS' => 36,
			'IRIref' => 285,
			'RDFLiteral' => 291
		}
	},
	{#State 273
		DEFAULT => -163
	},
	{#State 274
		DEFAULT => -161,
		GOTOS => {
			'STAR-44' => 326
		}
	},
	{#State 275
		DEFAULT => -175,
		GOTOS => {
			'STAR-46' => 327
		}
	},
	{#State 276
		ACTIONS => {
			":" => 23,
			'LANGMATCHES' => 215,
			"+" => 117,
			'DATATYPE' => 216,
			'ISIRI' => 228,
			'ISLITERAL' => 218,
			'STRING' => 119,
			'INTEGER_WS' => 96,
			'INTEGER_NEGATIVE' => 99,
			'ISBLANK' => 232,
			"\$" => 27,
			'SAMETERM' => 220,
			'DECIMAL' => 100,
			'LANG' => 221,
			'DECIMAL_NEGATIVE' => 123,
			'STR' => 233,
			'DOUBLE' => 125,
			'URI' => 6,
			'NAME' => 31,
			'INTEGER_NO_WS' => 95,
			"TRUE" => 105,
			"?" => 32,
			"FALSE" => 126,
			'BOUND' => 235,
			'DOUBLE_NEGATIVE' => 109,
			"(" => 224,
			'ISURI' => 237,
			"REGEX" => 238
		},
		GOTOS => {
			'BooleanLiteral' => 271,
			'RegexExpression' => 227,
			'NumericLiteralPositive' => 115,
			'DOUBLE_POSITIVE' => 116,
			'NumericLiteralNegative' => 118,
			'NumericLiteralUnsigned' => 120,
			'VAR1' => 25,
			'IRI_REF' => 28,
			'NumericLiteral' => 277,
			'IRIrefOrFunction' => 278,
			'Var' => 280,
			'VAR2' => 29,
			'INTEGER' => 104,
			'BrackettedExpression' => 281,
			'INTEGER_POSITIVE' => 127,
			'PrefixedName' => 34,
			'DECIMAL_POSITIVE' => 107,
			'PrimaryExpression' => 328,
			'PNAME_LN' => 35,
			'BuiltInCall' => 283,
			'PNAME_NS' => 36,
			'IRIref' => 285,
			'RDFLiteral' => 291
		}
	},
	{#State 277
		DEFAULT => -194
	},
	{#State 278
		DEFAULT => -192
	},
	{#State 279
		ACTIONS => {
			"!=" => 335,
			"<" => 329,
			"=" => 336,
			">=" => 331,
			"<=" => 332,
			">" => 333
		},
		DEFAULT => -165,
		GOTOS => {
			'OPTIONAL-45' => 334,
			'RelationalExpressionExtra' => 330
		}
	},
	{#State 280
		DEFAULT => -196
	},
	{#State 281
		DEFAULT => -190
	},
	{#State 282
		DEFAULT => -189
	},
	{#State 283
		DEFAULT => -191
	},
	{#State 284
		DEFAULT => -182,
		GOTOS => {
			'STAR-47' => 337
		}
	},
	{#State 285
		ACTIONS => {
			"(" => 293
		},
		DEFAULT => -214,
		GOTOS => {
			'NIL' => 294,
			'ArgList' => 338,
			'OPTIONAL-50' => 339
		}
	},
	{#State 286
		ACTIONS => {
			":" => 23,
			'LANGMATCHES' => 215,
			"+" => 117,
			'DATATYPE' => 216,
			'ISIRI' => 228,
			'ISLITERAL' => 218,
			'STRING' => 119,
			'INTEGER_WS' => 96,
			'INTEGER_NEGATIVE' => 99,
			'ISBLANK' => 232,
			"\$" => 27,
			'SAMETERM' => 220,
			'DECIMAL' => 340,
			'LANG' => 221,
			'DECIMAL_NEGATIVE' => 123,
			'STR' => 233,
			'DOUBLE' => 343,
			'URI' => 6,
			'NAME' => 31,
			'INTEGER_NO_WS' => 95,
			"TRUE" => 105,
			"?" => 32,
			"FALSE" => 126,
			'BOUND' => 235,
			'DOUBLE_NEGATIVE' => 109,
			"(" => 224,
			'ISURI' => 237,
			"REGEX" => 238
		},
		GOTOS => {
			'BooleanLiteral' => 271,
			'RegexExpression' => 227,
			'NumericLiteralPositive' => 115,
			'DOUBLE_POSITIVE' => 116,
			'NumericLiteralNegative' => 118,
			'NumericLiteralUnsigned' => 120,
			'VAR1' => 25,
			'IRI_REF' => 28,
			'NumericLiteral' => 277,
			'IRIrefOrFunction' => 278,
			'Var' => 280,
			'VAR2' => 29,
			'INTEGER' => 341,
			'BrackettedExpression' => 281,
			'INTEGER_POSITIVE' => 127,
			'PrefixedName' => 34,
			'DECIMAL_POSITIVE' => 107,
			'PrimaryExpression' => 342,
			'PNAME_LN' => 35,
			'BuiltInCall' => 283,
			'PNAME_NS' => 36,
			'IRIref' => 285,
			'RDFLiteral' => 291
		}
	},
	{#State 287
		DEFAULT => -154
	},
	{#State 288
		ACTIONS => {
			")" => 344
		}
	},
	{#State 289
		DEFAULT => -157,
		GOTOS => {
			'STAR-42' => 345
		}
	},
	{#State 290
		DEFAULT => -173
	},
	{#State 291
		DEFAULT => -193
	},
	{#State 292
		DEFAULT => -100
	},
	{#State 293
		ACTIONS => {
			"-" => 272,
			":" => 23,
			'LANGMATCHES' => 215,
			'DATATYPE' => 216,
			'ISLITERAL' => 218,
			'INTEGER_NEGATIVE' => 99,
			"!" => 276,
			'SAMETERM' => 220,
			"\$" => 27,
			'DECIMAL' => 100,
			'LANG' => 221,
			'INTEGER_NO_WS' => 95,
			"TRUE" => 105,
			'DOUBLE_NEGATIVE' => 109,
			"(" => 224,
			"+" => 286,
			'ISIRI' => 228,
			'INTEGER_WS' => 96,
			'STRING' => 119,
			'ISBLANK' => 232,
			'DECIMAL_NEGATIVE' => 123,
			'STR' => 233,
			'NAME' => 31,
			'URI' => 6,
			'DOUBLE' => 125,
			"?" => 32,
			"FALSE" => 126,
			'BOUND' => 235,
			'ISURI' => 237,
			"REGEX" => 238
		},
		DEFAULT => -300,
		GOTOS => {
			'BooleanLiteral' => 271,
			'RelationalExpression' => 273,
			'ValueLogical' => 274,
			'MultiplicativeExpression' => 275,
			'VAR1' => 25,
			'NumericLiteral' => 277,
			'IRIrefOrFunction' => 278,
			'NumericExpression' => 279,
			'VAR2' => 29,
			'Var' => 280,
			'INTEGER' => 104,
			'BrackettedExpression' => 281,
			'PrefixedName' => 34,
			'DECIMAL_POSITIVE' => 107,
			'PrimaryExpression' => 282,
			'PNAME_LN' => 35,
			'BuiltInCall' => 283,
			'UnaryExpression' => 284,
			'IRIref' => 285,
			'NumericLiteralPositive' => 115,
			'RegexExpression' => 227,
			'DOUBLE_POSITIVE' => 116,
			'NumericLiteralNegative' => 118,
			'NumericLiteralUnsigned' => 120,
			'IRI_REF' => 28,
			'ConditionalOrExpression' => 287,
			'STAR-55' => 161,
			'Expression' => 346,
			'INTEGER_POSITIVE' => 127,
			'ConditionalAndExpression' => 289,
			'PNAME_NS' => 36,
			'AdditiveExpression' => 290,
			'RDFLiteral' => 291
		}
	},
	{#State 294
		DEFAULT => -105
	},
	{#State 295
		ACTIONS => {
			"-" => 272,
			":" => 23,
			'LANGMATCHES' => 215,
			"+" => 286,
			'DATATYPE' => 216,
			'ISIRI' => 228,
			'ISLITERAL' => 218,
			'STRING' => 119,
			'INTEGER_WS' => 96,
			'INTEGER_NEGATIVE' => 99,
			"!" => 276,
			'ISBLANK' => 232,
			'SAMETERM' => 220,
			"\$" => 27,
			'DECIMAL' => 100,
			'LANG' => 221,
			'DECIMAL_NEGATIVE' => 123,
			'STR' => 233,
			'DOUBLE' => 125,
			'URI' => 6,
			'NAME' => 31,
			'INTEGER_NO_WS' => 95,
			"TRUE" => 105,
			"?" => 32,
			"FALSE" => 126,
			'BOUND' => 235,
			'DOUBLE_NEGATIVE' => 109,
			"(" => 224,
			'ISURI' => 237,
			"REGEX" => 238
		},
		GOTOS => {
			'BooleanLiteral' => 271,
			'RegexExpression' => 227,
			'NumericLiteralPositive' => 115,
			'DOUBLE_POSITIVE' => 116,
			'RelationalExpression' => 273,
			'ValueLogical' => 274,
			'MultiplicativeExpression' => 275,
			'NumericLiteralNegative' => 118,
			'NumericLiteralUnsigned' => 120,
			'VAR1' => 25,
			'IRI_REF' => 28,
			'NumericLiteral' => 277,
			'IRIrefOrFunction' => 278,
			'NumericExpression' => 279,
			'ConditionalOrExpression' => 287,
			'VAR2' => 29,
			'Var' => 280,
			'INTEGER' => 104,
			'Expression' => 347,
			'BrackettedExpression' => 281,
			'INTEGER_POSITIVE' => 127,
			'PrefixedName' => 34,
			'DECIMAL_POSITIVE' => 107,
			'ConditionalAndExpression' => 289,
			'PrimaryExpression' => 282,
			'PNAME_LN' => 35,
			'BuiltInCall' => 283,
			'PNAME_NS' => 36,
			'UnaryExpression' => 284,
			'AdditiveExpression' => 290,
			'IRIref' => 285,
			'RDFLiteral' => 291
		}
	},
	{#State 296
		ACTIONS => {
			"-" => 272,
			":" => 23,
			'LANGMATCHES' => 215,
			"+" => 286,
			'DATATYPE' => 216,
			'ISIRI' => 228,
			'ISLITERAL' => 218,
			'STRING' => 119,
			'INTEGER_WS' => 96,
			'INTEGER_NEGATIVE' => 99,
			"!" => 276,
			'ISBLANK' => 232,
			'SAMETERM' => 220,
			"\$" => 27,
			'DECIMAL' => 100,
			'LANG' => 221,
			'DECIMAL_NEGATIVE' => 123,
			'STR' => 233,
			'DOUBLE' => 125,
			'URI' => 6,
			'NAME' => 31,
			'INTEGER_NO_WS' => 95,
			"TRUE" => 105,
			"?" => 32,
			"FALSE" => 126,
			'BOUND' => 235,
			'DOUBLE_NEGATIVE' => 109,
			"(" => 224,
			'ISURI' => 237,
			"REGEX" => 238
		},
		GOTOS => {
			'BooleanLiteral' => 271,
			'RegexExpression' => 227,
			'NumericLiteralPositive' => 115,
			'DOUBLE_POSITIVE' => 116,
			'RelationalExpression' => 273,
			'ValueLogical' => 274,
			'MultiplicativeExpression' => 275,
			'NumericLiteralNegative' => 118,
			'NumericLiteralUnsigned' => 120,
			'VAR1' => 25,
			'IRI_REF' => 28,
			'NumericLiteral' => 277,
			'IRIrefOrFunction' => 278,
			'NumericExpression' => 279,
			'ConditionalOrExpression' => 287,
			'VAR2' => 29,
			'Var' => 280,
			'INTEGER' => 104,
			'Expression' => 348,
			'BrackettedExpression' => 281,
			'INTEGER_POSITIVE' => 127,
			'PrefixedName' => 34,
			'DECIMAL_POSITIVE' => 107,
			'ConditionalAndExpression' => 289,
			'PrimaryExpression' => 282,
			'PNAME_LN' => 35,
			'BuiltInCall' => 283,
			'PNAME_NS' => 36,
			'UnaryExpression' => 284,
			'AdditiveExpression' => 290,
			'IRIref' => 285,
			'RDFLiteral' => 291
		}
	},
	{#State 297
		ACTIONS => {
			"-" => 272,
			":" => 23,
			'LANGMATCHES' => 215,
			"+" => 286,
			'DATATYPE' => 216,
			'ISIRI' => 228,
			'ISLITERAL' => 218,
			'STRING' => 119,
			'INTEGER_WS' => 96,
			'INTEGER_NEGATIVE' => 99,
			"!" => 276,
			'ISBLANK' => 232,
			'SAMETERM' => 220,
			"\$" => 27,
			'DECIMAL' => 100,
			'LANG' => 221,
			'DECIMAL_NEGATIVE' => 123,
			'STR' => 233,
			'DOUBLE' => 125,
			'URI' => 6,
			'NAME' => 31,
			'INTEGER_NO_WS' => 95,
			"TRUE" => 105,
			"?" => 32,
			"FALSE" => 126,
			'BOUND' => 235,
			'DOUBLE_NEGATIVE' => 109,
			"(" => 224,
			'ISURI' => 237,
			"REGEX" => 238
		},
		GOTOS => {
			'BooleanLiteral' => 271,
			'RegexExpression' => 227,
			'NumericLiteralPositive' => 115,
			'DOUBLE_POSITIVE' => 116,
			'RelationalExpression' => 273,
			'ValueLogical' => 274,
			'MultiplicativeExpression' => 275,
			'NumericLiteralNegative' => 118,
			'NumericLiteralUnsigned' => 120,
			'VAR1' => 25,
			'IRI_REF' => 28,
			'NumericLiteral' => 277,
			'IRIrefOrFunction' => 278,
			'NumericExpression' => 279,
			'ConditionalOrExpression' => 287,
			'VAR2' => 29,
			'Var' => 280,
			'INTEGER' => 104,
			'Expression' => 349,
			'BrackettedExpression' => 281,
			'INTEGER_POSITIVE' => 127,
			'PrefixedName' => 34,
			'DECIMAL_POSITIVE' => 107,
			'ConditionalAndExpression' => 289,
			'PrimaryExpression' => 282,
			'PNAME_LN' => 35,
			'BuiltInCall' => 283,
			'PNAME_NS' => 36,
			'UnaryExpression' => 284,
			'AdditiveExpression' => 290,
			'IRIref' => 285,
			'RDFLiteral' => 291
		}
	},
	{#State 298
		ACTIONS => {
			"?" => 32,
			"\$" => 27
		},
		GOTOS => {
			'VAR1' => 25,
			'Var' => 350,
			'VAR2' => 29
		}
	},
	{#State 299
		ACTIONS => {
			"-" => 272,
			":" => 23,
			'LANGMATCHES' => 215,
			"+" => 286,
			'DATATYPE' => 216,
			'ISIRI' => 228,
			'ISLITERAL' => 218,
			'STRING' => 119,
			'INTEGER_WS' => 96,
			'INTEGER_NEGATIVE' => 99,
			"!" => 276,
			'ISBLANK' => 232,
			'SAMETERM' => 220,
			"\$" => 27,
			'DECIMAL' => 100,
			'LANG' => 221,
			'DECIMAL_NEGATIVE' => 123,
			'STR' => 233,
			'DOUBLE' => 125,
			'URI' => 6,
			'NAME' => 31,
			'INTEGER_NO_WS' => 95,
			"TRUE" => 105,
			"?" => 32,
			"FALSE" => 126,
			'BOUND' => 235,
			'DOUBLE_NEGATIVE' => 109,
			"(" => 224,
			'ISURI' => 237,
			"REGEX" => 238
		},
		GOTOS => {
			'BooleanLiteral' => 271,
			'RegexExpression' => 227,
			'NumericLiteralPositive' => 115,
			'DOUBLE_POSITIVE' => 116,
			'RelationalExpression' => 273,
			'ValueLogical' => 274,
			'MultiplicativeExpression' => 275,
			'NumericLiteralNegative' => 118,
			'NumericLiteralUnsigned' => 120,
			'VAR1' => 25,
			'IRI_REF' => 28,
			'NumericLiteral' => 277,
			'IRIrefOrFunction' => 278,
			'NumericExpression' => 279,
			'ConditionalOrExpression' => 287,
			'VAR2' => 29,
			'Var' => 280,
			'INTEGER' => 104,
			'Expression' => 351,
			'BrackettedExpression' => 281,
			'INTEGER_POSITIVE' => 127,
			'PrefixedName' => 34,
			'DECIMAL_POSITIVE' => 107,
			'ConditionalAndExpression' => 289,
			'PrimaryExpression' => 282,
			'PNAME_LN' => 35,
			'BuiltInCall' => 283,
			'PNAME_NS' => 36,
			'UnaryExpression' => 284,
			'AdditiveExpression' => 290,
			'IRIref' => 285,
			'RDFLiteral' => 291
		}
	},
	{#State 300
		ACTIONS => {
			"-" => 272,
			":" => 23,
			'LANGMATCHES' => 215,
			"+" => 286,
			'DATATYPE' => 216,
			'ISIRI' => 228,
			'ISLITERAL' => 218,
			'STRING' => 119,
			'INTEGER_WS' => 96,
			'INTEGER_NEGATIVE' => 99,
			"!" => 276,
			'ISBLANK' => 232,
			'SAMETERM' => 220,
			"\$" => 27,
			'DECIMAL' => 100,
			'LANG' => 221,
			'DECIMAL_NEGATIVE' => 123,
			'STR' => 233,
			'DOUBLE' => 125,
			'URI' => 6,
			'NAME' => 31,
			'INTEGER_NO_WS' => 95,
			"TRUE" => 105,
			"?" => 32,
			"FALSE" => 126,
			'BOUND' => 235,
			'DOUBLE_NEGATIVE' => 109,
			"(" => 224,
			'ISURI' => 237,
			"REGEX" => 238
		},
		GOTOS => {
			'BooleanLiteral' => 271,
			'RegexExpression' => 227,
			'NumericLiteralPositive' => 115,
			'DOUBLE_POSITIVE' => 116,
			'RelationalExpression' => 273,
			'ValueLogical' => 274,
			'MultiplicativeExpression' => 275,
			'NumericLiteralNegative' => 118,
			'NumericLiteralUnsigned' => 120,
			'VAR1' => 25,
			'IRI_REF' => 28,
			'NumericLiteral' => 277,
			'IRIrefOrFunction' => 278,
			'NumericExpression' => 279,
			'ConditionalOrExpression' => 287,
			'VAR2' => 29,
			'Var' => 280,
			'INTEGER' => 104,
			'Expression' => 352,
			'BrackettedExpression' => 281,
			'INTEGER_POSITIVE' => 127,
			'PrefixedName' => 34,
			'DECIMAL_POSITIVE' => 107,
			'ConditionalAndExpression' => 289,
			'PrimaryExpression' => 282,
			'PNAME_LN' => 35,
			'BuiltInCall' => 283,
			'PNAME_NS' => 36,
			'UnaryExpression' => 284,
			'AdditiveExpression' => 290,
			'IRIref' => 285,
			'RDFLiteral' => 291
		}
	},
	{#State 301
		DEFAULT => -65
	},
	{#State 302
		DEFAULT => -66
	},
	{#State 303
		DEFAULT => -56
	},
	{#State 304
		DEFAULT => -53
	},
	{#State 305
		DEFAULT => -51
	},
	{#State 306
		DEFAULT => -55
	},
	{#State 307
		DEFAULT => -121
	},
	{#State 308
		ACTIONS => {
			":" => 23,
			"a" => 154,
			"\$" => 27,
			'NAME' => 31,
			'URI' => 6,
			"?" => 32
		},
		DEFAULT => -119,
		GOTOS => {
			'OPTIONAL-34' => 355,
			'Verb' => 354,
			'PrefixedName' => 34,
			'PAREN-33' => 353,
			'VAR1' => 25,
			'PNAME_LN' => 35,
			'PNAME_NS' => 36,
			'IRI_REF' => 28,
			'IRIref' => 38,
			'VarOrIRIref' => 156,
			'VAR2' => 29,
			'Var' => 30
		}
	},
	{#State 309
		ACTIONS => {
			":" => 23,
			"+" => 117,
			'STRING' => 119,
			'INTEGER_WS' => 96,
			'INTEGER_NEGATIVE' => 99,
			"\$" => 27,
			'DECIMAL' => 100,
			"[" => 101,
			'DECIMAL_NEGATIVE' => 123,
			'INTEGER_NO_WS' => 95,
			"TRUE" => 105,
			'NAME' => 31,
			'URI' => 6,
			'DOUBLE' => 125,
			"?" => 32,
			"FALSE" => 126,
			'DOUBLE_NEGATIVE' => 109,
			"(" => 110,
			"_:" => 133
		},
		GOTOS => {
			'GraphNode' => 197,
			'BooleanLiteral' => 98,
			'NumericLiteralPositive' => 115,
			'DOUBLE_POSITIVE' => 116,
			'NumericLiteralNegative' => 118,
			'NumericLiteralUnsigned' => 120,
			'NIL' => 121,
			'VAR1' => 25,
			'IRI_REF' => 28,
			'Object' => 356,
			'NumericLiteral' => 102,
			'VAR2' => 29,
			'Var' => 103,
			'VarOrTerm' => 160,
			'INTEGER' => 104,
			'INTEGER_POSITIVE' => 127,
			'ANON' => 106,
			'TriplesNode' => 163,
			'GraphTerm' => 129,
			'BLANK_NODE_LABEL' => 128,
			'PrefixedName' => 34,
			'DECIMAL_POSITIVE' => 107,
			'PNAME_LN' => 35,
			'BlankNode' => 131,
			'PNAME_NS' => 36,
			'IRIref' => 112,
			'BlankNodePropertyList' => 113,
			'Collection' => 114,
			'RDFLiteral' => 132
		}
	},
	{#State 310
		DEFAULT => -128
	},
	{#State 311
		ACTIONS => {
			'NAME' => 358
		},
		GOTOS => {
			'PLUS-52' => 357
		}
	},
	{#State 312
		DEFAULT => -258
	},
	{#State 313
		ACTIONS => {
			"UNION" => 359
		},
		DEFAULT => -95,
		GOTOS => {
			'PAREN-25' => 360
		}
	},
	{#State 314
		ACTIONS => {
			"{" => 144
		},
		GOTOS => {
			'GroupGraphPattern' => 361
		}
	},
	{#State 315
		DEFAULT => -69
	},
	{#State 316
		ACTIONS => {
			":" => 23,
			"+" => 117,
			'STRING' => 119,
			'INTEGER_WS' => 96,
			'INTEGER_NEGATIVE' => 99,
			"\$" => 27,
			'DECIMAL' => 100,
			"[" => 101,
			'DECIMAL_NEGATIVE' => 123,
			'DOUBLE' => 125,
			'INTEGER_NO_WS' => 95,
			"TRUE" => 105,
			'NAME' => 31,
			'URI' => 6,
			"?" => 32,
			"FALSE" => 126,
			'DOUBLE_NEGATIVE' => 109,
			"(" => 110,
			"_:" => 133
		},
		DEFAULT => -72,
		GOTOS => {
			'BooleanLiteral' => 98,
			'OPTIONAL-19' => 363,
			'NumericLiteralPositive' => 115,
			'DOUBLE_POSITIVE' => 116,
			'NumericLiteralNegative' => 118,
			'NumericLiteralUnsigned' => 120,
			'NIL' => 121,
			'VAR1' => 25,
			'TriplesSameSubject' => 187,
			'IRI_REF' => 28,
			'TriplesBlock' => 362,
			'NumericLiteral' => 102,
			'VAR2' => 29,
			'Var' => 103,
			'VarOrTerm' => 124,
			'INTEGER' => 104,
			'INTEGER_POSITIVE' => 127,
			'ANON' => 106,
			'TriplesNode' => 130,
			'GraphTerm' => 129,
			'BLANK_NODE_LABEL' => 128,
			'PrefixedName' => 34,
			'DECIMAL_POSITIVE' => 107,
			'PNAME_LN' => 35,
			'BlankNode' => 131,
			'PNAME_NS' => 36,
			'IRIref' => 112,
			'BlankNodePropertyList' => 113,
			'Collection' => 114,
			'RDFLiteral' => 132
		}
	},
	{#State 317
		DEFAULT => -96
	},
	{#State 318
		ACTIONS => {
			"{" => 144
		},
		GOTOS => {
			'GroupGraphPattern' => 364
		}
	},
	{#State 319
		DEFAULT => -90
	},
	{#State 320
		ACTIONS => {
			"," => 365
		}
	},
	{#State 321
		ACTIONS => {
			")" => 366
		}
	},
	{#State 322
		ACTIONS => {
			")" => 367
		}
	},
	{#State 323
		ACTIONS => {
			"," => 368
		}
	},
	{#State 324
		ACTIONS => {
			")" => 369
		}
	},
	{#State 325
		DEFAULT => -188
	},
	{#State 326
		ACTIONS => {
			"&&" => 370
		},
		DEFAULT => -162,
		GOTOS => {
			'PAREN-43' => 371
		}
	},
	{#State 327
		ACTIONS => {
			"-" => 372,
			"+" => 375,
			'INTEGER_NEGATIVE' => 99,
			'DECIMAL_NEGATIVE' => 123,
			'DOUBLE_NEGATIVE' => 109
		},
		DEFAULT => -176,
		GOTOS => {
			'NumericLiteralPositive' => 374,
			'DOUBLE_POSITIVE' => 116,
			'AdditiveExpressionExtra' => 373,
			'INTEGER_POSITIVE' => 127,
			'NumericLiteralNegative' => 376,
			'DECIMAL_POSITIVE' => 107
		}
	},
	{#State 328
		DEFAULT => -186
	},
	{#State 329
		ACTIONS => {
			"-" => 272,
			":" => 23,
			'LANGMATCHES' => 215,
			"+" => 286,
			'DATATYPE' => 216,
			'ISIRI' => 228,
			'ISLITERAL' => 218,
			'STRING' => 119,
			'INTEGER_WS' => 96,
			'INTEGER_NEGATIVE' => 99,
			"!" => 276,
			'ISBLANK' => 232,
			'SAMETERM' => 220,
			"\$" => 27,
			'DECIMAL' => 100,
			'LANG' => 221,
			'DECIMAL_NEGATIVE' => 123,
			'STR' => 233,
			'DOUBLE' => 125,
			'URI' => 6,
			'NAME' => 31,
			'INTEGER_NO_WS' => 95,
			"TRUE" => 105,
			"?" => 32,
			"FALSE" => 126,
			'BOUND' => 235,
			'DOUBLE_NEGATIVE' => 109,
			"(" => 224,
			'ISURI' => 237,
			"REGEX" => 238
		},
		GOTOS => {
			'BooleanLiteral' => 271,
			'RegexExpression' => 227,
			'NumericLiteralPositive' => 115,
			'DOUBLE_POSITIVE' => 116,
			'MultiplicativeExpression' => 275,
			'NumericLiteralNegative' => 118,
			'NumericLiteralUnsigned' => 120,
			'VAR1' => 25,
			'IRI_REF' => 28,
			'NumericLiteral' => 277,
			'IRIrefOrFunction' => 278,
			'NumericExpression' => 377,
			'Var' => 280,
			'VAR2' => 29,
			'INTEGER' => 104,
			'BrackettedExpression' => 281,
			'INTEGER_POSITIVE' => 127,
			'PrefixedName' => 34,
			'DECIMAL_POSITIVE' => 107,
			'PrimaryExpression' => 282,
			'PNAME_LN' => 35,
			'BuiltInCall' => 283,
			'PNAME_NS' => 36,
			'UnaryExpression' => 284,
			'AdditiveExpression' => 290,
			'IRIref' => 285,
			'RDFLiteral' => 291
		}
	},
	{#State 330
		DEFAULT => -164
	},
	{#State 331
		ACTIONS => {
			"-" => 272,
			":" => 23,
			'LANGMATCHES' => 215,
			"+" => 286,
			'DATATYPE' => 216,
			'ISIRI' => 228,
			'ISLITERAL' => 218,
			'STRING' => 119,
			'INTEGER_WS' => 96,
			'INTEGER_NEGATIVE' => 99,
			"!" => 276,
			'ISBLANK' => 232,
			'SAMETERM' => 220,
			"\$" => 27,
			'DECIMAL' => 100,
			'LANG' => 221,
			'DECIMAL_NEGATIVE' => 123,
			'STR' => 233,
			'DOUBLE' => 125,
			'URI' => 6,
			'NAME' => 31,
			'INTEGER_NO_WS' => 95,
			"TRUE" => 105,
			"?" => 32,
			"FALSE" => 126,
			'BOUND' => 235,
			'DOUBLE_NEGATIVE' => 109,
			"(" => 224,
			'ISURI' => 237,
			"REGEX" => 238
		},
		GOTOS => {
			'BooleanLiteral' => 271,
			'RegexExpression' => 227,
			'NumericLiteralPositive' => 115,
			'DOUBLE_POSITIVE' => 116,
			'MultiplicativeExpression' => 275,
			'NumericLiteralNegative' => 118,
			'NumericLiteralUnsigned' => 120,
			'VAR1' => 25,
			'IRI_REF' => 28,
			'NumericLiteral' => 277,
			'IRIrefOrFunction' => 278,
			'NumericExpression' => 378,
			'Var' => 280,
			'VAR2' => 29,
			'INTEGER' => 104,
			'BrackettedExpression' => 281,
			'INTEGER_POSITIVE' => 127,
			'PrefixedName' => 34,
			'DECIMAL_POSITIVE' => 107,
			'PrimaryExpression' => 282,
			'PNAME_LN' => 35,
			'BuiltInCall' => 283,
			'PNAME_NS' => 36,
			'UnaryExpression' => 284,
			'AdditiveExpression' => 290,
			'IRIref' => 285,
			'RDFLiteral' => 291
		}
	},
	{#State 332
		ACTIONS => {
			"-" => 272,
			":" => 23,
			'LANGMATCHES' => 215,
			"+" => 286,
			'DATATYPE' => 216,
			'ISIRI' => 228,
			'ISLITERAL' => 218,
			'STRING' => 119,
			'INTEGER_WS' => 96,
			'INTEGER_NEGATIVE' => 99,
			"!" => 276,
			'ISBLANK' => 232,
			'SAMETERM' => 220,
			"\$" => 27,
			'DECIMAL' => 100,
			'LANG' => 221,
			'DECIMAL_NEGATIVE' => 123,
			'STR' => 233,
			'DOUBLE' => 125,
			'URI' => 6,
			'NAME' => 31,
			'INTEGER_NO_WS' => 95,
			"TRUE" => 105,
			"?" => 32,
			"FALSE" => 126,
			'BOUND' => 235,
			'DOUBLE_NEGATIVE' => 109,
			"(" => 224,
			'ISURI' => 237,
			"REGEX" => 238
		},
		GOTOS => {
			'BooleanLiteral' => 271,
			'RegexExpression' => 227,
			'NumericLiteralPositive' => 115,
			'DOUBLE_POSITIVE' => 116,
			'MultiplicativeExpression' => 275,
			'NumericLiteralNegative' => 118,
			'NumericLiteralUnsigned' => 120,
			'VAR1' => 25,
			'IRI_REF' => 28,
			'NumericLiteral' => 277,
			'IRIrefOrFunction' => 278,
			'NumericExpression' => 379,
			'Var' => 280,
			'VAR2' => 29,
			'INTEGER' => 104,
			'BrackettedExpression' => 281,
			'INTEGER_POSITIVE' => 127,
			'PrefixedName' => 34,
			'DECIMAL_POSITIVE' => 107,
			'PrimaryExpression' => 282,
			'PNAME_LN' => 35,
			'BuiltInCall' => 283,
			'PNAME_NS' => 36,
			'UnaryExpression' => 284,
			'AdditiveExpression' => 290,
			'IRIref' => 285,
			'RDFLiteral' => 291
		}
	},
	{#State 333
		ACTIONS => {
			"-" => 272,
			":" => 23,
			'LANGMATCHES' => 215,
			"+" => 286,
			'DATATYPE' => 216,
			'ISIRI' => 228,
			'ISLITERAL' => 218,
			'STRING' => 119,
			'INTEGER_WS' => 96,
			'INTEGER_NEGATIVE' => 99,
			"!" => 276,
			'ISBLANK' => 232,
			'SAMETERM' => 220,
			"\$" => 27,
			'DECIMAL' => 100,
			'LANG' => 221,
			'DECIMAL_NEGATIVE' => 123,
			'STR' => 233,
			'DOUBLE' => 125,
			'URI' => 6,
			'NAME' => 31,
			'INTEGER_NO_WS' => 95,
			"TRUE" => 105,
			"?" => 32,
			"FALSE" => 126,
			'BOUND' => 235,
			'DOUBLE_NEGATIVE' => 109,
			"(" => 224,
			'ISURI' => 237,
			"REGEX" => 238
		},
		GOTOS => {
			'BooleanLiteral' => 271,
			'RegexExpression' => 227,
			'NumericLiteralPositive' => 115,
			'DOUBLE_POSITIVE' => 116,
			'MultiplicativeExpression' => 275,
			'NumericLiteralNegative' => 118,
			'NumericLiteralUnsigned' => 120,
			'VAR1' => 25,
			'IRI_REF' => 28,
			'NumericLiteral' => 277,
			'IRIrefOrFunction' => 278,
			'NumericExpression' => 380,
			'Var' => 280,
			'VAR2' => 29,
			'INTEGER' => 104,
			'BrackettedExpression' => 281,
			'INTEGER_POSITIVE' => 127,
			'PrefixedName' => 34,
			'DECIMAL_POSITIVE' => 107,
			'PrimaryExpression' => 282,
			'PNAME_LN' => 35,
			'BuiltInCall' => 283,
			'PNAME_NS' => 36,
			'UnaryExpression' => 284,
			'AdditiveExpression' => 290,
			'IRIref' => 285,
			'RDFLiteral' => 291
		}
	},
	{#State 334
		DEFAULT => -166
	},
	{#State 335
		ACTIONS => {
			"-" => 272,
			":" => 23,
			'LANGMATCHES' => 215,
			"+" => 286,
			'DATATYPE' => 216,
			'ISIRI' => 228,
			'ISLITERAL' => 218,
			'STRING' => 119,
			'INTEGER_WS' => 96,
			'INTEGER_NEGATIVE' => 99,
			"!" => 276,
			'ISBLANK' => 232,
			'SAMETERM' => 220,
			"\$" => 27,
			'DECIMAL' => 100,
			'LANG' => 221,
			'DECIMAL_NEGATIVE' => 123,
			'STR' => 233,
			'DOUBLE' => 125,
			'URI' => 6,
			'NAME' => 31,
			'INTEGER_NO_WS' => 95,
			"TRUE" => 105,
			"?" => 32,
			"FALSE" => 126,
			'BOUND' => 235,
			'DOUBLE_NEGATIVE' => 109,
			"(" => 224,
			'ISURI' => 237,
			"REGEX" => 238
		},
		GOTOS => {
			'BooleanLiteral' => 271,
			'RegexExpression' => 227,
			'NumericLiteralPositive' => 115,
			'DOUBLE_POSITIVE' => 116,
			'MultiplicativeExpression' => 275,
			'NumericLiteralNegative' => 118,
			'NumericLiteralUnsigned' => 120,
			'VAR1' => 25,
			'IRI_REF' => 28,
			'NumericLiteral' => 277,
			'IRIrefOrFunction' => 278,
			'NumericExpression' => 381,
			'Var' => 280,
			'VAR2' => 29,
			'INTEGER' => 104,
			'BrackettedExpression' => 281,
			'INTEGER_POSITIVE' => 127,
			'PrefixedName' => 34,
			'DECIMAL_POSITIVE' => 107,
			'PrimaryExpression' => 282,
			'PNAME_LN' => 35,
			'BuiltInCall' => 283,
			'PNAME_NS' => 36,
			'UnaryExpression' => 284,
			'AdditiveExpression' => 290,
			'IRIref' => 285,
			'RDFLiteral' => 291
		}
	},
	{#State 336
		ACTIONS => {
			"-" => 272,
			":" => 23,
			'LANGMATCHES' => 215,
			"+" => 286,
			'DATATYPE' => 216,
			'ISIRI' => 228,
			'ISLITERAL' => 218,
			'STRING' => 119,
			'INTEGER_WS' => 96,
			'INTEGER_NEGATIVE' => 99,
			"!" => 276,
			'ISBLANK' => 232,
			'SAMETERM' => 220,
			"\$" => 27,
			'DECIMAL' => 100,
			'LANG' => 221,
			'DECIMAL_NEGATIVE' => 123,
			'STR' => 233,
			'DOUBLE' => 125,
			'URI' => 6,
			'NAME' => 31,
			'INTEGER_NO_WS' => 95,
			"TRUE" => 105,
			"?" => 32,
			"FALSE" => 126,
			'BOUND' => 235,
			'DOUBLE_NEGATIVE' => 109,
			"(" => 224,
			'ISURI' => 237,
			"REGEX" => 238
		},
		GOTOS => {
			'BooleanLiteral' => 271,
			'RegexExpression' => 227,
			'NumericLiteralPositive' => 115,
			'DOUBLE_POSITIVE' => 116,
			'MultiplicativeExpression' => 275,
			'NumericLiteralNegative' => 118,
			'NumericLiteralUnsigned' => 120,
			'VAR1' => 25,
			'IRI_REF' => 28,
			'NumericLiteral' => 277,
			'IRIrefOrFunction' => 278,
			'NumericExpression' => 382,
			'Var' => 280,
			'VAR2' => 29,
			'INTEGER' => 104,
			'BrackettedExpression' => 281,
			'INTEGER_POSITIVE' => 127,
			'PrefixedName' => 34,
			'DECIMAL_POSITIVE' => 107,
			'PrimaryExpression' => 282,
			'PNAME_LN' => 35,
			'BuiltInCall' => 283,
			'PNAME_NS' => 36,
			'UnaryExpression' => 284,
			'AdditiveExpression' => 290,
			'IRIref' => 285,
			'RDFLiteral' => 291
		}
	},
	{#State 337
		ACTIONS => {
			"*" => 383,
			"/" => 385
		},
		DEFAULT => -183,
		GOTOS => {
			'MultiplicativeExpressionExtra' => 384
		}
	},
	{#State 338
		DEFAULT => -213
	},
	{#State 339
		DEFAULT => -215
	},
	{#State 340
		DEFAULT => -225
	},
	{#State 341
		DEFAULT => -224
	},
	{#State 342
		DEFAULT => -187
	},
	{#State 343
		DEFAULT => -226
	},
	{#State 344
		DEFAULT => -197
	},
	{#State 345
		ACTIONS => {
			"||" => 387
		},
		DEFAULT => -158,
		GOTOS => {
			'PAREN-41' => 386
		}
	},
	{#State 346
		DEFAULT => -103,
		GOTOS => {
			'STAR-28' => 388
		}
	},
	{#State 347
		ACTIONS => {
			")" => 389
		}
	},
	{#State 348
		ACTIONS => {
			")" => 390
		}
	},
	{#State 349
		ACTIONS => {
			")" => 391
		}
	},
	{#State 350
		ACTIONS => {
			")" => 392
		}
	},
	{#State 351
		ACTIONS => {
			")" => 393
		}
	},
	{#State 352
		ACTIONS => {
			"," => 394
		}
	},
	{#State 353
		DEFAULT => -118
	},
	{#State 354
		ACTIONS => {
			":" => 23,
			"+" => 117,
			'STRING' => 119,
			'INTEGER_WS' => 96,
			'INTEGER_NEGATIVE' => 99,
			"\$" => 27,
			'DECIMAL' => 100,
			"[" => 101,
			'DECIMAL_NEGATIVE' => 123,
			'INTEGER_NO_WS' => 95,
			"TRUE" => 105,
			'NAME' => 31,
			'URI' => 6,
			'DOUBLE' => 125,
			"?" => 32,
			"FALSE" => 126,
			'DOUBLE_NEGATIVE' => 109,
			"(" => 110,
			"_:" => 133
		},
		GOTOS => {
			'GraphNode' => 197,
			'BooleanLiteral' => 98,
			'NumericLiteralPositive' => 115,
			'DOUBLE_POSITIVE' => 116,
			'NumericLiteralNegative' => 118,
			'NumericLiteralUnsigned' => 120,
			'NIL' => 121,
			'VAR1' => 25,
			'IRI_REF' => 28,
			'Object' => 198,
			'NumericLiteral' => 102,
			'VAR2' => 29,
			'Var' => 103,
			'VarOrTerm' => 160,
			'INTEGER' => 104,
			'ObjectList' => 395,
			'INTEGER_POSITIVE' => 127,
			'ANON' => 106,
			'TriplesNode' => 163,
			'GraphTerm' => 129,
			'BLANK_NODE_LABEL' => 128,
			'PrefixedName' => 34,
			'DECIMAL_POSITIVE' => 107,
			'PNAME_LN' => 35,
			'BlankNode' => 131,
			'PNAME_NS' => 36,
			'IRIref' => 112,
			'BlankNodePropertyList' => 113,
			'Collection' => 114,
			'RDFLiteral' => 132
		}
	},
	{#State 355
		DEFAULT => -120
	},
	{#State 356
		DEFAULT => -127
	},
	{#State 357
		ACTIONS => {
			'NAME' => 396
		},
		DEFAULT => -257
	},
	{#State 358
		DEFAULT => -256
	},
	{#State 359
		ACTIONS => {
			"{" => 144
		},
		GOTOS => {
			'GroupGraphPattern' => 397
		}
	},
	{#State 360
		DEFAULT => -93
	},
	{#State 361
		DEFAULT => -91
	},
	{#State 362
		DEFAULT => -71
	},
	{#State 363
		DEFAULT => -73
	},
	{#State 364
		DEFAULT => -89
	},
	{#State 365
		ACTIONS => {
			"-" => 272,
			":" => 23,
			'LANGMATCHES' => 215,
			"+" => 286,
			'DATATYPE' => 216,
			'ISIRI' => 228,
			'ISLITERAL' => 218,
			'STRING' => 119,
			'INTEGER_WS' => 96,
			'INTEGER_NEGATIVE' => 99,
			"!" => 276,
			'ISBLANK' => 232,
			'SAMETERM' => 220,
			"\$" => 27,
			'DECIMAL' => 100,
			'LANG' => 221,
			'DECIMAL_NEGATIVE' => 123,
			'STR' => 233,
			'DOUBLE' => 125,
			'URI' => 6,
			'NAME' => 31,
			'INTEGER_NO_WS' => 95,
			"TRUE" => 105,
			"?" => 32,
			"FALSE" => 126,
			'BOUND' => 235,
			'DOUBLE_NEGATIVE' => 109,
			"(" => 224,
			'ISURI' => 237,
			"REGEX" => 238
		},
		GOTOS => {
			'BooleanLiteral' => 271,
			'RegexExpression' => 227,
			'NumericLiteralPositive' => 115,
			'DOUBLE_POSITIVE' => 116,
			'RelationalExpression' => 273,
			'ValueLogical' => 274,
			'MultiplicativeExpression' => 275,
			'NumericLiteralNegative' => 118,
			'NumericLiteralUnsigned' => 120,
			'VAR1' => 25,
			'IRI_REF' => 28,
			'NumericLiteral' => 277,
			'IRIrefOrFunction' => 278,
			'NumericExpression' => 279,
			'ConditionalOrExpression' => 287,
			'VAR2' => 29,
			'Var' => 280,
			'INTEGER' => 104,
			'Expression' => 398,
			'BrackettedExpression' => 281,
			'INTEGER_POSITIVE' => 127,
			'PrefixedName' => 34,
			'DECIMAL_POSITIVE' => 107,
			'ConditionalAndExpression' => 289,
			'PrimaryExpression' => 282,
			'PNAME_LN' => 35,
			'BuiltInCall' => 283,
			'PNAME_NS' => 36,
			'UnaryExpression' => 284,
			'AdditiveExpression' => 290,
			'IRIref' => 285,
			'RDFLiteral' => 291
		}
	},
	{#State 366
		DEFAULT => -201
	},
	{#State 367
		DEFAULT => -207
	},
	{#State 368
		ACTIONS => {
			"-" => 272,
			":" => 23,
			'LANGMATCHES' => 215,
			"+" => 286,
			'DATATYPE' => 216,
			'ISIRI' => 228,
			'ISLITERAL' => 218,
			'STRING' => 119,
			'INTEGER_WS' => 96,
			'INTEGER_NEGATIVE' => 99,
			"!" => 276,
			'ISBLANK' => 232,
			'SAMETERM' => 220,
			"\$" => 27,
			'DECIMAL' => 100,
			'LANG' => 221,
			'DECIMAL_NEGATIVE' => 123,
			'STR' => 233,
			'DOUBLE' => 125,
			'URI' => 6,
			'NAME' => 31,
			'INTEGER_NO_WS' => 95,
			"TRUE" => 105,
			"?" => 32,
			"FALSE" => 126,
			'BOUND' => 235,
			'DOUBLE_NEGATIVE' => 109,
			"(" => 224,
			'ISURI' => 237,
			"REGEX" => 238
		},
		GOTOS => {
			'BooleanLiteral' => 271,
			'RegexExpression' => 227,
			'NumericLiteralPositive' => 115,
			'DOUBLE_POSITIVE' => 116,
			'RelationalExpression' => 273,
			'ValueLogical' => 274,
			'MultiplicativeExpression' => 275,
			'NumericLiteralNegative' => 118,
			'NumericLiteralUnsigned' => 120,
			'VAR1' => 25,
			'IRI_REF' => 28,
			'NumericLiteral' => 277,
			'IRIrefOrFunction' => 278,
			'NumericExpression' => 279,
			'ConditionalOrExpression' => 287,
			'VAR2' => 29,
			'Var' => 280,
			'INTEGER' => 104,
			'Expression' => 399,
			'BrackettedExpression' => 281,
			'INTEGER_POSITIVE' => 127,
			'PrefixedName' => 34,
			'DECIMAL_POSITIVE' => 107,
			'ConditionalAndExpression' => 289,
			'PrimaryExpression' => 282,
			'PNAME_LN' => 35,
			'BuiltInCall' => 283,
			'PNAME_NS' => 36,
			'UnaryExpression' => 284,
			'AdditiveExpression' => 290,
			'IRIref' => 285,
			'RDFLiteral' => 291
		}
	},
	{#State 369
		DEFAULT => -199
	},
	{#State 370
		ACTIONS => {
			"-" => 272,
			":" => 23,
			'LANGMATCHES' => 215,
			"+" => 286,
			'DATATYPE' => 216,
			'ISIRI' => 228,
			'ISLITERAL' => 218,
			'STRING' => 119,
			'INTEGER_WS' => 96,
			'INTEGER_NEGATIVE' => 99,
			"!" => 276,
			'ISBLANK' => 232,
			'SAMETERM' => 220,
			"\$" => 27,
			'DECIMAL' => 100,
			'LANG' => 221,
			'DECIMAL_NEGATIVE' => 123,
			'STR' => 233,
			'DOUBLE' => 125,
			'URI' => 6,
			'NAME' => 31,
			'INTEGER_NO_WS' => 95,
			"TRUE" => 105,
			"?" => 32,
			"FALSE" => 126,
			'BOUND' => 235,
			'DOUBLE_NEGATIVE' => 109,
			"(" => 224,
			'ISURI' => 237,
			"REGEX" => 238
		},
		GOTOS => {
			'BooleanLiteral' => 271,
			'RegexExpression' => 227,
			'NumericLiteralPositive' => 115,
			'DOUBLE_POSITIVE' => 116,
			'RelationalExpression' => 273,
			'ValueLogical' => 400,
			'MultiplicativeExpression' => 275,
			'NumericLiteralNegative' => 118,
			'NumericLiteralUnsigned' => 120,
			'VAR1' => 25,
			'IRI_REF' => 28,
			'NumericLiteral' => 277,
			'IRIrefOrFunction' => 278,
			'NumericExpression' => 279,
			'VAR2' => 29,
			'Var' => 280,
			'INTEGER' => 104,
			'BrackettedExpression' => 281,
			'INTEGER_POSITIVE' => 127,
			'PrefixedName' => 34,
			'DECIMAL_POSITIVE' => 107,
			'PrimaryExpression' => 282,
			'PNAME_LN' => 35,
			'BuiltInCall' => 283,
			'PNAME_NS' => 36,
			'UnaryExpression' => 284,
			'AdditiveExpression' => 290,
			'IRIref' => 285,
			'RDFLiteral' => 291
		}
	},
	{#State 371
		DEFAULT => -160
	},
	{#State 372
		ACTIONS => {
			"-" => 272,
			":" => 23,
			'LANGMATCHES' => 215,
			"+" => 286,
			'DATATYPE' => 216,
			'ISIRI' => 228,
			'ISLITERAL' => 218,
			'STRING' => 119,
			'INTEGER_WS' => 96,
			'INTEGER_NEGATIVE' => 99,
			"!" => 276,
			'ISBLANK' => 232,
			'SAMETERM' => 220,
			"\$" => 27,
			'DECIMAL' => 100,
			'LANG' => 221,
			'DECIMAL_NEGATIVE' => 123,
			'STR' => 233,
			'DOUBLE' => 125,
			'URI' => 6,
			'NAME' => 31,
			'INTEGER_NO_WS' => 95,
			"TRUE" => 105,
			"?" => 32,
			"FALSE" => 126,
			'BOUND' => 235,
			'DOUBLE_NEGATIVE' => 109,
			"(" => 224,
			'ISURI' => 237,
			"REGEX" => 238
		},
		GOTOS => {
			'BooleanLiteral' => 271,
			'RegexExpression' => 227,
			'NumericLiteralPositive' => 115,
			'DOUBLE_POSITIVE' => 116,
			'MultiplicativeExpression' => 401,
			'NumericLiteralNegative' => 118,
			'NumericLiteralUnsigned' => 120,
			'VAR1' => 25,
			'IRI_REF' => 28,
			'NumericLiteral' => 277,
			'IRIrefOrFunction' => 278,
			'Var' => 280,
			'VAR2' => 29,
			'INTEGER' => 104,
			'BrackettedExpression' => 281,
			'INTEGER_POSITIVE' => 127,
			'PrefixedName' => 34,
			'DECIMAL_POSITIVE' => 107,
			'PrimaryExpression' => 282,
			'PNAME_LN' => 35,
			'BuiltInCall' => 283,
			'PNAME_NS' => 36,
			'UnaryExpression' => 284,
			'IRIref' => 285,
			'RDFLiteral' => 291
		}
	},
	{#State 373
		DEFAULT => -174
	},
	{#State 374
		DEFAULT => -179
	},
	{#State 375
		ACTIONS => {
			"-" => 272,
			":" => 23,
			'LANGMATCHES' => 215,
			"+" => 286,
			'DATATYPE' => 216,
			'ISIRI' => 228,
			'ISLITERAL' => 218,
			'STRING' => 119,
			'INTEGER_WS' => 96,
			'INTEGER_NEGATIVE' => 99,
			"!" => 276,
			'ISBLANK' => 232,
			'SAMETERM' => 220,
			"\$" => 27,
			'DECIMAL' => 340,
			'LANG' => 221,
			'DECIMAL_NEGATIVE' => 123,
			'STR' => 233,
			'DOUBLE' => 343,
			'URI' => 6,
			'NAME' => 31,
			'INTEGER_NO_WS' => 95,
			"TRUE" => 105,
			"?" => 32,
			"FALSE" => 126,
			'BOUND' => 235,
			'DOUBLE_NEGATIVE' => 109,
			"(" => 224,
			'ISURI' => 237,
			"REGEX" => 238
		},
		GOTOS => {
			'BooleanLiteral' => 271,
			'RegexExpression' => 227,
			'NumericLiteralPositive' => 115,
			'DOUBLE_POSITIVE' => 116,
			'MultiplicativeExpression' => 402,
			'NumericLiteralNegative' => 118,
			'NumericLiteralUnsigned' => 120,
			'VAR1' => 25,
			'IRI_REF' => 28,
			'NumericLiteral' => 277,
			'IRIrefOrFunction' => 278,
			'Var' => 280,
			'VAR2' => 29,
			'INTEGER' => 341,
			'BrackettedExpression' => 281,
			'INTEGER_POSITIVE' => 127,
			'PrefixedName' => 34,
			'DECIMAL_POSITIVE' => 107,
			'PrimaryExpression' => 282,
			'PNAME_LN' => 35,
			'BuiltInCall' => 283,
			'PNAME_NS' => 36,
			'UnaryExpression' => 284,
			'IRIref' => 285,
			'RDFLiteral' => 291
		}
	},
	{#State 376
		DEFAULT => -180
	},
	{#State 377
		DEFAULT => -169
	},
	{#State 378
		DEFAULT => -172
	},
	{#State 379
		DEFAULT => -171
	},
	{#State 380
		DEFAULT => -170
	},
	{#State 381
		DEFAULT => -168
	},
	{#State 382
		DEFAULT => -167
	},
	{#State 383
		ACTIONS => {
			"-" => 272,
			":" => 23,
			'LANGMATCHES' => 215,
			"+" => 286,
			'DATATYPE' => 216,
			'ISIRI' => 228,
			'ISLITERAL' => 218,
			'STRING' => 119,
			'INTEGER_WS' => 96,
			'INTEGER_NEGATIVE' => 99,
			"!" => 276,
			'ISBLANK' => 232,
			'SAMETERM' => 220,
			"\$" => 27,
			'DECIMAL' => 100,
			'LANG' => 221,
			'DECIMAL_NEGATIVE' => 123,
			'STR' => 233,
			'DOUBLE' => 125,
			'URI' => 6,
			'NAME' => 31,
			'INTEGER_NO_WS' => 95,
			"TRUE" => 105,
			"?" => 32,
			"FALSE" => 126,
			'BOUND' => 235,
			'DOUBLE_NEGATIVE' => 109,
			"(" => 224,
			'ISURI' => 237,
			"REGEX" => 238
		},
		GOTOS => {
			'BooleanLiteral' => 271,
			'RegexExpression' => 227,
			'NumericLiteralPositive' => 115,
			'DOUBLE_POSITIVE' => 116,
			'NumericLiteralNegative' => 118,
			'NumericLiteralUnsigned' => 120,
			'VAR1' => 25,
			'IRI_REF' => 28,
			'NumericLiteral' => 277,
			'IRIrefOrFunction' => 278,
			'Var' => 280,
			'VAR2' => 29,
			'INTEGER' => 104,
			'BrackettedExpression' => 281,
			'INTEGER_POSITIVE' => 127,
			'PrefixedName' => 34,
			'DECIMAL_POSITIVE' => 107,
			'PrimaryExpression' => 282,
			'PNAME_LN' => 35,
			'BuiltInCall' => 283,
			'PNAME_NS' => 36,
			'UnaryExpression' => 403,
			'IRIref' => 285,
			'RDFLiteral' => 291
		}
	},
	{#State 384
		DEFAULT => -181
	},
	{#State 385
		ACTIONS => {
			"-" => 272,
			":" => 23,
			'LANGMATCHES' => 215,
			"+" => 286,
			'DATATYPE' => 216,
			'ISIRI' => 228,
			'ISLITERAL' => 218,
			'STRING' => 119,
			'INTEGER_WS' => 96,
			'INTEGER_NEGATIVE' => 99,
			"!" => 276,
			'ISBLANK' => 232,
			'SAMETERM' => 220,
			"\$" => 27,
			'DECIMAL' => 100,
			'LANG' => 221,
			'DECIMAL_NEGATIVE' => 123,
			'STR' => 233,
			'DOUBLE' => 125,
			'URI' => 6,
			'NAME' => 31,
			'INTEGER_NO_WS' => 95,
			"TRUE" => 105,
			"?" => 32,
			"FALSE" => 126,
			'BOUND' => 235,
			'DOUBLE_NEGATIVE' => 109,
			"(" => 224,
			'ISURI' => 237,
			"REGEX" => 238
		},
		GOTOS => {
			'BooleanLiteral' => 271,
			'RegexExpression' => 227,
			'NumericLiteralPositive' => 115,
			'DOUBLE_POSITIVE' => 116,
			'NumericLiteralNegative' => 118,
			'NumericLiteralUnsigned' => 120,
			'VAR1' => 25,
			'IRI_REF' => 28,
			'NumericLiteral' => 277,
			'IRIrefOrFunction' => 278,
			'Var' => 280,
			'VAR2' => 29,
			'INTEGER' => 104,
			'BrackettedExpression' => 281,
			'INTEGER_POSITIVE' => 127,
			'PrefixedName' => 34,
			'DECIMAL_POSITIVE' => 107,
			'PrimaryExpression' => 282,
			'PNAME_LN' => 35,
			'BuiltInCall' => 283,
			'PNAME_NS' => 36,
			'UnaryExpression' => 404,
			'IRIref' => 285,
			'RDFLiteral' => 291
		}
	},
	{#State 386
		DEFAULT => -156
	},
	{#State 387
		ACTIONS => {
			"-" => 272,
			":" => 23,
			'LANGMATCHES' => 215,
			"+" => 286,
			'DATATYPE' => 216,
			'ISIRI' => 228,
			'ISLITERAL' => 218,
			'STRING' => 119,
			'INTEGER_WS' => 96,
			'INTEGER_NEGATIVE' => 99,
			"!" => 276,
			'ISBLANK' => 232,
			'SAMETERM' => 220,
			"\$" => 27,
			'DECIMAL' => 100,
			'LANG' => 221,
			'DECIMAL_NEGATIVE' => 123,
			'STR' => 233,
			'DOUBLE' => 125,
			'URI' => 6,
			'NAME' => 31,
			'INTEGER_NO_WS' => 95,
			"TRUE" => 105,
			"?" => 32,
			"FALSE" => 126,
			'BOUND' => 235,
			'DOUBLE_NEGATIVE' => 109,
			"(" => 224,
			'ISURI' => 237,
			"REGEX" => 238
		},
		GOTOS => {
			'BooleanLiteral' => 271,
			'RegexExpression' => 227,
			'NumericLiteralPositive' => 115,
			'DOUBLE_POSITIVE' => 116,
			'RelationalExpression' => 273,
			'ValueLogical' => 274,
			'MultiplicativeExpression' => 275,
			'NumericLiteralNegative' => 118,
			'NumericLiteralUnsigned' => 120,
			'VAR1' => 25,
			'IRI_REF' => 28,
			'NumericLiteral' => 277,
			'IRIrefOrFunction' => 278,
			'NumericExpression' => 279,
			'VAR2' => 29,
			'Var' => 280,
			'INTEGER' => 104,
			'BrackettedExpression' => 281,
			'INTEGER_POSITIVE' => 127,
			'PrefixedName' => 34,
			'DECIMAL_POSITIVE' => 107,
			'ConditionalAndExpression' => 405,
			'PrimaryExpression' => 282,
			'PNAME_LN' => 35,
			'BuiltInCall' => 283,
			'PNAME_NS' => 36,
			'UnaryExpression' => 284,
			'AdditiveExpression' => 290,
			'IRIref' => 285,
			'RDFLiteral' => 291
		}
	},
	{#State 388
		ACTIONS => {
			"," => 407,
			")" => 408
		},
		GOTOS => {
			'PAREN-27' => 406
		}
	},
	{#State 389
		DEFAULT => -204
	},
	{#State 390
		DEFAULT => -206
	},
	{#State 391
		DEFAULT => -198
	},
	{#State 392
		DEFAULT => -202
	},
	{#State 393
		DEFAULT => -205
	},
	{#State 394
		ACTIONS => {
			"-" => 272,
			":" => 23,
			'LANGMATCHES' => 215,
			"+" => 286,
			'DATATYPE' => 216,
			'ISIRI' => 228,
			'ISLITERAL' => 218,
			'STRING' => 119,
			'INTEGER_WS' => 96,
			'INTEGER_NEGATIVE' => 99,
			"!" => 276,
			'ISBLANK' => 232,
			'SAMETERM' => 220,
			"\$" => 27,
			'DECIMAL' => 100,
			'LANG' => 221,
			'DECIMAL_NEGATIVE' => 123,
			'STR' => 233,
			'DOUBLE' => 125,
			'URI' => 6,
			'NAME' => 31,
			'INTEGER_NO_WS' => 95,
			"TRUE" => 105,
			"?" => 32,
			"FALSE" => 126,
			'BOUND' => 235,
			'DOUBLE_NEGATIVE' => 109,
			"(" => 224,
			'ISURI' => 237,
			"REGEX" => 238
		},
		GOTOS => {
			'BooleanLiteral' => 271,
			'RegexExpression' => 227,
			'NumericLiteralPositive' => 115,
			'DOUBLE_POSITIVE' => 116,
			'RelationalExpression' => 273,
			'ValueLogical' => 274,
			'MultiplicativeExpression' => 275,
			'NumericLiteralNegative' => 118,
			'NumericLiteralUnsigned' => 120,
			'VAR1' => 25,
			'IRI_REF' => 28,
			'NumericLiteral' => 277,
			'IRIrefOrFunction' => 278,
			'NumericExpression' => 279,
			'ConditionalOrExpression' => 287,
			'VAR2' => 29,
			'Var' => 280,
			'INTEGER' => 104,
			'Expression' => 409,
			'BrackettedExpression' => 281,
			'INTEGER_POSITIVE' => 127,
			'PrefixedName' => 34,
			'DECIMAL_POSITIVE' => 107,
			'ConditionalAndExpression' => 289,
			'PrimaryExpression' => 282,
			'PNAME_LN' => 35,
			'BuiltInCall' => 283,
			'PNAME_NS' => 36,
			'UnaryExpression' => 284,
			'AdditiveExpression' => 290,
			'IRIref' => 285,
			'RDFLiteral' => 291
		}
	},
	{#State 395
		DEFAULT => -117
	},
	{#State 396
		DEFAULT => -255
	},
	{#State 397
		DEFAULT => -92
	},
	{#State 398
		ACTIONS => {
			")" => 410
		}
	},
	{#State 399
		ACTIONS => {
			")" => 411
		}
	},
	{#State 400
		DEFAULT => -159
	},
	{#State 401
		DEFAULT => -178
	},
	{#State 402
		DEFAULT => -177
	},
	{#State 403
		DEFAULT => -184
	},
	{#State 404
		DEFAULT => -185
	},
	{#State 405
		DEFAULT => -155
	},
	{#State 406
		DEFAULT => -102
	},
	{#State 407
		ACTIONS => {
			"-" => 272,
			":" => 23,
			'LANGMATCHES' => 215,
			"+" => 286,
			'DATATYPE' => 216,
			'ISIRI' => 228,
			'ISLITERAL' => 218,
			'STRING' => 119,
			'INTEGER_WS' => 96,
			'INTEGER_NEGATIVE' => 99,
			"!" => 276,
			'ISBLANK' => 232,
			'SAMETERM' => 220,
			"\$" => 27,
			'DECIMAL' => 100,
			'LANG' => 221,
			'DECIMAL_NEGATIVE' => 123,
			'STR' => 233,
			'DOUBLE' => 125,
			'URI' => 6,
			'NAME' => 31,
			'INTEGER_NO_WS' => 95,
			"TRUE" => 105,
			"?" => 32,
			"FALSE" => 126,
			'BOUND' => 235,
			'DOUBLE_NEGATIVE' => 109,
			"(" => 224,
			'ISURI' => 237,
			"REGEX" => 238
		},
		GOTOS => {
			'BooleanLiteral' => 271,
			'RegexExpression' => 227,
			'NumericLiteralPositive' => 115,
			'DOUBLE_POSITIVE' => 116,
			'RelationalExpression' => 273,
			'ValueLogical' => 274,
			'MultiplicativeExpression' => 275,
			'NumericLiteralNegative' => 118,
			'NumericLiteralUnsigned' => 120,
			'VAR1' => 25,
			'IRI_REF' => 28,
			'NumericLiteral' => 277,
			'IRIrefOrFunction' => 278,
			'NumericExpression' => 279,
			'ConditionalOrExpression' => 287,
			'VAR2' => 29,
			'Var' => 280,
			'INTEGER' => 104,
			'Expression' => 412,
			'BrackettedExpression' => 281,
			'INTEGER_POSITIVE' => 127,
			'PrefixedName' => 34,
			'DECIMAL_POSITIVE' => 107,
			'ConditionalAndExpression' => 289,
			'PrimaryExpression' => 282,
			'PNAME_LN' => 35,
			'BuiltInCall' => 283,
			'PNAME_NS' => 36,
			'UnaryExpression' => 284,
			'AdditiveExpression' => 290,
			'IRIref' => 285,
			'RDFLiteral' => 291
		}
	},
	{#State 408
		DEFAULT => -104
	},
	{#State 409
		ACTIONS => {
			"," => 413
		},
		DEFAULT => -211,
		GOTOS => {
			'OPTIONAL-49' => 414,
			'PAREN-48' => 415
		}
	},
	{#State 410
		DEFAULT => -200
	},
	{#State 411
		DEFAULT => -203
	},
	{#State 412
		DEFAULT => -101
	},
	{#State 413
		ACTIONS => {
			"-" => 272,
			":" => 23,
			'LANGMATCHES' => 215,
			"+" => 286,
			'DATATYPE' => 216,
			'ISIRI' => 228,
			'ISLITERAL' => 218,
			'STRING' => 119,
			'INTEGER_WS' => 96,
			'INTEGER_NEGATIVE' => 99,
			"!" => 276,
			'ISBLANK' => 232,
			'SAMETERM' => 220,
			"\$" => 27,
			'DECIMAL' => 100,
			'LANG' => 221,
			'DECIMAL_NEGATIVE' => 123,
			'STR' => 233,
			'DOUBLE' => 125,
			'URI' => 6,
			'NAME' => 31,
			'INTEGER_NO_WS' => 95,
			"TRUE" => 105,
			"?" => 32,
			"FALSE" => 126,
			'BOUND' => 235,
			'DOUBLE_NEGATIVE' => 109,
			"(" => 224,
			'ISURI' => 237,
			"REGEX" => 238
		},
		GOTOS => {
			'BooleanLiteral' => 271,
			'RegexExpression' => 227,
			'NumericLiteralPositive' => 115,
			'DOUBLE_POSITIVE' => 116,
			'RelationalExpression' => 273,
			'ValueLogical' => 274,
			'MultiplicativeExpression' => 275,
			'NumericLiteralNegative' => 118,
			'NumericLiteralUnsigned' => 120,
			'VAR1' => 25,
			'IRI_REF' => 28,
			'NumericLiteral' => 277,
			'IRIrefOrFunction' => 278,
			'NumericExpression' => 279,
			'ConditionalOrExpression' => 287,
			'VAR2' => 29,
			'Var' => 280,
			'INTEGER' => 104,
			'Expression' => 416,
			'BrackettedExpression' => 281,
			'INTEGER_POSITIVE' => 127,
			'PrefixedName' => 34,
			'DECIMAL_POSITIVE' => 107,
			'ConditionalAndExpression' => 289,
			'PrimaryExpression' => 282,
			'PNAME_LN' => 35,
			'BuiltInCall' => 283,
			'PNAME_NS' => 36,
			'UnaryExpression' => 284,
			'AdditiveExpression' => 290,
			'IRIref' => 285,
			'RDFLiteral' => 291
		}
	},
	{#State 414
		ACTIONS => {
			")" => 417
		}
	},
	{#State 415
		DEFAULT => -210
	},
	{#State 416
		DEFAULT => -209
	},
	{#State 417
		DEFAULT => -212
	}
],
                                  yyrules  =>
[
	[#Rule _SUPERSTART
		 '$start', 2, undef
#line 7124 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule Query_1
		 'Query', 2,
sub {
#line 4 "lib/RDF/Query/Parser/tSPARQL.yp"
 { method => 'SELECT', %{ $_[1] }, %{ $_[2] } } }
#line 7131 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule Query_2
		 'Query', 2,
sub {
#line 5 "lib/RDF/Query/Parser/tSPARQL.yp"
 { method => 'CONSTRUCT', %{ $_[1] }, %{ $_[2] } } }
#line 7138 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule Query_3
		 'Query', 2,
sub {
#line 6 "lib/RDF/Query/Parser/tSPARQL.yp"
 { method => 'DESCRIBE', %{ $_[1] }, %{ $_[2] } } }
#line 7145 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule Query_4
		 'Query', 2,
sub {
#line 7 "lib/RDF/Query/Parser/tSPARQL.yp"
 { method => 'ASK', %{ $_[1] }, %{ $_[2] } } }
#line 7152 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule _OPTIONAL
		 'OPTIONAL-1', 1,
sub {
#line 10 "lib/RDF/Query/Parser/tSPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_single }
#line 7159 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule _OPTIONAL
		 'OPTIONAL-1', 0,
sub {
#line 10 "lib/RDF/Query/Parser/tSPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_empty }
#line 7166 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule _STAR_LIST_2
		 'STAR-2', 2,
sub {
#line 10 "lib/RDF/Query/Parser/tSPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_TX1X2 }
#line 7173 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule _STAR_LIST_2
		 'STAR-2', 0,
sub {
#line 10 "lib/RDF/Query/Parser/tSPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_empty }
#line 7180 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule Prologue_9
		 'Prologue', 2,
sub {
#line 10 "lib/RDF/Query/Parser/tSPARQL.yp"

										my $ret	= +{
													namespaces	=> { map {%$_} @{$_[2]{children}} },
													map { %$_ } (@{$_[1]{children}})
												};
										$ret;
									}
#line 7193 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule BaseDecl_10
		 'BaseDecl', 2,
sub {
#line 18 "lib/RDF/Query/Parser/tSPARQL.yp"
 +{ 'base' => $_[2] } }
#line 7200 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule PrefixDecl_11
		 'PrefixDecl', 3,
sub {
#line 20 "lib/RDF/Query/Parser/tSPARQL.yp"
 +{ $_[2] => $_[3][1] } }
#line 7207 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule _OPTIONAL
		 'OPTIONAL-3', 1,
sub {
#line 22 "lib/RDF/Query/Parser/tSPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_single }
#line 7214 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule _OPTIONAL
		 'OPTIONAL-3', 0,
sub {
#line 22 "lib/RDF/Query/Parser/tSPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_empty }
#line 7221 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule _STAR_LIST_4
		 'STAR-4', 2,
sub {
#line 22 "lib/RDF/Query/Parser/tSPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_TX1X2 }
#line 7228 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule _STAR_LIST_4
		 'STAR-4', 0,
sub {
#line 22 "lib/RDF/Query/Parser/tSPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_empty }
#line 7235 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule SelectQuery_16
		 'SelectQuery', 6,
sub {
#line 23 "lib/RDF/Query/Parser/tSPARQL.yp"

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
#line 7277 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule SelectModifier_17
		 'SelectModifier', 1,
sub {
#line 60 "lib/RDF/Query/Parser/tSPARQL.yp"
 [ distinct => 1 ] }
#line 7284 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule SelectModifier_18
		 'SelectModifier', 1,
sub {
#line 61 "lib/RDF/Query/Parser/tSPARQL.yp"
 [ reduced => 1 ] }
#line 7291 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule _PLUS_LIST
		 'PLUS-5', 2,
sub {
#line 63 "lib/RDF/Query/Parser/tSPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_TX1X2 }
#line 7298 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule _PLUS_LIST
		 'PLUS-5', 1,
sub {
#line 63 "lib/RDF/Query/Parser/tSPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_single }
#line 7305 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule SelectVars_21
		 'SelectVars', 1,
sub {
#line 63 "lib/RDF/Query/Parser/tSPARQL.yp"
 $_[1]{children} }
#line 7312 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule SelectVars_22
		 'SelectVars', 1,
sub {
#line 64 "lib/RDF/Query/Parser/tSPARQL.yp"
 ['*'] }
#line 7319 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule _STAR_LIST_6
		 'STAR-6', 2,
sub {
#line 66 "lib/RDF/Query/Parser/tSPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_TX1X2 }
#line 7326 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule _STAR_LIST_6
		 'STAR-6', 0,
sub {
#line 66 "lib/RDF/Query/Parser/tSPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_empty }
#line 7333 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule ConstructQuery_25
		 'ConstructQuery', 5,
sub {
#line 67 "lib/RDF/Query/Parser/tSPARQL.yp"

					my $template	= $_[2];
					my $ret	= +{
						construct_triples	=> $template,
						sources				=> $_[3]{children},
						triples				=> $_[4],
					};
					
					return $ret;
				}
#line 7349 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule _STAR_LIST_7
		 'STAR-7', 2,
sub {
#line 78 "lib/RDF/Query/Parser/tSPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_TX1X2 }
#line 7356 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule _STAR_LIST_7
		 'STAR-7', 0,
sub {
#line 78 "lib/RDF/Query/Parser/tSPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_empty }
#line 7363 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule _OPTIONAL
		 'OPTIONAL-8', 1,
sub {
#line 78 "lib/RDF/Query/Parser/tSPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_single }
#line 7370 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule _OPTIONAL
		 'OPTIONAL-8', 0,
sub {
#line 78 "lib/RDF/Query/Parser/tSPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_empty }
#line 7377 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule DescribeQuery_30
		 'DescribeQuery', 5,
sub {
#line 79 "lib/RDF/Query/Parser/tSPARQL.yp"

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
#line 7396 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule _PLUS_LIST
		 'PLUS-9', 2,
sub {
#line 92 "lib/RDF/Query/Parser/tSPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_TX1X2 }
#line 7403 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule _PLUS_LIST
		 'PLUS-9', 1,
sub {
#line 92 "lib/RDF/Query/Parser/tSPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_single }
#line 7410 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule DescribeVars_33
		 'DescribeVars', 1,
sub {
#line 92 "lib/RDF/Query/Parser/tSPARQL.yp"
 $_[1]{children} }
#line 7417 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule DescribeVars_34
		 'DescribeVars', 1,
sub {
#line 93 "lib/RDF/Query/Parser/tSPARQL.yp"
 '*' }
#line 7424 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule _STAR_LIST_10
		 'STAR-10', 2,
sub {
#line 95 "lib/RDF/Query/Parser/tSPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_TX1X2 }
#line 7431 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule _STAR_LIST_10
		 'STAR-10', 0,
sub {
#line 95 "lib/RDF/Query/Parser/tSPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_empty }
#line 7438 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule AskQuery_37
		 'AskQuery', 3,
sub {
#line 96 "lib/RDF/Query/Parser/tSPARQL.yp"

		my $ret	= +{
			sources		=> $_[2]{children},
			triples		=> $_[3],
			variables	=> [],
		};
		return $ret;
	}
#line 7452 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule DatasetClause_38
		 'DatasetClause', 2,
sub {
#line 105 "lib/RDF/Query/Parser/tSPARQL.yp"
 $_[2] }
#line 7459 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule DatasetClause_39
		 'DatasetClause', 2,
sub {
#line 106 "lib/RDF/Query/Parser/tSPARQL.yp"
 $_[2] }
#line 7466 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule DefaultGraphClause_40
		 'DefaultGraphClause', 1,
sub {
#line 109 "lib/RDF/Query/Parser/tSPARQL.yp"
 $_[1] }
#line 7473 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule NamedGraphClause_41
		 'NamedGraphClause', 1,
sub {
#line 111 "lib/RDF/Query/Parser/tSPARQL.yp"
 [ @{ $_[1] }, 'NAMED' ] }
#line 7480 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule SourceSelector_42
		 'SourceSelector', 1,
sub {
#line 113 "lib/RDF/Query/Parser/tSPARQL.yp"
 $_[1] }
#line 7487 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule _OPTIONAL
		 'OPTIONAL-11', 1,
sub {
#line 115 "lib/RDF/Query/Parser/tSPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_single }
#line 7494 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule _OPTIONAL
		 'OPTIONAL-11', 0,
sub {
#line 115 "lib/RDF/Query/Parser/tSPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_empty }
#line 7501 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule WhereClause_45
		 'WhereClause', 2,
sub {
#line 115 "lib/RDF/Query/Parser/tSPARQL.yp"

																my $ggp			= $_[2];
																return $ggp;
															}
#line 7511 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule _OPTIONAL
		 'OPTIONAL-12', 1,
sub {
#line 120 "lib/RDF/Query/Parser/tSPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_single }
#line 7518 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule _OPTIONAL
		 'OPTIONAL-12', 0,
sub {
#line 120 "lib/RDF/Query/Parser/tSPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_empty }
#line 7525 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule _OPTIONAL
		 'OPTIONAL-13', 1,
sub {
#line 120 "lib/RDF/Query/Parser/tSPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_single }
#line 7532 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule _OPTIONAL
		 'OPTIONAL-13', 0,
sub {
#line 120 "lib/RDF/Query/Parser/tSPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_empty }
#line 7539 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule SolutionModifier_50
		 'SolutionModifier', 2,
sub {
#line 121 "lib/RDF/Query/Parser/tSPARQL.yp"

		return +{ orderby => $_[1]{children}[0], limitoffset => $_[2]{children}[0] };
	}
#line 7548 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule _OPTIONAL
		 'OPTIONAL-14', 1,
sub {
#line 125 "lib/RDF/Query/Parser/tSPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_single }
#line 7555 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule _OPTIONAL
		 'OPTIONAL-14', 0,
sub {
#line 125 "lib/RDF/Query/Parser/tSPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_empty }
#line 7562 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule _OPTIONAL
		 'OPTIONAL-15', 1,
sub {
#line 126 "lib/RDF/Query/Parser/tSPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_single }
#line 7569 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule _OPTIONAL
		 'OPTIONAL-15', 0,
sub {
#line 126 "lib/RDF/Query/Parser/tSPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_empty }
#line 7576 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule LimitOffsetClauses_55
		 'LimitOffsetClauses', 2,
sub {
#line 125 "lib/RDF/Query/Parser/tSPARQL.yp"
 [ @{$_[1]}, @{ $_[2]{children}[0] || [] } ] }
#line 7583 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule LimitOffsetClauses_56
		 'LimitOffsetClauses', 2,
sub {
#line 126 "lib/RDF/Query/Parser/tSPARQL.yp"
 [ @{$_[1]}, @{ $_[2]{children}[0] || [] } ] }
#line 7590 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule _PLUS_LIST
		 'PLUS-16', 2,
sub {
#line 129 "lib/RDF/Query/Parser/tSPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_TX1X2 }
#line 7597 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule _PLUS_LIST
		 'PLUS-16', 1,
sub {
#line 129 "lib/RDF/Query/Parser/tSPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_single }
#line 7604 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule OrderClause_59
		 'OrderClause', 2,
sub {
#line 130 "lib/RDF/Query/Parser/tSPARQL.yp"

		my $order	= $_[2]{children};
		return $order;
	}
#line 7614 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule OrderCondition_60
		 'OrderCondition', 2,
sub {
#line 135 "lib/RDF/Query/Parser/tSPARQL.yp"
 [ $_[1], $_[2] ] }
#line 7621 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule OrderCondition_61
		 'OrderCondition', 1,
sub {
#line 136 "lib/RDF/Query/Parser/tSPARQL.yp"
 [ 'ASC', $_[1] ] }
#line 7628 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule OrderCondition_62
		 'OrderCondition', 1,
sub {
#line 137 "lib/RDF/Query/Parser/tSPARQL.yp"
 [ 'ASC', $_[1] ] }
#line 7635 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule OrderDirection_63
		 'OrderDirection', 1,
sub {
#line 139 "lib/RDF/Query/Parser/tSPARQL.yp"
 'ASC' }
#line 7642 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule OrderDirection_64
		 'OrderDirection', 1,
sub {
#line 140 "lib/RDF/Query/Parser/tSPARQL.yp"
 'DESC' }
#line 7649 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule LimitClause_65
		 'LimitClause', 2,
sub {
#line 143 "lib/RDF/Query/Parser/tSPARQL.yp"
 [ limit => $_[2] ] }
#line 7656 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule OffsetClause_66
		 'OffsetClause', 2,
sub {
#line 145 "lib/RDF/Query/Parser/tSPARQL.yp"
 [ offset => $_[2] ] }
#line 7663 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule _OPTIONAL
		 'OPTIONAL-17', 1,
sub {
#line 147 "lib/RDF/Query/Parser/tSPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_single }
#line 7670 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule _OPTIONAL
		 'OPTIONAL-17', 0,
sub {
#line 147 "lib/RDF/Query/Parser/tSPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_empty }
#line 7677 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule _OPTIONAL
		 'OPTIONAL-18', 1,
sub {
#line 147 "lib/RDF/Query/Parser/tSPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_single }
#line 7684 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule _OPTIONAL
		 'OPTIONAL-18', 0,
sub {
#line 147 "lib/RDF/Query/Parser/tSPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_empty }
#line 7691 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule _OPTIONAL
		 'OPTIONAL-19', 1,
sub {
#line 147 "lib/RDF/Query/Parser/tSPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_single }
#line 7698 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule _OPTIONAL
		 'OPTIONAL-19', 0,
sub {
#line 147 "lib/RDF/Query/Parser/tSPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_empty }
#line 7705 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule _PAREN
		 'PAREN-20', 3,
sub {
#line 147 "lib/RDF/Query/Parser/tSPARQL.yp"
 goto &Parse::Eyapp::Driver::YYBuildAST }
#line 7712 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule _STAR_LIST_21
		 'STAR-21', 2,
sub {
#line 147 "lib/RDF/Query/Parser/tSPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_TX1X2 }
#line 7719 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule _STAR_LIST_21
		 'STAR-21', 0,
sub {
#line 147 "lib/RDF/Query/Parser/tSPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_empty }
#line 7726 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule GroupGraphPattern_76
		 'GroupGraphPattern', 4,
sub {
#line 148 "lib/RDF/Query/Parser/tSPARQL.yp"

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
#line 7803 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule GGPAtom_77
		 'GGPAtom', 1,
sub {
#line 220 "lib/RDF/Query/Parser/tSPARQL.yp"
 $_[1] }
#line 7810 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule GGPAtom_78
		 'GGPAtom', 1,
sub {
#line 221 "lib/RDF/Query/Parser/tSPARQL.yp"

																	my $self	= $_[0];
																	[ $self->new_filter($_[1]), [] ]
																}
#line 7820 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule _OPTIONAL
		 'OPTIONAL-22', 1,
sub {
#line 227 "lib/RDF/Query/Parser/tSPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_single }
#line 7827 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule _OPTIONAL
		 'OPTIONAL-22', 0,
sub {
#line 227 "lib/RDF/Query/Parser/tSPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_empty }
#line 7834 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule _PAREN
		 'PAREN-23', 2,
sub {
#line 227 "lib/RDF/Query/Parser/tSPARQL.yp"
 goto &Parse::Eyapp::Driver::YYBuildAST }
#line 7841 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule _OPTIONAL
		 'OPTIONAL-24', 1,
sub {
#line 227 "lib/RDF/Query/Parser/tSPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_single }
#line 7848 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule _OPTIONAL
		 'OPTIONAL-24', 0,
sub {
#line 227 "lib/RDF/Query/Parser/tSPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_empty }
#line 7855 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule TriplesBlock_84
		 'TriplesBlock', 2,
sub {
#line 228 "lib/RDF/Query/Parser/tSPARQL.yp"

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
#line 7875 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule GraphPatternNotTriples_85
		 'GraphPatternNotTriples', 1,
sub {
#line 245 "lib/RDF/Query/Parser/tSPARQL.yp"
 [$_[1],[]] }
#line 7882 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule GraphPatternNotTriples_86
		 'GraphPatternNotTriples', 1,
sub {
#line 246 "lib/RDF/Query/Parser/tSPARQL.yp"
 [$_[1],[]] }
#line 7889 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule GraphPatternNotTriples_87
		 'GraphPatternNotTriples', 1,
sub {
#line 247 "lib/RDF/Query/Parser/tSPARQL.yp"
 [$_[1],[]] }
#line 7896 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule GraphPatternNotTriples_88
		 'GraphPatternNotTriples', 1,
sub {
#line 249 "lib/RDF/Query/Parser/tSPARQL.yp"

			my $time	= $_[1];
			return [$time, []];
		}
#line 7906 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule TimeGraphPattern_89
		 'TimeGraphPattern', 3,
sub {
#line 256 "lib/RDF/Query/Parser/tSPARQL.yp"

		my $self				= $_[0];
		my ($node, $triples)	= @{ $_[2] };
		my $ggp					= $_[3];
		if (scalar(@$triples)) {		# we can only get triples if the GraphNode is a bNode
			my $blank	= $node->[1];
			my $var		= $self->new_variable();
			foreach my $trip (@$triples) {
				if ($trip->[0][1] eq $blank) {
					$trip->[0] = $var;
				}
			}
			$node		= $var;
			
			my @triples	= map { $self->new_triple( @$_ ) } @$triples;
			my $bgp		= RDF::Query::Algebra::BasicGraphPattern->new( @triples );
			return RDF::Query::Algebra::TimeGraph->new( $node, $ggp, $bgp );
		} else {
			return RDF::Query::Algebra::TimeGraph->new( $node, $ggp );
		}
	}
#line 7933 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule OptionalGraphPattern_90
		 'OptionalGraphPattern', 2,
sub {
#line 278 "lib/RDF/Query/Parser/tSPARQL.yp"

																	my $ggp	= $_[2];
																	return ['OPTIONAL', $ggp]
																}
#line 7943 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule GraphGraphPattern_91
		 'GraphGraphPattern', 3,
sub {
#line 283 "lib/RDF/Query/Parser/tSPARQL.yp"

																	my $self	= $_[0];
																	my $graph	= $_[2];
																	my $ggp		= $_[3];
																	return $self->new_named_graph( $graph, $ggp );
																}
#line 7955 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule _PAREN
		 'PAREN-25', 2,
sub {
#line 290 "lib/RDF/Query/Parser/tSPARQL.yp"
 goto &Parse::Eyapp::Driver::YYBuildAST }
#line 7962 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule _STAR_LIST_26
		 'STAR-26', 2,
sub {
#line 290 "lib/RDF/Query/Parser/tSPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_TX1X2 }
#line 7969 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule _STAR_LIST_26
		 'STAR-26', 0,
sub {
#line 290 "lib/RDF/Query/Parser/tSPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_empty }
#line 7976 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule GroupOrUnionGraphPattern_95
		 'GroupOrUnionGraphPattern', 2,
sub {
#line 291 "lib/RDF/Query/Parser/tSPARQL.yp"

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
#line 7996 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule Filter_96
		 'Filter', 2,
sub {
#line 306 "lib/RDF/Query/Parser/tSPARQL.yp"

#									warn 'FILTER CONSTRAINT: ' . Dumper($_[2]);
								$_[2]
							}
#line 8006 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule Constraint_97
		 'Constraint', 1,
sub {
#line 311 "lib/RDF/Query/Parser/tSPARQL.yp"
 $_[1] }
#line 8013 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule Constraint_98
		 'Constraint', 1,
sub {
#line 312 "lib/RDF/Query/Parser/tSPARQL.yp"
 $_[1] }
#line 8020 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule Constraint_99
		 'Constraint', 1,
sub {
#line 313 "lib/RDF/Query/Parser/tSPARQL.yp"
 $_[1] }
#line 8027 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule FunctionCall_100
		 'FunctionCall', 2,
sub {
#line 317 "lib/RDF/Query/Parser/tSPARQL.yp"

		$_[0]->new_function_expression( $_[1], @{ $_[2] } )
	}
#line 8036 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule _PAREN
		 'PAREN-27', 2,
sub {
#line 321 "lib/RDF/Query/Parser/tSPARQL.yp"
 goto &Parse::Eyapp::Driver::YYBuildAST }
#line 8043 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule _STAR_LIST_28
		 'STAR-28', 2,
sub {
#line 321 "lib/RDF/Query/Parser/tSPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_TX1X2 }
#line 8050 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule _STAR_LIST_28
		 'STAR-28', 0,
sub {
#line 321 "lib/RDF/Query/Parser/tSPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_empty }
#line 8057 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule ArgList_104
		 'ArgList', 4,
sub {
#line 322 "lib/RDF/Query/Parser/tSPARQL.yp"

			my $args	= [
				$_[2],
				map { $_ } @{ $_[3]{children} }
			];
			
			$args;
		}
#line 8071 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule ArgList_105
		 'ArgList', 1,
sub {
#line 330 "lib/RDF/Query/Parser/tSPARQL.yp"
 [] }
#line 8078 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule _OPTIONAL
		 'OPTIONAL-29', 1,
sub {
#line 332 "lib/RDF/Query/Parser/tSPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_single }
#line 8085 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule _OPTIONAL
		 'OPTIONAL-29', 0,
sub {
#line 332 "lib/RDF/Query/Parser/tSPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_empty }
#line 8092 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule ConstructTemplate_108
		 'ConstructTemplate', 3,
sub {
#line 333 "lib/RDF/Query/Parser/tSPARQL.yp"

	if (@{ $_[2]{children} }) {
		return $_[2]{children}[0];
	} else {
		return {};
	}
}
#line 8105 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule _OPTIONAL
		 'OPTIONAL-30', 1,
sub {
#line 341 "lib/RDF/Query/Parser/tSPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_single }
#line 8112 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule _OPTIONAL
		 'OPTIONAL-30', 0,
sub {
#line 341 "lib/RDF/Query/Parser/tSPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_empty }
#line 8119 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule _PAREN
		 'PAREN-31', 2,
sub {
#line 341 "lib/RDF/Query/Parser/tSPARQL.yp"
 goto &Parse::Eyapp::Driver::YYBuildAST }
#line 8126 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule _OPTIONAL
		 'OPTIONAL-32', 1,
sub {
#line 341 "lib/RDF/Query/Parser/tSPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_single }
#line 8133 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule _OPTIONAL
		 'OPTIONAL-32', 0,
sub {
#line 341 "lib/RDF/Query/Parser/tSPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_empty }
#line 8140 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule ConstructTriples_114
		 'ConstructTriples', 2,
sub {
#line 342 "lib/RDF/Query/Parser/tSPARQL.yp"

		my @triples	= @{ $_[1] };
		if (@{ $_[2]{children} }) {
			my $triples	= $_[2]{children}[0]{children}[0];
			push(@triples, @{ $triples || [] });
		}
		return RDF::Query::Algebra::GroupGraphPattern->new( @triples );
	}
#line 8154 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule TriplesSameSubject_115
		 'TriplesSameSubject', 2,
sub {
#line 351 "lib/RDF/Query/Parser/tSPARQL.yp"

															my $self	= $_[0];
															my ($props, $triples)	= @{ $_[2] };
															my $subj	= $_[1];
															
															my @triples;
															push(@triples, map { [ $subj, @{$_} ] } @$props);
															push(@triples, @{ $triples });
															return [map { $self->new_triple(@$_) } @triples];
														}
#line 8170 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule TriplesSameSubject_116
		 'TriplesSameSubject', 2,
sub {
#line 361 "lib/RDF/Query/Parser/tSPARQL.yp"

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
#line 8192 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule _PAREN
		 'PAREN-33', 2,
sub {
#line 379 "lib/RDF/Query/Parser/tSPARQL.yp"
 goto &Parse::Eyapp::Driver::YYBuildAST }
#line 8199 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule _OPTIONAL
		 'OPTIONAL-34', 1,
sub {
#line 379 "lib/RDF/Query/Parser/tSPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_single }
#line 8206 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule _OPTIONAL
		 'OPTIONAL-34', 0,
sub {
#line 379 "lib/RDF/Query/Parser/tSPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_empty }
#line 8213 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule _PAREN
		 'PAREN-35', 2,
sub {
#line 379 "lib/RDF/Query/Parser/tSPARQL.yp"
 goto &Parse::Eyapp::Driver::YYBuildAST }
#line 8220 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule _STAR_LIST_36
		 'STAR-36', 2,
sub {
#line 379 "lib/RDF/Query/Parser/tSPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_TX1X2 }
#line 8227 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule _STAR_LIST_36
		 'STAR-36', 0,
sub {
#line 379 "lib/RDF/Query/Parser/tSPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_empty }
#line 8234 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule PropertyListNotEmpty_123
		 'PropertyListNotEmpty', 3,
sub {
#line 380 "lib/RDF/Query/Parser/tSPARQL.yp"

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
#line 8262 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule _OPTIONAL
		 'OPTIONAL-37', 1,
sub {
#line 403 "lib/RDF/Query/Parser/tSPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_single }
#line 8269 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule _OPTIONAL
		 'OPTIONAL-37', 0,
sub {
#line 403 "lib/RDF/Query/Parser/tSPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_empty }
#line 8276 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule PropertyList_126
		 'PropertyList', 1,
sub {
#line 404 "lib/RDF/Query/Parser/tSPARQL.yp"

		if (@{ $_[1]{children} }) {
			return $_[1]{children}[0];
		} else {
			return [ [], [] ];
		}
	}
#line 8289 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule _PAREN
		 'PAREN-38', 2,
sub {
#line 412 "lib/RDF/Query/Parser/tSPARQL.yp"
 goto &Parse::Eyapp::Driver::YYBuildAST }
#line 8296 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule _STAR_LIST_39
		 'STAR-39', 2,
sub {
#line 412 "lib/RDF/Query/Parser/tSPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_TX1X2 }
#line 8303 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule _STAR_LIST_39
		 'STAR-39', 0,
sub {
#line 412 "lib/RDF/Query/Parser/tSPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_empty }
#line 8310 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule ObjectList_130
		 'ObjectList', 2,
sub {
#line 413 "lib/RDF/Query/Parser/tSPARQL.yp"

		my @objects	= ($_[1][0], map { $_->[0] } @{ $_[2]{children} });
		my @triples	= (@{ $_[1][1] }, map { @{ $_->[1] } } @{ $_[2]{children} });
		my $data	= [ \@objects, \@triples ];
		return $data;
	}
#line 8322 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule Object_131
		 'Object', 1,
sub {
#line 420 "lib/RDF/Query/Parser/tSPARQL.yp"
 $_[1] }
#line 8329 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule Verb_132
		 'Verb', 1,
sub {
#line 422 "lib/RDF/Query/Parser/tSPARQL.yp"
 $_[1] }
#line 8336 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule Verb_133
		 'Verb', 1,
sub {
#line 423 "lib/RDF/Query/Parser/tSPARQL.yp"
 $_[0]->new_uri('http://www.w3.org/1999/02/22-rdf-syntax-ns#type') }
#line 8343 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule TriplesNode_134
		 'TriplesNode', 1,
sub {
#line 426 "lib/RDF/Query/Parser/tSPARQL.yp"
 return $_[1] }
#line 8350 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule TriplesNode_135
		 'TriplesNode', 1,
sub {
#line 427 "lib/RDF/Query/Parser/tSPARQL.yp"
 return $_[1] }
#line 8357 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule BlankNodePropertyList_136
		 'BlankNodePropertyList', 3,
sub {
#line 431 "lib/RDF/Query/Parser/tSPARQL.yp"

		my $node	= $_[0]->new_blank();
		my ($props, $triples)	= @{ $_[2] };
		my @triples	= @$triples;
		
		push(@triples, map { [$node, @$_] } @$props);
		return [ $node, \@triples ];
	}
#line 8371 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule _PLUS_LIST
		 'PLUS-40', 2,
sub {
#line 440 "lib/RDF/Query/Parser/tSPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_TX1X2 }
#line 8378 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule _PLUS_LIST
		 'PLUS-40', 1,
sub {
#line 440 "lib/RDF/Query/Parser/tSPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_single }
#line 8385 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule Collection_139
		 'Collection', 3,
sub {
#line 441 "lib/RDF/Query/Parser/tSPARQL.yp"

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
#line 8420 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule GraphNode_140
		 'GraphNode', 1,
sub {
#line 471 "lib/RDF/Query/Parser/tSPARQL.yp"
 [$_[1], []] }
#line 8427 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule GraphNode_141
		 'GraphNode', 1,
sub {
#line 472 "lib/RDF/Query/Parser/tSPARQL.yp"
 $_[1] }
#line 8434 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule VarOrTerm_142
		 'VarOrTerm', 1,
sub {
#line 475 "lib/RDF/Query/Parser/tSPARQL.yp"
 $_[1] }
#line 8441 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule VarOrTerm_143
		 'VarOrTerm', 1,
sub {
#line 476 "lib/RDF/Query/Parser/tSPARQL.yp"
 $_[1] }
#line 8448 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule VarOrIRIref_144
		 'VarOrIRIref', 1,
sub {
#line 479 "lib/RDF/Query/Parser/tSPARQL.yp"
 $_[1] }
#line 8455 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule VarOrIRIref_145
		 'VarOrIRIref', 1,
sub {
#line 480 "lib/RDF/Query/Parser/tSPARQL.yp"
 $_[1] }
#line 8462 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule Var_146
		 'Var', 1,
sub {
#line 483 "lib/RDF/Query/Parser/tSPARQL.yp"
 $_[1] }
#line 8469 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule Var_147
		 'Var', 1,
sub {
#line 484 "lib/RDF/Query/Parser/tSPARQL.yp"
 $_[1] }
#line 8476 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule GraphTerm_148
		 'GraphTerm', 1,
sub {
#line 487 "lib/RDF/Query/Parser/tSPARQL.yp"
 $_[1] }
#line 8483 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule GraphTerm_149
		 'GraphTerm', 1,
sub {
#line 488 "lib/RDF/Query/Parser/tSPARQL.yp"
 $_[1] }
#line 8490 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule GraphTerm_150
		 'GraphTerm', 1,
sub {
#line 489 "lib/RDF/Query/Parser/tSPARQL.yp"
 $_[1] }
#line 8497 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule GraphTerm_151
		 'GraphTerm', 1,
sub {
#line 490 "lib/RDF/Query/Parser/tSPARQL.yp"
 $_[1] }
#line 8504 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule GraphTerm_152
		 'GraphTerm', 1,
sub {
#line 491 "lib/RDF/Query/Parser/tSPARQL.yp"
 $_[1] }
#line 8511 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule GraphTerm_153
		 'GraphTerm', 1,
sub {
#line 492 "lib/RDF/Query/Parser/tSPARQL.yp"
 $_[1] }
#line 8518 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule Expression_154
		 'Expression', 1,
sub {
#line 495 "lib/RDF/Query/Parser/tSPARQL.yp"
 $_[1] }
#line 8525 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule _PAREN
		 'PAREN-41', 2,
sub {
#line 497 "lib/RDF/Query/Parser/tSPARQL.yp"
 goto &Parse::Eyapp::Driver::YYBuildAST }
#line 8532 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule _STAR_LIST_42
		 'STAR-42', 2,
sub {
#line 497 "lib/RDF/Query/Parser/tSPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_TX1X2 }
#line 8539 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule _STAR_LIST_42
		 'STAR-42', 0,
sub {
#line 497 "lib/RDF/Query/Parser/tSPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_empty }
#line 8546 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule ConditionalOrExpression_158
		 'ConditionalOrExpression', 2,
sub {
#line 498 "lib/RDF/Query/Parser/tSPARQL.yp"

		my $expr	= $_[1];
		if (@{ $_[2]{children} }) {
			$expr	= [ '||', $expr, @{ $_[2]{children} } ];
		}
		$expr;
	}
#line 8559 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule _PAREN
		 'PAREN-43', 2,
sub {
#line 506 "lib/RDF/Query/Parser/tSPARQL.yp"
 goto &Parse::Eyapp::Driver::YYBuildAST }
#line 8566 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule _STAR_LIST_44
		 'STAR-44', 2,
sub {
#line 506 "lib/RDF/Query/Parser/tSPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_TX1X2 }
#line 8573 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule _STAR_LIST_44
		 'STAR-44', 0,
sub {
#line 506 "lib/RDF/Query/Parser/tSPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_empty }
#line 8580 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule ConditionalAndExpression_162
		 'ConditionalAndExpression', 2,
sub {
#line 507 "lib/RDF/Query/Parser/tSPARQL.yp"

		my $expr	= $_[1];
		if (@{ $_[2]{children} }) {
			$expr	= [ '&&', $expr, @{ $_[2]{children} } ];
		}
		$expr;
	}
#line 8593 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule ValueLogical_163
		 'ValueLogical', 1,
sub {
#line 515 "lib/RDF/Query/Parser/tSPARQL.yp"
 $_[1] }
#line 8600 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule _OPTIONAL
		 'OPTIONAL-45', 1,
sub {
#line 517 "lib/RDF/Query/Parser/tSPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_single }
#line 8607 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule _OPTIONAL
		 'OPTIONAL-45', 0,
sub {
#line 517 "lib/RDF/Query/Parser/tSPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_empty }
#line 8614 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule RelationalExpression_166
		 'RelationalExpression', 2,
sub {
#line 518 "lib/RDF/Query/Parser/tSPARQL.yp"

		my $expr	= $_[1];
		if (@{ $_[2]{children} }) {
			my $more	= $_[2]{children}[0];
			$expr	= [ $more->[0], $expr, $more->[1] ];
		}
		$expr;
	}
#line 8628 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule RelationalExpressionExtra_167
		 'RelationalExpressionExtra', 2,
sub {
#line 527 "lib/RDF/Query/Parser/tSPARQL.yp"
 [ '==', $_[2] ] }
#line 8635 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule RelationalExpressionExtra_168
		 'RelationalExpressionExtra', 2,
sub {
#line 528 "lib/RDF/Query/Parser/tSPARQL.yp"
 [ '!=', $_[2] ] }
#line 8642 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule RelationalExpressionExtra_169
		 'RelationalExpressionExtra', 2,
sub {
#line 529 "lib/RDF/Query/Parser/tSPARQL.yp"
 [ '<', $_[2] ] }
#line 8649 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule RelationalExpressionExtra_170
		 'RelationalExpressionExtra', 2,
sub {
#line 530 "lib/RDF/Query/Parser/tSPARQL.yp"
 [ '>', $_[2] ] }
#line 8656 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule RelationalExpressionExtra_171
		 'RelationalExpressionExtra', 2,
sub {
#line 531 "lib/RDF/Query/Parser/tSPARQL.yp"
 [ '<=', $_[2] ] }
#line 8663 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule RelationalExpressionExtra_172
		 'RelationalExpressionExtra', 2,
sub {
#line 532 "lib/RDF/Query/Parser/tSPARQL.yp"
 [ '>=', $_[2] ] }
#line 8670 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule NumericExpression_173
		 'NumericExpression', 1,
sub {
#line 535 "lib/RDF/Query/Parser/tSPARQL.yp"
 $_[1] }
#line 8677 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule _STAR_LIST_46
		 'STAR-46', 2,
sub {
#line 537 "lib/RDF/Query/Parser/tSPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_TX1X2 }
#line 8684 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule _STAR_LIST_46
		 'STAR-46', 0,
sub {
#line 537 "lib/RDF/Query/Parser/tSPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_empty }
#line 8691 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule AdditiveExpression_176
		 'AdditiveExpression', 2,
sub {
#line 538 "lib/RDF/Query/Parser/tSPARQL.yp"

		my $expr	= $_[1];
		foreach my $extra (@{ $_[2]{children} }) {
			$expr	= [ $extra->[0], $expr, $extra->[1] ];
		}
		return $expr
	}
#line 8704 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule AdditiveExpressionExtra_177
		 'AdditiveExpressionExtra', 2,
sub {
#line 546 "lib/RDF/Query/Parser/tSPARQL.yp"
 ['+',$_[2]] }
#line 8711 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule AdditiveExpressionExtra_178
		 'AdditiveExpressionExtra', 2,
sub {
#line 547 "lib/RDF/Query/Parser/tSPARQL.yp"
 ['-',$_[2]] }
#line 8718 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule AdditiveExpressionExtra_179
		 'AdditiveExpressionExtra', 1,
sub {
#line 548 "lib/RDF/Query/Parser/tSPARQL.yp"
 $_[1] }
#line 8725 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule AdditiveExpressionExtra_180
		 'AdditiveExpressionExtra', 1,
sub {
#line 549 "lib/RDF/Query/Parser/tSPARQL.yp"
 $_[1] }
#line 8732 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule _STAR_LIST_47
		 'STAR-47', 2,
sub {
#line 552 "lib/RDF/Query/Parser/tSPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_TX1X2 }
#line 8739 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule _STAR_LIST_47
		 'STAR-47', 0,
sub {
#line 552 "lib/RDF/Query/Parser/tSPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_empty }
#line 8746 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule MultiplicativeExpression_183
		 'MultiplicativeExpression', 2,
sub {
#line 553 "lib/RDF/Query/Parser/tSPARQL.yp"

		my $expr	= $_[1];
		foreach my $extra (@{ $_[2]{children} }) {
			 $expr	= [ $extra->[0], $expr, $extra->[1] ];
		}
		$expr
}
#line 8759 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule MultiplicativeExpressionExtra_184
		 'MultiplicativeExpressionExtra', 2,
sub {
#line 560 "lib/RDF/Query/Parser/tSPARQL.yp"
 [ '*', $_[2] ] }
#line 8766 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule MultiplicativeExpressionExtra_185
		 'MultiplicativeExpressionExtra', 2,
sub {
#line 561 "lib/RDF/Query/Parser/tSPARQL.yp"
 [ '/', $_[2] ] }
#line 8773 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule UnaryExpression_186
		 'UnaryExpression', 2,
sub {
#line 563 "lib/RDF/Query/Parser/tSPARQL.yp"
 ['!', $_[2]] }
#line 8780 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule UnaryExpression_187
		 'UnaryExpression', 2,
sub {
#line 564 "lib/RDF/Query/Parser/tSPARQL.yp"
 $_[2] }
#line 8787 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule UnaryExpression_188
		 'UnaryExpression', 2,
sub {
#line 565 "lib/RDF/Query/Parser/tSPARQL.yp"
 ['-', $_[2]] }
#line 8794 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule UnaryExpression_189
		 'UnaryExpression', 1,
sub {
#line 566 "lib/RDF/Query/Parser/tSPARQL.yp"
 $_[1] }
#line 8801 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule PrimaryExpression_190
		 'PrimaryExpression', 1,
sub {
#line 569 "lib/RDF/Query/Parser/tSPARQL.yp"
 $_[1] }
#line 8808 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule PrimaryExpression_191
		 'PrimaryExpression', 1,
sub {
#line 570 "lib/RDF/Query/Parser/tSPARQL.yp"
 $_[1] }
#line 8815 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule PrimaryExpression_192
		 'PrimaryExpression', 1,
sub {
#line 571 "lib/RDF/Query/Parser/tSPARQL.yp"
 $_[1] }
#line 8822 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule PrimaryExpression_193
		 'PrimaryExpression', 1,
sub {
#line 572 "lib/RDF/Query/Parser/tSPARQL.yp"
 $_[1] }
#line 8829 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule PrimaryExpression_194
		 'PrimaryExpression', 1,
sub {
#line 573 "lib/RDF/Query/Parser/tSPARQL.yp"
 $_[1] }
#line 8836 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule PrimaryExpression_195
		 'PrimaryExpression', 1,
sub {
#line 574 "lib/RDF/Query/Parser/tSPARQL.yp"
 $_[1] }
#line 8843 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule PrimaryExpression_196
		 'PrimaryExpression', 1,
sub {
#line 575 "lib/RDF/Query/Parser/tSPARQL.yp"
 $_[1] }
#line 8850 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule BrackettedExpression_197
		 'BrackettedExpression', 3,
sub {
#line 578 "lib/RDF/Query/Parser/tSPARQL.yp"
 $_[2] }
#line 8857 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule BuiltInCall_198
		 'BuiltInCall', 4,
sub {
#line 580 "lib/RDF/Query/Parser/tSPARQL.yp"
 $_[0]->new_function_expression( $_[0]->new_uri('sop:str'), $_[3] ) }
#line 8864 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule BuiltInCall_199
		 'BuiltInCall', 4,
sub {
#line 581 "lib/RDF/Query/Parser/tSPARQL.yp"
 $_[0]->new_function_expression( $_[0]->new_uri('sparql:lang'), $_[3] ) }
#line 8871 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule BuiltInCall_200
		 'BuiltInCall', 6,
sub {
#line 582 "lib/RDF/Query/Parser/tSPARQL.yp"
 $_[0]->new_function_expression( $_[0]->new_uri('sparql:langmatches'), $_[3], $_[5] ) }
#line 8878 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule BuiltInCall_201
		 'BuiltInCall', 4,
sub {
#line 583 "lib/RDF/Query/Parser/tSPARQL.yp"
 $_[0]->new_function_expression( $_[0]->new_uri('sparql:datatype'), $_[3] ) }
#line 8885 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule BuiltInCall_202
		 'BuiltInCall', 4,
sub {
#line 584 "lib/RDF/Query/Parser/tSPARQL.yp"
 $_[0]->new_function_expression( $_[0]->new_uri('sop:isBound'), $_[3] ) }
#line 8892 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule BuiltInCall_203
		 'BuiltInCall', 6,
sub {
#line 585 "lib/RDF/Query/Parser/tSPARQL.yp"
 $_[0]->new_function_expression( $_[0]->new_uri('sparql:sameTerm'), $_[3], $_[5] ) }
#line 8899 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule BuiltInCall_204
		 'BuiltInCall', 4,
sub {
#line 586 "lib/RDF/Query/Parser/tSPARQL.yp"
 $_[0]->new_function_expression( $_[0]->new_uri('sop:isIRI'), $_[3] ) }
#line 8906 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule BuiltInCall_205
		 'BuiltInCall', 4,
sub {
#line 587 "lib/RDF/Query/Parser/tSPARQL.yp"
 $_[0]->new_function_expression( $_[0]->new_uri('sop:isURI'), $_[3] ) }
#line 8913 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule BuiltInCall_206
		 'BuiltInCall', 4,
sub {
#line 588 "lib/RDF/Query/Parser/tSPARQL.yp"
 $_[0]->new_function_expression( $_[0]->new_uri('sop:isBlank'), $_[3] ) }
#line 8920 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule BuiltInCall_207
		 'BuiltInCall', 4,
sub {
#line 589 "lib/RDF/Query/Parser/tSPARQL.yp"
 $_[0]->new_function_expression( $_[0]->new_uri('sop:isLiteral'), $_[3] ) }
#line 8927 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule BuiltInCall_208
		 'BuiltInCall', 1,
sub {
#line 590 "lib/RDF/Query/Parser/tSPARQL.yp"
 $_[1] }
#line 8934 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule _PAREN
		 'PAREN-48', 2,
sub {
#line 593 "lib/RDF/Query/Parser/tSPARQL.yp"
 goto &Parse::Eyapp::Driver::YYBuildAST }
#line 8941 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule _OPTIONAL
		 'OPTIONAL-49', 1,
sub {
#line 593 "lib/RDF/Query/Parser/tSPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_single }
#line 8948 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule _OPTIONAL
		 'OPTIONAL-49', 0,
sub {
#line 593 "lib/RDF/Query/Parser/tSPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_empty }
#line 8955 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule RegexExpression_212
		 'RegexExpression', 7,
sub {
#line 594 "lib/RDF/Query/Parser/tSPARQL.yp"

		my @data	= ('~~', $_[3], $_[5]);
		if (scalar(@{ $_[6]->{children} })) {
			push(@data, $_[6]->{children}[0]);
		}
		return \@data;
	}
#line 8968 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule _OPTIONAL
		 'OPTIONAL-50', 1,
sub {
#line 602 "lib/RDF/Query/Parser/tSPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_single }
#line 8975 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule _OPTIONAL
		 'OPTIONAL-50', 0,
sub {
#line 602 "lib/RDF/Query/Parser/tSPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_empty }
#line 8982 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule IRIrefOrFunction_215
		 'IRIrefOrFunction', 2,
sub {
#line 603 "lib/RDF/Query/Parser/tSPARQL.yp"

		my $self	= $_[0];
		my $uri		= $_[1];
		my $args	= $_[2]{children}[0];
		
		if (defined($args)) {
			return $self->new_function_expression( $uri, @$args )
		} else {
			return $uri;
		}
	}
#line 8999 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule _OPTIONAL
		 'OPTIONAL-51', 1,
sub {
#line 615 "lib/RDF/Query/Parser/tSPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_single }
#line 9006 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule _OPTIONAL
		 'OPTIONAL-51', 0,
sub {
#line 615 "lib/RDF/Query/Parser/tSPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_empty }
#line 9013 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule RDFLiteral_218
		 'RDFLiteral', 2,
sub {
#line 615 "lib/RDF/Query/Parser/tSPARQL.yp"

											my $self	= $_[0];
											my %extra	= @{ $_[2]{children}[0] || [] };
											my $dt		= $extra{datatype};
											my $lang	= $extra{lang};
											if ($dt) {
												$dt		= $dt->uri_value;
											}
											$self->new_literal( $_[1], $lang, $dt );
										}
#line 9029 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule LiteralExtra_219
		 'LiteralExtra', 1,
sub {
#line 626 "lib/RDF/Query/Parser/tSPARQL.yp"
 [ lang => $_[1] ] }
#line 9036 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule LiteralExtra_220
		 'LiteralExtra', 2,
sub {
#line 627 "lib/RDF/Query/Parser/tSPARQL.yp"
 [ datatype => $_[2] ] }
#line 9043 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule NumericLiteral_221
		 'NumericLiteral', 1,
sub {
#line 630 "lib/RDF/Query/Parser/tSPARQL.yp"
 my $self = $_[0]; my ($value, $type) = @{$_[1]}; $self->new_literal( $value, undef, $type ) }
#line 9050 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule NumericLiteral_222
		 'NumericLiteral', 1,
sub {
#line 631 "lib/RDF/Query/Parser/tSPARQL.yp"
 my $self = $_[0]; my ($value, $type) = @{$_[1]}; $self->new_literal( $value, undef, $type ) }
#line 9057 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule NumericLiteral_223
		 'NumericLiteral', 1,
sub {
#line 632 "lib/RDF/Query/Parser/tSPARQL.yp"
 my $self = $_[0]; my ($value, $type) = @{$_[1]}; $self->new_literal( $value, undef, $type ) }
#line 9064 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule NumericLiteralUnsigned_224
		 'NumericLiteralUnsigned', 1,
sub {
#line 635 "lib/RDF/Query/Parser/tSPARQL.yp"
 [$_[1], 'http://www.w3.org/2001/XMLSchema#integer'] }
#line 9071 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule NumericLiteralUnsigned_225
		 'NumericLiteralUnsigned', 1,
sub {
#line 636 "lib/RDF/Query/Parser/tSPARQL.yp"
 [$_[1], 'http://www.w3.org/2001/XMLSchema#decimal'] }
#line 9078 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule NumericLiteralUnsigned_226
		 'NumericLiteralUnsigned', 1,
sub {
#line 637 "lib/RDF/Query/Parser/tSPARQL.yp"
 [$_[1], 'http://www.w3.org/2001/XMLSchema#double'] }
#line 9085 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule NumericLiteralPositive_227
		 'NumericLiteralPositive', 1,
sub {
#line 641 "lib/RDF/Query/Parser/tSPARQL.yp"
 [$_[1], 'http://www.w3.org/2001/XMLSchema#integer'] }
#line 9092 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule NumericLiteralPositive_228
		 'NumericLiteralPositive', 1,
sub {
#line 642 "lib/RDF/Query/Parser/tSPARQL.yp"
 [$_[1], 'http://www.w3.org/2001/XMLSchema#decimal'] }
#line 9099 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule NumericLiteralPositive_229
		 'NumericLiteralPositive', 1,
sub {
#line 643 "lib/RDF/Query/Parser/tSPARQL.yp"
 [$_[1], 'http://www.w3.org/2001/XMLSchema#double'] }
#line 9106 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule NumericLiteralNegative_230
		 'NumericLiteralNegative', 1,
sub {
#line 647 "lib/RDF/Query/Parser/tSPARQL.yp"
 [$_[1], 'http://www.w3.org/2001/XMLSchema#integer'] }
#line 9113 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule NumericLiteralNegative_231
		 'NumericLiteralNegative', 1,
sub {
#line 648 "lib/RDF/Query/Parser/tSPARQL.yp"
 [$_[1], 'http://www.w3.org/2001/XMLSchema#decimal'] }
#line 9120 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule NumericLiteralNegative_232
		 'NumericLiteralNegative', 1,
sub {
#line 649 "lib/RDF/Query/Parser/tSPARQL.yp"
 [$_[1], 'http://www.w3.org/2001/XMLSchema#double'] }
#line 9127 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule BooleanLiteral_233
		 'BooleanLiteral', 1,
sub {
#line 652 "lib/RDF/Query/Parser/tSPARQL.yp"
 $_[0]->new_literal( 'true', undef, 'http://www.w3.org/2001/XMLSchema#boolean' ) }
#line 9134 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule BooleanLiteral_234
		 'BooleanLiteral', 1,
sub {
#line 653 "lib/RDF/Query/Parser/tSPARQL.yp"
 $_[0]->new_literal( 'false', undef, 'http://www.w3.org/2001/XMLSchema#boolean' ) }
#line 9141 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule IRIref_235
		 'IRIref', 1,
sub {
#line 658 "lib/RDF/Query/Parser/tSPARQL.yp"
 $_[1] }
#line 9148 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule IRIref_236
		 'IRIref', 1,
sub {
#line 659 "lib/RDF/Query/Parser/tSPARQL.yp"
 $_[1] }
#line 9155 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule PrefixedName_237
		 'PrefixedName', 1,
sub {
#line 662 "lib/RDF/Query/Parser/tSPARQL.yp"
 $_[1] }
#line 9162 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule PrefixedName_238
		 'PrefixedName', 1,
sub {
#line 663 "lib/RDF/Query/Parser/tSPARQL.yp"
 $_[0]->new_uri([$_[1],'']) }
#line 9169 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule BlankNode_239
		 'BlankNode', 1,
sub {
#line 666 "lib/RDF/Query/Parser/tSPARQL.yp"
 $_[1] }
#line 9176 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule BlankNode_240
		 'BlankNode', 1,
sub {
#line 667 "lib/RDF/Query/Parser/tSPARQL.yp"
 $_[1] }
#line 9183 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule IRI_REF_241
		 'IRI_REF', 1,
sub {
#line 670 "lib/RDF/Query/Parser/tSPARQL.yp"
 $_[0]->new_uri($_[1]) }
#line 9190 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule PNAME_NS_242
		 'PNAME_NS', 2,
sub {
#line 674 "lib/RDF/Query/Parser/tSPARQL.yp"

			return $_[1];
		}
#line 9199 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule PNAME_NS_243
		 'PNAME_NS', 1,
sub {
#line 678 "lib/RDF/Query/Parser/tSPARQL.yp"

			return '__DEFAULT__';
		}
#line 9208 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule PNAME_LN_244
		 'PNAME_LN', 2,
sub {
#line 683 "lib/RDF/Query/Parser/tSPARQL.yp"

	return $_[0]->new_uri([$_[1], $_[2]]);
}
#line 9217 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule BLANK_NODE_LABEL_245
		 'BLANK_NODE_LABEL', 2,
sub {
#line 687 "lib/RDF/Query/Parser/tSPARQL.yp"

											my $self	= $_[0];
											my $name	= $_[2];
#											$self->register_blank_node( $name );
											return $self->new_blank( $name );
										}
#line 9229 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule PN_LOCAL_246
		 'PN_LOCAL', 2,
sub {
#line 695 "lib/RDF/Query/Parser/tSPARQL.yp"

			my $name	= $_[1];
			my $extra	= $_[2];
			return join('',$name,$extra);
		}
#line 9240 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule PN_LOCAL_247
		 'PN_LOCAL', 3,
sub {
#line 700 "lib/RDF/Query/Parser/tSPARQL.yp"

			my $int		= $_[1];
			my $name	= $_[2];
			my $extra	= $_[3];
			return join('',$int,$name,$extra);
		}
#line 9252 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule PN_LOCAL_248
		 'PN_LOCAL', 2,
sub {
#line 706 "lib/RDF/Query/Parser/tSPARQL.yp"

			my $int		= $_[1];
			my $name	= $_[2];
			return join('',$int,$name);
		}
#line 9263 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule PN_LOCAL_249
		 'PN_LOCAL', 1,
sub {
#line 711 "lib/RDF/Query/Parser/tSPARQL.yp"
 $_[1] }
#line 9270 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule PN_LOCAL_EXTRA_250
		 'PN_LOCAL_EXTRA', 1,
sub {
#line 714 "lib/RDF/Query/Parser/tSPARQL.yp"
 return $_[1] }
#line 9277 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule PN_LOCAL_EXTRA_251
		 'PN_LOCAL_EXTRA', 2,
sub {
#line 715 "lib/RDF/Query/Parser/tSPARQL.yp"
 return "-$_[2]" }
#line 9284 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule PN_LOCAL_EXTRA_252
		 'PN_LOCAL_EXTRA', 2,
sub {
#line 716 "lib/RDF/Query/Parser/tSPARQL.yp"
 return "_$_[2]" }
#line 9291 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule VAR1_253
		 'VAR1', 2,
sub {
#line 719 "lib/RDF/Query/Parser/tSPARQL.yp"
 my $self	= $_[0]; return $self->new_variable($_[2]) }
#line 9298 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule VAR2_254
		 'VAR2', 2,
sub {
#line 721 "lib/RDF/Query/Parser/tSPARQL.yp"
 my $self	= $_[0]; return $self->new_variable($_[2]) }
#line 9305 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule _PLUS_LIST
		 'PLUS-52', 2,
sub {
#line 723 "lib/RDF/Query/Parser/tSPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_TX1X2 }
#line 9312 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule _PLUS_LIST
		 'PLUS-52', 1,
sub {
#line 723 "lib/RDF/Query/Parser/tSPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_single }
#line 9319 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule _PAREN
		 'PAREN-53', 2,
sub {
#line 723 "lib/RDF/Query/Parser/tSPARQL.yp"
 goto &Parse::Eyapp::Driver::YYBuildAST }
#line 9326 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule _STAR_LIST_54
		 'STAR-54', 2,
sub {
#line 723 "lib/RDF/Query/Parser/tSPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_TX1X2 }
#line 9333 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule _STAR_LIST_54
		 'STAR-54', 0,
sub {
#line 723 "lib/RDF/Query/Parser/tSPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_empty }
#line 9340 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule LANGTAG_260
		 'LANGTAG', 3,
sub {
#line 723 "lib/RDF/Query/Parser/tSPARQL.yp"
 join('-', $_[2], map { $_->{children}[0]{attr} } @{ $_[3]{children} }) }
#line 9347 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule INTEGER_POSITIVE_261
		 'INTEGER_POSITIVE', 2,
sub {
#line 727 "lib/RDF/Query/Parser/tSPARQL.yp"
 '+' . $_[2] }
#line 9354 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule DOUBLE_POSITIVE_262
		 'DOUBLE_POSITIVE', 2,
sub {
#line 728 "lib/RDF/Query/Parser/tSPARQL.yp"
 '+' . $_[2] }
#line 9361 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule DECIMAL_POSITIVE_263
		 'DECIMAL_POSITIVE', 2,
sub {
#line 729 "lib/RDF/Query/Parser/tSPARQL.yp"
 '+' . $_[2] }
#line 9368 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule VARNAME_264
		 'VARNAME', 1,
sub {
#line 734 "lib/RDF/Query/Parser/tSPARQL.yp"
 $_[1] }
#line 9375 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule VARNAME_265
		 'VARNAME', 1,
sub {
#line 735 "lib/RDF/Query/Parser/tSPARQL.yp"
 $_[1] }
#line 9382 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule VARNAME_266
		 'VARNAME', 1,
sub {
#line 736 "lib/RDF/Query/Parser/tSPARQL.yp"
 $_[1] }
#line 9389 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule VARNAME_267
		 'VARNAME', 1,
sub {
#line 737 "lib/RDF/Query/Parser/tSPARQL.yp"
 $_[1] }
#line 9396 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule VARNAME_268
		 'VARNAME', 1,
sub {
#line 738 "lib/RDF/Query/Parser/tSPARQL.yp"
 $_[1] }
#line 9403 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule VARNAME_269
		 'VARNAME', 1,
sub {
#line 739 "lib/RDF/Query/Parser/tSPARQL.yp"
 $_[1] }
#line 9410 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule VARNAME_270
		 'VARNAME', 1,
sub {
#line 740 "lib/RDF/Query/Parser/tSPARQL.yp"
 $_[1] }
#line 9417 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule VARNAME_271
		 'VARNAME', 1,
sub {
#line 741 "lib/RDF/Query/Parser/tSPARQL.yp"
 $_[1] }
#line 9424 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule VARNAME_272
		 'VARNAME', 1,
sub {
#line 742 "lib/RDF/Query/Parser/tSPARQL.yp"
 $_[1] }
#line 9431 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule VARNAME_273
		 'VARNAME', 1,
sub {
#line 743 "lib/RDF/Query/Parser/tSPARQL.yp"
 $_[1] }
#line 9438 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule VARNAME_274
		 'VARNAME', 1,
sub {
#line 744 "lib/RDF/Query/Parser/tSPARQL.yp"
 $_[1] }
#line 9445 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule VARNAME_275
		 'VARNAME', 1,
sub {
#line 745 "lib/RDF/Query/Parser/tSPARQL.yp"
 $_[1] }
#line 9452 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule VARNAME_276
		 'VARNAME', 1,
sub {
#line 746 "lib/RDF/Query/Parser/tSPARQL.yp"
 $_[1] }
#line 9459 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule VARNAME_277
		 'VARNAME', 1,
sub {
#line 747 "lib/RDF/Query/Parser/tSPARQL.yp"
 $_[1] }
#line 9466 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule VARNAME_278
		 'VARNAME', 1,
sub {
#line 748 "lib/RDF/Query/Parser/tSPARQL.yp"
 $_[1] }
#line 9473 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule VARNAME_279
		 'VARNAME', 1,
sub {
#line 749 "lib/RDF/Query/Parser/tSPARQL.yp"
 $_[1] }
#line 9480 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule VARNAME_280
		 'VARNAME', 1,
sub {
#line 750 "lib/RDF/Query/Parser/tSPARQL.yp"
 $_[1] }
#line 9487 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule VARNAME_281
		 'VARNAME', 1,
sub {
#line 751 "lib/RDF/Query/Parser/tSPARQL.yp"
 $_[1] }
#line 9494 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule VARNAME_282
		 'VARNAME', 1,
sub {
#line 752 "lib/RDF/Query/Parser/tSPARQL.yp"
 $_[1] }
#line 9501 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule VARNAME_283
		 'VARNAME', 1,
sub {
#line 753 "lib/RDF/Query/Parser/tSPARQL.yp"
 $_[1] }
#line 9508 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule VARNAME_284
		 'VARNAME', 1,
sub {
#line 754 "lib/RDF/Query/Parser/tSPARQL.yp"
 $_[1] }
#line 9515 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule VARNAME_285
		 'VARNAME', 1,
sub {
#line 755 "lib/RDF/Query/Parser/tSPARQL.yp"
 $_[1] }
#line 9522 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule VARNAME_286
		 'VARNAME', 1,
sub {
#line 756 "lib/RDF/Query/Parser/tSPARQL.yp"
 $_[1] }
#line 9529 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule VARNAME_287
		 'VARNAME', 1,
sub {
#line 757 "lib/RDF/Query/Parser/tSPARQL.yp"
 $_[1] }
#line 9536 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule VARNAME_288
		 'VARNAME', 1,
sub {
#line 758 "lib/RDF/Query/Parser/tSPARQL.yp"
 $_[1] }
#line 9543 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule VARNAME_289
		 'VARNAME', 1,
sub {
#line 759 "lib/RDF/Query/Parser/tSPARQL.yp"
 $_[1] }
#line 9550 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule VARNAME_290
		 'VARNAME', 1,
sub {
#line 760 "lib/RDF/Query/Parser/tSPARQL.yp"
 $_[1] }
#line 9557 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule VARNAME_291
		 'VARNAME', 1,
sub {
#line 761 "lib/RDF/Query/Parser/tSPARQL.yp"
 $_[1] }
#line 9564 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule VARNAME_292
		 'VARNAME', 1,
sub {
#line 762 "lib/RDF/Query/Parser/tSPARQL.yp"
 $_[1] }
#line 9571 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule VARNAME_293
		 'VARNAME', 1,
sub {
#line 763 "lib/RDF/Query/Parser/tSPARQL.yp"
 $_[1] }
#line 9578 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule VARNAME_294
		 'VARNAME', 1,
sub {
#line 764 "lib/RDF/Query/Parser/tSPARQL.yp"
 $_[1] }
#line 9585 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule VARNAME_295
		 'VARNAME', 1,
sub {
#line 765 "lib/RDF/Query/Parser/tSPARQL.yp"
 $_[1] }
#line 9592 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule VARNAME_296
		 'VARNAME', 1,
sub {
#line 766 "lib/RDF/Query/Parser/tSPARQL.yp"
 $_[1] }
#line 9599 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule VARNAME_297
		 'VARNAME', 1,
sub {
#line 767 "lib/RDF/Query/Parser/tSPARQL.yp"
 $_[1] }
#line 9606 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule VARNAME_298
		 'VARNAME', 1,
sub {
#line 768 "lib/RDF/Query/Parser/tSPARQL.yp"
 $_[1] }
#line 9613 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule _STAR_LIST_55
		 'STAR-55', 2,
sub {
#line 771 "lib/RDF/Query/Parser/tSPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_TX1X2 }
#line 9620 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule _STAR_LIST_55
		 'STAR-55', 0,
sub {
#line 771 "lib/RDF/Query/Parser/tSPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_empty }
#line 9627 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule NIL_301
		 'NIL', 3,
sub {
#line 771 "lib/RDF/Query/Parser/tSPARQL.yp"
 $_[0]->new_uri('http://www.w3.org/1999/02/22-rdf-syntax-ns#nil') }
#line 9634 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule _STAR_LIST_56
		 'STAR-56', 2,
sub {
#line 773 "lib/RDF/Query/Parser/tSPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_TX1X2 }
#line 9641 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule _STAR_LIST_56
		 'STAR-56', 0,
sub {
#line 773 "lib/RDF/Query/Parser/tSPARQL.yp"
 goto &Parse::Eyapp::Driver::YYActionforT_empty }
#line 9648 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule ANON_304
		 'ANON', 3,
sub {
#line 773 "lib/RDF/Query/Parser/tSPARQL.yp"
 $_[0]->new_blank() }
#line 9655 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule INTEGER_305
		 'INTEGER', 1,
sub {
#line 777 "lib/RDF/Query/Parser/tSPARQL.yp"
 $_[1] }
#line 9662 lib/RDF/Query/Parser/tSPARQL.pm
	],
	[#Rule INTEGER_306
		 'INTEGER', 1,
sub {
#line 778 "lib/RDF/Query/Parser/tSPARQL.yp"
 $_[1] }
#line 9669 lib/RDF/Query/Parser/tSPARQL.pm
	]
],
#line 9672 lib/RDF/Query/Parser/tSPARQL.pm
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
         GraphPatternNotTriples_88
         TimeGraphPattern_89
         OptionalGraphPattern_90
         GraphGraphPattern_91
         _STAR_LIST_26
         GroupOrUnionGraphPattern_95
         Filter_96
         Constraint_97
         Constraint_98
         Constraint_99
         FunctionCall_100
         _STAR_LIST_28
         ArgList_104
         ArgList_105
         ConstructTemplate_108
         ConstructTriples_114
         TriplesSameSubject_115
         TriplesSameSubject_116
         _STAR_LIST_36
         PropertyListNotEmpty_123
         PropertyList_126
         _STAR_LIST_39
         ObjectList_130
         Object_131
         Verb_132
         Verb_133
         TriplesNode_134
         TriplesNode_135
         BlankNodePropertyList_136
         Collection_139
         GraphNode_140
         GraphNode_141
         VarOrTerm_142
         VarOrTerm_143
         VarOrIRIref_144
         VarOrIRIref_145
         Var_146
         Var_147
         GraphTerm_148
         GraphTerm_149
         GraphTerm_150
         GraphTerm_151
         GraphTerm_152
         GraphTerm_153
         Expression_154
         _STAR_LIST_42
         ConditionalOrExpression_158
         _STAR_LIST_44
         ConditionalAndExpression_162
         ValueLogical_163
         RelationalExpression_166
         RelationalExpressionExtra_167
         RelationalExpressionExtra_168
         RelationalExpressionExtra_169
         RelationalExpressionExtra_170
         RelationalExpressionExtra_171
         RelationalExpressionExtra_172
         NumericExpression_173
         _STAR_LIST_46
         AdditiveExpression_176
         AdditiveExpressionExtra_177
         AdditiveExpressionExtra_178
         AdditiveExpressionExtra_179
         AdditiveExpressionExtra_180
         _STAR_LIST_47
         MultiplicativeExpression_183
         MultiplicativeExpressionExtra_184
         MultiplicativeExpressionExtra_185
         UnaryExpression_186
         UnaryExpression_187
         UnaryExpression_188
         UnaryExpression_189
         PrimaryExpression_190
         PrimaryExpression_191
         PrimaryExpression_192
         PrimaryExpression_193
         PrimaryExpression_194
         PrimaryExpression_195
         PrimaryExpression_196
         BrackettedExpression_197
         BuiltInCall_198
         BuiltInCall_199
         BuiltInCall_200
         BuiltInCall_201
         BuiltInCall_202
         BuiltInCall_203
         BuiltInCall_204
         BuiltInCall_205
         BuiltInCall_206
         BuiltInCall_207
         BuiltInCall_208
         RegexExpression_212
         IRIrefOrFunction_215
         RDFLiteral_218
         LiteralExtra_219
         LiteralExtra_220
         NumericLiteral_221
         NumericLiteral_222
         NumericLiteral_223
         NumericLiteralUnsigned_224
         NumericLiteralUnsigned_225
         NumericLiteralUnsigned_226
         NumericLiteralPositive_227
         NumericLiteralPositive_228
         NumericLiteralPositive_229
         NumericLiteralNegative_230
         NumericLiteralNegative_231
         NumericLiteralNegative_232
         BooleanLiteral_233
         BooleanLiteral_234
         IRIref_235
         IRIref_236
         PrefixedName_237
         PrefixedName_238
         BlankNode_239
         BlankNode_240
         IRI_REF_241
         PNAME_NS_242
         PNAME_NS_243
         PNAME_LN_244
         BLANK_NODE_LABEL_245
         PN_LOCAL_246
         PN_LOCAL_247
         PN_LOCAL_248
         PN_LOCAL_249
         PN_LOCAL_EXTRA_250
         PN_LOCAL_EXTRA_251
         PN_LOCAL_EXTRA_252
         VAR1_253
         VAR2_254
         _STAR_LIST_54
         LANGTAG_260
         INTEGER_POSITIVE_261
         DOUBLE_POSITIVE_262
         DECIMAL_POSITIVE_263
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
         VARNAME_296
         VARNAME_297
         VARNAME_298
         _STAR_LIST_55
         NIL_301
         _STAR_LIST_56
         ANON_304
         INTEGER_305
         INTEGER_306} );
    $self;
}

#line 791 "lib/RDF/Query/Parser/tSPARQL.yp"


# RDF::Query::Parser::tSPARQL
# -------------
# $Revision: 194 $
# $Date: 2007-04-18 22:26:36 -0400 (Wed, 18 Apr 2007) $
# -----------------------------------------------------------------------------

=head1 NAME

RDF::Query::Parser::tSPARQL - A temporal-extended SPARQL parser for RDF::Query

=cut

package RDF::Query::Parser::tSPARQL;

use strict;
use warnings;
no warnings 'ambiguous';
no warnings 'redefine';
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
	$lang		= 'tsparql';
	$languri	= '--';
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
			|	TIME\b
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
		
		
		m{\G<([^<>"{}|^`\\\x{00}-\x{20}]*)>}gc and return('URI',$parser->__new_value( $1, $ws ));
		
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


#line 10238 lib/RDF/Query/Parser/tSPARQL.pm

1;
