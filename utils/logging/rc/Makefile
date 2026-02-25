BINARY := rc

.PHONY: all build run clean install uninstall

all: build

build:
	go build -o $(BINARY) ./main.go

run:
	go run ./main.go --help

clean:
	rm -f $(BINARY)

install:
	chmod +x ./install.sh
	./install.sh

uninstall:
	chmod +x ./uninstall.sh
	./uninstall.sh
