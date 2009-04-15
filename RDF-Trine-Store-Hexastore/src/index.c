#include "index.h"

int _hx_index_iter_prime_first_result( hx_index_iter* iter );
int _hx_index_iter_next_head ( hx_index_iter* iter );
int _hx_index_iter_next_vector ( hx_index_iter* iter );

int _hx_index_got_head_trigger ( hx_index_iter* iter, hx_node_id n );
int _hx_index_got_vector_trigger ( hx_index_iter* iter, hx_node_id n );


/**

	Arguments index_order = {a,b,c} map the positions of a triple to the
	ordering of the index.
	
	(a,b,c) = (0,1,2)	==> (s,p,o) index
	(a,b,c) = (1,0,2)	==> (p,s,o) index
	(a,b,c) = (2,1,0)	==> (o,p,s) index

**/

hx_index* hx_new_index ( hx_storage_manager* s, int* index_order ) {
	int a	= index_order[0];
	int b	= index_order[1];
	int c	= index_order[2];
	hx_index* i	= (hx_index*) hx_storage_new_block( s, sizeof( hx_index ) );
	i->order[0]	= a;
	i->order[1]	= b;
	i->order[2]	= c;
	hx_head* h	= hx_new_head( s );
	i->head		= hx_storage_id_from_block( s, h );
	return i;
}

int hx_free_index ( hx_index* i, hx_storage_manager* st ) {
	hx_free_head( hx_storage_block_from_id( st, i->head ) );
	hx_storage_release_block( st, i );
	return 0;
}

// XXX replace the use of ->used, etc. with iterators (preserves abstraction)
int hx_index_debug ( hx_index* index, hx_storage_manager* st ) {
	hx_head* h	= hx_storage_block_from_id( st, index->head );
	fprintf(
		stderr,
		"index: %p\n  -> head: %p\n  -> order [%d, %d, %d]\n  -> triples:\n",
		(void*) index,
		(void*) h,
		(int) index->order[0],
		(int) index->order[1],
		(int) index->order[2]
	);
	hx_node_id triple_ordered[3];
	
	hx_head_iter* hiter	= hx_head_new_iter( h );
	int i	= 0;
	while (!hx_head_iter_finished( hiter )) {
		hx_vector* v;
		hx_head_iter_current( hiter, &(triple_ordered[ index->order[ 0 ] ]), &v );
		
		hx_vector_iter* viter	= hx_vector_new_iter( v );
		int j = 0;
		while (!hx_vector_iter_finished( viter )) {
			hx_terminal* t;
			hx_vector_iter_current( viter, &(triple_ordered[ index->order[ 1 ] ]), &t );
			hx_terminal_iter* titer	= hx_terminal_new_iter( t );
			while (!hx_terminal_iter_finished( titer )) {
				hx_node_id n;
				hx_terminal_iter_current( titer, &n );
				
				triple_ordered[ index->order[ 2 ] ]	= n;
				fprintf( stderr, "\t{ %d, %d, %d }\n", (int) triple_ordered[0], (int) triple_ordered[1], (int) triple_ordered[2] );
				
				hx_terminal_iter_next( titer );
			}
			hx_free_terminal_iter( titer );
			hx_vector_iter_next( viter );
			j++;
		}
		
		hx_head_iter_next( hiter );
		i++;
	}
	hx_free_head_iter( hiter );
	
	return 0;
}

int hx_index_add_triple ( hx_index* index, hx_storage_manager* st, hx_node_id s, hx_node_id p, hx_node_id o ) {
	return hx_index_add_triple_terminal( index, st, s, p, o, NULL );
}

int hx_index_add_triple_terminal ( hx_index* index, hx_storage_manager* st, hx_node_id s, hx_node_id p, hx_node_id o, hx_terminal** r_terminal ) {
	hx_node_id triple_ordered[3];
	triple_ordered[0]	= s;
	triple_ordered[1]	= p;
	triple_ordered[2]	= o;
	hx_node_id index_ordered[3];
	for (int i = 0; i < 3; i++) {
		index_ordered[ i ]	= triple_ordered[ index->order[ i ] ];
	}
//	fprintf( stderr, "add_triple index order: { %d, %d, %d }\n", (int) index_ordered[0], (int) index_ordered[1], (int) index_ordered[2] );
	
	hx_head* h	= hx_storage_block_from_id( st, index->head );
	hx_vector* v	= NULL;
	hx_terminal* t;
	
	if ((v = hx_head_get_vector( h, index_ordered[0] )) == NULL) {
//		fprintf( stderr, "adding missing vector for node %d\n", (int) index_ordered[0] );
		v	= hx_new_vector( st );
		hx_head_add_vector( h, index_ordered[0], v );
	}
	
	if ((t = hx_vector_get_terminal( v, index_ordered[1] )) == NULL) {
		t	= hx_new_terminal( st );
		hx_vector_add_terminal( v, index_ordered[1], t );
	}
	
	int added	= hx_terminal_add_node( t, index_ordered[2] );
	if (added == 0) {
		hx_head_triples_count_add( h, 1);
		hx_vector_triples_count_add( v, 1 );
	}
	
	if (r_terminal != NULL) {
		*r_terminal	= t;
	}
	return added;
}

int hx_index_add_triple_with_terminal ( hx_index* index, hx_storage_manager* st, hx_terminal* t, hx_node_id s, hx_node_id p, hx_node_id o, int added ) {
	hx_node_id triple_ordered[3];
	triple_ordered[0]	= s;
	triple_ordered[1]	= p;
	triple_ordered[2]	= o;
	hx_node_id index_ordered[3];
	for (int i = 0; i < 3; i++) {
		index_ordered[ i ]	= triple_ordered[ index->order[ i ] ];
	}
//	fprintf( stderr, "add_triple index order: { %d, %d, %d }\n", (int) index_ordered[0], (int) index_ordered[1], (int) index_ordered[2] );
	
	hx_head* h	= hx_storage_block_from_id( st, index->head );
	hx_vector* v	= NULL;
	
	if ((v = hx_head_get_vector( h, index_ordered[0] )) == NULL) {
//		fprintf( stderr, "adding missing vector for node %d\n", (int) index_ordered[0] );
		v	= hx_new_vector( st );
		hx_head_add_vector( h, index_ordered[0], v );
	}
	
	hx_vector_add_terminal( v, index_ordered[1], t );
	if (added == 0) {
		hx_head_triples_count_add( h, 1);
		hx_vector_triples_count_add( v, 1 );
	}
	
	return added;
}

int hx_index_remove_triple ( hx_index* index, hx_storage_manager* st, hx_node_id s, hx_node_id p, hx_node_id o ) {
	hx_node_id triple_ordered[3];
	triple_ordered[0]	= s;
	triple_ordered[1]	= p;
	triple_ordered[2]	= o;
	hx_node_id index_ordered[3];
	for (int i = 0; i < 3; i++) {
		index_ordered[ i ]	= triple_ordered[ index->order[ i ] ];
	}
	
	hx_head* h	= hx_storage_block_from_id( st, index->head );
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
	
	int removed	= hx_terminal_remove_node( t, index_ordered[2] );
	if (removed == 0) {
		hx_head_triples_count_add( h, -1 );
		hx_vector_triples_count_add( v, -1 );
	}
	
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

hx_storage_id_t hx_index_triples_count ( hx_index* index, hx_storage_manager* st ) {
	return hx_head_triples_count( hx_storage_block_from_id( st, index->head ) );
}

hx_head* hx_index_head ( hx_index* index, hx_storage_manager* st ) {
	return hx_storage_block_from_id( st, index->head );
}

hx_index_iter* hx_index_new_iter ( hx_index* index, hx_storage_manager* st ) {
	hx_index_iter* iter	= (hx_index_iter*) calloc( 1, sizeof( hx_index_iter ) );
	iter->storage		= st;
	iter->flags			= 0;
	iter->started		= 0;
	iter->finished		= 0;
	iter->node_mask_a	= (hx_node_id) -1;
	iter->node_mask_b	= (hx_node_id) -2;
	iter->node_mask_c	= (hx_node_id) -3;
	iter->index			= index;
	return iter;
}

hx_index_iter* hx_index_new_iter1 ( hx_index* index, hx_storage_manager* st, hx_node_id s, hx_node_id p, hx_node_id o ) {
	hx_index_iter* iter	= hx_index_new_iter( index, st );
	hx_node_id masks[3]	= { s, p, o };
	iter->node_mask_a	= masks[ index->order[0] ];
	iter->node_mask_b	= masks[ index->order[1] ];;
	iter->node_mask_c	= masks[ index->order[2] ];
	iter->node_dup_b	= 0;
	iter->node_dup_c	= 0;
	
//	fprintf( stderr, "*** index using node masks (in index-order): %d %d %d\n", (int) iter->node_mask_a, (int) iter->node_mask_b, (int) iter->node_mask_c );
	
	if (iter->node_mask_b == iter->node_mask_a && iter->node_mask_a != (hx_node_id) 0) {
// 		fprintf( stderr, "*** Looking for duplicated subj/pred triples\n" );
		iter->node_dup_b	= HX_INDEX_ITER_DUP_A;
	}
	
	if (iter->node_mask_c == iter->node_mask_a && iter->node_mask_a != (hx_node_id) 0) {
// 		fprintf( stderr, "*** Looking for duplicated subj/obj triples\n" );
		iter->node_dup_c	= HX_INDEX_ITER_DUP_A;
	} else if (iter->node_mask_c == iter->node_mask_b && iter->node_mask_b != (hx_node_id) 0) {
// 		fprintf( stderr, "*** Looking for duplicated pred/obj triples\n" );
		iter->node_dup_c	= HX_INDEX_ITER_DUP_B;
	}
	return iter;
}

int hx_free_index_iter ( hx_index_iter* iter ) {
	if (iter->head_iter != NULL) {
		hx_free_head_iter( iter->head_iter );
		iter->head_iter	= NULL;
	}
	if (iter->vector_iter != NULL) {
		hx_free_vector_iter( iter->vector_iter );
		iter->vector_iter	= NULL;
	}
	if (iter->terminal_iter != NULL) {
		hx_free_terminal_iter( iter->terminal_iter );
		iter->terminal_iter	= NULL;
	}
	free( iter );
	return 0;
}

int hx_index_iter_finished ( hx_index_iter* iter ) {
	if (iter->started == 0) {
		_hx_index_iter_prime_first_result( iter );
	}
	return iter->finished;
}

int hx_index_iter_current ( hx_index_iter* iter, hx_node_id* s, hx_node_id* p, hx_node_id* o ) {
	if (iter->started == 0) {
		_hx_index_iter_prime_first_result( iter );
	}
	if (iter->finished == 1) {
		return 1;
	}
	
	hx_node_id triple_ordered[3];
//	fprintf( stderr, "iter: %p\n", iter );
	hx_index* index	= iter->index;
//	fprintf( stderr, "index: %p\n", iter->index );
	hx_vector* v;
// 	fprintf( stderr, "triple position %d comes from the head\n", index->order[0] );
	hx_head_iter_current( iter->head_iter, &(triple_ordered[ index->order[0] ]), &v );
	
	hx_terminal* t;
// 	fprintf( stderr, "triple position %d comes from the vector\n", index->order[1] );
	hx_vector_iter_current( iter->vector_iter, &(triple_ordered[ index->order[1] ]), &t );
// 	fprintf( stderr, "triple position %d comes from the terminal\n", index->order[2] );
	hx_terminal_iter_current( iter->terminal_iter, &(triple_ordered[ index->order[2] ]) );
	
	*s	= triple_ordered[0];
	*p	= triple_ordered[1];
	*o	= triple_ordered[2];
// 	fprintf( stderr, "hx_iter_current: got nodes (%d, %d, %d)\n", (int) *s, (int) *p, (int) *o );
	return 0;
}

int _hx_index_iter_prime_first_result( hx_index_iter* iter ) {
	iter->started	= 1;
	hx_index* index	= iter->index;
// 	fprintf( stderr, "_hx_index_iter_prime_first_result( %p )\n", (void*) iter );
	iter->head_iter	= hx_head_new_iter( hx_storage_block_from_id( iter->storage, index->head ) );
	if (iter->node_mask_a > (hx_node_id) 0) {
//		fprintf( stderr, "- head seeking to %d\n", (int) iter->node_mask_a );
		if (hx_head_iter_seek( iter->head_iter, iter->node_mask_a ) != 0) {
			iter->finished	= 1;
			return 1;
		}
	}
	
	while (!hx_head_iter_finished( iter->head_iter )) {
		hx_node_id n;
		hx_vector* v;
		hx_head_iter_current( iter->head_iter, &n, &v );
		_hx_index_got_head_trigger( iter, n );
		
		if (iter->node_mask_a > (hx_node_id) 0 && n != iter->node_mask_a) {
			break;
		}
		
		iter->vector_iter	= hx_vector_new_iter( v );
		if (iter->node_mask_b > (hx_node_id) 0) {
//			fprintf( stderr, "- vector seeking to %d\n", (int) iter->node_mask_b );
			if (hx_vector_iter_seek( iter->vector_iter, iter->node_mask_b ) != 0) {
//				fprintf( stderr, "  - vector doesn't contain node %d\n", (int) iter->node_mask_b );
				hx_head_iter_next( iter->head_iter );
				continue;
			}
		}
		
		
		while (!hx_vector_iter_finished( iter->vector_iter )) {
			hx_terminal* t;
			hx_vector_iter_current( iter->vector_iter, &n, &t );
			_hx_index_got_vector_trigger( iter, n );
			if (iter->node_mask_b > (hx_node_id) 0 && n != iter->node_mask_b) {
				break;
			}
			
			iter->terminal_iter	= hx_terminal_new_iter( t );
			if (iter->node_mask_c > (hx_node_id) 0) {
//				fprintf( stderr, "- terminal seeking to %d\n", (int) iter->node_mask_c );
				if (hx_terminal_iter_seek( iter->terminal_iter, iter->node_mask_c ) != 0) {
					hx_vector_iter_next( iter->vector_iter );
					continue;
				}
			}
			
			if (hx_terminal_iter_finished( iter->terminal_iter )) {
				hx_free_terminal_iter( iter->terminal_iter );
				iter->terminal_iter	= NULL;
				iter->finished	= 1;
				return 1;
			} else {
				return 0;
			}
		}
		hx_head_iter_next( iter->head_iter );
	}
	
	if (iter->vector_iter != NULL) {
		hx_free_vector_iter( iter->vector_iter );
		iter->vector_iter	= NULL;
	}
	if (iter->head_iter != NULL) {
		hx_free_head_iter( iter->head_iter );
		iter->head_iter	= NULL;
	}
	iter->finished	= 1;
	return 1;
}

int _hx_index_iter_next_head ( hx_index_iter* iter ) {
	int hr;
NEXTHEAD:
	hr	= hx_head_iter_next( iter->head_iter );
	if (hr == 0 && (iter->node_mask_a < (hx_node_id) 0)) {
//		fprintf( stderr, "got next head\n" );
		hx_free_terminal_iter( iter->terminal_iter );
		iter->terminal_iter	= NULL;
		hx_free_vector_iter( iter->vector_iter );
		iter->vector_iter	= NULL;
		
		// set up vector and terminal iterators
		hx_node_id n;
		hx_vector* v;
		hx_terminal* t;
		hx_head_iter_current( iter->head_iter, &n, &v );
		_hx_index_got_head_trigger( iter, n );
		iter->vector_iter	= hx_vector_new_iter( v );
		if (iter->node_mask_b > (hx_node_id) 0) {
			if (hx_vector_iter_seek( iter->vector_iter, iter->node_mask_b ) != 0) {
				goto NEXTHEAD;
			}
		}
		
		hx_vector_iter_current( iter->vector_iter, &n, &t );
		_hx_index_got_vector_trigger( iter, n );
		iter->terminal_iter	= hx_terminal_new_iter( t );
		if (iter->node_mask_c > (hx_node_id) 0) {
			if (hx_terminal_iter_seek( iter->terminal_iter, iter->node_mask_c ) != 0) {
				_hx_index_iter_next_vector( iter );
			}
		}
		return 0;
	} else {
//		fprintf( stderr, "no next head... iterator is finished...\n" );
		hx_free_head_iter( iter->head_iter );
		iter->head_iter	= NULL;
		hx_free_vector_iter( iter->vector_iter );
		iter->vector_iter	= NULL;
		hx_free_terminal_iter( iter->terminal_iter );
		iter->terminal_iter	= NULL;
		iter->finished	= 1;
		return 1;
	}
}

int _hx_index_iter_next_vector ( hx_index_iter* iter ) {
	int vr;
NEXTVECTOR:
	vr	= hx_vector_iter_next( iter->vector_iter );
	if (vr == 0 && (iter->node_mask_b < (hx_node_id) 0)) {
//		fprintf( stderr, "got next vector\n" );
		hx_free_terminal_iter( iter->terminal_iter );
		iter->terminal_iter	= NULL;
		
		// set up terminal iterator
		hx_node_id n;
		hx_terminal* t;
		hx_vector_iter_current( iter->vector_iter, &n, &t );
		_hx_index_got_vector_trigger( iter, n );
		iter->terminal_iter	= hx_terminal_new_iter( t );
		if (iter->node_mask_c > (hx_node_id) 0) {
			if (hx_terminal_iter_seek( iter->terminal_iter, iter->node_mask_c ) != 0) {
				goto NEXTVECTOR;
			}
		}
		return 1;
	} else {
//		fprintf( stderr, "no next vector... getting next head...\n" );
		return _hx_index_iter_next_head( iter );
	}
	return 0;
}

int hx_index_iter_next ( hx_index_iter* iter ) {
//	fprintf( stderr, "hx_index_iter_next( %p )\n", (void*) iter );
	if (iter->started == 0) {
//		fprintf( stderr, "- iter not started... priming first result...\n" );
		_hx_index_iter_prime_first_result( iter );
		if (iter->finished == 1) {
			return 1;
		}
	}
	
	int tr;
// NEXTTERMINAL:
	tr	= hx_terminal_iter_next( iter->terminal_iter );
	if (tr == 0 && (iter->node_mask_c < (hx_node_id) 0)) {
//		fprintf( stderr, "got next terminal\n" );
		return 0;
	} else {
//		fprintf( stderr, "node_mask_c == %d\n", (int) iter->node_mask_c );
//		fprintf( stderr, "tr == %d\n", tr );
//		fprintf( stderr, "no next terminal... getting next vector\n" );
		int r	= _hx_index_iter_next_vector( iter );
		if (r != 0) {
			return r;
		}
	}
	
	return 0;
}


int hx_index_write( hx_index* i, hx_storage_manager* s, FILE* f ) {
	fputc( 'I', f );
	fwrite( i->order, sizeof( int ), 3, f );
	return hx_head_write( hx_storage_block_from_id( s, i->head ), f );
}

hx_index* hx_index_read( hx_storage_manager* s, FILE* f, int buffer ) {
	size_t read;
	int c	= fgetc( f );
	if (c != 'I') {
//		fprintf( stderr, "*** Bad header cookie trying to read index from file.\n" );
		return NULL;
	}
	hx_index* i	= (hx_index*) hx_storage_new_block( s, sizeof( hx_index ) );
	read	= fread( i->order, sizeof( int ), 3, f );
	if (read == 0 || (i->head = hx_storage_id_from_block( s, hx_head_read( s, f, buffer ))) == 0) {
		hx_storage_release_block( s, i );
		return NULL;
	} else {
		return i;
	}
}

int _hx_index_got_head_trigger ( hx_index_iter* iter, hx_node_id n ) {
	if (HX_INDEX_ITER_DUP_A == iter->node_dup_b) {
// 		fprintf( stderr, "Got a new head item... masking vector values to %d...\n", (int) n );
		iter->node_mask_b	= n;
	}
	if (HX_INDEX_ITER_DUP_A == iter->node_dup_c) {
// 		fprintf( stderr, "Got a new head item... masking object values to %d...\n", (int) n );
		iter->node_mask_c	= n;
	}
	return 0;
}

int _hx_index_got_vector_trigger ( hx_index_iter* iter, hx_node_id n ) {
	if (HX_INDEX_ITER_DUP_B == iter->node_dup_c) {
// 		fprintf( stderr, "Got a new vector item... masking object values to %d...\n", (int) n );
		iter->node_mask_c	= n;
	}
	return 0;
}

int hx_index_iter_is_sorted_by_index ( hx_index_iter* iter, int index ) {
	hx_node_id masks[3]	= { iter->node_mask_a, iter->node_mask_b, iter->node_mask_c };
// 	fprintf( stderr, ">>> %d\n", index );
// 	fprintf( stderr, "*** masks: { %d, %d, %d }\n", (int) masks[0], (int) masks[1], (int) masks[2] );
// 	fprintf( stderr, "*** order: { %d, %d, %d }\n", iter->index->order[0], iter->index->order[1], iter->index->order[2] );
	int* order	= iter->index->order;
	if (index == order[0]) {
		return 1;
	} else if (index == order[1]) {
		return (masks[0] > 0);
	} else if (index == order[2]) {
		return (masks[0] > 0 && masks[1] > 0);
	} else {
		fprintf( stderr, "*** not a valid triple position index in call to hx_index_iter_is_sorted_by_index\n" );
		return -1;
	}
}
