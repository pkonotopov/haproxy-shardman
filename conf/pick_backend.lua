local pgmoon = require("pgmoon")

local function pick_backend(txn)
  -- Match available backend
  -- Set haproxy backend prefix name here

  -- local pg_backend_name_prefix = 'shardman_node'
  -- or we can use environment variables, i.e.
  -- export SHARDMAN_BACKEND_PREFIX=shardman_node
  
  local pg_backend_name_prefix = os.getenv('SHARDMAN_BACKEND_PREFIX')

  -- backends counter init
  local picked_backend_count = -1

  for backend_name, v in pairs(core.backends) do
    -- Backend match with pg_backend_name
    if string.match(backend_name, pg_backend_name_prefix) then
      if backend_name ~= 'MASTER' then
        for server_name, server in pairs(v.servers) do
          -- Skip any server that is not UP.
          if server:get_stats()['status'] == 'UP' then
            local tcp = core.tcp()
            tcp:settimeout(1)
            -- Connect to shardman node to get connection count
            -- We are checking here the number of connections to Postgres
            -- Not to the haproxy backend connections!

            -- get host:port here
            local host = server:get_addr():match '(.*):.*$'
            local port = server:get_addr():match '^.*:(.*)$'

            local sh_node = pgmoon.new({
              host = host,
              port = port,
              database = os.getenv('PGDATABASE'),
              user = os.getenv('PGUSER'),
              password = os.getenv('PGPASSWORD')
            })

            -- trying to connect
            local success, conn_err = sh_node:connect()

            -- if success then proceed with queries
            if success then
              -- check instance mode master/replica
              local rec, query_err = sh_node:query("select case when pg_is_in_recovery() = 'f' then 0 else 1 end as leader")
              if rec ~= nil then
                if rec[1].leader == 0 then
                  -- get connection count from instance              
                  local res, query_err = sh_node:query("select count(usename) as count from pg_stat_activity")
                  if res ~=nil then
                    local msg = string.format("haproxy backend: %s, shardman node: %s, active connections: %d", backend_name, server_name, res[1].count)
                    core.log(core.info, msg)
                    if (picked_backend_count == -1) then
                      picked_backend_count = res[1].count
                      picked_backend = backend_name
                    else
                      if (res[1].count < picked_backend_count) then
                        picked_backend_count = res[1].count
                        picked_backend = backend_name
                      end
                    end
                  else
                    local msg = string.format("backend: %s, shardman node: %s:%s query error: %s", backend_name, host, port, query_err)
                    core.log(core.err, msg)
                  end
                else
                  local msg = string.format("backend: %s, shardman node: %s:%s is replica, skipping", backend_name, host, port)
                  core.log(core.info, msg)
                end
              else
                local msg = string.format("backend: %s, shardman node: %s:%s, replica check query error: %s", backend_name, host, port, query_err)
                core.log(core.err, msg)
              end
            else
                local msg = string.format("backend: %s, shardman node: %s:%s connection error: %s", backend_name, host, port, conn_err)
                core.log(core.err, msg)
            end
            -- close connection to database
            sh_node:disconnect()
            -- close tpc connection
            tcp:close()
          end
        end
      end
    end
    -- Set winner backend name to variable on the request.
    txn:set_var('req.pgbackend', picked_backend)
  end
  if picked_backend_count == -1 then
    core.log(core.info, "no backends available")
  else
    local msg = string.format("picked backend: %s", picked_backend)
    core.log(core.info, msg)
  end
end

core.register_action('pick_backend', { 'tcp-req', 'http-req' }, pick_backend)
