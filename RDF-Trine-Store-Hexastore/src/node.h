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
	hx_node_id	id;
	char type;
	char* value;
} hx_node;

typedef struct {
	hx_node_id	id;
	char type;
	char* value;
	char* lang;
} hx_node_lang_literal;

typedef struct {
	hx_node_id	id;
	char type;
	char* value;
	char* dt;
} hx_node_dt_literal;

hx_node* hx_new_node_resource ( char* value );
hx_node* hx_new_node_blank ( char* value );
hx_node* hx_new_node_literal ( char* value );
hx_node_lang_literal* hx_new_node_lang_literal ( char* value, char* lang );
hx_node_dt_literal* hx_new_node_dt_literal ( char* value, char* dt );
int hx_free_node( hx_node* n );







#endif
