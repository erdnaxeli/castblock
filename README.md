# CastBlock

Skip sponsor segments in YouTube videos playing on a Chromecast.

This project is inspired by [CastBlock by stephen304](https://github.com/stephen304/castblock).
It was rewritten in Crystal and uses the HTTP API exposed by [go-chromecast](https://github.com/vishen/go-chromecast) to be less CPU intensive.

The impact of CastBlock on the CPU should be almost zero, and only a few dozen of Mo on the memory.

## Installation

### Docker

```
docker pull erdnaxeli/castblock:latest
docker run --network="host" erdnaxeli/castblock
```

The docker image supports amd64 and arm architecture.
In particular it should run on all raspberry pi.
If not, please open an issue :)

### From source

You need to install [go-chromecast](https://github.com/vishen/go-chromecast) first, and to make it available in your PATH.
Then you need a working Crystal environment and run `shards build --release`.
The binary is in `./bin/castblock`.

## Usage

Run CastBlock in the same network as the Chromecast.

It will detect all Chromecast, watches their activity and skip any sponsor segment using the [SponsorBlock](https://sponsor.ajay.app/) API.

New devices are detected every 30s.
Segments shorter that 5s cannot be skipped. The last 20 videos' segments are cached to limit the number on queries on SponsorBlock.

If you have any issue, please run CastBlock with the `--debug` flag, try to reproduce your problem and past the output in your issue.
You can use the flag with docker too like this: `docker run --network="host" erdnaxeli/castblock --debug`.

## Contributing

1. Fork it (<https://github.com/erdnaxeli/castblock/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [erdnaxeli](https://github.com/erdnaxeli) - creator and maintainer
