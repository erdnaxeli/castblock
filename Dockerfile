FROM crystallang/crystal:1.0.0-alpine
WORKDIR /src
COPY shard.yml shard.lock /src/
RUN shards install --production
COPY src /src/src
RUN shards build --release --static

FROM golang:alpine
RUN go get -u github.com/vishen/go-chromecast@d2b4deefaef4c9f1a9859cb1334dbfaa9a1fbbb6

FROM alpine
RUN apk add tini
COPY --from=0 /src/bin/castblock /usr/bin/castblock
COPY --from=1 /go/bin/go-chromecast /usr/bin/go-chromecast
ENTRYPOINT ["/sbin/tini", "--", "/usr/bin/castblock"]
