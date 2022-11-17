# syntax=docker/dockerfile:1.4

ARG ALPINE_VERSION=3.16
ARG GO_VERSION=1.19.3
ARG NODE_VERSION=18
ARG PHP_GRPC_VERSION=3.0.0
ARG PROTOC_GEN_DOC_VERSION=1.5.1
ARG PROTOC_GEN_GO_VERSION=1.28.1
ARG PROTOC_GEN_GO_GRPC_VERSION=1.45.0
ARG PROTOC_GEN_GOGO_VERSION=1.3.2
ARG PROTOC_GEN_VALIDATE_VERSION=0.9.0
ARG PROTOC_GEN_TS_VERSION=0.15.0
ARG GRPC_GATEWAY_VERSION=2.14.0
ARG GRPC_WEB_VERSION=1.4.2
ARG GOOGLE_API_VERSION=0184330e57d223dee21501ff4c9a08e9624add47
ARG UPX_VERSION=4.0.1


FROM --platform=$BUILDPLATFORM tonistiigi/xx AS xx


FROM --platform=$BUILDPLATFORM golang:${GO_VERSION}-alpine${ALPINE_VERSION} as go_host
COPY --from=xx / /
WORKDIR /
RUN mkdir -p /out
RUN apk add --no-cache \
    build-base \
    curl


FROM --platform=$BUILDPLATFORM alpine:${ALPINE_VERSION} as alpine_host
COPY --from=xx / /
WORKDIR /
RUN mkdir -p /out
RUN apk add --no-cache \
    curl \
    unzip


# protoc-gen-gateway
FROM --platform=$BUILDPLATFORM go_host as grpc_gateway
RUN mkdir -p ${GOPATH}/src/github.com/grpc-ecosystem/grpc-gateway
ARG GRPC_GATEWAY_VERSION
RUN curl -sSL https://api.github.com/repos/grpc-ecosystem/grpc-gateway/tarball/v${GRPC_GATEWAY_VERSION} | tar xz --strip 1 -C ${GOPATH}/src/github.com/grpc-ecosystem/grpc-gateway
WORKDIR ${GOPATH}/src/github.com/grpc-ecosystem/grpc-gateway
RUN go mod download
ARG TARGETPLATFORM
RUN xx-go --wrap
RUN go build -ldflags '-w -s' -o /grpc-gateway-out/protoc-gen-grpc-gateway ./protoc-gen-grpc-gateway
RUN go build -ldflags '-w -s' -o /grpc-gateway-out/protoc-gen-openapiv2 ./protoc-gen-openapiv2
RUN install -D /grpc-gateway-out/protoc-gen-grpc-gateway /out/usr/bin/protoc-gen-grpc-gateway
RUN install -D /grpc-gateway-out/protoc-gen-openapiv2 /out/usr/bin/protoc-gen-openapiv2
RUN mkdir -p /out/usr/include/protoc-gen-openapiv2/options
RUN install -D $(find ./protoc-gen-openapiv2/options -name '*.proto') -t /out/usr/include/protoc-gen-openapiv2/options
RUN xx-verify /out/usr/bin/protoc-gen-grpc-gateway
RUN xx-verify /out/usr/bin/protoc-gen-openapiv2


# protoc-gen-doc
FROM --platform=$BUILDPLATFORM go_host as protoc_gen_doc
RUN mkdir -p ${GOPATH}/src/github.com/pseudomuto/protoc-gen-doc
ARG PROTOC_GEN_DOC_VERSION
RUN curl -sSL https://api.github.com/repos/pseudomuto/protoc-gen-doc/tarball/v${PROTOC_GEN_DOC_VERSION} | tar xz --strip 1 -C ${GOPATH}/src/github.com/pseudomuto/protoc-gen-doc
WORKDIR ${GOPATH}/src/github.com/pseudomuto/protoc-gen-doc
RUN go mod download
ARG TARGETPLATFORM
RUN xx-go --wrap
RUN go build -ldflags '-w -s' -o /protoc-gen-doc-out/protoc-gen-doc ./cmd/protoc-gen-doc
RUN install -D /protoc-gen-doc-out/protoc-gen-doc /out/usr/bin/protoc-gen-doc
RUN xx-verify /out/usr/bin/protoc-gen-doc


# protoc-gen-go-grpc
FROM --platform=$BUILDPLATFORM go_host as protoc_gen_go_grpc
RUN mkdir -p ${GOPATH}/src/github.com/grpc/grpc-go
ARG PROTOC_GEN_GO_GRPC_VERSION
RUN curl -sSL https://api.github.com/repos/grpc/grpc-go/tarball/v${PROTOC_GEN_GO_GRPC_VERSION} | tar xz --strip 1 -C ${GOPATH}/src/github.com/grpc/grpc-go
WORKDIR ${GOPATH}/src/github.com/grpc/grpc-go/cmd/protoc-gen-go-grpc
RUN go mod download
ARG TARGETPLATFORM
RUN xx-go --wrap
RUN go build -ldflags '-w -s' -o /golang-protobuf-out/protoc-gen-go-grpc .
RUN install -D /golang-protobuf-out/protoc-gen-go-grpc /out/usr/bin/protoc-gen-go-grpc
RUN xx-verify /out/usr/bin/protoc-gen-go-grpc


# protoc-gen-go
FROM --platform=$BUILDPLATFORM go_host as protoc_gen_go
RUN mkdir -p ${GOPATH}/src/google.golang.org/protobuf
ARG PROTOC_GEN_GO_VERSION
RUN curl -sSL https://api.github.com/repos/protocolbuffers/protobuf-go/tarball/v${PROTOC_GEN_GO_VERSION} | tar xz --strip 1 -C ${GOPATH}/src/google.golang.org/protobuf
WORKDIR ${GOPATH}/src/google.golang.org/protobuf
RUN go mod download
ARG TARGETPLATFORM
RUN xx-go --wrap
RUN go build -ldflags '-w -s' -o /golang-protobuf-out/protoc-gen-go ./cmd/protoc-gen-go
RUN install -D /golang-protobuf-out/protoc-gen-go /out/usr/bin/protoc-gen-go
RUN xx-verify /out/usr/bin/protoc-gen-go


# protoc-gen-gogo
FROM --platform=$BUILDPLATFORM go_host as protoc_gen_gogo
RUN mkdir -p ${GOPATH}/src/github.com/gogo/protobuf
ARG PROTOC_GEN_GOGO_VERSION
RUN curl -sSL https://api.github.com/repos/gogo/protobuf/tarball/v${PROTOC_GEN_GOGO_VERSION} | tar xz --strip 1 -C ${GOPATH}/src/github.com/gogo/protobuf
WORKDIR ${GOPATH}/src/github.com/gogo/protobuf
RUN go mod download
ARG TARGETPLATFORM
RUN xx-go --wrap
RUN go build -ldflags '-w -s' -o /gogo-protobuf-out/protoc-gen-gofast ./protoc-gen-gofast
RUN go build -ldflags '-w -s' -o /gogo-protobuf-out/protoc-gen-gogo ./protoc-gen-gogo
RUN go build -ldflags '-w -s' -o /gogo-protobuf-out/protoc-gen-gogofast ./protoc-gen-gogofast
RUN go build -ldflags '-w -s' -o /gogo-protobuf-out/protoc-gen-gogofaster ./protoc-gen-gogofaster
RUN go build -ldflags '-w -s' -o /gogo-protobuf-out/protoc-gen-gogoslick ./protoc-gen-gogoslick
RUN go build -ldflags '-w -s' -o /gogo-protobuf-out/protoc-gen-gogotypes ./protoc-gen-gogotypes
RUN go build -ldflags '-w -s' -o /gogo-protobuf-out/protoc-gen-gostring ./protoc-gen-gostring
RUN install -D $(find /gogo-protobuf-out -name 'protoc-gen-*') -t /out/usr/bin
RUN mkdir -p /out/usr/include/github.com/gogo/protobuf/protobuf/google/protobuf
RUN install -D $(find ./protobuf/google/protobuf -name '*.proto') -t /out/usr/include/github.com/gogo/protobuf/protobuf/google/protobuf
RUN install -D ./gogoproto/gogo.proto /out/usr/include/github.com/gogo/protobuf/gogoproto/gogo.proto
RUN xx-verify /out/usr/bin/protoc-gen-gogo


# protoc-gen-validate
FROM --platform=$BUILDPLATFORM go_host as protoc_gen_validate
ARG PROTOC_GEN_VALIDATE_VERSION
RUN mkdir -p ${GOPATH}/src/github.com/envoyproxy/protoc-gen-validate
RUN curl -sSL https://api.github.com/repos/envoyproxy/protoc-gen-validate/tarball/v${PROTOC_GEN_VALIDATE_VERSION} | tar xz --strip 1 -C ${GOPATH}/src/github.com/envoyproxy/protoc-gen-validate
WORKDIR ${GOPATH}/src/github.com/envoyproxy/protoc-gen-validate
RUN go mod download
ARG TARGETPLATFORM
RUN xx-go --wrap
RUN go build -ldflags '-w -s' -o /protoc-gen-validate-out/protoc-gen-validate .
RUN install -D /protoc-gen-validate-out/protoc-gen-validate /out/usr/bin/protoc-gen-validate
RUN install -D ./validate/validate.proto /out/usr/include/github.com/envoyproxy/protoc-gen-validate/validate/validate.proto
RUN xx-verify /out/usr/bin/protoc-gen-validate


# protoc-gen-php-grpc
FROM --platform=$BUILDPLATFORM go_host as protoc_gen_php_grpc
ARG PHP_GRPC_VERSION
RUN mkdir -p ${GOPATH}/src/github.com/roadrunner-server/grpc
RUN curl -sSL https://api.github.com/repos/roadrunner-server/grpc/tarball/v${PHP_GRPC_VERSION} | tar xz --strip 1 -C ${GOPATH}/src/github.com/roadrunner-server/grpc
WORKDIR ${GOPATH}/src/github.com/roadrunner-server/grpc
RUN go mod download
ARG TARGETPLATFORM
RUN xx-go --wrap
RUN go build -trimpath -ldflags "-s" -o /php-grpc-out/protoc-gen-php-grpc protoc_plugins/protoc-gen-php-grpc/main.go
RUN install -D /php-grpc-out/protoc-gen-php-grpc /out/usr/bin/protoc-gen-php-grpc
RUN xx-verify /out/usr/bin/protoc-gen-php-grpc


# protoc-gen-grpc-web
FROM alpine:${ALPINE_VERSION} as grpc_web
RUN apk add --no-cache \
    build-base \
    curl \
    protobuf-dev
RUN mkdir -p /grpc-web
ARG GRPC_WEB_VERSION
RUN curl -sSL https://api.github.com/repos/grpc/grpc-web/tarball/${GRPC_WEB_VERSION} | tar xz --strip 1 -C /grpc-web
WORKDIR /grpc-web
RUN make -j$(nproc) install-plugin
RUN install -Ds /usr/local/bin/protoc-gen-grpc-web /out/usr/bin/protoc-gen-grpc-web


# googleapis proto
FROM --platform=$BUILDPLATFORM alpine_host as googleapis
RUN mkdir -p /googleapis
ARG GOOGLE_API_VERSION
RUN curl -sSL https://api.github.com/repos/googleapis/googleapis/tarball/${GOOGLE_API_VERSION} | tar xz --strip 1 -C /googleapis
WORKDIR /googleapis
RUN install -D ./google/api/annotations.proto /out/usr/include/google/api/annotations.proto
RUN install -D ./google/api/field_behavior.proto /out/usr/include/google/api/field_behavior.proto
RUN install -D ./google/api/http.proto /out/usr/include/google/api/http.proto
RUN install -D ./google/api/httpbody.proto /out/usr/include/google/api/httpbody.proto


# protoc-gen-ts
FROM node:${NODE_VERSION}-alpine${ALPINE_VERSION} as protoc_gen_ts
ARG PROTOC_GEN_TS_VERSION
ARG NODE_VERSION
RUN npm install -g pkg ts-protoc-gen@${PROTOC_GEN_TS_VERSION}
RUN pkg \
    --compress Brotli \
    --targets node${NODE_VERSION}-alpine \
    -o protoc-gen-ts \
    /usr/local/lib/node_modules/ts-protoc-gen
RUN install -D protoc-gen-ts /out/usr/bin/protoc-gen-ts


# upx packing
FROM --platform=$BUILDPLATFORM alpine_host as upx
RUN mkdir -p /upx 
ARG BUILDARCH 
ARG BUILDOS 
ARG TARGETARCH
ARG UPX_VERSION
RUN if ! [ "${TARGETARCH}" = "arm64" ]; then curl -sSL https://github.com/upx/upx/releases/download/v${UPX_VERSION}/upx-${UPX_VERSION}-${BUILDARCH}_${BUILDOS}.tar.xz | tar xJ --strip 1 -C /upx; fi
RUN if ! [ "${TARGETARCH}" = "arm64" ]; then install -D /upx/upx /usr/local/bin/upx; fi
COPY --from=googleapis /out/ /out/
COPY --from=grpc_gateway /out/ /out/
COPY --from=grpc_web /out/ /out/
COPY --from=protoc_gen_doc /out/ /out/
COPY --from=protoc_gen_go /out/ /out/
COPY --from=protoc_gen_go_grpc /out/ /out/
COPY --from=protoc_gen_gogo /out/ /out/
COPY --from=protoc_gen_validate /out/ /out/
COPY --from=protoc_gen_php_grpc /out/ /out/
RUN <<EOF
    if ! [ "${TARGETARCH}" = "arm64" ]; then
        upx --lzma $(find /out/usr/bin/ -type f \
            -name 'protoc-gen-*' -or \
            -name 'grpc_*' \
        )
    fi
EOF
RUN find /out -name "*.a" -delete -or -name "*.la" -delete


FROM alpine:edge
COPY --from=upx /out/ /
COPY --from=protoc_gen_ts /out/ /
RUN apk add --no-cache \
    bash\
    grpc \
    protobuf \
    protobuf-dev \
    protobuf-c-compiler
RUN wget -q -O /etc/apk/keys/sgerrand.rsa.pub https://alpine-pkgs.sgerrand.com/sgerrand.rsa.pub \
    && wget https://github.com/sgerrand/alpine-pkg-glibc/releases/download/2.35-r0/glibc-2.35-r0.apk \
    && apk add glibc-2.35-r0.apk \
    && rm -f glibc-2.35-r0.apk
RUN <<EOF
ln -s /usr/bin/grpc_cpp_plugin /usr/bin/protoc-gen-grpc-cpp
ln -s /usr/bin/grpc_csharp_plugin /usr/bin/protoc-gen-grpc-csharp
ln -s /usr/bin/grpc_node_plugin /usr/bin/protoc-gen-grpc-js
ln -s /usr/bin/grpc_objective_c_plugin /usr/bin/protoc-gen-grpc-objc
ln -s /usr/bin/grpc_php_plugin /usr/bin/protoc-gen-grpc-php
ln -s /usr/bin/grpc_python_plugin /usr/bin/protoc-gen-grpc-python
ln -s /usr/bin/grpc_ruby_plugin /usr/bin/protoc-gen-grpc-ruby
ln -s /usr/bin/protoc-gen-go-grpc /usr/bin/protoc-gen-grpc-go
ln -s /usr/bin/protoc-gen-rust-grpc /usr/bin/protoc-gen-grpc-rust
EOF
COPY protoc-wrapper /usr/bin/protoc-wrapper
RUN <<EOF
mkdir -p /test
protoc-wrapper \
    --c_out=/test \
    --go_out=/test \
    --grpc-cpp_out=/test \
    --grpc-csharp_out=/test \
    --grpc-go_out=/test \
    --grpc-js_out=/test \
    --grpc-objc_out=/test \
    --grpc-php_out=/test \
    --grpc-python_out=/test \
    --grpc-ruby_out=/test \
    --grpc-web_out=import_style=commonjs,mode=grpcwebtext:/test \
    --js_out=import_style=commonjs:/test \
    --php_out=/test \
    --php-grpc_out=/test \
    --python_out=/test \
    --ruby_out=/test \
    --ts_out=/test \
    --validate_out=lang=go:/test \
    google/protobuf/any.proto
protoc-wrapper \
    --gogo_out=/test \
    google/protobuf/any.proto
rm -rf /test
EOF
ENTRYPOINT ["protoc-wrapper", "-I/usr/include"]
