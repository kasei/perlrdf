#include <unistd.h>
#include "storage.h"
#include "btree.h"
#include "tap.h"

static uint32_t branching_size	= 126;

void _add_data ( hx_storage_manager* s, hx_btree* tree, int count, int add );
extern int _hx_btree_node_split_child( hx_storage_manager* w, hx_btree_node* parent, uint32_t index, hx_btree_node* child, uint32_t branching_size );

void small_split_test ( void );
void medium_split_test ( void );
void large_split_test ( void );
void new_root_test ( void );
void large_test ( void );
void small_remove_test ( void );
void medium_remove_test ( void );
void large_remove_test ( void );

int main ( void ) {
	plan_no_plan();
	
	small_split_test();
	medium_split_test();
	large_split_test();
	new_root_test();
	large_test();
	small_remove_test();
	medium_remove_test();
	large_remove_test();
	
	return exit_status();
}

void new_root_test ( void ) {
	hx_storage_manager* w	= hx_new_memory_storage_manager();
	
	hx_btree_node* orig	= hx_new_btree_root( w, branching_size );
	hx_btree_node* root	= orig;
	
	for (int i = 0; i < branching_size; i++) {
		hx_node_id key	= (hx_node_id) i*2;
		hx_storage_id_t value	= (hx_storage_id_t) 100 + i;
		hx_btree_node_insert( w, &root, key, value, branching_size );
	}
	
	ok1( orig == root ); // root hasn't split yet
	ok1( root->used == branching_size );
	
	hx_btree_node_insert( w, &root, (hx_node_id) 7, (hx_storage_id_t) 777, branching_size );
	ok1( orig != root );
	ok1( root->used == 2 );
	
	int total	= 0;
//	hx_btree_node_debug( "root>\t", w, root );
	for (int i = 0; i < root->used; i++) {
		hx_btree_node* c	= hx_storage_block_from_id( w, root->ptr[i].child );
		total	+= c->used;
//		hx_btree_node_debug( "child>\t", w, c );
	}
	ok1( total == branching_size + 1 );
	hx_free_btree_node( w, root );
	hx_free_storage_manager( w );
}

void small_split_test ( void ) {
	hx_storage_manager* w	= hx_new_memory_storage_manager();
	hx_btree_node* root	= hx_new_btree_node( w, branching_size );
	hx_btree_node_set_flag( w, root, HX_BTREE_NODE_ROOT );
	
	hx_btree_node* child	= hx_new_btree_node( w, branching_size );
	hx_btree_node_set_flag( w, child, HX_BTREE_NODE_LEAF );
	
	for (int i = 0; i < 10; i++) {
		hx_node_id key	= (hx_node_id) 7 + i;
		hx_storage_id_t value	= (hx_storage_id_t) 100 + i;
		hx_btree_node_add_child( w, child, key, value, branching_size );
	}
	hx_storage_id_t cid	= hx_storage_id_from_block( w, child );
	hx_btree_node_add_child( w, root, (hx_node_id) 16, cid, branching_size );
	
	ok1( root->used == 1 );
	
//	fprintf( stderr, "# *** BEFORE SPLIT:\n" );
//	hx_btree_node_debug( "# root>\t", w, root );
	for (int i = 0; i < root->used; i++) {
		hx_btree_node* c	= hx_storage_block_from_id( w, root->ptr[i].child );
		ok1( c->used == 10 );
//		hx_btree_node_debug( "# child>\t", w, c );
	}
	
	_hx_btree_node_split_child( w, root, 0, child, branching_size );
	
// 	fprintf( stderr, "# *** AFTER SPLIT:\n" );
// 	hx_btree_node_debug( "# root>\t", w, root );
	
	ok1( root->used == 2 );
	ok1( root->ptr[0].key == (hx_node_id) 11 );
	ok1( root->ptr[1].key == (hx_node_id) 16 );
	
	for (int i = 0; i < root->used; i++) {
		hx_btree_node* c	= hx_storage_block_from_id( w, root->ptr[i].child );
		ok1( c->used == 5 );
// 		hx_btree_node_debug( "# child>\t", w, c );
	}
	
	hx_free_btree_node(w, root);
	hx_free_storage_manager( w );
}

void medium_split_test ( void ) {
	hx_storage_manager* w	= hx_new_memory_storage_manager();
	hx_btree_node* root	= hx_new_btree_node( w, branching_size );
	hx_btree_node_set_flag( w, root, HX_BTREE_NODE_ROOT );
	
	hx_btree_node* child	= hx_new_btree_node( w, branching_size );
	hx_btree_node_set_flag( w, child, HX_BTREE_NODE_LEAF );
	
	for (int i = 0; i < branching_size-1; i++) {
		hx_node_id key	= (hx_node_id) i;
		hx_storage_id_t value	= (hx_storage_id_t) 100 + i;
		hx_btree_node_add_child( w, child, key, value, branching_size );
	}
	hx_storage_id_t cid	= hx_storage_id_from_block( w, child );
	hx_btree_node_add_child( w, root, (hx_node_id) branching_size-1, cid, branching_size );
	
	ok1( root->used == 1 );
	
// 	fprintf( stderr, "# *** BEFORE SPLIT:\n" );
// 	hx_btree_node_debug( "# root>\t", w, root );
	
	{
		int counter	= 0;
		for (int i = 0; i < root->used; i++) {
			hx_btree_node* c	= hx_storage_block_from_id( w, root->ptr[i].child );
			ok1( c->used == branching_size-1 );
//			hx_btree_node_debug( "# child>\t", w, c );
			counter++;
		}
		ok1( counter == 1 );
	}
	
	
	_hx_btree_node_split_child( w, root, 0, child, branching_size );
	
// 	fprintf( stderr, "# *** AFTER SPLIT:\n" );
// 	hx_btree_node_debug( "# root>\t", w, root );
	
	ok1( root->used == 2 );
	ok1( root->ptr[0].key == (hx_node_id) ((branching_size-2)/2) );
	ok1( root->ptr[1].key == (hx_node_id) branching_size-2 );
	
	{
		int total	= 0;
		int counter	= 0;
		for (int i = 0; i < root->used; i++) {
			hx_btree_node* c	= hx_storage_block_from_id( w, root->ptr[i].child );
			total	+= c->used;
//			hx_btree_node_debug( "# child>\t", w, c );
			counter++;
		}
		ok1( counter == 2 );
		ok1( total == branching_size-1 );
	}
	
	hx_free_btree_node(w, root);
	hx_free_storage_manager( w );
}

void large_split_test ( void ) {
	hx_storage_manager* w	= hx_new_memory_storage_manager();
	hx_btree_node* root	= hx_new_btree_node( w, branching_size );
	hx_btree_node_set_flag( w, root, HX_BTREE_NODE_ROOT );
	
	hx_btree_node* child	= hx_new_btree_node( w, branching_size );
	hx_btree_node_set_flag( w, child, HX_BTREE_NODE_LEAF );
	
	for (int i = 0; i < branching_size; i++) {
		hx_node_id key	= (hx_node_id) i;
		hx_storage_id_t value	= (hx_storage_id_t) 100 + i;
		hx_btree_node_add_child( w, child, key, value, branching_size );
	}
	hx_storage_id_t cid	= hx_storage_id_from_block( w, child );
	hx_btree_node_add_child( w, root, (hx_node_id) branching_size, cid, branching_size );
	
	ok1( root->used == 1 );
	
// 	fprintf( stderr, "# *** BEFORE SPLIT:\n" );
// 	hx_btree_node_debug( "# root>\t", w, root );
	
	{
		int counter	= 0;
		for (int i = 0; i < root->used; i++) {
			hx_btree_node* c	= hx_storage_block_from_id( w, root->ptr[i].child );
			ok1( c->used == branching_size );
// 			hx_btree_node_debug( "# child>\t", w, c );
			counter++;
		}
		ok1( counter == 1 );
	}
	
	
	_hx_btree_node_split_child( w, root, 0, child, branching_size );
	
// 	fprintf( stderr, "# *** AFTER SPLIT:\n" );
// 	hx_btree_node_debug( "# root>\t", w, root );
	
	ok1( root->used == 2 );
	ok1( root->ptr[0].key == (hx_node_id) (branching_size/2)-1 );
	ok1( root->ptr[1].key == (hx_node_id) branching_size-1 );
	
	{
		int counter	= 0;
		for (int i = 0; i < root->used; i++) {
			hx_btree_node* c	= hx_storage_block_from_id( w, root->ptr[i].child );
			ok1( c->used == (branching_size/2) );
// 			hx_btree_node_debug( "# child>\t", w, c );
			counter++;
		}
		ok1( counter == 2 );
	}
	
	hx_free_btree_node(w, root);
	hx_free_storage_manager( w );
}

void large_test ( void ) {
	hx_storage_manager* w	= hx_new_memory_storage_manager();
//	printf( "%d\n", (int) sizeof( hx_btree_node ) );
	hx_btree* tree		= hx_new_btree( w, branching_size );
	hx_btree_node* root	= tree->root;
	hx_btree_node_set_flag( w, root, HX_BTREE_NODE_ROOT );
	hx_btree_node_set_flag( w, root, HX_BTREE_NODE_LEAF );
//	printf( "root: %d (%p)\n", (int) _hx_btree_node2int(w, root), (void*) root );
	
	for (int i = 1; i <= 4000000; i++) {
		hx_btree_node_insert( w, &(tree->root), (hx_node_id) i, (hx_storage_id_t) 10*i, branching_size );
	}
	
	list_size_t size	= hx_btree_size( w, tree );
	ok1( 4000000 == size );
//	ok1( 15876 == hx_btree_size( w, hx_storage_block_from_id( w, root->ptr[0].child ) ) );
	
	int counter	= 0;
	hx_node_id key, last;
	hx_storage_id_t value3;
	hx_btree_iter* iter	= hx_btree_new_iter( w, tree );
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
	hx_free_btree(w, tree);
	hx_free_storage_manager( w );
}


void small_remove_test ( void ) {
	hx_storage_manager* s	= hx_new_memory_storage_manager();
	hx_btree* tree		= hx_new_btree( s, branching_size );
	hx_btree_node* root	= tree->root;
	
	{
		// remove in increasing order
		_add_data( s, tree, 10, 7 );
		ok1( hx_btree_size(s,tree) == 10 );
		
		for (int i = 0; i < 10; i++) {
			hx_node_id key	= (hx_node_id) 7 + i;
			hx_btree_node_remove( s, &(tree->root), key, branching_size );
		}
		ok1( hx_btree_size(s,tree) == 0 );
	}
	
	{
		// remove in decreasing order
		_add_data( s, tree, 10, 7 );
		ok1( hx_btree_size(s,tree) == 10 );
		
		for (int i = 9; i >= 0; i--) {
			hx_node_id key	= (hx_node_id) 7 + i;
			hx_btree_node_remove( s, &(tree->root), key, branching_size );
		}
		ok1( hx_btree_size(s,tree) == 0 );
	}
	
	{
		// remove in random order
		_add_data( s, tree, 10, 7 );
		ok1( hx_btree_size(s,tree) == 10 );
		hx_btree_node_remove( s, &(tree->root), (hx_node_id) 14, branching_size );
		hx_btree_node_remove( s, &(tree->root), (hx_node_id) 10, branching_size );
		hx_btree_node_remove( s, &(tree->root), (hx_node_id) 11, branching_size );
		hx_btree_node_remove( s, &(tree->root), (hx_node_id) 12, branching_size );
		hx_btree_node_remove( s, &(tree->root), (hx_node_id) 16, branching_size );
		hx_btree_node_remove( s, &(tree->root), (hx_node_id) 15, branching_size );
		hx_btree_node_remove( s, &(tree->root), (hx_node_id) 9, branching_size );
		hx_btree_node_remove( s, &(tree->root), (hx_node_id) 8, branching_size );
		hx_btree_node_remove( s, &(tree->root), (hx_node_id) 13, branching_size );
		hx_btree_node_remove( s, &(tree->root), (hx_node_id) 7, branching_size );
		ok1( hx_btree_size(s,tree) == 0 );
	}
	
	hx_free_btree(s, tree);
	hx_free_storage_manager( s );
}

void medium_remove_test ( void ) {
	hx_storage_manager* s	= hx_new_memory_storage_manager();
	hx_btree* tree		= hx_new_btree( s, branching_size );
	hx_btree_node* root	= tree->root;
	
	{
		// remove in increasing order
		_add_data( s, tree, 253, 1 );
// 		hx_btree_tree_debug( "tree>\t", s, root );
		
		ok1( hx_btree_node_search( s, tree->root, (hx_node_id) 253, branching_size ) > 0 );
		ok1( hx_btree_size(s,tree) == 253 );
		hx_btree_node_remove( s, &(tree->root), (hx_node_id) 1, branching_size );
		ok1( hx_btree_node_search( s, tree->root, (hx_node_id) 253, branching_size ) > 0 );
		ok1( hx_btree_size(s,tree) == 252 );
		
		hx_btree_node_remove( s, &(tree->root), (hx_node_id) 2, branching_size );
		ok1( hx_btree_size(s,tree) == 251 );
		
		for (int i = 1; i <= 253; i++) {
			hx_btree_node_remove( s, &(tree->root), (hx_node_id) i, branching_size );
		}
		ok1( hx_btree_size(s,tree) == 0 );
	}
	
	hx_free_btree(s, tree);
	hx_free_storage_manager( s );
}

void large_remove_test ( void ) {
	hx_storage_manager* s	= hx_new_memory_storage_manager();
	hx_btree* tree		= hx_new_btree( s, branching_size );
	hx_btree_node* root	= tree->root;
	
	{
		// remove in increasing order
		_add_data( s, tree, 5000, 1 );
// 		hx_btree_tree_debug( "", s, root );
		ok1( hx_btree_size(s,tree) == 5000 );
		for (int i = 1; i <= 126; i++) {
			hx_btree_node_remove( s, &(tree->root), (hx_node_id) i, branching_size );
		}
// 		fprintf( stderr, "%d\n", (int) hx_btree_size(s,root) );
		ok1( hx_btree_size(s,tree) == 4874 );
// 		hx_btree_tree_debug( "", s, root );
		hx_btree_node_remove( s, &(tree->root), (hx_node_id) 127, branching_size );
// 		fprintf( stderr, "%d\n", (int) hx_btree_size(s,root) );
		ok1( hx_btree_size(s,tree) == 4873 );
		
		for (int i = 1; i <= 5000; i++) {
			hx_btree_node_remove( s, &(tree->root), (hx_node_id) i, branching_size );
		}
		ok1( hx_btree_size(s,tree) == 0 );
// 		hx_btree_tree_debug( "", s, root );
	}
	
	hx_free_btree(s, tree);
	hx_free_storage_manager( s );
}



void _add_data ( hx_storage_manager* s, hx_btree* tree, int count, int add ) {
	for (int i = 0; i < count; i++) {
		hx_node_id key	= (hx_node_id) add + i;
		hx_storage_id_t value	= (hx_storage_id_t) 100 + i;
		hx_btree_insert( s, tree, key, value );
	}
}
