#ifndef _TERMINAL_H
#define _TERMINAL_H

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

#include "hexastore_types.h"
#include "btree.h"
#include "storage.h"

typedef struct {
	hx_storage_id_t triples_count;
	hx_storage_id_t tree;
	int refcount;
} hx_terminal;

typedef struct {
	hx_storage_manager* storage;
	hx_terminal* terminal;
	hx_btree_iter* t;
} hx_terminal_iter;

hx_terminal* hx_new_terminal ( hx_storage_manager* s );
int hx_free_terminal ( hx_terminal* list, hx_storage_manager* st );

int hx_terminal_inc_refcount ( hx_terminal* t, hx_storage_manager* st );
int hx_terminal_dec_refcount ( hx_terminal* t, hx_storage_manager* st );

int hx_terminal_debug ( const char* header, hx_terminal* t, hx_storage_manager* st, int newline );
int hx_terminal_add_node ( hx_terminal* t, hx_storage_manager* st, hx_node_id n );
int hx_terminal_contains_node ( hx_terminal* t, hx_storage_manager* st, hx_node_id n );
int hx_terminal_remove_node ( hx_terminal* t, hx_storage_manager* st, hx_node_id n );
list_size_t hx_terminal_size ( hx_terminal* t, hx_storage_manager* st );

int hx_terminal_write( hx_terminal* t, hx_storage_manager* st, FILE* f );
hx_terminal* hx_terminal_read( hx_storage_manager* s, FILE* f, int buffer );

hx_terminal_iter* hx_terminal_new_iter ( hx_terminal* terminal, hx_storage_manager* st );
int hx_free_terminal_iter ( hx_terminal_iter* iter );
int hx_terminal_iter_finished ( hx_terminal_iter* iter );
int hx_terminal_iter_current ( hx_terminal_iter* iter, hx_node_id* n );
int hx_terminal_iter_next ( hx_terminal_iter* iter );
int hx_terminal_iter_seek( hx_terminal_iter* iter, hx_node_id n );

#ifdef __cplusplus
}
#endif

#endif
