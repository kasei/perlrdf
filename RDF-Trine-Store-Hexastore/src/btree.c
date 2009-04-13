#include "btree.h"
#include <assert.h>

void _hx_btree_debug_leaves_visitor (hx_storage_manager* w, hx_btree_node* node, int level, uint32_t branching_size, void* param);
void _hx_btree_debug_visitor ( hx_storage_manager* w, hx_btree_node* node, int level, uint32_t branching_size, void* param );
void _hx_btree_free_node_visitor ( hx_storage_manager* s, hx_btree_node* node, int level, uint32_t branching_size, void* param );

void _hx_btree_count ( hx_storage_manager* w, hx_btree_node* node, int level, uint32_t branching_size, void* param );
int _hx_btree_binary_search ( const hx_btree_node* node, const hx_node_id n, int* index );
int _hx_btree_node_insert_nonfull( hx_storage_manager* w, hx_btree_node* root, hx_node_id key, uint64_t value, uint32_t branching_size );
int _hx_btree_node_split_child( hx_storage_manager* w, hx_btree_node* parent, uint32_t index, hx_btree_node* child, uint32_t branching_size );
int _hx_btree_iter_prime ( hx_btree_iter* iter );
hx_btree_node* _hx_btree_node_search_page ( hx_storage_manager* w, hx_btree_node* root, hx_node_id key, uint32_t branching_size );
int _hx_btree_rebalance( hx_storage_manager* s, hx_btree_node* node, hx_btree_node* from, int dir, uint32_t branching_size );
int _hx_btree_merge_nodes( hx_storage_manager* s, hx_btree_node* a, hx_btree_node* b, uint32_t branching_size );
void _hx_btree_node_reset_keys( hx_storage_manager* s, hx_btree_node* parent );

hx_btree* hx_new_btree ( hx_storage_manager* s, uint32_t branching_size ) {
	hx_btree* tree			= (hx_btree*) hx_storage_new_block( s, sizeof( hx_btree ) );
	tree->root				= hx_new_btree_root( s, branching_size );
	tree->branching_size	= branching_size;
	hx_storage_sync_block( s, tree );
	return tree;
}

int hx_free_btree ( hx_storage_manager* s, hx_btree* tree ) {
	hx_btree_node_traverse( s, tree->root, NULL, _hx_btree_free_node_visitor, 0, tree->branching_size, NULL );
	hx_storage_release_block( s, tree );
	return 0;
}

hx_btree_block_t hx_btree_search ( hx_storage_manager* s, hx_btree* tree, hx_node_id key ) {
	return hx_btree_node_search( s, tree->root, key, tree->branching_size );
}

int hx_btree_insert ( hx_storage_manager* s, hx_btree* tree, hx_node_id key, hx_btree_block_t value ) {
	return hx_btree_node_insert( s, &( tree->root ), key, value, tree->branching_size );
}

int hx_btree_remove ( hx_storage_manager* s, hx_btree* tree, hx_node_id key ) {
	return hx_btree_node_remove( s, &( tree->root ), key, tree->branching_size );
}

void hx_btree_traverse ( hx_storage_manager* s, hx_btree* tree, hx_btree_node_visitor* before, hx_btree_node_visitor* after, int level, void* param ) {
	hx_btree_node_traverse( s, tree->root, before, after, level, tree->branching_size, param );
}

////////////////////////////////////////////////////////////////////////////////

hx_btree_node* hx_new_btree_root ( hx_storage_manager* s, uint32_t branching_size ) {
	hx_btree_node* root	= hx_new_btree_node( s, branching_size );
	hx_btree_node_set_flag( s, root, HX_BTREE_NODE_ROOT );
	hx_btree_node_set_flag( s, root, HX_BTREE_NODE_LEAF );
	hx_storage_sync_block( s, root );
	return root;
}

hx_btree_node* hx_new_btree_node ( hx_storage_manager* w, uint32_t branching_size ) {
	hx_btree_node* node	= (hx_btree_node*) hx_storage_new_block( w, sizeof( hx_btree_node ) + (branching_size * sizeof( hx_btree_child )) );
	memcpy( &( node->type ), "HXBN", 4 );
	node->used	= (uint32_t) 0;
	hx_storage_sync_block( w, node );
	return node;
}

int hx_free_btree_node ( hx_storage_manager* w, hx_btree_node* node ) {
	hx_storage_release_block( w, node );
	return 0;
}

list_size_t hx_btree_size ( hx_storage_manager* w, hx_btree* tree ) {
	list_size_t count	= 0;
	hx_btree_node_traverse( w, tree->root, _hx_btree_count, NULL, 0, tree->branching_size, &count );
	return count;
}

int hx_btree_node_set_parent ( hx_storage_manager* s, hx_btree_node* node, hx_btree_node* parent ) {
	uint64_t id	= hx_storage_id_from_block( s, parent );
	node->parent	= id;
	return 0;
}

int hx_btree_node_set_prev_neighbor ( hx_storage_manager* w, hx_btree_node* node, hx_btree_node* prev ) {
	node->prev	= hx_storage_id_from_block( w, prev );
	return 0;
}

int hx_btree_node_set_next_neighbor ( hx_storage_manager* w, hx_btree_node* node, hx_btree_node* next ) {
	node->next	= hx_storage_id_from_block( w, next );
	return 0;
}

hx_btree_node* hx_btree_node_next_neighbor ( hx_storage_manager* w, hx_btree_node* node ) {
	return hx_storage_block_from_id( w, node->next );
}

hx_btree_node* hx_btree_node_prev_neighbor ( hx_storage_manager* w, hx_btree_node* node ) {
	return hx_storage_block_from_id( w, node->prev );
}

int hx_btree_node_set_flag ( hx_storage_manager* w, hx_btree_node* node, uint32_t flag ) {
	node->flags	|= flag;
	return 0;
}

int hx_btree_node_unset_flag ( hx_storage_manager* w, hx_btree_node* node, uint32_t flag ) {
	if (node->flags & flag) {
		node->flags	^= flag;
	}
	return 0;
}

int hx_btree_node_debug ( char* string, hx_storage_manager* w, hx_btree_node* node, uint32_t branching_size ) {
	fprintf( stderr, "%sNode %d (%p):\n", string, (int) hx_storage_id_from_block(w,node), (void*) node );
	fprintf( stderr, "%s\tUsed: [%d/%d]\n", string, node->used, branching_size );
	fprintf( stderr, "%s\tFlags: ", string );
	if (node->flags & HX_BTREE_NODE_ROOT)
		fprintf( stderr, "HX_BTREE_NODE_ROOT " );
	if (node->flags & HX_BTREE_NODE_LEAF)
		fprintf( stderr, "HX_BTREE_NODE_LEAF" );
	fprintf( stderr, "\n" );
	for (int i = 0; i < node->used; i++) {
		fprintf( stderr, "%s\t- %d -> %d\n", string, (int) node->ptr[i].key, (int) node->ptr[i].child );
	}
	return 0;
}

int hx_btree_tree_debug ( char* string, hx_storage_manager* w, hx_btree_node* node, uint32_t branching_size ) {
	hx_btree_node_traverse( w, node, _hx_btree_debug_visitor, NULL, 0, branching_size, string );
	return 0;
}

int _hx_btree_binary_search ( const hx_btree_node* node, const hx_node_id n, int* index ) {
	int low		= 0;
	int high	= node->used - 1;
	while (low <= high) {
		int mid	= low + (high - low) / 2;
		if (node->ptr[mid].key > n) {
			high	= mid - 1;
		} else if (node->ptr[mid].key < n) {
			low	= mid + 1;
		} else {
			*index	= mid;
			return 0;
		}
	}
	*index	= low;
	return -1;
}

int hx_btree_node_add_child ( hx_storage_manager* w, hx_btree_node* node, hx_node_id n, uint64_t child, uint32_t branching_size ) {
	int i;
	int r	= _hx_btree_binary_search( node, n, &i );
	if (r == 0) {
		// already in list. do nothing.
		return 1;
	} else {
		// not found. need to add at index i
		if (node->used >= branching_size) {
			fprintf( stderr, "*** Cannot add child to already-full node\n" );
			return 2;
		}
		
		for (int k = node->used - 1; k >= i; k--) {
			node->ptr[ k+1 ]	= node->ptr[ k ];
// 			node->keys[k + 1]	= node->keys[k];
// 			node->children[k + 1]	= node->children[k];
		}
		
		node->ptr[i].key	= n;
		node->ptr[i].child	= child;
// 		node->keys[i]		= n;
// 		node->children[i]	= child;
		node->used++;
	}
	hx_storage_sync_block( w, node );
	return 0;
}

uint64_t hx_btree_node_get_child ( hx_storage_manager* w, hx_btree_node* node, hx_node_id n, uint32_t branching_size ) {
	int i;
	int r	= _hx_btree_binary_search( node, n, &i );
	if (r == 0) {
		// found
		return node->ptr[ i ].child;
	} else {
		// not found. need to add at index i
		return 0;
	}
}

int hx_btree_node_remove_child ( hx_storage_manager* w, hx_btree_node* node, hx_node_id n, uint32_t branching_size ) {
	int i;
	int r	= _hx_btree_binary_search( node, n, &i );
	if (r == 0) {
		// found
		for (int k = i; k < node->used; k++) {
			node->ptr[k]		= node->ptr[k+1];
// 			node->keys[ k ]		= node->keys[ k + 1 ];
// 			node->children[ k ]	= node->children[ k + 1 ];
		}
		node->used--;
		hx_storage_sync_block( w, node );
		return 0;
	} else {
		// not found. need to add at index i
		return 1;
	}
}

hx_btree_block_t hx_btree_node_search ( hx_storage_manager* w, hx_btree_node* root, hx_node_id key, uint32_t branching_size ) {
	hx_btree_node* u	= _hx_btree_node_search_page( w, root, key, branching_size );
	int i;
	int r	= _hx_btree_binary_search( u, key, &i );
// 	fprintf( stderr, "looking for %d\n", (int) key );
// 	hx_btree_node_debug( "> ", w, u, branching_size );
	if (r == 0) {
		// found
		return u->ptr[i].child;
	} else {
		// not found
		return 0;
	}
}

hx_btree_node* _hx_btree_node_search_page ( hx_storage_manager* w, hx_btree_node* root, hx_node_id key, uint32_t branching_size ) {
	hx_btree_node* u	= root;
	while (!hx_btree_node_has_flag(w, u, HX_BTREE_NODE_LEAF)) {
//		fprintf( stderr, "node is not a leaf... (flags: %x)\n", u->flags );
		for (int i = 0; i < u->used - 1; i++) {
			if (key <= u->ptr[i].key) {
				uint64_t id	= u->ptr[i].child;
//				fprintf( stderr, "descending to child %d\n", (int) id );
				u	= hx_storage_block_from_id( w, id );
				goto NEXT;
			}
		}
//		fprintf( stderr, "decending to last child\n" );
		u	= hx_storage_block_from_id( w, u->ptr[ u->used - 1 ].child );
NEXT:	1;
	}
	
	return u;
}

int hx_btree_node_insert ( hx_storage_manager* w, hx_btree_node** _root, hx_node_id key, hx_btree_block_t value, uint32_t branching_size ) {
	hx_btree_node* root	= *_root;
	if (root->used == branching_size) {
		hx_btree_node* s	= hx_new_btree_node( w, branching_size );
		{
			hx_btree_node_set_flag( w, s, HX_BTREE_NODE_ROOT );
			hx_btree_node_unset_flag( w, root, HX_BTREE_NODE_ROOT );
			hx_btree_node_set_parent( w, root, s );
			hx_node_id key	= root->ptr[ branching_size - 1 ].key;
			uint64_t rid	= hx_storage_id_from_block( w, root );
			hx_btree_node_add_child( w, s, key, rid, branching_size );
			_hx_btree_node_split_child( w, s, 0, root, branching_size );
			*_root	= s;
			hx_storage_sync_block( w, s );
		}
		return _hx_btree_node_insert_nonfull( w, s, key, value, branching_size );
	} else {
		return _hx_btree_node_insert_nonfull( w, root, key, value, branching_size );
	}
}

int _hx_btree_node_insert_nonfull( hx_storage_manager* w, hx_btree_node* node, hx_node_id key, uint64_t value, uint32_t branching_size ) {
	if (hx_btree_node_has_flag( w, node, HX_BTREE_NODE_LEAF )) {
		return hx_btree_node_add_child( w, node, key, value, branching_size );
	} else {
		int i;
		hx_btree_node* u	= NULL;
		for (i = 0; i < node->used - 1; i++) {
			if (key <= node->ptr[i].key) {
				uint64_t id	= node->ptr[i].child;
				u	= hx_storage_block_from_id( w, id );
				break;
			}
		}
		if (u == NULL) {
			i	= node->used - 1;
			u	= hx_storage_block_from_id( w, node->ptr[ i ].child );
		}
		
		if (u->used == branching_size) {
			_hx_btree_node_split_child( w, node, i, u, branching_size );
			if (key > node->ptr[i].key) {
				i++;
				u	= hx_storage_block_from_id( w, node->ptr[ i ].child );
			}
		}
		
		if (key > node->ptr[i].key) {
			node->ptr[i].key	= key;
		}
		hx_storage_sync_block( w, node );
		
		return _hx_btree_node_insert_nonfull( w, u, key, value, branching_size );
	}
}

int hx_btree_node_remove ( hx_storage_manager* s, hx_btree_node** _root, hx_node_id key, uint32_t branching_size ) {
//	fprintf( stderr, "removing node %d from btree...\n", (int) key );
	// recurse to leaf node
//	fprintf( stderr, "remove> recurse to leaf node\n" );
	
	hx_btree_node* root	= *_root;
	hx_btree_node* node	= _hx_btree_node_search_page( s, root, key, branching_size );
	int i	= -1;
	int r	= _hx_btree_binary_search( node, key, &i );
	
	// if node doesn't have key, return 1
//	fprintf( stderr, "remove> if node doesn't have key, return 1\n" );
	if (r != 0) {
// 		fprintf( stderr, "node %d not found in btree\n", (int) key );
		return 1;
	}
	
//	fprintf( stderr, "remove> REMOVED NODE FROM LEAF\n" );
	
REMOVE_NODE:
	// [3] remove entry from node
//	fprintf( stderr, "remove> [3] remove entry from node\n" );
//	fprintf( stderr, "      > removing node from parent with (%d/%d) slots used\n", (int) node->used, branching_size );
	for (int k = i; k < node->used; k++) {
		node->ptr[k]		= node->ptr[k+1];
// 		node->keys[ k ]		= node->keys[ k + 1 ];
// 		node->children[ k ]	= node->children[ k + 1 ];
	}
	node->used--;
	hx_storage_sync_block( s, node );
	
	// if node doesn't underflow return 0
//	fprintf( stderr, "remove> if node doesn't underflow return 0\n" );
	if (node->used >= branching_size/2) {
		return 0;
	}
	
//	fprintf( stderr, "remove> UNDERFLOW DETECTED\n" );
	
	// if current node is root
//	fprintf( stderr, "remove> if current node is root..." );
	if (node == root) {
//		fprintf( stderr, "yes\n" );
		if (hx_btree_node_has_flag(s, root, HX_BTREE_NODE_LEAF)) {
			// node is root and leaf -- we're done
//			fprintf( stderr, "remove> node is root and leaf -- we're done\n" );
			return 0;
		}
		
		// if root has only 1 child
		if (root->used == 1) {
			// make new root the current root's only child
//			fprintf( stderr, "remove> make new root the current root's only child\n" );
//			fprintf( stderr, "removing unnecessary root %p...\n", (void*) root );
			hx_btree_node* newroot	= hx_storage_block_from_id( s, root->ptr[0].child );
// 			hx_btree_node_debug( "new root>\t", s, newroot, branching_size );
//			fprintf( stderr, "setting new root to %p...\n", (void*) newroot );
			*_root	= newroot;
			hx_free_btree_node( s, root );
			root	= newroot;
			hx_btree_node_set_flag( s, root, HX_BTREE_NODE_ROOT );
			hx_storage_sync_block( s, root );
		}
		return 0;
	} else {
//		fprintf( stderr, "no\n" );
	}
	
	// check number of entries in both left and right neighbors
//	fprintf( stderr, "remove> check number of entries in both left and right neighbors\n" );
	hx_btree_node* prev	= hx_btree_node_prev_neighbor( s, node );
	hx_btree_node* next	= hx_btree_node_next_neighbor( s, node );
	
// 	if (prev != NULL) {
// 		fprintf( stderr, "      > prev: (%d/%d)\n", (int) prev->used, (int) branching_size );
// 	}
// 	if (next != NULL) {
// 		fprintf( stderr, "      > next: (%d/%d)\n", (int) next->used, (int) branching_size );
// 	}
	
	int prev_minimal	= 1;
	int next_minimal	= 1;
	if (prev != NULL && prev->used > branching_size/2) {
		prev_minimal	= 0;
	}
	if (next != NULL && next->used > branching_size/2) {
		next_minimal	= 0;
	}
	
	// if both are minimal, continue, else balance current node:
	// shift over half of a neighbor’s surplus keys, adjust anchor, done
//	fprintf( stderr, "remove> if both are minimal, continue, else balance current node\n" );
	if (!(prev_minimal == 1 && next_minimal == 1)) {
//		fprintf( stderr, "remove> both are NOT minimal\n" );
		int rebalanced	= 0;
		if (prev != NULL && prev->used > branching_size/2) {
//			fprintf( stderr, "remove> rebalancing with previous node\n" );
			_hx_btree_rebalance( s, node, prev, 1, branching_size );
			rebalanced	= 1;
		}
		if ((!rebalanced) && next != NULL && next->used > branching_size/2) {
//			fprintf( stderr, "remove> rebalancing with next node\n" );
			_hx_btree_rebalance( s, node, next, 0, branching_size );
			rebalanced	= 1;
		}
		if (rebalanced == 1) {
			return 0;
		} else {
			fprintf( stderr, "*** rebalancing should have occurred, but didn't\n" );
		}
	}
	
	
	
	
	
	// merge with neighbor whose anchor is the current node's parent
//	fprintf( stderr, "remove> merge with neighbor whose anchor is the current node's parent\n" );
//	fprintf( stderr, "      > prev: %p\tnext: %p\n", (void*) prev, (void*) next );
	int merged	= 0;
	uint64_t removed_nodeid	= 0;
	if (prev != NULL) {
//		fprintf( stderr, "node parent: %d, prev parent: %d\n", (int) node->parent, (int) prev->parent );
		if (prev->parent == node->parent) {
//			fprintf( stderr, "remove> merging with previous node (%d)\n", (int) hx_storage_id_from_block( s, prev ) );
			_hx_btree_merge_nodes( s, node, prev, branching_size );
			removed_nodeid	= hx_storage_id_from_block( s, prev );
			merged	= 1;
		}
	}
	if ((!merged) && next != NULL) {
//		fprintf( stderr, "node parent: %d, next parent: %d\n", (int) node->parent, (int) next->parent );
		if (next->parent == node->parent) {
//			fprintf( stderr, "remove> merging with next node (%d)\n", (int) hx_storage_id_from_block( s, next ) );
			removed_nodeid	= hx_storage_id_from_block( s, next );
			_hx_btree_merge_nodes( s, node, next, branching_size );
			merged	= 1;
		}
	}
	
	if (!merged) {
		fprintf( stderr, "*** merge should have occurred, but didn't\n" );
	}
	
	// re-wind to parent, continue at [3] (removing the just-removed node from the parent)
	int found_parent_index	= 0;
//	fprintf( stderr, "remove> re-wind to parent, continue at [3] (removing the just-removed node from the parent)\n" );
	hx_btree_node* parent	= hx_storage_block_from_id( s, node->parent );
	for (int j = 0; j < parent->used; j++) {
		if (parent->ptr[j].child == removed_nodeid) {
			found_parent_index	= 1;
			i	= j;
//			fprintf( stderr, "removed node: %d\n", (int) removed_nodeid );
//			fprintf( stderr, "\t(at index %d)\n", j );
			break;
		}
	}
	
	if (!found_parent_index) {
		fprintf( stderr, "*** didn't find node %d as a child of node %d\n", (int) removed_nodeid, (int) node->parent );
	}
	
	node	= parent;
	goto REMOVE_NODE;
}

// take half the extra nodes from the `from' node, and add them to `node'.
// dir specifies from which end of `from' to take from:
//     dir=0 => shift from the beginning
//     dir=1 => pop off the end
int _hx_btree_rebalance( hx_storage_manager* s, hx_btree_node* node, hx_btree_node* from, int dir, uint32_t branching_size ) {
	if (from->used < branching_size/2) {
		fprintf( stderr, "*** trying to rebalance with an already underfull node\n" );
		return 1;
	}
	
// 	fprintf( stderr, "before rebalancing key count: %d, %d\n", node->used, from->used );
	
	int min		= branching_size/2;
	int extra	= from->used - min;
	int take	= (extra+1)/2;
	if (dir == 1) {
		for (int i = from->used - take - 1; i < from->used; i++) {
// 			fprintf( stderr, "rebalancing>\t%d\n", i );
			hx_btree_node_add_child( s, node, from->ptr[i].key, from->ptr[i].child, branching_size );
			if (!hx_btree_node_has_flag( s, from, HX_BTREE_NODE_LEAF )) {
				hx_btree_node* child	= hx_storage_block_from_id( s, from->ptr[i].child );
				hx_btree_node_set_parent( s, child, node );
				hx_storage_sync_block( s, child );
			}
		}
	} else {
		for (int i = 0; i < take; i++) {
// 			fprintf( stderr, "rebalancing>\t%d\n", i );
			hx_btree_node_add_child( s, node, from->ptr[i].key, from->ptr[i].child, branching_size );
			if (!hx_btree_node_has_flag( s, from, HX_BTREE_NODE_LEAF )) {
				hx_btree_node* child	= hx_storage_block_from_id( s, from->ptr[i].child );
				hx_btree_node_set_parent( s, child, node );
				hx_storage_sync_block( s, child );
			}
		}
		// now shift the remaining nodes in `from' over
		for (int i = 0; i < from->used - take; i++) {
// 			fprintf( stderr, "rebalancing>\t[%d] = [%d]\n", i, i+take );
			from->ptr[i]		= from->ptr[i+take];
// 			from->keys[i]		= from->keys[i+take];
// 			from->children[i]	= from->children[i+take];
		}
	}
	
	// refresh the key list (this could be more efficient by only updating the two keys that were possibly affected)
	hx_btree_node* parent	= hx_storage_block_from_id( s, node->parent );
	_hx_btree_node_reset_keys( s, parent );
	
	from->used	-= take;
	
	hx_storage_sync_block( s, from );
	hx_storage_sync_block( s, parent );
	
// 	fprintf( stderr, "rebalanced key count: %d, %d\n", node->used, from->used );
	return 0;
}

void _hx_btree_node_reset_keys( hx_storage_manager* s, hx_btree_node* parent ) {
	for (int i = 0; i < parent->used; i++) {
		hx_btree_node* child	= hx_storage_block_from_id( s, parent->ptr[i].child );
		parent->ptr[i].key	= child->ptr[ child->used - 1 ].key;
	}
}

// merge data from node b into node a
int _hx_btree_merge_nodes( hx_storage_manager* s, hx_btree_node* a, hx_btree_node* b, uint32_t branching_size ) {
	if (a->parent != b->parent) {
		fprintf( stderr, "*** trying to merge nodes with different parents!\n" );
		return 1;
	}
	
	if ((a->used + b->used) > branching_size) {
		fprintf( stderr, "*** trying to merge nodes would result in an overflow!\n" );
		return 1;
	}
	
	for (int i = 0; i < b->used; i++) {
		hx_btree_node_add_child( s, a, b->ptr[i].key, b->ptr[i].child, branching_size );
		if (!hx_btree_node_has_flag( s, a, HX_BTREE_NODE_LEAF )) {
			hx_btree_node* child	= hx_storage_block_from_id( s, b->ptr[i].child );
			hx_btree_node_set_parent( s, child, a );
			hx_storage_sync_block( s, child );
		}
	}
	
	a->next	= b->next;
	hx_storage_sync_block( s, a );
	
	hx_btree_node* c	= hx_storage_block_from_id( s, a->next );
	if (c != NULL) {
		c->prev	= hx_storage_id_from_block( s, a );
		hx_storage_sync_block( s, c );
	}
	
	// refresh the key list (this could be more efficient by only updating the two keys that were possibly affected)
	hx_btree_node* parent	= hx_storage_block_from_id( s, a->parent );
	_hx_btree_node_reset_keys( s, parent );
	hx_storage_sync_block( s, parent );
	
	return 0;
}

int _hx_btree_node_split_child( hx_storage_manager* w, hx_btree_node* parent, uint32_t index, hx_btree_node* child, uint32_t branching_size ) {
	hx_btree_node* z	= hx_new_btree_node( w, branching_size );
	hx_btree_node* next	= hx_btree_node_next_neighbor( w, child );
	hx_btree_node_set_prev_neighbor( w, z, child );
	hx_btree_node_set_next_neighbor( w, z, next );
	hx_btree_node_set_next_neighbor( w, child, z );
	if (next != NULL) {
		hx_btree_node_set_prev_neighbor( w, next, z );
		hx_storage_sync_block( w, next );
	}
	
	hx_btree_node_set_parent( w, z, parent );
	if (hx_btree_node_has_flag( w, child, HX_BTREE_NODE_LEAF )) {
		hx_btree_node_set_flag( w, z, HX_BTREE_NODE_LEAF );
	}
	int i	= 0;
	z->used	= 0;
	int to_move		= child->used / 2;
	int child_index	= child->used - to_move;
	for (int j = 0; j < to_move; j++) {
		z->ptr[j]		= child->ptr[ child_index ];
// 		z->keys[j]		= child->keys[ child_index ];
// 		z->children[j]	= child->children[ child_index ];
		child_index++;
		z->used++;
		child->used--;
	}
	
	uint64_t cid	= hx_storage_id_from_block( w, child );
	uint64_t zid	= hx_storage_id_from_block( w, z );
	
	hx_node_id ckey	= child->ptr[ child->used - 1 ].key;
	hx_node_id zkey	= z->ptr[ z->used - 1 ].key;
	
	parent->ptr[index].key	= ckey;
	hx_btree_node_add_child( w, parent, zkey, zid, branching_size );
	
	hx_storage_sync_block( w, parent );
	hx_storage_sync_block( w, z );
	hx_storage_sync_block( w, child );
	
	return 0;
}

void hx_btree_node_traverse ( hx_storage_manager* w, hx_btree_node* node, hx_btree_node_visitor* before, hx_btree_node_visitor* after, int level, uint32_t branching_size, void* param ) {
	if (before != NULL) before( w, node, level, branching_size, param );
	if (!hx_btree_node_has_flag( w, node, HX_BTREE_NODE_LEAF )) {
		for (int i = 0; i < node->used; i++) {
			hx_btree_node* c	= hx_storage_block_from_id( w, node->ptr[i].child );
			hx_btree_node_traverse( w, c, before, after, level + 1, branching_size, param );
		}
	}
	if (after != NULL) after( w, node, level, branching_size, param );
}

void _hx_btree_debug_leaves_visitor ( hx_storage_manager* w, hx_btree_node* node, int level, uint32_t branching_size, void* param ) {
	if (hx_btree_node_has_flag( w, node, HX_BTREE_NODE_LEAF )) {
		fprintf( stderr, "LEVEL %d\n", level );
		hx_btree_node_debug( "", w, node, branching_size );
	}
}

void _hx_btree_debug_visitor ( hx_storage_manager* w, hx_btree_node* node, int level, uint32_t branching_size, void* param ) {
	hx_btree_node_debug( param, w, node, branching_size );
}

void _hx_btree_count ( hx_storage_manager* w, hx_btree_node* node, int level, uint32_t branching_size, void* param ) {
	list_size_t* count	= (list_size_t*) param;
	if (hx_btree_node_has_flag( w, node, HX_BTREE_NODE_LEAF )) {
		*count	+= node->used;
	}
}

void _hx_btree_free_node_visitor ( hx_storage_manager* s, hx_btree_node* node, int level, uint32_t branching_size, void* param ) {
	hx_free_btree_node( s, node );
}

hx_btree_iter* hx_btree_new_iter ( hx_storage_manager* w, hx_btree* tree ) {
	hx_btree_node* root	= tree->root;
	hx_btree_iter* iter	= (hx_btree_iter*) calloc( 1, sizeof( hx_btree_iter ) );
	iter->storage	= w;
	iter->started	= 0;
	iter->finished	= 0;
	iter->tree		= tree;
	iter->page		= NULL;
	iter->index		= 0;
	return iter;
}

int hx_free_btree_iter ( hx_btree_iter* iter ) {
	free( iter );
	return 0;
}


int _hx_btree_iter_prime ( hx_btree_iter* iter ) {
	iter->started	= 1;
	hx_btree_node* p	= iter->tree->root;
	while (!hx_btree_node_has_flag(iter->storage, p, HX_BTREE_NODE_LEAF)) {
		if (p->used > 0) {
			p	= hx_storage_block_from_id( iter->storage, p->ptr[0].child );
		} else {
			iter->finished	= 1;
			return 1;
		}
	}
	iter->page	= p;
	iter->index	= 0;
	return 0;
}

int hx_btree_iter_finished ( hx_btree_iter* iter ) {
	if (iter->started == 0) {
		_hx_btree_iter_prime( iter );
	}
	return iter->finished;
}

int hx_btree_iter_current ( hx_btree_iter* iter, hx_node_id* n, uint64_t* v ) {
	if (iter->started == 0) {
		_hx_btree_iter_prime( iter );
	}
	if (iter->finished == 1) {
		return 1;
	}
	*n	= iter->page->ptr[ iter->index ].key;
	if (v != NULL) {
		*v	= iter->page->ptr[ iter->index ].child;
	}
	return 0;
}

int hx_btree_iter_next ( hx_btree_iter* iter ) {
	if (hx_btree_iter_finished(iter)) {
		return 1;
	}
	iter->index++;
	if (iter->index >= iter->page->used) {
		iter->page	= hx_btree_node_next_neighbor( iter->storage, iter->page );
		iter->index	= 0;
		if (iter->page == NULL) {
			iter->finished	= 1;
			return 1;
		}
	}
	return 0;
}

int hx_btree_iter_seek( hx_btree_iter* iter, hx_node_id key ) {
	if (iter->started == 0) {
		_hx_btree_iter_prime( iter );
	}
	
	hx_btree_node* u	= _hx_btree_node_search_page( iter->storage, iter->tree->root, key, iter->tree->branching_size );
	int i;
	int r	= _hx_btree_binary_search( u, key, &i );
	iter->page	= u;
	iter->index	= i;
	if (r == 0) {
		return 0;
	} else {
		return 1;
	}
}


