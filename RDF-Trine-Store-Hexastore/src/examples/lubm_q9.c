// PREFIX : <http://www.lehigh.edu/~zhp2/2004/0401/univ-bench.owl#>
// SELECT DISTINCT * WHERE {
// 	?y a :Faculty .
// 	?x :advisor ?y .
// 	?y :teacherOf ?z .
// 	?z a :Course .
// 	?x a :Student .
// 	?x :takesCourse ?z .
// }

#include <time.h>
#include <stdio.h>
#include <pthread.h>
#include "hexastore.h"
#include "variablebindings.h"
#include "mergejoin.h"
#include "node.h"
#include "bgp.h"

#define DIFFTIME(a,b) ((b-a)/(double)CLOCKS_PER_SEC)
double bench ( hx_hexastore* hx, hx_bgp* b );

static hx_node* x;
static hx_node* y;
static hx_node* z;
static hx_node* type;
static hx_node* faculty;
static hx_node* advisor;
static hx_node* teacherOf;
static hx_node* course;
static hx_node* student;
static hx_node* takesCourse;

void _fill_triple ( hx_triple* t, hx_node* s, hx_node* p, hx_node* o );

void _fill_triple ( hx_triple* t, hx_node* s, hx_node* p, hx_node* o ) {
	t->subject		= s;
	t->predicate	= p;
	t->object		= o;
}

int main ( int argc, char** argv ) {
	const char* filename	= argv[1];
	FILE* f	= fopen( filename, "r" );
	if (f == NULL) {
		perror( "Failed to open hexastore file for reading: " );
		return 1;
	}
	
	hx_storage_manager* s	= hx_new_memory_storage_manager();
	hx_hexastore* hx		= hx_read( s, f, 0 );
	hx_nodemap* map			= hx_get_nodemap( hx );
	fprintf( stderr, "Finished loading hexastore...\n" );
	
	x			= hx_new_named_variable( hx, "x" );
	y			= hx_new_named_variable( hx, "y" );
	z			= hx_new_named_variable( hx, "z" );
	type		= hx_new_node_resource("http://www.w3.org/1999/02/22-rdf-syntax-ns#type");
	faculty		= hx_new_node_resource("http://www.lehigh.edu/~zhp2/2004/0401/univ-bench.owl#Faculty");
	advisor		= hx_new_node_resource("http://www.lehigh.edu/~zhp2/2004/0401/univ-bench.owl#advisor");
	teacherOf	= hx_new_node_resource("http://www.lehigh.edu/~zhp2/2004/0401/univ-bench.owl#teacherOf");
	course		= hx_new_node_resource("http://www.lehigh.edu/~zhp2/2004/0401/univ-bench.owl#Course");
	student		= hx_new_node_resource("http://www.lehigh.edu/~zhp2/2004/0401/univ-bench.owl#Student");
	takesCourse	= hx_new_node_resource("http://www.lehigh.edu/~zhp2/2004/0401/univ-bench.owl#takesCourse");
	
	hx_triple t0, t1, t2, t3, t4, t5;
	hx_triple* triples[6];
	{
		_fill_triple( &t0, x, advisor, y );
		_fill_triple( &t1, x, type, student );
		_fill_triple( &t2, x, takesCourse, z );
		_fill_triple( &t3, y, type, faculty );
		_fill_triple( &t4, y, teacherOf, z );
		_fill_triple( &t5, z, type, course );
		triples[0]	= &t0;
		triples[1]	= &t1;
		triples[2]	= &t2;
		triples[3]	= &t3;
		triples[4]	= &t4;
		triples[5]	= &t5;
	}
	
	hx_bgp* b	= hx_new_bgp( 5, triples );
	hx_variablebindings_iter* iter	= hx_bgp_execute( b, hx );
//	hx_variablebindings_iter_debug( iter, "lubm8> ", 0 );
	
	int size		= hx_variablebindings_iter_size( iter );
	char** names	= hx_variablebindings_iter_names( iter );
	
	int xi, yi, zi;
	for (int i = 0; i < size; i++) {
		if (strcmp(names[i], "x") == 0) {
			xi	= i;
		} else if (strcmp(names[i], "y") == 0) {
			yi	= i;
		} else if (strcmp(names[i], "z") == 0) {
			zi	= i;
		}
	}
	
	while (!hx_variablebindings_iter_finished( iter )) {
		hx_variablebindings* b;
		hx_variablebindings_iter_current( iter, &b );
		hx_node_id xid	= hx_variablebindings_node_id_for_binding ( b, xi );
		hx_node_id yid	= hx_variablebindings_node_id_for_binding ( b, yi );
		hx_node_id zid	= hx_variablebindings_node_id_for_binding ( b, zi );
		hx_node* x		= hx_nodemap_get_node( map, xid );
		hx_node* y		= hx_nodemap_get_node( map, yid );
		hx_node* z		= hx_nodemap_get_node( map, zid );
		
		char *xs, *ys, *zs;
		hx_node_string( x, &xs );
		hx_node_string( y, &ys );
		hx_node_string( z, &zs );
		printf( "%s\t%s\t%s\n", xs, ys, zs );
		free( xs );
		free( ys );
		free( zs );
		
		hx_free_variablebindings( b, 0 );
		hx_variablebindings_iter_next( iter );
	}
	
	hx_free_variablebindings_iter( iter, 1 );
	
	hx_free_bgp( b );
	hx_free_node( x );
	hx_free_node( y );
	hx_free_node( z );
	hx_free_node( type );
	hx_free_node( faculty );
	hx_free_node( advisor );
	hx_free_node( teacherOf );
	hx_free_node( course );
	hx_free_node( student );
	hx_free_node( takesCourse );
	
	hx_free_hexastore( hx );
	hx_free_storage_manager( s );
	
	return 0;
}
