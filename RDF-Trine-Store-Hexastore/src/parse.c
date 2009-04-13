#include <time.h>
#include <stdio.h>
#include <raptor.h>
#include <inttypes.h>
#include "hexastore.h"
#include "node.h"
#include "parser.h"

#define DIFFTIME(a,b) ((b-a)/(double)CLOCKS_PER_SEC)

void help (int argc, char** argv);
int main (int argc, char** argv);

static int count	= 0;

void help (int argc, char** argv) {
	fprintf( stderr, "Usage: %s data.rdf hexastore.out\n\n", argv[0] );
}

void logger ( uint64_t _count ) {
	fprintf( stderr, "\rParsed %"PRIu64" triples...", _count );
}

int main (int argc, char** argv) {
	const char* rdf_filename	= NULL;
	const char* output_filename	= NULL;
	
	if (argc < 3) {
		help(argc, argv);
		exit(1);
	}
	
	rdf_filename	= argv[1];
	output_filename	= argv[2];
	
	hx_storage_manager* s	= hx_new_memory_storage_manager();
	hx_hexastore* hx		= hx_new_hexastore( s );
	
	FILE* f	= NULL;
	if (strcmp(output_filename, "/dev/null") != 0) {
		f	= fopen( output_filename, "w" );
		if (f == NULL) {
			perror( "Failed to open hexastore file for writing: " );
			return 1;
		}
	}
	
	hx_parser* parser	= hx_new_parser();
	hx_parser_set_logger( parser, logger );
	
	clock_t st_time	= clock();
	uint64_t total	= hx_parser_parse_file_into_hexastore( parser, hx, rdf_filename );
	clock_t end_time	= clock();
	
	double elapsed	= DIFFTIME(st_time, end_time);
	double tps	= ((double) total / elapsed);
	fprintf( stderr, "\rParsed %"PRIu64" triples in %.1lf seconds (%.1lf triples/second)\n", total, elapsed, tps );
	
	if (f != NULL) {
		if (hx_write( hx, f ) != 0) {
			fprintf( stderr, "*** Couldn't write hexastore to disk.\n" );
			return 1;
		}
	}
	fprintf( stderr, "\n" );
	
	hx_free_parser( parser );
	hx_free_hexastore( hx );
	hx_free_storage_manager( s );
	return 0;
}

