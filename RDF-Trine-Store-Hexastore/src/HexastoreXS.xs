#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include <raptor.h>
#include <openssl/sha.h>
#include "hexastore.h"


MODULE = RDF::Trine::Store::HexastoreXS        PACKAGE = RDF::Trine::Store::HexastoreXS
PROTOTYPES: DISABLE

hx_index*
new_index ()
	PREINIT:
		hx_index* index;
	CODE:
		index	= hx_new_index( HX_INDEX_ORDER_SPO );
		if (index == NULL) {
			croak("hx_new_index returned NULL");
		}
		RETVAL	= index;
	OUTPUT:
		RETVAL

void
free_index ( index )
	hx_index* index;
	CODE:
		hx_free_index( index );
	OUTPUT:

MODULE = RDF::Trine::Store::HexastoreXS		PACKAGE = hx_indexPtr		PREFIX = hx_

hx_iter*
iterator (i)
	hx_index* i
	PREINIT:
		hx_iter *iter;
	CODE:
		iter	= hx_new_iter( i );
		if (iter == NULL) {
			croak("hx_new_iter returned NULL");
		}
		RETVAL	= iter;
	OUTPUT:
		RETVAL

