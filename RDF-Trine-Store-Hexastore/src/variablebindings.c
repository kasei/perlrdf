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

hx_variablebindings_iter* hx_variablebindings_new_iterator_triples ( hx_index_iter* i, char* subj_name, char* pred_name, char* obj_name ) {
	hx_variablebindings_iter* iter	= (hx_variablebindings_iter*) calloc( 1, sizeof( hx_variablebindings_iter ) );
	iter->type	= 'I';
	iter->size	= 0;
	if (subj_name != NULL)
		iter->size++;
	if (pred_name != NULL)
		iter->size++;
	if (obj_name != NULL)
		iter->size++;
	
	int j	= 0;
	iter->names		= calloc( iter->size, sizeof( char* ) );
	iter->indexes	= calloc( iter->size, sizeof( int ) );
	if (subj_name != NULL) {
		int idx	= j++;
		iter->names[ idx ]		= subj_name;
		iter->indexes[ idx ]	= 0;
	}
	if (pred_name != NULL) {
		int idx	= j++;
		iter->names[ idx ]		= pred_name;
		iter->indexes[ idx ]	= 1;
	}
	if (obj_name != NULL) {
		int idx	= j++;
		iter->names[ idx ]		= obj_name;
		iter->indexes[ idx ]	= 2;
	}
	
	iter->ptr	= (void*) i;
	return iter;
}

int hx_free_variablebindings_iter ( hx_variablebindings_iter* iter ) {
	if (iter->type == 'I') {
		hx_free_index_iter( (hx_index_iter*) iter->ptr );
	}
	free( iter );
	return 0;
}

int hx_variablebindings_iter_finished ( hx_variablebindings_iter* iter ) {
	if (iter->type == 'I') {
		hx_index_iter* i	= (hx_index_iter*) iter->ptr;
		return hx_index_iter_finished( i );
	}
	return 0;
}

int hx_variablebindings_iter_current ( hx_variablebindings_iter* iter, hx_variablebindings** b ) {
	if (iter->type == 'I') {
		hx_index_iter* i	= (hx_index_iter*) iter->ptr;
		hx_node_id* nodes	= calloc( iter->size, sizeof( hx_node_id ) );
		hx_node_id n[3];
		hx_index_iter_current( i, &(n[0]), &(n[1]), &(n[2]) );
		int j	= 0;
		for (int j = 0; j < iter->size; j++) {
			nodes[j]	= n[ iter->indexes[j] ];
		}
		
		*b	= hx_new_variablebindings( iter->size, iter->names, nodes );
		return 0;
	}
	return 0;
}

int hx_variablebindings_iter_next ( hx_variablebindings_iter* iter ) {
	if (iter->type == 'I') {
		hx_index_iter* i	= (hx_index_iter*) iter->ptr;
		return hx_index_iter_next( i );
	}
	return 0;
}

