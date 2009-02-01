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
	iter->index			= index;
	return iter;
}

int hx_free_iter ( hx_iter* iter ) {
	free( iter );
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
	triple_ordered[ index->order[ 0 ] ]	= iter->head->ptr[ iter->a_index ].node;

//	fprintf( stderr, "hx_iter_current: getting second node\n" );
	triple_ordered[ index->order[ 1 ] ]	= iter->vector->ptr[ iter->b_index ].node;

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
	iter->head		= index->head;
	if (iter->head->used > 0) {
		iter->a_index	= 0;
		iter->vector	= index->head->ptr[0].vector;
		
		if (iter->vector->used > 0) {
			iter->b_index	= 0;
			iter->terminal_iter	= hx_terminal_new_iter( index->head->ptr[0].vector->ptr[0].terminal );
			
			if (hx_terminal_iter_finished( iter->terminal_iter )) {
				iter->finished	= 1;
				return 1;
			}
		} else {
			iter->finished	= 1;
			return 1;
		}
	} else {
		iter->finished	= 1;
		return 1;
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
		if (iter->b_index >= (iter->vector->used - 1)) {
			// need to go to the next vector
			if (iter->a_index >= (iter->head->used - 1)) {
				// no more triples!
				iter->finished	= 1;
				iter->head		= NULL;
				iter->vector	= NULL;
				iter->terminal_iter	= NULL;
				return 1;
			} else {
				iter->a_index++;
				iter->b_index	= 0;
				iter->vector	= iter->head->ptr[ iter->a_index ].vector;
				iter->terminal_iter	= hx_terminal_new_iter( iter->vector->ptr[ iter->b_index ].terminal );
			}
		} else {
			iter->b_index++;
			iter->terminal_iter	= hx_terminal_new_iter( iter->vector->ptr[ iter->b_index ].terminal );
		}
	} else {
//		fprintf( stderr, "hx_iter_next: there are remaining nodes in the terminal (moving from %d/%d)\n", iter->c_index, iter->terminal->used );
		hx_terminal_iter_next( iter->terminal_iter );
	}
	
	return 0;
}




hx_iter* hx_new_iter1 ( hx_index* index, rdf_node a );
hx_iter* hx_new_iter2 ( hx_index* index, rdf_node a, rdf_node b );



