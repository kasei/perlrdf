CFLAGS	=	-std=c99 -pedantic -ggdb -Wall # -Werror -DAVL_ALLOC_COUNT
CC		=	gcc $(CFLAGS)
LIBS	=	-lraptor -L/cs/willig4/local/lib -I/cs/willig4/local/include

all: main parse print

main: main.c hexastore.o index.o terminal.o vector.o head.o avl.o nodemap.o
	$(CC) $(INC) main.c hexastore.o index.o terminal.o vector.o head.o avl.o nodemap.o

parse: parse.c hexastore.o index.o terminal.o vector.o head.o avl.o nodemap.o
	$(CC) $(INC) $(LIBS) -o parse parse.c hexastore.o index.o terminal.o vector.o head.o avl.o nodemap.o

print: print.c hexastore.o index.o terminal.o vector.o head.o avl.o nodemap.o
	$(CC) $(INC) $(LIBS) -o print print.c hexastore.o index.o terminal.o vector.o head.o avl.o nodemap.o

avl.o: avl.c avl.h hexastore_types.h
	$(CC) $(INC) -c avl.c

hexastore.o: hexastore.c hexastore.h index.h head.h vector.h terminal.h hexastore_types.h
	$(CC) $(INC) -c hexastore.c

index.o: index.c index.h terminal.h vector.h head.h hexastore_types.h
	$(CC) $(INC) -c index.c

terminal.o: terminal.c terminal.h hexastore_types.h
	$(CC) $(INC) -c terminal.c

vector.o: vector.c vector.h terminal.h hexastore_types.h
	$(CC) $(INC) -c vector.c

head.o: head.c head.h vector.h terminal.h avl.h hexastore_types.h
	$(CC) $(INC) -c head.c

nodemap.o: nodemap.c nodemap.h avl.h hexastore_types.h
	$(CC) $(INC) -c nodemap.c

clean:
	rm -f parse print a.out
	rm -f *.o
	rm -rf a.out.dSYM parse.dSYM print.dSYM

