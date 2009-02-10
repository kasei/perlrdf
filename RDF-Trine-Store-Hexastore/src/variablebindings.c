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

int hx_variablebindings_string ( hx_variablebindings* b, hx_nodemap* map, char** string ) {
	int size	= b->size;
	hx_node_id id[ size ];
	char* nodestrs[ size ];
	size_t len	= 5;
	for (int i = 0; i < size; i++) {
		hx_node_id id	= b->nodes[ i ];
		if (map == NULL) {
			char* number	= malloc( 20 );
			sprintf( number, "%d", (int) id );
			nodestrs[i]	= number;
		} else {
			hx_node* node	= hx_nodemap_get_node( map, id );
			hx_node_string( node, &( nodestrs[i] ) );
		}
		len	+= strlen( nodestrs[i] ) + 2 + strlen(b->names[i]) + 1;
	}
	*string	= malloc( len );
	char* p			= *string;
	if (*string == NULL) {
		fprintf( stderr, "*** Failed to allocated memory in hx_variablebindings_string\n" );
		return 1;
	}
	
	strcpy( p, "{ " );
	p	+= 2;
	for (int i = 0; i < size; i++) {
		strcpy( p, b->names[i] );
		p	+= strlen( b->names[i] );
		
		strcpy( p, "=" );
		p	+= 1;
		
		strcpy( p, nodestrs[i] );
		p	+= strlen( nodestrs[i] );
		if (i == size-1) {
			strcpy( p, " }" );
		} else {
			strcpy( p, ", " );
		}
		p	+= 2;
	}
	return 0;
}

void hx_variablebindings_debug ( hx_variablebindings* b, hx_nodemap* m ) {
	char* string;
	if (hx_variablebindings_string( b, m, &string ) != 0) {
		return;
	}

	fprintf( stderr, "%s\n", string );
	
	free( string );
}

int hx_variablebindings_size ( hx_variablebindings* b ) {
	return b->size;
}

char* hx_variablebindings_name_for_binding ( hx_variablebindings* b, int column ) {
	return b->names[ column ];
}

hx_node_id hx_variablebindings_node_for_binding ( hx_variablebindings* b, int column ) {
	return b->nodes[ column ];
}



hx_variablebindings_iter* hx_variablebindings_new_iter ( hx_variablebindings_iter_vtable* vtable, void* ptr ) {
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

int hx_variablebindings_iter_columns ( hx_variablebindings_iter* iter ) {
	return iter->vtable->columns( iter->ptr );
}

char** hx_variablebindings_iter_names ( hx_variablebindings_iter* iter ) {
	return iter->vtable->names( iter->ptr );
}
