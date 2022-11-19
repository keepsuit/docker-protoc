# syntax=docker/dockerfile:1.4

ARG UBUNTU_VERSION=22.04
ARG NODE_VERSION=18
ARG PROTOC_VERSION=21.9
ARG GRPC_VERSION=1.50.1
ARG ROADRUNNER_VERSION=2.11.4
ARG PROTOBUF_JS_VERSION=3.21.2
ARG TS_PROTO_VERSION=1.131.0


FROM --platform=$BUILDPLATFORM tonistiigi/xx AS xx


FROM --platform=$BUILDPLATFORM ubuntu:${UBUNTU_VERSION} as ubuntu_host
COPY --from=xx / /
WORKDIR /
RUN mkdir -p /out/usr/local/bin \
    && mkdir -p /out/usr/include \
    && mkdir -p /tmp
RUN apt-get update && apt-get install -y \
    curl \
    git \
    unzip


FROM --platform=$BUILDPLATFORM ubuntu_host as protobuf
ARG TARGETARCH
ARG PROTOC_VERSION
RUN case ${TARGETARCH} in \
         "amd64")  PROTOC_ARCH=x86_64  ;; \
         "arm64")  PROTOC_ARCH=aarch_64  ;; \
    esac \
    && curl -sSLo /tmp/protoc.zip "https://github.com/protocolbuffers/protobuf/releases/download/v${PROTOC_VERSION}/protoc-${PROTOC_VERSION}-linux-${PROTOC_ARCH}.zip"
RUN unzip -q /tmp/protoc.zip -d /tmp/protoc
RUN mkdir -p /out/usr/local/bin \
    && cp /tmp/protoc/bin/protoc /out/usr/local/bin/protoc \
    && chmod a+x /out/usr/local/bin/protoc \
    && mkdir -p /out/usr/include \
    && cp -R /tmp/protoc/include/* /out/usr/include/


FROM --platform=$BUILDPLATFORM ubuntu_host as grpc
RUN apt update && apt install -y \
    build-essential \
    pkg-config \
    cmake \
    libtool \
    autoconf \
    zlib1g-dev \
    libssl-dev \
    clang \
    lld
ARG GRPC_VERSION
RUN git clone -b v${GRPC_VERSION} https://github.com/grpc/grpc
WORKDIR grpc
RUN git submodule update --init
ARG TARGETPLATFORM
RUN xx-apt install -y \
    libc6-dev \
    gcc \
    g++
RUN mkdir -p cmake/build
WORKDIR cmake/build
RUN cmake $(xx-clang --print-cmake-defines) ../..
RUN make grpc_php_plugin
RUN xx-verify grpc_php_plugin
RUN mkdir -p /out/usr/local/bin \
    && cp grpc_php_plugin /out/usr/local/bin/protoc-gen-grpc-php \
    && chmod a+x /out/usr/local/bin/protoc-gen-grpc-php


FROM --platform=$BUILDPLATFORM ubuntu_host as roadrunner
ARG TARGETARCH
ARG ROADRUNNER_VERSION
ENV FILENAME=protoc-gen-php-grpc-${ROADRUNNER_VERSION}-linux-${TARGETARCH}
RUN curl -sSLo /tmp/protoc-gen-php-grpc.tar.gz "https://github.com/roadrunner-server/roadrunner/releases/download/v${ROADRUNNER_VERSION}/${FILENAME}.tar.gz"
RUN tar -xzf /tmp/protoc-gen-php-grpc.tar.gz -C /tmp
RUN mkdir -p /out/usr/local/bin \
    && cp /tmp/${FILENAME}/protoc-gen-php-grpc /out/usr/local/bin/protoc-gen-php-grpc \
    && chmod a+x /out/usr/local/bin/protoc-gen-php-grpc


FROM --platform=$BUILDPLATFORM ubuntu_host as protobuf-js
ARG TARGETARCH
ARG PROTOBUF_JS_VERSION
RUN case ${TARGETARCH} in \
         "amd64")  PROTOC_ARCH=x86_64  ;; \
         "arm64")  PROTOC_ARCH=aarch_64  ;; \
    esac \
    && curl -sSLo /tmp/protoc-gen-js.tar.gz "https://github.com/protocolbuffers/protobuf-javascript/releases/download/v${PROTOBUF_JS_VERSION}/protobuf-javascript-${PROTOBUF_JS_VERSION}-linux-${PROTOC_ARCH}.tar.gz"
RUN tar -xzf /tmp/protoc-gen-js.tar.gz -C /tmp
RUN mkdir -p /out/usr/local/bin \
    && cp /tmp/bin/protoc-gen-js /out/usr/local/bin/protoc-gen-js \
    && chmod a+x /out/usr/local/bin/protoc-gen-js


FROM ubuntu:${UBUNTU_VERSION}
RUN apt-get update && apt-get install -y \
    curl
ARG NODE_VERSION
RUN curl -fsSL "https://deb.nodesource.com/setup_${NODE_VERSION}.x" | bash - \
  && apt-get install -y nodejs
ARG TS_PROTO_VERSION
RUN npm config set unsafe-perm true && npm i -g \
    ts-proto@$TS_PROTO_VERSION
RUN ln -s /usr/lib/node_modules/ts-proto/protoc-gen-ts_proto /usr/local/bin/protoc-gen-ts_proto
COPY --from=protobuf /out/ /
COPY --from=grpc /out/ /
COPY --from=roadrunner /out/ /
COPY --from=protobuf-js /out/ /
COPY protoc-wrapper /usr/local/bin/protoc-wrapper
COPY protoc-test /usr/local/bin/protoc-test
RUN /usr/local/bin/protoc-test
ENTRYPOINT ["protoc-wrapper", "-I/usr/include"]