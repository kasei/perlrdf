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
	hx_node_id node;
	hx_terminal* terminal;
} hx_vector_item;

typedef struct {
	uint64_t triples_count;
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
int hx_vector_add_terminal ( hx_vector* v, const hx_node_id n, hx_terminal* t );
hx_terminal* hx_vector_get_terminal ( hx_vector* v, hx_node_id n );
int hx_vector_remove_terminal ( hx_vector* v, hx_node_id n );
list_size_t hx_vector_size ( hx_vector* v );
uint64_t hx_vector_triples_count ( hx_vector* v );
void hx_vector_triples_count_add ( hx_vector* v, int c );
size_t hx_vector_memory_size ( hx_vector* v );

int hx_vector_write( hx_vector* t, FILE* f );
hx_vector* hx_vector_read( FILE* f, int buffer );

hx_vector_iter* hx_vector_new_iter ( hx_vector* vector );
int hx_free_vector_iter ( hx_vector_iter* iter );
int hx_vector_iter_finished ( hx_vector_iter* iter );
int hx_vector_iter_current ( hx_vector_iter* iter, hx_node_id* n, hx_terminal** t );
int hx_vector_iter_next ( hx_vector_iter* iter );
int hx_vector_iter_seek( hx_vector_iter* iter, hx_node_id n );

#endif
