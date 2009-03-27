#include "node.h"

int _hx_node_parse_datatypes ( hx_node* n );

hx_node* _hx_new_node ( char type, char* value, int padding, int flags, int iv, double nv ) {
	hx_node* n	= (hx_node*) calloc( 1, sizeof( hx_node ) + padding );
	n->type		= type;
	n->flags	= flags;
	if (flags & HX_NODE_IOK) {
		n->iv		= iv;
	}
	
	if (flags & HX_NODE_NOK) {
		n->nv		= nv;
	}
	
	if (value != NULL) {
		n->value	= malloc( strlen( value ) + 1 );
		strcpy( n->value, value );
	}
	return n;
}

hx_node* hx_new_node_variable ( int value ) {
	hx_node* n	= _hx_new_node( '?', NULL, 0, HX_NODE_IOK, value, 0.0 );
	return n;
}

hx_node* hx_new_node_named_variable( int value, char* name ) {
	hx_node* n	= _hx_new_node( '?', name, 0, HX_NODE_IOK, value, 0.0 );
	return n;
}

hx_node* hx_new_node_resource ( char* value ) {
	hx_node* n	= _hx_new_node( 'R', value, 0, HX_NODE_NONE, 0, 0.0 );
	return n;
}

hx_node* hx_new_node_blank ( char* value ) {
	hx_node* n	= _hx_new_node( 'B', value, 0, HX_NODE_NONE, 0, 0.0 );
	return n;
}

hx_node* hx_new_node_literal ( char* value ) {
	hx_node* n	= _hx_new_node( 'L', value, 0, HX_NODE_NONE, 0, 0.0 );
	_hx_node_parse_datatypes( n );
	return n;
}

hx_node_lang_literal* hx_new_node_lang_literal ( char* value, char* lang ) {
	int padding	= sizeof( hx_node_lang_literal ) - sizeof( hx_node );
	hx_node_lang_literal* n	= (hx_node_lang_literal*) _hx_new_node( 'G', value, padding, HX_NODE_NONE, 0, 0.0 );
	n->lang		= malloc( strlen( lang ) + 1 );
	if (n->lang == NULL) {
		free( n->value );
		free( n );
		return NULL;
	}
	strcpy( n->lang, lang );
	_hx_node_parse_datatypes( (hx_node*) n );
	return n;
}

hx_node_dt_literal* hx_new_node_dt_literal ( char* value, char* dt ) {
	int padding	= sizeof( hx_node_dt_literal ) - sizeof( hx_node );
	hx_node_dt_literal* n	= (hx_node_dt_literal*) _hx_new_node( 'D', value, padding, HX_NODE_NONE, 0, 0.0 );
	n->dt		= malloc( strlen( dt ) + 1 );
	if (n->dt == NULL) {
		free( n->value );
		free( n );
		return NULL;
	}
	strcpy( n->dt, dt );
	_hx_node_parse_datatypes( (hx_node*) n );
	return n;
}

hx_node* hx_node_copy( hx_node* n ) {
	if (hx_node_is_literal( n )) {
		if (hx_node_is_lang_literal( n )) {
			hx_node_lang_literal* d	= (hx_node_lang_literal*) n;
			int padding	= sizeof( hx_node_lang_literal ) - sizeof( hx_node );
			hx_node_lang_literal* copy	= (hx_node_lang_literal*) _hx_new_node( 'G', d->value, padding, HX_NODE_NONE, 0, 0.0 );
			copy->lang		= malloc( strlen( d->lang ) + 1 );
			copy->flags		= d->flags;
			copy->iv		= d->iv;
			copy->nv		= d->nv;
			strcpy( copy->lang, d->lang );
			_hx_node_parse_datatypes( (hx_node*) copy );
			return (hx_node*) copy;
		} else if (hx_node_is_dt_literal( n )) {
			hx_node_dt_literal* d	= (hx_node_dt_literal*) n;
			int padding	= sizeof( hx_node_dt_literal ) - sizeof( hx_node );
			hx_node_dt_literal* copy	= (hx_node_dt_literal*) _hx_new_node( 'D', d->value, padding, HX_NODE_NONE, 0, 0.0 );
			copy->dt		= malloc( strlen( d->dt ) + 1 );
			copy->flags		= d->flags;
			copy->iv		= d->iv;
			copy->nv		= d->nv;
			strcpy( copy->dt, d->dt );
			_hx_node_parse_datatypes( (hx_node*) copy );
			return (hx_node*) copy;
		} else {
			hx_node* copy	= hx_new_node_literal( n->value );
			return copy;
		}
	} else if (hx_node_is_resource( n )) {
		hx_node* copy	= hx_new_node_resource( n->value );
		return copy;
	} else if (hx_node_is_blank( n )) {
		hx_node* copy	= hx_new_node_blank( n->value );
		return copy;
	}
	return NULL;
}

int hx_free_node( hx_node* n ) {
	if (n->type == 'G') {
		hx_node_lang_literal* l	= (hx_node_lang_literal*) n;
		free( l->lang );
	} else if (n->type == 'D') {
		hx_node_dt_literal* d	= (hx_node_dt_literal*) n;
		free( d->dt );
	}
	if (n->type != '?') {
		free( n->value );
	}
	free( n );
	return 0;
}

size_t hx_node_alloc_size( hx_node* n ) {
	if (hx_node_is_literal( n )) {
		if (hx_node_is_lang_literal( n )) {
			return sizeof( hx_node_lang_literal );
		} else if (hx_node_is_dt_literal( n )) {
			return sizeof( hx_node_dt_literal );
		} else {
			return sizeof( hx_node );
		}
	} else if (hx_node_is_resource( n )) {
		return sizeof( hx_node );
	} else if (hx_node_is_blank( n )) {
		return sizeof( hx_node );
	} else {
		fprintf( stderr, "*** Unrecognized node type '%c' in hx_node_alloc_size\n", n->type );
		return 0;
	}
}

int hx_node_is_variable ( hx_node* n ) {
	return (n->type == '?');
}

int hx_node_is_literal ( hx_node* n ) {
	return (n->type == 'L' || n->type == 'G' || n->type == 'D');
}

int hx_node_is_lang_literal ( hx_node* n ) {
	return (n->type == 'G');
}

int hx_node_is_dt_literal ( hx_node* n ) {
	return (n->type == 'D');
}

int hx_node_is_resource ( hx_node* n ) {
	return (n->type == 'R');
}

int hx_node_is_blank ( hx_node* n ) {
	return (n->type == 'B');
}

char* hx_node_value ( hx_node* n ) {
	return n->value;
}

int hx_node_variable_name ( hx_node* n, char** name ) {
	if (n->type == '?') {
		if (n->value == NULL) {
			int alloc	= 10 + 6;
			*name	= calloc( 1, alloc );
			if (*name == NULL) {
				return 0;
			}
			sprintf( *name, "__var%d", n->iv );
		} else {
			*name	= malloc( strlen( n->value ) + 1 );
			strcpy( *name, n->value );
		}
	} else {
		*name	= NULL;
	}
	return 0;
}

int hx_node_ivok( hx_node* n ) {
	return (n->flags & HX_NODE_IOK) ? 1 : 0;
}

int hx_node_nvok( hx_node* n ) {
	return (n->flags & HX_NODE_NOK) ? 1 : 0;
}

int hx_node_iv ( hx_node* n ) {
	return n->iv;
}

double hx_node_nv ( hx_node* n ) {
	return n->nv;
}

char* hx_node_lang ( hx_node_lang_literal* n ) {
	return n->lang;
}

char* hx_node_dt ( hx_node_dt_literal* n ) {
	return n->dt;
}

int hx_node_string ( hx_node* n, char** str ) {
	int alloc	= 0;
	if (hx_node_is_literal( n )) {
		alloc	= strlen(n->value) + 3;
		if (hx_node_is_lang_literal( n )) {
			hx_node_lang_literal* l	= (hx_node_lang_literal*) n;
			alloc	+= 1 + strlen( l->lang );
		} else if (hx_node_is_dt_literal( n )) {
			hx_node_dt_literal* d	= (hx_node_dt_literal*) n;
			alloc	+= 4 + strlen( d->dt );
		}
		*str	= calloc( 1, alloc );
		if (*str == NULL) {
			return 0;
		}
		
		if (hx_node_is_lang_literal( n )) {
			hx_node_lang_literal* l	= (hx_node_lang_literal*) n;
			sprintf( *str, "\"%s\"@%s", l->value, l->lang );
		} else if (hx_node_is_dt_literal( n )) {
			hx_node_dt_literal* d	= (hx_node_dt_literal*) n;
			sprintf( *str, "\"%s\"^^<%s>", d->value, d->dt );
		} else {
			sprintf( *str, "\"%s\"", n->value );
		}
	} else if (hx_node_is_resource( n )) {
		alloc	= strlen(n->value) + 3;
		*str	= calloc( 1, alloc );
		if (*str == NULL) {
			return 0;
		}
		sprintf( *str, "<%s>", n->value );
	} else if (hx_node_is_blank( n )) {
		alloc	= strlen(n->value) + 3;
		*str	= calloc( 1, alloc );
		if (*str == NULL) {
			return 0;
		}
		sprintf( *str, "_:%s", n->value );
	} else if (hx_node_is_variable( n )) {
		alloc	= 10 + 6;
		*str	= calloc( 1, alloc );
		if (*str == NULL) {
			return 0;
		}
		sprintf( *str, "?__var%d", n->iv );
	} else {
		fprintf( stderr, "*** Unrecognized node type '%c'\n", n->type );
		return 0;
	}
	return alloc;
}

int hx_node_nodestr( hx_node* n, char** str ) {
	int alloc	= 0;
	if (hx_node_is_literal( n )) {
		alloc	= strlen(n->value) + 4;
		char* lang	= NULL;
		char* dt	= NULL;
		if (hx_node_is_lang_literal( n )) {
			hx_node_lang_literal* l	= (hx_node_lang_literal*) n;
			lang	= hx_node_lang( l );
			alloc	+= strlen( l->lang );
		} else if (hx_node_is_dt_literal( n )) {
			hx_node_dt_literal* d	= (hx_node_dt_literal*) n;
			dt	= hx_node_dt( d );
			alloc	+= strlen( d->dt );
		}
		*str	= calloc( 1, alloc );
		if (*str == NULL) {
			return 0;
		}
		sprintf( *str, "L%s<%s>%s", n->value, lang, dt );
	} else if (hx_node_is_resource( n )) {
		alloc	= strlen(n->value) + 2;
		*str	= calloc( 1, alloc );
		if (*str == NULL) {
			return 0;
		}
		sprintf( *str, "R%s", n->value );
	} else if (hx_node_is_blank( n )) {
		alloc	= strlen(n->value) + 2;
		*str	= calloc( 1, alloc );
		if (*str == NULL) {
			return 0;
		}
		sprintf( *str, "B%s", n->value );
	} else {
		fprintf( stderr, "*** Unrecognized node type '%c'\n", n->type );
		return 0;
	}
	return alloc;
}

int hx_node_cmp( const void* _a, const void* _b ) {
	hx_node* a	= (hx_node*) _a;
	hx_node* b	= (hx_node*) _b;
	
	if (a->type == b->type) {
		if (hx_node_is_blank( a )) {
			return strcmp( a->value, b->value );
		} else if (hx_node_is_resource( a )) {
			return strcmp( a->value, b->value );
		} else if (hx_node_is_literal( a )) {
			// XXX need to deal with language and datatype literals
			return strcmp( a->value, b->value );
		} else if (hx_node_is_variable( a )) {
			return (hx_node_iv( a ) - hx_node_iv( b ));
		} else {
			fprintf( stderr, "*** Unknown node type %c in _sparql_sort_cmp\n", a->type );
			return 0;
		}
	} else {
		if (hx_node_is_blank( a ))
			return -1;
		if (hx_node_is_literal( a ))
			return 1;
		if (hx_node_is_blank( b ))
			return 1;
		if (hx_node_is_literal( b ))
			return -1;
	}
	return 0;
}

int hx_node_write( hx_node* n, FILE* f ) {
	if (n->type == '?') {
//		fprintf( stderr, "*** Cannot write variable nodes to a file.\n" );
		return 1;
	}
	fputc( 'N', f );
	fputc( n->type, f );
	size_t len	= (size_t) strlen( n->value );
	fwrite( &len, sizeof( size_t ), 1, f );
	fwrite( n->value, 1, strlen( n->value ), f );
	if (hx_node_is_literal( n )) {
		if (hx_node_is_lang_literal( n )) {
			hx_node_lang_literal* l	= (hx_node_lang_literal*) n;
			size_t len	= strlen( l->lang );
			fwrite( &len, sizeof( size_t ), 1, f );
			fwrite( l->lang, 1, strlen( l->lang ), f );
		}
		if (hx_node_is_dt_literal( n )) {
			hx_node_dt_literal* d	= (hx_node_dt_literal*) n;
			size_t len	= strlen( d->dt );
			fwrite( &len, sizeof( size_t ), 1, f );
			fwrite( d->dt, 1, strlen( d->dt ), f );
		}
	}
	return 0;
}

hx_node* hx_node_read( FILE* f, int buffer ) {
	size_t used, read;
	int c	= fgetc( f );
	if (c != 'N') {
		fprintf( stderr, "*** Bad header cookie ('%c') trying to read node from file.\n", c );
		return NULL;
	}
	
	char* value;
	char* extra	= NULL;
	hx_node* node;
	c	= fgetc( f );
	switch (c) {
		case 'R':
			read	= fread( &used, sizeof( size_t ), 1, f );
			value	= (char*) calloc( 1, used + 1 );
			read	= fread( value, 1, used, f );
			node	= hx_new_node_resource( value );
			free( value );
			return node;
		case 'B':
			read	= fread( &used, sizeof( size_t ), 1, f );
			value	= (char*) calloc( 1, used + 1 );
			read	= fread( value, 1, used, f );
			node	= hx_new_node_blank( value );
			free( value );
			return node;
		case 'L':
		case 'G':
		case 'D':
			read	= fread( &used, sizeof( size_t ), 1, f );
			value	= (char*) calloc( 1, used + 1 );
			read	= fread( value, 1, used, f );
			if (c == 'G' || c == 'D') {
				read	= fread( &used, sizeof( size_t ), 1, f );
				extra	= (char*) calloc( 1, used + 1 );
				read	= fread( extra, 1, used, f );
			}
			if (c == 'G') {
				node	= (hx_node*) hx_new_node_lang_literal( value, extra );
			} else if (c == 'D') {
				node	= (hx_node*) hx_new_node_dt_literal( value, extra );
			} else {
				node	= hx_new_node_literal( value );
			}
			free( value );
			if (extra != NULL)
				free( extra );
			return node;
		default:
			fprintf( stderr, "*** Bad node type '%c' trying to read node from file.\n", (char) c );
			return NULL;
	};
	
}

int _hx_node_parse_datatypes ( hx_node* n ) {
	if (!hx_node_is_dt_literal(n)) {
		return 1;
	}
	
	char* dt	= hx_node_dt( (hx_node_dt_literal*) n );
	if (strcmp( dt, "http://www.w3.org/2001/XMLSchema#integer" ) == 0) {
		char* value	= hx_node_value( n );
		int iv		= atoi( value );
		n->iv		= iv;
		n->flags	|= HX_NODE_IOK;
	} else if (strcmp( dt, "http://www.w3.org/2001/XMLSchema#float" ) == 0) {
		char* ptr;
		char* value	= hx_node_value( n );
		double nv	= strtod( value, &ptr );
		int diff	= ptr - value;
		n->nv		= nv;
		n->flags	|= HX_NODE_NOK;
	}
	
	return 0;
}


//	R	- IRI resource
//	B	- Blank node
//	L	- Plain literal
//	G	- Language-tagged literal
//	D	- Datatyped literal
