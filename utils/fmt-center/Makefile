BINARY := fmt-center

.PHONY: all build run clean install uninstall self-test

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

self-test: build
	chmod +x ./self-test.sh
	./self-test.sh
