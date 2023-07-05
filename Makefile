run:
	docker run -d -l app=loadbalancer --name haproxy --hostname haproxy --network shrnetwork -e SHARDMAN_BACKEND_PREFIX=shardman_node -e PGUSER=postgres -e PGPASSWORD=12345 -e PGDATABASE=postgres -p 15432:5432 -p 17001:7001 -v ${PWD}/conf:/etc/haproxy:ro --ip=172.21.0.200 arm64v8/haproxy-lua:0.0.1
# run:
# 	docker run -d -l app=loadbalancer --name haproxy --hostname haproxy --network sdmnet -p 15432:5432 -p 17001:7001 -v ${PWD}/conf:/etc/haproxy:ro --ip=172.88.1.200 arm64v8/haproxy-lua:0.0.1

build:
	docker buildx build --platform linux/arm64 -t arm64v8/haproxy-lua:0.0.1 -f Dockerfile .

rm:
	docker rm -f haproxy

restart: rm run

reload:
	docker exec -it haproxy sh -c 'echo "reload" | socat - /tmp/haproxy-master.sock'

logs:
	docker logs haproxy -f -n 50

tpcc-prepare:
	gotpc tpcc prepare --driver postgres --db postgres --host 172.21.0.200 --port 5432 --user postgres --password 12345 --conn-params sslmode=disable --warehouses 1 --dropdata --no-check -T 4
	gotpc tpch prepare --driver postgres --db postgres --host 172.21.0.200 --port 5432 --user postgres --password 12345 --conn-params sslmode=disable --analyze

tpcc-run:
	gotpc tpcc run --driver postgres --db postgres --host 172.21.0.200 --port 5432 --user postgres --password 12345 --conn-params sslmode=disable --max-procs 30 --warehouses 1 -T 30 --ignore-error