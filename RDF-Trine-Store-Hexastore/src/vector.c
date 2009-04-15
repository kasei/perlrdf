#include "vector.h"

hx_vector* hx_new_vector( hx_storage_manager* s ) {
	hx_vector* vector	= (hx_vector*) hx_storage_new_block( s, sizeof( hx_vector ) );
	hx_btree* tree		= hx_new_btree( s, VECTOR_TREE_BRANCHING_SIZE );
	vector->tree		= hx_storage_id_from_block( s, tree );
// 	fprintf( stderr, ">>> allocated tree %p\n", (void*) vector->tree );
	vector->triples_count	= 0;
	return vector;
}

int hx_free_vector ( hx_vector* vector, hx_storage_manager* st ) {
//	fprintf( stderr, "freeing vector %p\n", vector );
	hx_node_id key;
	hx_storage_id_t value;
	hx_btree_iter* iter	= hx_btree_new_iter( st, hx_storage_block_from_id( st, vector->tree ) );
	while (!hx_btree_iter_finished(iter)) {
		hx_btree_iter_current( iter, &key, &value );
		hx_terminal* t	= hx_storage_block_from_id( st, value );
		hx_terminal_dec_refcount( t, st );
		hx_btree_iter_next(iter);
	}
	hx_free_btree_iter( iter );
	hx_free_btree( st, hx_storage_block_from_id( st, vector->tree ) );
	hx_storage_release_block( st, vector );
	return 0;
}

int hx_vector_debug ( const char* header, const hx_vector* v, hx_storage_manager* st ) {
	hx_node_id key;
	hx_storage_id_t value;
	fprintf( stderr, "%s[\n", header );
	
	hx_btree_iter* iter	= hx_btree_new_iter( st, hx_storage_block_from_id( st, v->tree ) );
	while (!hx_btree_iter_finished(iter)) {
		hx_btree_iter_current( iter, &key, &value );
		hx_terminal* t	= hx_storage_block_from_id( st, value );
		fprintf( stderr, "%s  %d", header, (int) key );
		hx_terminal_debug( " -> ", t, st, 0 );
		fprintf( stderr, ",\n" );
		hx_btree_iter_next(iter);
	}
	hx_free_btree_iter( iter );
	fprintf( stderr, "%s]\n", header );
	return 0;
}

int hx_vector_add_terminal ( hx_vector* v, hx_storage_manager* st, const hx_node_id n, hx_terminal* t ) {
	hx_storage_id_t value	= hx_storage_id_from_block( st, t );
//	fprintf( stderr, "adding terminal: %llu\n", value );
	int r	= hx_btree_insert( st, hx_storage_block_from_id( st, v->tree ), n, value );
	if (r == 0) {
		// added OK.
		hx_terminal_inc_refcount( t, st );
	}
	return r;
}

hx_terminal* hx_vector_get_terminal ( hx_vector* v, hx_storage_manager* st, hx_node_id n ) {
	hx_storage_id_t terminal	= hx_btree_search( st, hx_storage_block_from_id( st, v->tree ), n );
//	fprintf( stderr, "got terminal: %llu\n", terminal );
	hx_terminal* t	= hx_storage_block_from_id( st, terminal );
	return t;
}

int hx_vector_remove_terminal ( hx_vector* v, hx_storage_manager* st, hx_node_id n ) {
	hx_terminal* t	= hx_vector_get_terminal( v, st, n );
	if (t != NULL) {
		hx_terminal_dec_refcount( t, st );
		hx_btree_remove( st, hx_storage_block_from_id( st, v->tree ), n );
		return 0;
	} else {
		return 1;
	}
}

list_size_t hx_vector_size ( hx_vector* v, hx_storage_manager* st ) {
	return hx_btree_size( st, hx_storage_block_from_id( st, v->tree ) );
}

hx_storage_id_t hx_vector_triples_count ( hx_vector* v, hx_storage_manager* st ) {
	return v->triples_count;
}

void hx_vector_triples_count_add ( hx_vector* v, hx_storage_manager* st, int c ) {
	v->triples_count	+= c;
}

hx_vector_iter* hx_vector_new_iter ( hx_vector* vector, hx_storage_manager* st ) {
	hx_vector_iter* iter	= (hx_vector_iter*) calloc( 1, sizeof( hx_vector_iter ) );
	iter->vector	= vector;
	iter->storage	= st;
	iter->t			= hx_btree_new_iter( st, hx_storage_block_from_id( st, vector->tree ) );
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
	hx_storage_id_t terminal;
	int r	= hx_btree_iter_current( iter->t, n, &terminal );
	*t		= hx_storage_block_from_id( iter->storage, terminal );
	return r;
}

int hx_vector_iter_next ( hx_vector_iter* iter ) {
	return hx_btree_iter_next( iter->t );
}

int hx_vector_iter_seek( hx_vector_iter* iter, hx_node_id n ) {
	return hx_btree_iter_seek( iter->t, n );
}

int hx_vector_write( hx_vector* v, hx_storage_manager* st, FILE* f ) {
	fputc( 'V', f );
	list_size_t used	= hx_vector_size( v, st );
	fwrite( &used, sizeof( list_size_t ), 1, f );
	fwrite( &( v->triples_count ), sizeof( hx_storage_id_t ), 1, f );
	hx_vector_iter* iter	= hx_vector_new_iter( v, st );
	while (!hx_vector_iter_finished( iter )) {
		hx_node_id n;
		hx_terminal* t;
		hx_vector_iter_current( iter, &n, &t );
		fwrite( &n, sizeof( hx_node_id ), 1, f );
		hx_terminal_write( t, st, f );
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
		read	= fread( &(v->triples_count), sizeof( hx_storage_id_t ), 1, f );
		if (read == 0) {
			return NULL;
		}
		for (int i = 0; i < used; i++) {
			hx_node_id n;
			hx_terminal* t;
			read	= fread( &n, sizeof( hx_node_id ), 1, f );
			if (read == 0 || (t = hx_terminal_read( s, f, buffer )) == NULL) {
				fprintf( stderr, "*** NULL terminal returned while trying to read vector from file.\n" );
				hx_free_vector( v, s );
				return NULL;
			} else {
				hx_vector_add_terminal( v, s, n, t );
			}
		}
		return v;
	}
}

