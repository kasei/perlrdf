#include "index.h"
#include "tap.h"

void spo_test1 ( void );
void spo_test2 ( void );
void pos_iter_test1 ( void );
void spo_iter_test1 ( void );
void pso_iter1_test1 ( void );
void shared_terminal_test ( void );

int main ( void ) {
	plan_tests(136);
	
	spo_test1();
	spo_test2();
	
	pos_iter_test1();
	spo_iter_test1();
	pso_iter1_test1();
	
	shared_terminal_test();
	
	return exit_status();
}

void spo_test1 ( void ) {
	hx_storage_manager* st	= hx_new_memory_storage_manager();
	hx_index* i	= hx_new_index( st, HX_INDEX_ORDER_SPO );
	ok1( i != NULL );
	
	hx_node_id s	= (hx_node_id) 1;
	hx_node_id p	= (hx_node_id) 2;
	hx_node_id o	= (hx_node_id) 3;
	
	ok1( hx_index_triples_count( i ) == 0 );
	ok1( hx_index_add_triple( i, s, p, o ) == 0 );
	ok1( hx_index_triples_count( i ) == 1 );
	ok1( hx_index_add_triple( i, s, p, o ) == 1 ); //adding duplicate triple returns non-zero
	
	o	= (hx_node_id) 4;
	ok1( hx_index_add_triple( i, s, p, o ) == 0 );
	ok1( hx_index_triples_count( i ) == 2 );
	ok1( hx_index_remove_triple( i, s, p, (hx_node_id) 3 ) == 0 );
	ok1( hx_index_triples_count( i ) == 1 );
	ok1( hx_index_remove_triple( i, s, p, (hx_node_id) 4 ) == 0 );
	ok1( hx_index_triples_count( i ) == 0 );
	
	hx_free_index(i);
	hx_free_storage_manager( st );
}

void spo_test2 ( void ) {
	hx_storage_manager* st	= hx_new_memory_storage_manager();
	hx_index* i	= hx_new_index( st, HX_INDEX_ORDER_SPO );
	hx_node_id s, p, o;
	s	= (hx_node_id) 1;
	for (p = 1; p <= 10; p++) {
		for (o = 1; o <= 100; o++) {
			hx_index_add_triple( i, s, p, o );
		}
	}
	ok1( hx_index_triples_count( i ) == 1000 );
	
	for (p = 1; p <= 10; p++) {
		for (o = 1; o <= 50; o++) {
			hx_index_remove_triple( i, s, p, o );
		}
	}
	ok1( hx_index_triples_count( i ) == 500 );
	fprintf( stderr, "*** index triples count: %d\n", (int) hx_index_triples_count( i ) );

	for (p = 1; p <= 10; p++) {
		for (o = 26; o <= 100; o++) {
			hx_index_add_triple( i, s, p, o );
		}
	}
	ok1( hx_index_triples_count( i ) == 750 );
	
	hx_free_index(i);
	hx_free_storage_manager( st );
}

void pos_iter_test1 ( void ) {
	hx_storage_manager* st	= hx_new_memory_storage_manager();
	hx_index* i	= hx_new_index( st, HX_INDEX_ORDER_POS );
	ok1( i != NULL );
	
	const int range	= 3;
	const int triples	= range * range * range;
	
	hx_node_id s, p, o;
	for (s = 1; s <= range; s++) {
		for (p = 1; p <= range; p++) {
			for (o = 1; o <= range; o++) {
				hx_index_add_triple( i, s, p, o );
			}
		}
	}
	ok1( hx_index_triples_count( i ) == triples );
	
	{
		hx_index_iter* iter	= hx_index_new_iter( i );
		int counter	= 0;
		ok1( iter != NULL );
		hx_node_id last_s, last_p, last_o;
		hx_node_id cur_s, cur_p, cur_o;
		while (!hx_index_iter_finished(iter)) {
			hx_index_iter_current( iter, &cur_s, &cur_p, &cur_o );
			if (counter > 0) {
				ok1( last_p <= cur_p );
				if (counter % range > 0) {
					ok1( last_o == cur_o );
				}
			}
			last_s	= cur_s;
			last_p	= cur_p;
			last_o	= cur_o;
			counter++;
			hx_index_iter_next(iter);
		}
		hx_free_index_iter( iter );
		ok1( counter == triples );
	}
	
	hx_free_index(i);
	hx_free_storage_manager( st );
}

void spo_iter_test1 ( void ) {
	hx_storage_manager* st	= hx_new_memory_storage_manager();
	hx_index* i	= hx_new_index( st, HX_INDEX_ORDER_SPO );
	ok1( i != NULL );
	
	const int range	= 3;
	const int triples	= range * range * range;
	
	hx_node_id s, p, o;
	for (s = 1; s <= range; s++) {
		for (p = 1; p <= range; p++) {
			for (o = 1; o <= range; o++) {
				hx_index_add_triple( i, s, p, o );
			}
		}
	}
	ok1( hx_index_triples_count( i ) == triples );
	
	{
		hx_index_iter* iter	= hx_index_new_iter( i );
		int counter	= 0;
		ok1( iter != NULL );
		hx_node_id last_s, last_p, last_o;
		hx_node_id cur_s, cur_p, cur_o;
		while (!hx_index_iter_finished(iter)) {
			hx_index_iter_current( iter, &cur_s, &cur_p, &cur_o );
			if (counter > 0) {
				ok1( last_s <= cur_s );
				if (counter % range > 0) {
					ok1( last_p == cur_p );
				}
			}
			last_s	= cur_s;
			last_p	= cur_p;
			last_o	= cur_o;
			counter++;
			hx_index_iter_next(iter);
		}
		hx_free_index_iter( iter );
		ok1( counter == triples );
	}
	
	hx_free_index(i);
	hx_free_storage_manager( st );
}

void pso_iter1_test1 ( void ) {
	diag( "hx_index_new_iter1" );
	hx_storage_manager* st	= hx_new_memory_storage_manager();
	hx_index* i	= hx_new_index( st, HX_INDEX_ORDER_PSO );
	ok1( i != NULL );
	
	const int range	= 3;
	const int triples	= range * range * range;
	
	hx_node_id s, p, o;
	for (int j = 0; j < 2; j++) {
		// duplicate adds should do nothing
		for (s = 1; s <= range; s++) {
			for (p = 1; p <= range; p++) {
				for (o = 1; o <= range; o++) {
					hx_index_add_triple( i, s, p, o );
				}
			}
		}
	}
	ok1( hx_index_triples_count( i ) == triples );
	
	const hx_node_id seek	= (hx_node_id) 2;
	hx_index_iter* iter	= hx_index_new_iter1( i, (hx_node_id) -1, seek, (hx_node_id) -2 );
	ok1( iter != NULL );
	hx_node_id last_s, last_p, last_o;
	hx_node_id cur_s, cur_p, cur_o;
	
	int counter	= 0;
	while (!hx_index_iter_finished(iter)) {
		hx_index_iter_current( iter, &cur_s, &cur_p, &cur_o );
		if (counter > 0) {
			ok1( last_s <= cur_s );
			if (counter % range > 0) {
				ok1( last_o <= cur_o );
			}
		}
		last_s	= cur_s;
		last_p	= cur_p;
		last_o	= cur_o;
		counter++;
		hx_index_iter_next(iter);
	}
	hx_free_index_iter( iter );
	ok1( counter == range * range );
	
	hx_free_index(i);
	hx_free_storage_manager( st );
}

void shared_terminal_test ( void ) {
	hx_storage_manager* st	= hx_new_memory_storage_manager();
	hx_index* spo	= hx_new_index( st, HX_INDEX_ORDER_SPO );
	hx_index* pso	= hx_new_index( st, HX_INDEX_ORDER_SPO );
	
	hx_node_id s	= (hx_node_id) 1;
	hx_node_id p	= (hx_node_id) 2;
	hx_node_id o	= (hx_node_id) 3;
	
	hx_terminal* t;
	ok1( hx_index_add_triple_terminal( spo, s, p, o, &t ) == 0 );
	ok1( t != NULL );
	ok1( hx_index_add_triple_with_terminal( pso, t, s, p, o, 0 ) == 0 );
	
	ok1( hx_index_triples_count( spo ) == 1 );
	ok1( hx_index_triples_count( pso ) == 1 );
	
	o	= (hx_node_id) 4;
	ok1( hx_index_add_triple( spo, s, p, o ) == 0 );
	ok1( hx_index_triples_count( spo ) == 2 );
	
	ok1( hx_index_add_triple( pso, s, p, o ) == 1 );	// should have already been added through the spo index
	
	hx_free_index(spo);
	hx_free_index(pso);
	hx_free_storage_manager( st );
}
