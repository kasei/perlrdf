#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

MODULE = RDF::Base        PACKAGE = RDF::Base::Storage::DBI


SV*
_c (value)
	unsigned char* value
	CODE:
		uint64_t j	= 0;
		int k		= 0;
		char hash[21];
		
		for (k = 0; k < 8; k++) {
			uint64_t l	= value[ k ];
			j	+= (l << (8 * k));
		}
		
		sprintf( hash, "%llu", j );
		RETVAL	= newSVpv(hash, 0);
	OUTPUT:
		RETVAL
