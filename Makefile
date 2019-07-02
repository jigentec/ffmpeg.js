PWD=$(shell pwd)
BIN=ffmpeg.js
TAG=korob/ffmpegjs-builder:latest

.PHONY: all docker clean

all:
	docker run \
		--rm \
		-v $(PWD):/build:z \
		-it $(TAG) \
		/bin/bash -c "source emsdk/emsdk-portable/emsdk_env.sh && cd /build && make -f ${BIN}.mk clean all"

docker:
	docker build -t $(TAG) .
	docker push $(TAG)

clean:
	$(MAKE) -f ${BIN}.mk clean BIN=${BIN}

