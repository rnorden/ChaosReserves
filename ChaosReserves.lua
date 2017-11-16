-- global static variables
ChaosReserves_SlashCommand = "reserves"
ChaosReserves_AddonMsgPrefix = "CHAOSRESERVES"
ChaosReserves_Topic_Leader = "LEADER"
ChaosReserves_Topic_Reservelist = "RESERVELIST"
ChaosReserves_TopicReservelist_Request = "REQUEST"
ChaosReserves_SerializationDelimiter = "§"
ChaosReserves_ReserveListSerializationDelimiter = "#"

-- changeable global variables
ChaosReserves_Disabled = true
ChaosReserves_debug = false

-- list of current reserves
ChaosReserves_ReserveList = {}
ChaosReserves_ReserveList_Update_Timestamp = 0

-- caching GuildRosterInfo
ChaosReserves_GuildRosterInfoCache = {}

-- this is the reserve manager (leader)
ChaosReserves_Leader = UnitName("player")

--debug function to print all local variables
function ChaosReserves_DumpVariables()
	Debug_Message("ChaosReserves_ReserveList: "..ChaosReserves_serializeReserveList(ChaosReserves_ReserveList_Update_Timestamp, ChaosReserves_ReserveList));
	Debug_Message("ChaosReserves_ReserveList_Update_Timestamp: "..ChaosReserves_ReserveList_Update_Timestamp);
	Debug_Message("ChaosReserves_Leader: "..ChaosReserves_Leader);
end

function ChaosReserves_InitGuildRosterInfoCache()
	ChaosReserves_GuildRosterInfoCache = {}
	SetGuildRosterShowOffline(true) -- include offline guildies
	for i=1, GetNumGuildMembers() do
		local name, rank, rankIndex, _, class = GetGuildRosterInfo(i);
		ChaosReserves_GuildRosterInfoCache[name] = {
			name = name,
			rank = rank,
			rankIndex = rankIndex,
			class = class
		}
	end
	if ChaosReserves_debug then 
		local idxName = UnitName("player")
		local me = ChaosReserves_GuildRosterInfoCache[idxName]
		if me then
			local itemString = "name: "..me["name"].." rank: "..me["rank"].." rankIndex: "..me["rankIndex"].." class: "..me["class"]
			Debug_Message("Example GuildRosterInfoCache item: "..itemString)
		else
			Debug_Message(ChaosReserve_GetColoredString("ChaosReserves: Couldn't read the guild roster!", "FF0000"))
		end
	end
end

ChaosReserves_ListenEvents = {
	"CHAT_MSG_ADDON", 
	"CHAT_MSG_GUILD", -- messages in guild chat
	"CHAT_MSG_SYSTEM", -- online/offline system messages
	--"GUILD_ROSTER_UPDATE", -- updates to the guild TODO: this is fired way too often, we need to switch to listening to system messages too.
}

function ChaosReserves_Init(f)	
	f:SetScript("OnEvent", function()
		ChaosReserves_EventHandlers(event)
	end
	)
	SLASH_CHAOSRESERVES1 = "/"..ChaosReserves_SlashCommand;
	SlashCmdList["CHAOSRESERVES"] = function(args) ChaosReserves_SlashHandler(args); end;
	Debug_Message("ChaosReserves loaded. Have fun raiding!");
	ChaosReserves_InitGuildRosterInfoCache()
	ChaosReserves_RequestReserveList()
end

function ChaosReserves_RegisterEvents(f, events)
	for i=1, getn(events) do
		f:RegisterEvent(events[i])
	end
end

function ChaosReserves_UnregisterEvents(f, events)
	for i=1, getn(events) do
		f:UnregisterEvent(events[i])
	end
end

-- Event handling
function ChaosReserves_EventHandlers(event)
	if ChaosReserves_Disabled then return end
	if event == "CHAT_MSG_ADDON" then
		ChaosReserves_ChatAddonMessageHandler(arg1, arg2, arg3, arg4)
	elseif event == "CHAT_MSG_GUILD" then
		ChaosReserves_ChatCommandHandler(arg2, arg1);
	elseif event == "CHAT_MSG_SYSTEM" then
		ChaosReserves_LoginLogoutHandler(arg1);
	elseif event == "CHANNEL_ROSTER_UPDATE" then
		ChaosReserves_InitGuildRosterInfoCache(); -- reinitialize the guild info cache
	end
end;

-- Handle the slash commands
function ChaosReserves_SlashHandler(arg1)
	if ChaosReserves_debug then Debug_Message("ChaosReserves_SlashHandler called"); end
	local _, _, command, args = string.find(arg1, "(%w+)%s?(.*)");
	if(command) then
		command = strlower(command);
	else
		command = "";
	end
	if(command == "enable") then
		ChaosReserves_Disabled = false;
		ChaosReserves_RegisterEvents(ChaosReserves_Frame, ChaosReserves_ListenEvents) -- start listening to events
		Debug_Message("ChaosReserves is now enabled!");
	elseif(command == "disable") then
		ChaosReserves_Disabled = true
		ChaosReserves_UnregisterEvents(ChaosReserves_Frame, ChaosReserves_ListenEvents) -- stop listening to events
		Debug_Message("ChaosReserves is now disabled! :-(");
	elseif(command == "debug") then
		ChaosReserves_debug = not ChaosReserves_debug
		if ChaosReserves_debug then
			Debug_Message("ChaosReserves is now in debugging mode!");
		else 
			Debug_Message("ChaosReserves debugging mode disabled.");
		end
	elseif(command == "dumpvars") then
		ChaosReserves_DumpVariables()
	else
		ChaosReserves_PrintSlashCommandsHelp()
	end
end

function ChaosReserves_PrintSlashCommandsHelp()
	local prefix = "   /"..ChaosReserves_SlashCommand.." "
	Debug_Message("Use the following commands:")
	Debug_Message(prefix.."enable - enable ChaosReserves")
	Debug_Message(prefix.."disable - disable ChaosReserves")
	Debug_Message(prefix.."debug - toggle debug mode on/off")
	Debug_Message(prefix.."dumpvars - dump some variables to your chatwindow")
end

-- Handle the chat commands prefixed with !reserves
function ChaosReserves_ChatCommandHandler(sender, msg)
	if ChaosReserves_debug then Debug_Message("ChaosReserves_ChatCommandHandler called with arguments: sender="..sender.." and msg="..msg); end
	local _, _,command, args = string.find(msg, "^!(%w+)%s?(.*)");
	if(command) then
		command = strlower(command);
	else
		command = "";
	end
	if(command == ChaosReserves_SlashCommand) then
		if ChaosReserves_debug then Debug_Message("Chatcommand token detected"); end
		if (string.find(args, "add%s?")) then
			_, _, subcommand, altName = string.find(args, "(%w+)%s?(.*)")
			ChaosReserves_AddReserve(sender, altName)
		elseif (string.find(args, "remove%s?")) then
			_, _, subcommand, name = string.find(args, "(%w+)%s?(.*)")
			if name == "" then name = nil; end
			ChaosReserves_RemoveReserve(sender, name)
		elseif (args == "list") then
			ChaosReserves_PrintReserves()
		elseif (args == "leader") then
			ChaosReserves_SetLeader(sender, nil)
		else
			ChaosReserves_WhisperChatCommandsHelp(sender)
		end
	elseif(command == "reserve") then
		ChaosReserves_Whisper(sender, "You are an idiot, "..sender.."! Use !"..ChaosReserves_SlashCommand.." "..args)
	end
end

function ChaosReserves_WhisperChatCommandsHelp(sender)
	ChaosReserves_Whisper(sender, "Use something like: ")
	local prefix = "   !"..ChaosReserves_SlashCommand.." "
	ChaosReserves_Whisper(sender, prefix.."add [altname] - add yourself with an optional altname if you're saving buffs")
	ChaosReserves_Whisper(sender, prefix.."remove - remove yourself")
	if ChaosReserves_isOfficer(sender) then
		ChaosReserves_Whisper(sender, prefix.."remove [name] - remove [name] from reserves")
		ChaosReserves_Whisper(sender, prefix.."force check - force an afk check")
		ChaosReserves_Whisper(sender, prefix.."leader - after sending this you will be the leader")
	end
	ChaosReserves_Whisper(sender, prefix.."help - show this help")
end

function ChaosReserves_LoginLogoutHandler(msg)
	if ChaosReserves_debug then Debug_Message("ChaosReserves_LoginLogoutHandler called with arguments: msg="..msg); end
	local player = ChaosReserves_findPlayerInOnlineOfflineMessage(msg)
	local status = ChaosReserves_findStatusInOnlineOfflineMessage(msg)
	if status == "online" or status == "offline" then -- short circuit abort if this is not an online/offline system message
		isGuildie = ChaosReserves_isPlayerInGuild(player)
		if isGuildie then
			if status == "online" then
				-- print reserves list and announce reserve manager
				ChaosReserves_PrintReserves()
				ChaosReserves_AnnounceLeader(player)
			elseif status == "offline" then
				-- notice player is offline
			end
		end
	end
end

function ChaosReserves_ChatAddonMessageHandler(prefix, message, channel, sender)
	-- is this message for me?
	local prefix = string.sub(arg1,1,strlen(ChaosReserves_AddonMsgPrefix))
	local topic = string.sub(arg1,strlen(ChaosReserves_AddonMsgPrefix)+1)
	if  (prefix == ChaosReserves_AddonMsgPrefix and ChaosReserves_isOfficer(UnitName("player"))) then
		if ChaosReserves_debug then Debug_Message("Received addon msg on topic ("..topic.."): "..string.sub(message,1,100)); end
		if (topic == ChaosReserves_Topic_Reservelist) then
			if (message == ChaosReserves_TopicReservelist_Request) then
				ChaosReserves_SendReserveList(sender)
			else
				ChaosReserves_ProcessIncomingReserveList(sender, message)
			end
		elseif (topic == ChaosReserves_Topic_Leader) then
			if ChaosReserves_debug then Debug_Message("Received leader message: "..string.sub(message,1,100)); end
			ChaosReserves_SetLeader(sender, message)
		end
	end
end

function ChaosReserves_RequestReserveList()
	ChaosReserves_AddonMessage(ChaosReserves_Topic_Reservelist, ChaosReserves_TopicReservelist_Request)
end

function ChaosReserves_SendReserveList(sender)
	if sender ~= UnitName("player") then -- dont answer your own request
		if ChaosReserves_debug then Debug_Message("Incoming reserve list request..."); end
		ChaosReserves_AddonMessage(ChaosReserves_Topic_Reservelist, ChaosReserves_serializeReserveList(ChaosReserves_ReserveList_Update_Timestamp, ChaosReserves_ReserveList))
		if ChaosReserves_debug then Debug_Message("Finished sending my reserve list!"); end
	end
end

function ChaosReserves_ProcessIncomingReserveList(sender, serializedReserveList)
	if sender ~= UnitName("player") then -- dont answer your own request
		if ChaosReserves_debug then Debug_Message("Incoming reserve list: "..serializedReserveList); end
		local timestamp, reserveList = ChaosReserves_deserializeReserveList(serializedReserveList)
		if (tonumber(timestamp) > tonumber(ChaosReserves_ReserveList_Update_Timestamp)) then -- the incoming reserveList is newer than what I have
			ChaosReserves_ReserveList_Update_Timestamp = tonumber(timestamp)
			ChaosReserves_ReserveList = reserveList
			Debug_Message("Updated reserve list with "..sender.."'s!")
		end
	end
end

function ChaosReserves_findPlayerInOnlineOfflineMessage(msg)
	local temp = msg
	string.gsub(temp, "|Hp[^|]*|h[^|]*|h", "|Hp[^|]*|h[^|]*|h")
	if ChaosReserves_debug then Debug_Message("Converted system msg to: "..temp); end
	local _, _, player = string.find(temp, "(%w+)")
	if player == "Hplayer" then _, _, player = string.find(temp, "Hplayer:(%w+)"); end -- workaround for hyperlinks in "[xxx] is now online." message...
	if ChaosReserves_debug then Debug_Message("Found in system message player="..tostring(player)); end
	return player
end

function ChaosReserves_findStatusInOnlineOfflineMessage(msg)
	local _, _, status = string.find(msg, "(%w+).$")
	if ChaosReserves_debug then Debug_Message("Found in system message status="..tostring(status)); end
	return status
end

function ChaosReserves_isPlayerInGuild(player)
	for key, _ in pairs(ChaosReserves_GuildRosterInfoCache) do
		if key == player then
			if ChaosReserves_debug then Debug_Message("Found player="..player.." in guild!"); end
			return true
		end
	end
	if ChaosReserves_debug then Debug_Message("Didn't find player="..player.." in guild!"); end
	return false
end

function ChaosReserves_SetLeader(sender, newLeader)
	if newLeader == nil then newLeader = UnitName("player") end
	if ChaosReserves_isOfficer(sender) then
		if ChaosReserves_isOfficer(newLeader) then
			if ChaosReserves_Leader ~= newLeader then
				ChaosReserves_Leader = newLeader
				if ChaosReserves_ImTheLeader() then
					ChaosReserves_GuildMessage("I'm the new leader!")
					ChaosReserves_AddonMessage(ChaosReserves_Topic_Leader, ChaosReserves_Leader)
				end
			end
		end
	else
		ChaosReserves_WhisperOfficersOnly(sender)
	end
end

function ChaosReserves_isOfficer(player)
	local playerGuildInfo = ChaosReserves_GuildRosterInfoCache[player]
	if playerGuildInfo ~= nil and playerGuildInfo["rankIndex"] < 2 then
		return true
	end
	return false
end

function ChaosReserves_ImTheLeader()
	return ChaosReserves_Leader == UnitName("player")
end

function ChaosReserves_WhisperOfficersOnly(sender)
	if sender == UnitName("player") then
		Debug_Message("You need to be of rank Lieutenant or higher to do this!")
	else
		if UnitLevel("player") < 10 then
			Debug_Message(sender.." needs to be of rank Lieutenant or higher to do this!")
		else
			ChaosReserves_Whisper(sender, "You need to be of rank Lieutenant or higher to do this!")
		end
	end
end

function ChaosReserves_AddReserve(sender, altName)
	if ChaosReserves_ImTheLeader() then
		local exists = false
		for idx, reserve in ipairs(ChaosReserves_ReserveList) do
			if reserve["name"] == sender then
				ChaosReserves_Whisper(sender, sender .. " is already on reserves, you idiot!")
				exists = true
			end
		end
		if not exists then
			local reserve = {}
			reserve["name"] = sender
			reserve["datetime"] = ChaosReserves_GetGameTime()
			if altName ~= "" then
				reserve["altname"] = altName
			end
			tinsert(ChaosReserves_ReserveList, reserve)
			ChaosReserves_CallbackReservesUpdated()
			ChaosReserves_PrintReserves()
		end
	end
end

function ChaosReserves_RemoveReserve(sender, removeName)
	if ChaosReserves_ImTheLeader() then
		if ChaosReserves_debug then Debug_Message("ChaosReserves_RemoveReserve called with arguments: sender="..sender.."; removeName="..tostring(removeName)); end
		idxToRemove = 1000
		if removeName and not ChaosReserves_isOfficer(sender) then
			ChaosReserves_WhisperOfficersOnly(sender)
			return
		end
		if not removeName or removeName == "" then nameToRemove = sender else nameToRemove = removeName end
		for idx, reserve in ipairs(ChaosReserves_ReserveList) do
			if reserve["name"] == nameToRemove then
				idxToRemove = idx
			end
		end
		if idxToRemove <= getn(ChaosReserves_ReserveList) then
			tremove(ChaosReserves_ReserveList, idxToRemove)
			ChaosReserves_CallbackReservesUpdated()
			if removeName ~= nil then
				ChaosReserves_GuildMessage(removeName .. " was removed from reserves by " .. sender .. "!")
			else
				ChaosReserves_GuildMessage(sender .. " removed himself/herself from reserves!")
			end
			ChaosReserves_PrintReserves()
		end
	end
end

function ChaosReserves_CallbackReservesUpdated()
	ChaosReserves_ReserveList_Update_Timestamp = time()
	ChaosReserves_SendReserveList(sender)
end

function ChaosReserves_PrintReserves()
	if ChaosReserves_ImTheLeader() then
		numberOfReserves = getn(ChaosReserves_ReserveList)
		msgString = "Current reserves (" .. numberOfReserves .. "): "
		if numberOfReserves > 0 then
			for idx, reserve in ipairs(ChaosReserves_ReserveList) do
				msgString = msgString .. ChaosReserves_getMainAndAltNameString(reserve) .. " (" .. reserve["datetime"] .. ")"
				if idx < numberOfReserves then
					-- more reserves in the list, add separator
					msgString = msgString .. ", "
				end
			end
		else
			msgString = msgString .. "None!"
		end
		ChaosReserves_GuildMessage(msgString)
	end
end

function ChaosReserves_AnnounceLeader(playerToGreet)
	if ChaosReserves_ImTheLeader() then
		--TODO ChaosReserves_Whisper(playerToGreet, "Hello "..playerToGreet.."! You're late to the raid but don't worry. Reserves are managed by "..ChaosReserves_Leader..". You can add yourself to reserves with !"..ChaosReserves_SlashCommand.." add");
	end
end

function ChaosReserves_getMainAndAltNameString(reserve)
	ret = reserve["name"]
	local playerGuildInfo = ChaosReserves_GuildRosterInfoCache[ret]
	class = nil; if playerGuildInfo then class = playerGuildInfo["class"]; end
	--ret = ChaosReserve_GetClickableLink(ret, ChaosReserve_GetColoredString(ret, ChaosReserves_GetColorCodeForClass(class))) --funktioniert nicht
	ret = ChaosReserve_GetColoredString(ChaosReserve_GetClickableLink(ret, ret), ChaosReserves_GetColorCodeForClass(class))
	if reserve["altname"] ~= nil then
	 ret = ret .."/"..reserve["altname"]
	end
	return ret
end

function ChaosReserve_GetClickableLink(link, text)
	return "\124Hplayer:"..link.."\124h"..text.."\124h"
end

function ChaosReserve_GetColoredString(str, colorCode)
	return "\124cff"..tostring(colorCode)..tostring(str).."\124r"
end

function ChaosReserves_GetColorCodeForClass(class)
	if class == "Druid" then
		return "FF7D0A"
	elseif class == "Hunter" then
		return "ABD473"
	elseif class == "Mage" then
		return "69CCF0"
	elseif class == "Paladin" then
		return "F58CBA"
	elseif class == "Priest" then
		return "FFFFFF"
	elseif class == "Rogue" then
		return "FFF569"
	elseif class == "Shaman" then
		return "0070DE"
	elseif class == "Warlock" then
		return "9482C9"
	elseif class == "Warrior" then
		return "C79C6E"
	else
		return "40FBf0" -- guild chat color as fallback
	end
end

function ChaosReserves_GuildMessage(msg)
	SendChatMessage(msg, "GUILD", nil, nil);
end

function ChaosReserves_Whisper(recipient, msg)
	SendChatMessage(msg, "WHISPER", nil, recipient)
end

function ChaosReserves_AddonMessage(topic, msg)
	SendAddonMessage(ChaosReserves_AddonMsgPrefix..topic, msg, "GUILD")
end

function Debug_Message(msg)
	DEFAULT_CHAT_FRAME:AddMessage(msg,1,1,0);
end

function ChaosReserves_GetGameTime()
	local h,m = GetGameTime()
	local s = getCurrentTimeInUTC()
	if strlen(h) == 1 then h = "0"..h end
	if strlen(m) == 1 then m = "0"..m end
	if strlen(s) == 1 then s = "0"..s end
	return h..":"..m..":"..s
end

function ChaosReserves_serializeReserveList(timestamp, reserveList)
	timeStampMap = {}
	timeStampMap["timestamp"] = timestamp
	serializedReserveList = ChaosReserves_serializeMap(timeStampMap) .. ChaosReserves_ReserveListSerializationDelimiter
	for _, reserve in ipairs(reserveList) do
		serializedReserveList = serializedReserveList .. ChaosReserves_serializeMap(reserve) .. ChaosReserves_ReserveListSerializationDelimiter
	end
	return serializedReserveList
end

function ChaosReserves_deserializeReserveList(serialize)
	reservelist = {}
	splitResultList = ChaosReserves_strsplit(serialize, ChaosReserves_ReserveListSerializationDelimiter)
	local timeStampKeyValuePair = ChaosReserves_deserializeMap(splitResultList[1])
	local timestamp = timeStampKeyValuePair["timestamp"]
	for i=2, getn(splitResultList) do
		reserve = ChaosReserves_deserializeMap(splitResultList[i])
		tinsert(reservelist, reserve)
	end
	return timestamp, reservelist
end

function ChaosReserves_serializeMap(map)
	serialize = ""
	for key, value in pairs(map) do
		serialize = serialize .. key .. "=" .. value .. ChaosReserves_SerializationDelimiter
	end
	return serialize
end

function ChaosReserves_deserializeMap(serialize)
	deserializedMap = {}
	splitResult = ChaosReserves_strsplit(serialize, ChaosReserves_SerializationDelimiter)
	for i=1, getn(splitResult) do
		keyValuePair = splitResult[i]
		keyValueSplit = ChaosReserves_strsplit(keyValuePair.."=", "=") --ugly hack, but it doesnt work without the concatenated "="
		deserializedMap[keyValueSplit[1]] = keyValueSplit[2]
	end
	return deserializedMap
end

function ChaosReserves_strsplit(pString, pPattern)
	local Table = {}
	local fpat = "(.-)" .. pPattern
	local last_end = 1
	local s, e, cap = string.find(pString, fpat, 1)
	while s do
		if s ~= 1 or cap ~= "" then
			table.insert(Table,cap)
		end
		last_end = e+1
		s, e, cap = strfind(pString, fpat, last_end)
	end
	if last_end <= strlen(pString) then
		cap = strfind(pString, last_end)
		table.insert(Table, cap)
	end
	return Table
end


---------------------------------------------------------
--Utility function to calculate the current datetime
-----------------------------------------------------------
function getCurrentTimeInUTC()
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

-- bootstrap the Addon by creating a frame and passing it to the ChaosReserves_Init function
ChaosReserves_Frame = CreateFrame("Frame",nil,UIParent)
ChaosReserves_Init(ChaosReserves_Frame)