#ifndef _HEXASTORE_TYPES_H
#define _HEXASTORE_TYPES_H

#include <stdint.h>
#include <stdlib.h>
#include <sys/types.h>
#include <unistd.h>

#define HEAD_LIST_ALLOC_SIZE				4096
#define VECTOR_LIST_ALLOC_SIZE				64
#define TERMINAL_LIST_ALLOC_SIZE			32

typedef uint64_t list_size_t;
typedef uint64_t rdf_node;

#endif
