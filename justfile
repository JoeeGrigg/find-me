image := "joeegrigg/find-me:latest"

default: build

build:
	docker build -t {{image}} .

push: build
	docker push {{image}}
