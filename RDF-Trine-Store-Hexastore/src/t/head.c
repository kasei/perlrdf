#include <unistd.h>
#include "head.h"
#include "tap.h"

void head_test ( void );
void head_iter_test1 ( void );
void head_iter_test2 ( void );
void head_iter_test3 ( void );
hx_vector* _new_vector ( hx_storage_manager* st, int n );

int main ( void ) {
	plan_tests(28);
	head_test();
	head_iter_test1();
	head_iter_test2();
	head_iter_test3();
	return exit_status();
}

void head_test ( void ) {
	hx_storage_manager* st	= hx_new_memory_storage_manager();
	hx_head* h	= hx_new_head( st );
	ok1( h != NULL );
	
	for (int i = 1; i <= 10; i++) {
		hx_vector* v	= _new_vector( st, i );
		hx_head_add_vector( h, st, (hx_node_id) i, v );
	}
	
	{
		hx_vector* v	= hx_head_get_vector( h, st, (hx_node_id) 4 );
		ok1( 14 == (int) hx_vector_size(v) );
	}
	
	{
		hx_vector* v	= hx_head_get_vector( h, st, (hx_node_id) 8 );
		ok1( 18 == (int) hx_vector_size(v) );
	}
	
	hx_free_head(h, st);
}

void head_iter_test1 ( void ) {
	hx_storage_manager* st	= hx_new_memory_storage_manager();
	hx_head* h	= hx_new_head( st );
	for (int i = 1; i <= 10; i++) {
		hx_vector* v	= _new_vector( st, i );
		hx_head_add_vector( h, st, (hx_node_id) i, v );
	}
	hx_head_iter* iter	= hx_head_new_iter( h, st );
	ok1( iter != NULL );
	
	int counter	= 0;
	hx_node_id last, cur;
	while (!hx_head_iter_finished(iter)) {
		hx_vector* v;
		hx_head_iter_current( iter, &cur, &v );
		if (counter > 0) {
			ok1( cur > last );
		}
		ok1( hx_vector_size(v) == (int) cur + 10 );
		last	= cur;
		counter++;
		hx_head_iter_next(iter);
	}
	
	ok1( counter == 10 );
	hx_free_head_iter( iter );
	hx_free_head(h, st);
}

void head_iter_test2 ( void ) {
	hx_storage_manager* st	= hx_new_memory_storage_manager();
	hx_head* h	= hx_new_head( st );
	for (int i = 1; i <= 10; i++) {
		hx_vector* v	= _new_vector( st, i );
		hx_head_add_vector( h, st, (hx_node_id) i, v );
	}
	hx_head_iter* iter	= hx_head_new_iter( h, st );
	ok1( hx_head_iter_seek( iter, (hx_node_id) 7 ) == 0);
	int counter	= 0;
	while (!hx_head_iter_finished(iter)) {
		counter++;
		hx_head_iter_next(iter);
	}
	
	ok1( counter == 4 );
	hx_free_head_iter( iter );
	hx_free_head(h, st);
}

void head_iter_test3 ( void ) {
	hx_storage_manager* st	= hx_new_memory_storage_manager();
	hx_head* h	= hx_new_head( st );
	for (int i = 2; i <= 10; i+=2) {
		hx_vector* v	= _new_vector( st, i );
		hx_head_add_vector( h, st, (hx_node_id) i, v );
	}
	hx_head_iter* iter	= hx_head_new_iter( h, st );
	ok1( hx_head_iter_seek( iter, (hx_node_id) 7 ) != 0);
	int counter	= 0;
	while (!hx_head_iter_finished(iter)) {
		counter++;
		hx_head_iter_next(iter);
	}
	
	ok1( counter == 2 );
	
	hx_free_head_iter( iter );
	hx_free_head(h, st);
}

hx_vector* _new_vector ( hx_storage_manager* st, int n ) {
	hx_vector* v	= hx_new_vector( st );
	for (int i = 1; i <= 10+n; i++) {
		hx_terminal* t	= hx_new_terminal( st );
		for (int j = 1; j <= i; j++) {
			hx_terminal_add_node( t, (hx_node_id) j );
		}
		hx_vector_add_terminal( v, (hx_node_id) i, t );
	}
	return v;
}
