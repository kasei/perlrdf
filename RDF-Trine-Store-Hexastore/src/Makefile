CFLAGS	=	-std=c99 -pedantic -ggdb -Wall -Wno-unused-value -Wno-unused-variable # -Werror -DAVL_ALLOC_COUNT
CC		=	gcc $(CFLAGS)
LIBS	=	-lpthread -L/cs/willig4/local/lib -I/cs/willig4/local/include
OBJECTS	=	hexastore.o index.o terminal.o vector.o head.o avl.o nodemap.o node.o variablebindings.o

all: test parse print optimize

test: test.c $(OBJECTS)
	$(CC) $(INC) $(LIBS) -o test test.c $(OBJECTS)

parse: parse.c $(OBJECTS)
	$(CC) $(INC) $(LIBS) -o parse -lraptor parse.c $(OBJECTS)

optimize: optimize.c $(OBJECTS)
	$(CC) $(INC) $(LIBS) -o optimize optimize.c $(OBJECTS)

print: print.c $(OBJECTS)
	$(CC) $(INC) $(LIBS) -o print print.c $(OBJECTS)

avl.o: avl.c avl.h hexastore_types.h
	$(CC) $(INC) -c avl.c

hexastore.o: hexastore.c hexastore.h index.h head.h vector.h terminal.h hexastore_types.h variablebindings.h nodemap.h
	$(CC) $(INC) -c hexastore.c

index.o: index.c index.h terminal.h vector.h head.h hexastore_types.h
	$(CC) $(INC) -c index.c

terminal.o: terminal.c terminal.h hexastore_types.h
	$(CC) $(INC) -c terminal.c

vector.o: vector.c vector.h terminal.h hexastore_types.h
	$(CC) $(INC) -c vector.c

head.o: head.c head.h vector.h terminal.h avl.h hexastore_types.h
	$(CC) $(INC) -c head.c

node.o: node.c node.h hexastore_types.h
	$(CC) $(INC) -c node.c
	
nodemap.o: nodemap.c nodemap.h avl.h hexastore_types.h
	$(CC) $(INC) -c nodemap.c

variablebindings.o: variablebindings.c variablebindings.h hexastore_types.h node.h index.h nodemap.h
	$(CC) $(INC) -c variablebindings.c

clean:
	rm -f test parse print optimize a.out
	rm -f *.o
	rm -rf *.dSYM

