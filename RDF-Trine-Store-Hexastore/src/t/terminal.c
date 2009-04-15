#include <unistd.h>
#include "terminal.h"
#include "tap.h"

void terminal_test ( void );
void terminal_iter_test ( void );

int main ( void ) {
	plan_tests(113);
	terminal_test();
	terminal_iter_test();
	return exit_status();
}

void terminal_test ( void ) {
	hx_storage_manager* st	= hx_new_memory_storage_manager();
	hx_terminal* t	= hx_new_terminal( st );
	ok1( t != NULL );
	
	ok1( hx_terminal_size(t, st) == 0 );
	ok1( hx_terminal_add_node(t, st, (hx_node_id) 1 ) == 0 );
	ok1( hx_terminal_size(t, st) == 1 );
	ok1( hx_terminal_add_node(t, st, (hx_node_id) 1 ) == 1 );
	ok1( hx_terminal_size(t, st) == 1 );
	ok1( hx_terminal_contains_node( t, st, (hx_node_id) 1 ) == 1 );
	ok1( hx_terminal_contains_node( t, st, (hx_node_id) 2 ) == 0 );
	
	for (int i = 5000; i > 0; i--) {
		hx_terminal_add_node(t, st, (hx_node_id) i );
	}
	ok1( hx_terminal_size(t, st) == 5000 );
	
	ok1( hx_terminal_contains_node( t, st, (hx_node_id) 5000 ) == 1 );
	ok1( hx_terminal_contains_node( t, st, (hx_node_id) 5001 ) == 0 );
	
	for (int i = 1; i <= 5000; i++) {
		hx_terminal_remove_node(t, st, (hx_node_id) i );
	}
	
	ok1( hx_terminal_size(t, st) == 0 );
	
	hx_free_terminal(t, st);
	hx_free_storage_manager( st );
}

void terminal_iter_test ( void ) {
	hx_storage_manager* st	= hx_new_memory_storage_manager();
	hx_terminal* t	= hx_new_terminal( st );
	for (int i = 200; i > 0; i -= 2) {
		hx_terminal_add_node(t, st, (hx_node_id) i );
	}
	
	hx_terminal_iter* iter	= hx_terminal_new_iter( t, st );
	ok1( iter != NULL );
	
	int counter	= 0;
	hx_node_id last, cur;
	while (!hx_terminal_iter_finished(iter)) {
		hx_terminal_iter_current( iter, &cur );
		if (counter > 0) {
			ok1( last < cur );
		}
		last	= cur;
		counter++;
		hx_terminal_iter_next(iter);
	}
	ok1( counter == 100 );
	
	hx_free_terminal_iter( iter );
	hx_free_terminal(t, st);
	hx_free_storage_manager( st );
}
