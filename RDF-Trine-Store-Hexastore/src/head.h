#ifndef _HEAD_H
#define _HEAD_H

#ifdef __cplusplus
extern "C" {
#endif

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

#include "btree.h"
#include "hexastore_types.h"
#include "vector.h"
#include "storage.h"

typedef struct {
	hx_storage_id_t triples_count;
	hx_storage_id_t tree;
} hx_head;

typedef struct {
	hx_storage_manager* storage;
	hx_head* head;
	hx_btree_iter* t;
} hx_head_iter;

hx_head* hx_new_head ( hx_storage_manager* s );
int hx_free_head ( hx_head* head, hx_storage_manager* s );

int hx_head_debug ( const char* header, hx_head* h, hx_storage_manager* s );
int hx_head_add_vector ( hx_head* h, hx_storage_manager* s, hx_node_id n, hx_vector* v );
hx_vector* hx_head_get_vector ( hx_head* h, hx_storage_manager* s, hx_node_id n );
int hx_head_remove_vector ( hx_head* h, hx_storage_manager* s, hx_node_id n );
list_size_t hx_head_size ( hx_head* h, hx_storage_manager* s );
hx_storage_id_t hx_head_triples_count ( hx_head* h, hx_storage_manager* s );
void hx_head_triples_count_add ( hx_head* h, hx_storage_manager* s, int c );

int hx_head_write( hx_head* t, hx_storage_manager* s, FILE* f );
hx_head* hx_head_read( hx_storage_manager* s, FILE* f, int buffer );

hx_head_iter* hx_head_new_iter ( hx_head* head, hx_storage_manager* s );
int hx_free_head_iter ( hx_head_iter* iter );
int hx_head_iter_finished ( hx_head_iter* iter );
int hx_head_iter_current ( hx_head_iter* iter, hx_node_id* n, hx_vector** v );
int hx_head_iter_next ( hx_head_iter* iter );
int hx_head_iter_seek( hx_head_iter* iter, hx_node_id n );

#ifdef __cplusplus
}
#endif

#endif
