#ifndef _MATERIALIZE_H
#define _MATERIALIZE_H

#define NODE_LIST_ALLOC_SIZE	10

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
#include <pthread.h>

#include "hexastore_types.h"
#include "variablebindings.h"

typedef struct {
	hx_variablebindings** bindings;
	int size;
	int length;
	char** names;
	int started;
	int finished;
	int index;
	int sorted_by;
	hx_variablebindings_iter* iter;
} _hx_materialize_iter_vb_info;

typedef struct {
	short index;
	hx_variablebindings* binding;
} _hx_materialize_bindings_sort_info;

int _hx_materialize_iter_vb_finished ( void* iter );
int _hx_materialize_iter_vb_current ( void* iter, void* results );
int _hx_materialize_iter_vb_next ( void* iter );	
int _hx_materialize_iter_vb_free ( void* iter );
int _hx_materialize_iter_vb_size ( void* iter );
char** _hx_materialize_iter_vb_names ( void* iter );

int _hx_materialize_cmp_bindings ( const void* _a, const void* _b );
int _hx_materialize_cmp_bindings_column ( const void* _a, const void* _b );

hx_variablebindings_iter* hx_new_materialize_iter ( hx_variablebindings_iter* iter );
int hx_materialize_sort_iter_by_column ( hx_variablebindings_iter* iter, int index );
int hx_materialize_sort_iter ( hx_variablebindings_iter* iter );

void hx_materialize_iter_debug ( hx_variablebindings_iter* iter );

#endif
