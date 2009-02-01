#include <stdio.h>
#include "avl.h"



int cmp ( const void* a, const void* b, void* param ) {
	return ((int) a - (int) b);
}

// void item_function (void *avl_item, void *avl_param);
// void *copy_func (void *avl_item, void *avl_param);


int main (void) {
	struct avl_table* t	= avl_create( cmp, NULL, &avl_allocator_default );
	fprintf( stderr, "avl tree: %p\n", (void*) t );
	
	for (int i = 5; i < 10; i++) {
		fprintf( stderr, "inserting %d\n", i );
		avl_insert( t, (void*) i );
	}
	for (int i = 20; i > 12; i--) {
		fprintf( stderr, "inserting %d\n", i );
		avl_insert( t, (void*) i );
	}
	
	fprintf( stderr, "tree size: %d\n", (int) avl_count( t ) );
	
	struct avl_traverser iter;
	avl_t_init( &iter, t );
	void* item;
	
	while ((item = avl_t_next( &iter )) != NULL) {
		int c	= (int) item;
		fprintf( stderr, "-> %d\n", c );
	}
	
	avl_destroy( t, NULL );
	return 0;
}
