#include "variablebindings.h"

hx_variablebindings* hx_new_variablebindings ( int size, char** names, hx_node_id* nodes ) {
	hx_variablebindings* b	= (hx_variablebindings*) calloc( 1, sizeof( hx_variablebindings ) );
	b->size		= size;
	b->names	= names;
	b->nodes	= nodes;
	return b;
}

int hx_free_variablebindings ( hx_variablebindings* b, int free_names ) {
	if (free_names > 0) {
		for (int i = 0; i < b->size; i++) {
			free( b->names[ i ] );
		}
		free( b->names );
	}
	free( b->nodes );
	free( b );
	return 0;
}

void hx_variablebindings_debug ( hx_variablebindings* b, hx_nodemap* m ) {
	fprintf( stderr, "{ " );
	hx_node* node;
	char* string;
	for (int i = 0; i < b->size; i++) {
		hx_node_id id	= b->nodes[ i ];
		node	= hx_nodemap_get_node( m, id );
		if (node == NULL) {
			fprintf( stderr, "*** Node %d doesn't exist in nodemap.\n", (int) id );
		}
		hx_node_string( node, &string );
		fprintf( stderr, "%s = %s", b->names[i], string );
		free( string );
		if (i < (b->size - 1)) {
			fprintf( stderr, "," );
		}
		fprintf( stderr, " " );
	}
	fprintf( stderr, " }\n" );
}

char* hx_variablebindings_name_for_binding ( hx_variablebindings* b, int column ) {
	return b->names[ column ];
}

hx_node_id hx_variablebindings_node_for_binding ( hx_variablebindings* b, int column ) {
	return b->nodes[ column ];
}



hx_variablebindings_iter* hx_variablebindings_new_iter ( hx_iter_vtable* vtable, void* ptr ) {
	hx_variablebindings_iter* iter	= (hx_variablebindings_iter*) malloc( sizeof( hx_variablebindings_iter ) );
	iter->vtable	= vtable;
	iter->ptr		= ptr;
	return iter;
}

int hx_free_variablebindings_iter ( hx_variablebindings_iter* iter, int free_vtable ) {
	iter->vtable->free( iter->ptr );
	if (free_vtable) {
		free( iter->vtable );
	}
	free( iter );
	return 0;
}

int hx_variablebindings_iter_finished ( hx_variablebindings_iter* iter ) {
	return iter->vtable->finished( iter->ptr );
}

int hx_variablebindings_iter_current ( hx_variablebindings_iter* iter, hx_variablebindings** b ) {
	return iter->vtable->current( iter->ptr, b );
}

int hx_variablebindings_iter_next ( hx_variablebindings_iter* iter ) {
	return iter->vtable->next( iter->ptr );
}

