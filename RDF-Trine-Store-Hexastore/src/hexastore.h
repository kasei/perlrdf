#include <errno.h>
#include <stdio.h>
#include <stdint.h>
#include <sys/mman.h>
#include <fcntl.h>
#include <stdlib.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <string.h>
#include <unistd.h>

#define HEAD_LIST_ALLOC_SIZE				4096
#define VECTOR_LIST_ALLOC_SIZE				64
#define TERMINAL_LIST_ALLOC_SIZE			32

typedef uint64_t list_size_t;
typedef uint64_t rdf_node;

typedef struct {
	list_size_t allocated;
	list_size_t used;
	rdf_node* ptr;
	int refcount;
} hx_terminal;

typedef struct {
	rdf_node node;
	hx_terminal* terminal;
} hx_vector_item;

typedef struct {
	list_size_t allocated;
	list_size_t used;
	hx_vector_item* ptr;
} hx_vector;

typedef struct {
	rdf_node node;
	hx_vector* vector;
} hx_head_item;

typedef struct {
	list_size_t allocated;
	list_size_t used;
	hx_head_item* ptr;
	int order[3];
} hx_head;


// new and free operations for: head, vector, and terminal list
hx_terminal* hx_new_terminal ( void );
int hx_free_terminal ( hx_terminal* list );
hx_vector* hx_new_vector ( void );
int hx_free_vector ( hx_vector* list );
hx_head* hx_new_head ( void );
int hx_free_head ( hx_head* head );

// terminal list operations
int hx_terminal_debug ( const char* header, hx_terminal* t, int newline );
int hx_terminal_add_node ( hx_terminal* t, rdf_node n );
int hx_terminal_remove_node ( hx_terminal* t, rdf_node n );
int hx_terminal_binary_search ( const hx_terminal* t, const rdf_node n, int* index );
list_size_t hx_terminal_size ( hx_terminal* t );
size_t hx_terminal_memory_size ( hx_terminal* t );

// vector operations
int hx_vector_debug ( const char* header, hx_vector* v );
int hx_vector_add_terminal ( hx_vector* v, rdf_node n, hx_terminal* t );
int hx_vector_remove_terminal ( hx_vector* v, rdf_node n );
int hx_vector_binary_search ( const hx_vector* v, const rdf_node n, int* index );
list_size_t hx_vector_size ( hx_vector* v );
uint64_t hx_vector_triples_count ( hx_vector* v );
size_t hx_vector_memory_size ( hx_vector* v );

// head operations
int hx_head_debug ( const char* header, hx_head* h );
int hx_head_binary_search ( const hx_head* h, const rdf_node n, int* index );
int hx_head_add_vector ( hx_head* h, rdf_node n, hx_vector* v );
int hx_head_remove_vector ( hx_head* h, rdf_node n );
list_size_t hx_head_size ( hx_head* h );
uint64_t hx_head_triples_count ( hx_head* h );
size_t hx_head_memory_size ( hx_head* h );
