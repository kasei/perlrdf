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

char** hx_variablebindings_names ( hx_variablebindings* b ) {
	return b->names;
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
	
	int shared_count	= 0;
	int shared_lhs_index[max_size];
	char* shared_names[max_size];
	for (int i = 0; i < lhs_size; i++) {
		char* lhs_name	= lhs_names[ i ];
		for (int j = 0; j < rhs_size; j++) {
			char* rhs_name	= rhs_names[ i ];
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
		hx_node_id node	= hx_variablebindings_node_for_binding( left, shared_lhs_index[i] );
		for (int j = 0; j < rhs_size; j++) {
			char* rhs_name	= rhs_names[ j ];
			if (strcmp( name, rhs_name ) == 0) {
				hx_node_id rnode	= hx_variablebindings_node_for_binding( right, shared_lhs_index[j] );
				if (node != rnode) {
					return NULL;
				}
			}
		}
		
	}
	
	int size;
	char** names;
	_hx_variablebindings_join_names( left, right, &names, &size );
	hx_variablebindings* b;
	
	hx_node_id* values	= calloc( size, sizeof( hx_node_id ) );
	for (int i = 0; i < size; i++) {
		char* name	= names[ i ];
		for (int j = 0; j < lhs_size; j++) {
			if (strcmp( name, lhs_names[j] ) == 0) {
				values[i]	= hx_variablebindings_node_for_binding( left, j );
			}
		}
		for (int j = 0; j < rhs_size; j++) {
			if (strcmp( name, rhs_names[j] ) == 0) {
				values[i]	= hx_variablebindings_node_for_binding( right, j );
			}
		}
	}
	
	b	= hx_new_variablebindings( size, names, values );
	return b;
}



hx_variablebindings_iter* hx_variablebindings_new_iter ( hx_variablebindings_iter_vtable* vtable, void* ptr ) {
	hx_variablebindings_iter* iter	= (hx_variablebindings_iter*) malloc( sizeof( hx_variablebindings_iter ) );
	iter->vtable		= vtable;
	iter->ptr			= ptr;
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

int hx_variablebindings_iter_size ( hx_variablebindings_iter* iter ) {
	return iter->vtable->size( iter->ptr );
}

char** hx_variablebindings_iter_names ( hx_variablebindings_iter* iter ) {
	return iter->vtable->names( iter->ptr );
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
	return iter->vtable->sorted_by( iter->ptr, index );
}

hx_variablebindings_iter* hx_variablebindings_sort_iter( hx_variablebindings_iter* iter, int index ) {
	int size		= hx_variablebindings_iter_size( iter );
	char** names	= hx_variablebindings_iter_names( iter );
// 	fprintf( stderr, "requested sorting of iterator on '%s'\n", names[index] );
	
	if (hx_variablebindings_iter_is_sorted_by_index(iter, index)) {
		return iter;
	} else {
// 		fprintf( stderr, "*** Sorting of variable binding iterators not implemented yet.\n" ); // XXX
// 		fprintf( stderr, "\tnames:\n" );
// 		for (int i = 0; i < size; i++) {
// 			fprintf( stderr, "\t- %s\n", names[ i ] );
// 		}
		return NULL;
	}
}
