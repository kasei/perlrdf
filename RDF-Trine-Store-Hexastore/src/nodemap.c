#include "nodemap.h"

int _hx_node_cmp_id ( const void* a, const void* b, void* param ) {
	hx_nodemap_item* ia	= (hx_nodemap_item*) a;
	hx_nodemap_item* ib	= (hx_nodemap_item*) b;
// 	fprintf( stderr, "hx_node_cmp_id( %d, %d )\n", (int) ia->id, (int) ib->id );
	return (ia->id - ib->id);
}

int _hx_node_cmp_str ( const void* a, const void* b, void* param ) {
	hx_nodemap_item* ia	= (hx_nodemap_item*) a;
	hx_nodemap_item* ib	= (hx_nodemap_item*) b;
// 	fprintf( stderr, "hx_node_cmp_str( %s, %s )\n", ia->string, ib->string );
	return strcmp(ia->string, ib->string);
}

void _hx_free_node_item (void *avl_item, void *avl_param) {
	hx_nodemap_item* i	= (hx_nodemap_item*) avl_item;
	if (i->string != NULL)
		free( i->string );
	free( i );
}

hx_nodemap* hx_new_nodemap( void ) {
	hx_nodemap* m	= (hx_nodemap*) calloc( 1, sizeof( hx_nodemap ) );
	m->id2node		= avl_create( _hx_node_cmp_id, NULL, &avl_allocator_default );
	m->node2id		= avl_create( _hx_node_cmp_str, NULL, &avl_allocator_default );
	m->next_id		= (rdf_node_id) 1;
	return m;
}

int hx_free_nodemap ( hx_nodemap* m ) {
	avl_destroy( m->id2node, NULL );
	avl_destroy( m->node2id, _hx_free_node_item );
	free( m );
	return 0;
}

rdf_node_id hx_nodemap_add_node ( hx_nodemap* m, char* nodestr ) {
	hx_nodemap_item i;
	i.string	= nodestr;
	hx_nodemap_item* item	= (hx_nodemap_item*) avl_find( m->node2id, &i );
	if (item == NULL) {
// 		fprintf( stderr, "nodemap adding key '%s'\n", nodestr );
		item	= (hx_nodemap_item*) calloc( 1, sizeof( hx_nodemap_item ) );
		item->string	= malloc( strlen( nodestr ) + 1 );
		strcpy( item->string, nodestr );
		item->id		= m->next_id++;
		avl_insert( m->node2id, item );
		avl_insert( m->id2node, item );
// 		fprintf( stderr, "*** new item %d -> %s\n", (int) item->id, item->string );
		return item->id;
	} else {
// 		fprintf( stderr, "nodemap key '%s' alread exists\n", nodestr );
		return item->id;
	}
}

int hx_nodemap_remove_node_id ( hx_nodemap* m, rdf_node_id id ) {
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

int hx_nodemap_remove_node_string ( hx_nodemap* m, char* nodestr ) {
	hx_nodemap_item i;
	i.string	= nodestr;
	hx_nodemap_item* item	= (hx_nodemap_item*) avl_delete( m->node2id, &i );
	if (item != NULL) {
		avl_delete( m->id2node, item );
		_hx_free_node_item( item, NULL );
		return 0;
	} else {
		return 1;
	}
}

rdf_node_id hx_nodemap_get_node_id ( hx_nodemap* m, char* nodestr ) {
	hx_nodemap_item i;
	i.string	= nodestr;
	hx_nodemap_item* item	= (hx_nodemap_item*) avl_find( m->node2id, &i );
	if (item == NULL) {
		return (rdf_node_id) 0;
	} else {
		return item->id;
	}
}

char* hx_nodemap_get_node_string ( hx_nodemap* m, rdf_node_id id ) {
	hx_nodemap_item i;
	i.id		= id;
	i.string	= NULL;
// 	fprintf( stderr, "hx_nodemap_get_node_string( %p, %d )\n", (void*) m, (int) id );
	hx_nodemap_item* item	= (hx_nodemap_item*) avl_find( m->id2node, &i );
	if (item == NULL) {
// 		fprintf( stderr, "*** node %d string not found\n", (int) id );
		return NULL;
	} else {
// 		fprintf( stderr, "*** node %d string: '%s'\n", (int) id, item->string );
		return item->string;
	}
}

int hx_nodemap_write( hx_nodemap* m, FILE* f ) {
	fputc( 'N', f );
	size_t used	= avl_count( m->id2node );
	fwrite( &used, sizeof( size_t ), 1, f );
	fwrite( &( m->next_id ), sizeof( rdf_node_id ), 1, f );

	struct avl_traverser iter;
	avl_t_init( &iter, m->id2node );
	hx_nodemap_item* item;
	
	while ((item = (hx_nodemap_item*) avl_t_next( &iter )) != NULL) {
		size_t len	= strlen( item->string );
		fwrite( &( item->id ), sizeof( rdf_node_id ), 1, f );
		fwrite( &len, sizeof( size_t ), 1, f );
		fwrite( item->string, 1, len + 1, f );
	}

	return 0;
}

hx_nodemap* hx_nodemap_read( FILE* f, int buffer ) {
	size_t used, read;
	rdf_node_id next_id;
	int c	= fgetc( f );
	if (c != 'N') {
		fprintf( stderr, "*** Bad header cookie trying to read nodemap from file.\n" );
		return NULL;
	}
	
	hx_nodemap* m	= hx_new_nodemap();
	read	= fread( &used, sizeof( size_t ), 1, f );
	read	= fread( &next_id, sizeof( rdf_node_id ), 1, f );
	m->next_id	= next_id;
	for (int i = 0; i < used; i++) {
		size_t len;
		hx_nodemap_item* item	= (hx_nodemap_item*) malloc( sizeof( hx_nodemap_item ) );
		if ((read = fread( &( item->id ), sizeof( rdf_node_id ), 1, f )) == 0) {
			fprintf( stderr, "*** Failed to read item rdf_node_id\n" );
		}
		if ((read = fread( &len, sizeof( size_t ), 1, f )) == 0) {
			fprintf( stderr, "*** Failed to read item length\n" );
		}
		item->string	= (char*) malloc( len + 1 );
		fread( item->string, len + 1, 1, f );
		avl_insert( m->node2id, item );
		avl_insert( m->id2node, item );
	}
	return m;
}

