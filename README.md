# KingState
A Lua Module for the Roblox Engine

try it: https://create.roblox.com/store/asset/16115485990/KingState%3Fkeyword=&pageNumber=&pagePosition=

The KingState module allows for an easy management of states and methods across scripts on both server and client.
Helping the developer to cut down on manually creating remote and bindable functions. And allowing easy access and replication of states across the game.

The module can be required in both scripts and local-scripts. All methods excluding "allowRemoteClient()" are the same between script and local-script.

## initDomain()

Place the KingState module in ReplicatedStorage so that it can be used by both server and client.

Require the module. Then initialize a new Domain like this:

```lua
local KingState = require(game.ReplicatedStorage.KingState)

local domain = KingState.initDomain({ name = 'myDomain' })

```

Defining a new state. You can add as many states as you like to a domain

```lua
local KingState = require(game.ReplicatedStorage.KingState)

local domain = KingState.initDomain({ name = 'myDomain' })

domain:define('myState')

```

You can also add action functions to a state. Actions will be called when the state changes. If you define a state multiple times it will add your new actions to the state. You can define as many actions as you would like, they will all be called when the state changes.

```lua
local KingState = require(game.ReplicatedStorage.KingState)

local domain = KingState.initDomain({ name = 'myDomain' })

domain:define('myState', function(currentValue, newValue) --the currentValue and the newValue of the state will be passed in
  print("myStateAction",currentValue,newValue)
end)

```

States can be read and written like so. If your are unsure a state has been defined in time. You can use waitToWrite which will wait for the state the exist before writing.

```lua
domain:write('myState', newValue)

domain:waitToWrite('myState', newValue)

local myStateValue = domain:read('myState')

domain:write('myState', domain:read('myState')+1) -- Example to increment a state value

```

## connectDomain()

A helpful feature of KingState is to be able to connect to domains across other scripts, even across client and server.
Connecting a domain works like this.

```lua
local otherScriptDomain = KingState.connectDomain('otherScriptDomain')

otherScriptDomain:write('DisplayMenu', false)

otherScriptDomain:waitToWrite('Sprint', true)

local vehicleSpeed = otherScriptDomain:read('vehicleSpeed')

```
>[!NOTE]
> You cannot define a state from a connected domain

## Connecting to a server domain from client

To connect to a server domain you must set the remote value to true when initializing the server domain. This setting will allow clients to connect to the domain.

### Server Script
```lua
local serverDomain = KingState.initDomain({ name = 'serverDomain', remote = true })
```
### Local Script
```lua
local serverDomain = KingState.connectDomain('serverDomain')
```

## Connecting to client domain from server

To connect to a client domain from a server script, you first need to call the allowRemoteClient function from the KingState.
Then set the remote setting to true in the client domain init.
Finally when connecting to the client domain, the player name has to be specified at the end after double colons "::"
Heres an example with both local script and server script:

### Server Script
```lua
local KingState = require(game.ReplicatedStorage.KingState)

KingState.allowRemoteClient()

game.Players.PlayerAdded:Connect(function(player)
	
	local theClientDomain = KingState.connectDomain('theClientDomain::'..player.Name)
	
	theClientDomain:waitToWrite('playerState', 'winner')
	
end)

```
### Local Script
```lua
local KingState = require(game.ReplicatedStorage.KingState)

local myDomain = KingState.initDomain({ name = 'theClientDomain', remote = true }) --remember to set remote to true

local playerState = myDomain:define('playerState', function(currentValue, newValue)
	print("playerStateAction ",currentValue,newValue)
end)

```

\
\
\
\
\
\
\
\
\




A simplified chart displaying how it works.
![Screenshot 2024-01-25 at 12 54 27 PM](https://github.com/NoahSpencerCode/KingState/assets/84402734/44ec9208-d0da-4f86-b0ac-ba731e207049)
