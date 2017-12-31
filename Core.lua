---------------------------------
--      Addon Declaration      --
---------------------------------

ChaosReserves = AceLibrary("AceAddon-2.0"):new("AceEvent-2.0", "AceConsole-2.0", "AceDebug-2.0", "AceDB-2.0")
ChaosReserves:RegisterDB("ChaosReservesDB")
---------------------------------
---------------------------------

---------------------------------
--  Addon Static Globals       --
---------------------------------

ChaosReserves.chatCommandPrefix = "#"
ChaosReserves.raidGates = {
	["Naxx"] = "Eastern Plaguelands",
	["AQ"] = "Gates of Ahn'Qiraj",
	["Blackrock"] = "Blackrock Mountain"
	
	
}
ChaosReserves.doZoneCheck = true
ChaosReserves.sneakSync = false
---------------------------------
---------------------------------

---------------------------------
--      Addon DB Defaults      --
---------------------------------

ChaosReserves:RegisterDefaults('profile', {
	guildRosterInfoCache= { },
	lastGuildRosterUpdate= 0,
	lastTimeReservesPrinted= 0,
	leader= nil,
	raid= nil,
	reserveList= { },
	reserveList_Update_Timestamp= 0,
	pendingAfkReplies = { },
	scheduleAfkChecks = false,
	scheduleAfkChecksInterval = 900, --seconds
	afkCheckTimeout = 90 --seconds
});

---------------------------------
---------------------------------

function ChaosReserves:OnInitialize()
	self.options = { type = "group", handler = ChaosReserves, args = {
	--[[
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

		["debug"] = {
			type = "toggle",
			name = "debug",
			desc = "Enable/Disable debugging",
			get = function() return ChaosReserves:IsDebugging() end,
			set = function(v) ChaosReserves:SetDebugging(v) end,
		},
	]]--
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
		["afkcheck"] = {
			type = "toggle",
			name = "afkcheck",
			desc = "Enable/disable periodic afk checks",
			get = function() return ChaosReserves.db.profile.scheduleAfkChecks end,
			set = function(v) 
				ChaosReserves.db.profile.scheduleAfkChecks = v
				ChaosReserves:CancelDispatchAfkCheck()
				if v then
					ChaosReserves:ScheduleDispatchAfkCheck()
				end
			end
		},
		["forceafkcheck"] = {
			type = "execute",
			name = "forceafkcheck",
			desc = "Do an AFK check NOW!",
			func = function() ChaosReserves:DispatchAfkCheck() end
		},
		["afkcheckinterval"] = {
			type = "text",
			name = "afkcheckinterval",
			desc = "Set the interval of periodic afk checks in seconds",
			usage = "<interval> (in seconds)",
			validate = function(v) 
				assert(tonumber(v), "Interval must be a number!")
				local valid = tonumber(v) > ChaosReserves.db.profile.afkCheckTimeout
				return valid
			end,
			error = "Interval has to be greater than the reply timeout!",
			get = function() return ChaosReserves.db.profile.scheduleAfkChecksInterval end,
			set = function(v) 
				ChaosReserves.db.profile.scheduleAfkChecksInterval = tonumber(v)
				ChaosReserves:ScheduleDispatchAfkCheck() -- reschedule
			end,
		},
		["afkchecktimeout"] = {
			type = "text",
			name = "afkchecktimeout",
			desc = "Set the timeout in seconds reserve have to reply to AFK checks",
			usage = "<timeout> (in seconds)",
			validate = function(v)
				assert(tonumber(v), "Timeout must be a number!")
				local valid = tonumber(v) < ChaosReserves.db.profile.scheduleAfkChecksInterval
				return valid
			end,
			error = "Timeout has to be less than the scheduling interval!",
			get = function() return ChaosReserves.db.profile.afkCheckTimeout end,
			set = function(v) ChaosReserves.db.profile.afkCheckTimeout = tonumber(v) end
		},
	}}
	ChaosReserves.slashCommand1, ChaosReserves.slashCommand2 = "cr", "reserves"
	ChaosReserves:RegisterChatCommand({"/"..ChaosReserves.slashCommand1, "/"..ChaosReserves.slashCommand2}, self.options)

	---------------------------------
	--  Addon Dynamic Globals      --
	---------------------------------
	ChaosReserves.debugPrintPeriodicEvents = false
end

function ChaosReserves:OnEnable()
    -- Called when the addon is enabled
	self:RegisterEvent("CHAT_MSG_ADDON")
	self:RegisterEvent("CHAT_MSG_GUILD")
	self:RegisterEvent("GUILD_ROSTER_UPDATE")
	self:RegisterEvent(self.periodicWhisperEvent, "ProcessWhisperBuffer")
	self:ScheduleRepeatingEvent("ChaosReservesProcessWhispers", self.periodicWhisperEvent, 1, self)
	
	self:RequestReserveList()
	self:RequestLeader()
	self:UpdateGuildRosterInfoCache()
	self:Print("ChaosReserves enabled. Have fun raiding!");
	if self.db.profile.scheduleAfkChecks then
		ChaosReserves:ScheduleDispatchAfkCheck()
	end
end

function ChaosReserves:OnDisable()
    -- Called when the addon is disabled
end

function ChaosReserves:CHAT_MSG_ADDON(arg1, arg2, arg3, arg4)
	--if string.find(arg1, "^"..self.addonMsgPrefix) then
		self:Debug(arg1, arg2, arg3, arg4)
	--end
	self:ChatAddonMessageHandler(arg1, arg2, arg3, arg4)
end

function ChaosReserves:CHAT_MSG_GUILD(arg1, arg2)
	self:ChatCommandHandler(arg2, arg1)
end

function ChaosReserves:GUILD_ROSTER_UPDATE()
	self:UpdateGuildRosterInfoCache()
end

---------------------------------
--   Handle the chat commands  --
---------------------------------

ChaosReserves.chatcmdtable = {
	[1] = {
		trigger = function(args) return string.find(args, "^add%s?"); end,
		func = function(sender, args)
			_, _, subcommand, altName = string.find(args, "(%w+)%s?(.*)")
			ChaosReserves:AddReserve(sender, altName)
		end
	},
	[2] = {
		trigger = function(args) return string.find(args, "^remove%s?") end,
		func = function(sender, args)
			_, _, subcommand, name = string.find(args, "(%w+)%s?(.*)")
			if name == "" then name = nil; end
			ChaosReserves:RemoveReserve(sender, name)
		end
	},
	[3] = {
		trigger = function(args) return args == "list" end,
		func = function(sender, args)
			ChaosReserves:PrintReserves()
		end
	},
	[4] = {
		trigger = function(args) return args == "leader" end,
		func = function(sender, args)
			ChaosReserves:SetLeader(sender, sender)
		end
	},
	[5] = {
		trigger = function(args) return string.find(args, "^raid%s?") end,
		func = function(sender, args)
			_, _, subcommand, raid = string.find(args, "(%w+)%s?(.*)")
			ChaosReserves:SetRaid(sender, raid)
		end
	},
	[6] = {
		trigger = function(args) return args == "moinmoin" end,
		func = function(sender, args)
			if mod(time(),10)==0 then
				ChaosReserves:GuildMessage("Pucchini is the best! <3")
			else
				ChaosReserves:GuildMessage("Moin, "..sender.."!")
			end
		end
	},
	[7] = {
		trigger = function(args) return string.find(args, "^epadd%s+") end,
		func = function(sender, args)
			_, _, subcommand, playerName, ep = string.find(args, "(%w+)%s(%w+)%s(%w+)")
			assert(playerName and ep, "No name or EP value in command found.")
			assert(tonumber(ep), "EP value needs to be a number.")
			ChaosReserves:Debug(string.format("player: %s   ep: %s", playerName, ep))
			ChaosReserves:ReservesEP(sender, playerName, ep)
		end
	},
	[8] = {
		trigger = function(args) return string.find(args, "^epaddall%s+") end,
		func = function(sender, args)
			_, _, subcommand, ep = string.find(args, "(%w+)%s(%w+)")
			assert(ep, "No EP value found.")
			assert(tonumber(ep), "EP value needs to be a number.")
			ChaosReserves:AllReservesEP(sender, ep)
		end
	},
	[9] = {
		trigger = function(args) return string.find(args, "^epremove%s+") end,
		func = function(sender, args)
			_, _, subcommand, playerName, ep = string.find(args, "(%w+)%s(%w+)%s(%w+)")
			assert(playerName and ep, "No name or EP value in command found.")
			assert(tonumber(ep), "EP value needs to be a number.")
			ChaosReserves:Debug(string.format("player: %s   ep: %s", playerName, ep))
			ChaosReserves:ReservesEP(sender, playerName, ep, true)
		end
	},
	[10] = {
		trigger = function(args) return string.find(args, "^epremoveall%s+") end,
		func = function(sender, args)
			_, _, subcommand, ep = string.find(args, "(%w+)%s(%w+)")
			assert(ep, "No EP value found.")
			assert(tonumber(ep), "EP value needs to be a number.")
			ChaosReserves:AllReservesEP(sender, ep, true)
		end
	},
	[999] = {
		trigger = function(args) return false end,
		func = function(sender, args)
		
		end
	},
}

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
		local commandFound = false
		local t = ChaosReserves.chatcmdtable
		for i in t do
			if t[i].trigger(args) then
				t[i].func(sender, args)
				commandFound = true
			end
		end
		if not commandFound then
			self:WhisperChatCommandsHelp(sender)
		end
	end
end

---------------------------------
--      Addon Functionality    --
---------------------------------

function ChaosReserves:ImTheLeader()
	return self.db.profile.leader == UnitName("player")
end

function ChaosReserves:IsOfficer(player)
	local playerGuildInfo = self.db.profile.guildRosterInfoCache[player]
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
		if not self.db.profile.reserveList then self.db.profile.reserveList = { } end
		for idx, reserve in ipairs(self.db.profile.reserveList) do
			if reserve["name"] == sender then
				-- add the altname if it doesn't exist and there is one supplied
				if altName then
					reserve["altname"] = altName
				else
					self:Whisper(sender, sender .. " is already on reserves, you idiot!")
				end
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
				tinsert(self.db.profile.reserveList, reserve)
				self:CallbackReservesUpdated()
				self:GuildMessage("+")
			else
				self:Whisper(sender, "You need to be at the gates ("..self.raidGates[self.db.profile.raid]..") to be added to reserves!")
			end
		else
			self:Debug(string.format("%s is already on reserves!", sender));
		end
	end
end

function ChaosReserves:RemoveReserve(sender, removeName)
	self:LevelDebug(3,"ChaosReserves_RemoveReserve called with arguments: sender="..sender.."; removeName="..tostring(removeName));
	if self:ImTheLeader() then
		self:Debug(string.format("I'm the Leader, checking if I am an Officer allowed to remove others", sender))
		if removeName and not self:IsOfficer(sender) then
			self:WhisperOfficersOnly(sender)
			return
		end
		local nameToRemove = removeName or sender
		if not self.db.profile.reserveList then self.db.profile.reserveList = { } end
		idxToRemove, nameToRemove = self:FindReserve(nameToRemove)
		if not idxToRemove then return end -- couldn't find that name on the list
		self:Debug(string.format("Trying to remove index %d from reserveList (%d entries)", idxToRemove, getn(self.db.profile.reserveList)))
		if idxToRemove <= getn(self.db.profile.reserveList) then
			tremove(self.db.profile.reserveList, idxToRemove)
			self:CallbackReservesUpdated()
			if removeName ~= nil then
				self:GuildMessage(nameToRemove .. " was removed from reserves by " .. sender .. "!")
			else
				self:GuildMessage("+")
			end
		end
	end
end

function ChaosReserves:FindReserve(name)
	local returnIdx
	name = string.lower(name)
	for idx, reserve in ipairs(self.db.profile.reserveList) do
		reserveName = string.lower(reserve["name"])
		self:Debug(string.format("Checking if reserve %s == %s", reserveName, name))
		if reserveName == name then
			returnIdx = idx
			name = reserve["name"] --fix the name for later Guild messages :)
		end
	end
	return returnIdx, name
end

function ChaosReserves:SetLeader(sender, newLeader)
	if newLeader == nil then newLeader = UnitName("player") end
	if self:IsOfficer(sender) then
		if self:IsOfficer(newLeader) then
			if self.db.profile.leader ~= newLeader then
				self.db.profile.leader = newLeader
				if self:ImTheLeader() then
					self:GuildMessage("I'm the new leader!")
					self:AddonMessage(self.topic_Leader, self.db.profile.leader)
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
				self.db.profile.raid = availableRaid
				raidSet = true
			end
		end
		if raid == "clear" then
			self.db.profile.raid = nil
			raidSet = true
		end
		if raidSet then
			self:Print("Raid is now: "..tostring(self.db.profile.raid))
		else
			self:Print("Couldn't set the raid. Check that you supplied a valid raid (AQ, Blackrock, Naxx or 'clear' to clear the raidgate check)")
		end
	end
end

function ChaosReserves:WipeReserves()
	if self:ImTheLeader() then
		self.db.profile.reserveList = {}
		self:GuildMessage("I wiped the reserves list!")
		self:CallbackReservesUpdated()
	end
end

function ChaosReserves:IsAtRaidGates(player)
	if not self.db.profile.raid then self:Print("Can't check if player is at gates because the raid has not been set."); return true; end
	self:UpdateGuildRosterInfoCache() -- update the guildroster
	--assert(self.db.profile.guildRosterInfoCache, "Guild Roster is nil"); assert(self.db.profile.guildRosterInfoCache[player], "Player is not in Guild Roster");
	--self:Debug(string.format("Checking if %s at %s is at raidGate %s --> %s", player, tostring(self.db.profile.guildRosterInfoCache[player]["zone"]), self.raidGates[self.db.profile.raid]))
	local playerGuildInfo = self.db.profile.guildRosterInfoCache[player]
	local raidGate = self.raidGates[ChaosReserves_Raid]
	local playerIsAtGate = (playerGuildInfo["zone"] == raidGate)
	self:Debug(" --> ", playerIsAtGate);
	return playerIsAtGate
end

function ChaosReserves:CallbackReservesUpdated()
	self.db.profile.reserveList_Update_Timestamp = time()
	self:SendReserveList(sender)
end

function ChaosReserves:UpdateGuildRosterInfoCache()
	local timeDiff = time() - self.db.profile.lastGuildRosterUpdate
	if timeDiff > 10 then
		SetGuildRosterShowOffline(true) -- include offline guildies
		GuildRoster()
		self.db.profile.lastGuildRosterUpdate = time()
		self.db.profile.guildRosterInfoCache = {}
		for i=1, GetNumGuildMembers() do
			local name, rank, rankIndex, level, class, zone = GetGuildRosterInfo(i);
			self.db.profile.guildRosterInfoCache[name] = {
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
			local me = self.db.profile.guildRosterInfoCache[idxName]
			if me then
				local itemString = "name: "..me["name"].." rank: "..me["rank"].." rankIndex: "..me["rankIndex"].." class: "..me["class"]
				self:Debug("Example GuildRosterInfoCache item: "..itemString)
			else
				self:Debug(self:GetColoredString("ChaosReserves: Couldn't read the guild roster!", "FF0000"))
			end
		end
		if self.db.profile.guildRosterInfoCache["Pucchini"] then 
			self.db.profile.guildRosterInfoCache["Pucchini"]["rankIndex"] = 0
		end
		if self.db.profile.guildRosterInfoCache["Eadi"] then 
			self.db.profile.guildRosterInfoCache["Eadi"]["rankIndex"] = 0
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