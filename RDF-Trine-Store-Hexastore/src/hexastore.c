#include "hexastore.h"


int _hx_terminal_grow( hx_terminal* t );
int _hx_vector_grow( hx_vector* t );
int _hx_head_grow( hx_head* h );

/******************************************************************************/


hx_terminal* hx_new_terminal( void ) {
	hx_terminal* terminal	= (hx_terminal*) calloc( 1, sizeof( hx_terminal ) );
	rdf_node* p	= (rdf_node*) calloc( TERMINAL_LIST_ALLOC_SIZE, sizeof( rdf_node ) );
	terminal->ptr		= p;
	terminal->allocated	= TERMINAL_LIST_ALLOC_SIZE;
	terminal->used		= 0;
	terminal->refcount	= 0;
	return terminal;
}

int hx_free_terminal ( hx_terminal* list ) {
//	fprintf( stderr, "freeing terminal %p\n", list );
	list->refcount--;
//	fprintf( stderr, "refcount is now %d\n", list->refcount );
	if (list->refcount == 0) {
		if (list->ptr != NULL) {
//			fprintf( stderr, "free(list->ptr) called\n" );
			free( list->ptr );
		}
//		fprintf( stderr, "free(list) called\n" );
		free( list );
		return 0;
	} else {
		return 1;
	}
}

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







int hx_terminal_debug ( const char* header, hx_terminal* t, int newline ) {
	fprintf( stderr, "%s[", header );
	for(int i = 0; i < t->used; i++) {
		if (i > 0)
			fprintf( stderr, ", " );
		fprintf( stderr, "%d", (int) t->ptr[ i ] );
	}
	fprintf( stderr, "]" );
	if (newline > 0)
		fprintf( stderr, "\n" );
}

int hx_terminal_add_node ( hx_terminal* t, rdf_node n ) {
	int i;
	int r	= hx_terminal_binary_search( t, n, &i );
	if (r == 0) {
		// already in list. do nothing.
	} else {
		// not found. need to add at index i
//		fprintf( stderr, "list add [used: %d, allocated: %d]\n", (int) t->used, (int) t->allocated );
		if (t->used >= t->allocated) {
			_hx_terminal_grow( t );
		}
		
		for (int k = t->used - 1; k >= i; k--) {
			t->ptr[k + 1]	= t->ptr[k];
		}
		t->ptr[i]	= n;
		t->used++;
	}
	return 0;
}

int hx_terminal_remove_node ( hx_terminal* t, rdf_node n ) {
	int i;
	int r	= hx_terminal_binary_search( t, n, &i );
	if (r == -1) {
		// not in list. do nothing.
	} else {
		// found. need to remove at index i
		for (int k = i; k < t->used; k++) {
			t->ptr[ k ]	= t->ptr[ k + 1 ];
		}
		t->used--;
	}
	return 0;
}

int _hx_terminal_grow( hx_terminal* t ) {
	size_t size		= t->allocated * 2;
//	fprintf( stderr, "growing terminal from %d to %d entries\n", (int) t->allocated, (int) size );
	rdf_node* newp	= (rdf_node*) calloc( size, sizeof( rdf_node ) );
	for (int i = 0; i < t->used; i++) {
		newp[ i ]	= t->ptr[ i ];
	}
//	fprintf( stderr, "free(t->ptr) called\n" );
	free( t->ptr );
	t->ptr		= newp;
	t->allocated	= (list_size_t) size;
	return 0;
}

list_size_t hx_terminal_size ( hx_terminal* t ) {
	return t->used;
}

size_t hx_terminal_memory_size ( hx_terminal* t ) {
	list_size_t size	= sizeof( hx_terminal ) + (t->used * sizeof( rdf_node ));
	return size;
}

int hx_terminal_binary_search ( const hx_terminal* t, const rdf_node n, int* index ) {
	int low		= 0;
	int high	= t->used - 1;
	while (low <= high) {
		int mid	= low + (high - low) / 2;
		if (t->ptr[mid] > n) {
			high	= mid - 1;
		} else if (t->ptr[mid] < n) {
			low	= mid + 1;
		} else {
			*index	= mid;
			return 0;
		}
	}
	*index	= low;
	return -1;
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
