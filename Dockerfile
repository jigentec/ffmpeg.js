FROM ubuntu:latest
MAINTAINER Pu-Chen Mao <mao@jigentec.com>

RUN apt-get update && \
    apt-get -y install wget python git automake libtool build-essential cmake \
    libglib2.0-dev closure-compiler

SHELL ["/bin/bash", "-c"]
RUN mkdir -p /emsdk && \
	cd /emsdk && \
	wget https://s3.amazonaws.com/mozilla-games/emscripten/releases/emsdk-portable.tar.gz && \
	tar xzvf emsdk-portable.tar.gz && \
	cd emsdk-portable && \
	./emsdk update && \
	./emsdk install latest && \
	./emsdk activate latest && \
	cp ./emsdk_env.sh /emsdk_env.sh

CMD ["/bin/bash"]

