// SELECT DISTINCT * WHERE {
// 	?x <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://www.lehigh.edu/~zhp2/2004/0401/univ-bench.owl#Professor> .
// 	?x <http://www.lehigh.edu/~zhp2/2004/0401/univ-bench.owl#worksFor> <http://www.Department0.University0.edu> .
// 	?x <http://www.lehigh.edu/~zhp2/2004/0401/univ-bench.owl#name> ?y1 .
// 	?x <http://www.lehigh.edu/~zhp2/2004/0401/univ-bench.owl#emailAddress> ?y2 .
// 	?x <http://www.lehigh.edu/~zhp2/2004/0401/univ-bench.owl#telephone> ?y3 .
// }

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
	hx_node* y1			= hx_new_named_variable( hx, "y1" );
	hx_node* y2			= hx_new_named_variable( hx, "y2" );
	hx_node* y3			= hx_new_named_variable( hx, "y3" );
	
	hx_node* type		= hx_new_node_resource("http://www.w3.org/1999/02/22-rdf-syntax-ns#type");
	hx_node* prof		= hx_new_node_resource("http://www.lehigh.edu/~zhp2/2004/0401/univ-bench.owl#Professor");
	hx_node* worksFor	= hx_new_node_resource("http://www.lehigh.edu/~zhp2/2004/0401/univ-bench.owl#worksFor");
	hx_node* univ0		= hx_new_node_resource("http://www.Department0.University0.edu");
	hx_node* name		= hx_new_node_resource("http://www.lehigh.edu/~zhp2/2004/0401/univ-bench.owl#name");
	hx_node* email		= hx_new_node_resource("http://www.lehigh.edu/~zhp2/2004/0401/univ-bench.owl#emailAddress");
	hx_node* tel		= hx_new_node_resource("http://www.lehigh.edu/~zhp2/2004/0401/univ-bench.owl#telephone");
	
	hx_triple* triples[5];
	{
		hx_triple t0, t1, t2, t3, t4;
		_fill_triple( &t0, x, type, prof );
		_fill_triple( &t1, x, worksFor, univ0 );
		_fill_triple( &t2, x, name, y1 );
		_fill_triple( &t3, x, email, y2 );
		_fill_triple( &t4, x, tel, y3 );
		triples[0]	= &t0;
		triples[1]	= &t1;
		triples[2]	= &t2;
		triples[3]	= &t3;
		triples[4]	= &t4;
	}
	
	hx_bgp* b	= hx_new_bgp( 4, triples );
	hx_variablebindings_iter* iter	= hx_bgp_execute( b, hx );
	
	int size		= hx_variablebindings_iter_size( iter );
	char** names	= hx_variablebindings_iter_names( iter );
	int xi, y1i, y2i, y3i;
	for (int i = 0; i < size; i++) {
		if (strcmp(names[i], "x") == 0) {
			xi	= i;
		} else if (strcmp(names[i], "y1") == 0) {
			y1i	= i;
		} else if (strcmp(names[i], "y2") == 0) {
			y2i	= i;
		} else if (strcmp(names[i], "y3") == 0) {
			y3i	= i;
		}
	}
	
	while (!hx_variablebindings_iter_finished( iter )) {
		hx_variablebindings* b;
		hx_variablebindings_iter_current( iter, &b );
		hx_node_id xid	= hx_variablebindings_node_id_for_binding ( b, xi );
		hx_node_id y1id	= hx_variablebindings_node_id_for_binding ( b, y1i );
		hx_node_id y2id	= hx_variablebindings_node_id_for_binding ( b, y2i );
		hx_node_id y3id	= hx_variablebindings_node_id_for_binding ( b, y3i );
		hx_node* x		= hx_nodemap_get_node( map, xid );
		hx_node* y1		= hx_nodemap_get_node( map, y1id );
		hx_node* y2		= hx_nodemap_get_node( map, y2id );
		hx_node* y3		= hx_nodemap_get_node( map, y3id );
		
		char *xs, *y1s, *y2s, *y3s;
		hx_node_string( x, &xs );
		hx_node_string( y1, &y1s );
		hx_node_string( y2, &y2s );
		hx_node_string( y3, &y3s );
		printf( "%s\t%s\t%s\t%s\n", xs, y1s, y2s, y3s );
		free( xs );
		free( y1s );
		free( y2s );
		free( y3s );
		
		hx_free_variablebindings( b, 0 );
		hx_variablebindings_iter_next( iter );
	}
	hx_free_variablebindings_iter( iter, 1 );
	
	hx_free_bgp( b );
	hx_free_node( x );
	hx_free_node( y1 );
	hx_free_node( y2 );
	hx_free_node( y3 );
	hx_free_node( type );
	hx_free_node( prof );
	hx_free_node( worksFor );
	hx_free_node( univ0 );
	hx_free_node( name );
	hx_free_node( email );
	hx_free_node( tel );
	
	return 0;
}

void _fill_triple ( hx_triple* t, hx_node* s, hx_node* p, hx_node* o ) {
	t->subject		= s;
	t->predicate	= p;
	t->object		= o;
}
