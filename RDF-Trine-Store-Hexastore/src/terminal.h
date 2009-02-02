#ifndef _TERMINAL_H
#define _TERMINAL_H

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

typedef struct {
	list_size_t allocated;
	list_size_t used;
	rdf_node* ptr;
	int refcount;
} hx_terminal;

typedef struct {
	hx_terminal* terminal;
	size_t index;
	int started;
	int finished;
} hx_terminal_iter;

hx_terminal* hx_new_terminal ( void );
int hx_free_terminal ( hx_terminal* list );

int hx_terminal_debug ( const char* header, hx_terminal* t, int newline );
int hx_terminal_add_node ( hx_terminal* t, rdf_node n );
int hx_terminal_contains_node ( hx_terminal* t, rdf_node n );
int hx_terminal_remove_node ( hx_terminal* t, rdf_node n );
int hx_terminal_binary_search ( const hx_terminal* t, const rdf_node n, int* index );
list_size_t hx_terminal_size ( hx_terminal* t );
size_t hx_terminal_memory_size ( hx_terminal* t );

hx_terminal_iter* hx_terminal_new_iter ( hx_terminal* terminal );
int hx_free_terminal_iter ( hx_terminal_iter* iter );
int hx_terminal_iter_finished ( hx_terminal_iter* iter );
int hx_terminal_iter_current ( hx_terminal_iter* iter, rdf_node* n );
int hx_terminal_iter_next ( hx_terminal_iter* iter );
int hx_terminal_iter_seek( hx_terminal_iter* iter, rdf_node n );

#endif
