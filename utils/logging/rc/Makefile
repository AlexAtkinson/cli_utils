BINARY := rc

.PHONY: all build run clean self-test install uninstall

all: build

build:
	go build -o $(BINARY) ./main.go

run:
	go run ./main.go --help

clean:
	rm -f $(BINARY)

self-test: build
	chmod +x ./self-test.sh
	./self-test.sh

install:
	chmod +x ./install.sh
	./install.sh

uninstall:
	chmod +x ./uninstall.sh
	./uninstall.sh
