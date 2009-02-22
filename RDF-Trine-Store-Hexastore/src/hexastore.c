#include "hexastore.h"

// #define DEBUG_INDEX_SELECTION


void* _hx_add_triple_threaded (void* arg);
int _hx_iter_vb_finished ( void* iter );
int _hx_iter_vb_current ( void* iter, void* results );
int _hx_iter_vb_next ( void* iter );	
int _hx_iter_vb_free ( void* iter );
int _hx_iter_vb_size ( void* iter );
int _hx_iter_vb_sorted_by (void* iter, int index );
char** _hx_iter_vb_names ( void* iter );
int _hx_add_triple( hx_hexastore* hx, hx_node_id s, hx_node_id p, hx_node_id o );

/////////////////////

hx_hexastore* hx_new_hexastore ( void ) {
	hx_nodemap* map	= hx_new_nodemap();
	return hx_new_hexastore_with_nodemap( map );
}

hx_hexastore* hx_new_hexastore_with_nodemap ( hx_nodemap* map ) {
	hx_hexastore* hx	= (hx_hexastore*) calloc( 1, sizeof( hx_hexastore ) );
	hx->map			= map;
	hx->spo			= hx_new_index( HX_INDEX_ORDER_SPO );
	hx->sop			= hx_new_index( HX_INDEX_ORDER_SOP );
	hx->pso			= hx_new_index( HX_INDEX_ORDER_PSO );
	hx->pos			= hx_new_index( HX_INDEX_ORDER_POS );
	hx->osp			= hx_new_index( HX_INDEX_ORDER_OSP );
	hx->ops			= hx_new_index( HX_INDEX_ORDER_OPS );
	hx->next_var	= -1;
	return hx;
}

int hx_free_hexastore ( hx_hexastore* hx ) {
	hx_free_nodemap( hx->map );
	hx_free_index( hx->spo );
	hx_free_index( hx->sop );
	hx_free_index( hx->pso );
	hx_free_index( hx->pos );
	hx_free_index( hx->osp );
	hx_free_index( hx->ops );
	free( hx );
	return 0;
}

hx_nodemap* hx_get_nodemap ( hx_hexastore* hx ) {
	return hx->map;
}

int hx_add_triple( hx_hexastore* hx, hx_node* sn, hx_node* pn, hx_node* on ) {
	hx_nodemap* map	= hx->map;
	hx_node_id s	= hx_nodemap_add_node( map, sn );
	hx_node_id p	= hx_nodemap_add_node( map, pn );
	hx_node_id o	= hx_nodemap_add_node( map, on );
	return _hx_add_triple( hx, s, p, o );
}

int _hx_add_triple( hx_hexastore* hx, hx_node_id s, hx_node_id p, hx_node_id o ) {
	hx_terminal* t;
	{
		int added	= hx_index_add_triple_terminal( hx->spo, s, p, o, &t );
		hx_index_add_triple_with_terminal( hx->pso, t, s, p, o, added );
	}

	{
		int added	= hx_index_add_triple_terminal( hx->sop, s, p, o, &t );
		hx_index_add_triple_with_terminal( hx->osp, t, s, p, o, added );
	}
	
	{
		int added	= hx_index_add_triple_terminal( hx->pos, s, p, o, &t );
		hx_index_add_triple_with_terminal( hx->ops, t, s, p, o, added );
	}
	
	return 0;
}

int hx_add_triples( hx_hexastore* hx, hx_triple* triples, int count ) {
	if (count < THREADED_BATCH_SIZE) {
		for (int i = 0; i < count; i++) {
			hx_add_triple( hx, triples[i].subject, triples[i].predicate, triples[i].object );
		}
	} else {
		hx_triple_id triple_ids[ count ];
		for (int i = 0; i < count; i++) {
			triple_ids[i].subject	= hx_nodemap_add_node( hx->map, triples[i].subject );
			triple_ids[i].predicate	= hx_nodemap_add_node( hx->map, triples[i].predicate );
			triple_ids[i].object	= hx_nodemap_add_node( hx->map, triples[i].object );
		}
		
		pthread_t threads[3];
		hx_thread_info tinfo[3];
		for (int i = 0; i < 3; i++) {
			tinfo[i].hx			= hx;
			tinfo[i].count		= count;
			tinfo[i].triples	= triple_ids;
		}
		
		{
			tinfo[0].index		= hx->spo;
			tinfo[0].secondary	= hx->pso;
			
			tinfo[1].index		= hx->sop;
			tinfo[1].secondary	= hx->osp;
			
			tinfo[2].index		= hx->pos;
			tinfo[2].secondary	= hx->ops;
			
			for (int i = 0; i < 3; i++) {
				pthread_create(&(threads[i]), NULL, _hx_add_triple_threaded, &( tinfo[i] ));
			}
			for (int i = 0; i < 3; i++) {
				pthread_join(threads[i], NULL);
			}
		}
	}
	return 0;
}

void* _hx_add_triple_threaded (void* arg) {
	hx_thread_info* tinfo	= (hx_thread_info*) arg;
	for (int i = 0; i < tinfo->count; i++) {
		hx_node_id s	= tinfo->triples[i].subject;
		hx_node_id p	= tinfo->triples[i].predicate;
		hx_node_id o	= tinfo->triples[i].object;
		hx_terminal* t;
		int added	= hx_index_add_triple_terminal( tinfo->index, s, p, o, &t );
		hx_index_add_triple_with_terminal( tinfo->secondary, t, s, p, o, added );
	}
	return NULL;
}

int hx_remove_triple( hx_hexastore* hx, hx_node* sn, hx_node* pn, hx_node* on ) {
	hx_node_id s	= hx_get_node_id( hx, sn );
	hx_node_id p	= hx_get_node_id( hx, pn );
	hx_node_id o	= hx_get_node_id( hx, on );
	hx_index_remove_triple( hx->spo, s, p, o );
	hx_index_remove_triple( hx->sop, s, p, o );
	hx_index_remove_triple( hx->pso, s, p, o );
	hx_index_remove_triple( hx->pos, s, p, o );
	hx_index_remove_triple( hx->osp, s, p, o );
	hx_index_remove_triple( hx->ops, s, p, o );
	return 0;
}

int hx_get_ordered_index( hx_hexastore* hx, hx_node* sn, hx_node* pn, hx_node* on, int order_position, hx_index** index, hx_node** nodes ) {
	int i		= 0;
	int vars	= 0;
	hx_node_id s	= hx_get_node_id( hx, sn );
	hx_node_id p	= hx_get_node_id( hx, pn );
	hx_node_id o	= hx_get_node_id( hx, on );

#ifdef DEBUG_INDEX_SELECTION
	fprintf( stderr, "triple: { %d, %d, %d }\n", (int) s, (int) p, (int) o );
#endif
	int used[3]	= { 0, 0, 0 };
	hx_node_id triple_id[3]	= { s, p, o };
	hx_node* triple[3]		= { sn, pn, on };
	int index_order[3]		= { 0xdeadbeef, 0xdeadbeef, 0xdeadbeef };
	char* pnames[3]			= { "SUBJECT", "PREDICATE", "OBJECT" };
	
	if (s > (hx_node_id) 0) {
#ifdef DEBUG_INDEX_SELECTION
		fprintf( stderr, "- bound subject\n" );
#endif
		index_order[ i++ ]	= HX_SUBJECT;
		used[ HX_SUBJECT ]++;
	} else if (s < (hx_node_id) 0) {
		vars++;
	}
	if (p > (hx_node_id) 0) {
#ifdef DEBUG_INDEX_SELECTION
		fprintf( stderr, "- bound predicate\n" );
#endif
		index_order[ i++ ]	= HX_PREDICATE;
		used[ HX_PREDICATE ]++;
	} else if (p < (hx_node_id) 0) {
		vars++;
	}
	if (o > (hx_node_id) 0) {
#ifdef DEBUG_INDEX_SELECTION
		fprintf( stderr, "- bound object\n" );
#endif
		index_order[ i++ ]	= HX_OBJECT;
		used[ HX_OBJECT ]++;
	} else if (o < (hx_node_id) 0) {
		vars++;
	}
	
#ifdef DEBUG_INDEX_SELECTION
	fprintf( stderr, "index order: { %d, %d, %d }\n", (int) index_order[0], (int) index_order[1], (int) index_order[2] );
#endif
	if (i < 3 && !(used[order_position]) && triple_id[order_position] != (hx_node_id) 0) {
#ifdef DEBUG_INDEX_SELECTION
		fprintf( stderr, "requested ordering position: %s\n", pnames[order_position] );
#endif
		index_order[ i++ ]	= order_position;
		used[order_position]++;
	}
#ifdef DEBUG_INDEX_SELECTION
	fprintf( stderr, "index order: { %d, %d, %d }\n", (int) index_order[0], (int) index_order[1], (int) index_order[2] );
#endif	
	// check for any duplicated variables. if they haven't been added to the index order, add them now:
	for (int j = 0; j < 3; j++) {
		if (!(used[j])) {
			int current_chosen	= i;
//			fprintf( stderr, "checking if %s (%d) matches already chosen nodes:\n", pnames[j], (int) triple_id[j] );
			for (int k = 0; k < current_chosen; k++) {
//				fprintf( stderr, "- %s (%d)?\n", pnames[k], triple_id[ index_order[k] ] );
				if (triple_id[index_order[k]] == triple_id[j] && triple_id[j] != (hx_node_id) 0) {
//					fprintf( stderr, "*** MATCHED\n" );
					if (i < 3) {
						index_order[ i++ ]	= j;
						used[ j ]++;
					}
				}
			}
		}
	}
	
	// add any remaining triple positions to the index order:
	if (i == 0) {
		for (int j = 0; j < 3; j++) {
			if (j != order_position) {
				index_order[ i++ ]	= j;
			}
		}
	} else if (i == 1) {
		for (int j = 0; j < 3; j++) {
			if (j != order_position && !(used[j])) {
				index_order[ i++ ]	= j;
			}
		}
	} else if (i == 2) {
		for (int j = 0; j < 3; j++) {
			if (!(used[j])) {
				index_order[ i++ ]	= j;
			}
		}
	}
	
	switch (index_order[0]) {
		case 0:
			switch (index_order[1]) {
				case 1:
#ifdef DEBUG_INDEX_SELECTION
					fprintf( stderr, "using spo index\n" );
#endif
					*index	= hx->spo;
					break;
				case 2:
#ifdef DEBUG_INDEX_SELECTION
					fprintf( stderr, "using sop index\n" );
#endif
					*index	= hx->sop;
					break;
			}
			break;
		case 1:
			switch (index_order[1]) {
				case 0:
#ifdef DEBUG_INDEX_SELECTION
					fprintf( stderr, "using pso index\n" );
#endif
					*index	= hx->pso;
					break;
				case 2:
#ifdef DEBUG_INDEX_SELECTION
					fprintf( stderr, "using pos index\n" );
#endif
					*index	= hx->pos;
					break;
			}
			break;
		case 2:
			switch (index_order[1]) {
				case 0:
#ifdef DEBUG_INDEX_SELECTION
					fprintf( stderr, "using osp index\n" );
#endif
					*index	= hx->osp;
					break;
				case 1:
#ifdef DEBUG_INDEX_SELECTION
					fprintf( stderr, "using ops index\n" );
#endif
					*index	= hx->ops;
					break;
			}
			break;
	}
	
	hx_node* triple_ordered[3]	= { sn, pn, on };
	nodes[0]	= triple_ordered[ (*index)->order[0] ];
	nodes[1]	= triple_ordered[ (*index)->order[1] ];
	nodes[2]	= triple_ordered[ (*index)->order[2] ];
	return 0;
}

hx_index_iter* hx_get_statements( hx_hexastore* hx, hx_node* sn, hx_node* pn, hx_node* on, int order_position ) {
	hx_node* index_ordered[3];
	hx_index* index;
	hx_get_ordered_index( hx, sn, pn, on, order_position, &index, index_ordered );
	
	hx_node_id s	= hx_get_node_id( hx, sn );
	hx_node_id p	= hx_get_node_id( hx, pn );
	hx_node_id o	= hx_get_node_id( hx, on );
	hx_node_id index_ordered_id[3]	= { s, p, o };
	hx_index_iter* iter	= hx_index_new_iter1( index, index_ordered_id[0], index_ordered_id[1], index_ordered_id[2] );
	return iter;
}

uint64_t hx_triples_count ( hx_hexastore* hx ) {
	hx_index* i	= hx->spo;
	return hx_index_triples_count( i );
}

int hx_write( hx_hexastore* h, FILE* f ) {
	fputc( 'X', f );
	if (hx_nodemap_write( h->map, f ) != 0) {
		fprintf( stderr, "*** Error while writing hexastore nodemap to disk.\n" );
		return 1;
	}
	if ((
		(hx_index_write( h->spo, f )) ||
		(hx_index_write( h->sop, f )) ||
		(hx_index_write( h->pso, f )) ||
		(hx_index_write( h->pos, f )) ||
		(hx_index_write( h->osp, f )) ||
		(hx_index_write( h->ops, f ))
		) != 0) {
		fprintf( stderr, "*** Error while writing hexastore indices to disk.\n" );
		return 1;
	} else {
		return 0;
	}
}

hx_hexastore* hx_read( FILE* f, int buffer ) {
	size_t read;
	int c	= fgetc( f );
	if (c != 'X') {
		fprintf( stderr, "*** Bad header cookie trying to read hexastore from file.\n" );
		return NULL;
	}
	hx_hexastore* hx	= (hx_hexastore*) calloc( 1, sizeof( hx_hexastore ) );
	hx->map	= hx_nodemap_read( f, buffer );
	if (hx->map == NULL) {
		fprintf( stderr, "*** NULL nodemap returned while trying to read hexastore from disk.\n" );
		free( hx );
		return NULL;
	}
	
	hx->next_var	= -1;
	hx->spo	= hx_index_read( f, buffer );
	hx->sop	= hx_index_read( f, buffer );
	hx->pso	= hx_index_read( f, buffer );
	hx->pos	= hx_index_read( f, buffer );
	hx->osp	= hx_index_read( f, buffer );
	hx->ops	= hx_index_read( f, buffer );
	if ((hx->spo == NULL) || (hx->spo == NULL) || (hx->spo == NULL) || (hx->spo == NULL) || (hx->spo == NULL) || (hx->spo == NULL)) {
		fprintf( stderr, "*** NULL index returned while trying to read hexastore from disk.\n" );
		free( hx );
		return NULL;
	} else {
		return hx;
	}
}

hx_variablebindings_iter* hx_new_iter_variablebindings ( hx_index_iter* i, char* subj_name, char* pred_name, char* obj_name ) {
	hx_variablebindings_iter_vtable* vtable	= malloc( sizeof( hx_variablebindings_iter_vtable ) );
	vtable->finished	= _hx_iter_vb_finished;
	vtable->current		= _hx_iter_vb_current;
	vtable->next		= _hx_iter_vb_next;
	vtable->free		= _hx_iter_vb_free;
	vtable->names		= _hx_iter_vb_names;
	vtable->size		= _hx_iter_vb_size;
	vtable->sorted_by	= _hx_iter_vb_sorted_by;
	
	int size	= 0;
	if (subj_name != NULL)
		size++;
	if (pred_name != NULL)
		size++;
	if (obj_name != NULL)
		size++;
	
	_hx_iter_vb_info* info			= (_hx_iter_vb_info*) calloc( 1, sizeof( _hx_iter_vb_info ) );
	info->size						= size;
	info->subject					= subj_name;
	info->predicate					= pred_name;
	info->object					= obj_name;
	info->iter						= i;
	info->names						= (char**) calloc( size, sizeof( char* ) );
	info->triple_pos_to_index		= (int*) calloc( size, sizeof( int ) );
	info->index_to_triple_pos		= (int*) calloc( size, sizeof( int ) );
	int j	= 0;
	if (subj_name != NULL) {
		int idx	= j++;
		info->names[ idx ]		= subj_name;
		info->triple_pos_to_index[ idx ]	= 0;
		info->index_to_triple_pos[ 0 ]		= idx;
	}
	
	if (pred_name != NULL) {
		int idx	= j++;
		info->names[ idx ]		= pred_name;
		info->triple_pos_to_index[ idx ]	= 1;
		info->index_to_triple_pos[ 1 ]		= idx;
	}
	if (obj_name != NULL) {
		int idx	= j++;
		info->names[ idx ]		= obj_name;
		info->triple_pos_to_index[ idx ]	= 2;
		info->index_to_triple_pos[ 2 ]		= idx;
	}
	
	hx_variablebindings_iter* iter	= hx_variablebindings_new_iter( vtable, (void*) info );
	return iter;
}

int _hx_iter_vb_finished ( void* data ) {
	_hx_iter_vb_info* info	= (_hx_iter_vb_info*) data;
	hx_index_iter* iter		= (hx_index_iter*) info->iter;
	return hx_index_iter_finished( iter );
}

int _hx_iter_vb_current ( void* data, void* results ) {
	_hx_iter_vb_info* info	= (_hx_iter_vb_info*) data;
	hx_index_iter* iter		= (hx_index_iter*) info->iter;
	hx_node_id triple[3];
	hx_index_iter_current ( iter, &(triple[0]), &(triple[1]), &(triple[2]) );
	hx_node_id* values	= calloc( info->size, sizeof( hx_node_id ) );
	for (int i = 0; i < info->size; i++) {
		values[ i ]	= triple[ info->triple_pos_to_index[ i ] ];
	}
	hx_variablebindings** bindings	= (hx_variablebindings**) results;
	*bindings	= hx_new_variablebindings( info->size, info->names, values );
	return 0;
}

int _hx_iter_vb_next ( void* data ) {
	_hx_iter_vb_info* info	= (_hx_iter_vb_info*) data;
	hx_index_iter* iter		= (hx_index_iter*) info->iter;
	return hx_index_iter_next( iter );
}

int _hx_iter_vb_free ( void* data ) {
	_hx_iter_vb_info* info	= (_hx_iter_vb_info*) data;
	hx_index_iter* iter		= (hx_index_iter*) info->iter;
	return hx_free_index_iter( iter );
	free( info->names );
	free( info->triple_pos_to_index );
	free( info );
}

int _hx_iter_vb_size ( void* data ) {
	_hx_iter_vb_info* info	= (_hx_iter_vb_info*) data;
	return info->size;
}

char** _hx_iter_vb_names ( void* data ) {
	_hx_iter_vb_info* info	= (_hx_iter_vb_info*) data;
	return info->names;
}

int _hx_iter_vb_sorted_by (void* data, int index ) {
	_hx_iter_vb_info* info	= (_hx_iter_vb_info*) data;
	int triple_pos	= info->index_to_triple_pos[ index ];
// 	fprintf( stderr, "*** checking if index iterator is sorted by %d (triple %s)\n", index, HX_POSITION_NAMES[triple_pos] );
	return hx_index_iter_is_sorted_by_index( info->iter, triple_pos );
}

hx_node_id hx_get_node_id ( hx_hexastore* hx, hx_node* node ) {
	if (node == NULL) {
		return (hx_node_id) 0;
	}
	hx_node_id id;
	hx_nodemap* map	= hx->map;
	if (hx_node_is_variable( node )) {
		id	= hx_node_number( node );
	} else {
		id	= hx_nodemap_get_node_id( map, node );
	}
	return id;
}

hx_node* hx_new_variable ( hx_hexastore* hx ) {
	int v	= hx->next_var--;
	hx_node* n	= hx_new_node_variable( v );
	return n;
}
