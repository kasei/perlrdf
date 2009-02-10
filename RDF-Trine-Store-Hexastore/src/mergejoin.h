#ifndef _MERGEJOIN_H
#define _MERGEJOIN_H

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
	hx_variablebindings_iter* lhs;
	hx_variablebindings_iter* rhs;
	int size;
	char** names;
	int lhs_index;
	int rhs_index;
	int current_batch_join_index;
	hx_node_id batch_id;
	int batch_size;
	int batch_alloc_size;
	hx_variablebindings** batch;
	int finished;
	int started;
} _hx_mergejoin_iter_vb_info;

int _hx_mergejoin_iter_vb_finished ( void* iter );
int _hx_mergejoin_iter_vb_current ( void* iter, void* results );
int _hx_mergejoin_iter_vb_next ( void* iter );	
int _hx_mergejoin_iter_vb_free ( void* iter );
int _hx_mergejoin_iter_vb_columns ( void* iter );
char** _hx_mergejoin_iter_vb_names ( void* iter );

hx_variablebindings_iter* hx_new_mergejoin_iter ( hx_variablebindings_iter* lhs, int lhs_index, hx_variablebindings_iter* rhs, int rhs_index );

#endif
