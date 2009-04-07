#include "triple.h"

hx_triple* hx_new_triple( hx_node* s, hx_node* p, hx_node* o ) {
	hx_triple* t	= (hx_triple*) calloc( 1, sizeof( hx_triple ) );
	t->subject		= s;
	t->predicate	= p;
	t->object		= o;
	return t;
}

int hx_free_triple ( hx_triple* t ) {
	free( t );
	return 0;
}

