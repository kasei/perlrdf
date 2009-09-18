#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#include </usr/local/include/mentok/mentok.h>
#include </usr/local/include/mentok/parser/parser.h>

#include "const-c.inc"

typedef struct hx_model * RDF_Mentok;


double plmentok_test ( void ) {
	return 13;
}

MODULE = RDF::Mentok		PACKAGE = RDF::Mentok	PREFIX = plmentok_

PROTOTYPES: DISABLE

INCLUDE: const-xs.inc

double plmentok_test ()

RDF_Mentok
plmentok_new_model ()
	CODE:
		RDF_Mentok m	= hx_new_model( NULL );
		RETVAL	= m;
	OUTPUT:
		RETVAL

void plmentok_load_file ( m, file )
		RDF_Mentok m
		char* file
	CODE:
		hx_parser* parser	= hx_new_parser();
		hx_parser_parse_file_into_model( parser, m, file );
		hx_free_parser(parser);

long plmentok_size ( m )
		RDF_Mentok m
	CODE:
		long s	= (long) hx_model_triples_count(m);
		RETVAL	= s;
	OUTPUT:
		RETVAL
		
void
plmentok_DESTROY (model)
		RDF_Mentok model
	CODE:
//		hx_model_debug( model );
		hx_free_model(model);

