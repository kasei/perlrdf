#ifndef _HEXASTORE_TYPES_H
#define _HEXASTORE_TYPES_H

#include <stdint.h>
#include <stdlib.h>
#include <sys/types.h>
#include <unistd.h>
#include "storage.h"

#define HEAD_TREE_BRANCHING_SIZE				252
#define VECTOR_TREE_BRANCHING_SIZE				28
#define TERMINAL_TREE_BRANCHING_SIZE			4

typedef int64_t hx_node_id;
typedef hx_node_id list_size_t;

#define HX_SUBJECT		0
#define HX_PREDICATE	1
#define HX_OBJECT		2

static char* HX_POSITION_NAMES[3]	= { "SUBJECT", "PREDICATE", "OBJECT" };

#endif
