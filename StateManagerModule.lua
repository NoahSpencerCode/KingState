local isClient = game:GetService('RunService'):IsClient()


local StateManager = {}

local function useState(state, name, value, domain, waitFor, isRead)
	if isRead then
		if not state.values[name] then
			warn(tostring(name).." : "..tostring(value)..' | state not found in '..tostring(domain))
			return nil
		end
		return state.values[name].value
	end
	
	if waitFor then
		repeat
			wait()
		until state.values[name] ~= nil
	end
	
	if not state.values[name] then
		warn(tostring(name).." : "..tostring(value)..' | state not found in '..tostring(domain))
		return
	end
	
	for i,v in ipairs(state.values[name].actions) do
		v(state.values[name].value,value)
	end
	
	state.values[name].value = value
	return value
end

function StateManager.initDomain(props)
	if not props.name then 
		warn('No name prop provided in StateManager.init => ', props)
		return
	end
	
	local state = {}
	
	function state:write(name, value)
		if not props.name then
			warn('No name prop provided in StateManager.create => ', props)
			return
		end
		useState(self, name, value, props.name)
	end
	
	function state:waitToWrite(name, value)
		if not props.name then
			warn('No name prop provided in StateManager.create => ', props)
			return
		end
		useState(self, name, value, props.name, true)
	end
	
	function state:define(name, action)
		if not props.name then
			warn('No name prop provided in StateManager.create => ', props)
			return
		end
		
		if self.values[name] then
			table.insert(self.values[name].actions, action)
		else
			self.values[name] = {
				actions = {
					action
				}
			}
		end
		
		return self.values[name]
	end
	
	function state:read(name)
		return useState(self, name, false, props.name, false, true)
	end
	
	state.values = {}
	
	local dir = workspace
	
	if not isClient then
		dir = game.ServerScriptService
	end
	
	local binder = Instance.new("BindableFunction")
	binder.Name = 'stateDomain.'..props.name
	binder.Parent = dir
	binder.OnInvoke = function(name, value, waitFor, isRead)
		return useState(state, name, value, props.name, waitFor, isRead)
	end
		
	if props.remote and isClient then
		local remote = workspace:FindFirstChild("stateManager.allowRemoteClient")
		
		if not remote then
			warn('connection to server failed => allowRemoteClient is either not set to allowed or the server has not yet loaded.')
		else
			local myRemote = remote:InvokeServer(props.name)
			if not myRemote then
				warn('connection to server failed => server did not return a remote')
			else
				myRemote.OnClientInvoke = function(name, value, waitFor, isRead)
					return useState(state, name, value, props.name, waitFor, isRead)
				end
			end
		end
		
	elseif props.remote and not isClient then
		local remote = Instance.new("RemoteFunction")
		remote.Name = 'stateDomain.'..props.name
		remote.Parent = workspace
		remote.OnServerInvoke = function(player, name, value, waitFor, isRead)
			return useState(state, name, value, props.name, waitFor, isRead)
		end
	end
	
	return state
end

function StateManager.connectDomain(name)
	local dir = workspace
	
	if not isClient and not string.find(name, "::") then
		dir = game.ServerScriptService
	end
	
	local binder = dir:WaitForChild('stateDomain.'..name)
	
	local controller = {}
	
	if binder:IsA("RemoteFunction") then
		if isClient then
			function controller:write(name, value)
				binder:InvokeServer(name, value)
			end
			
			function controller:waitToWrite(name, value)
				binder:InvokeServer(name, value, true)
			end
			
			function controller:read(name)
				return binder:InvokeServer(name, false, false, true)
			end
			
		else
			local colon1,colon2 = string.find(binder.Name, "::")
			
			if not colon2 then
				warn('Could not find :: marker while searching for playertag')
			end
			
			local playerTag = string.sub(binder.Name,colon2+1,string.len(binder.Name))
			
			local player = game.Players:FindFirstChild(playerTag)
			
			if not playerTag or not player then
				warn("Tried to connect to client remote, but could not find player tag => "..playerTag)
				return
			end
			
			function controller:write(name, value)
				binder:InvokeClient(player, name, value)
			end
			
			function controller:waitToWrite(name, value)
				binder:InvokeClient(player, name, value, true)
			end
			
			function controller:read(name)
				return binder:InvokeClient(name, false, false, true)
			end
		end
	else
		function controller:write(name, value)
			binder:Invoke(name, value)
		end
		
		function controller:waitToWrite(name, value)
			binder:Invoke(name, value, true)
		end
		
		function controller:read(name)
			return binder:Invoke(name, false, false, true)
		end
	end
	
	function controller:define()
		warn('Cannot define in a connected domain.')
		return false
	end
	
	return controller
end

function StateManager.allowRemoteClient()
	if isClient then
		warn('Cannot call this function from a localscript')
		return
	end
	
	if workspace:FindFirstChild("stateManager.allowRemoteClient") then
		warn('allowRemoteClient already set')
		return
	end
	
	local remote = Instance.new("RemoteFunction")
	remote.Name = 'stateManager.allowRemoteClient'
	remote.Parent = workspace
	remote.OnServerInvoke = function(player, name)
		local newRemote = Instance.new("RemoteFunction")
		newRemote.Name = 'stateDomain.'..name.."::"..player.Name
		newRemote.Parent = workspace
		return newRemote
	end
end


return StateManager
