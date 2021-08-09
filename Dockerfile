FROM golang:1.15-alpine as php-grpc-server
RUN apk add --no-cache git \
    && git clone --depth=1 https://github.com/spiral/php-grpc.git /go/src/github.com/spiral/php-grpc \
    && cd /go/src/github.com/spiral/php-grpc/cmd/protoc-gen-php-grpc \
    && go build

FROM thethingsindustries/protoc:3
COPY --from=php-grpc-server /go/src/github.com/spiral/php-grpc/cmd/protoc-gen-php-grpc/protoc-gen-php-grpc /usr/bin/protoc-gen-php-grpc
