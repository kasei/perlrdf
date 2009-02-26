#include <unistd.h>
#include "storage.h"
#include "btree.h"
#include "tap.h"

void small_split_test ( void );
void medium_split_test ( void );
void large_split_test ( void );
void new_root_test ( void );
void large_test ( void );

int main ( void ) {
	plan_no_plan();
	small_split_test();
	medium_split_test();
	large_split_test();
	new_root_test();
	large_test();
	return exit_status();
}

void new_root_test ( void ) {
	diag( "new root test" );
	hx_storage_manager* w	= hx_new_memory_storage_manager();
	
	hx_btree_node* orig	= hx_new_btree_root( w );
	hx_btree_node* root	= orig;
	
	for (int i = 0; i < BRANCHING_SIZE; i++) {
		hx_node_id key	= (hx_node_id) i*2;
		uint64_t value	= (uint64_t) 100 + i;
		hx_btree_insert( w, &root, key, value );
	}
	
	ok1( orig == root ); // root hasn't split yet
	ok1( root->used == BRANCHING_SIZE );
	
	hx_btree_insert( w, &root, (hx_node_id) 7, (uint64_t) 777 );
	ok1( orig != root );
	ok1( root->used == 2 );
	
	int total	= 0;
//	hx_btree_node_debug( "root>\t", w, root );
	for (int i = 0; i < root->used; i++) {
		hx_btree_node* c	= hx_storage_block_from_id( w, root->children[i] );
		total	+= c->used;
//		hx_btree_node_debug( "child>\t", w, c );
	}
	ok1( total == BRANCHING_SIZE + 1 );
	hx_free_btree_node( w, root );
	hx_free_storage_manager( w );
}

void small_split_test ( void ) {
	diag( "small split test" );
	hx_storage_manager* w	= hx_new_memory_storage_manager();
	hx_btree_node* root	= hx_new_btree_node( w );
	hx_btree_node_set_flag( w, root, HX_BTREE_NODE_ROOT );
	
	hx_btree_node* child	= hx_new_btree_node( w );
	hx_btree_node_set_flag( w, child, HX_BTREE_NODE_LEAF );
	
	for (int i = 0; i < 10; i++) {
		hx_node_id key	= (hx_node_id) 7 + i;
		uint64_t value	= (uint64_t) 100 + i;
		hx_btree_node_add_child( w, child, key, value );
	}
	uint64_t cid	= hx_storage_id_from_block( w, child );
	hx_btree_node_add_child( w, root, (hx_node_id) 16, cid );
	
	ok1( root->used == 1 );
	
//	fprintf( stderr, "# *** BEFORE SPLIT:\n" );
//	hx_btree_node_debug( "# root>\t", w, root );
	for (int i = 0; i < root->used; i++) {
		hx_btree_node* c	= hx_storage_block_from_id( w, root->children[i] );
		ok1( c->used == 10 );
//		hx_btree_node_debug( "# child>\t", w, c );
	}
	
	_hx_btree_node_split_child( w, root, 0, child );
	
// 	fprintf( stderr, "# *** AFTER SPLIT:\n" );
// 	hx_btree_node_debug( "# root>\t", w, root );
	
	ok1( root->used == 2 );
	ok1( root->keys[0] == (hx_node_id) 11 );
	ok1( root->keys[1] == (hx_node_id) 16 );
	
	for (int i = 0; i < root->used; i++) {
		hx_btree_node* c	= hx_storage_block_from_id( w, root->children[i] );
		ok1( c->used == 5 );
// 		hx_btree_node_debug( "# child>\t", w, c );
	}
	
	hx_free_btree_node(w, root);
	hx_free_storage_manager( w );
}

void medium_split_test ( void ) {
	diag( "medium split test" );
	hx_storage_manager* w	= hx_new_memory_storage_manager();
	hx_btree_node* root	= hx_new_btree_node( w );
	hx_btree_node_set_flag( w, root, HX_BTREE_NODE_ROOT );
	
	hx_btree_node* child	= hx_new_btree_node( w );
	hx_btree_node_set_flag( w, child, HX_BTREE_NODE_LEAF );
	
	for (int i = 0; i < BRANCHING_SIZE-1; i++) {
		hx_node_id key	= (hx_node_id) i;
		uint64_t value	= (uint64_t) 100 + i;
		hx_btree_node_add_child( w, child, key, value );
	}
	uint64_t cid	= hx_storage_id_from_block( w, child );
	hx_btree_node_add_child( w, root, (hx_node_id) BRANCHING_SIZE-1, cid );
	
	ok1( root->used == 1 );
	
// 	fprintf( stderr, "# *** BEFORE SPLIT:\n" );
// 	hx_btree_node_debug( "# root>\t", w, root );
	
	{
		int counter	= 0;
		for (int i = 0; i < root->used; i++) {
			hx_btree_node* c	= hx_storage_block_from_id( w, root->children[i] );
			ok1( c->used == BRANCHING_SIZE-1 );
//			hx_btree_node_debug( "# child>\t", w, c );
			counter++;
		}
		ok1( counter == 1 );
	}
	
	
	_hx_btree_node_split_child( w, root, 0, child );
	
// 	fprintf( stderr, "# *** AFTER SPLIT:\n" );
// 	hx_btree_node_debug( "# root>\t", w, root );
	
	ok1( root->used == 2 );
	ok1( root->keys[0] == (hx_node_id) ((BRANCHING_SIZE-2)/2) );
	ok1( root->keys[1] == (hx_node_id) BRANCHING_SIZE-2 );
	
	{
		int total	= 0;
		int counter	= 0;
		for (int i = 0; i < root->used; i++) {
			hx_btree_node* c	= hx_storage_block_from_id( w, root->children[i] );
			total	+= c->used;
//			hx_btree_node_debug( "# child>\t", w, c );
			counter++;
		}
		ok1( counter == 2 );
		ok1( total == BRANCHING_SIZE-1 );
	}
	
	hx_free_btree_node(w, root);
	hx_free_storage_manager( w );
}

void large_split_test ( void ) {
	diag( "large split test" );
	hx_storage_manager* w	= hx_new_memory_storage_manager();
	hx_btree_node* root	= hx_new_btree_node( w );
	hx_btree_node_set_flag( w, root, HX_BTREE_NODE_ROOT );
	
	hx_btree_node* child	= hx_new_btree_node( w );
	hx_btree_node_set_flag( w, child, HX_BTREE_NODE_LEAF );
	
	for (int i = 0; i < BRANCHING_SIZE; i++) {
		hx_node_id key	= (hx_node_id) i;
		uint64_t value	= (uint64_t) 100 + i;
		hx_btree_node_add_child( w, child, key, value );
	}
	uint64_t cid	= hx_storage_id_from_block( w, child );
	hx_btree_node_add_child( w, root, (hx_node_id) BRANCHING_SIZE, cid );
	
	ok1( root->used == 1 );
	
// 	fprintf( stderr, "# *** BEFORE SPLIT:\n" );
// 	hx_btree_node_debug( "# root>\t", w, root );
	
	{
		int counter	= 0;
		for (int i = 0; i < root->used; i++) {
			hx_btree_node* c	= hx_storage_block_from_id( w, root->children[i] );
			ok1( c->used == BRANCHING_SIZE );
// 			hx_btree_node_debug( "# child>\t", w, c );
			counter++;
		}
		ok1( counter == 1 );
	}
	
	
	_hx_btree_node_split_child( w, root, 0, child );
	
// 	fprintf( stderr, "# *** AFTER SPLIT:\n" );
// 	hx_btree_node_debug( "# root>\t", w, root );
	
	ok1( root->used == 2 );
	ok1( root->keys[0] == (hx_node_id) (BRANCHING_SIZE/2)-1 );
	ok1( root->keys[1] == (hx_node_id) BRANCHING_SIZE-1 );
	
	{
		int counter	= 0;
		for (int i = 0; i < root->used; i++) {
			hx_btree_node* c	= hx_storage_block_from_id( w, root->children[i] );
			ok1( c->used == (BRANCHING_SIZE/2) );
// 			hx_btree_node_debug( "# child>\t", w, c );
			counter++;
		}
		ok1( counter == 2 );
	}
	
	hx_free_btree_node(w, root);
	hx_free_storage_manager( w );
}

void large_test ( void ) {
	diag( "large test" );
	hx_storage_manager* w	= hx_new_memory_storage_manager();
//	printf( "%d\n", (int) sizeof( hx_btree_node ) );
	hx_btree_node* root	= hx_new_btree_node( w );
	hx_btree_node_set_flag( w, root, HX_BTREE_NODE_ROOT );
	hx_btree_node_set_flag( w, root, HX_BTREE_NODE_LEAF );
//	printf( "root: %d (%p)\n", (int) _hx_btree_node2int(w, root), (void*) root );
	
	for (int i = 1; i <= 4000000; i++) {
		hx_btree_insert( w, &root, (hx_node_id) i, (uint64_t) 10*i );
	}
	
	list_size_t size	= hx_btree_size( w, root );
	ok1( 4000000 == size );
	ok1( 15876 == hx_btree_size( w, hx_storage_block_from_id( w, root->children[0] ) ) );
	
	int counter	= 0;
	hx_node_id key, last;
	uint64_t value3;
	hx_btree_iter* iter	= hx_btree_new_iter( w, root );
	while (!hx_btree_iter_finished(iter)) {
		hx_btree_iter_current( iter, &key, &value3 );
		if (counter > 0) {
//			fprintf( stderr, "# cur=%d last=%d\n", (int) key, (int) last );
			if (counter % 2081 == 0) {	// pare down the number of test results we emit
				ok1( key == last + 1 );
			}
		}
//		fprintf( stderr, "iter -> %d => %d\n", (int) key, (int) value3 );
		hx_btree_iter_next(iter);
		last	= key;
		counter++;
	}
//	fprintf( stderr, "# Total records: %d\n", counter );
	ok1( counter == 4000000 );
	
	hx_free_btree_iter( iter );
	hx_free_btree_node(w, root);
	hx_free_storage_manager( w );
}






// 	for (int i = 1; i < 20; i++) {
// 		hx_btree_node_add_child( w, root, (hx_node_id) i, (uint64_t) i*2 );
// 	}
// //	hx_btree_node_debug( w, root );
// 	
// 	for (int i = 1; i < 20; i+=2) {
// 		hx_btree_node_remove_child( w, root, (hx_node_id) i );
// 	}
// //	hx_btree_node_debug( w, root );
// 	
// 	uint64_t value	= hx_btree_search( w, root, (hx_node_id) 8 );
// //	fprintf( stderr, "key(8) value: %d\n", (int) value );
// 	
// //	for (int i = 4000000; i > 0; i--) {
// //	printf( "root after bulk-load: %d (%p)\n", (int) _hx_btree_node2int(w, root), (void*) root );
// 	
// 	uint64_t value2	= hx_btree_search( w, root, (hx_node_id) 1818 );
// //	fprintf( stderr, "-> %d\n", (int) value2 );
// 	
// //	fprintf( stderr, "***************************\n" );
// //	hx_btree_traverse( w, root, _hx_btree_debug_leaves, NULL, 0 );
// //	fprintf( stderr, "***************************\n" );
