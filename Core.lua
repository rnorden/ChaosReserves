
---------------------------------
--      Addon Declaration      --
---------------------------------

ChaosReserves = AceLibrary("AceAddon-2.0"):new("AceEvent-2.0", "AceDebug-2.0", "AceConsole-2.0")
ChaosReserves.cmdtable =  {type = "group", handler = ChaosReserves, args = {
	["enable"] = {
		type = "execute",
		name = "enable",
		desc = "Enable the addon",
		args = {},
		func = function() ChaosReserves:OnEnable(); end
	},
	["disable"] = {
		type = "execute",
		name = "disable",
		desc = "Disable the addon",
		args = {},
		func = function() ChaosReserves:OnDisable(); end
	},
	["wipe"] = {
		type = "execute",
		name = "wipe",
		desc = "Wipe the reserve list",
		args = {},
		func = function() ChaosReserves:WipeReserves(); end
	},
	["list"] = {
		type = "execute",
		name = "list",
		desc = "List the current reserves",
		args = {},
		func = function() ChaosReserves:PrintReservesConsole(); end
	},
	["guildupdate"] = {
		type = "execute",
		name = "guildupdate",
		desc = "Update Guildroster cache",
		args = {},
		func = function() 
			ChaosReserves:Print("Updating Guildroster cache...")
			ChaosReserves:UpdateGuildRosterInfoCache()
			ChaosReserves:Print("Done!") 
		end
	},
	["dumpvars"] = {
		type = "execute",
		name = "dumpvars",
		desc = "Dump variables to the console",
		args = {},
		func = function() ChaosReserves:DumpVariables(); end
	},
	
}}
ChaosReserves.slashCommand1, ChaosReserves.slashCommand2 = "cr", "reserves"
ChaosReserves:RegisterChatCommand({"/"..ChaosReserves.slashCommand1, "/"..ChaosReserves.slashCommand2}, ChaosReserves.cmdtable)

function ChaosReserves:OnInitialize()
    self:SetDebugging(true) 
end

function ChaosReserves:OnEnable()
    -- Called when the addon is enabled
	self:RegisterEvent("CHAT_MSG_ADDON")
	self:RegisterEvent("CHAT_MSG_GUILD")
	self:RegisterEvent("GUILD_ROSTER_UPDATE")
	
	self:RequestReserveList()
	self:RequestLeader()
	self:UpdateGuildRosterInfoCache()
	self:Print("ChaosReserves enabled. Have fun raiding!");
end

function ChaosReserves:OnDisable()
    -- Called when the addon is disabled
end

function ChaosReserves:CHAT_MSG_ADDON(arg1, arg2, arg3, arg4)
	self:ChatAddonMessageHandler(arg1, arg2, arg3, arg4)
end

function ChaosReserves:CHAT_MSG_GUILD(arg1, arg2)
	self:ChatCommandHandler(arg2, arg1)
end

function ChaosReserves:GUILD_ROSTER_UPDATE()
	self:UpdateGuildRosterInfoCache()
end

---------------------------------
--      Addon Globals          --
---------------------------------

ChaosReserves.chatCommandPrefix = "#"
ChaosReserves.lastTimeReservesPrinted = 0
ChaosReserves.leader = nil

ChaosReserves.raidGates = {
	["Naxx"] = "Plaguewood",
	["AQ"] = "Gates of Ahn'Qiraj",
	["Blackrock"] = "Blackrock Mountain"
}
ChaosReserves.doZoneCheck = true
ChaosReserves.raid = nil

ChaosReserves.reserveList_Update_Timestamp = 0
ChaosReserves.reserveList = { }

ChaosReserves.lastGuildRosterUpdate = 0
ChaosReserves.guildRosterInfoCache = { }

---------------------------------
--   Handle the chat commands  --
---------------------------------

-- Handle the chat commands prefixed with !reserves
function ChaosReserves:ChatCommandHandler(sender, msg)
	self:LevelDebug(3,"ChaosReserves_ChatCommandHandler called with arguments: sender="..sender.." and msg="..msg)
	local _, _,command, args = string.find(msg, "^"..self.chatCommandPrefix.."(%w+)%s?(.*)");
	if command then
		command = strlower(command);
	else
		command = "";
	end
	if command == ChaosReserves.slashCommand1 or command == ChaosReserves.slashCommand2 then
		self:LevelDebug(3,"Chatcommand token detected")
		if (string.find(args, "add%s?")) then
			_, _, subcommand, altName = string.find(args, "(%w+)%s?(.*)")
			self:AddReserve(sender, altName)
		elseif (string.find(args, "remove%s?")) then
			_, _, subcommand, name = string.find(args, "(%w+)%s?(.*)")
			if name == "" then name = nil; end
			self:RemoveReserve(sender, name)
		elseif (args == "list") then
			self:PrintReserves()
		elseif (args == "leader") then
			self:SetLeader(sender, sender)
		elseif (string.find(args, "raid%s?")) then
			_, _, subcommand, raid = string.find(args, "(%w+)%s?(.*)")
			self:SetRaid(sender, raid)
		elseif (args == "moinmoin") then
			if mod(time(),10)==0 then
				self:GuildMessage("Pucchini is the best! <3")
			else
				self:GuildMessage("Moin, "..sender.."!")
			end
		else
			self:WhisperChatCommandsHelp(sender)
		end
	end
end

---------------------------------
--      Addon Functionality    --
---------------------------------

function ChaosReserves:ImTheLeader()
	return self.leader == UnitName("player")
end

function ChaosReserves:IsOfficer(player)
	local playerGuildInfo = self.guildRosterInfoCache[player]
	if playerGuildInfo ~= nil and playerGuildInfo["rankIndex"] < 2 then
		return true
	end
	return false
end

function ChaosReserves:AddReserve(sender, altName)
	assert(sender, "Sender may not be null")
	if self:ImTheLeader() then
		self:Debug(string.format("I'm the Leader, checking if %s is on reserves", sender))
		local exists = false
		if not self.reserveList then self.reserveList = { } end
		for idx, reserve in ipairs(self.reserveList) do
			if reserve["name"] == sender then
				self:Whisper(sender, sender .. " is already on reserves, you idiot!")
				exists = true
			end
		end
		if not exists then
			local isPlayerAtGates = self:IsAtRaidGates(sender)
			if self:IsDebugging() then
				self:Debug(string.format("%s is not on reserves!", sender))
				self:LevelDebug(2,string.format("DoZoneCheck? %s; IsAtGates(%s)? %s --> not %s or %s", 
					tostring(self.doZoneCheck), 
					sender, 
					tostring(isPlayerAtGates), 
					tostring(self.doZoneCheck), 
					tostring(isPlayerAtGates)
				))
			end
			if not self.doZoneCheck or isPlayerAtGates then
				local reserve = {}
				reserve["name"] = sender
				reserve["timeAdded"] = self:GetGameTime()
				if altName ~= "" then
					reserve["altname"] = altName
				end
				tinsert(self.reserveList, reserve)
				self:CallbackReservesUpdated()
				self:GuildMessage("+")
			else
				self:Whisper(sender, "You need to be at the gates ("..self.raidGates[self.raid]..") to be added to reserves!")
			end
		else
			self:Debug(string.format("%s is already on reserves!", sender));
		end
	end
end

function ChaosReserves:RemoveReserve(sender, name)
	self:LevelDebug(3,"ChaosReserves_RemoveReserve called with arguments: sender="..sender.."; removeName="..tostring(removeName));
	if self:ImTheLeader() then
		self:Debug(string.format("I'm the Leader, checking if I am an Officer allowed to remove others", sender))
		nameToRemove = "" --define variable here for scope...
		if removeName and not self:IsOfficer(sender) then
			self:WhisperOfficersOnly(sender)
			return
		end
		if not removeName or removeName == "" then nameToRemove = string.lower(sender) else nameToRemove = string.lower(removeName) end
		if not self.reserveList then self.reserveList = { } end
		idxToRemove = 1000
		for idx, reserve in ipairs(self.reserveList) do
			reserveName = string.lower(reserve["name"])
			self:Debug(string.format("Checking if reserve %s == %s", reserveName, nameToRemove))
			if reserveName == nameToRemove then
				idxToRemove = idx
				nameToRemove = reserve["name"] --fix the name for later Guild messages :)
			end
		end
		self:Debug(string.format("Trying to remove index %d from reserveList (%d entries)", idxToRemove, getn(self.reserveList)))
		if idxToRemove <= getn(self.reserveList) then
			tremove(self.reserveList, idxToRemove)
			self:CallbackReservesUpdated()
			if removeName ~= nil then
				self:GuildMessage(nameToRemove .. " was removed from reserves by " .. sender .. "!")
			else
				self:GuildMessage("+")
			end
		end
	end
end

function ChaosReserves:SetLeader(sender, newLeader)
	if newLeader == nil then newLeader = UnitName("player") end
	if self:IsOfficer(sender) then
		if self:IsOfficer(newLeader) then
			if self.leader ~= newLeader then
				self.leader = newLeader
				if self:ImTheLeader() then
					self:GuildMessage("I'm the new leader!")
					self:AddonMessage(self.topic_Leader, self.leader)
				end
			end
		end
	else
		self:WhisperOfficersOnly(sender)
	end
end

function ChaosReserves:SetRaid(sender, raid)
	if self:ImTheLeader() then
		raidSet = false
		for availableRaid, gate in pairs(self.raidGates) do
			if string.lower(availableRaid) == string.lower(raid)  then -- check that requested raid is available
				self.raid = availableRaid
				raidSet = true
			end
		end
		if raidSet then
			self:Print("Raid is now: "..self.raid)
		else
			self:Print("Couldn't set the raid. Check that you supplied a valid raid (AQ, Blackrock, Naxx)")
		end
	end
end

function ChaosReserves:WipeReserves()
	if self:ImTheLeader() then
		self.reserveList = {}
		self:GuildMessage("I wiped the reserves list!")
		self:CallbackReservesUpdated()
	end
end

function ChaosReserves:IsAtRaidGates(sender)
	if not self.raid then self:Print("Can't check if player is at gates because the raid has not been set."); return true; end
	self:UpdateGuildRosterInfoCache() -- update the guildroster
	local playerGuildInfo = self.guildRosterInfoCache[player]
	local raidGate = self.raidGates[ChaosReserves_Raid]
	local playerIsAtGate = (playerGuildInfo["zone"] == raidGate)
	self:Debug(string.format("Checking if %s at %s is at raidGate %s --> %s", player, playerGuildInfo["zone"], self.raidGates[self.raid], tostring(playerIsAtGate)))
	return playerIsAtGate
end

function ChaosReserves:CallbackReservesUpdated()
	self.reserveList_Update_Timestamp = time()
	self:SendReserveList(sender)
end

function ChaosReserves:UpdateGuildRosterInfoCache()
	local timeDiff = time() - self.lastGuildRosterUpdate
	if timeDiff > 10 then
		SetGuildRosterShowOffline(true) -- include offline guildies
		GuildRoster()
		self.lastGuildRosterUpdate = time()
		self.guildRosterInfoCache = {}
		for i=1, GetNumGuildMembers() do
			local name, rank, rankIndex, level, class, zone = GetGuildRosterInfo(i);
			self.guildRosterInfoCache[name] = {
				name = name,
				rank = rank,
				rankIndex = rankIndex,
				level = level,
				class = class,
				zone = zone
			}
		end
		if self:IsDebugging() then 
			local idxName = UnitName("player")
			local me = self.guildRosterInfoCache[idxName]
			if me then
				local itemString = "name: "..me["name"].." rank: "..me["rank"].." rankIndex: "..me["rankIndex"].." class: "..me["class"]
				self:Debug("Example GuildRosterInfoCache item: "..itemString)
			else
				self:Debug(self:GetColoredString("ChaosReserves: Couldn't read the guild roster!", "FF0000"))
			end
		end
	end
end

function ChaosReserves:GetGameTime()
	local h,m = GetGameTime()
	local s = self:GetCurrentTimeInUTC()
	if strlen(h) == 1 then h = "0"..h end
	if strlen(m) == 1 then m = "0"..m end
	if strlen(s) == 1 then s = "0"..s end
	return h..":"..m --..":"..s
end

---------------------------------------------------------
--Utility function to calculate the current datetime
-----------------------------------------------------------
function ChaosReserves:GetCurrentTimeInUTC()
	local _days={-1, 30, 58, 89, 119, 150, 180, 211, 242, 272, 303, 333, 364}
	local _lpdays={}
	for i=1,2  do _lpdays[i]=_days[i]   end
	for i=3,13 do _lpdays[i]=_days[i]+1 end
	local DSEC=24*60*60 -- secs in a day
	local YSEC=365*DSEC -- secs in a year
	local LSEC=YSEC+DSEC    -- secs in a leap year
	local FSEC=4*YSEC+DSEC  -- secs in a 4-year interval
	local BASE_DOW=4    -- 1970-01-01 was a Thursday
	local BASE_YEAR=1970    -- 1970 is the base year
    local y,j,m,d,w,h,n,s
    local mdays=_days
    t=time()
	s=t
    -- First calculate the number of four-year-interval, so calculation
    -- of leap year will be simple. Btw, because 2000 IS a leap year and
    -- 2100 is out of range, this formula is so simple.
    y=floor(s/FSEC)
    s=s-y*FSEC
    y=y*4+BASE_YEAR         -- 1970, 1974, 1978, ...
    if s>=YSEC then
        y=y+1           -- 1971, 1975, 1979,...
        s=s-YSEC
        if s>=YSEC then
            y=y+1       -- 1972, 1976, 1980,... (leap years!)
            s=s-YSEC
            if s>=LSEC then
                y=y+1   -- 1971, 1975, 1979,...
                s=s-LSEC
            else        -- leap year
                mdays=_lpdays
            end
        end
    end
    j=floor(s/DSEC)
    s=s-j*DSEC
    local m=1
    while mdays[m]<j do m=m+1 end
    m=m-1
    local d=j-mdays[m]
    -- Calculate day of week. Sunday is 0
    w=mod((floor(t/DSEC)+BASE_DOW),7)
    -- Calculate the time of day from the remaining seconds
    h=floor(s/3600)
    s=s-h*3600
    n=floor(s/60)
    s=s-n*60
	
	--return y.."-"..m.."-"..d.." "..h..":"..n..":"..s
	--return h..":"..n..":"..s
	return s
end