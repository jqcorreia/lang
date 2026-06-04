test:
	odin test .

install:
	odin build . -out:zero 
	mkdir -p ~/.local/lib/zero
	cp -r runtime std vendor zero ~/.local/lib/zero
	ln -sf ~/.local/lib/zero/zero ~/.local/bin/zero
