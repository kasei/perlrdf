#ifndef _NODE_H
#define _NODE_H

#include <errno.h>
#include <stdio.h>
#include <stdint.h>
#include <fcntl.h>
#include <stdlib.h>
#include <sys/types.h>
#include <string.h>
#include <unistd.h>

#include "hexastore_types.h"


// node type characters:
// ?	- Variable
//	R	- IRI resource
//	B	- Blank node
//	L	- Plain literal
//	G	- Language-tagged literal
//	D	- Datatyped literal

// other hexastore magic characters:
//	H - head
//	V - vector
//	X - hexastore
//	I - index
//	M - node map

typedef struct {
	char type;
	char* value;
	int number;
} hx_node;

typedef struct {
	char type;
	char* value;
	int number;
	char* lang;
} hx_node_lang_literal;

typedef struct {
	char type;
	char* value;
	int number;
	char* dt;
} hx_node_dt_literal;

hx_node* hx_new_node_variable ( int value );
hx_node* hx_new_node_resource ( char* value );
hx_node* hx_new_node_blank ( char* value );
hx_node* hx_new_node_literal ( char* value );
hx_node_lang_literal* hx_new_node_lang_literal ( char* value, char* lang );
hx_node_dt_literal* hx_new_node_dt_literal ( char* value, char* dt );
hx_node* hx_node_copy( hx_node* n );
int hx_free_node( hx_node* n );

size_t hx_node_alloc_size( hx_node* n );

int hx_node_is_variable ( hx_node* n );
int hx_node_is_literal ( hx_node* n );
int hx_node_is_lang_literal ( hx_node* n );
int hx_node_is_dt_literal ( hx_node* n );
int hx_node_is_resource ( hx_node* n );
int hx_node_is_blank ( hx_node* n );

char* hx_node_value ( hx_node* n );
int hx_node_number ( hx_node* n );
char* hx_node_lang ( hx_node_lang_literal* n );
char* hx_node_dt ( hx_node_dt_literal* n );
int hx_node_string ( hx_node* n, char** string );

int hx_node_nodestr( hx_node* n, char** str );
int hx_node_cmp( const void* a, const void* b );

int hx_node_write( hx_node* n, FILE* f );
hx_node* hx_node_read( FILE* f, int buffer );

#endif
