// PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
// PREFIX ub: <http://www.lehigh.edu/~zhp2/2004/0401/univ-bench.owl#>
// SELECT ?X ?Y ?Z 
// WHERE
// {
// ?Y ub:subOrganizationOf <http://www.University0.edu> .
// ?Y rdf:type ub:Department .
// ?X ub:memberOf ?Y .
// ?X rdf:type ub:UndergraduateStudent .
// ?X ub:emailAddress ?Z .
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
static hx_node* dept;
static hx_node* subOrg;
static hx_node* univ;
static hx_node* email;
static hx_node* student;
static hx_node* member;

void _fill_triple ( hx_triple* t, hx_node* s, hx_node* p, hx_node* o );

double average ( hx_hexastore* hx, hx_bgp* b, int count ) {
	double total	= 0.0;
	for (int i = 0; i < count; i++) {
		total	+= bench( hx, b );
	}
	return (total / (double) count);
}

double bench ( hx_hexastore* hx, hx_bgp* b ) {
	hx_nodemap* map		= hx_get_nodemap( hx );
	clock_t st_time	= clock();
	
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
	
	uint64_t count	= 0;
	while (!hx_variablebindings_iter_finished( iter )) {
		count++;
		hx_variablebindings* b;
		hx_variablebindings_iter_current( iter, &b );
		
		if (0) {
			hx_node* x		= hx_variablebindings_node_for_binding_name( b, map, "x" );
			hx_node* y		= hx_variablebindings_node_for_binding_name( b, map, "y" );
			hx_node* z		= hx_variablebindings_node_for_binding_name( b, map, "z" );
		
			char *xs, *ys, *zs;
			hx_node_string( x, &xs );
			hx_node_string( y, &ys );
			hx_node_string( z, &zs );
			printf( "%s\t%s\t%s\n", xs, ys, zs );
			free( xs );
			free( ys );
			free( zs );
		}
		
		hx_free_variablebindings( b, 1 );
		hx_variablebindings_iter_next( iter );
	}
	printf( "%llu results\n", (unsigned long long) count );
	clock_t end_time	= clock();
	
	hx_free_variablebindings_iter( iter, 1 );
	return DIFFTIME(st_time, end_time);
}

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
	dept		= hx_new_node_resource("http://www.lehigh.edu/~zhp2/2004/0401/univ-bench.owl#Department");
	subOrg		= hx_new_node_resource("http://www.lehigh.edu/~zhp2/2004/0401/univ-bench.owl#subOrganizationOf");
	univ		= hx_new_node_resource("http://www.University0.edu");
	email		= hx_new_node_resource("http://www.lehigh.edu/~zhp2/2004/0401/univ-bench.owl#emailAddress");
	student		= hx_new_node_resource("http://www.lehigh.edu/~zhp2/2004/0401/univ-bench.owl#UndergraduateStudent");
	member		= hx_new_node_resource("http://www.lehigh.edu/~zhp2/2004/0401/univ-bench.owl#memberOf");
	
	hx_triple t0, t1, t2, t3, t4;
	hx_triple* triples[5];
	{
		_fill_triple( &t0, y, subOrg, univ );
		_fill_triple( &t1, y, type, dept );
		_fill_triple( &t2, x, member, y );
		_fill_triple( &t3, x, type, student );
		_fill_triple( &t4, x, email, z );
		triples[0]	= &t0;
		triples[1]	= &t1;
		triples[2]	= &t2;
		triples[3]	= &t3;
		triples[4]	= &t4;
	}
	
	{
		hx_bgp* b	= hx_new_bgp( 5, triples );
		hx_bgp_debug( b );
		fprintf( stderr, "running time: %lf\n", average( hx, b, 5 ) );
		hx_free_bgp( b );
	}
	
	hx_free_node( x );
	hx_free_node( y );
	hx_free_node( z );
	hx_free_node( type );
	hx_free_node( dept );
	hx_free_node( subOrg );
	hx_free_node( univ );
	hx_free_node( email );
	hx_free_node( student );
	hx_free_node( member );
	
	hx_free_hexastore( hx );
	hx_free_storage_manager( s );
	
	return 0;
}
