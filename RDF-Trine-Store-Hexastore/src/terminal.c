#include "terminal.h"

hx_terminal* hx_new_terminal( hx_storage_manager* s ) {
	hx_terminal* terminal	= (hx_terminal*) hx_storage_new_block( s, sizeof( hx_terminal ) );
	terminal->storage		= s;
	terminal->tree			= hx_new_btree( s, TERMINAL_TREE_BRANCHING_SIZE );
	terminal->refcount		= 0;
	terminal->triples_count	= 0;
	return terminal;
}

int hx_free_terminal ( hx_terminal* t ) {
	hx_free_btree( t->storage, t->tree );
	hx_storage_release_block( t->storage, t );
	return 0;
}

int hx_terminal_inc_refcount ( hx_terminal* t ) {
	return ++(t->refcount);
}

int hx_terminal_dec_refcount ( hx_terminal* t ) {
	--(t->refcount);
	if (t->refcount <= 0) {
		hx_free_terminal( t );
	}
	return 0;
}

int hx_terminal_debug ( const char* header, hx_terminal* t, int newline ) {
	fprintf( stderr, "%s[", header );
	hx_terminal_iter* iter	= hx_terminal_new_iter( t );
	int i	= 0;
	while (!hx_terminal_iter_finished( iter )) {
		hx_node_id n;
		hx_terminal_iter_current( iter, &n );
		if (i > 0)
			fprintf( stderr, ", " );
		fprintf( stderr, "%d", (int) n );
		hx_terminal_iter_next( iter );
		i++;
	}
	hx_free_terminal_iter( iter );
	fprintf( stderr, "]" );
	if (newline > 0)
		fprintf( stderr, "\n" );
	return 0;
}

int hx_terminal_add_node ( hx_terminal* t, hx_node_id n ) {
	int i;
	
	if (n == (hx_node_id) 0) {
		fprintf( stderr, "*** hx_node_id cannot be zero in hx_terminal_add_node\n" );
		return 1;
	}
	
	int r	= hx_btree_insert( t->storage, t->tree, n, (uint64_t) 1 );
	if (r == 0) {
		t->triples_count++;
	}
	return r;
}

int hx_terminal_contains_node ( hx_terminal* t, hx_node_id n ) {
	uint64_t r	= hx_btree_search( t->storage, t->tree, n );
	if (r == 0) {
		// not found
		return 0;
	} else {
		// found
		return 1;
	}
}

int hx_terminal_remove_node ( hx_terminal* t, hx_node_id n ) {
//	fprintf( stderr, "%p\n", t->tree->root );
	int r	= hx_btree_remove( t->storage, t->tree, n );
//	fprintf( stderr, "after removing node from terminal, tree root = %p\n", t->tree->root );
	if (r == 0) {
		t->triples_count--;
	}
	return r;
}

list_size_t hx_terminal_size ( hx_terminal* t ) {
	return t->triples_count;
}

hx_terminal_iter* hx_terminal_new_iter ( hx_terminal* t ) {
	hx_terminal_iter* iter	= (hx_terminal_iter*) calloc( 1, sizeof( hx_terminal_iter ) );
	iter->terminal	= t;
	iter->t			= hx_btree_new_iter( t->storage, t->tree );
	return iter;
}

int hx_free_terminal_iter ( hx_terminal_iter* iter ) {
	hx_free_btree_iter( iter->t );
	free( iter );
	return 0;
}

int hx_terminal_iter_finished ( hx_terminal_iter* iter ) {
	return hx_btree_iter_finished( iter->t );
}

int hx_terminal_iter_current ( hx_terminal_iter* iter, hx_node_id* n ) {
	return hx_btree_iter_current( iter->t, n, NULL );
}

int hx_terminal_iter_next ( hx_terminal_iter* iter ) {
	return hx_btree_iter_next( iter->t );
}

int hx_terminal_iter_seek( hx_terminal_iter* iter, hx_node_id n ) {
	return hx_btree_iter_seek( iter->t, n );
}


int hx_terminal_write( hx_terminal* t, FILE* f ) {
	fputc( 'T', f );
	fwrite( &( t->triples_count ), sizeof( list_size_t ), 1, f );
	
	hx_terminal_iter* iter	= hx_terminal_new_iter( t );
	while (!hx_terminal_iter_finished( iter )) {
		hx_node_id n;
		hx_terminal_iter_current( iter, &n );
		fwrite( &n, sizeof( hx_node_id ), 1, f );
		hx_terminal_iter_next( iter );
	}
	hx_free_terminal_iter( iter );
	return 0;
}

hx_terminal* hx_terminal_read( hx_storage_manager* s, FILE* f, int buffer ) {
	list_size_t used;
	int c	= fgetc( f );
	if (c != 'T') {
		fprintf( stderr, "*** Bad header cookie trying to read terminal from file.\n" );
		return NULL;
	}
	
	size_t read	= fread( &used, sizeof( list_size_t ), 1, f );
	if (read == 0) {
		return NULL;
	} else {
		list_size_t allocated;
		if (buffer == 0) {
			allocated	= used;
		} else {
			allocated	= used * 1.5;
		}
		
		hx_terminal* terminal	= hx_new_terminal( s );
		hx_node_id* p	= (hx_node_id*) calloc( used, sizeof( hx_node_id ) );
		size_t ptr_read	= fread( p, sizeof( hx_node_id ), used, f );
		if (ptr_read == 0) {
			hx_free_terminal( terminal );
			return NULL;
		} else {
			for (int i = 0; i < used; i++) {
				hx_terminal_add_node( terminal, p[i] );
			}
			free( p );
			return terminal;
		}
	}
}

