.PHONY: lint test

lint:
	gofmt -l .
	golangci-lint run

test:
	go test ./...
