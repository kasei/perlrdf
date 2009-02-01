#include "index.h"

hx_index* hx_new_index ( int* index_order ) {
	int a	= index_order[0];
	int b	= index_order[1];
	int c	= index_order[2];
	hx_index* i	= (hx_index*) calloc( 1, sizeof( hx_index ) );
	i->order[0]	= a;
	i->order[1]	= b;
	i->order[2]	= c;
	i->head		= hx_new_head();
	return i;
}

int hx_free_index ( hx_index* i ) {
	free( i->head );
	free( i );
	return 0;
}

int hx_index_debug ( hx_index* index ) {
	hx_head* h	= index->head;
	fprintf( stderr, "index: %p\n  -> head: %p\n  -> order [%d, %d, %d]\n  -> triples:\n", index, h, index->order[0], index->order[1], index->order[2] );
	rdf_node triple_ordered[3];
	for (int i = 0; i < h->used; i++) {
		hx_vector* v	= h->ptr[i].vector;
		triple_ordered[ index->order[ 0 ] ]	= h->ptr[i].node;
		for (int j = 0; j < v->used; j++) {
			hx_terminal* t	= v->ptr[j].terminal;
			triple_ordered[ index->order[ 1 ] ]	= v->ptr[j].node;
			for (int k = 0; k < t->used;  k++) {
				rdf_node n	= t->ptr[k];
				triple_ordered[ index->order[ 2 ] ]	= n;
				fprintf( stderr, "\t{ %d, %d, %d }\n", (int) triple_ordered[0], (int) triple_ordered[1], (int) triple_ordered[2] );
			}
		}
	}
	
	return 0;
}

int hx_index_add_triple ( hx_index* index, rdf_node s, rdf_node p, rdf_node o ) {
	rdf_node triple_ordered[3];
	triple_ordered[0]	= s;
	triple_ordered[1]	= p;
	triple_ordered[2]	= o;
	rdf_node index_ordered[3];
	for (int i = 0; i < 3; i++) {
		index_ordered[ i ]	= triple_ordered[ index->order[ i ] ];
	}
//	fprintf( stderr, "add_triple index order: { %d, %d, %d }\n", (int) index_ordered[0], (int) index_ordered[1], (int) index_ordered[2] );
	
	hx_head* h	= index->head;
	hx_vector* v;
	hx_terminal* t;
	
	if ((v = hx_head_get_vector( h, index_ordered[0] )) == NULL) {
		v	= hx_new_vector();
		hx_head_add_vector( h, index_ordered[0], v );
	}
	
	if ((t = hx_vector_get_terminal( v, index_ordered[1] )) == NULL) {
		t	= hx_new_terminal();
		hx_vector_add_terminal( v, index_ordered[1], t );
	}
	
	hx_terminal_add_node( t, index_ordered[2] );
	return 0;
}

int hx_index_remove_triple ( hx_index* index, rdf_node s, rdf_node p, rdf_node o ) {
	rdf_node triple_ordered[3];
	triple_ordered[0]	= s;
	triple_ordered[1]	= p;
	triple_ordered[2]	= o;
	rdf_node index_ordered[3];
	for (int i = 0; i < 3; i++) {
		index_ordered[ i ]	= triple_ordered[ index->order[ i ] ];
	}
	fprintf( stderr, "remove_triple index order: { %d, %d, %d }\n", (int) index_ordered[0], (int) index_ordered[1], (int) index_ordered[2] );
	
	hx_head* h	= index->head;
	hx_vector* v;
	hx_terminal* t;
	
	if ((v = hx_head_get_vector( h, index_ordered[0] )) == NULL) {
		// no vector for this node... do nothing.
		return 1;
	}
	
	if ((t = hx_vector_get_terminal( v, index_ordered[1] )) == NULL) {
		// no terminal for this node... do nothing.
		return 1;
	}
	
	hx_terminal_remove_node( t, index_ordered[2] );
	
	if (hx_terminal_size( t ) == 0) {
		// no more nodes in this terminal list... remove it from the vector.
		hx_vector_remove_terminal( v, index_ordered[1] );
		
		if (hx_vector_size( v ) == 0) {
			// no more terminal lists in this vector... remove it from the head.
			hx_head_remove_vector( h, index_ordered[0] );
		}
	}
	
	return 0;
}

uint64_t hx_index_triples_count ( hx_index* index ) {
	return hx_head_triples_count( index->head );
}

size_t hx_index_memory_size ( hx_index* i ) {
	uint64_t size	= sizeof( hx_index ) + hx_head_memory_size( i->head );
	return size;
}
