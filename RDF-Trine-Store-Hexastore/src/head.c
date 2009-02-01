#include "head.h"

int _hx_head_grow( hx_head* h );

hx_head* hx_new_head( void ) {
	hx_head* head	= (hx_head*) calloc( 1, sizeof( hx_head ) );
	hx_head_item* p	= (hx_head_item*) calloc( HEAD_LIST_ALLOC_SIZE, sizeof( hx_head_item ) );
	head->ptr		= p;
	head->allocated	= HEAD_LIST_ALLOC_SIZE;
	head->used		= 0;
	return head;
}

int hx_free_head ( hx_head* head ) {
//	fprintf( stderr, "freeing head %p\n", head );
	if (head->ptr != NULL) {
//		fprintf( stderr, "free(head->ptr) called\n" );
		free( head->ptr );
	}
//	fprintf( stderr, "free(head) called\n" );
	free( head );
	return 0;
}


int hx_head_binary_search ( const hx_head* h, const rdf_node n, int* index ) {
	int low		= 0;
	int high	= h->used - 1;
	while (low <= high) {
		int mid	= low + (high - low) / 2;
		if (h->ptr[mid].node > n) {
			high	= mid - 1;
		} else if (h->ptr[mid].node < n) {
			low	= mid + 1;
		} else {
			*index	= mid;
			return 0;
		}
	}
	*index	= low;
	return -1;
}

int hx_head_debug ( const char* header, hx_head* h ) {
	char indent[ strlen(header) * 2 + 5 ];
	fprintf( stderr, "%s{{\n", header );
	sprintf( indent, "%s%s  ", header, header );
	
	for(int i = 0; i < h->used; i++) {
		fprintf( stderr, "%s  %d", header, (int) h->ptr[ i ].node );
		hx_vector_debug( indent, h->ptr[ i ].vector );
		fprintf( stderr, ",\n" );
	}
	fprintf( stderr, "%s}}\n", header );
}

int hx_head_add_vector ( hx_head* h, rdf_node n, hx_vector* v ) {
	int i;
	
	if (n == (rdf_node) 0) {
		fprintf( stderr, "*** rdf_node cannot be zero in hx_head_add_vector\n" );
		return 1;
	}
	
	int r	= hx_head_binary_search( h, n, &i );
	if (r == 0) {
		// already in list. do nothing.
	} else {
		// not found. need to add at index i
		if (h->used >= h->allocated) {
			_hx_head_grow( h );
		}
		
		for (int k = h->used - 1; k >= i; k--) {
			h->ptr[k + 1]	= h->ptr[k];
		}
		h->ptr[i].node		= n;
		h->ptr[i].vector	= v;
		h->used++;
	}
	return 0;
}

hx_vector* hx_head_get_vector ( hx_head* h, rdf_node n ) {
	int i;
	int r	= hx_head_binary_search( h, n, &i );
	if (r == 0) {
		return h->ptr[i].vector;
	} else {
		return NULL;
	}
}

int hx_head_remove_vector ( hx_head* h, rdf_node n ) {
	int i;
	int r	= hx_head_binary_search( h, n, &i );
	if (r == -1) {
		// not in list. do nothing.
	} else {
		// found. need to remove at index i
		hx_free_vector( h->ptr[ i ].vector );
		for (int k = i; k < h->used; k++) {
			h->ptr[ k ]	= h->ptr[ k + 1 ];
		}
		h->used--;
	}
	return 0;
}

int _hx_head_grow( hx_head* h ) {
	size_t size		= h->allocated * 2;
//	fprintf( stderr, "growing head from %d to %d entries\n", (int) h->allocated, (int) size );
	hx_head_item* newp	= (hx_head_item*) calloc( size, sizeof( hx_head_item ) );
	for (int i = 0; i < h->used; i++) {
		newp[ i ]	= h->ptr[ i ];
	}
	free( h->ptr );
	h->ptr		= newp;
	h->allocated	= (list_size_t) size;
	return 0;
}

list_size_t hx_head_size ( hx_head* h ) {
	return h->used;
}

uint64_t hx_head_triples_count ( hx_head* h ) {
	uint64_t count	= 0;
	for (int i = 0; i < h->used; i++) {
		uint64_t c	= hx_vector_triples_count( h->ptr[ i ].vector );
		count	+= c;
	}
	return count;
}

size_t hx_head_memory_size ( hx_head* h ) {
	uint64_t size	= sizeof( hx_head ) + (h->used * sizeof( hx_head_item ));
	for (int i = 0; i < h->used; i++) {
		size	+= hx_vector_memory_size( h->ptr[ i ].vector );
	}
	return size;
}
