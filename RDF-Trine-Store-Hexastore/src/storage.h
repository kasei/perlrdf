#ifndef _STORAGE_H
#define _STORAGE_H

#ifdef __cplusplus
extern "C" {
#endif

#include <errno.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>

#define HX_STORAGE_HEADER_SIZE	12
#define HX_STORAGE_BLOCK_HEADER_SIZE	sizeof(uint32_t)
#define HX_STORAGE_MMAP_NEXT_BLOCK(s)	*( (uint64_t*) (&(((uint8_t*) s->m)[4])) )
enum {
	HX_STORAGE_MEMORY	= 2,
	HX_STORAGE_FILE		= 4,
	HX_STORAGE_MMAP		= 8
};

typedef uint64_t hx_storage_id_t;
static hx_storage_id_t hx_storage_id_mask	= ~( (hx_storage_id_t) 0 );

typedef void hx_storage_handler ( void* s, void* arg );
typedef struct {
	int flags;
	int fd;
	int prot;
	void* m;	// mmap ptr
	off_t size;	// mmap file size
	const char* filename;
	hx_storage_handler* freeze_handler;
	void* freeze_arg;
	hx_storage_handler* thaw_handler;
	void* thaw_arg;
} hx_storage_manager;

hx_storage_manager* hx_new_memory_storage_manager( void );
hx_storage_manager* hx_new_mmap_storage_manager( const char* filename );
hx_storage_manager* hx_open_mmap_storage_manager( const char* filename, int prot );
hx_storage_manager* hx_new_file_storage_manager( const char* filename );
hx_storage_manager* hx_open_file_storage_manager( const char* filename );

int hx_free_storage_manager( hx_storage_manager* s );

int hx_storage_set_freeze_remap_handler ( hx_storage_manager* s, hx_storage_handler* h, void* arg );
int hx_storage_set_thaw_remap_handler ( hx_storage_manager* s, hx_storage_handler* h, void* arg );

void* hx_storage_new_block( hx_storage_manager* s, size_t size );
int hx_storage_release_block( hx_storage_manager* s, void* block );
int hx_storage_sync_block( hx_storage_manager* s, void* block );

hx_storage_id_t hx_storage_id_from_block ( hx_storage_manager* s, void* block );
void* hx_storage_block_from_id ( hx_storage_manager* s, hx_storage_id_t id );
void* hx_storage_first_block ( hx_storage_manager* s );

#ifdef __cplusplus
}
#endif

#endif
