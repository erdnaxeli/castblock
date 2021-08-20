# CastBlock

Skip sponsor segments in YouTube videos playing on a Chromecast.

This project is inspired by [CastBlock by stephen304](https://github.com/stephen304/castblock).
It was rewritten in Crystal and uses the HTTP API exposed by [go-chromecast](https://github.com/vishen/go-chromecast) to be less CPU intensive.

The impact of CastBlock on the CPU should be almost zero, and only a few dozen of Mo on the memory.

## Installation

### Docker

```
docker pull erdnaxeli/castblock:latest
# Run CastBlock in foreground. Add -d after "run" to run it in background.
docker run --rm --network host erdnaxeli/castblock
```

The docker image supports amd64, arm and arm64 architectures.
In particular it should run on all raspberry pi.
If not, please open an issue :)

The amd64 and arm64 images are based on Alpine and weigh only 20Mo, but due to [a missing cross compilation target](https://github.com/crystal-lang/crystal/issues/5467) the arm images use Debian and weights 47Mo.

### From source

You need to install [go-chromecast](https://github.com/vishen/go-chromecast) first, and to make it available in your PATH.
Then you need a working Crystal environment and run `shards build --release`.
The binary is in `./bin/castblock`.

## Usage

Run CastBlock in the same network as the Chromecast.

It will detect all Chromecast, watch their activity and skip any sponsor segment using the [SponsorBlock](https://sponsor.ajay.app/) API.

New devices are detected every 30s.
Segments shorter that 5s cannot be skipped. The last 20 videos' segments are cached to limit the number on queries on SponsorBlock.

If you have any issue, please run CastBlock with the `--debug` flag, try to reproduce your problem and past the output in the issue.
You can use the flag with docker too like this: `docker run --rm --network host erdnaxeli/castblock --debug`.

Available options:

* `--debug`: run the app with the debug logs.
* `--offset`: set an offset to use before the end of the segment, in seconds.
  An offset of 2 means that it will seek 2s before the end of the segmend.
* `--category`: specify the [category of segments](https://github.com/ajayyy/SponsorBlock/wiki/Types#category) to skip.
  It can be repeated to specify many categories.
  Default to "sponsor".
* `--merge-threshold`: The maximum number of seconds between segments to be merged.
  Adjust this value to skip multiple adjacent segments that don't overlap.
* `--mute-ads`: enable auto mute during native YouTube ads. These are different
  from in-video sponsors, and are typically blocked by browser extension ad blockers.

All options can also be read from the environment variables:

* `DEBUG=true`
* `OFFSET=1`
* `CATEGORIES=sponsor,interaction`
* `MUTE_ADS=true`

## Contributing

1. Fork it (<https://github.com/erdnaxeli/castblock/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [erdnaxeli](https://github.com/erdnaxeli) - creator and maintainer
- [stephen304](https://github.com/stephen304) - contributor and ad blocking enthusiast
