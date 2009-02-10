#include "mergejoin.h"

int _hx_mergejoin_get_lhs_batch ( _hx_mergejoin_iter_vb_info* info );

int _hx_mergejoin_iter_vb_finished ( void* data ) {
//	fprintf( stderr, "*** _hx_mergejoin_iter_vb_finished\n" );
	_hx_mergejoin_iter_vb_info* info	= (_hx_mergejoin_iter_vb_info*) data;
	if (info->started == 0) {
		_hx_mergejoin_iter_vb_next( info );
	}
//	fprintf( stderr, "- finished == %d\n", info->finished );
	return info->finished;
}

int _hx_mergejoin_iter_vb_current ( void* data, void* results ) {
//	fprintf( stderr, "*** _hx_mergejoin_iter_vb_current\n" );
	_hx_mergejoin_iter_vb_info* info	= (_hx_mergejoin_iter_vb_info*) data;
	hx_variablebindings* rb;
	hx_variablebindings_iter_current( info->rhs, &rb );
//	fprintf( stderr, "- rb: %p\n", (void*) rb );
	
//	fprintf( stderr, "- current batch has %d items\n", info->batch_size );
//	fprintf( stderr, "- current batch index is %d\n", info->current_batch_join_index );
//	fprintf( stderr, "- current batch item is %p\n", (void*) info->batch[ info->current_batch_join_index ] );
	hx_variablebindings* ra	= info->batch[ info->current_batch_join_index ];
//	fprintf( stderr, "- ra: %p\n", (void*) ra );
	hx_variablebindings** bindings	= (hx_variablebindings**) results;
	
	// merge the bindings
// 	hx_variablebindings_debug( ra, NULL );
// 	hx_variablebindings_debug( rb, NULL );
	
	hx_node_id* values	= calloc( info->size, sizeof( hx_node_id ) );
	int lhs_size		= hx_variablebindings_iter_columns( info->lhs );
	char** lhs_names	= hx_variablebindings_iter_names( info->lhs );
	int rhs_size	= hx_variablebindings_iter_columns( info->rhs );
	char** rhs_names	= hx_variablebindings_iter_names( info->rhs );
	for (int i = 0; i < info->size; i++) {
		char* name	= info->names[ i ];
// 		fprintf( stderr, "filling node value for column %s (%d)\n", name, i );
		for (int j = 0; j < lhs_size; j++) {
			if (strcmp( name, lhs_names[j] ) == 0) {
				values[i]	= hx_variablebindings_node_for_binding( ra, j );
			}
		}
		for (int j = 0; j < rhs_size; j++) {
			if (strcmp( name, rhs_names[j] ) == 0) {
				values[i]	= hx_variablebindings_node_for_binding( rb, j );
			}
		}
	}
	
	hx_variablebindings* b	= hx_new_variablebindings( info->size, info->names, values );
	*bindings	= b;
	return 0;
}

int _hx_mergejoin_iter_vb_next ( void* data ) {
//	fprintf( stderr, "*** _hx_mergejoin_iter_vb_next\n" );
	_hx_mergejoin_iter_vb_info* info	= (_hx_mergejoin_iter_vb_info*) data;
	info->current_batch_join_index++;
	if (info->batch_size == 0 || info->current_batch_join_index >= info->batch_size) {
		fprintf( stderr, "- getting new batch from LHS\n" );
		if (_hx_mergejoin_get_lhs_batch( info ) == 1) {
			info->finished	= 1;
			return 1;
		} else {
			fprintf( stderr, "- got LHS with key = %d, batch size = %d\n", (int) info->batch_id, info->batch_size );
		}
		hx_node_id rhs_id	= (hx_node_id) 0;
		
NEXTRHS:	
		do {
			if (info->started > 0) {
				fprintf( stderr, "- getting next item from RHS\n" );
				hx_variablebindings_iter_next( info->rhs );
			} else {
				info->started	= 1;
			}
			if (hx_variablebindings_iter_finished( info->rhs ) == 1) {
				fprintf( stderr, "- RHS is finished. returning.\n" );
				info->finished	= 1;
				return 1;
			} else {
				hx_variablebindings* rb;
				hx_variablebindings_iter_current( info->rhs, &rb );
				rhs_id	= hx_variablebindings_node_for_binding( rb, info->rhs_index );
//				fprintf( stderr, "- got RHS with key = %d\n", (int) rhs_id );
			}
		} while (rhs_id < info->batch_id);
		
		if (rhs_id > info->batch_id) {
			if (_hx_mergejoin_get_lhs_batch( info ) != 0) {
				info->finished	= 1;
				return 1;
			} else {
				goto NEXTRHS;
			}
		}
		
		return 0;
	} else {
		fprintf( stderr, "- moving to new item from LHS\n" );
		return 0;
	}
}


int _hx_mergejoin_iter_vb_free ( void* data ) {
	_hx_mergejoin_iter_vb_info* info	= (_hx_mergejoin_iter_vb_info*) data;
	hx_free_variablebindings_iter( info->lhs, 0 );
	hx_free_variablebindings_iter( info->rhs, 0 );
	free( info->names );
	free( info );
	return 0;
}


int _hx_mergejoin_iter_vb_columns ( void* data ) {
	_hx_mergejoin_iter_vb_info* info	= (_hx_mergejoin_iter_vb_info*) data;
	return info->size;
}


char** _hx_mergejoin_iter_vb_names ( void* data ) {
	_hx_mergejoin_iter_vb_info* info	= (_hx_mergejoin_iter_vb_info*) data;
	return info->names;
}


hx_variablebindings_iter* hx_new_mergejoin_iter ( hx_variablebindings_iter* lhs, int lhs_index, hx_variablebindings_iter* rhs, int rhs_index ) {
	hx_variablebindings_iter_vtable* vtable	= malloc( sizeof( hx_variablebindings_iter_vtable ) );
	vtable->finished	= _hx_mergejoin_iter_vb_finished;
	vtable->current		= _hx_mergejoin_iter_vb_current;
	vtable->next		= _hx_mergejoin_iter_vb_next;
	vtable->free		= _hx_mergejoin_iter_vb_free;
	vtable->names		= _hx_mergejoin_iter_vb_names;
	vtable->columns		= _hx_mergejoin_iter_vb_columns;
	
	int seen_names	= 0;
	int lhs_size		= hx_variablebindings_iter_columns( lhs );
	char** lhs_names	= hx_variablebindings_iter_names( lhs );
	int rhs_size	= hx_variablebindings_iter_columns( rhs );
	char** rhs_names	= hx_variablebindings_iter_names( rhs );
	
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
	for (int i = 0; i < hx_variablebindings_iter_columns( rhs ); i++) {
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
	
	char** merged_names	= calloc( seen_names, sizeof( char* ) );
	for (int i = 0; i < seen_names; i++) {
		merged_names[ i ]	= names[ i ];
	}
	_hx_mergejoin_iter_vb_info* info	= (_hx_mergejoin_iter_vb_info*) calloc( 1, sizeof( _hx_mergejoin_iter_vb_info ) );
	info->batch_size		= 0;
	info->batch				= (hx_variablebindings**) calloc( NODE_LIST_ALLOC_SIZE, sizeof( hx_variablebindings* ) );
	info->batch_alloc_size	= NODE_LIST_ALLOC_SIZE;
	info->batch_id			= (hx_node_id) 0;
	info->finished			= 0;
	info->started			= 0;
	info->lhs				= lhs;
	info->lhs_index			= lhs_index;
	info->rhs				= rhs;
	info->rhs_index			= rhs_index;
	info->size				= seen_names;
	info->names				= merged_names;
	info->current_batch_join_index	= -1;
	hx_variablebindings_iter* iter	= hx_variablebindings_new_iter( vtable, (void*) info );
//	hx_variablebindings_iter_next( iter );
	return iter;
}

int _hx_mergejoin_get_batch ( _hx_mergejoin_iter_vb_info* info, hx_variablebindings_iter* iter, int join_column, hx_node_id* batch_id, int* batch_size, int* batch_alloc_size, hx_variablebindings*** batch ) {
	hx_variablebindings* b;
	*batch_size	= 0;
	
	if (hx_variablebindings_iter_finished( iter )) {
		*batch_size	= 0;
		return 1;
	}
	
	hx_variablebindings_iter_current( iter, &b );
	hx_node_id cur	= hx_variablebindings_node_for_binding( b, join_column );
	(*batch)[ (*batch_size)++ ]	= b;
	hx_variablebindings_iter_next( iter );
	
	while (!hx_variablebindings_iter_finished( iter )) {
		hx_variablebindings_iter_current( iter, &b );
		hx_node_id id	= hx_variablebindings_node_for_binding( b, join_column );
		if (id == cur) {
			if (*batch_size >= *batch_alloc_size) {
				int size	= *batch_alloc_size * 2;
				hx_variablebindings** new	= calloc( size, sizeof( hx_variablebindings* ) );
				if (new == NULL) {
					return -1;
				}
				for (int i = 0; i < *batch_size; i++) {
					new[i]	= (*batch)[i];
				}
				free( *batch );
				*batch	= new;
				*batch_alloc_size	= size;
			}
			(*batch)[ (*batch_size)++ ]	= b;
			hx_variablebindings_iter_next( iter );
		} else {
			break;
		}
	}
	
	if (*batch_size > 0) {
		*batch_id	= cur;
//		fprintf( stderr, "- batch:\n" );
		for (int i = 0; i < *batch_size; i++) {
//			fprintf( stderr, "- [%d] - ", i );
//			hx_variablebindings_debug( info->batch[ i ], NULL );
		}
		return 0;
	} else {
		info->finished	= 1;
		*batch_size	= 0;
		return 1;
	}
}

int _hx_mergejoin_get_lhs_batch ( _hx_mergejoin_iter_vb_info* info ) {
	return _hx_mergejoin_get_batch( info, info->lhs, info->lhs_index, &( info->batch_id ), &( info->batch_size ), &( info->batch_alloc_size ), &( info->batch ) );
}

int _hx_mergejoin_join_names ( hx_variablebindings* lhs, hx_variablebindings* rhs, char*** merged_names, int* size ) {
	int seen_names	= 0;
	int lhs_size		= hx_variablebindings_size( lhs );
	char** lhs_names	= hx_variablebindings_names( lhs );
	int rhs_size		= hx_variablebindings_size( rhs );
	char** rhs_names	= hx_variablebindings_names( rhs );
	
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

hx_variablebindings* hx_mergejoin_join_variablebindings( hx_variablebindings* left, hx_variablebindings* right ) {
	int size;
	char** names;
	_hx_mergejoin_join_names( left, right, &names, &size );
// 	fprintf( stderr, "%d shared names\n", size );
	hx_variablebindings* b;
	
	hx_node_id* values	= calloc( size, sizeof( hx_node_id ) );
	int lhs_size		= hx_variablebindings_size( left );
	char** lhs_names	= hx_variablebindings_names( left );
	int rhs_size	= hx_variablebindings_size( right );
	char** rhs_names	= hx_variablebindings_names( right );
	for (int i = 0; i < size; i++) {
		char* name	= names[ i ];
// 		fprintf( stderr, "filling node value for column %s (%d)\n", name, i );
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

hx_variablebindings** hx_mergejoin_cross ( hx_variablebindings** left, int left_size, hx_variablebindings** right, int right_size ) {
	int size	= left_size * right_size;
	hx_variablebindings** crossed	= calloc( size, sizeof( hx_variablebindings* ) );
	
	int seen	= 0;
// 	fprintf( stderr, "crossing %p(%d) and %p(%d)\n", (void*) left, left_size, (void*) right, right_size );
	for (int i = 0; i < left_size; i++) {
		for (int j = 0; j < right_size; j++) {
			hx_variablebindings* join	= hx_mergejoin_join_variablebindings( left[i], right[j] );
			crossed[ seen++ ]	= join;
		}
	}
	return crossed;
}

void hx_mergejoin_run ( void* data, hx_nodemap* map ) {
	_hx_mergejoin_iter_vb_info* info	= (_hx_mergejoin_iter_vb_info*) data;
	hx_variablebindings_iter* left		= info->lhs;
	hx_variablebindings_iter* right		= info->rhs;
	
	int lhs_batch_alloc	= NODE_LIST_ALLOC_SIZE;
	int rhs_batch_alloc	= NODE_LIST_ALLOC_SIZE;
	int lhs_batch_size, rhs_batch_size;
	hx_node_id lhs_key, rhs_key;
	hx_variablebindings **lhs_batch	= (hx_variablebindings**) calloc( NODE_LIST_ALLOC_SIZE, sizeof( hx_variablebindings* ) );
	hx_variablebindings **rhs_batch	= (hx_variablebindings**) calloc( NODE_LIST_ALLOC_SIZE, sizeof( hx_variablebindings* ) );
	
	_hx_mergejoin_get_batch( info, info->lhs, info->lhs_index, &lhs_key, &lhs_batch_size, &lhs_batch_alloc, &lhs_batch );
	_hx_mergejoin_get_batch( info, info->rhs, info->rhs_index, &rhs_key, &rhs_batch_size, &rhs_batch_alloc, &rhs_batch );
	
	while ((lhs_batch_size != 0) && (rhs_batch_size != 0)) {
		if (lhs_key == rhs_key) {
			hx_variablebindings** crossed	= hx_mergejoin_cross( lhs_batch, lhs_batch_size, rhs_batch, rhs_batch_size );
			for (int i = 0; i < lhs_batch_size * rhs_batch_size; i++) {
				char* string;
				hx_variablebindings_string( crossed[i], map, &string );
				fprintf( stdout, "%s\n", string );
				free(string);
			}
			
			_hx_mergejoin_get_batch( info, info->lhs, info->lhs_index, &lhs_key, &lhs_batch_size, &lhs_batch_alloc, &lhs_batch );
			_hx_mergejoin_get_batch( info, info->rhs, info->rhs_index, &rhs_key, &rhs_batch_size, &rhs_batch_alloc, &rhs_batch );
		} else if (lhs_key < rhs_key) {
			_hx_mergejoin_get_batch( info, info->lhs, info->lhs_index, &lhs_key, &lhs_batch_size, &lhs_batch_alloc, &lhs_batch );
		} else { // left_key > right_key
			_hx_mergejoin_get_batch( info, info->rhs, info->rhs_index, &rhs_key, &rhs_batch_size, &rhs_batch_alloc, &rhs_batch );
		}
	}
}

