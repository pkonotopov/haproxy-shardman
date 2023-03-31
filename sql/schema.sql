select shardman.broadcast_all_sql('create schema pgbench');

drop table if exists pgbench_accounts;
drop table if exists pgbench_branches;
drop table if exists pgbench_history;
drop table if exists pgbench_tellers;

CREATE TABLE if not exists pgbench_accounts (
    aid integer NOT NULL,
    bid integer,
    abalance integer,
    filler character(84)
)
WITH (distributed_by = 'aid', num_parts = 8);

CREATE TABLE if not exists pgbench_branches (
    bid integer NOT NULL,
    bbalance integer,
    filler character(88)
)
WITH (distributed_by = 'bid', num_parts = 8);

CREATE TABLE if not exists pgbench_history (
    tid integer,
    bid integer,
    aid integer,
    delta integer,
    mtime timestamp without time zone,
    filler character(22)
) WITH (distributed_by = 'aid', num_parts = 8);

CREATE TABLE if not exists pgbench_tellers (
    tid integer NOT NULL,
    bid integer,
    tbalance integer,
    filler character(84)
)
WITH (distributed_by = 'tid', num_parts = 8);

alter table pgbench_accounts ADD CONSTRAINT pgbench_accounts_pkey PRIMARY KEY (aid);
alter table pgbench_branches ADD CONSTRAINT pgbench_branches_pkey PRIMARY KEY (bid);
alter table pgbench_tellers ADD CONSTRAINT pgbench_tellers_pkey PRIMARY KEY (tid);
