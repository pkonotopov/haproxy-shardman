run:
	docker run -d -l app=loadbalancer --name haproxy --hostname haproxy --network sdmnet -p 15432:5432 -p 17001:7001 -v ${PWD}/conf:/etc/haproxy:ro --ip=172.88.1.200 arm64v8/haproxy-lua:0.0.1

build:
	docker buildx build --platform linux/arm64 -t arm64v8/haproxy-lua:0.0.1 -f Dockerfile .
rm:
	docker rm -f haproxy