#include <stdio.h>
#include "hexastore.h"

void head_test (void);
void vector_test (void);
void terminal_test (void);
void memory_test (void);

int main ( void ) {
//	head_test();
//	vector_test();
//	terminal_test();
	memory_test();
	return 0;
}

void memory_test (void) {
	hx_head* h	= hx_new_head();
	for (int i = 0; i < 100000; i++) {
		hx_vector* v	= hx_new_vector();
		hx_head_add_vector( h, (rdf_node) i, v );
		for (int j = 0; j < 20; j++) {
			hx_terminal* t	= hx_new_terminal();
			hx_vector_add_terminal( v, (rdf_node) j, t );
			for (int k = 0; k < 25; k++) {
//				fprintf( stdout, "%d %d %d\n", (int) i, (int) j, (int) k );
				hx_terminal_add_node( t, (rdf_node) k );
			}
		}
	}
	
	size_t bytes		= hx_head_memory_size( h );
	size_t megs			= bytes / (1024 * 1024);
	uint64_t triples	= hx_head_triples_count( h );
	int mtriples		= (int) (triples / 1000000);
	fprintf( stdout, "total triples: %d (%dM)\n", (int) triples, mtriples );
	fprintf( stdout, "total memory size: %d bytes (%d megs)\n", bytes, megs );
}

void head_test (void) {
	hx_head* h	= hx_new_head();
	printf( "sizeof head: %d\n", sizeof( hx_head ) );
	printf( "head: %p\n", h );
	hx_head_debug( "", h );
	
	hx_vector* v	= hx_new_vector();
	hx_head_add_vector( h, (rdf_node) 1, v );
	hx_head_debug( "", h );
	
	{
		hx_terminal* l	= hx_new_terminal();
		hx_vector_add_terminal( v, (rdf_node) 3, l );
		hx_head_debug( "", h );
		for (int i = 0; i < 8; i++) {
			hx_terminal_add_node( l, (rdf_node) i );
		}
		hx_head_debug( "", h );
	}
	
	{
		hx_terminal* l	= hx_new_terminal();
		hx_vector_add_terminal( v, (rdf_node) 1, l );
		hx_head_debug( "", h );
		for (int i = 5; i < 9; i++) {
			hx_terminal_add_node( l, (rdf_node) i );
		}
		hx_head_debug( "", h );
	}
	
	for (int i = 0; i < 500; i++) {
		hx_vector* v	= hx_new_vector();
		hx_head_add_vector( h, (rdf_node) i, v );
	}
	fprintf( stderr, "size: %d\n", (int) hx_head_size( h ) );
	fprintf( stderr, "triples count: %d\n", (int) hx_head_triples_count( h ) );
	
	for (int i = 499; i >= 0; i--) {
		hx_head_remove_vector( h, (rdf_node) i );
	}
	fprintf( stderr, "size: %d\n", (int) hx_head_size( h ) );
	
	hx_free_head( h );
}
	
void vector_test (void) {
	hx_vector* v	= hx_new_vector();
	printf( "sizeof vector: %d\n", sizeof( hx_vector ) );
	printf( "vector: %p\n", v );
	
	hx_vector_debug( "- ", v );
	hx_terminal* l	= hx_new_terminal();
	hx_vector_add_terminal( v, (rdf_node) 3, l );
	hx_vector_debug( "- ", v );
	hx_terminal_add_node( l, (rdf_node) 7 );
	hx_vector_debug( "- ", v );
	hx_vector_add_terminal( v, (rdf_node) 2, l );
	hx_vector_debug( "- ", v );
	hx_terminal_add_node( l, (rdf_node) 8 );
	hx_vector_debug( "- ", v );
	hx_terminal_add_node( l, (rdf_node) 9 );
	hx_vector_debug( "- ", v );
	
	fprintf( stderr, "size: %d\n", (int) hx_vector_size( v ) );
	hx_vector_remove_terminal( v, (rdf_node) 3 );
	fprintf( stderr, "size: %d\n", (int) hx_vector_size( v ) );
	hx_vector_debug( "- ", v );
	
	for (int i = 0; i < 400; i++) {
		hx_terminal* l	= hx_new_terminal();
		hx_vector_add_terminal( v, (rdf_node) i, l );
	}
	
	fprintf( stderr, "size: %d\n", (int) hx_vector_size( v ) );
	fprintf( stderr, "triples count: %d\n", (int) hx_vector_triples_count( v ) );
	for (int i = 399; i >= 0; i--) {
		hx_vector_remove_terminal( v, (rdf_node) i );
	}
	fprintf( stderr, "size: %d\n", (int) hx_vector_size( v ) );
	
	hx_free_vector( v );
}
	
void terminal_test (void) {
	hx_terminal* l	= hx_new_terminal();
	printf( "sizeof terminal list: %d\n", sizeof( hx_terminal ) );
	printf( "terminal list: %p\n", l );
	hx_terminal_debug( "- ", l, 1 );
	
	hx_terminal_add_node( l, (rdf_node) 5 );
	hx_terminal_debug( "- ", l, 1 );

	hx_terminal_add_node( l, (rdf_node) 1 );
	hx_terminal_debug( "- ", l, 1 );

	hx_terminal_add_node( l, (rdf_node) 2 );
	hx_terminal_debug( "- ", l, 1 );
	
	int i, r, n;
	n	= (rdf_node) 3;
	r	= hx_terminal_binary_search( l, n, &i );
	printf( "search: %d %d\n", r, i );

	hx_terminal_add_node( l, (rdf_node) 3 );
	hx_terminal_debug( "- ", l, 1 );

	r	= hx_terminal_binary_search( l, n, &i );
	printf( "search: %d %d\n", r, i );
	
	hx_terminal_remove_node( l, (rdf_node) 2 );
	hx_terminal_debug( "- ", l, 1 );
	hx_terminal_remove_node( l, (rdf_node) 3 );
	hx_terminal_debug( "- ", l, 1 );
	hx_terminal_remove_node( l, (rdf_node) 5 );
	hx_terminal_debug( "- ", l, 1 );
	hx_terminal_remove_node( l, (rdf_node) 6 );
	hx_terminal_debug( "- ", l, 1 );
	hx_terminal_remove_node( l, (rdf_node) 1 );
	hx_terminal_debug( "- ", l, 1 );
	
	printf( "grow test...\n" );
	for (int i = 0; i < 260; i++) {
		hx_terminal_add_node( l, (rdf_node) i );
		hx_terminal_debug( "- ", l, 1 );
	}

	printf( "shrink test...\n" );
	for (int i = 101; i < 200; i++) {
		hx_terminal_remove_node( l, (rdf_node) i );
		hx_terminal_debug( "- ", l, 1 );
	}
	for (int i = 100; i >= 0; i--) {
		hx_terminal_remove_node( l, (rdf_node) i );
		hx_terminal_debug( "- ", l, 1 );
	}
	for (int i = 200; i < 260; i++) {
		hx_terminal_remove_node( l, (rdf_node) i );
		hx_terminal_debug( "- ", l, 1 );
	}
	
	hx_free_terminal( l );
}

