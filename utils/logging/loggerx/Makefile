BINARY := loggerx

.PHONY: all build run clean self-test install uninstall

all: build

build:
	go build -o $(BINARY) ./loggerx_golang/main.go

run:
	go run ./loggerx_golang/main.go --help

clean:
	rm -f $(BINARY)

self-test: build
	chmod +x ./loggerx_golang/self-test.sh
	./loggerx_golang/self-test.sh

install:
	chmod +x ./install.sh
	./install.sh

uninstall:
	chmod +x ./uninstall.sh
	./uninstall.sh
