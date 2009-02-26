#ifndef _STORAGE_H
#define _STORAGE_H

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

enum {
	HX_STORAGE_MEMORY	= 2,
	HX_STORAGE_FILE		= 4
};

typedef struct {
	int flags;
	int fd;
	char* filename;
} hx_storage_manager;

hx_storage_manager* hx_new_memory_storage_manager( void );
hx_storage_manager* hx_new_file_storage_manager( const char* filename );
hx_storage_manager* hx_open_file_storage_manager( const char* filename );

int hx_free_storage_manager( hx_storage_manager* s );

void* hx_storage_new_block( hx_storage_manager* s, size_t size );
int hx_storage_release_block( hx_storage_manager* s, void* block );
int hx_storage_sync_block( hx_storage_manager* s, void* block );

uint64_t hx_storage_id_from_block ( hx_storage_manager* s, void* block );
void* hx_storage_block_from_id ( hx_storage_manager* s, uint64_t id );

#endif
