#include "head.h"

#ifdef AVL_ALLOC_COUNT
struct my_allocator {
	void *(*libavl_malloc) (struct libavl_allocator *, size_t libavl_size);
	void (*libavl_free) (struct libavl_allocator *, void *libavl_block);
	size_t count;
};
void* my_libavl_malloc (struct libavl_allocator * libavl_allocator, size_t libavl_size) {
	struct my_allocator* a	= (struct my_allocator*) libavl_allocator;
	a->count	+= libavl_size;
	return malloc( libavl_size );
}
void my_libavl_free (struct libavl_allocator * libavl_allocator, void *libavl_block) {
	free( libavl_block );
}

struct my_allocator libavl_allocator_counting = {
	my_libavl_malloc,
	my_libavl_free,
	(size_t) 0
};
#endif






int _hx_head_item_cmp ( const void* a, const void* b, void* param );
hx_head* hx_new_head( void ) {
	hx_head* head	= (hx_head*) calloc( 1, sizeof( hx_head ) );

#ifdef AVL_ALLOC_COUNT
	head->tree		= avl_create( _hx_head_item_cmp, NULL, &libavl_allocator_counting );
#else
	head->tree		= avl_create( _hx_head_item_cmp, NULL, &avl_allocator_default );
#endif
	
	return head;
}

void _hx_free_head_item (void *avl_item, void *avl_param) {
	hx_head_item* item	= (hx_head_item*) avl_item;
	hx_free_vector( item->vector );
	free( avl_item );
}

int hx_free_head ( hx_head* head ) {
	avl_destroy( head->tree, _hx_free_head_item );
	free( head );
	return 0;
}

// int hx_head_binary_search ( const hx_head* h, const rdf_node n, int* index ) {
// 	int low		= 0;
// 	int high	= h->used - 1;
// 	while (low <= high) {
// 		int mid	= low + (high - low) / 2;
// 		if (h->ptr[mid].node > n) {
// 			high	= mid - 1;
// 		} else if (h->ptr[mid].node < n) {
// 			low	= mid + 1;
// 		} else {
// 			*index	= mid;
// 			return 0;
// 		}
// 	}
// 	*index	= low;
// 	return -1;
// }

int hx_head_debug ( const char* header, hx_head* h ) {
	char indent[ strlen(header) * 2 + 5 ];
	fprintf( stderr, "%s{{\n", header );
	sprintf( indent, "%s%s  ", header, header );

	struct avl_traverser iter;
	avl_t_init( &iter, h->tree );
	hx_head_item* item;
	while ((item = (hx_head_item*) avl_t_next( &iter )) != NULL) {
		fprintf( stderr, "%s  %d", header, (int) item->node );
		hx_vector_debug( indent, item->vector );
		fprintf( stderr, ",\n" );
	}
	fprintf( stderr, "%s}}\n", header );
	return 0;
}

int hx_head_add_vector ( hx_head* h, rdf_node n, hx_vector* v ) {
	hx_head_item* item	= (hx_head_item*) calloc( 1, sizeof( hx_head_item ) );
	item->node		= n;
	item->vector	= v;
	if (avl_insert( h->tree, (void*) item ) != NULL) {
		_hx_free_head_item( item, NULL );
	}
	return 0;
}

hx_vector* hx_head_get_vector ( hx_head* h, rdf_node n ) {
	hx_head_item* item	= (hx_head_item*) avl_find( h->tree, &n );
	if (item == NULL) {
		return NULL;
	} else {
// 		fprintf( stderr, "hx_head_get_vector %d\n", (int) n );
// 		fprintf( stderr, "-> %p\n", (void*) item );
// 		fprintf( stderr, "-> %d\n", (int) item->node );
// 		fprintf( stderr, "-> %p\n", (void*) item->vector );
		hx_vector* v	= item->vector;
		return v;
	}
}

int hx_head_remove_vector ( hx_head* h, rdf_node n ) {
	hx_head_item* item	= avl_delete( h->tree, &n );
	if (item != NULL) {
		_hx_free_head_item( item, NULL );
	}
	return 0;
}

list_size_t hx_head_size ( hx_head* h ) {
	return (list_size_t) avl_count( h->tree );
}

uint64_t hx_head_triples_count ( hx_head* h ) {
	uint64_t count	= 0;
	struct avl_traverser iter;
	avl_t_init( &iter, h->tree );
	hx_head_item* item;
	while ((item = (hx_head_item*) avl_t_next( &iter )) != NULL) {
		uint64_t c	= hx_vector_triples_count( item->vector );
		count	+= c;
	}
	return count;
}

size_t hx_head_memory_size ( hx_head* h ) {
	fprintf( stderr, "*** memory size isn't accurate for AVL-based indices\n" );
	uint64_t size	= sizeof( hx_head );
#ifdef AVL_ALLOC_COUNT
	fprintf( stderr, "libavl memory requests: %d\n", (int) libavl_allocator_counting.count );
	size	+= libavl_allocator_counting.count;
#endif
	struct avl_traverser iter;
	avl_t_init( &iter, h->tree );
	hx_head_item* item;
	while ((item = (hx_head_item*) avl_t_next( &iter )) != NULL) {
		size	+= sizeof( hx_head_item );
		size	+= hx_vector_memory_size( item->vector );
	}
	return size;
}


hx_head_iter* hx_head_new_iter ( hx_head* head ) {
	hx_head_iter* iter	= (hx_head_iter*) calloc( 1, sizeof( hx_head_iter ) );
	iter->head		= head;
	
	avl_t_init( &(iter->t), head->tree );
	avl_t_next( &(iter->t) );
	return iter;
}

int hx_free_head_iter ( hx_head_iter* iter ) {
	free( iter );
	return 0;
}

int hx_head_iter_finished ( hx_head_iter* iter ) {
	return (avl_t_cur( &(iter->t) ) == NULL) ? 1 : 0;
}

int hx_head_iter_current ( hx_head_iter* iter, rdf_node* n, hx_vector** v ) {
	hx_head_item* item	= avl_t_cur( &(iter->t) );
	if (item == NULL) {
		return 1;
	} else {
		*n	= item->node;
		*v	= item->vector;
		return 0;
	}
}

int hx_head_iter_next ( hx_head_iter* iter ) {
	if (avl_t_next( &(iter->t) ) == NULL) {
		return 1;
	} else {
		return 0;
	}
}

int _hx_head_item_cmp ( const void* a, const void* b, void* param ) {
	rdf_node *ia, *ib;
	ia	= (rdf_node*) a;
	ib	= (rdf_node*) b;
	return (*ia - *ib);
}

int hx_head_iter_seek( hx_head_iter* iter, rdf_node n ) {
	hx_head_item* item	= (hx_head_item*) avl_t_find( &(iter->t), iter->head->tree, &n );
	if (item == NULL) {
// 		fprintf( stderr, "hx_head_iter_seek: didn't find item %d\n", (int) n );
		return 1;
	} else {
// 		fprintf( stderr, "hx_head_iter_seek: found item %d\n", (int) n );
		return 0;
	}
}


int hx_head_write( hx_head* h, FILE* f ) {
	fputc( 'H', f );
	list_size_t used	= (list_size_t) avl_count( h->tree );
	fwrite( &used, sizeof( list_size_t ), 1, f );
	hx_head_iter* iter	= hx_head_new_iter( h );
	while (!hx_head_iter_finished( iter )) {
		rdf_node n;
		hx_vector* v;
		hx_head_iter_current( iter, &n, &v );
		fwrite( &n, sizeof( rdf_node ), 1, f );
		hx_vector_write( v, f );
		hx_head_iter_next( iter );
	}
	hx_free_head_iter( iter );
	return 0;
}

hx_head* hx_head_read( FILE* f, int buffer ) {
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
		hx_head* h			= hx_new_head();
		for (int i = 0; i < used; i++) {
			rdf_node n;
			hx_vector* v;
			read	= fread( &n, sizeof( rdf_node ), 1, f );
			if (read == 0 || (v = hx_vector_read( f, buffer )) == NULL) {
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

