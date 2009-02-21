#include <unistd.h>
#include "vector.h"
#include "tap.h"

void vector_test ( void );
void vector_iter_test ( void );

int main ( void ) {
	plan_tests(24);
	vector_test();
	vector_iter_test();
	return exit_status();
}

void vector_test ( void ) {
	hx_vector* v	= hx_new_vector();
	ok1( v != NULL );
	
	for (int i = 1; i <= 10; i++) {
		hx_terminal* t	= hx_new_terminal();
		for (int j = 1; j <= i; j++) {
			hx_terminal_add_node( t, (hx_node_id) j );
		}
		hx_vector_add_terminal( v, (hx_node_id) i, t );
	}
	
	hx_terminal* t	= hx_vector_get_terminal(v, (hx_node_id) 3 );
	ok1( t != NULL );
	ok1( hx_terminal_size( t ) == 3 );
	
	t	= hx_vector_get_terminal(v, (hx_node_id) 12 );
	ok1( t == NULL );
	
	hx_free_vector(v);
}

void vector_iter_test ( void ) {
	hx_vector* v	= hx_new_vector();
	for (int i = 1; i <= 10; i++) {
		hx_terminal* t	= hx_new_terminal();
		for (int j = i; j > 0; j--) {
			hx_terminal_add_node( t, (hx_node_id) j );
		}
		hx_vector_add_terminal( v, (hx_node_id) i, t );
	}
	hx_vector_iter* iter	= hx_vector_new_iter( v );
	ok1( iter != NULL );
	
	int counter	= 0;
	hx_node_id last, cur;
	while (!hx_vector_iter_finished(iter)) {
		hx_terminal* t;
		hx_vector_iter_current( iter, &cur, &t );
		if (counter > 0) {
			ok1( cur > last );
		}
		ok1( hx_terminal_size(t) == (int) cur );
		last	= cur;
		counter++;
		hx_vector_iter_next(iter);
	}
	
	hx_free_vector_iter( iter );
	hx_free_vector(v);
}
