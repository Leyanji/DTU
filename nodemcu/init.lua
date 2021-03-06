ip = "192.168.4.1"
svr = nil
chipId = string.format("%x",node.chipid())


tmr.alarm(0,2000,0,function()
require("config")
require("devConfig")
--print(server)
if(regCode~=nil) then
     regCodeShort =string.sub(regCode,-10,-1)
else
     regCodeShort = ""
end


function setupDefaultAp()
     print("start default ap")
     cfg={}
     cfg.ssid="DTU"
     if(regCode~=nil) then
          cfg.ssid="DTU-"..regCodeShort
     end
     cfg.pwd="12345678"
     if(wifi.ap.config(cfg))then
          print("AP is ON")
          setupServer()
     end
end

function trim(s)
  return (s:gsub("^%s*(.-)%s*$", "%1"))
end

local unescape = function (s)
     s = string.gsub(s, "+", " ")
     s = string.gsub(s, "%%(%x%x)", function (h)
          return string.char(tonumber(h, 16))
         end)
     return s
end


function setupServer()
     wifi.sta.getap(function(t)
          available_aps = ""
          --[[
          if t then
               local count = 0
               for k,v in pairs(t) do
                    ap = string.format("%-10s",k)
                    ap = trim(ap)
                    available_aps = available_aps .. "<option value='".. ap .."'"
                    if(ap == _G['ssid']) then available_aps = available_aps .. " selected=\"SELECTED\"" end
                    available_aps = available_aps ..">".. ap .."</option>"
                    count = count+1
                    if (count>=15) then break end
               end
               available_aps = available_aps .. "<option value='-1'>---hidden SSID---</option>"
          end
          ]]--
     if srv ~= nil then srv:close() end
     print("Setting up webserver")
     srv=net.createServer(net.TCP)
     srv:listen(80,function(conn)
     conn:on("receive", function(client,request)

          fetchFile = "wifi.html"
          local _, _, method, path, vars = string.find(request, "([A-Z]+) (.+)?(.+) HTTP");

          --if(method == nil)then
           _, _, method, path = string.find(request, "([A-Z]+) (.+) HTTP");
          --print(method,path,vars)
          if(path =="/dev") then
               fetchFile = "dev.html"
          elseif(path =="/info.xml") then
               fetchFile = "info.xml"
          end
          print("Send HTML File:"..fetchFile)
          --print(node.heap())
          if (file.open(fetchFile,'r')) then
               buf = file.read()
               file.close()
          end
          --end
          local _GET = {}
          configFile = "config.lua"
          if (vars ~= nil)then
               for k, v in string.gmatch(vars, "([_%w]+)=([^%&]+)&*") do
                    _GET[k] = unescape(v)
                    if(k=="server")then configFile = "devConfig.lua" end
               end
          end
          cfgContent = ""
          -- write every variable in the form
          for k,v in pairs(_GET) do
               cfgContent = cfgContent .. k..' = "'..v ..'"\r\n'
               _G[k]=v
          end
          if(cfgContent ~= "") then
               if(file.open(configFile, "w+")) then
                    --print("writing cfg:"..configFile)
                    file.write(cfgContent)
                    cfgContent = ""
                    file.close()
               end
          end

          if (_GET.password ~= nil) then
               if (_GET.ssid == "-1") then _GET.ssid=_GET.hiddenssid end
               --_G['html_head']="<meta http-equiv=\"refresh\" content=\"5;url=\\\">"
               --if(wifi.sta.status()~=5) then
                    _G['status']="Saved.Connecting..."
                    station_cfg={}
                    station_cfg.ssid=_GET.ssid
                    station_cfg.pwd=_GET.password
                    station_cfg.save=true
                    wifi.sta.config(station_cfg)
               --end
           end
           if(_G['status']=="Saved.Connecting...")then
               _G['html_head']="<meta http-equiv=\"refresh\" content=\"5;url=\\\">"
           end
          --node.compile("config.lua")
          --file.remove("config.lua")
          --client:send(buf);
          --node.restart();

          buf = buf:gsub('($%b{})', function(w)
               return _G[w:sub(3, -2)] or ""
          end)

          payloadLen = string.len(buf)
          client:send("HTTP/1.1 200 OK\r\n")
          --print("info:",info)
          if(info~="" and info~= nil) then
               client:send("Content-Type: text/xml\r\n")
          else
               client:send("Content-Type: text/html; charset=UTF-8\r\n")
               client:send("Content-Length:" .. tostring(payloadLen) .. "\r\n")
          end
          client:send("Connection:close\r\n\r\n")
          if(info~="" and info~= nil) then client:send(buf, function(client) client:close() end);
          --print(info)
          info = ""
          else client:send(buf, function(client) client:close() end);
          buf = nil
          end
          _G['html_head']=""
          _GET = nil
          --print(node.heap())
          end)
     end)
     print("Webserver ready: " .. ip)
     --print(node.heap())
     end)

end

function setupMonitor()
     wifi.eventmon.register(wifi.eventmon.STA_CONNECTED, function(T)
     print("\n\tSTA - CONNECTED".."\n\tSSID: "..T.SSID.."\n\tBSSID: "..
     T.BSSID.."\n\tChannel: "..T.channel)
     end)
     wifi.eventmon.register(wifi.eventmon.STA_DISCONNECTED, function(T)
          print("\n\tSTA - DISCONNECTED".."\n\tSSID: "..T.SSID.."\n\tBSSID: "..
          T.BSSID.."\n\treason: "..T.reason)
          _G['status']="wifi error code:"..T.reason
          wifi.sta.disconnect()
          setupDefaultAp()
          --restart in 5 min later
          tmr.alarm(0,300000,0,function()
               --wifi.sta.connect()
               node.restart()
          end)
     end)
     wifi.eventmon.register(wifi.eventmon.STA_GOT_IP, function(T)
     print("\n\tSTA - GOT IP".."\n\tStation IP: "..T.IP.."\n\tSubnet mask: "..
     T.netmask.."\n\tGateway IP: "..T.gateway)
     --_G['html_head']="<meta http-equiv=\"refresh\" content=\"25;url=http://"..T.IP.."\\\">"
     ip = T.IP
     _G['status']="wifi connected"
     require("upnp")
     tmr.alarm(0,30000,0,function()
          print("AP is OFF")
          wifi.setmode(wifi.STATION)
          require("dtu")
     end)
     setupServer()
     end)
     wifi.eventmon.register(wifi.eventmon.STA_DHCP_TIMEOUT, function()
     print("\n\tSTA - DHCP TIMEOUT")
     end)
     wifi.eventmon.register(wifi.eventmon.AP_STACONNECTED, function(T)
     print("\n\tAP - STATION CONNECTED".."\n\tMAC: "..T.MAC.."\n\tAID: "..T.AID)
     end)
     wifi.eventmon.register(wifi.eventmon.AP_STADISCONNECTED, function(T)
     print("\n\tAP - STATION DISCONNECTED".."\n\tMAC: "..T.MAC.."\n\tAID: "..T.AID)
     end)
end

wifi.setmode(wifi.STATIONAP)
setupMonitor()
ssid, password, bssid_set, bssid=wifi.sta.getconfig()

if(ssid==nil or ssid=="")then
     setupDefaultAp()
else
     print("Connectint AP")
     wifi.sta.connect()
     if(wifi.sta.getip()~=nil) then
          setupServer()
     end
end

end )
