#include "btree.h"
#include <assert.h>

void _hx_btree_debug_leaves (hx_btree_world* w, hx_btree_node* node, int level, void* param);
void _hx_btree_count ( hx_btree_world* w, hx_btree_node* node, int level, void* param );
int _hx_btree_binary_search ( const hx_btree_node* node, const hx_node_id n, int* index );
hx_btree_node* _hx_btree_int2node ( hx_btree_world* w, uint64_t id );
uint64_t _hx_btree_node2int ( hx_btree_world* w, hx_btree_node* node );
int _hx_btree_insert_nonfull( hx_btree_world* w, hx_btree_node* root, hx_node_id key, uint64_t value );
int _hx_btree_node_split_child( hx_btree_world* w, hx_btree_node* parent, uint32_t index, hx_btree_node* child );
int _hx_btree_iter_prime ( hx_btree_iter* iter );
hx_btree_node* _hx_btree_search_page ( hx_btree_world* w, hx_btree_node* root, hx_node_id key );

hx_btree_world* hx_new_btree_world ( uint32_t flags ) {
	hx_btree_world* w	= (hx_btree_world*) calloc( 1, sizeof( hx_btree_world ) );
	w->flags			= flags;
	return w;
}

int hx_free_btree_world ( hx_btree_world* w ) {
	free( w );
	return 0;
}

hx_btree_node* hx_new_btree_root ( hx_btree_world* w ) {
	hx_btree_node* root	= hx_new_btree_node( w );
	hx_btree_node_set_flag( w, root, HX_BTREE_NODE_ROOT );
	hx_btree_node_set_flag( w, root, HX_BTREE_NODE_LEAF );
	return root;
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

list_size_t hx_btree_size ( hx_btree_world* w, hx_btree_node* node ) {
	list_size_t count	= 0;
	hx_btree_traverse( w, node, _hx_btree_count, NULL, 0, &count );
	return count;
}

int hx_btree_node_set_parent ( hx_btree_world* w, hx_btree_node* node, hx_btree_node* parent ) {
	uint64_t id	= _hx_btree_node2int( w, parent );
	node->parent	= id;
	return 0;
}

int hx_btree_node_set_prev_neighbor ( hx_btree_world* w, hx_btree_node* node, hx_btree_node* prev ) {
	node->prev	= _hx_btree_node2int( w, prev );
	return 0;
}

int hx_btree_node_set_next_neighbor ( hx_btree_world* w, hx_btree_node* node, hx_btree_node* next ) {
	node->next	= _hx_btree_node2int( w, next );
	return 0;
}

hx_btree_node* hx_btree_node_next_neighbor ( hx_btree_world* w, hx_btree_node* node ) {
	return _hx_btree_int2node( w, node->next );
}

hx_btree_node* hx_btree_node_prev_neighbor ( hx_btree_world* w, hx_btree_node* node ) {
	return _hx_btree_int2node( w, node->prev );
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

int hx_btree_node_debug ( char* string, hx_btree_world* w, hx_btree_node* node ) {
	fprintf( stderr, "%sNode %d (%p):\n", string, (int) _hx_btree_node2int(w,node), (void*) node );
	fprintf( stderr, "%s\tUsed: [%d/%d]\n", string, node->used, BRANCHING_SIZE );
	fprintf( stderr, "%s\tFlags: ", string );
	if (node->flags & HX_BTREE_NODE_ROOT)
		fprintf( stderr, "HX_BTREE_NODE_ROOT " );
	if (node->flags & HX_BTREE_NODE_LEAF)
		fprintf( stderr, "HX_BTREE_NODE_LEAF" );
	fprintf( stderr, "\n" );
	for (int i = 0; i < node->used; i++) {
		fprintf( stderr, "%s\t- %d -> %d\n", string, (int) node->keys[i], (int) node->children[i] );
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
	hx_btree_node* u	= _hx_btree_search_page( w, root, key );
	int i;
	int r	= _hx_btree_binary_search( u, key, &i );
	if (r == 0) {
		return u->children[i];
	} else {
		return 0;
	}
}

hx_btree_node* _hx_btree_search_page ( hx_btree_world* w, hx_btree_node* root, hx_node_id key ) {
	hx_btree_node* u	= root;
	while (!hx_btree_node_has_flag(w, u, HX_BTREE_NODE_LEAF)) {
//		fprintf( stderr, "node is not a leaf... (flags: %x)\n", u->flags );
		for (int i = 0; i < u->used - 1; i++) {
			if (key <= u->keys[i]) {
				uint64_t id	= u->children[i];
//				fprintf( stderr, "descending to child %d\n", (int) id );
				u	= _hx_btree_int2node( w, id );
				goto NEXT;
			}
		}
//		fprintf( stderr, "decending to last child\n" );
		u	= _hx_btree_int2node( w, u->children[ u->used - 1 ] );
NEXT:	1;
	}
	
	return u;
}

int hx_btree_insert ( hx_btree_world* w, hx_btree_node** _root, hx_node_id key, uint64_t value ) {
	hx_btree_node* root	= *_root;
	if (root->used == BRANCHING_SIZE) {
		hx_btree_node* s	= hx_new_btree_node( w );
		{
			hx_btree_node_set_flag( w, s, HX_BTREE_NODE_ROOT );
			hx_btree_node_unset_flag( w, root, HX_BTREE_NODE_ROOT );
			hx_btree_node_set_parent( w, root, s );
			hx_node_id key	= root->keys[ BRANCHING_SIZE - 1 ];
			uint64_t rid	= _hx_btree_node2int( w, root );
			hx_btree_node_add_child( w, s, key, rid );
			_hx_btree_node_split_child( w, s, 0, root );
			*_root	= s;
		}
		return _hx_btree_insert_nonfull( w, s, key, value );
	} else {
		return _hx_btree_insert_nonfull( w, root, key, value );
	}
}

int _hx_btree_node_split_child( hx_btree_world* w, hx_btree_node* parent, uint32_t index, hx_btree_node* child ) {
	hx_btree_node* z	= hx_new_btree_node( w );
	hx_btree_node* next	= hx_btree_node_next_neighbor( w, child );
	hx_btree_node_set_prev_neighbor( w, z, child );
	hx_btree_node_set_next_neighbor( w, z, next );
	hx_btree_node_set_next_neighbor( w, child, z );
	if (next != NULL) {
		hx_btree_node_set_prev_neighbor( w, next, z );
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
		z->keys[j]		= child->keys[ child_index ];
		z->children[j]	= child->children[ child_index ];
		child_index++;
		z->used++;
		child->used--;
	}
	
	uint64_t cid	= _hx_btree_node2int( w, child );
	uint64_t zid	= _hx_btree_node2int( w, z );
	
	hx_node_id ckey	= child->keys[ child->used - 1 ];
	hx_node_id zkey	= z->keys[ z->used - 1 ];
	
	parent->keys[index]	= ckey;
	hx_btree_node_add_child( w, parent, zkey, zid );
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
				u	= _hx_btree_int2node( w, node->children[i+1] );
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

void hx_btree_traverse ( hx_btree_world* w, hx_btree_node* node, hx_btree_node_visitor* before, hx_btree_node_visitor* after, int level, void* param ) {
	if (before != NULL) before( w, node, level, param );
	if (!hx_btree_node_has_flag( w, node, HX_BTREE_NODE_LEAF )) {
		for (int i = 0; i < node->used; i++) {
			hx_btree_node* c	= _hx_btree_int2node( w, node->children[i] );
			hx_btree_traverse( w, c, before, after, level + 1, param );
		}
	}
	if (after != NULL) after( w, node, level, after );
}

void _hx_btree_debug_leaves ( hx_btree_world* w, hx_btree_node* node, int level, void* param ) {
	if (hx_btree_node_has_flag( w, node, HX_BTREE_NODE_LEAF )) {
		fprintf( stderr, "LEVEL %d\n", level );
		hx_btree_node_debug( "", w, node );
	}
}

void _hx_btree_count ( hx_btree_world* w, hx_btree_node* node, int level, void* param ) {
	list_size_t* count	= (list_size_t*) param;
	if (hx_btree_node_has_flag( w, node, HX_BTREE_NODE_LEAF )) {
		*count	+= node->used;
	}
}

hx_btree_iter* hx_btree_new_iter ( hx_btree_world* w, hx_btree_node* root ) {
	hx_btree_iter* iter	= (hx_btree_iter*) calloc( 1, sizeof( hx_btree_iter ) );
	iter->world		= w;
	iter->started	= 0;
	iter->finished	= 0;
	iter->root		= root;
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
	hx_btree_node* p	= iter->root;
	while (!hx_btree_node_has_flag(iter->world, p, HX_BTREE_NODE_LEAF)) {
		if (p->used > 0) {
			p	= _hx_btree_int2node( iter->world, p->children[0] );
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
	*n	= iter->page->keys[ iter->index ];
	*v	= iter->page->children[ iter->index ];
	return 0;
}

int hx_btree_iter_next ( hx_btree_iter* iter ) {
	iter->index++;
	if (iter->index >= iter->page->used) {
		iter->page	= hx_btree_node_next_neighbor( iter->world, iter->page );
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
	
	hx_btree_node* u	= _hx_btree_search_page( iter->world, iter->root, key );
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


