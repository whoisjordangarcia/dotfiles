BINARY  := bin/otobun
GOFLAGS := -trimpath
SRC     := $(shell find . -name '*.go' -not -path './vendor/*')

.PHONY: build test clean run

build: $(BINARY)

$(BINARY): $(SRC) go.mod go.sum
	go build $(GOFLAGS) -o $(BINARY) ./cmd/otobun

test:
	go test ./...

run: build
	./$(BINARY)

clean:
	rm -f $(BINARY)
