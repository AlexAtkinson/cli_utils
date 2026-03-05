BINARY := loggerx

.PHONY: all build run clean self-test

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
