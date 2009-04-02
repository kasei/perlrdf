/*
 * Drizzle Client & Protocol Library
 *
 * Copyright (C) 2008 Eric Day (eday@oddments.org)
 * All rights reserved.
 *
 * Use and distribution licensed under the BSD license.  See
 * the COPYING file in this directory for full text.
 */

#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <strings.h>

#include <libdrizzle/drizzle_server.h>
#include <hexastore.h>

#define HX_SERVER_VERSION "Hexastore Server using libdrizzle 0.2"

#define DRIZZLE_RETURN_CHECK(__ret, __function, __drizzle) { \
  if ((__ret) != DRIZZLE_RETURN_OK) \
  { \
    printf(__function ":%s\n", drizzle_error(__drizzle)); \
    return; \
  } }

#define DRIZZLE_RETURN_CHECK_VAL(__ret, __function, __drizzle) { \
  if ((__ret) != DRIZZLE_RETURN_OK) \
  { \
    printf(__function ":%s\n", drizzle_error(__drizzle)); \
    return ret; \
  } }

typedef struct
{
  drizzle_st drizzle;
  drizzle_con_st con;
  drizzle_result_st result;
  drizzle_column_st column;
  hx_hexastore* db;
  bool send_columns;
  uint8_t verbose;
  uint64_t rows;
} hx_server;

static void server_run(hx_server *server);
//static int row_cb(void *data, int field_count, char **fields, char **columns);
static int row_cb(hx_server *server, int field_count, char **fields, char **columns);
static drizzle_return_t send_version(hx_server *server);
static void usage(char *name);
int listen_init( in_port_t port );

int main(int argc, char *argv[])
{
  uint32_t count= 0;
  bool mysql= false;
  char c;
  int listen_fd;
  drizzle_st drizzle;
  int fd;
  struct sockaddr_in sa;
  socklen_t sa_len;
  drizzle_return_t ret;
  hx_server server;

  server.db= NULL;
  server.verbose= 0;

  while((c = getopt(argc, argv, "c:mv")) != EOF)
  {
    switch(c)
    {
    case 'c':
      count= (uint32_t)atoi(optarg);
      break;

    case 'm':
      mysql= true;
      break;

    case 'v':
      server.verbose++;
      break;

    default:
      usage(argv[0]);
      return 1;
    }
  }

  if (argc != (optind + 2))
  {
    usage(argv[0]);
    return 1;
  }

  FILE* f = fopen( argv[optind], "r" );
  if (f == NULL) {
    perror( "Failed to open hexastore file for reading: " );
    return 1;
  }
  hx_storage_manager* s = hx_new_memory_storage_manager();
  server.db  = hx_read( s, f, 0 );
  
  if (server.db == NULL)
  {
    printf("hx_read: could not open hexastore db\n");
    return 1;
  }

  listen_fd= listen_init((in_port_t)atoi(argv[optind + 1]));
  if (listen_fd == -1)
    return 1;

  if (drizzle_create(&(server.drizzle)) == NULL)
  {
    printf("drizzle_create: memory allocation error\n");
    return 1;
  }

  while (1)
  {
    sa_len= sizeof(sa);
    fd= accept(listen_fd, (struct sockaddr *)(&sa), &sa_len);
    if (fd == -1)
    {
      printf("accept:%d\n", errno);
      return 1;
    }

    if (drizzle_con_create(&(server.drizzle), &(server.con)) == NULL)
    {
      printf("drizzle_con_create: memory allocation error\n");
      return 1;
    }

    ret= drizzle_con_set_fd(&(server.con), fd);
    if (ret != DRIZZLE_RETURN_OK)
    {
      printf("drizzle_con_connect: %s\n", drizzle_error(&drizzle));
      return 1;
    }

    if (mysql)
      drizzle_con_add_options(&(server.con), DRIZZLE_CON_MYSQL);

    if (server.verbose > 0)
      printf("Connect: %s:%u\n", inet_ntoa(sa.sin_addr), ntohs(sa.sin_port));

    server_run(&server);

    printf("Disconnect\n");

    drizzle_con_free(&(server.con));

    if (count > 0)
    {
      count--;

      if (count == 0)
        break;
    }
  }

  drizzle_free(&(server.drizzle));
  hx_free_hexastore( server.db );
  hx_free_storage_manager( s );

  return 0;
}

static void server_run(hx_server *server)
{
  drizzle_return_t ret;
  drizzle_command_t command;
  uint8_t *data= NULL;
  size_t total;
  int hx_ret;
  char *hx_err;

  /* Handshake packets. */
  drizzle_con_set_protocol_version(&(server->con), 10);
  drizzle_con_set_server_version(&(server->con), "libdrizzle+Hexastore");
  drizzle_con_set_thread_id(&(server->con), 1);
  drizzle_con_set_scramble(&(server->con),
                           (const uint8_t *)"ABCDEFGHIJKLMNOPQRST");
  drizzle_con_set_capabilities(&(server->con), DRIZZLE_CAPABILITIES_NONE);
  drizzle_con_set_charset(&(server->con), 8);
  drizzle_con_set_status(&(server->con), DRIZZLE_CON_STATUS_NONE);
  drizzle_con_set_max_packet_size(&(server->con), DRIZZLE_MAX_PACKET_SIZE);

  ret= drizzle_server_handshake_write(&(server->con));
  DRIZZLE_RETURN_CHECK(ret, "drizzle_server_handshake_write",
                       &(server->drizzle))

  ret= drizzle_client_handshake_read(&(server->con));
  DRIZZLE_RETURN_CHECK(ret, "drizzle_client_handshake_read", &(server->drizzle))

  if (drizzle_result_create(&(server->con), &(server->result)) == NULL)
    DRIZZLE_RETURN_CHECK(ret, "drizzle_result_create", &(server->drizzle))

  ret= drizzle_result_write(&(server->con), &(server->result), true);
  DRIZZLE_RETURN_CHECK(ret, "drizzle_result_write", &(server->drizzle))

  /* Command loop. */
  while (1)
  {
    drizzle_result_free(&(server->result));
    if (data != NULL)
      free(data);

    data= drizzle_command_buffer(&(server->con), &command, &total, &ret);
    if (ret == DRIZZLE_RETURN_EOF ||
        (ret == DRIZZLE_RETURN_OK && command == DRIZZLE_COMMAND_QUIT))
    {
      if (data != NULL)
        free(data);
      return;
    }
    DRIZZLE_RETURN_CHECK(ret, "drizzle_command_buffer", &(server->drizzle))

    if (server->verbose > 0)
    {
      printf("Command=%u Data=%s\n", command,
             data == NULL ? "NULL" : (char *)data);
    }

    if (drizzle_result_create(&(server->con), &(server->result)) == NULL)
      DRIZZLE_RETURN_CHECK(ret, "drizzle_result_create", &(server->drizzle))

    if (strstr((char *)data, "@@version") != NULL)
    {
      ret= send_version(server);
      if (ret != DRIZZLE_RETURN_OK)
        return;

      continue;
    }

    server->send_columns= true;
    server->rows= 0;

//     if (!strcasecmp((char *)data, "SHOW TABLES"))
//     {
//       hx_ret= sqlite3_exec(server->db,
//                             "SELECT name FROM sqlite_master WHERE type='table'",
//                                row_cb, server, &hx_err);
//     }
//     else
//     {
//       hx_ret= sqlite3_exec(server->db, (char *)data, row_cb, server,
//                                &hx_err);
//     }
	
    int count = 1;
    char* columns[3]	= { "subject", "predicate", "object" };
    hx_index_iter* iter = hx_index_new_iter( server->db->spo );
	if (iter == NULL) {
      printf("hx_index_new_iter failed\n");
      return;
    }

	char* fields[3];
    hx_node_id s, p, o;
    hx_nodemap* map	= hx_get_nodemap( server->db );;
    while (!hx_index_iter_finished( iter )) {
      hx_index_iter_current( iter, &s, &p, &o );
      hx_node* sn = hx_nodemap_get_node( map, s );
      hx_node* pn = hx_nodemap_get_node( map, p );
      hx_node* on = hx_nodemap_get_node( map, o );
      hx_node_string( sn, &(fields[0]) );
      hx_node_string( pn, &(fields[1]) );
      hx_node_string( on, &(fields[2]) );
      
      row_cb( server, 3, fields, columns );
      
      hx_index_iter_next( iter );
    }
    hx_free_index_iter( iter );
    
    if (server->rows == 0)
    {
      drizzle_result_set_column_count(&(server->result), 0);
      ret= drizzle_result_write(&(server->con), &(server->result), true);
      DRIZZLE_RETURN_CHECK(ret, "drizzle_result_write", &(server->drizzle))
    }
    else
    {
      drizzle_result_set_eof(&(server->result), true);
      ret= drizzle_result_write(&(server->con), &(server->result), true);
      DRIZZLE_RETURN_CHECK(ret, "drizzle_result_write", &(server->drizzle))
    }
  }
}

//static int row_cb(hx_server* server, int field_count, char **fields, char **columns)
static int row_cb(hx_server *server, int field_count, char **fields, char **columns)
{
  drizzle_return_t ret;
  int x;
  size_t sizes[8192];

  if (server->send_columns == true)
  {
    server->send_columns= false;
    drizzle_result_set_column_count(&(server->result), field_count);

    ret= drizzle_result_write(&(server->con), &(server->result), false);
    DRIZZLE_RETURN_CHECK_VAL(ret, "drizzle_result_write", &(server->drizzle))

    if (drizzle_column_create(&(server->result), &(server->column)) == NULL)
      DRIZZLE_RETURN_CHECK_VAL(ret, "drizzle_column_create", &(server->drizzle))

    drizzle_column_set_catalog(&(server->column), "sqlite");
    drizzle_column_set_db(&(server->column), "sqlite_db");
    drizzle_column_set_table(&(server->column), "sqlite_table");
    drizzle_column_set_orig_table(&(server->column), "sqlite_table");
    drizzle_column_set_charset(&(server->column), 8);
    drizzle_column_set_type(&(server->column), DRIZZLE_COLUMN_TYPE_VARCHAR);

    for (x= 0; x < field_count; x++)
    {
      drizzle_column_set_size(&(server->column),
                              fields[x] == NULL ? 0 : strlen(fields[x]));
      drizzle_column_set_name(&(server->column), columns[x]);
      drizzle_column_set_orig_name(&(server->column), columns[x]);

      ret= drizzle_column_write(&(server->result), &(server->column));
      DRIZZLE_RETURN_CHECK_VAL(ret, "drizzle_column_write", &(server->drizzle))
    }

    drizzle_column_free(&(server->column));

    drizzle_result_set_eof(&(server->result), true);

    ret= drizzle_result_write(&(server->con), &(server->result), false);
    DRIZZLE_RETURN_CHECK_VAL(ret, "drizzle_result_write", &(server->drizzle))
  }

  for (x= 0; x < field_count; x++)
  {
    if (fields[x] == NULL)
      sizes[x]= 0;
    else
      sizes[x]= strlen(fields[x]);
  }

  /* This is needed for MySQL and old Drizzle protocol. */
  drizzle_result_calc_row_size(&(server->result), (drizzle_field_t *)fields,
                               sizes);

  ret= drizzle_row_write(&(server->result));
  DRIZZLE_RETURN_CHECK_VAL(ret, "drizzle_row_write", &(server->drizzle))

  for (x= 0; x < field_count; x++)
  {
    ret= drizzle_field_write(&(server->result), (drizzle_field_t)fields[x],
                             sizes[x], sizes[x]);
    DRIZZLE_RETURN_CHECK_VAL(ret, "drizzle_field_write", &(server->drizzle))
  }

  server->rows++;

  return 0;
}

static drizzle_return_t send_version(hx_server *server)
{
  drizzle_return_t ret;
  drizzle_field_t fields[1];
  size_t sizes[1];

  fields[0]= (drizzle_field_t)HX_SERVER_VERSION;
  sizes[0]= strlen(HX_SERVER_VERSION);

  drizzle_result_set_column_count(&(server->result), 1);

  ret= drizzle_result_write(&(server->con), &(server->result), false);
  DRIZZLE_RETURN_CHECK_VAL(ret, "drizzle_result_write", &(server->drizzle))

  if (drizzle_column_create(&(server->result), &(server->column)) == NULL)
    DRIZZLE_RETURN_CHECK_VAL(ret, "drizzle_column_create", &(server->drizzle))

  drizzle_column_set_catalog(&(server->column), "sqlite");
  drizzle_column_set_db(&(server->column), "sqlite_db");
  drizzle_column_set_table(&(server->column), "sqlite_table");
  drizzle_column_set_orig_table(&(server->column), "sqlite_table");
  drizzle_column_set_charset(&(server->column), 8);
  drizzle_column_set_type(&(server->column), DRIZZLE_COLUMN_TYPE_VARCHAR);
  drizzle_column_set_size(&(server->column), sizes[0]);
  drizzle_column_set_name(&(server->column), "version");
  drizzle_column_set_orig_name(&(server->column), "version");

  ret= drizzle_column_write(&(server->result), &(server->column));
  DRIZZLE_RETURN_CHECK_VAL(ret, "drizzle_column_write", &(server->drizzle))

  drizzle_column_free(&(server->column));

  drizzle_result_set_eof(&(server->result), true);

  ret= drizzle_result_write(&(server->con), &(server->result), false);
  DRIZZLE_RETURN_CHECK_VAL(ret, "drizzle_result_write", &(server->drizzle))

  /* This is needed for MySQL and old Drizzle protocol. */
  drizzle_result_calc_row_size(&(server->result), fields, sizes);

  ret= drizzle_row_write(&(server->result));
  DRIZZLE_RETURN_CHECK_VAL(ret, "drizzle_row_write", &(server->drizzle))

  ret= drizzle_field_write(&(server->result), fields[0], sizes[0], sizes[0]);
  DRIZZLE_RETURN_CHECK_VAL(ret, "drizzle_field_write", &(server->drizzle))

  ret= drizzle_result_write(&(server->con), &(server->result), true);
  DRIZZLE_RETURN_CHECK_VAL(ret, "drizzle_result_write", &(server->drizzle))

  return DRIZZLE_RETURN_OK;
}

static void usage(char *name)
{
  printf("\nusage: %s [-c <count>] [-m] <hexastore db file> <port>\n", name);
  printf("\t-c <count> - number of connections to accept before exiting\n");
  printf("\t-m         - use the MySQL protocol\n");
  printf("\t-v         - increase verbosity level\n");
}

int listen_init(in_port_t port)
{
  struct sockaddr_in sa;
  int fd;
  int opt= 1;

  if (signal(SIGPIPE, SIG_IGN) == SIG_ERR)
  {
    printf("signal:%d\n", errno);
    return -1;
  }

  memset(&sa, 0, sizeof(sa));
  sa.sin_family = AF_INET;
  sa.sin_port= htons(port);
  sa.sin_addr.s_addr = INADDR_ANY;

  fd= socket(sa.sin_family, SOCK_STREAM, 0);
  if (fd == -1)
  {
    printf("socket:%d\n", errno);
    return -1;
  }

  if (setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt)) == -1)
  {
    printf("setsockopt:%d\n", errno);
    return -1;
  }

  if (bind(fd, (struct sockaddr *)(&sa), sizeof(sa)) == -1)
  {
    printf("bind:%d\n", errno);
    return -1;
  }

  if (listen(fd, 32) == -1)
  {
    printf("listen:%d\n", errno);
    return -1;
  }

  return fd;
}
