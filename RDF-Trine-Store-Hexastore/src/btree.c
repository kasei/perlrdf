#include "btree.h"

void _hx_btree_debug_leaves (hx_btree_world* w, hx_btree_node* node, int level);
int _hx_btree_binary_search ( const hx_btree_node* node, const hx_node_id n, int* index );
hx_btree_node* _hx_btree_int2node ( hx_btree_world* w, uint64_t id );
uint64_t _hx_btree_node2int ( hx_btree_world* w, hx_btree_node* node );
int _hx_btree_insert_nonfull( hx_btree_world* w, hx_btree_node* root, hx_node_id key, uint64_t value );
int _hx_btree_node_split_child( hx_btree_world* w, hx_btree_node* parent, uint32_t index, hx_btree_node* child );

int main (void) {
	hx_btree_world w;
	w.flags	= HX_BTREE_MEMORY;
	printf( "%d\n", (int) sizeof( hx_btree_node ) );
	hx_btree_node* root	= hx_new_btree_node( &w );
	hx_btree_node_set_flag( &w, root, HX_BTREE_NODE_ROOT );
	hx_btree_node_set_flag( &w, root, HX_BTREE_NODE_LEAF );
	printf( "%p\n", (void*) root );
	
	for (int i = 1; i < 20; i++) {
		hx_btree_node_add_child( &w, root, (hx_node_id) i, (uint64_t) i*2 );
	}
//	hx_btree_node_debug( &w, root );
	
	for (int i = 1; i < 20; i+=2) {
		hx_btree_node_remove_child( &w, root, (hx_node_id) i );
	}
//	hx_btree_node_debug( &w, root );
	
	uint64_t value	= hx_btree_search( &w, root, (hx_node_id) 8 );
//	fprintf( stderr, "key(8) value: %d\n", (int) value );
	
	for (int i = 10000000; i > 0; i--) {
		hx_btree_insert( &w, &root, (hx_node_id) i, (uint64_t) 10*i );
	}
	
	uint64_t value2	= hx_btree_search( &w, root, (hx_node_id) 1818 );
//	fprintf( stderr, "-> %d\n", (int) value2 );
	
//	fprintf( stderr, "***************************\n" );
//	hx_btree_traverse( &w, root, _hx_btree_debug_leaves, NULL, 0 );
//	fprintf( stderr, "***************************\n" );
	
	hx_free_btree_node(&w, root);
	return 0;
}

hx_btree_node* hx_new_btree_node ( hx_btree_world* w ) {
	if (!(w->flags & HX_BTREE_MEMORY)) {
		fprintf( stderr, "*** file-based btrees not implemented yet\n" );
		exit(1);
	}
	hx_btree_node* node	= (hx_btree_node*) calloc( 1, sizeof( hx_btree_node ) );
	memcpy( &( node->type ), "HXBN", 4 );
	node->used	= (uint32_t) 0;
	return node;
}

int hx_free_btree_node ( hx_btree_world* w, hx_btree_node* node ) {
	if (!(w->flags & HX_BTREE_MEMORY)) {
		fprintf( stderr, "*** file-based btrees not implemented yet\n" );
		exit(1);
	}
	free( node );
	return 0;
}

int hx_btree_node_has_flag ( hx_btree_world* w, hx_btree_node* node, uint32_t flag ) {
	return ((node->flags & flag) > 0) ? 1 : 0;
}

int hx_btree_node_set_flag ( hx_btree_world* w, hx_btree_node* node, uint32_t flag ) {
	node->flags	|= flag;
	return 0;
}

int hx_btree_node_unset_flag ( hx_btree_world* w, hx_btree_node* node, uint32_t flag ) {
	if (node->flags & flag) {
		node->flags	^= flag;
	}
	return 0;
}

int hx_btree_node_debug ( hx_btree_world* w, hx_btree_node* node ) {
	fprintf( stderr, "Node (%p):\n", (void*) node );
	fprintf( stderr, "\tUsed: [%d/%d]\n", node->used, BRANCHING_SIZE );
	fprintf( stderr, "\tFlags: " );
	if (node->flags & HX_BTREE_NODE_ROOT)
		fprintf( stderr, "HX_BTREE_NODE_ROOT " );
	if (node->flags & HX_BTREE_NODE_LEAF)
		fprintf( stderr, "HX_BTREE_NODE_LEAF" );
	fprintf( stderr, "\n" );
	for (int i = 0; i < node->used; i++) {
		fprintf( stderr, "\t- %d -> %d\n", (int) node->keys[i], (int) node->children[i] );
	}
	return 0;
}

int _hx_btree_binary_search ( const hx_btree_node* node, const hx_node_id n, int* index ) {
	int low		= 0;
	int high	= node->used - 1;
	while (low <= high) {
		int mid	= low + (high - low) / 2;
		if (node->keys[mid] > n) {
			high	= mid - 1;
		} else if (node->keys[mid] < n) {
			low	= mid + 1;
		} else {
			*index	= mid;
			return 0;
		}
	}
	*index	= low;
	return -1;
}

int hx_btree_node_add_child ( hx_btree_world* w, hx_btree_node* node, hx_node_id n, uint64_t child ) {
	int i;
	int r	= _hx_btree_binary_search( node, n, &i );
	if (r == 0) {
		// already in list. do nothing.
		return 1;
	} else {
		// not found. need to add at index i
		if (node->used >= BRANCHING_SIZE) {
			fprintf( stderr, "*** Cannot add child to already-full node\n" );
			return 2;
		}
		
		for (int k = node->used - 1; k >= i; k--) {
			node->keys[k + 1]	= node->keys[k];
			node->children[k + 1]	= node->children[k];
		}
		node->keys[i]		= n;
		node->children[i]	= child;
		node->used++;
	}
	return 0;
}

uint64_t hx_btree_node_get_child ( hx_btree_world* w, hx_btree_node* node, hx_node_id n ) {
	int i;
	int r	= _hx_btree_binary_search( node, n, &i );
	if (r == 0) {
		// found
		return node->children[ i ];
	} else {
		// not found. need to add at index i
		return 0;
	}
}

int hx_btree_node_remove_child ( hx_btree_world* w, hx_btree_node* node, hx_node_id n ) {
	int i;
	int r	= _hx_btree_binary_search( node, n, &i );
	if (r == 0) {
		// found
		for (int k = i; k < node->used; k++) {
			node->keys[ k ]	= node->keys[ k + 1 ];
			node->children[ k ]	= node->children[ k + 1 ];
		}
		node->used--;
		return 0;
	} else {
		// not found. need to add at index i
		return 1;
	}
}

uint64_t hx_btree_search ( hx_btree_world* w, hx_btree_node* root, hx_node_id key ) {
	hx_btree_node* u	= root;
	while (!hx_btree_node_has_flag(w, u, HX_BTREE_NODE_LEAF)) {
//		fprintf( stderr, "node is not a leaf... (flags: %x)\n", u->flags );
		for (int i = 0; i < u->used - 1; i++) {
			if (key <= u->keys[i]) {
				uint64_t id	= u->children[i];
//				fprintf( stderr, "decending to child %d\n", (int) id );
				u	= _hx_btree_int2node( w, id );
				goto NEXT;
			}
		}
//		fprintf( stderr, "decending to last child\n" );
		u	= _hx_btree_int2node( w, u->children[ u->used - 1 ] );
NEXT:	1;
	}
	int i;
	int r	= _hx_btree_binary_search( u, key, &i );
	if (r == 0) {
		return u->children[i];
	} else {
		return 0;
	}
}

int hx_btree_insert ( hx_btree_world* w, hx_btree_node** _root, hx_node_id key, uint64_t value ) {
	hx_btree_node* root	= *_root;
	if (root->used == BRANCHING_SIZE) {
		hx_btree_node* s	= hx_new_btree_node( w );
		hx_btree_node_set_flag( w, s, HX_BTREE_NODE_ROOT );
		hx_btree_node_unset_flag( w, root, HX_BTREE_NODE_ROOT );
		hx_node_id key	= root->keys[ BRANCHING_SIZE - 1 ];
		uint64_t rid	= _hx_btree_node2int( w, root );
		hx_btree_node_add_child( w, s, key, rid );
		_hx_btree_node_split_child( w, s, 0, root );
		*_root	= s;
		return _hx_btree_insert_nonfull( w, s, key, value );
	} else {
		return _hx_btree_insert_nonfull( w, root, key, value );
	}
}

int _hx_btree_node_split_child( hx_btree_world* w, hx_btree_node* parent, uint32_t index, hx_btree_node* child ) {
	hx_btree_node* z	= hx_new_btree_node( w );
	if (hx_btree_node_has_flag( w, child, HX_BTREE_NODE_LEAF )) {
		hx_btree_node_set_flag( w, z, HX_BTREE_NODE_LEAF );
	}
	z->used	= BRANCHING_MIN;
	for (int j = 0; j < BRANCHING_MIN; j++) {
		z->keys[j]		= child->keys[ j + BRANCHING_MIN ];
		z->children[j]	= child->children[ j + BRANCHING_MIN ];
	}
	
	child->used	= child->used - BRANCHING_MIN;
	
	uint64_t zid	= _hx_btree_node2int( w, z );
	hx_node_id key	= z->keys[ z->used - 1 ];
	hx_btree_node_add_child( w, parent, key, zid );
	return 0;
}

int _hx_btree_insert_nonfull( hx_btree_world* w, hx_btree_node* node, hx_node_id key, uint64_t value ) {
	if (hx_btree_node_has_flag( w, node, HX_BTREE_NODE_LEAF )) {
		hx_btree_node_add_child( w, node, key, value );
	} else {
		int i;
		hx_btree_node* u	= NULL;
		for (i = 0; i < node->used - 1; i++) {
			if (key <= node->keys[i]) {
				uint64_t id	= node->children[i];
				u	= _hx_btree_int2node( w, id );
				break;
			}
		}
		if (u == NULL) {
			i	= node->used - 1;
			u	= _hx_btree_int2node( w, node->children[ i ] );
		}
		if (u->used == BRANCHING_SIZE) {
			_hx_btree_node_split_child( w, node, i, u );
			if (key > node->keys[i]) {
				uint64_t id	= node->children[i+1];
				u	= _hx_btree_int2node( w, id );
			}
		}
		_hx_btree_insert_nonfull( w, u, key, value );
	}
	return 0;
}

hx_btree_node* _hx_btree_int2node ( hx_btree_world* w, uint64_t id ) {
	if (!(w->flags & HX_BTREE_MEMORY)) {
		fprintf( stderr, "*** file-based btrees not implemented yet\n" );
		exit(1);
	} else {
		return (hx_btree_node*) id;
	}
}

uint64_t _hx_btree_node2int ( hx_btree_world* w, hx_btree_node* node ) {
	if (!(w->flags & HX_BTREE_MEMORY)) {
		fprintf( stderr, "*** file-based btrees not implemented yet\n" );
		exit(1);
	} else {
		return (uint64_t) node;
	}
}

void hx_btree_traverse ( hx_btree_world* w, hx_btree_node* node, hx_btree_node_visitor* before, hx_btree_node_visitor* after, int level ) {
	if (before != NULL) before( w, node, level );
	if (!hx_btree_node_has_flag( w, node, HX_BTREE_NODE_LEAF )) {
		for (int i = 0; i < node->used; i++) {
			hx_btree_node* c	= _hx_btree_int2node( w, node->children[i] );
			hx_btree_traverse( w, c, before, after, level + 1 );
		}
	}
	if (after != NULL) after( w, node, level );
}

void _hx_btree_debug_leaves (hx_btree_world* w, hx_btree_node* node, int level) {
	if (hx_btree_node_has_flag( w, node, HX_BTREE_NODE_LEAF )) {
		fprintf( stderr, "LEVEL %d\n", level );
		hx_btree_node_debug( w, node );
	}
}
