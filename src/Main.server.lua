local apiConsumer = require(script.Parent.APIConsumer)
local warnLogger = require(script.Parent.Slogger)
warnLogger.init{postInit = table.freeze, logFunc = warn}
local tableWriter = require(script.Parent.TableWriter)
local glut = require(script.Parent.GLUt)

local runService = game:GetService("RunService")

type APIReference = apiConsumer.APIReference

local warn = warnLogger.new("StateWrangler")
glut.configure{ warn = warn }

local hookName = nil

local StateWrangler = {}

function StateWrangler.OnAPILoaded(api: APIReference, wranglerState)
	hookName = hookName or api.GetRegistrantFactory("Sprix", "StateWrangler")
	local hookData = {}
	wranglerState[1] = api.AddHook("PreSerialize", hookName("PreSerialize"), StateWrangler.OnPreSerialize, hookData)
	wranglerState[2] = api.AddHook("PreSerializeMissionSetup", hookName("PreSerializeMissionSetup"), StateWrangler.OnPreSerializeMissionSetup, hookData)
end

function StateWrangler.OnAPIUnloaded(api: APIReference, wranglerState)
	for _, token in ipairs(wranglerState) do
		api.RemoveHook(token)
	end
end

function StateWrangler.OnPreSerialize(callbackState, invokeState, mission: Folder)
	local warn = warn.specialize("OnPreSerialize")
	
	local first = true
	repeat
		if not first then coroutine.yield() end
		local _, present = invokeState.Get("Sprix_PrefabSystem_PreSerialize_Present")
		local success, done = invokeState.Get("Sprix_PrefabSystem_PreSerialize", "Done")
		first = false
	until (not present) or (success and done)
	
	local missionGlobalData = {}
	callbackState.MissionGlobals = missionGlobalData
	
	local missionGlobalFolder = mission:FindFirstChild("MissionGlobals")
	if missionGlobalFolder == nil then return end
	
	for _, child in missionGlobalFolder:GetDescendants() do
		if child:IsA("Folder") then continue end
		
		local warn = warn.specialize(`MissionGlobal {child.Parent}.{child} is invalid`)
		if not child:IsA("StringValue") then
			warn(`Expected type StringValue got {child.ClassName}`, "Value will be ignored")
			continue
		end
		
		local dest = child:GetAttribute("Destination") or "Globals"
		if type(dest) ~= "string" then
			warn(`Destination attribute found, but of unexpected type {type(dest)}`, "Destination will default to Globals")
			dest = "Globals"
		end
		
		missionGlobalData[child.Name] = {
			Destination = glut.str_split(dest, '.'),
			DestinationFull = dest,
			Value = child.Value
		}
	end
	
	missionGlobalFolder:Destroy()
end

function StateWrangler.OnPreSerializeMissionSetup(callbackState, invokeState, missionSetupScript)
	local warn = warn.specialize("OnPreSerializeMissionSetup")
	
	local success, missionSetup = pcall(function() return require(missionSetupScript) end)
	if not success then warn("Error while running MissionSetup", missionSetup) return end
	
	local missionGlobalData = callbackState.MissionGlobals
	if missionGlobalData == nil then return end
	
	for k, v in pairs(missionGlobalData) do
		local value = tostring(v.Value)
		local destFound, dest = glut.tbl_tryindex(missionSetup, unpack(v.Destination))
		local fullDest = v.DestinationFull
		
		if not destFound or not glut.typecheck(dest, "table") then
			warn(`Destination MissionSetup.{fullDest} is invalid - destination must be an already-existing table`, "StateValue will be skipped" )
			continue
		end
		if dest[k] ~= nil then
			warn(`StateWrangler instructed to set Globals.{k} = {v}, but a Global of the same name already exists`, "Global will be skipped")
			continue
		end
		
		print(`StateWrangler : Injecting MissionSetup.{fullDest}[\"{k}\"] = \"{value}\"`)
		dest[tostring(k)] = value
	end
	
	local newSrc = "return " .. tableWriter.write_tbl(missionSetup)
	missionSetupScript.Source = newSrc
end

apiConsumer.DoAPILoop(plugin, "InfiltrationEngine-StateWrangler", StateWrangler.OnAPILoaded, StateWrangler.OnAPIUnloaded)