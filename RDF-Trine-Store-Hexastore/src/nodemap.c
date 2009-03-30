#include "nodemap.h"

int _hx_nodemap_cmp_nodes ( const void* _a, const void* _b );

// int _sparql_sort_cmp (const void * a, const void * b);
int _hx_node_cmp_id ( const void* a, const void* b, void* param ) {
	hx_nodemap_item* ia	= (hx_nodemap_item*) a;
	hx_nodemap_item* ib	= (hx_nodemap_item*) b;
// 	fprintf( stderr, "hx_node_cmp_id( %d, %d )\n", (int) ia->id, (int) ib->id );
	return (ia->id - ib->id);
}

int _hx_node_cmp_str ( const void* a, const void* b, void* param ) {
	hx_nodemap_item* ia	= (hx_nodemap_item*) a;
	hx_nodemap_item* ib	= (hx_nodemap_item*) b;
	return hx_node_cmp(ia->node, ib->node);
}

void _hx_free_node_item (void *avl_item, void *avl_param) {
	hx_nodemap_item* i	= (hx_nodemap_item*) avl_item;
	if (i->node != NULL) {
		hx_free_node( i->node );
	}
	free( i );
}

hx_nodemap* hx_new_nodemap( void ) {
	hx_nodemap* m	= (hx_nodemap*) calloc( 1, sizeof( hx_nodemap ) );
	m->id2node		= avl_create( _hx_node_cmp_id, NULL, &avl_allocator_default );
	m->node2id		= avl_create( _hx_node_cmp_str, NULL, &avl_allocator_default );
	m->next_id		= (hx_node_id) 1;
	return m;
}

int hx_free_nodemap ( hx_nodemap* m ) {
	avl_destroy( m->id2node, NULL );
	avl_destroy( m->node2id, _hx_free_node_item );
	free( m );
	return 0;
}

hx_node_id hx_nodemap_add_node ( hx_nodemap* m, hx_node* n ) {
	hx_node* node	= hx_node_copy( n );
	hx_nodemap_item i;
	i.node	= node;
	hx_nodemap_item* item	= (hx_nodemap_item*) avl_find( m->node2id, &i );
	if (item == NULL) {
		if (0) {
			char* nodestr;
			hx_node_string( node, &nodestr );
			fprintf( stderr, "nodemap adding key '%s'\n", nodestr );
			free(nodestr);
		}
		
		item	= (hx_nodemap_item*) calloc( 1, sizeof( hx_nodemap_item ) );
		item->node	= node;
		item->id	= m->next_id++;
		avl_insert( m->node2id, item );
		avl_insert( m->id2node, item );
// 		fprintf( stderr, "*** new item %d -> %p\n", (int) item->id, (void*) item->node );
		
		if (0) {
			hx_node_id id	= hx_nodemap_get_node_id( m, node );
			fprintf( stderr, "*** After adding: %d\n", (int) id );
		}
		
		return item->id;
	} else {
		hx_free_node( node );
		return item->id;
	}
}

int hx_nodemap_remove_node_id ( hx_nodemap* m, hx_node_id id ) {
	hx_nodemap_item i;
	i.id	= id;
	hx_nodemap_item* item	= (hx_nodemap_item*) avl_delete( m->id2node, &i );
	if (item != NULL) {
		avl_delete( m->node2id, item );
		_hx_free_node_item( item, NULL );
		return 0;
	} else {
		return 1;
	}
}

int hx_nodemap_remove_node ( hx_nodemap* m, hx_node* n ) {
	hx_nodemap_item i;
	i.node	= n;
	hx_nodemap_item* item	= (hx_nodemap_item*) avl_delete( m->node2id, &i );
	if (item != NULL) {
		avl_delete( m->id2node, item );
		_hx_free_node_item( item, NULL );
		return 0;
	} else {
		return 1;
	}
}

hx_node_id hx_nodemap_get_node_id ( hx_nodemap* m, hx_node* node ) {
	hx_nodemap_item i;
	i.node	= node;
// 	if (0) {
// 		char* nodestr;
// 		hx_node_string( node, &nodestr );
// 		fprintf( stderr, "nodemap getting id for key '%s'\n", nodestr );
// 		free(nodestr);
// 	}
	hx_nodemap_item* item	= (hx_nodemap_item*) avl_find( m->node2id, &i );
	if (item == NULL) {
//		fprintf( stderr, "hx_nodemap_get_node_id: did not find node in nodemap\n" );
		return (hx_node_id) 0;
	} else {
		return item->id;
	}
}

hx_node* hx_nodemap_get_node ( hx_nodemap* m, hx_node_id id ) {
	hx_nodemap_item i;
	i.id	= id;
	i.node	= NULL;
// 	fprintf( stderr, "hx_nodemap_get_node( %p, %d )\n", (void*) m, (int) id );
	hx_nodemap_item* item	= (hx_nodemap_item*) avl_find( m->id2node, &i );
	if (item == NULL) {
// 		fprintf( stderr, "*** node %d string not found\n", (int) id );
		return NULL;
	} else {
// 		fprintf( stderr, "*** node %d string: '%s'\n", (int) id, item->string );
		return item->node;
	}
}

int hx_nodemap_debug ( hx_nodemap* map ) {
	struct avl_traverser iter;
	avl_t_init( &iter, map->id2node );
	hx_nodemap_item* item;
	fprintf( stderr, "Nodemap:\n" );
	while ((item = (hx_nodemap_item*) avl_t_next( &iter )) != NULL) {
		char* string;
		hx_node_string( item->node, &string );
		fprintf( stderr, "\t%d -> %s\n", (int) item->id, string );
		free( string );
	}
	return 0;
}

int hx_nodemap_write( hx_nodemap* m, FILE* f ) {
	fputc( 'M', f );
	size_t used	= avl_count( m->id2node );
	fwrite( &used, sizeof( size_t ), 1, f );
	fwrite( &( m->next_id ), sizeof( hx_node_id ), 1, f );

	struct avl_traverser iter;
	avl_t_init( &iter, m->id2node );
	hx_nodemap_item* item;
	
	while ((item = (hx_nodemap_item*) avl_t_next( &iter )) != NULL) {
		fwrite( &( item->id ), sizeof( hx_node_id ), 1, f );
		hx_node_write( item->node, f );
	}

	return 0;
}

hx_nodemap* hx_nodemap_read( hx_storage_manager* s, FILE* f, int buffer ) {
	size_t used, read;
	hx_node_id next_id;
	int c	= fgetc( f );
	if (c != 'M') {
		fprintf( stderr, "*** Bad header cookie trying to read nodemap from file.\n" );
		return NULL;
	}
	
	hx_nodemap* m	= hx_new_nodemap();
	read	= fread( &used, sizeof( size_t ), 1, f );
	read	= fread( &next_id, sizeof( hx_node_id ), 1, f );
	m->next_id	= next_id;
	for (int i = 0; i < used; i++) {
		hx_nodemap_item* item	= (hx_nodemap_item*) malloc( sizeof( hx_nodemap_item ) );
		if ((read = fread( &( item->id ), sizeof( hx_node_id ), 1, f )) == 0) {
			fprintf( stderr, "*** Failed to read item hx_node_id\n" );
		}
		item->node	= hx_node_read( f, 0 );
		avl_insert( m->node2id, item );
		avl_insert( m->id2node, item );
	}
	return m;
}

hx_nodemap* hx_nodemap_sparql_order_nodes ( hx_nodemap* map ) {
	size_t count	= avl_count( map->id2node );
	hx_node** node_handles	= calloc( count, sizeof( hx_node* ) );
	int i	= 0;
	struct avl_traverser iter;
	avl_t_init( &iter, map->id2node );
	hx_nodemap_item* item;
	
	while ((item = (hx_nodemap_item*) avl_t_next( &iter )) != NULL) {
		node_handles[ i++ ]	= item->node;
	}
	qsort( node_handles, i, sizeof( hx_node* ), _hx_nodemap_cmp_nodes );
	hx_nodemap* sorted	= hx_new_nodemap();
	for (int j = 0; j < i; j++) {
		hx_nodemap_add_node( sorted, node_handles[ j ] );
	}
	free( node_handles );
	return sorted;
}

int _hx_nodemap_cmp_nodes ( const void* _a, const void* _b ) {
	hx_node** a	= (hx_node**) _a;
	hx_node** b	= (hx_node**) _b;
	return hx_node_cmp( *a, *b );
}
