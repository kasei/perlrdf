#include "hexastore.h"

int _hx_iter_prime_first_result( hx_iter* iter );

/**

	Arguments a,b,c map the positions of a triple to the ordering of the index.
	(a,b,c) = (0,1,2)	==> (s,p,o) index
	(a,b,c) = (1,0,2)	==> (p,s,o) index
	(a,b,c) = (2,1,0)	==> (o,p,s) index

**/

hx_iter* hx_new_iter ( hx_index* index ) {
	hx_iter* iter	= (hx_iter*) calloc( 1, sizeof( hx_iter ) );
	iter->flags			= 0;
	iter->started		= 0;
	iter->finished		= 0;
	iter->node_mask_a	= (rdf_node) 0;
	iter->node_mask_b	= (rdf_node) 0;
	iter->node_mask_c	= (rdf_node) 0;
	iter->index			= index;
	return iter;
}

hx_iter* hx_new_iter1 ( hx_index* index, rdf_node a ) {
	hx_iter* iter	= hx_new_iter( index );
	iter->node_mask_a	= a;
	return iter;
}

hx_iter* hx_new_iter2 ( hx_index* index, rdf_node a, rdf_node b );


int hx_free_iter ( hx_iter* iter ) {
	if (iter->head_iter != NULL)
		hx_free_head_iter( iter->head_iter );
	if (iter->vector_iter != NULL)
		hx_free_vector_iter( iter->vector_iter );
	if (iter->terminal_iter != NULL)
		hx_free_terminal_iter( iter->terminal_iter );
	free( iter );
	return 0;
}

int hx_iter_finished ( hx_iter* iter ) {
	if (iter->started == 0) {
		_hx_iter_prime_first_result( iter );
	}
	return iter->finished;
}

int hx_iter_current ( hx_iter* iter, rdf_node* s, rdf_node* p, rdf_node* o ) {
	if (iter->started == 0) {
		_hx_iter_prime_first_result( iter );
		if (iter->finished == 1) {
			return 1;
		}
	}
	rdf_node triple_ordered[3];
//	fprintf( stderr, "iter: %p\n", iter );
	hx_index* index	= iter->index;
//	fprintf( stderr, "index: %p\n", iter->index );
//	fprintf( stderr, "hx_iter_current: getting first node\n" );
	hx_vector* v;
	hx_head_iter_current( iter->head_iter, &(triple_ordered[ index->order[ 0 ] ]), &v );
	
//	fprintf( stderr, "hx_iter_current: getting second node\n" );
	hx_terminal* t;
	hx_vector_iter_current( iter->vector_iter, &(triple_ordered[ index->order[ 1 ] ]), &t );
	
//	fprintf( stderr, "hx_iter_current: getting third node\n" );
	hx_terminal_iter_current( iter->terminal_iter, &(triple_ordered[ index->order[ 2 ] ]) );
	
//	fprintf( stderr, "hx_iter_current: got nodes\n" );
	*s	= triple_ordered[0];
	*p	= triple_ordered[1];
	*o	= triple_ordered[2];
	return 0;
}

int _hx_iter_prime_first_result( hx_iter* iter ) {
	iter->started	= 1;
	hx_index* index	= iter->index;
	
	iter->head_iter	= hx_head_new_iter( index->head );
	if (hx_head_iter_finished( iter->head_iter )) {
		hx_free_head_iter( iter->head_iter );
		iter->head_iter	= NULL;
		iter->finished	= 1;
		return 1;
	} else {
		rdf_node n;
		hx_vector* v;
		hx_head_iter_current( iter->head_iter, &n, &v );
		iter->vector_iter	= hx_vector_new_iter( v );
		
		if (hx_vector_iter_finished( iter->vector_iter )) {
			hx_free_vector_iter( iter->vector_iter );
			iter->vector_iter	= NULL;
			iter->finished	= 1;
			return 1;
		} else {
			hx_terminal* t;
			hx_vector_iter_current( iter->vector_iter, &n, &t );
			iter->terminal_iter	= hx_terminal_new_iter( t );
			
			if (hx_terminal_iter_finished( iter->terminal_iter )) {
				hx_free_terminal_iter( iter->terminal_iter );
				iter->terminal_iter	= NULL;
				iter->finished	= 1;
				return 1;
			}
		}
	}
	return 0;
}

int hx_iter_next ( hx_iter* iter ) {
	if (iter->started == 0) {
		_hx_iter_prime_first_result( iter );
		if (iter->finished == 1) {
			return 1;
		}
	}
	
	if (hx_terminal_iter_finished( iter->terminal_iter )) {
		// need to go to the next terminal
		hx_free_terminal_iter( iter->terminal_iter );
		iter->terminal_iter	= NULL;
		if (hx_vector_iter_finished( iter->vector_iter )) {
			// need to go to the next vector
			hx_free_vector_iter( iter->vector_iter );
			iter->vector_iter	= NULL;
			if (hx_head_iter_finished( iter->head_iter )) {
				hx_free_head_iter( iter->head_iter );
				iter->head_iter	= NULL;
				// iterator is exhausted.
				iter->finished	= 1;
				return 1;
			} else {
				// need to go to the next vector in the head
				hx_head_iter_next( iter->head_iter );
				if (hx_head_iter_finished( iter->head_iter )) {
					iter->finished	= 1;
					return 1;
				} else {
					// and replace the vector and terminal iterators
					if (iter->terminal_iter != NULL) {
						hx_free_terminal_iter( iter->terminal_iter );
						iter->terminal_iter	= NULL;
					}
					if (iter->vector_iter != NULL) {
						hx_free_vector_iter( iter->vector_iter );
						iter->vector_iter	= NULL;
					}
					rdf_node n;
					hx_vector *v;
					hx_terminal *t;
					hx_head_iter_current( iter->head_iter, &n, &v );
					iter->vector_iter	= hx_vector_new_iter( v );
	
					hx_vector_iter_current( iter->vector_iter, &n, &t );
					iter->terminal_iter	= hx_terminal_new_iter( t );
				}
			}
		} else {
			// need to go to the next terminal in the vector
			hx_vector_iter_next( iter->vector_iter );
			if (hx_vector_iter_finished( iter->vector_iter )) {
				iter->finished	= 1;
				return 1;
			} else {
				// and replace the terminal iterator
				if (iter->terminal_iter != NULL) {
					hx_free_terminal_iter( iter->terminal_iter );
					iter->terminal_iter	= NULL;
				}
				rdf_node n;
				hx_terminal* t;
				hx_vector_iter_current( iter->vector_iter, &n, &t );
				iter->terminal_iter	= hx_terminal_new_iter( t );
			}
		}
	} else {
		// need to go to the next node in the terminal
		hx_terminal_iter_next( iter->terminal_iter );
		if (hx_terminal_iter_finished( iter->terminal_iter )) {
			iter->finished	= 1;
			return 1;
		}
	}
	
	return 0;
}


