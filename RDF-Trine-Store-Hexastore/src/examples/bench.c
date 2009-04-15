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
double bench ( hx_hexastore* hx, hx_bgp* b, hx_storage_manager* s );

static hx_node* x;
static hx_node* y;
static hx_node* z;
static hx_node* type;
static hx_node* dept;
static hx_node* subOrg;
static hx_node* univ;
static hx_node* degFrom;
static hx_node* gradstudent;
static hx_node* member;

void _fill_triple ( hx_triple* t, hx_node* s, hx_node* p, hx_node* o );

double average ( hx_hexastore* hx, hx_bgp* b, hx_storage_manager* s, int count ) {
	double total	= 0.0;
	for (int i = 0; i < count; i++) {
		total	+= bench( hx, b, s );
	}
	return (total / (double) count);
}

double bench ( hx_hexastore* hx, hx_bgp* b, hx_storage_manager* s ) {
	hx_nodemap* map		= hx_get_nodemap( hx );
	clock_t st_time	= clock();
	
	hx_variablebindings_iter* iter	= hx_bgp_execute( b, hx, s );
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
		
		hx_free_variablebindings( b, 0 );
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
	univ		= hx_new_node_resource("http://www.lehigh.edu/~zhp2/2004/0401/univ-bench.owl#University");
	degFrom		= hx_new_node_resource("http://www.lehigh.edu/~zhp2/2004/0401/univ-bench.owl#undergraduateDegreeFrom");
	gradstudent	= hx_new_node_resource("http://www.lehigh.edu/~zhp2/2004/0401/univ-bench.owl#GraduateStudent");
	member		= hx_new_node_resource("http://www.lehigh.edu/~zhp2/2004/0401/univ-bench.owl#memberOf");
	
	hx_triple t0, t1, t2, t3, t4, t5;
	hx_triple* triples[6];
	{
		_fill_triple( &t0, x, degFrom, y );
		_fill_triple( &t1, x, type, gradstudent );
		_fill_triple( &t2, x, member, z );
		_fill_triple( &t3, z, type, dept );
		_fill_triple( &t4, z, subOrg, y );
		_fill_triple( &t5, y, type, univ );
		triples[0]	= &t0;
		triples[1]	= &t1;
		triples[2]	= &t2;
		triples[3]	= &t3;
		triples[4]	= &t4;
		triples[5]	= &t5;
	}
	
	{
		hx_bgp* b	= hx_new_bgp( 6, triples );
		hx_bgp_debug( b );
		fprintf( stderr, "running time: %lf\n", average( hx, b, s, 4 ) );
		hx_free_bgp( b );
	}
	{
		hx_bgp* b	= hx_new_bgp( 6, triples );
		hx_bgp_reorder( b, hx, s );
		hx_bgp_debug( b );
		fprintf( stderr, "BGP-optimized running time: %lf\n", average( hx, b, s, 4 ) );
		hx_free_bgp( b );
	}
	
	hx_free_node( x );
	hx_free_node( y );
	hx_free_node( z );
	hx_free_node( type );
	hx_free_node( dept );
	hx_free_node( subOrg );
	hx_free_node( univ );
	hx_free_node( degFrom );
	hx_free_node( gradstudent );
	hx_free_node( member );
	
	hx_free_hexastore( hx, s );
	hx_free_storage_manager( s );
	
	return 0;
}
