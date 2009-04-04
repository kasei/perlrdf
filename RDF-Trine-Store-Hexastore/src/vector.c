#include "vector.h"

hx_vector* hx_new_vector( hx_storage_manager* s ) {
	hx_vector* vector	= (hx_vector*) hx_storage_new_block( s, sizeof( hx_vector ) );
	vector->storage		= s;
	vector->tree		= hx_new_btree( s, VECTOR_TREE_BRANCHING_SIZE );
// 	fprintf( stderr, ">>> allocated tree %p\n", (void*) vector->tree );
	vector->triples_count	= 0;
	return vector;
}

int hx_free_vector ( hx_vector* vector ) {
//	fprintf( stderr, "freeing vector %p\n", vector );
	hx_node_id key;
	uint64_t value;
	hx_btree_iter* iter	= hx_btree_new_iter( vector->storage, vector->tree );
	while (!hx_btree_iter_finished(iter)) {
		hx_btree_iter_current( iter, &key, &value );
		hx_terminal* t	= hx_storage_block_from_id( vector->storage, value );
		hx_terminal_dec_refcount( t );
		hx_btree_iter_next(iter);
	}
	hx_free_btree_iter( iter );
	hx_free_btree( vector->storage, vector->tree );
	hx_storage_release_block( vector->storage, vector );
	return 0;
}

int hx_vector_debug ( const char* header, const hx_vector* v ) {
	hx_node_id key;
	uint64_t value;
	fprintf( stderr, "%s[\n", header );
	
	hx_btree_iter* iter	= hx_btree_new_iter( v->storage, v->tree );
	while (!hx_btree_iter_finished(iter)) {
		hx_btree_iter_current( iter, &key, &value );
		hx_terminal* t	= hx_storage_block_from_id( v->storage, value );
		fprintf( stderr, "%s  %d", header, (int) key );
		hx_terminal_debug( " -> ", t, 0 );
		fprintf( stderr, ",\n" );
		hx_btree_iter_next(iter);
	}
	hx_free_btree_iter( iter );
	fprintf( stderr, "%s]\n", header );
	return 0;
}

int hx_vector_add_terminal ( hx_vector* v, const hx_node_id n, hx_terminal* t ) {
	uint64_t value	= hx_storage_id_from_block( v->storage, t );
//	fprintf( stderr, "adding terminal: %llu\n", value );
	int r	= hx_btree_insert( v->storage, v->tree, n, value );
	if (r == 0) {
		// added OK.
		hx_terminal_inc_refcount( t );
	}
	return r;
}

hx_terminal* hx_vector_get_terminal ( hx_vector* v, hx_node_id n ) {
	uint64_t terminal	= hx_btree_search( v->storage, v->tree, n );
//	fprintf( stderr, "got terminal: %llu\n", terminal );
	hx_terminal* t	= hx_storage_block_from_id( v->storage, terminal );
	return t;
}

int hx_vector_remove_terminal ( hx_vector* v, hx_node_id n ) {
	hx_terminal* t	= hx_vector_get_terminal( v, n );
	if (t != NULL) {
		// removed OK.
		hx_terminal_dec_refcount( t );
		return 0;
	} else {
		return 1;
	}
}

list_size_t hx_vector_size ( hx_vector* v ) {
	return hx_btree_size( v->storage, v->tree );
}

uint64_t hx_vector_triples_count ( hx_vector* v ) {
	return v->triples_count;
}

void hx_vector_triples_count_add ( hx_vector* v, int c ) {
	v->triples_count	+= c;
}

hx_vector_iter* hx_vector_new_iter ( hx_vector* vector ) {
	hx_vector_iter* iter	= (hx_vector_iter*) calloc( 1, sizeof( hx_vector_iter ) );
	iter->vector	= vector;
	iter->t			= hx_btree_new_iter( vector->storage, vector->tree );
	return iter;
}

int hx_free_vector_iter ( hx_vector_iter* iter ) {
	hx_free_btree_iter( iter->t );
	free( iter );
	return 0;
}

int hx_vector_iter_finished ( hx_vector_iter* iter ) {
	return hx_btree_iter_finished( iter->t );
}

int hx_vector_iter_current ( hx_vector_iter* iter, hx_node_id* n, hx_terminal** t ) {
	uint64_t terminal;
	int r	= hx_btree_iter_current( iter->t, n, &terminal );
	*t		= hx_storage_block_from_id( iter->vector->storage, terminal );
	return r;
}

int hx_vector_iter_next ( hx_vector_iter* iter ) {
	return hx_btree_iter_next( iter->t );
}

int hx_vector_iter_seek( hx_vector_iter* iter, hx_node_id n ) {
	return hx_btree_iter_seek( iter->t, n );
}

int hx_vector_write( hx_vector* v, FILE* f ) {
	fputc( 'V', f );
	list_size_t used	= hx_vector_size( v );
	fwrite( &used, sizeof( list_size_t ), 1, f );
	fwrite( &( v->triples_count ), sizeof( uint64_t ), 1, f );
	hx_vector_iter* iter	= hx_vector_new_iter( v );
	while (!hx_vector_iter_finished( iter )) {
		hx_node_id n;
		hx_terminal* t;
		hx_vector_iter_current( iter, &n, &t );
		fwrite( &n, sizeof( hx_node_id ), 1, f );
		hx_terminal_write( t, f );
		hx_vector_iter_next( iter );
	}
	hx_free_vector_iter( iter );
	return 0;
}

hx_vector* hx_vector_read( hx_storage_manager* s, FILE* f, int buffer ) {
	size_t read;
	list_size_t used;
	int c	= fgetc( f );
	if (c != 'V') {
		fprintf( stderr, "*** Bad header cookie trying to read vector from file.\n" );
		return NULL;
	}
	
	read	= fread( &used, sizeof( list_size_t ), 1, f );
	if (read == 0) {
		return NULL;
	} else {
		hx_vector* v	= hx_new_vector( s );
		read	= fread( &(v->triples_count), sizeof( uint64_t ), 1, f );
		if (read == 0) {
			return NULL;
		}
		for (int i = 0; i < used; i++) {
			hx_node_id n;
			hx_terminal* t;
			read	= fread( &n, sizeof( hx_node_id ), 1, f );
			if (read == 0 || (t = hx_terminal_read( s, f, buffer )) == NULL) {
				fprintf( stderr, "*** NULL terminal returned while trying to read vector from file.\n" );
				hx_free_vector( v );
				return NULL;
			} else {
				hx_vector_add_terminal( v, n, t );
			}
		}
		return v;
	}
}

