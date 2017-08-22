#!/usr/bin/env lua5.3
server_root = "/home/_www"

if true then
	local socket = require("socket")
	local server = assert(socket.tcp())
	assert(server:bind("0.0.0.0",4),"Could not bind to port... are you root?",2)
	server:close()
end

loadfile(server_root.."/config/envvars")()

--The dir this is in, and the docs and config

function HTTPerror(id)
	if id == 400 then
		return luaparser(slurp(document_root.."/error/400.lua"))
	elseif id == 401 then
		return luaparser(slurp(document_root.."/error/401.lua"))
	elseif id == 404 then
		return luaparser(slurp(document_root.."/error/404.lua"))
	elseif id == 403 then
		return luaparser(slurp(document_root.."/error/403.lua"))
	elseif id == 405 then
		return luaparser(slurp(document_root.."/error/405.lua"))
	else
		return luaparser(slurp(document_root.."/error/super.lua"))
	end
end

function os.sleep(n)
	os.execute("sleep " .. tonumber(n))
end


function slurp(path)
    local f = io.open(path)
    if not f then
	return nil
    end
    local s = f:read("*a")
    f:close()
    return s
end

function escape_pattern(text)
	if text == nil then return nil end
	text = tostring(text)
	return text:gsub("%%","%%%1")
end

function luaparser(doc)
	while string.find(doc,"<%%") do
		--This glob selects and removes the <% and %> tags and tabs from the code
		local code = string.gsub(string.gsub(string.sub(doc,string.find(doc,"<%%.-%%>")),"	",""),"\n",";")
		code = string.gsub(code,"%%>","",1)
		code = string.gsub(code,"<%%","",1)
		local icode = load(code)
		if icode then icode = escape_pattern(icode()) else icode = "<!-- <%"..code.."%> -->" end
		if icode == nil then icode = "<!-- <%"..code.."%> -->" end
		doc = string.gsub(doc,"<%%.-%%>",icode,1)
	end
	return doc
end

function bash(cmd)
	return io.popen(cmd,r):read()
end

function getHTML(req)
	req = string.gsub(string.gsub(req,"GET ",""),string.match(req," HTTP.*$"),"")
	if req == "/" then req = req.."index.lua" end
	if slurp(document_root..req) == nil then return HTTPerror(404) end
	if string.match(req,".*.lua$") then 
		resp = luaparser(slurp(document_root..req)) else
		resp = slurp(document_root..req) end
	if resp == nil then return "HTTP/1.0 401 Bad Request" end
	if hsts then hsts_header = "Strict-Transport-Security: max-age=157680000; includeSubDomains\n" else hsts_header = "" end
	resp = ("HTTP/1.0 200 OK\nDate: "..os.date().."\n"..hsts_header.."Content-Type: text/html\nContent-Length: "..string.len(resp).."\n\n"..resp.."\n\n\n")
	return resp
end

function main()

local socket = require("socket")

--{{Options
---The port number for the HTTP server. Default is 80

--PORT=443
-- In the envvars

---The parameter backlog specifies the number of client connections
-- that can be queued waiting for service. If the queue is full and
-- another client attempts connection, the connection is refused.

--BACKLOG=5000
-- In the envvars

--}}Options

-- create a TCP socket and bind it to the local host, at any port
server=assert(socket.tcp())
io.write("Binding to port...")
os.sleep(2)
i=1 ; while server:bind(bind.addr,bind.port) == nil do ; if i == 0 then io.write(".") end ; i = (i + 1)%(10000) ; end ; local i=nil

io.write("\n") 
server:listen(BACKLOG)

-- Print IP and port
local ip, port = server:getsockname()
io.write("Listening on ",ip,":",port,".\n")

-- loop forever waiting for clients
if true then
local i = -1
while true do
	i=(i+1)%20000
	-- wait for a connection from any client
	client,err = server:accept()

	if client then
		io.write("Connection from ",tostring(client:getpeername()),".\n")
		local line, err = client:receive()
		-- if there was no error, send it back to the client
		if not err then
			if string.match(line,"GET.*") ~= nil then
				client:send(getHTML(line))
			else
				client:send(HTTPerror(400))
			end
		end

	else
		io.write("Error happened while connecting.\nError: ",err,"\n")
	end

	-- done with client, close the object
	client:close()
	if i == 0 then
		io.write("Memory usage: ",collectgarbage("count")," Kilobytes.\n")
	end
	collectgarbage()	
end
end
server:close()
end

main()
