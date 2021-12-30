FROM crystallang/crystal:1.0.0-alpine
WORKDIR /src
COPY shard.yml shard.lock /src/
RUN shards install --production
COPY src /src/src
RUN shards build --release --static

FROM golang:alpine
RUN go get -u github.com/johnmurphyme/go-chromecast@v0.2.10.2

FROM alpine
RUN apk add tini
COPY --from=0 /src/bin/castblock /usr/bin/castblock
COPY --from=1 /go/bin/go-chromecast /usr/bin/go-chromecast
ENTRYPOINT ["/sbin/tini", "--", "/usr/bin/castblock"]
