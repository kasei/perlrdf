#include "bgp.h"
#include "mergejoin.h"

int _hx_bgp_selectivity_cmp ( const void* a, const void* b );
int _hx_bgp_sort_for_triple_join ( hx_triple* l, hx_triple* r );
int _hx_bgp_sort_for_vb_join ( hx_triple* l, hx_variablebindings_iter* iter );

typedef struct {
	uint64_t cost;
	hx_triple* triple;
} _hx_bgp_selectivity_t;

hx_bgp* hx_new_bgp ( int size, hx_triple** triples ) {
	hx_bgp* b	= (hx_bgp*) calloc( 1, sizeof( hx_bgp ) );
	b->size		= size;
	b->triples	= (hx_triple**) calloc( size, sizeof( hx_triple* ) );
	int vars	= 0;
	for (int i = 0; i < size; i++) {
		b->triples[i]	= triples[i];
		if (hx_node_is_variable( triples[i]->subject )) {
			int vid	= abs(hx_node_iv( triples[i]->subject ));
			if (vid > vars) {
				vars	= vid;
			}
		}
		if (hx_node_is_variable( triples[i]->object )) {
			int vid	= abs(hx_node_iv( triples[i]->object ));
			if (vid > vars) {
				vars	= vid;
			}
		}
		if (hx_node_is_variable( triples[i]->predicate )) {
			int vid	= abs(hx_node_iv( triples[i]->predicate ));
			if (vid > vars) {
				vars	= vid;
			}
		}
	}
	b->variables		= vars;
	b->variable_names	= (char**) calloc( vars, sizeof( char* ) );
	for (int i = 0; i < size; i++) {
		if (hx_node_is_variable( triples[i]->subject )) {
			int vid	= abs(hx_node_iv( triples[i]->subject ));
			hx_node_variable_name( triples[i]->subject, &( b->variable_names[ vid ] ) );
		}
		if (hx_node_is_variable( triples[i]->predicate )) {
			int vid	= abs(hx_node_iv( triples[i]->predicate ));
			hx_node_variable_name( triples[i]->predicate, &( b->variable_names[ vid ] ) );
		}
		if (hx_node_is_variable( triples[i]->object )) {
			int vid	= abs(hx_node_iv( triples[i]->object ));
			hx_node_variable_name( triples[i]->object, &( b->variable_names[ vid ] ) );
		}
	}
	return b;
}

hx_bgp* hx_new_bgp1 ( hx_triple* t1 ) {
	hx_bgp* b	= hx_new_bgp( 1, &t1 );
	return b;
}

hx_bgp* hx_new_bgp2 ( hx_triple* t1, hx_triple* t2 ) {
	hx_triple* triples[2];
	triples[0]	= t1;
	triples[1]	= t2;
	hx_bgp* b	= hx_new_bgp( 2, triples );
	return b;	
}

int hx_free_bgp ( hx_bgp* b ) {
	free( b->triples );
	free( b );
	return 0;
}

int hx_bgp_size ( hx_bgp* b ) {
	return b->size;
}

hx_triple* hx_bgp_triple ( hx_bgp* b, int i ) {
	return b->triples[ i ];
}

int _hx_bgp_string_concat ( char** string, char* new, int* alloc ) {
	int sl	= strlen(*string);
	int nl	= strlen(new);
	while (sl + nl + 1 >= *alloc) {
		*alloc	*= 2;
		char* newstring	= (char*) malloc( *alloc );
		if (newstring == NULL) {
			fprintf( stderr, "*** could not allocate memory for bgp string\n" );
			return 1;
		}
		strcpy( newstring, *string );
		free( *string );
		*string	= newstring;
	}
	char* str	= *string;
	char* base	= &( str[ sl ] );
	strcpy( base, new );
	return 0;
}

int hx_bgp_string ( hx_bgp* b, char** string ) {
	// XXX refactor hx_bgp_debug code into here, with dynamic memory allocation
	int alloc	= 256;
	char* str	= (char*) calloc( 1, alloc );
	
	int size	= hx_bgp_size( b );
	_hx_bgp_string_concat( &str, "{\n", &alloc );
	
	hx_node *last_s	= NULL;
	hx_node *last_p	= NULL;
	for (int i = 0; i < size; i++) {
		char *s, *p, *o;
		hx_triple* t	= hx_bgp_triple( b, i );
		hx_node_string( t->subject, &s );
		hx_node_string( t->predicate, &p );
		hx_node_string( t->object, &o );
		
		if (last_s != NULL) {
			if (hx_node_cmp(t->subject, last_s) == 0) {
				if (hx_node_cmp(t->predicate, last_p) == 0) {
					_hx_bgp_string_concat( &str, ", ", &alloc );
					_hx_bgp_string_concat( &str, o, &alloc );
				} else {
					_hx_bgp_string_concat( &str, " ;\n\t\t", &alloc );
					_hx_bgp_string_concat( &str, p, &alloc );
					_hx_bgp_string_concat( &str, " ", &alloc );
					_hx_bgp_string_concat( &str, o, &alloc );
				}
			} else {
				_hx_bgp_string_concat( &str, " .\n\t", &alloc );
				_hx_bgp_string_concat( &str, s, &alloc );
				_hx_bgp_string_concat( &str, " ", &alloc );
				_hx_bgp_string_concat( &str, p, &alloc );
				_hx_bgp_string_concat( &str, " ", &alloc );
				_hx_bgp_string_concat( &str, o, &alloc );
			}
		} else {
			_hx_bgp_string_concat( &str, "\t", &alloc );
			_hx_bgp_string_concat( &str, s, &alloc );
			_hx_bgp_string_concat( &str, " ", &alloc );
			_hx_bgp_string_concat( &str, p, &alloc );
			_hx_bgp_string_concat( &str, " ", &alloc );
			_hx_bgp_string_concat( &str, o, &alloc );
		}
		last_s	= t->subject;
		last_p	= t->predicate;
		free( s );
		free( p );
		free( o );
	}
	_hx_bgp_string_concat( &str, " .\n}\n", &alloc );
	*string	= str;
	return 0;
}

int hx_bgp_debug ( hx_bgp* b ) {
	char* string;
	int r	= hx_bgp_string( b, &string );
	if (r == 0) {
		fprintf( stderr, string );
		return 0;
	} else {
		fprintf( stderr, "hx_bgp_string didn't return success\n" );
		return 1;
	}
}

int hx_bgp_reorder ( hx_bgp* b, hx_hexastore* hx ) {
	int size	= hx_bgp_size( b );
	_hx_bgp_selectivity_t* s	= (_hx_bgp_selectivity_t*) calloc( size, sizeof( _hx_bgp_selectivity_t ) );
	for (int i = 0; i < size; i++) {
		hx_triple* t	= hx_bgp_triple( b, i );
		s[i].triple		= t;
		s[i].cost		= hx_count_statements( hx, t->subject, t->predicate, t->object );
	}
	
	qsort( s, size, sizeof( _hx_bgp_selectivity_t ), _hx_bgp_selectivity_cmp );
	
	for (int i = 0; i < size; i++) {
		b->triples[i]	= s[i].triple;
	}
	
	free( s );
	return 0;
}

hx_variablebindings_iter* hx_bgp_execute ( hx_bgp* b, hx_hexastore* hx ) {
//	hx_bgp_reorder( b, hx );
	int size	= hx_bgp_size( b );
	
	hx_triple* t0	= hx_bgp_triple( b, 0 );
	int sort;
	if (size > 1) {
		sort	= _hx_bgp_sort_for_triple_join( t0, hx_bgp_triple( b, 1 ) );
	} else {
		sort	= HX_SUBJECT;
	}
	
	hx_index_iter* titer0	= hx_get_statements( hx, t0->subject, t0->predicate, t0->object, sort );
	
	char *sname, *pname, *oname;
	hx_node_variable_name( t0->subject, &sname );
	hx_node_variable_name( t0->predicate, &pname );
	hx_node_variable_name( t0->object, &oname );
	hx_variablebindings_iter* iter	= hx_new_iter_variablebindings( titer0, sname, pname, oname );
	
	if (size > 1) {
		for (int i = 1; i < size; i++) {
			char *sname, *pname, *oname;
			hx_triple* t			= hx_bgp_triple( b, i );
			int jsort				= _hx_bgp_sort_for_vb_join( t, iter );
			hx_index_iter* titer	= hx_get_statements( hx, t->subject, t->predicate, t->object, jsort );
			hx_node_variable_name( t->subject, &sname );
			hx_node_variable_name( t->predicate, &pname );
			hx_node_variable_name( t->object, &oname );
			hx_variablebindings_iter* interm	= hx_new_iter_variablebindings( titer, sname, pname, oname );
			iter		= hx_new_mergejoin_iter( interm, iter );
		}
	}
	return iter;
}

int _hx_bgp_selectivity_cmp ( const void* _a, const void* _b ) {
	const _hx_bgp_selectivity_t* a	= (_hx_bgp_selectivity_t*) _a;
	const _hx_bgp_selectivity_t* b	= (_hx_bgp_selectivity_t*) _b;
	int64_t d	= (a->cost - b->cost);
	if (d < 0) {
		return -1;
	} else if (d > 0) {
		return 1;
	} else {
		return 0;
	}
}

int _hx_bgp_sort_for_triple_join ( hx_triple* l, hx_triple* r ) {
	int pos[3]			= { HX_SUBJECT, HX_PREDICATE, HX_OBJECT };
	hx_node* lnodes[3]	= { l->subject, l->predicate, l->object };
	hx_node* rnodes[3]	= { r->subject, r->predicate, r->object };
	for (int i = 0; i < 3; i++) {
		if (hx_node_is_variable( lnodes[i] )) {
			for (int j = 0; j < 3; j++) {
				if (hx_node_is_variable( rnodes[j] )) {
					if (hx_node_cmp(lnodes[i], rnodes[j]) == 0) {
// 						fprintf( stderr, "should sort on %d\n", pos[i] );
						return pos[i];
					}
				}
			}
		}
	}
	return HX_SUBJECT;
}

int _hx_bgp_sort_for_vb_join ( hx_triple* l, hx_variablebindings_iter* iter ) {
	int pos[3]			= { HX_SUBJECT, HX_PREDICATE, HX_OBJECT };
	hx_node* lnodes[3]	= { l->subject, l->predicate, l->object };
	int rsize			= hx_variablebindings_iter_size( iter );
	char** rnames		= hx_variablebindings_iter_names( iter );
	for (int j = 0; j < rsize; j++) {
		if (hx_variablebindings_iter_is_sorted_by_index(iter, j)) {
			for (int i = 0; i < 3; i++) {
				if (hx_node_is_variable( lnodes[i] )) {
					char* lname;
					hx_node_variable_name( lnodes[i], &lname );
					if (strcmp(lname, rnames[j]) == 0) {
						return pos[i];
					}
				}
			}
		}
	}
	
	
	for (int i = 0; i < 3; i++) {
		if (hx_node_is_variable( lnodes[i] )) {
			char* lname;
			hx_node_variable_name( lnodes[i], &lname );
			for (int j = 0; j < rsize; j++) {
				if (strcmp(lname, rnames[j]) == 0) {
//					fprintf( stderr, "should sort on %d (%s)\n", pos[i], lname );
					return pos[i];
				}
			}
		}
	}
	return HX_SUBJECT;
}
