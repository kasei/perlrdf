#include "materialize.h"
#include "mergejoin.h"

// prototypes
int _hx_materialize_join_vb_names ( hx_variablebindings* lhs, hx_variablebindings* rhs, char*** merged_names, int* size );
int _hx_materialize_join_iter_names ( hx_variablebindings_iter* lhs, hx_variablebindings_iter* rhs, char*** merged_names, int* size );
int _hx_materialize_join_names ( char** lhs_names, int lhs_size, char** rhs_names, int rhs_size, char*** merged_names, int* size );
int _hx_materialize_debug ( void* info, char* header, int indent );
int _hx_materialize_prime_results ( _hx_materialize_iter_vb_info* info );

// implementations

int _hx_materialize_iter_vb_finished ( void* data ) {
//	fprintf( stderr, "*** _hx_materialize_iter_vb_finished (%p)\n", (void*) data );
	_hx_materialize_iter_vb_info* info	= (_hx_materialize_iter_vb_info*) data;
	if (info->started == 0) {
		_hx_materialize_prime_results( info );
	}
	
//	fprintf( stderr, "- finished == %d\n", info->finished );
	return info->finished;
}

int _hx_materialize_iter_vb_current ( void* data, void* results ) {
//	fprintf( stderr, "*** _hx_materialize_iter_vb_current\n" );
	_hx_materialize_iter_vb_info* info	= (_hx_materialize_iter_vb_info*) data;
	if (info->started == 0) {
		_hx_materialize_prime_results( info );
	}
	
	if (info->index >= info->length) {
		fprintf( stderr, "*** trying to get the materialized iterator's current variable binding, but it's passed the end of results.\n" );
	}
	hx_variablebindings** b	= (hx_variablebindings**) results;
	*b	= hx_copy_variablebindings( info->bindings[ info->index ] );
	return 0;
}

int _hx_materialize_iter_vb_next ( void* data ) {
// 	fprintf( stderr, "*** _hx_materialize_iter_vb_next\n" );
	_hx_materialize_iter_vb_info* info	= (_hx_materialize_iter_vb_info*) data;
	if (info->started == 0) {
		_hx_materialize_prime_results( info );
	}
	
	info->index++;
	if (info->index >= info->length) {
		info->finished	= 1;
		return 1;
	} else {
		return 0;
	}
}

int _hx_materialize_iter_vb_free ( void* data ) {
	_hx_materialize_iter_vb_info* info	= (_hx_materialize_iter_vb_info*) data;
	if (info->started == 0) {
		_hx_materialize_prime_results( info );
	}
	
	for (int i = 0; i < info->length; i++) {
		hx_free_variablebindings( info->bindings[i], 0 );
	}
	free( info->bindings );
	for (int i = 0; i < info->size; i++) {
		free( info->names[i] );
	}
	free( info->names );
	free( info );
	return 0;
}

int _hx_materialize_iter_vb_size ( void* data ) {
	_hx_materialize_iter_vb_info* info	= (_hx_materialize_iter_vb_info*) data;
	return info->size;
}

char** _hx_materialize_iter_vb_names ( void* data ) {
	_hx_materialize_iter_vb_info* info	= (_hx_materialize_iter_vb_info*) data;
	return info->names;
}

int _hx_materialize_iter_sorted_by ( void* data, int index ) {
	_hx_materialize_iter_vb_info* info	= (_hx_materialize_iter_vb_info*) data;
	return (index == info->sorted_by);
}

hx_variablebindings_iter* hx_new_materialize_iter ( hx_variablebindings_iter* iter ) {
	int size		= hx_variablebindings_iter_size( iter );
	char** _names	= hx_variablebindings_iter_names( iter );
	char** names	= (char**) calloc( size, sizeof( char* ) );
	int sorted_by	= -1;
	for (int i = 0; i < size; i++) {
		char* new	= (char*) calloc( strlen( _names[i] ) + 1, sizeof( char ) );
		strcpy( new, _names[i] );
		names[i]	= new;
		if (hx_variablebindings_iter_is_sorted_by_index( iter, i )) {
			sorted_by	= i;
		}
	}
	
	hx_variablebindings_iter_vtable* vtable	= malloc( sizeof( hx_variablebindings_iter_vtable ) );
	vtable->finished	= _hx_materialize_iter_vb_finished;
	vtable->current		= _hx_materialize_iter_vb_current;
	vtable->next		= _hx_materialize_iter_vb_next;
	vtable->free		= _hx_materialize_iter_vb_free;
	vtable->names		= _hx_materialize_iter_vb_names;
	vtable->size		= _hx_materialize_iter_vb_size;
	vtable->sorted_by	= _hx_materialize_iter_sorted_by;
	vtable->debug		= _hx_materialize_debug;
	
	_hx_materialize_iter_vb_info* info	= (_hx_materialize_iter_vb_info*) calloc( 1, sizeof( _hx_materialize_iter_vb_info ) );
	info->started	= 0;
	info->finished	= 0;
	info->size		= size;
	info->index		= 0;
	info->sorted_by	= sorted_by;
	
	info->names		= names;
	info->iter		= iter;
	info->length	= 0;
	
	hx_variablebindings_iter* miter	= hx_variablebindings_new_iter( vtable, (void*) info );
	return miter;
}

int _hx_materialize_prime_results ( _hx_materialize_iter_vb_info* info ) {
	if (info->started == 0) {
		info->started	= 1;
		
		hx_variablebindings_iter* iter	= info->iter;
		char** names	= info->names;
		info->iter		= NULL;
		int alloc		= 32;
		hx_variablebindings** bindings	= calloc( alloc, sizeof( hx_variablebindings* ) );
		
		while (!hx_variablebindings_iter_finished( iter )) {
			hx_variablebindings* b;
			hx_variablebindings_iter_current( iter, &b );
			
			// replace the names array for this variable binding with our new copy,
			// because the one it's got is stored in the iterator we're materializing
			// and will be deallocated at the end of this function
			hx_variablebindings_set_names( b, names );
			
			bindings[ info->length++ ]	= b;
			if (info->length >= alloc) {
				alloc	= alloc * 2;
				hx_variablebindings** newbindings	= calloc( alloc, sizeof( hx_variablebindings* ) );
				if (newbindings == NULL) {
					hx_free_variablebindings_iter( iter, 1 );
					fprintf( stderr, "*** allocating space for %d materialized bindings failed\n", alloc );
					return 1;
				}
				for (int i = 0; i < info->length; i++) {
					newbindings[i]	= bindings[i];
				}
				free( bindings );
				bindings	= newbindings;
			}
			hx_variablebindings_iter_next( iter );
		}
		
		if (info->length == 0) {
			info->finished	= 1;
		}
		
		info->bindings	= bindings;
		hx_free_variablebindings_iter( iter, 1 );
		return 0;
	} else {
		// iterator is already materialized and started
		return 1;
	}
}

int hx_materialize_sort_iter_by_column ( hx_variablebindings_iter* iter, int index ) {
	_hx_materialize_iter_vb_info* info	= (_hx_materialize_iter_vb_info*) iter->ptr;
	if (info->started == 0) {
		_hx_materialize_prime_results( info );
	}
	
	_hx_materialize_bindings_sort_info* sorted	= calloc( info->length, sizeof( _hx_materialize_bindings_sort_info ) );
	if (sorted == NULL) {
		fprintf( stderr, "*** allocating space for sorting materialized bindings failed\n" );
		return 1;
	}
	
	for (int i = 0; i < info->length; i++) {
		sorted[i].index		= index;
		sorted[i].binding	= info->bindings[i];
	}
	
	qsort( sorted, info->length, sizeof( _hx_materialize_bindings_sort_info ), _hx_materialize_cmp_bindings_column );
	for (int i = 0; i < info->length; i++) {
		info->bindings[i]	= sorted[i].binding;
	}
	free( sorted );
	info->sorted_by	= index;
	return 0;
}

int hx_materialize_sort_iter ( hx_variablebindings_iter* iter ) {
	_hx_materialize_iter_vb_info* info	= (_hx_materialize_iter_vb_info*) iter->ptr;
	qsort( info->bindings, info->length, sizeof(hx_variablebindings*), _hx_materialize_cmp_bindings );
	info->sorted_by	= 0;
	return 0;
}

int _hx_materialize_cmp_bindings_column ( const void* _a, const void* _b ) {
	_hx_materialize_bindings_sort_info* a	= (_hx_materialize_bindings_sort_info*) _a;
	_hx_materialize_bindings_sort_info* b	= (_hx_materialize_bindings_sort_info*) _b;
	hx_node_id na	= hx_variablebindings_node_id_for_binding( a->binding, a->index );
	hx_node_id nb	= hx_variablebindings_node_id_for_binding( b->binding, b->index );
	if (na < nb) {
		return -1;
	} else if (na > nb) {
		return 1;
	} else {
		return 0;
	}
}

int _hx_materialize_cmp_bindings ( const void* _a, const void* _b ) {
	hx_variablebindings** a	= (hx_variablebindings**) _a;
	hx_variablebindings** b	= (hx_variablebindings**) _b;
	return hx_variablebindings_cmp( *a, *b );
}

void hx_materialize_iter_debug ( hx_variablebindings_iter* iter ) {
	fprintf( stderr, "Materialized iterator %p\n", (void*) iter );
	_hx_materialize_iter_vb_info* info	= (_hx_materialize_iter_vb_info*) iter->ptr;
	fprintf( stderr, "\tInfo: %p\n", (void*) info );
	fprintf( stderr, "\tLength: %d\n", (int) info->length );
	for (int i = 0; i < info->length; i++) {
		char* string;
		hx_variablebindings_string( info->bindings[i], NULL, &string );
		fprintf( stderr, "\t[%d] %s\n", i, string );
	}
}

int _hx_materialize_debug ( void* data, char* header, int _indent ) {
	_hx_materialize_iter_vb_info* info	= (_hx_materialize_iter_vb_info*) data;
	char* indent	= malloc( _indent + 1 );
	char* p			= indent;
	for (int i = 0; i < _indent; i++) *(p++) = ' ';
	*p	= (char) 0;
	
	fprintf( stderr, "%s%s materialize iterator\n", indent, header );
	
	fprintf( stderr, "%s%s  Info: %p\n", indent, header, (void*) info );
	fprintf( stderr, "%s%s  Length: %d\n", indent, header, (int) info->length );
	for (int i = 0; i < info->length; i++) {
		fprintf( stderr, "[%d]\n", i );
		char* string;
		hx_variablebindings_string( info->bindings[i], NULL, &string );
		fprintf( stderr, "%s%s  [%d] %s\n", indent, header, i, string );
	}
	return 0;
}
