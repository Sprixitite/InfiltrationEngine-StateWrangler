local apiConsumer = require(script.Parent.APIConsumer)
local warnLogger = require(script.Parent.Slogger)
warnLogger.init{postInit = table.freeze, logFunc = warn}
local tableWriter = require(script.Parent.TableWriter)

local runService = game:GetService("RunService")

type APIReference = apiConsumer.APIReference

local warn = warnLogger.new("StateWrangler")

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
		if not child:IsA("StringValue") then
			warn(`MissionGlobal {child.Parent}.{child} is invalid`, `Expected type StringValue got {child.ClassName}`)
		end
		missionGlobalData[child.Name] = child.Value
	end
	
	missionGlobalFolder:Destroy()
end

function StateWrangler.OnPreSerializeMissionSetup(callbackState, invokeState, missionSetupScript)
	local warn = warn.specialize("OnPreSerializeMissionSetup")
	
	local success, missionSetup = pcall(function() return require(missionSetupScript) end)
	if not success then warn("Error while running MissionSetup", missionSetup) return end
	
	local missionGlobalData = callbackState.MissionGlobals
	print(missionGlobalData)
	if missionGlobalData == nil then return end
	if missionSetup.Globals == nil then
		warn("MissionSetup has no Globals table, create one if needed!")
		return
	end
	
	for k, v in pairs(missionGlobalData) do
		if missionSetup.Globals[k] ~= nil then
			warn(`StateWrangler instructed to set Globals.{k} = {v}, but a Global of the same name already exists`, "Global will be skipped")
			continue
		end
		print(`Injecting Global {k} = {v}`)
		missionSetup.Globals[tostring(k)] = tostring(v)
	end
	
	local newSrc = "return " .. tableWriter.write_tbl(missionSetup)
	missionSetupScript.Source = newSrc
end

apiConsumer.DoAPILoop(plugin, "InfiltrationEngine-StateWrangler", StateWrangler.OnAPILoaded, StateWrangler.OnAPIUnloaded)