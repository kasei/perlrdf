#include "mergejoin.h"

// prototypes
int _hx_mergejoin_join_vb_names ( hx_variablebindings* lhs, hx_variablebindings* rhs, char*** merged_names, int* size );
int _hx_mergejoin_join_iter_names ( hx_variablebindings_iter* lhs, hx_variablebindings_iter* rhs, char*** merged_names, int* size );
int _hx_mergejoin_join_names ( char** lhs_names, int lhs_size, char** rhs_names, int rhs_size, char*** merged_names, int* size );
int _hx_mergejoin_get_lhs_batch ( _hx_mergejoin_iter_vb_info* info );
int _hx_mergejoin_get_rhs_batch ( _hx_mergejoin_iter_vb_info* info );
int _hx_mergejoin_debug ( void* info, char* header, int indent );

// implementations

int _hx_mergejoin_prime_first_result ( _hx_mergejoin_iter_vb_info* info ) {
	_hx_mergejoin_get_lhs_batch( info );
	_hx_mergejoin_get_rhs_batch( info );
	info->started	= 1;
	while ((info->lhs_batch_size != 0) && (info->rhs_batch_size != 0)) {
//		fprintf( stderr, "looking for match while priming first result\n" );
//		fprintf( stderr, "batch sizes %d <=> %d\n", info->lhs_batch_size, info->rhs_batch_size );
//		fprintf( stderr, "keys %d <=> %d\n", (int) info->lhs_key, (int) info->rhs_key );
		if (info->lhs_key == info->rhs_key) {
//			fprintf( stderr, "found matching keys. indexes: %d <=> %d\n", info->lhs_batch_index, info->rhs_batch_index );
			hx_variablebindings* left	= info->lhs_batch[ info->lhs_batch_index ];
			hx_variablebindings* right	= info->rhs_batch[ info->rhs_batch_index ];
			info->current	= hx_variablebindings_natural_join( left, right );
// 			hx_free_variablebindings( right, 0 );
			if (info->current != NULL) {
				break;
			} else {
				_hx_mergejoin_iter_vb_next( info );
			}
		} else if (info->lhs_key < info->rhs_key) {
// 			hx_free_variablebindings( info->lhs_batch[ info->lhs_batch_index ], 0 );
			_hx_mergejoin_get_lhs_batch( info );
		} else { // left_key > right_key
// 			for (int i = info->rhs_batch_index; i < info->rhs_batch_size; i++) {
// 				hx_free_variablebindings( info->rhs_batch[ i ], 0 );
// 			}
			_hx_mergejoin_get_rhs_batch( info );
		}
	}
	if ((info->lhs_batch_size == 0) || (info->rhs_batch_size == 0)) {
		info->finished	= 1;
		return 1;
	} else {
		info->lhs_batch_index	= 0;
		info->rhs_batch_index	= 0;
		return 0;
	}
}

int _hx_mergejoin_iter_vb_finished ( void* data ) {
//	fprintf( stderr, "*** _hx_mergejoin_iter_vb_finished\n" );
	_hx_mergejoin_iter_vb_info* info	= (_hx_mergejoin_iter_vb_info*) data;
	if (info->started == 0) {
		_hx_mergejoin_prime_first_result( info );
	}
//	fprintf( stderr, "- finished == %d\n", info->finished );
	return info->finished;
}

int _hx_mergejoin_iter_vb_current ( void* data, void* results ) {
//	fprintf( stderr, "*** _hx_mergejoin_iter_vb_current\n" );
	_hx_mergejoin_iter_vb_info* info	= (_hx_mergejoin_iter_vb_info*) data;
	if (info->started == 0) {
		_hx_mergejoin_prime_first_result( info );
	}
	
	hx_variablebindings** b	= (hx_variablebindings**) results;
	*b	= info->current;
	return 0;
}

int _hx_mergejoin_iter_vb_next ( void* data ) {
// 	fprintf( stderr, "*** _hx_mergejoin_iter_vb_next\n" );
	_hx_mergejoin_iter_vb_info* info	= (_hx_mergejoin_iter_vb_info*) data;
	if (info->started == 0) {
		_hx_mergejoin_prime_first_result( info );
	}
	

	while ((info->lhs_batch_size != 0) && (info->rhs_batch_size != 0)) {
// 		fprintf( stderr, "- incrementing RHS index\n" );
		info->rhs_batch_index++;
		if (info->rhs_batch_index >= info->rhs_batch_size) {
// 			fprintf( stderr, "- end of RHS. incrementing LHS index and resetting RHS index to 0\n" );
			info->rhs_batch_index	= 0;
			info->lhs_batch_index++;
			if (info->lhs_batch_index >= info->lhs_batch_size) {
// 				fprintf( stderr, "- end of LHS. finding new matching batches...\n" );
				_hx_mergejoin_get_lhs_batch( info );
				_hx_mergejoin_get_rhs_batch( info );
				while ((info->lhs_batch_size != 0) && (info->rhs_batch_size != 0)) {
					if (info->lhs_key == info->rhs_key) {
						break;
					} else if (info->lhs_key < info->rhs_key) {
						_hx_mergejoin_get_lhs_batch( info );
					} else { // left_key > right_key
						_hx_mergejoin_get_rhs_batch( info );
					}
				}
				if ((info->lhs_batch_size == 0) || (info->rhs_batch_size == 0)) {
// 					fprintf( stderr, "- no more matching batches. iterator is finished\n" );
					info->finished	= 1;
					return 1;
				} else {
// 					fprintf( stderr, "- found matching batches on node id %d\n", (int) info->lhs_key );
					info->lhs_batch_index	= 0;
					info->rhs_batch_index	= 0;
//					return 0;
				}
			}
		}
		
		hx_variablebindings* left	= info->lhs_batch[ info->lhs_batch_index ];
		hx_variablebindings* right	= info->rhs_batch[ info->rhs_batch_index ];
		info->current	= hx_variablebindings_natural_join( left, right );
		if (info->current != NULL) {
// 			fprintf( stderr, "- got result with natural join\n" );
			break;
		} else {
// 			fprintf( stderr, "- failed natural join\n" );
		}
	}
	return 0;
}

int _hx_mergejoin_iter_vb_free ( void* data ) {
	_hx_mergejoin_iter_vb_info* info	= (_hx_mergejoin_iter_vb_info*) data;
	hx_free_variablebindings_iter( info->lhs, 0 );
	hx_free_variablebindings_iter( info->rhs, 0 );
	free( info->names );
	free( info );
	return 0;
}

int _hx_mergejoin_iter_vb_size ( void* data ) {
	_hx_mergejoin_iter_vb_info* info	= (_hx_mergejoin_iter_vb_info*) data;
	return info->size;
}

char** _hx_mergejoin_iter_vb_names ( void* data ) {
	_hx_mergejoin_iter_vb_info* info	= (_hx_mergejoin_iter_vb_info*) data;
	return info->names;
}

int _hx_mergejoin_iter_sorted_by ( void* data, int index ) {
	_hx_mergejoin_iter_vb_info* info	= (_hx_mergejoin_iter_vb_info*) data;
	char* name	= info->names[ index ];
	int lhs_size		= hx_variablebindings_iter_size( info->lhs );
	char** lhs_names	= hx_variablebindings_iter_names( info->lhs );
	int lhs_index		= hx_variablebindings_column_index( info->lhs, name );
	return (lhs_index == info->lhs_index);
}

int _hx_mergejoin_debug ( void* data, char* header, int indent ) {
	_hx_mergejoin_iter_vb_info* info	= (_hx_mergejoin_iter_vb_info*) data;
	for (int i = 0; i < indent; i++) fwrite( " ", sizeof( char ), 1, stderr );
	fprintf( stderr, "%s mergejoin iterator\n", header );
	hx_variablebindings_iter_debug( info->lhs, header, indent + 4 );
	hx_variablebindings_iter_debug( info->rhs, header, indent + 4 );
	return 0;
}

hx_variablebindings_iter* hx_new_mergejoin_iter ( hx_variablebindings_iter* _lhs, hx_variablebindings_iter* _rhs ) {
	int asize		= hx_variablebindings_iter_size( _lhs );
	char** anames	= hx_variablebindings_iter_names( _lhs );
	int bsize		= hx_variablebindings_iter_size( _rhs );
	char** bnames	= hx_variablebindings_iter_names( _rhs );
	int lhs_index, rhs_index;
	for (int i = 0; i < asize; i++) {
		int set	= 0;
		for (int j = 0; j < bsize; j++) {
			if (strcmp( anames[i], bnames[j] ) == 0) {
				lhs_index	= i;
				rhs_index	= j;
				set			= 1;
				break;
			}
		}
		if (set == 1)
			break;
	}
//	fprintf( stderr, "joining A(%s) X B(%s)\n", anames[ lhs_index ], bnames[ rhs_index ] );
	
	hx_variablebindings_iter* lhs	= hx_variablebindings_sort_iter( _lhs, lhs_index );
	hx_variablebindings_iter* rhs	= hx_variablebindings_sort_iter( _rhs, rhs_index );
	
	
	hx_variablebindings_iter_vtable* vtable	= malloc( sizeof( hx_variablebindings_iter_vtable ) );
	vtable->finished	= _hx_mergejoin_iter_vb_finished;
	vtable->current		= _hx_mergejoin_iter_vb_current;
	vtable->next		= _hx_mergejoin_iter_vb_next;
	vtable->free		= _hx_mergejoin_iter_vb_free;
	vtable->names		= _hx_mergejoin_iter_vb_names;
	vtable->size		= _hx_mergejoin_iter_vb_size;
	vtable->sorted_by	= _hx_mergejoin_iter_sorted_by;
	vtable->debug		= _hx_mergejoin_debug;
	
	int size;
	char** merged_names;
	_hx_mergejoin_join_iter_names( lhs, rhs, &merged_names, &size );
	_hx_mergejoin_iter_vb_info* info	= (_hx_mergejoin_iter_vb_info*) calloc( 1, sizeof( _hx_mergejoin_iter_vb_info ) );
	
	info->current			= NULL;
	info->lhs				= lhs;
	info->lhs_index			= lhs_index;
	info->rhs				= rhs;
	info->rhs_index			= rhs_index;
	info->size				= size;
	info->names				= merged_names;
	info->finished			= 0;
	info->started			= 0;
	
	info->lhs_batch_size	= 0;
	info->rhs_batch_size	= 0;
	
	info->lhs_batch_index	= 0;
	info->rhs_batch_index	= 0;
	
	info->lhs_batch			= (hx_variablebindings**) calloc( NODE_LIST_ALLOC_SIZE, sizeof( hx_variablebindings* ) );
	info->rhs_batch			= (hx_variablebindings**) calloc( NODE_LIST_ALLOC_SIZE, sizeof( hx_variablebindings* ) );
	
	info->lhs_batch_alloc_size	= NODE_LIST_ALLOC_SIZE;
	info->rhs_batch_alloc_size	= NODE_LIST_ALLOC_SIZE;
	
	info->lhs_key		= (hx_node_id) 0;
	info->rhs_key		= (hx_node_id) 0;
	
	hx_variablebindings_iter* iter	= hx_variablebindings_new_iter( vtable, (void*) info );
	return iter;
}

int _hx_mergejoin_get_batch ( _hx_mergejoin_iter_vb_info* info, hx_variablebindings_iter* iter, int join_column, hx_node_id* batch_id, int* batch_size, int* batch_alloc_size, hx_variablebindings*** batch ) {
	hx_variablebindings* b;
	*batch_size	= 0;
	
	if (hx_variablebindings_iter_finished( iter )) {
// 		fprintf( stderr, "- iterator is finished (in get_batch)\n" );
		*batch_size	= 0;
		return 1;
	}
	
	hx_variablebindings_iter_current( iter, &b );
	hx_node_id cur	= hx_variablebindings_node_for_binding( b, join_column );
// 	fprintf( stderr, "*** get_batch: node id %d\n", (int) cur );
	(*batch)[ (*batch_size)++ ]	= b;
	hx_variablebindings_iter_next( iter );
	
	while (!hx_variablebindings_iter_finished( iter )) {
		hx_variablebindings_iter_current( iter, &b );
		hx_node_id id	= hx_variablebindings_node_for_binding( b, join_column );
// 		fprintf( stderr, "*** get_batch: next id %d\n", (int) id );
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
// 		fprintf( stderr, "- batch:\n" );
// 		for (int i = 0; i < *batch_size; i++) {
// 			fprintf( stderr, "- [%d] - ", i );
// 			hx_variablebindings_debug( (*batch)[ i ], NULL );
// 		}
		return 0;
	} else {
		info->finished	= 1;
		*batch_size	= 0;
		return 1;
	}
}
int _hx_mergejoin_get_lhs_batch ( _hx_mergejoin_iter_vb_info* info ) {
	return _hx_mergejoin_get_batch( info, info->lhs, info->lhs_index, &( info->lhs_key ), &( info->lhs_batch_size ), &( info->lhs_batch_alloc_size ), &( info->lhs_batch ) );
}
int _hx_mergejoin_get_rhs_batch ( _hx_mergejoin_iter_vb_info* info ) {
	return _hx_mergejoin_get_batch( info, info->rhs, info->rhs_index, &( info->rhs_key ), &( info->rhs_batch_size ), &( info->rhs_batch_alloc_size ), &( info->rhs_batch ) );
}

int _hx_mergejoin_join_vb_names ( hx_variablebindings* lhs, hx_variablebindings* rhs, char*** merged_names, int* size ) {
	int lhs_size		= hx_variablebindings_size( lhs );
	char** lhs_names	= hx_variablebindings_names( lhs );
	int rhs_size		= hx_variablebindings_size( rhs );
	char** rhs_names	= hx_variablebindings_names( rhs );
	return _hx_mergejoin_join_names( lhs_names, lhs_size, rhs_names, rhs_size, merged_names, size );
}
int _hx_mergejoin_join_iter_names ( hx_variablebindings_iter* lhs, hx_variablebindings_iter* rhs, char*** merged_names, int* size ) {
	int lhs_size		= hx_variablebindings_iter_size( lhs );
	char** lhs_names	= hx_variablebindings_iter_names( lhs );
	int rhs_size		= hx_variablebindings_iter_size( rhs );
	char** rhs_names	= hx_variablebindings_iter_names( rhs );
	return _hx_mergejoin_join_names( lhs_names, lhs_size, rhs_names, rhs_size, merged_names, size );
}
int _hx_mergejoin_join_names ( char** lhs_names, int lhs_size, char** rhs_names, int rhs_size, char*** merged_names, int* size ) {
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

// return the natural join of two variable bindings 
hx_variablebindings* hx_mergejoin_join_variablebindings( hx_variablebindings* left, hx_variablebindings* right ) {
	int size;
	char** names;
	_hx_mergejoin_join_vb_names( left, right, &names, &size );
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
