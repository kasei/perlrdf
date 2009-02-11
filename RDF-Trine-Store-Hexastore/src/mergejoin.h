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
	int size;
	char** names;
	hx_variablebindings_iter* lhs;
	hx_variablebindings_iter* rhs;
	int lhs_index;
	int rhs_index;
	int finished;
	int started;
	
	int lhs_batch_size;
	int rhs_batch_size;
	hx_variablebindings** lhs_batch;
	hx_variablebindings** rhs_batch;
	hx_node_id lhs_key;
	hx_node_id rhs_key;
	int lhs_batch_alloc_size;
	int rhs_batch_alloc_size;
	int lhs_batch_index;
	int rhs_batch_index;
} _hx_mergejoin_iter_vb_info;

int _hx_mergejoin_iter_vb_finished ( void* iter );
int _hx_mergejoin_iter_vb_current ( void* iter, void* results );
int _hx_mergejoin_iter_vb_next ( void* iter );	
int _hx_mergejoin_iter_vb_free ( void* iter );
int _hx_mergejoin_iter_vb_size ( void* iter );
char** _hx_mergejoin_iter_vb_names ( void* iter );

hx_variablebindings_iter* hx_new_mergejoin_iter ( hx_variablebindings_iter* lhs, int lhs_index, hx_variablebindings_iter* rhs, int rhs_index );
hx_variablebindings* hx_mergejoin_join_variablebindings( hx_variablebindings* left, hx_variablebindings* right );







void hx_mergejoin_run ( void* data, hx_nodemap* map ); // XXX

#endif
