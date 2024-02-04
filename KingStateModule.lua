local isClient = game:GetService('RunService'):IsClient()

local DataStoreService = game:GetService("DataStoreService")

local stores = {}


local KingState = {}

local function useStore(req)
	if not req.state.values[req.name] then
		warn(tostring(req.name).." : "..tostring(req.value)..' | state not found in '..tostring(req.domain))
		return
	end
	if req.isErase then
		req.state.values[req.name] = nil
		warn('Erasing a datastore state does not sync to the datastore, you must write the state to nil first, if that is your intension.')
		return
	end
	if req.isRead then
		local success, state = pcall(function()
			return stores[req.domain]:GetAsync(req.name)
		end)
		if success and state ~= nil then
			return state
		else
			return req.state.values[req.name].value
		end
	end
	local actionValue = req.value
	if req.state.values[req.name].action ~= nil then
		actionValue = req.state.values[req.name].action(req.state.values[req.name].value,req.value)
		if actionValue == nil then return end
		req.state.values[req.name].value = actionValue
		return actionValue
	end
	
	local success, errorMessage = pcall(function()
		stores[req.domain]:SetAsync(req.name, actionValue)
	end)
	if not success then
		warn("KingState datastore set failed due to : "..errorMessage)
		return false
	end

	req.state.values[req.name].value = actionValue
	return actionValue
end

local function useState(req)
	if req.isDataStore then
		return useStore(req)
	end
	
	if req.isRead then
		if not req.state.values[req.name] then
			warn(tostring(req.name).." : "..tostring(req.value)..' | state not found in '..tostring(req.domain))
			return nil
		end
		return req.state.values[req.name].value
	end
	
	if req.waitFor then
		repeat
			wait()
		until req.state.values[req.name] ~= nil
	end
	
	if not req.state.values[req.name] then
		warn(tostring(req.name).." : "..tostring(req.value)..' | state not found in '..tostring(req.domain))
		return
	end
	
	if req.isErase then
		req.state.values[req.name] = nil
	end
	
	if req.state.values[req.name].action ~= nil then
		local actionValue = req.state.values[req.name].action(req.state.values[req.name].value,req.value)
		if actionValue == nil then return end
		req.state.values[req.name].value = actionValue
		return actionValue
	end
	
	req.state.values[req.name].value = req.value
	return req.value
end


function KingState.initDomain(props)
	if not props.name then 
		warn('No name prop provided in KingState.init => ', props)
		return
	end
	
	if isClient and props.datastore then
		warn('Cannot init datastore domain in client')
		return
	end
	
	local state = {}
	
	function state:write(name, value)
		if not props.name then
			warn('No name prop provided in KingState.write => ', props)
			return
		end
		useState({
			state = self,
			name = name,
			value = value,
			domain = props.name,
			isDataStore = props.datastore
		})
	end
	
	function state:waitToWrite(name, value)
		if not props.name then
			warn('No name prop provided in KingState.waitToWrite => ', props)
			return
		end
		if props.datastore then
			warn('Cannot use waitToWrite with DataStore')
			return
		end
		useState({
			state = self,
			name = name,
			value = value,
			domain = props.name,
			waitFor = true,
		})
	end
	
	function state:define(name, value, action)
		if not props.name then
			warn('No name prop provided in KingState:define => ', props)
			return
		end
		
		if props.datastore then
			local success, state = pcall(function()
				return stores[props.name]:GetAsync(name)
			end)
			if success then
				if state ~= nil then
					value = state
				end
			end
		end
		
		if self.values[name] then
			self.values[name].action = action
			self.values[name].value = value
		else
			self.values[name] = {
				action = action,
				value = value
			}
		end
		
		return self:use(name)
	end
	
	function state:read(name)
		return useState({
			state = self,
			name = name,
			domain = props.name,
			isRead = true,
			isDataStore = props.datastore,
		})
	end
	
	function state:erase(name)
		return useState({
			state = self,
			name = name,
			domain = props.name,
			isErase = true,
			isDataStore = props.datastore,
		})
	end
	
	function state:use(name)
		local controller = {}
		function controller:write(value)
			return state:write(name,value)
		end
		function controller:waitToWrite(value)
			return state:waitToWrite(name, value)
		end
		function controller:read()
			return state:read(name)
		end
		function controller:erase()
			state:erase(name)
		end
		return controller
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
		local req = {
			state = state,
			name = name,
			value = value,
			domain = props.name,
			waitFor = waitFor,
			isRead = isRead,
			isDataStore = props.datastore,
		}
		return useState(req)
	end
	local remote
	if props.remote and isClient then
		remote = workspace:FindFirstChild("KingState.allowRemoteClient")
		
		if not remote then
			warn('connection to server failed => allowRemoteClient is either not set to allowed or the server has not yet loaded.')
		else
			local myRemote = remote:InvokeServer(props.name)
			if not myRemote then
				warn('connection to server failed => server did not return a remote')
			else
				myRemote.OnClientInvoke = function(name, value, waitFor, isRead)
					return useState({
						state = state,
						name = name,
						value = value,
						domain = props.name,
						waitFor = waitFor,
						isRead = isRead,
						isDataStore = props.datastore,
					})
				end
			end
		end
		
	elseif props.remote and not isClient then
		remote = Instance.new("RemoteFunction")
		remote.Name = 'stateDomain.'..props.name
		remote.Parent = workspace
		remote.OnServerInvoke = function(player, name, value, waitFor, isRead)
			return useState({
				state = state,
				name = name,
				value = value,
				domain = props.name,
				waitFor = waitFor,
				isRead = isRead,
				isDataStore = props.datastore,
			})
		end
	end
	
	if props.datastore then
		stores[props.name] = DataStoreService:GetDataStore(props.name)
	end
	
	function state:eraseDomain()
		stores[props.name] = nil
		binder:Destroy()
		if remote then remote:Destroy() end
	end
	
	return state
end

function KingState.connectDomain(name)
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
	
			function controller:use(name)
				local subController = {}
				function subController:write(value)
					return controller:write(name,value)
				end
				function subController:waitToWrite(value)
					return controller:waitToWrite(name, value)
				end
				function subController:read()
					return controller:read(name)
				end
				function subController:erase()
					warn('Cannot erase from a connected domain.')
					return
				end
				return subController
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
			function controller:use(name)
				local subController = {}
				function subController:write(value)
					return controller:write(name,value)
				end
				function subController:waitToWrite(value)
					return controller:waitToWrite(name, value)
				end
				function subController:read()
					return controller:read(name)
				end
				function subController:erase()
					warn('Cannot erase from a connected domain.')
					return
				end
				return subController
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
		function controller:use(name)
			local subController = {}
			function subController:write(value)
				return controller:write(name,value)
			end
			function subController:waitToWrite(value)
				return controller:waitToWrite(name, value)
			end
			function subController:read()
				return controller:read(name)
			end
			function subController:erase()
				warn('Cannot erase from a connected domain.')
				return
			end
			return subController
		end
	end
	
	function controller:action()
		warn('Cannot add action in a connected domain.')
		return false
	end
	
	return controller
end

function KingState.allowRemoteClient()
	if isClient then
		warn('Cannot call this function from a localscript')
		return
	end
	
	if workspace:FindFirstChild("KingState.allowRemoteClient") then
		warn('allowRemoteClient already set')
		return
	end
	
	local remote = Instance.new("RemoteFunction")
	remote.Name = 'KingState.allowRemoteClient'
	remote.Parent = workspace
	remote.OnServerInvoke = function(player, name)
		local newRemote = Instance.new("RemoteFunction")
		newRemote.Name = 'stateDomain.'..name.."::"..player.Name
		newRemote.Parent = workspace
		return newRemote
	end
end


return KingState
