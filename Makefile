PWD=$(shell pwd)
BIN=ffmpeg.js
TAG=ffmpegjs-builder:latest

.PHONY: all docker clean

all:
	docker run \
		--rm \
		-v $(PWD):/build:z \
		-it $(TAG) \
		/bin/sh -c "cd /build && make -f ${BIN}.mk clean all"

docker:
	docker build -t $(TAG) .

clean:
	$(MAKE) -f ${BIN}.mk clean BIN=${BIN}

