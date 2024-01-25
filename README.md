# StateManager
A Lua Module for the Roblox Engine

The StateManager module allows for an easy management of states and methods across scripts on both server and client.
Helping the developer to cut down on manually creating remote and bindable functions. And allowing easy access and replication of states across the game.

The module can be required in both scripts and local-scripts. All methods excluding "allowRemoteClient()" are the same between script and local-script.

## initDomain()

Place the StateManager module in ReplicatedStorage so that it can be used by both server and client.

require and the init a new Domain like this:

```lua
local StateManager = require(game.ReplicatedStorage.StateManager)

local domain = StateManager.initDomain({ name = 'myDomain' })

```

Defining a new state. You can add as many states as you like to a domain

```lua
local StateManager = require(game.ReplicatedStorage.StateManager)

local domain = StateManager.initDomain({ name = 'myDomain' })

domain:define('myState')

```

You can also add action functions to a state. Actions will be called when the state changes. If you define a state multiple times it will add your new actions to the state. You can define as many actions as you would like, they will all be called when the state changes.

```lua
local StateManager = require(game.ReplicatedStorage.StateManager)

local domain = StateManager.initDomain({ name = 'myDomain' })

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

A helpful feature of StateManager is to be able to connect to domains across other scripts, even across client and server.
connecting a state works like this.

```lua
local otherScriptDomain = StateManager.connectDomain('otherScriptDomain')

otherScriptDomain:write('DisplayMenu', false)

otherScriptDomain:waitToWrite('Sprint', true)

local vehicleSpeed = otherScriptDomain:read('vehicleSpeed')

```
note: you cannot define a state from a connected domain









A simplified chart displaying how it works.
![Screenshot 2024-01-25 at 12 54 27 PM](https://github.com/NoahSpencerCode/StateManager/assets/84402734/44ec9208-d0da-4f86-b0ac-ba731e207049)
