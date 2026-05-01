image := "joeegrigg/find-me:latest"

# Show available commands
default: help

# Show available commands
help:
	@just --list

# Build the Docker image
build:
	docker build -t {{image}} .

# Build and push the Docker image
push: build
	docker push {{image}}
