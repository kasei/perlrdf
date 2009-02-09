#include <stdio.h>
#include <stdlib.h>
#include "hexastore.h"
#include "nodemap.h"

void head_test (void);
void vector_test (void);
void terminal_test (void);
void memory_test (void);
void index_test ( void );
void hexastore_test ( void );
void nodemap_test ( void );
void terminal_store_test ( void );
void vector_store_test ( void );

int main ( void ) {
//	terminal_store_test();
	vector_store_test();
//	nodemap_test();
//	hexastore_test();
// 	index_test();
// 	head_test();
// 	vector_test();
// 	terminal_test();
// 	memory_test();
	return 0;
}

void vector_store_test ( void ) {
	if (1) {
		int writecount	= 0;
		{
			FILE* f;
			hx_vector* v	= hx_new_vector();
			for (int j = 10; j > 5; j--) {
				hx_terminal* t	= hx_new_terminal();
				for (int i = j; i > 0; i--) {
					writecount++;
					hx_terminal_add_node( t, (hx_node_id) i );
				}
				hx_vector_add_terminal( v, (hx_node_id) j, t );
			}
			fprintf( stderr, "\nfinished loading %d triples\n", writecount );
			fprintf( stderr, "writing vector to file...\n" );
			f	= fopen( "vector.dat", "w" );
			if (f == NULL) {
				perror( "*** Failed to open file vector.dat for writing: " );
				exit(1);
			}
			hx_vector_write( v, f );
			fclose( f );
		}
		
		{
			int readcount	= 0;
			int expected	= 6;
			FILE* f;
			f	= fopen( "vector.dat", "r" );
			if (f == NULL) {
				perror( "*** Failed to open file vector.dat for reading: " );
				exit(1);
			}
			fprintf( stderr, "Reading vector from file...\n" );
			hx_vector* v	= hx_vector_read( f, 0 );
			hx_vector_iter* iter	= hx_vector_new_iter( v );
			while (!hx_vector_iter_finished( iter )) {
				hx_node_id n;
				hx_terminal* t;
				hx_vector_iter_current( iter, &n, &t );
				fprintf( stderr, "%d ", (int) n );
				hx_terminal_debug( "-> ", t, 1 );
				if (n == expected) {
					fprintf( stdout, "ok # expected vector for node %d\n", (int) n );
				} else {
					fprintf( stdout, "not ok # unexpected vector for node %d does not match expected node %d\n", (int) n, (int) expected );
				}
				expected++;
				readcount	+= hx_terminal_size( t );
				hx_vector_iter_next( iter );
			}
			if (readcount == writecount) {
				fprintf( stdout, "ok # read the same number of values as written\n" );
			} else {
				fprintf( stdout, "not ok # read different number of values (%d) than written (%d)\n", (int) readcount, (int) writecount );
			}
			hx_free_vector_iter( iter );
			hx_free_vector( v );
			unlink( "vector.dat" );
		}
	}	
}

void terminal_store_test ( void ) {
	if (1) {
		int writecount	= 0;
		{
			FILE* f;
			hx_terminal* t	= hx_new_terminal();
			for (int i = 100; i > 50; i--) {
				writecount++;
				hx_terminal_add_node( t, (hx_node_id) i );
			}
			fprintf( stderr, "\nfinished loading %d triples\n", writecount );
			fprintf( stderr, "writing terminal to file...\n" );
			f	= fopen( "terminal.dat", "w" );
			if (f == NULL) {
				perror( "*** Failed to open file terminal.dat for writing: " );
				exit(1);
			}
			hx_terminal_write( t, f );
			fclose( f );
		}
		
		{
			int readcount	= 0;
			int expected	= 51;
			FILE* f;
			f	= fopen( "terminal.dat", "r" );
			if (f == NULL) {
				perror( "*** Failed to open file terminal.dat for reading: " );
				exit(1);
			}
			hx_terminal* t	= hx_terminal_read( f, 0 );
			hx_terminal_iter* iter	= hx_terminal_new_iter( t );
			while (!hx_terminal_iter_finished( iter )) {
				hx_node_id n;
				hx_terminal_iter_current( iter, &n );
				if (n == expected) {
					fprintf( stdout, "ok # expected value %d\n", (int) n );
				} else {
					fprintf( stdout, "not ok # unexpected value %d does not equal expected %d\n", (int) n, (int) expected );
				}
				expected++;
				readcount++;
				hx_terminal_iter_next( iter );
			}
			if (readcount == writecount) {
				fprintf( stdout, "ok # read the same number of values as written\n" );
			} else {
				fprintf( stdout, "not ok # read different number of values than written\n" );
			}
			hx_free_terminal_iter( iter );
			hx_free_terminal( t );
			unlink( "terminal.dat" );
		}
	}	
}

void nodemap_test ( void ) {
	hx_nodemap*	m	= hx_new_nodemap();
	char s[2];
	for (char c = 'a'; c <= 'z'; c++) {
		sprintf( s, "%c", c );
		hx_node* n	= (hx_node*) hx_new_node_literal( s );
		hx_nodemap_add_node( m, n );
		hx_free_node( n );
	}
	
	for (char c = 'z'; c >= 'a'; c--) {
		sprintf( s, "%c", c );
		hx_node* node	= (hx_node*) hx_new_node_literal( s );
		hx_node_id n	= hx_nodemap_get_node_id( m, node );
		fprintf( stderr, "%c -> %d\n", c, (int) n );
		hx_free_node( node );
	}
	
	hx_node* node	= hx_nodemap_get_node( m, (hx_node_id) 7 );
	char* nodestr	= NULL;
	hx_node_string( node, &nodestr );
	fprintf( stderr, "%d -> '%s' (%p)", 7, nodestr, nodestr );
	free( nodestr );
	
	hx_free_nodemap( m );
}

void hexastore_test ( void ) {
	if (1) {
		hx_hexastore* hx	= hx_new_hexastore();
		
		{
			int count	= 0;
			for (int i = 1; i <= 400; i++) {
				for (int j = 1; j <= 100; j++) {
					for (int k = 1; k <= 50; k++) {
						count++;
						hx_add_triple( hx, (hx_node_id) i, (hx_node_id) j, (hx_node_id) k );
						if (count % 25000 == 0)
							fprintf( stderr, "\rloaded %d triples", count );
					}
				}
			}
			fprintf( stderr, "\nfinished loading %d triples\n", count );
		}
		sleep(30);
		
		if (0) {
			hx_index_iter* iter	= hx_index_new_iter( hx->spo );
			while (!hx_index_iter_finished( iter )) {
				hx_node_id s, p, o;
				hx_index_iter_current( iter, &s, &p, &o );
				fprintf( stderr, "%d, %d, %d\n", (int) s, (int) p, (int) o );
				hx_index_iter_next( iter );
			}
			hx_free_index_iter( iter );
		}
		fprintf( stderr, "removing triples...\n" );
		{
			int count	= 0;
			for (int i = 1; i <= 9; i++) {
				for (int j = 1; j <= 9; j++) {
					for (int k = 1; k <= 9; k++) {
						count++;
						hx_remove_triple( hx, (hx_node_id) i, (hx_node_id) j, (hx_node_id) k );
					}
				}
			}
			fprintf( stderr, "removed %d triples\n", count );
		}
	
		fprintf( stderr, "full iterator...\n" );
		{
			int count	= 1;
			hx_index_iter* iter	= hx_index_new_iter( hx->spo );
			while (!hx_index_iter_finished( iter )) {
				hx_node_id s, p, o;
				hx_index_iter_current( iter, &s, &p, &o );
				fprintf( stderr, "[%d] %d, %d, %d\n", count++, (int) s, (int) p, (int) o );
				hx_index_iter_next( iter );
			}
			hx_free_index_iter( iter );
		}
		
		hx_free_hexastore( hx );
	}
	
	if (0) {
		hx_hexastore* hx	= hx_new_hexastore();
		for (int i = 1; i <= 10; i++) {
			for (int j = 1; j <= 10; j++) {
				for (int k = 1; k <= 10; k++) {
					hx_add_triple( hx, (hx_node_id) i, (hx_node_id) j, (hx_node_id) k );
				}
			}
		}

		{
			fprintf( stderr, "iter (4,*,*) ordered by object...\n" );
			int count	= 1;
			hx_index_iter* iter	= hx_get_statements( hx, (hx_node_id) 4, (hx_node_id) 0, (hx_node_id) 0, HX_OBJECT );
			while (!hx_index_iter_finished( iter )) {
				hx_node_id s, p, o;
				hx_index_iter_current( iter, &s, &p, &o );
				fprintf( stderr, "[%d] %d, %d, %d\n", count++, (int) s, (int) p, (int) o );
				hx_index_iter_next( iter );
			}
			hx_free_index_iter( iter );
		}
		{
			fprintf( stderr, "iter (*,*,9) ordered by predicate...\n" );
			int count	= 1;
			hx_index_iter* iter	= hx_get_statements( hx, (hx_node_id) 0, (hx_node_id) 0, (hx_node_id) 9, HX_PREDICATE );
			while (!hx_index_iter_finished( iter )) {
				hx_node_id s, p, o;
				hx_index_iter_current( iter, &s, &p, &o );
				fprintf( stderr, "[%d] %d, %d, %d\n", count++, (int) s, (int) p, (int) o );
				hx_index_iter_next( iter );
			}
			hx_free_index_iter( iter );
		}
		{
			fprintf( stderr, "iter (*,*,*) ordered by predicate...\n" );
			int count	= 1;
			hx_index_iter* iter	= hx_get_statements( hx, (hx_node_id) 0, (hx_node_id) 0, (hx_node_id) 0, HX_PREDICATE );
			while (!hx_index_iter_finished( iter )) {
				hx_node_id s, p, o;
				hx_index_iter_current( iter, &s, &p, &o );
				fprintf( stderr, "[%d] %d, %d, %d\n", count++, (int) s, (int) p, (int) o );
				hx_index_iter_next( iter );
			}
			hx_free_index_iter( iter );
		}
		hx_free_hexastore( hx );
	}
}

void memory_test (void) {
	hx_head* h	= hx_new_head();
	for (int i = 100; i > 0; i--) {
		hx_vector* v	= hx_new_vector();
		hx_head_add_vector( h, (hx_node_id) i, v );
		for (int j = 200; j > 0; j--) {
			hx_terminal* t	= hx_new_terminal();
			hx_vector_add_terminal( v, (hx_node_id) j, t );
			for (int k = 1; k < 25; k++) {
//				fprintf( stderr, "%d %d %d\n", (int) i, (int) j, (int) k );
				hx_terminal_add_node( t, (hx_node_id) k );
			}
		}
	}
	
	size_t bytes		= hx_head_memory_size( h );
	size_t megs			= bytes / (1024 * 1024);
	uint64_t triples	= hx_head_triples_count( h );
	int mtriples		= (int) (triples / 1000000);
	fprintf( stderr, "total triples: %d (%dM)\n", (int) triples, (int) mtriples );
	fprintf( stderr, "total memory size: %d bytes (%d megs)\n", (int) bytes, (int) megs );
	hx_free_head( h );
}

void index_test (void) {
	hx_index* index	= hx_new_index( HX_INDEX_ORDER_SOP );
	fprintf( stderr, "index size: %d\n", (int) sizeof( hx_index ) );
	hx_index_debug( index );
	hx_index_add_triple( index, (hx_node_id) 1, (hx_node_id) 2, (hx_node_id) 3 );
	hx_index_debug( index );
	
	for (int i = 1; i < 4; i++) {
		for (int j = 4; j <= 6; j++) {
			for (int k = 7; k <= 8; k++) {
				hx_index_add_triple( index, (hx_node_id) i, (hx_node_id) j, (hx_node_id) k );
			}
		}
	}
	hx_index_debug( index );
	fprintf( stderr, "total triples: %d\n", (int) hx_index_triples_count( index ) );
	
	fprintf( stderr, "iterator test...\n" );
	{
		hx_index_iter* iter	= hx_index_new_iter( index );
		if (!hx_index_iter_finished( iter )) {
			hx_node_id s, p, o;
			hx_index_iter_current( iter, &s, &p, &o );
			fprintf( stderr, "{ %d, %d, %d }\n", (int) s, (int) p, (int) o );
		}
		hx_free_index_iter( iter );
	}
	
	fprintf( stderr, "removing triples matching {0,4,*}...\n" );
	hx_index_remove_triple( index, (hx_node_id) 0, (hx_node_id) 4, (hx_node_id) 7 );
	hx_index_remove_triple( index, (hx_node_id) 0, (hx_node_id) 4, (hx_node_id) 8 );
	fprintf( stderr, "total triples: %d\n", (int) hx_index_triples_count( index ) );

	fprintf( stderr, "second iterator test...\n" );
	{
		int count	= 0;
		hx_index_iter* iter	= hx_index_new_iter( index );
		while (!hx_index_iter_finished( iter )) {
			count++;
			hx_node_id s, p, o;
			hx_index_iter_current( iter, &s, &p, &o );
			fprintf( stderr, "{ %d, %d, %d }\n", (int) s, (int) p, (int) o );
			hx_index_iter_next( iter );
		}
		hx_free_index_iter( iter );
		fprintf( stderr, "got %d triples from iterator\n", count );
	}
	
	hx_free_index( index );
}

void head_test (void) {
	hx_head* h	= hx_new_head();
	printf( "sizeof head: %d\n", (int) sizeof( hx_head ) );
	printf( "head: %p\n", (void*) h );
	hx_head_debug( "", h );
	
	hx_vector* v	= hx_new_vector();
	hx_head_add_vector( h, (hx_node_id) 1, v );
	hx_head_debug( "", h );
	
	{
		hx_terminal* l	= hx_new_terminal();
		hx_vector_add_terminal( v, (hx_node_id) 3, l );
		hx_head_debug( "", h );
		for (int i = 1; i < 8; i++) {
			hx_terminal_add_node( l, (hx_node_id) i );
		}
		hx_head_debug( "", h );
	}
	
	{
		hx_terminal* l	= hx_new_terminal();
		hx_vector_add_terminal( v, (hx_node_id) 1, l );
		hx_head_debug( "", h );
		for (int i = 5; i < 9; i++) {
			hx_terminal_add_node( l, (hx_node_id) i );
		}
		hx_head_debug( "", h );
	}
	
	for (int i = 0; i < 500; i++) {
		hx_vector* v	= hx_new_vector();
		hx_head_add_vector( h, (hx_node_id) i, v );
	}
	fprintf( stderr, "size: %d\n", (int) hx_head_size( h ) );
	fprintf( stderr, "triples count: %d\n", (int) hx_head_triples_count( h ) );
	
	for (int i = 499; i > 0; i--) {
		hx_head_remove_vector( h, (hx_node_id) i );
	}
	fprintf( stderr, "size: %d\n", (int) hx_head_size( h ) );
	
	for (int k = 1; k < 3; k++) {
		hx_vector* v	= hx_new_vector();
		for (int i = 1; i <= 10; i++) {
			hx_terminal* l	= hx_new_terminal();
			for (int j = 1; j < (1 + rand() % 10); j++) {
				hx_terminal_add_node( l, (hx_node_id) j );
			}
			hx_vector_add_terminal( v, (hx_node_id) i, l );
		}
		hx_head_add_vector( h, (hx_node_id) k, v );
	}
	
	fprintf( stderr, "head iter test...\n" );
	hx_head_iter* iter	= hx_head_new_iter( h );
	while (!hx_head_iter_finished( iter )) {
		hx_vector* v;
		hx_node_id n;
		hx_head_iter_current( iter, &n, &v );
		fprintf( stderr, "%d ", (int) n );
		hx_vector_debug( "----> ", v );
		fprintf( stderr, "<----------------------->\n" );
		hx_head_iter_next( iter );
	}
	hx_free_head_iter( iter );
	hx_free_head( h );
}
	
void vector_test (void) {
	hx_vector* v	= hx_new_vector();
	printf( "sizeof vector: %d\n", (int) sizeof( hx_vector ) );
	printf( "vector: %p\n", (void*) v );
	
	hx_vector_debug( "- ", v );
	hx_terminal* l	= hx_new_terminal();
	hx_vector_add_terminal( v, (hx_node_id) 3, l );
	hx_vector_debug( "- ", v );
	hx_terminal_add_node( l, (hx_node_id) 7 );
	hx_vector_debug( "- ", v );
	hx_vector_add_terminal( v, (hx_node_id) 2, l );
	hx_vector_debug( "- ", v );
	hx_terminal_add_node( l, (hx_node_id) 8 );
	hx_vector_debug( "- ", v );
	hx_terminal_add_node( l, (hx_node_id) 9 );
	hx_vector_debug( "- ", v );
	
	fprintf( stderr, "size: %d\n", (int) hx_vector_size( v ) );
	hx_vector_remove_terminal( v, (hx_node_id) 3 );
	fprintf( stderr, "size: %d\n", (int) hx_vector_size( v ) );
	hx_vector_debug( "- ", v );
	
	for (int i = 1; i < 400; i++) {
		hx_terminal* l	= hx_new_terminal();
		if (hx_vector_add_terminal( v, (hx_node_id) i, l ) != 0) {
			hx_free_terminal( l );
		}
	}
	
	fprintf( stderr, "size: %d\n", (int) hx_vector_size( v ) );
	fprintf( stderr, "triples count: %d\n", (int) hx_vector_triples_count( v ) );
	for (int i = 399; i >= 0; i--) {
		hx_vector_remove_terminal( v, (hx_node_id) i );
	}
	fprintf( stderr, "size: %d\n", (int) hx_vector_size( v ) );
	
	
	
	for (int i = 1; i <= 10; i++) {
		hx_terminal* l	= hx_new_terminal();
		for (int j = 1; j < (1 + rand() % 10); j++) {
			hx_terminal_add_node( l, (hx_node_id) j );
		}
		hx_vector_add_terminal( v, (hx_node_id) i, l );
	}
	
	hx_vector_iter* iter	= hx_vector_new_iter( v );
	while (!hx_vector_iter_finished( iter )) {
		hx_terminal* t;
		hx_node_id n;
		hx_vector_iter_current( iter, &n, &t );
		fprintf( stderr, "%d ", (int) n );
		hx_terminal_debug( "-> ", t, 1 );
		hx_vector_iter_next( iter );
	}
	hx_free_vector_iter( iter );
	hx_free_vector( v );
}
	
void terminal_test (void) {
	hx_terminal* l	= hx_new_terminal();
	printf( "sizeof terminal list: %d\n", (int) sizeof( hx_terminal ) );
	printf( "terminal list: %p\n", (void*) l );
	hx_terminal_debug( "- ", l, 1 );
	
	hx_terminal_add_node( l, (hx_node_id) 5 );
	hx_terminal_debug( "- ", l, 1 );

	hx_terminal_add_node( l, (hx_node_id) 1 );
	hx_terminal_debug( "- ", l, 1 );

	hx_terminal_add_node( l, (hx_node_id) 2 );
	hx_terminal_debug( "- ", l, 1 );
	
	int i, r, n;
	n	= (hx_node_id) 3;
	r	= hx_terminal_binary_search( l, n, &i );
	printf( "search: %d %d\n", r, i );

	hx_terminal_add_node( l, (hx_node_id) 3 );
	hx_terminal_debug( "- ", l, 1 );

	r	= hx_terminal_binary_search( l, n, &i );
	printf( "search: %d %d\n", r, i );
	
	hx_terminal_remove_node( l, (hx_node_id) 2 );
	hx_terminal_debug( "- ", l, 1 );
	hx_terminal_remove_node( l, (hx_node_id) 3 );
	hx_terminal_debug( "- ", l, 1 );
	hx_terminal_remove_node( l, (hx_node_id) 5 );
	hx_terminal_debug( "- ", l, 1 );
	hx_terminal_remove_node( l, (hx_node_id) 6 );
	hx_terminal_debug( "- ", l, 1 );
	hx_terminal_remove_node( l, (hx_node_id) 1 );
	hx_terminal_debug( "- ", l, 1 );
	
	printf( "grow test...\n" );
	for (int i = 1; i < 260; i++) {
		hx_terminal_add_node( l, (hx_node_id) i );
// 		hx_terminal_debug( "- ", l, 1 );
	}

	printf( "shrink test...\n" );
	for (int i = 101; i < 200; i++) {
		hx_terminal_remove_node( l, (hx_node_id) i );
// 		hx_terminal_debug( "- ", l, 1 );
	}
	for (int i = 100; i >= 0; i--) {
		hx_terminal_remove_node( l, (hx_node_id) i );
// 		hx_terminal_debug( "- ", l, 1 );
	}
	for (int i = 200; i < 260; i++) {
		hx_terminal_remove_node( l, (hx_node_id) i );
// 		hx_terminal_debug( "- ", l, 1 );
	}
	
	for (int i = 1; i < 25; i++) {
		hx_terminal_add_node( l, (hx_node_id) i );
	}
	hx_terminal_iter* iter	= hx_terminal_new_iter( l );
	while (!hx_terminal_iter_finished( iter )) {
		hx_node_id n;
		hx_terminal_iter_current( iter, &n );
		fprintf( stderr, "-> %d\n", (int) n );
		hx_terminal_iter_next( iter );
	}
	hx_free_terminal_iter( iter );
	
	hx_free_terminal( l );
}

