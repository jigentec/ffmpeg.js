# Compile FFmpeg and all its dependencies to JavaScript.
# You need emsdk environment installed and activated, see:
# <https://kripken.github.io/emscripten-site/docs/getting_started/downloads.html>.

PRE_JS = build/pre.js
POST_JS_SYNC = build/post-sync.js
POST_JS_WORKER = build/post-worker.js

COMMON_FILTERS = aresample scale crop overlay
COMMON_DEMUXERS = flv 
COMMON_DECODERS = h264 hevc opus mp3 aac

WEBM_MUXERS =
WEBM_ENCODERS = 
FFMPEG_WEBM_BC = build/ffmpeg-webm/ffmpeg.bc
LIBASS_PC_PATH = ../freetype/dist/lib/pkgconfig:../fribidi/dist/lib/pkgconfig
FFMPEG_WEBM_PC_PATH_ = \
	$(LIBASS_PC_PATH):\
	../libass/dist/lib/pkgconfig:\
	../opus/dist/lib/pkgconfig
FFMPEG_WEBM_PC_PATH = $(subst : ,:,$(FFMPEG_WEBM_PC_PATH_))
LIBASS_DEPS = 
WEBM_SHARED_DEPS =
MP4_MUXERS = mp4 
MP4_ENCODERS = libx264 aac
FFMPEG_MP4_BC = build/ffmpeg-mp4/ffmpeg.bc
FFMPEG_MP4_PC_PATH = ../x264/dist/lib/pkgconfig
MP4_SHARED_DEPS = build/x264/dist/lib/libx264.so

all: submodules mp4

submodules:
	git submodule init
	git submodule update --recursive

webm: ffmpeg-webm.js ffmpeg-worker-webm.js

mp4: ffmpeg-mp4.js ffmpeg-worker-mp4.js

clean: clean-js \
	clean-freetype clean-fribidi clean-libass \
	clean-opus clean-libvpx clean-ffmpeg-webm \
	clean-lame clean-x264 clean-ffmpeg-mp4
clean-js:
	rm -f -- ffmpeg*.js
clean-opus:
	-cd build/opus && rm -rf dist && make clean
clean-freetype:
	-cd build/freetype && rm -rf dist && make clean
clean-fribidi:
	-cd build/fribidi && rm -rf dist && make clean
clean-libass:
	-cd build/libass && rm -rf dist && make clean
clean-libvpx:
	-cd build/libvpx && rm -rf dist && make clean
clean-lame:
	-cd build/lame && rm -rf dist && make clean
clean-x264:
	-cd build/x264 && rm -rf dist && make clean
clean-ffmpeg-webm:
	-cd build/ffmpeg-webm && rm -f ffmpeg.bc && make clean
clean-ffmpeg-mp4:
	-cd build/ffmpeg-mp4 && rm -f ffmpeg.bc && make clean

build/opus/configure:
	cd build/opus && ./autogen.sh

build/opus/dist/lib/libopus.so: build/opus/configure
	cd build/opus && \
	emconfigure ./configure \
		CFLAGS=-O3 \
		--prefix="$$(pwd)/dist" \
		--disable-static \
		--disable-doc \
		--disable-extra-programs \
		--disable-asm \
		--disable-rtcd \
		--disable-intrinsics \
		&& \
	emmake make -j8 && \
	emmake make install

build/x264/dist/lib/libx264.so:
	cd build/x264 && \
	#git reset --hard &&
	patch -p1 < ../x264-configure.patch && \
	emconfigure ./configure \
		--prefix="$$(pwd)/dist" \
		--extra-cflags="-Wno-unknown-warning-option" \
		--host=x86-none-linux \
		--disable-cli \
		--enable-shared \
		--disable-opencl \
		--disable-thread \
		--disable-asm \
		\
		--disable-avs \
		--disable-swscale \
		--disable-lavf \
		--disable-ffms \
		--disable-gpac \
		--disable-lsmash \
		&& \
	emmake make -j8 && \
	emmake make install

# TODO(Kagami): Emscripten documentation recommends to always use shared
# libraries but it's not possible in case of ffmpeg because it has
# multiple declarations of `ff_log2_tab` symbol. GCC builds FFmpeg fine
# though because it uses version scripts and so `ff_log2_tag` symbols
# are not exported to the shared libraries. Seems like `emcc` ignores
# them. We need to file bugreport to upstream. See also:
# - <https://kripken.github.io/emscripten-site/docs/compiling/Building-Projects.html>
# - <https://github.com/kripken/emscripten/issues/831>
# - <https://ffmpeg.org/pipermail/libav-user/2013-February/003698.html>
FFMPEG_COMMON_ARGS = \
	--cc=emcc \
	--enable-cross-compile \
	--target-os=none \
	--arch=x86 \
	--disable-runtime-cpudetect \
	--disable-asm \
	--disable-fast-unaligned \
	--disable-pthreads \
	--disable-w32threads \
	--disable-os2threads \
	--disable-debug \
	--disable-stripping \
	\
	--disable-all \
	--enable-ffmpeg \
	--enable-avcodec \
	--enable-avformat \
	--enable-avutil \
	--enable-swresample \
	--enable-swscale \
	--enable-avfilter \
	--disable-network \
	--disable-d3d11va \
	--disable-dxva2 \
	--disable-vaapi \
	--disable-vda \
	--disable-vdpau \
	$(addprefix --enable-decoder=,$(COMMON_DECODERS)) \
	$(addprefix --enable-demuxer=,$(COMMON_DEMUXERS)) \
	--enable-protocol=file \
	$(addprefix --enable-filter=,$(COMMON_FILTERS)) \
	--disable-bzlib \
	--disable-iconv \
	--disable-libxcb \
	--disable-lzma \
	--disable-sdl \
	--disable-securetransport \
	--disable-xlib \
	--disable-zlib

build/ffmpeg-webm/ffmpeg.bc: $(WEBM_SHARED_DEPS)
	cd build/ffmpeg-webm && \
	# git reset --hard &&
	patch -p1 < ../ffmpeg-disable-arc4random.patch && \
	patch -p1 < ../ffmpeg-default-font.patch && \
	patch -p1 < ../ffmpeg-disable-monotonic.patch && \
	EM_PKG_CONFIG_PATH=$(FFMPEG_WEBM_PC_PATH) emconfigure ./configure \
		$(FFMPEG_COMMON_ARGS) \
		$(addprefix --enable-encoder=,$(WEBM_ENCODERS)) \
		$(addprefix --enable-muxer=,$(WEBM_MUXERS)) \
		--enable-filter=subtitles \
		--enable-libass \
		--enable-libopus \
		--enable-libvpx \
		--extra-cflags="-I../libvpx/dist/include" \
		--extra-ldflags="-L../libvpx/dist/lib" \
		&& \
	emmake make -j8 && \
	cp ffmpeg ffmpeg.bc

build/ffmpeg-mp4/ffmpeg.bc: $(MP4_SHARED_DEPS)
	cd build/ffmpeg-mp4 && \
	# git reset --hard &&
	patch -p1 < ../ffmpeg-disable-arc4random.patch && \
	patch -p1 < ../ffmpeg-disable-monotonic.patch && \
	EM_PKG_CONFIG_PATH=$(FFMPEG_MP4_PC_PATH) emconfigure ./configure \
		$(FFMPEG_COMMON_ARGS) \
		$(addprefix --enable-encoder=,$(MP4_ENCODERS)) \
		$(addprefix --enable-muxer=,$(MP4_MUXERS)) \
		--enable-gpl \
		--enable-libmp3lame \
		--enable-libx264 \
		--extra-cflags="-I../lame/dist/include" \
		--extra-ldflags="-L../lame/dist/lib" \
		&& \
	emmake make -j8 && \
	cp ffmpeg ffmpeg.bc

# Compile bitcode to JavaScript.
# NOTE(Kagami): Bump heap size to 64M, default 16M is not enough even
# for simple tests and 32M tends to run slower than 64M.
EMCC_COMMON_ARGS = \
	--closure 1 \
	-s TOTAL_MEMORY=67108864 \
	-s OUTLINING_LIMIT=20000 \
	-O3 --memory-init-file 0 \
	--pre-js $(PRE_JS) \
	-o $@

ffmpeg-webm.js: $(FFMPEG_WEBM_BC) $(PRE_JS) $(POST_JS_SYNC)
	emcc $(FFMPEG_WEBM_BC) $(WEBM_SHARED_DEPS) \
		--post-js $(POST_JS_SYNC) \
		$(EMCC_COMMON_ARGS)

ffmpeg-worker-webm.js: $(FFMPEG_WEBM_BC) $(PRE_JS) $(POST_JS_WORKER)
	emcc $(FFMPEG_WEBM_BC) $(WEBM_SHARED_DEPS) \
		--post-js $(POST_JS_WORKER) \
		$(EMCC_COMMON_ARGS)

ffmpeg-mp4.js: $(FFMPEG_MP4_BC) $(PRE_JS) $(POST_JS_SYNC)
	emcc $(FFMPEG_MP4_BC) $(MP4_SHARED_DEPS) \
		--post-js $(POST_JS_SYNC) \
		$(EMCC_COMMON_ARGS)

ffmpeg-worker-mp4.js: $(FFMPEG_MP4_BC) $(PRE_JS) $(POST_JS_WORKER)
	emcc $(FFMPEG_MP4_BC) $(MP4_SHARED_DEPS) \
		--post-js $(POST_JS_WORKER) \
		$(EMCC_COMMON_ARGS)
