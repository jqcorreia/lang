test:
	odin test .

install:
	odin build . -out:zero 
	mv zero ~/.local/bin
