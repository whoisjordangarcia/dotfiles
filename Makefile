GOFLAGS := -trimpath
SRC     := $(shell find . -name '*.go' -not -path './vendor/*')

.PHONY: build test clean run

build: bin/otobun bin/nxps

bin/otobun: $(SRC) go.mod go.sum
	go build $(GOFLAGS) -o bin/otobun ./cmd/otobun

bin/nxps: $(SRC) go.mod go.sum
	go build $(GOFLAGS) -o bin/nxps ./cmd/nxps

test:
	go test ./...

run: build
	./bin/otobun

clean:
	rm -f bin/otobun bin/nxps
