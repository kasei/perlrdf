#include <stdio.h>
#include <pthread.h>
#include "hexastore.h"
#include "mergejoin.h"
#include "node.h"
#include "bgp.h"

void _fill_triple ( hx_triple* t, hx_node* s, hx_node* p, hx_node* o );
int main ( int argc, char** argv ) {
	const char* filename	= argv[1];
	FILE* f	= fopen( filename, "r" );
	if (f == NULL) {
		perror( "Failed to open hexastore file for reading: " );
		return 1;
	}
	hx_storage_manager* s	= hx_new_memory_storage_manager();
	hx_hexastore* hx	= hx_read( s, f, 0 );
	hx_nodemap* map		= hx_get_nodemap( hx );
	fprintf( stderr, "Finished loading hexastore...\n" );
	
	hx_node* x			= hx_new_named_variable( hx, "x" );
	hx_node* y			= hx_new_named_variable( hx, "y" );
	
	hx_node* type		= hx_new_node_resource("http://www.w3.org/1999/02/22-rdf-syntax-ns#type");
	hx_node* knows		= hx_new_node_resource("http://xmlns.com/foaf/0.1/knows");
	hx_node* person		= hx_new_node_resource("http://xmlns.com/foaf/0.1/Person");
	
	hx_triple* triples[2];
	{
		hx_triple t0, t1;
		_fill_triple( &t0, x, type, person );
		_fill_triple( &t1, x, knows, y );
		triples[0]	= &t0;
		triples[1]	= &t1;
	}
	
	hx_bgp* b	= hx_new_bgp( 2, triples );
	hx_variablebindings_iter* iter	= hx_bgp_execute( b, hx );
	
	int size		= hx_variablebindings_iter_size( iter );
	char** names	= hx_variablebindings_iter_names( iter );
	int xi, yi;
	for (int i = 0; i < size; i++) {
		if (strcmp(names[i], "x") == 0) {
			xi	= i;
		} else if (strcmp(names[i], "y") == 0) {
			yi	= i;
		}
	}
	
	while (!hx_variablebindings_iter_finished( iter )) {
		hx_variablebindings* b;
		hx_variablebindings_iter_current( iter, &b );
		hx_node_id xid	= hx_variablebindings_node_id_for_binding ( b, xi );
		hx_node_id yid	= hx_variablebindings_node_id_for_binding ( b, yi );
		hx_node* x		= hx_nodemap_get_node( map, xid );
		hx_node* y		= hx_nodemap_get_node( map, yid );
		
		char *xs, *ys;
		hx_node_string( x, &xs );
		hx_node_string( y, &ys );
		printf( "%s\t%s\n", xs, ys );
		free( xs );
		free( ys );
		
		hx_free_variablebindings( b, 0 );
		hx_variablebindings_iter_next( iter );
	}
	hx_free_variablebindings_iter( iter, 1 );
	
	hx_free_bgp( b );
	hx_free_node( x );
	hx_free_node( y );
	hx_free_node( type );
	hx_free_node( person );
	hx_free_node( knows );
	hx_free_hexastore( hx );
	hx_free_storage_manager( s );
	
	return 0;
}

void _fill_triple ( hx_triple* t, hx_node* s, hx_node* p, hx_node* o ) {
	t->subject		= s;
	t->predicate	= p;
	t->object		= o;
}
