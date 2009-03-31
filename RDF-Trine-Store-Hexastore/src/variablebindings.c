#include "variablebindings.h"

hx_variablebindings* hx_new_variablebindings ( int size, char** names, hx_node_id* nodes, int free_names ) {
	hx_variablebindings* b	= (hx_variablebindings*) calloc( 1, sizeof( hx_variablebindings ) );
	b->size			= size;
	b->names		= names;
	b->nodes		= nodes;
	b->free_names	= free_names;
	return b;
}

hx_variablebindings* hx_copy_variablebindings ( hx_variablebindings* b ) {
	hx_variablebindings* c	= (hx_variablebindings*) calloc( 1, sizeof( hx_variablebindings ) );
	c->size		= b->size;
	c->names	= calloc( c->size, sizeof( char* ) );
	for (int i = 0; i < c->size; i++) {
		char* new	= calloc( strlen(b->names[i]) + 1, sizeof( char ) );
		strcpy( new, b->names[i] );
		c->names[i]	= new;
	}
	c->free_names	= 1;
	c->nodes		= b->nodes;
	return c;
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

char** hx_variablebindings_names ( hx_variablebindings* b ) {
	return b->names;
}

int hx_variablebindings_size ( hx_variablebindings* b ) {
	return b->size;
}

char* hx_variablebindings_name_for_binding ( hx_variablebindings* b, int column ) {
	return b->names[ column ];
}

hx_node_id hx_variablebindings_node_id_for_binding ( hx_variablebindings* b, int column ) {
	return b->nodes[ column ];
}

hx_node* hx_variablebindings_node_for_binding ( hx_variablebindings* b, hx_nodemap* map, int column ) {
	hx_node_id id	= b->nodes[ column ];
	hx_node* node	= hx_nodemap_get_node( map, id );
	return node;
}

hx_node* hx_variablebindings_node_for_binding_name ( hx_variablebindings* b, hx_nodemap* map, char* name ) {
	int column	= -1;
	for (int i = 0; i < b->size; i++) {
		if (strcmp(b->names[i], name) == 0) {
			column	= i;
			break;
		}
	}
	if (column >= 0) {
		hx_node_id id	= b->nodes[ column ];
		hx_node* node	= hx_nodemap_get_node( map, id );
		return node;
	} else {
		return NULL;
	}
}

int _hx_variablebindings_join_names ( hx_variablebindings* lhs, hx_variablebindings* rhs, char*** merged_names, int* size ) {
	int lhs_size		= hx_variablebindings_size( lhs );
	char** lhs_names	= hx_variablebindings_names( lhs );
	int rhs_size		= hx_variablebindings_size( rhs );
	char** rhs_names	= hx_variablebindings_names( rhs );
	int seen_names	= 0;
	char* names[ lhs_size + rhs_size ];
	for (int i = 0; i < lhs_size; i++) {
		char* name	= lhs_names[ i ];
		int seen	= 0;
		for (int j = 0; j < seen_names; j++) {
			if (strcmp( name, names[ j ] ) == 0) {
				seen	= 1;
			}
		}
		if (!seen) {
			names[ seen_names++ ]	= name;
		}
	}
	for (int i = 0; i < rhs_size; i++) {
		char* name	= rhs_names[ i ];
		int seen	= 0;
		for (int j = 0; j < seen_names; j++) {
			if (strcmp( name, names[ j ] ) == 0) {
				seen	= 1;
			}
		}
		if (!seen) {
			names[ seen_names++ ]	= name;
		}
	}
	
	*merged_names	= calloc( seen_names, sizeof( char* ) );
	for (int i = 0; i < seen_names; i++) {
		(*merged_names)[ i ]	= names[ i ];
	}
	*size	= seen_names;
	return 0;
}
hx_variablebindings* hx_variablebindings_natural_join( hx_variablebindings* left, hx_variablebindings* right ) {
	int lhs_size		= hx_variablebindings_size( left );
	char** lhs_names	= hx_variablebindings_names( left );
	int rhs_size		= hx_variablebindings_size( right );
	char** rhs_names	= hx_variablebindings_names( right );
	int max_size		= (lhs_size > rhs_size) ? lhs_size : rhs_size;
	
// 	fprintf( stderr, "natural join...\n" );
	int shared_count	= 0;
	int* shared_lhs_index	= calloc( max_size, sizeof(int) );
	char* shared_names[max_size];
	for (int i = 0; i < lhs_size; i++) {
		char* lhs_name	= lhs_names[ i ];
		for (int j = 0; j < rhs_size; j++) {
			char* rhs_name	= rhs_names[ j ];
			if (strcmp( lhs_name, rhs_name ) == 0) {
				int k	= shared_count++;
				shared_lhs_index[ k ]	= i;
				shared_names[ k ]	= lhs_name;
				break;
			}
		}
	}
	
	for (int i = 0; i < shared_count; i++) {
		char* name		= shared_names[i];
// 		fprintf( stderr, "*** shared key in natural join: %s\n", name );
		hx_node_id node	= hx_variablebindings_node_id_for_binding( left, shared_lhs_index[i] );
		for (int j = 0; j < rhs_size; j++) {
			char* rhs_name	= rhs_names[ j ];
			if (strcmp( name, rhs_name ) == 0) {
// 				fprintf( stderr, "rhs_name: %s\n", rhs_name );
// 				fprintf( stderr, "\tindex in lhs is %d\n", shared_lhs_index[j] );
				char* lhs_name	= lhs_names[ shared_lhs_index[j] ];
// 				fprintf( stderr, "lhs_name: %s\n", lhs_name );
				hx_node_id rnode	= hx_variablebindings_node_id_for_binding( right, j );
// 				fprintf( stderr, "\tcomparing nodes %d <=> %d\n", node, rnode );
				if (node != rnode) {
					free( shared_lhs_index );
					return NULL;
				}
			}
		}
		
	}
	
	free( shared_lhs_index );
	
	int size;
	char** names;
	_hx_variablebindings_join_names( left, right, &names, &size );
	hx_variablebindings* b;
	
	hx_node_id* values	= calloc( size, sizeof( hx_node_id ) );
	for (int i = 0; i < size; i++) {
		char* name	= names[ i ];
		for (int j = 0; j < lhs_size; j++) {
			if (strcmp( name, lhs_names[j] ) == 0) {
				values[i]	= hx_variablebindings_node_id_for_binding( left, j );
			}
		}
		for (int j = 0; j < rhs_size; j++) {
			if (strcmp( name, rhs_names[j] ) == 0) {
				values[i]	= hx_variablebindings_node_id_for_binding( right, j );
			}
		}
	}
	
	b	= hx_new_variablebindings( size, names, values, HX_VARIABLEBINDINGS_FREE_NAMES );
	return b;
}


hx_variablebindings_iter* hx_variablebindings_new_empty_iter ( void ) {
	hx_variablebindings_iter* iter	= (hx_variablebindings_iter*) malloc( sizeof( hx_variablebindings_iter ) );
	iter->vtable		= NULL;
	iter->ptr			= NULL;
	return iter;
}

hx_variablebindings_iter* hx_variablebindings_new_iter ( hx_variablebindings_iter_vtable* vtable, void* ptr ) {
	hx_variablebindings_iter* iter	= (hx_variablebindings_iter*) malloc( sizeof( hx_variablebindings_iter ) );
	iter->vtable		= vtable;
	iter->ptr			= ptr;
	return iter;
}

int hx_free_variablebindings_iter ( hx_variablebindings_iter* iter, int free_vtable ) {
	if (iter->vtable != NULL) {
		iter->vtable->free( iter->ptr );
		if (free_vtable) {
			free( iter->vtable );
			iter->vtable	= NULL;
		}
		iter->ptr	= NULL;
	}
	free( iter );
	return 0;
}

int hx_variablebindings_iter_finished ( hx_variablebindings_iter* iter ) {
	if (iter->vtable != NULL) {
		return iter->vtable->finished( iter->ptr );
	} else {
		return 1;
	}
}

int hx_variablebindings_iter_current ( hx_variablebindings_iter* iter, hx_variablebindings** b ) {
	if (iter->vtable != NULL) {
		return iter->vtable->current( iter->ptr, b );
	} else {
		return 1;
	}
}

int hx_variablebindings_iter_next ( hx_variablebindings_iter* iter ) {
	if (iter->vtable != NULL) {
		return iter->vtable->next( iter->ptr );
	} else {
		return 1;
	}
}

int hx_variablebindings_set_names ( hx_variablebindings* b, char** names ) {
	b->names	= names;
	return 0;
}

int hx_variablebindings_iter_size ( hx_variablebindings_iter* iter ) {
	if (iter->vtable != NULL) {
		return iter->vtable->size( iter->ptr );
	} else {
		return -1;
	}
}

char** hx_variablebindings_iter_names ( hx_variablebindings_iter* iter ) {
	if (iter->vtable != NULL) {
		return iter->vtable->names( iter->ptr );
	} else {
		return NULL;
	}
}

int hx_variablebindings_column_index ( hx_variablebindings_iter* iter, char* column ) {
	int size		= hx_variablebindings_iter_size( iter );
	char** names	= hx_variablebindings_iter_names( iter );
	for (int i = 0; i < size; i++) {
		if (strcmp(column, names[i]) == 0) {
			return i;
		}
	}
	return -1;
}

int hx_variablebindings_iter_is_sorted_by_index ( hx_variablebindings_iter* iter, int index ) {
	if (iter->vtable != NULL) {
		return iter->vtable->sorted_by( iter->ptr, index );
	} else {
		return 0;
	}
}

int hx_variablebindings_iter_debug ( hx_variablebindings_iter* iter, char* header, int indent ) {
	if (iter->vtable != NULL) {
		return iter->vtable->debug( iter->ptr, header, indent );
	} else {
		return 1;
	}
}

hx_variablebindings_iter* hx_variablebindings_sort_iter( hx_variablebindings_iter* iter, int index ) {
	int size		= hx_variablebindings_iter_size( iter );
	char** names	= hx_variablebindings_iter_names( iter );
// 	fprintf( stderr, "requested sorting of iterator on '%s'\n", names[index] );
	
	if (hx_variablebindings_iter_is_sorted_by_index(iter, index)) {
		return iter;
	} else {
		// iterator isn't sorted on the requested column...
		
		// so, materialize the iterator
		hx_variablebindings_iter* sorted	= hx_new_materialize_iter( iter );
		if (sorted == NULL) {
			hx_free_variablebindings_iter( iter, 0 );
			return NULL;
		}
		
// 		hx_materialize_iter_debug( iter );
		
		// and sort the materialized bindings by the requested column...
		int r	= hx_materialize_sort_iter( sorted, index );
		if (r == 0) {
			return sorted;
		} else {
			hx_free_variablebindings_iter( sorted, 0 );
			return NULL;
		}
	}
}

