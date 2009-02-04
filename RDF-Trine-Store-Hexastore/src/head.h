#ifndef _HEAD_H
#define _HEAD_H

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

#include "avl.h"
#include "hexastore_types.h"
#include "vector.h"

typedef struct {
	rdf_node_id node;
	hx_vector* vector;
} hx_head_item;

typedef struct {
	struct avl_table* tree;
} hx_head;

typedef struct {
	hx_head* head;
	struct avl_traverser t;
} hx_head_iter;

hx_head* hx_new_head ( void );
int hx_free_head ( hx_head* head );

int hx_head_debug ( const char* header, hx_head* h );
// int hx_head_binary_search ( const hx_head* h, const rdf_node_id n, int* index );
int hx_head_add_vector ( hx_head* h, rdf_node_id n, hx_vector* v );
hx_vector* hx_head_get_vector ( hx_head* h, rdf_node_id n );
int hx_head_remove_vector ( hx_head* h, rdf_node_id n );
list_size_t hx_head_size ( hx_head* h );
uint64_t hx_head_triples_count ( hx_head* h );
size_t hx_head_memory_size ( hx_head* h );

int hx_head_write( hx_head* t, FILE* f );
hx_head* hx_head_read( FILE* f, int buffer );

hx_head_iter* hx_head_new_iter ( hx_head* head );
int hx_free_head_iter ( hx_head_iter* iter );
int hx_head_iter_finished ( hx_head_iter* iter );
int hx_head_iter_current ( hx_head_iter* iter, rdf_node_id* n, hx_vector** v );
int hx_head_iter_next ( hx_head_iter* iter );
int hx_head_iter_seek( hx_head_iter* iter, rdf_node_id n );

#endif
