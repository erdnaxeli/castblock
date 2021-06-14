docker-all: docker docker-arm docker-aarch64

docker-arm:
	docker build --pull -t erdnaxeli/castblock:arm -f Dockerfile.arm .

docker-aarch64:
	docker build --pull -t erdnaxeli/castblock:aarch64 -f Dockerfile.aarch64 .

docker:
	docker build --pull -t erdnaxeli/castblock:amd64 .

docker-push-all:
	docker push erdnaxeli/castblock:arm
	docker push erdnaxeli/castblock:aarch64
	docker push erdnaxeli/castblock:amd64

docker-manifest:
	(test -d ${HOME}/.docker/manifests/docker.io_erdnaxeli_castblock-latest/ && rm -rv ${HOME}/.docker/manifests/docker.io_erdnaxeli_castblock-latest/) || true
	docker manifest create erdnaxeli/castblock:latest -a erdnaxeli/castblock:amd64 -a erdnaxeli/castblock:arm -a erdnaxeli/castblock:aarch64
	docker manifest push erdnaxeli/castblock:latest
