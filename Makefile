SWIFT_BUILD_FLAGS=--configuration release

build:
	swift build -Xswiftc -enable-library-evolution -v $(SWIFT_BUILD_FLAGS)

clean:
	rm -rf .build

test:
	swift test -v

update:
	swift package update

profile: clean
	mkdir -p /tmp/spanker.stats
	swift build \
		--configuration release \
		-Xswiftc -stats-output-dir \
		-Xswiftc /tmp/spanker.stats \
		-Xswiftc -trace-stats-events \
		-Xswiftc -driver-time-compilation \
		-Xswiftc -debug-time-function-bodies

docker:
	-docker buildx create --name cluster_builder203
	-DOCKER_HOST=ssh://rjbowli@192.168.111.203 docker buildx create --name cluster_builder203 --platform linux/amd64 --append
	-docker buildx use cluster_builder203
	-docker buildx inspect --bootstrap
	-docker login
	docker buildx build --platform linux/amd64,linux/arm64 --push -t kittymac/spanker .
