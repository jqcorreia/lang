test:
	odin run . -- test2.z
	gcc -o calc calc.o
	./calc
