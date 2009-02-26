#include "storage.h"

hx_storage_manager* hx_new_memory_storage_manager( void ) {
	hx_storage_manager* s	= (hx_storage_manager*) calloc( 1, sizeof( hx_storage_manager ) );
	s->flags				= HX_STORAGE_MEMORY;
	return s;
}

hx_storage_manager* hx_new_file_storage_manager( const char* filename );
hx_storage_manager* hx_open_file_storage_manager( const char* filename );

int hx_free_storage_manager( hx_storage_manager* s ) {
	if (s->flags & HX_STORAGE_MEMORY) {
		free( s );
		return 0;
	} else {
		fprintf( stderr, "*** trying to free non-memory storage manager\n" );
		return 1;
	}
}

void* hx_storage_new_block( hx_storage_manager* s, size_t size ) {
	if (s->flags & HX_STORAGE_MEMORY) {
		return calloc( 1, size );
	} else {
		fprintf( stderr, "*** trying to create new block with non-memory storage manager\n" );
		return NULL;
	}
}

int hx_storage_release_block( hx_storage_manager* s, void* block ) {
	if (s->flags & HX_STORAGE_MEMORY) {
		free( block );
		return 0;
	} else {
		fprintf( stderr, "*** trying to free block with non-memory storage manager\n" );
		return 1;
	}
}

int hx_storage_sync_block( hx_storage_manager* s, void* block ) {
	if (s->flags & HX_STORAGE_MEMORY) {
		return 0;
	} else {
		fprintf( stderr, "*** trying to sync block with non-memory storage manager\n" );
		return 1;
	}
}

uint64_t hx_storage_id_from_block ( hx_storage_manager* s, void* block ) {
	if (s->flags & HX_STORAGE_MEMORY) {
		return (uint64_t) block;
	} else {
		fprintf( stderr, "*** trying to get block id with non-memory storage manager\n" );
		return 0;
	}
}

void* hx_storage_block_from_id ( hx_storage_manager* s, uint64_t id ) {
	if (s->flags & HX_STORAGE_MEMORY) {
		return (void*) id;
	} else {
		fprintf( stderr, "*** trying to get block pointer with non-memory storage manager\n" );
		return NULL;
	}
}
