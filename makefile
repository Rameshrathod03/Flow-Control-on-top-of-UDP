CC = gcc
CFLAGS = -Wall

LIBNAME = libksocket.a

LIBS = -L. -lksocket

all: $(LIBNAME) initksocket user1 user2

apps: user1 user2

$(LIBNAME): ksocket.o
	ar rcs $(LIBNAME) ksocket.o

ksocket.o: ksocket.c ksocket.h
	$(CC) $(CFLAGS) -c ksocket.c

initksocket: initksocket.o $(LIBNAME)
	$(CC) $(CFLAGS) -o initksocket initksocket.o $(LIBS)

initksocket.o: initksocket.c ksocket.h
	$(CC) $(CFLAGS) -c initksocket.c

user1: user1.o $(LIBNAME)
	$(CC) $(CFLAGS) -o user1 user1.o $(LIBS)

user1.o: user1.c ksocket.h
	$(CC) $(CFLAGS) -c user1.c

user2: user2.o $(LIBNAME)
	$(CC) $(CFLAGS) -o user2 user2.o $(LIBS)

user2.o: user2.c ksocket.h
	$(CC) $(CFLAGS) -c user2.c

clean:
	rm -f *.o $(LIBNAME) initksocket user1 user2
