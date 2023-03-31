local pgmoon = require("pgmoon")

local function pick_backend(txn)
  -- Match available backend
  local pg_backend_name = 'shardman_node'
  -- count init
  local picked_backend_count = -1

  for backend_name, v in pairs(core.backends) do
    -- Backend match with pg_backend_name
    if string.match(backend_name, pg_backend_name) then
      if (backend_name ~= 'MASTER') then
        -- Check if any server in shardman cluster has DOWN status
        -- Close connections to every backend

        for _, server in pairs(v.servers) do
          if server:get_stats()['status'] == 'DOWN' then
            picked_backend = 'none'
            break
          end
        end

        for server_name, server in pairs(v.servers) do
          -- Skip any server that is not UP.
          if server:get_stats()['status'] == 'UP' then
            -- if server:get_stats()['status'] ~= 'DOWN' then
            local tcp = core.tcp()
            tcp:settimeout(1)
            -- Connect to shardman node to get connection count
            -- We are checking here the number of connections of PG
            -- Not the haproxy backend connection!!!
            local sh_node = pgmoon.new({
              host = server_name,
              port = "5432",
              database = "postgres",
              user = "postgres",
              password = "12345"
            })

            local success, err = sh_node:connect()

            if err then
              print(err)
            end

            if success then
              local res, qerr = sh_node:query("select count(usename) as count from pg_stat_activity")

              if err then
                print(qerr)
              end

              if res then
                print(string.format("check backend %s, shardman node %s connections count :: %d", backend_name,
                server_name, res[1].count))
              end

              sh_node:disconnect()
              if (picked_backend_count == -1) then
                picked_backend_count = res[1].count
                picked_backend = backend_name
              else
                if (res[1].count < picked_backend_count) then
                  picked_backend_count = res[1].count
                  picked_backend = backend_name
                end
              end
            end
            tcp:close()
          else
            print('Socket connection failed')
          end
        end
      end
    end
    -- Set winner backend name to variable on the request.
    txn:set_var('req.pgbackend', picked_backend)
  end
  print(string.format('picked backend :: %s', picked_backend))
end

core.register_action('pick_backend', { 'tcp-req', 'http-req' }, pick_backend)
