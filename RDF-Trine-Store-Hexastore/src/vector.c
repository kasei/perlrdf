#include "vector.h"

int _hx_vector_grow( hx_vector* t );


hx_vector* hx_new_vector( void ) {
	hx_vector* head	= (hx_vector*) calloc( 1, sizeof( hx_vector ) );
	hx_vector_item* p	= (hx_vector_item*) calloc( VECTOR_LIST_ALLOC_SIZE, sizeof( hx_vector_item ) );
	head->ptr		= p;
	head->allocated	= VECTOR_LIST_ALLOC_SIZE;
	head->used		= 0;
	return head;
}

int hx_free_vector ( hx_vector* vector ) {
//	fprintf( stderr, "freeing vector %p\n", vector );
	for (int i = 0; i < vector->used; i++) {
		hx_free_terminal( vector->ptr[ i ].terminal );
	}
	if (vector->ptr != NULL) {
//		fprintf( stderr, "free(vector->ptr) called\n" );
		free( vector->ptr );
	}
//	fprintf( stderr, "free(vector) called\n" );
	free( vector );
	return 0;
}

int hx_vector_debug ( const char* header, hx_vector* v ) {
	fprintf( stderr, "%s[\n", header );
	for(int i = 0; i < v->used; i++) {
		fprintf( stderr, "%s  %d", header, (int) v->ptr[ i ].node );
		hx_terminal_debug( " -> ", v->ptr[ i ].terminal, 0 );
		fprintf( stderr, ",\n" );
	}
	fprintf( stderr, "%s]\n", header );
}

int hx_vector_add_terminal ( hx_vector* v, rdf_node n, hx_terminal* t ) {
	int i;
	int r	= hx_vector_binary_search( v, n, &i );
	if (r == 0) {
		// already in list. do nothing.
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
		v->used++;
	}
	return 0;
}

hx_terminal* hx_vector_get_terminal ( hx_vector* v, rdf_node n ) {
	int i;
	int r	= hx_vector_binary_search( v, n, &i );
	if (r == 0) {
		return v->ptr[i].terminal;
	} else {
		return NULL;
	}
}

int hx_vector_remove_terminal ( hx_vector* v, rdf_node n ) {
	int i;
	int r	= hx_vector_binary_search( v, n, &i );
	if (r == -1) {
		// not in list. do nothing.
	} else {
		// found. need to remove at index i
//		fprintf( stderr, "removing terminal list %d from vector\n", (int) n );
		hx_free_terminal( v->ptr[ i ].terminal );
		for (int k = i; k < v->used; k++) {
			v->ptr[ k ]	= v->ptr[ k + 1 ];
		}
		v->used--;
	}
	return 0;
}

list_size_t hx_vector_size ( hx_vector* v ) {
	return v->used;
}

uint64_t hx_vector_triples_count ( hx_vector* v ) {
	uint64_t count	= 0;
	for (int i = 0; i < v->used; i++) {
		uint64_t c	= hx_terminal_size( v->ptr[ i ].terminal );
		count	+= c;
	}
	return count;
}

size_t hx_vector_memory_size ( hx_vector* v ) {
	uint64_t size	= sizeof( hx_vector ) + (v->used * sizeof( hx_vector_item ));
	for (int i = 0; i < v->used; i++) {
		size	+= hx_terminal_memory_size( v->ptr[ i ].terminal );
	}
	return size;
}

int hx_vector_binary_search ( const hx_vector* v, const rdf_node n, int* index ) {
	int low		= 0;
	int high	= v->used - 1;
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

