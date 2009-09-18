#define PERL_constant_NOTFOUND	1
#define PERL_constant_NOTDEF	2
#define PERL_constant_ISIV	3
#define PERL_constant_ISNO	4
#define PERL_constant_ISNV	5
#define PERL_constant_ISPV	6
#define PERL_constant_ISPVN	7
#define PERL_constant_ISSV	8
#define PERL_constant_ISUNDEF	9
#define PERL_constant_ISUV	10
#define PERL_constant_ISYES	11

#ifndef NVTYPE
typedef double NV; /* 5.6 and later define NVTYPE, and typedef NV to it.  */
#endif
#ifndef aTHX_
#define aTHX_ /* 5.6 or later define this for threading support.  */
#endif
#ifndef pTHX_
#define pTHX_ /* 5.6 or later define this for threading support.  */
#endif

static int
constant_22 (pTHX_ const char *name, IV *iv_return) {
  /* When generated this function returned values for the list of names given
     here.  However, subsequent manual editing may have added or removed some.
     RDF_ITER_FLAGS_BOUND_A RDF_ITER_FLAGS_BOUND_B RDF_ITER_FLAGS_BOUND_C */
  /* Offset 21 gives the best switch position.  */
  switch (name[21]) {
  case 'A':
    if (memEQ(name, "RDF_ITER_FLAGS_BOUND_", 21)) {
    /*                                    A      */
      *iv_return = RDF_ITER_FLAGS_BOUND_A;
      return PERL_constant_ISIV;
    }
    break;
  case 'B':
    if (memEQ(name, "RDF_ITER_FLAGS_BOUND_", 21)) {
    /*                                    B      */
      *iv_return = RDF_ITER_FLAGS_BOUND_B;
      return PERL_constant_ISIV;
    }
    break;
  case 'C':
    if (memEQ(name, "RDF_ITER_FLAGS_BOUND_", 21)) {
    /*                                    C      */
      *iv_return = RDF_ITER_FLAGS_BOUND_C;
      return PERL_constant_ISIV;
    }
    break;
  }
  return PERL_constant_NOTFOUND;
}

static int
constant (pTHX_ const char *name, STRLEN len, IV *iv_return) {
  /* Initially switch on the length of the name.  */
  /* When generated this function returned values for the list of names given
     in this section of perl code.  Rather than manually editing these functions
     to add or remove constants, which would result in this comment and section
     of code becoming inaccurate, we recommend that you edit this section of
     code, and use it to regenerate a new set of constant functions which you
     then use to replace the originals.

     Regenerate these constant functions by feeding this entire source file to
     perl -x

#!/ext/local/bin/perl -w
use ExtUtils::Constant qw (constant_types C_constant XS_constant);

my $types = {map {($_, 1)} qw(IV)};
my @names = (qw(THREADED_BATCH_SIZE),
            {name=>"RDF_ITER_FLAGS_BOUND_A", type=>"IV", macro=>"1"},
            {name=>"RDF_ITER_FLAGS_BOUND_B", type=>"IV", macro=>"1"},
            {name=>"RDF_ITER_FLAGS_BOUND_C", type=>"IV", macro=>"1"});

print constant_types(), "\n"; # macro defs
foreach (C_constant ("RDF::Mentok", 'constant', 'IV', $types, undef, 3, @names) ) {
    print $_, "\n"; # C constant subs
}
print "\n#### XS Section:\n";
print XS_constant ("RDF::Mentok", $types);
__END__
   */

  switch (len) {
  case 19:
    if (memEQ(name, "THREADED_BATCH_SIZE", 19)) {
#ifdef THREADED_BATCH_SIZE
      *iv_return = THREADED_BATCH_SIZE;
      return PERL_constant_ISIV;
#else
      return PERL_constant_NOTDEF;
#endif
    }
    break;
  case 22:
    return constant_22 (aTHX_ name, iv_return);
    break;
  }
  return PERL_constant_NOTFOUND;
}

