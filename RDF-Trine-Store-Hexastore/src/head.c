#include "head.h"

hx_head* hx_new_head( hx_storage_manager* s ) {
	hx_head* head	= (hx_head*) calloc( 1, sizeof( hx_head ) );
	head->storage		= s;
	head->tree		= hx_new_btree_root( s );
// 	fprintf( stderr, ">>> allocated tree %p\n", (void*) head->tree );
	head->triples_count	= 0;
	return head;
}

int hx_free_head ( hx_head* head ) {
// 	fprintf( stderr, "<<< freeing tree %p\n", (void*) head->tree );
	hx_free_btree_node( head->storage, head->tree );
	free( head );
	return 0;
}

int hx_head_debug ( const char* header, hx_head* h ) {
	char indent[ strlen(header) * 2 + 5 ];
	fprintf( stderr, "%s [%d]{{\n", header, (int) h->triples_count );
	sprintf( indent, "%s%s  ", header, header );
	
	hx_node_id key;
	uint64_t value;
	hx_btree_iter* iter	= hx_btree_new_iter( h->storage, h->tree );
	while (!hx_btree_iter_finished(iter)) {
		hx_btree_iter_current( iter, &key, &value );
		hx_vector* v	= hx_storage_block_from_id( h->storage, value );
		fprintf( stderr, "%s  %d", header, (int) key );
		hx_vector_debug( indent, v );
		fprintf( stderr, ",\n" );
		hx_btree_iter_next(iter);
	}
	fprintf( stderr, "%s}}\n", header );
	return 0;
}

int hx_head_add_vector ( hx_head* h, hx_node_id n, hx_vector* v ) {
	uint64_t value	= hx_storage_id_from_block( h->storage, v );
	hx_btree_insert( h->storage, &( h->tree ), n, value );
//	fprintf( stderr, "adding vector: %llu\n", value );
	return 0;
}

hx_vector* hx_head_get_vector ( hx_head* h, hx_node_id n ) {
	uint64_t vector	= hx_btree_search( h->storage, h->tree, n );
//	fprintf( stderr, "got vector: %llu\n", vector );
	hx_vector* v	= hx_storage_block_from_id( h->storage, vector );
	return v;
}

int hx_head_remove_vector ( hx_head* h, hx_node_id n ) {
	int r	= hx_btree_remove( h->storage, &(h->tree), n );
	return r;
}

list_size_t hx_head_size ( hx_head* h ) {
	return hx_btree_size( h->storage, h->tree );
}

uint64_t hx_head_triples_count ( hx_head* h ) {
	return h->triples_count;
}

void hx_head_triples_count_add ( hx_head* h, int c ) {
	h->triples_count	+= c;
}

hx_head_iter* hx_head_new_iter ( hx_head* head ) {
	hx_head_iter* iter	= (hx_head_iter*) calloc( 1, sizeof( hx_head_iter ) );
	iter->head		= head;
	iter->t			= hx_btree_new_iter( head->storage, head->tree );
	return iter;
}

int hx_free_head_iter ( hx_head_iter* iter ) {
	free( iter );
	return 0;
}

int hx_head_iter_finished ( hx_head_iter* iter ) {
	return hx_btree_iter_finished( iter->t );
}

int hx_head_iter_current ( hx_head_iter* iter, hx_node_id* n, hx_vector** v ) {
	uint64_t vector;
	int r	= hx_btree_iter_current( iter->t, n, &vector );
	*v		= hx_storage_block_from_id( iter->head->storage, vector );
	return r;
}

int hx_head_iter_next ( hx_head_iter* iter ) {
	return hx_btree_iter_next( iter->t );
}

int hx_head_iter_seek( hx_head_iter* iter, hx_node_id n ) {
	return hx_btree_iter_seek( iter->t, n );
}


int hx_head_write( hx_head* h, FILE* f ) {
	fputc( 'H', f );
	list_size_t used	= hx_head_size( h );
	fwrite( &used, sizeof( list_size_t ), 1, f );
	fwrite( &( used ), sizeof( uint64_t ), 1, f );
	hx_head_iter* iter	= hx_head_new_iter( h );
	while (!hx_head_iter_finished( iter )) {
		hx_node_id n;
		hx_vector* v;
		hx_head_iter_current( iter, &n, &v );
		fwrite( &n, sizeof( hx_node_id ), 1, f );
		hx_vector_write( v, f );
		hx_head_iter_next( iter );
	}
	hx_free_head_iter( iter );
	return 0;
}

hx_head* hx_head_read( hx_storage_manager* s, FILE* f, int buffer ) {
	size_t read;
	list_size_t used;
	int c	= fgetc( f );
	if (c != 'H') {
		fprintf( stderr, "*** Bad header cookie trying to read head from file.\n" );
		return NULL;
	}
	
	read	= fread( &used, sizeof( list_size_t ), 1, f );
	if (read == 0) {
		return NULL;
	} else {
		hx_head* h	= hx_new_head( s );
		read	= fread( &(h->triples_count), sizeof( uint64_t ), 1, f );
		if (read == 0) {
			return NULL;
		}
		for (int i = 0; i < used; i++) {
			hx_node_id n;
			hx_vector* v;
			read	= fread( &n, sizeof( hx_node_id ), 1, f );
			if (read == 0 || (v = hx_vector_read( s, f, buffer )) == NULL) {
				fprintf( stderr, "*** NULL vector returned while trying to read head from file.\n" );
				hx_free_head( h );
				return NULL;
			} else {
				hx_head_add_vector( h, n, v );
			}
		}
		return h;
	}
}

