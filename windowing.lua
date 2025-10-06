EventLoop:createWindow({
	title = "Hello, world",
	icon = { icon = "information" },
	cursor = { icon = "pointer" },
    show = "restore"
})

local function handleEvent(type, payload)
	if type == "window" then
		if payload["type"] == "close" then
			EventLoop:closeWindow(payload["target"]:id())
		end
	end
end

while EventLoop:isActive() do
	pcall(EventLoop.wait, EventLoop)

	local ok, event = pcall(EventLoop.pop, EventLoop)
	while ok and event ~= nil do
		handleEvent(event["type"], event["payload"])
		ok, event = pcall(EventLoop.pop, EventLoop)
	end
end

function OnSetup()
end

function OnUpdate()
end
