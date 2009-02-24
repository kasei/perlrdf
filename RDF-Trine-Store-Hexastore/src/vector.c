#include "vector.h"

int _hx_vector_grow( hx_vector* t );
int _hx_vector_iter_prime_first_result( hx_vector_iter* iter );
int _hx_vector_binary_search ( const hx_vector* v, const hx_node_id n, int* index );


hx_vector* hx_new_vector( void ) {
	hx_vector* vector		= (hx_vector*) calloc( 1, sizeof( hx_vector ) );
	hx_vector_item* p		= (hx_vector_item*) calloc( VECTOR_LIST_ALLOC_SIZE, sizeof( hx_vector_item ) );
	vector->ptr				= p;
	vector->allocated		= VECTOR_LIST_ALLOC_SIZE;
	vector->used			= 0;
	vector->triples_count	= 0;
	return vector;
}

int hx_free_vector ( hx_vector* vector ) {
//	fprintf( stderr, "freeing vector %p\n", vector );
	for (int i = 0; i < vector->used; i++) {
		(vector->ptr[ i ].terminal->refcount)--;
		hx_free_terminal( vector->ptr[ i ].terminal );
	}
	free( vector->ptr );
	free( vector );
	return 0;
}

int hx_vector_debug ( const char* header, const hx_vector* v ) {
	fprintf( stderr, "%s (%d/%d)[\n", header, (int) v->used, (int) v->allocated );
	for(int i = 0; i < v->used; i++) {
		fprintf( stderr, "%s  %d", header, (int) v->ptr[ i ].node );
		hx_terminal_debug( " -> ", v->ptr[ i ].terminal, 0 );
		fprintf( stderr, ",\n" );
	}
	fprintf( stderr, "%s]\n", header );
	return 0;
}

int hx_vector_add_terminal ( hx_vector* v, const hx_node_id n, hx_terminal* t ) {
	int i;
	
	if (n == (hx_node_id) 0) {
		fprintf( stderr, "*** hx_node_id cannot be zero in hx_vector_add_terminal\n" );
		return 1;
	}
	
	int r	= _hx_vector_binary_search( v, n, &i );
	if (r == 0) {
		// already in list. do nothing.
		return 1;
	} else {
		// not found. need to add at index i
//		fprintf( stderr, "vector add [used: %d, allocated: %d]\n", (int) v->used, (int) v->allocated );
		if (v->used >= v->allocated) {
			_hx_vector_grow( v );
		}
		
		for (int k = v->used - 1; k >= i; k--) {
			v->ptr[k + 1]	= v->ptr[k];
		}
		v->ptr[i].node		= n;
		v->ptr[i].terminal	= t;
		(v->ptr[i].terminal->refcount)++;
//		fprintf( stderr, "refcount of terminal list is now %d\n", (int) v->ptr[i].terminal->refcount );
//		fprintf( stderr, "*** (hx_vector_add_terminal) increasing used count\n" );
		v->used++;
	}
	return 0;
}

hx_terminal* hx_vector_get_terminal ( hx_vector* v, hx_node_id n ) {
	int i;
	int r	= _hx_vector_binary_search( v, n, &i );
	if (r == 0) {
		return v->ptr[i].terminal;
	} else {
		return NULL;
	}
}

int hx_vector_remove_terminal ( hx_vector* v, hx_node_id n ) {
	int i;
	int r	= _hx_vector_binary_search( v, n, &i );
	if (r == -1) {
		// not in list. do nothing.
	} else {
		// found. need to remove at index i
//		fprintf( stderr, "removing terminal list %d from vector\n", (int) n );
		(v->ptr[ i ].terminal->refcount)--;
		hx_free_terminal( v->ptr[ i ].terminal );
		for (int k = i; k < v->used; k++) {
			v->ptr[ k ]	= v->ptr[ k + 1 ];
		}
//		fprintf( stderr, "*** (hx_vector_add_terminal) decreasing used count\n" );
		v->used--;
	}
	return 0;
}

list_size_t hx_vector_size ( hx_vector* v ) {
	return v->used;
}

uint64_t hx_vector_triples_count ( hx_vector* v ) {
	return v->triples_count;
// 	uint64_t count	= 0;
// 	for (int i = 0; i < v->used; i++) {
// 		uint64_t c	= hx_terminal_size( v->ptr[ i ].terminal );
// 		count	+= c;
// 	}
// 	return count;
}

void hx_vector_triples_count_add ( hx_vector* v, int c ) {
	v->triples_count	+= c;
}

int _hx_vector_binary_search ( const hx_vector* v, const hx_node_id n, int* index ) {
	int low		= 0;
	int high	= v->used - 1;
//	fprintf( stderr, "_hx_vector_binary_search: %p\n", (void*) v );
//	hx_vector_debug( "*** ", v );
	
	while (low <= high) {
		int mid	= low + (high - low) / 2;
		if (v->ptr[mid].node > n) {
			high	= mid - 1;
		} else if (v->ptr[mid].node < n) {
			low	= mid + 1;
		} else {
			*index	= mid;
			return 0;
		}
	}
	*index	= low;
	return -1;
}

int _hx_vector_grow( hx_vector* v ) {
	size_t size		= v->allocated * 2;
//	fprintf( stderr, "growing vector from %d to %d entries\n", (int) v->allocated, (int) size );
	hx_vector_item* newp	= (hx_vector_item*) calloc( size, sizeof( hx_vector_item ) );
	for (int i = 0; i < v->used; i++) {
		newp[ i ]	= v->ptr[ i ];
	}
//	fprintf( stderr, "free(v->ptr) called\n" );
	free( v->ptr );
	v->ptr		= newp;
	v->allocated	= (list_size_t) size;
	return 0;
}


hx_vector_iter* hx_vector_new_iter ( hx_vector* vector ) {
	if (vector == NULL) {
		fprintf( stderr, "*** NULL vector passed to hx_vector_new_iter" );
		return NULL;
	}
	hx_vector_iter* iter	= (hx_vector_iter*) calloc( 1, sizeof( hx_vector_iter ) );
	iter->started		= 0;
	iter->finished		= 0;
	iter->vector		= vector;
	return iter;
}

int hx_free_vector_iter ( hx_vector_iter* iter ) {
	free( iter );
	return 0;
}

int hx_vector_iter_finished ( hx_vector_iter* iter ) {
	if (iter->started == 0) {
		_hx_vector_iter_prime_first_result( iter );
	}
	return iter->finished;
}

int _hx_vector_iter_prime_first_result( hx_vector_iter* iter ) {
// 	fprintf( stderr, "_hx_vector_iter_prime_first_result( %p )\n", (void*) iter );
// 	fprintf( stderr, "vector: %p\n", (void*) iter->vector );
	iter->started	= 1;
	iter->index		= 0;
	if (iter->vector->used == 0) {
		iter->finished	= 1;
		return 1;
	}
	return 0;
}

int hx_vector_iter_current ( hx_vector_iter* iter, hx_node_id* n, hx_terminal** t ) {
	if (iter->started == 0) {
		_hx_vector_iter_prime_first_result( iter );
	}
	if (iter->finished == 1) {
		return 1;
	} else {
		*t	= iter->vector->ptr[ iter->index ].terminal;
		*n	= iter->vector->ptr[ iter->index ].node;
		return 0;
	}
}

int hx_vector_iter_next ( hx_vector_iter* iter ) {
	if (iter->started == 0) {
		_hx_vector_iter_prime_first_result( iter );
		if (iter->finished == 1) {
			return 1;
		}
	}
	
	if (iter->index >= (iter->vector->used - 1)) {
		// vector is exhausted
		iter->finished	= 1;
		iter->vector	= NULL;
		return 1;
	} else {
		iter->index++;
		return 0;
	}
}

int hx_vector_iter_seek( hx_vector_iter* iter, hx_node_id n ) {
	int i;
	int r	= _hx_vector_binary_search( iter->vector, n, &i );
	if (r == 0) {
//		fprintf( stderr, "hx_vector_iter_seek: found in list at index %d\n", i );
		iter->started	= 1;
		iter->index		= i;
		return 0;
	} else {
//		fprintf( stderr, "hx_vector_iter_seek: didn't find in list\n" );
		return 1;
	}
}

int hx_vector_write( hx_vector* v, FILE* f ) {
	fputc( 'V', f );
	fwrite( &( v->used ), sizeof( list_size_t ), 1, f );
	fwrite( &( v->triples_count ), sizeof( uint64_t ), 1, f );
	for (int i = 0; i < v->used; i++) {
		fwrite( &( v->ptr[i].node ), sizeof( hx_node_id ), 1, f );
		hx_terminal_write( v->ptr[i].terminal, f );
	}
	return 0;
}

hx_vector* hx_vector_read( FILE* f, int buffer ) {
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

		list_size_t allocated;
		if (buffer == 0) {
			allocated	= used;
		} else {
			allocated	= used * 1.5;
		}
		
		hx_vector* vector	= (hx_vector*) calloc( 1, sizeof( hx_vector ) );
		hx_vector_item* p	= (hx_vector_item*) calloc( allocated, sizeof( hx_vector_item ) );
		read	= fread( &(vector->triples_count), sizeof( uint64_t ), 1, f );
		if (read == 0) {
			return NULL;
		}
		vector->ptr			= p;
		vector->allocated	= allocated;
		vector->used		= 0;
		
		for (int i = 0; i < used; i++) {
			read	= fread( &( vector->ptr[i].node ), sizeof( hx_node_id ), 1, f );
			if (read == 0 || (vector->ptr[i].terminal	= hx_terminal_read( f, buffer )) == NULL) {
				fprintf( stderr, "*** NULL terminal returned while trying to read vector from file.\n" );
				hx_free_vector( vector );
				return NULL;
			} else {
				vector->used++;
			}
		}
		return vector;
	}
}

