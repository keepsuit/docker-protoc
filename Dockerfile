# syntax=docker/dockerfile:1.4

ARG UBUNTU_VERSION=22.04
ARG NODE_VERSION=20
ARG PROTOC_VERSION=24.3
ARG GRPC_VERSION=1.59.0
ARG ROADRUNNER_VERSION=2023.2.0
ARG PROTOBUF_JS_VERSION=3.21.2
ARG BUF_VERSION=1.26.1
ARG BUF_PROTOC_ES=1.3.1


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
WORKDIR /tmp/grpc
RUN git clone -b v${GRPC_VERSION} https://github.com/grpc/grpc .
RUN git submodule update --init
ARG TARGETPLATFORM
RUN xx-apt install -y \
    libc6-dev \
    gcc \
    g++
WORKDIR /tmp/grpc/cmake/build
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


ARG BUF_VERSION
FROM bufbuild/buf:${BUF_VERSION} as buf


FROM ubuntu:${UBUNTU_VERSION}
RUN apt-get update && apt-get install -y \
    ca-certificates \
    curl \
    gnupg
ARG NODE_VERSION
RUN mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_VERSION.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list \
    && apt-get update -y \
    && apt-get install -y nodejs
ARG BUF_PROTOC_ES
RUN npm i -g \
    @bufbuild/protoc-gen-es@$BUF_PROTOC_ES
RUN ln -s /usr/lib/node_modules/@bufbuild/protoc-gen-es/bin/protoc-gen-es /usr/local/bin/protoc-gen-es
COPY --from=protobuf /out/ /
COPY --from=grpc /out/ /
COPY --from=roadrunner /out/ /
COPY --from=protobuf-js /out/ /
COPY --from=buf /usr/local/bin/buf /usr/local/bin/buf
COPY protoc-wrapper /usr/local/bin/protoc-wrapper
COPY protoc-test /usr/local/bin/protoc-test
RUN /usr/local/bin/protoc-test
ENTRYPOINT ["protoc-wrapper", "-I/usr/include"]
