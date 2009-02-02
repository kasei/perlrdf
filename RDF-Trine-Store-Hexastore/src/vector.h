#ifndef _VECTOR_H
#define _VECTOR_H

#include <errno.h>
#include <stdio.h>
#include <stdint.h>
#include <sys/mman.h>
#include <fcntl.h>
#include <stdlib.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <string.h>
#include <unistd.h>

#include "hexastore_types.h"
#include "terminal.h"

typedef struct {
	rdf_node node;
	hx_terminal* terminal;
} hx_vector_item;

typedef struct {
	list_size_t allocated;
	list_size_t used;
	hx_vector_item* ptr;
} hx_vector;

typedef struct {
	hx_vector* vector;
	size_t index;
	int started;
	int finished;
} hx_vector_iter;

hx_vector* hx_new_vector ( void );
int hx_free_vector ( hx_vector* list );

int hx_vector_debug ( const char* header, const hx_vector* v );
int hx_vector_add_terminal ( hx_vector* v, const rdf_node n, hx_terminal* t );
hx_terminal* hx_vector_get_terminal ( hx_vector* v, rdf_node n );
int hx_vector_remove_terminal ( hx_vector* v, rdf_node n );
int hx_vector_binary_search ( const hx_vector* v, const rdf_node n, int* index );
list_size_t hx_vector_size ( hx_vector* v );
uint64_t hx_vector_triples_count ( hx_vector* v );
size_t hx_vector_memory_size ( hx_vector* v );

hx_vector_iter* hx_vector_new_iter ( hx_vector* vector );
int hx_free_vector_iter ( hx_vector_iter* iter );
int hx_vector_iter_finished ( hx_vector_iter* iter );
int hx_vector_iter_current ( hx_vector_iter* iter, rdf_node* n, hx_terminal** t );
int hx_vector_iter_next ( hx_vector_iter* iter );
int hx_vector_iter_seek( hx_vector_iter* iter, rdf_node n );

#endif
