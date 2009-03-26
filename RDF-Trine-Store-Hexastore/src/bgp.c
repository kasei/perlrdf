#include "bgp.h"

int _hx_bgp_selectivity_cmp ( const void* a, const void* b );

typedef struct {
	uint64_t cost;
	hx_triple* triple;
} _hx_bgp_selectivity_t;

hx_bgp* hx_new_bgp ( int size, hx_triple** triples ) {
	hx_bgp* b	= (hx_bgp*) calloc( 1, sizeof( hx_bgp ) );
	b->size		= size;
	b->triples	= (hx_triple**) calloc( size, sizeof( hx_triple* ) );
	for (int i = 0; i < size; i++) {
		b->triples[i]	= triples[i];
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
