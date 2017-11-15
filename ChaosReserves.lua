-- global variables
ChaosReserves_debug = true
ChaosReserves_SlashCommand = "reserves"
ChaosReserves_Disabled = false

-- list of current reserves
ChaosReserves_ReserveList = {}

-- caching GuildRosterInfo
ChaosReserves_GuildRosterInfoCache = {}

-- this is the reserve manager (leader)
ChaosReserves_Leader = UnitName("player")

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
		if ChaosReserves_debug then DEFAULT_CHAT_FRAME:AddMessage("Added to GuildRosterInfoCache: "..name,1,1,0); end
	end
	if ChaosReserves_debug then 
		local idxName = UnitName("player")
		local itemString = "name: "..ChaosReserves_GuildRosterInfoCache[idxName]["name"].." rank: "..ChaosReserves_GuildRosterInfoCache[idxName]["rank"].." rankIndex: "..ChaosReserves_GuildRosterInfoCache[idxName]["rankIndex"].." class: "..ChaosReserves_GuildRosterInfoCache[idxName]["class"]
		DEFAULT_CHAT_FRAME:AddMessage("Example GuildRosterInfoCache item: "..itemString,1,1,0)
	end
end

function ChaosReserves_Init(f)
	f:RegisterEvent("CHAT_MSG_ADDON");
	f:RegisterEvent("CHAT_MSG_GUILD"); -- messages in guild chat
	f:RegisterEvent("CHAT_MSG_SYSTEM"); -- online/offline system messages
	--f:RegisterEvent("GUILD_ROSTER_UPDATE"); -- updates to the guild TODO: this is fired way too often, we need to switch to listening to system messages too.
	f:SetScript("OnEvent", function()
		ChaosReserves_EventHandlers(event)
	end
	)
	SLASH_CHAOSRESERVES1 = "/"..ChaosReserves_SlashCommand;
	SlashCmdList["CHAOSRESERVES"] = function(args) ChaosReserves_SlashHandler(args); end;
	DEFAULT_CHAT_FRAME:AddMessage("ChaosReserves loaded. Have fun raiding!",1,1,0);
	ChaosReserves_InitGuildRosterInfoCache()
end

-- Event handling
function ChaosReserves_EventHandlers(event)
	if ChaosReserves_Disabled then return end
	if event == "CHAT_MSG_GUILD" then
		ChaosReserves_ChatCommandHandler(arg2, arg1);
	elseif event == "CHAT_MSG_SYSTEM" then
		ChaosReserves_LoginLogoutHandler(arg1);
	elseif event == "CHANNEL_ROSTER_UPDATE" then
		ChaosReserves_InitGuildRosterInfoCache(); -- reinitialize the guild info cache
	end
end;

-- bootstrap the Addon by creating a frame and passing it to the ChaosReserves_Init function
local f = CreateFrame("Frame",nil,UIParent)
ChaosReserves_Init(f)

-- Handle the slash commands
function ChaosReserves_SlashHandler(arg1)
	if ChaosReserves_debug then DEFAULT_CHAT_FRAME:AddMessage("ChaosReserves_SlashHandler called",1,1,0); end
	local _, _, command, args = string.find(arg1, "(%w+)%s?(.*)");
	if(command) then
		command = strlower(command);
	else
		command = "";
	end
	if(command == "enable") then
		ChaosReserves_Disabled = false;
		DEFAULT_CHAT_FRAME:AddMessage("ChaosReserves is now enabled!",1,1,0);
	elseif(command == "disable") then
		ChaosReserves_Disabled = true
		DEFAULT_CHAT_FRAME:AddMessage("ChaosReserves is now disabled! :-(",1,1,0);
	elseif(command == "debug") then
		ChaosReserves_debug = not ChaosReserves_debug 
		if ChaosReserves_debug then
			DEFAULT_CHAT_FRAME:AddMessage("ChaosReserves is now in debugging mode!",1,1,0);
		else 
			DEFAULT_CHAT_FRAME:AddMessage("ChaosReserves debugging mode disabled.",1,1,0);
		end
	else
		ChaosReserves_PrintSlashCommandsHelp()
	end
end

function ChaosReserves_PrintSlashCommandsHelp()
	local prefix = "   /"..ChaosReserves_SlashCommand.." "
	DEFAULT_CHAT_FRAME:AddMessage("Use the following commands:",1,1,0)
	DEFAULT_CHAT_FRAME:AddMessage(prefix.."enable - enable ChaosReserves",1,1,0)
	DEFAULT_CHAT_FRAME:AddMessage(prefix.."disable - disable ChaosReserves",1,1,0)
	DEFAULT_CHAT_FRAME:AddMessage(prefix.."debug - toggle debug mode on/off",1,1,0)
end

-- Handle the chat commands prefixed with !reserves
function ChaosReserves_ChatCommandHandler(sender, msg)
	if ChaosReserves_debug then DEFAULT_CHAT_FRAME:AddMessage("ChaosReserves_ChatCommandHandler called with arguments: sender="..sender.." and msg="..msg,1,1,0); end
	local _, _,command, args = string.find(msg, "(%w+)%s?(.*)");
	if(command) then
		command = strlower(command);
	else
		command = "";
	end
	if(command == ChaosReserves_SlashCommand) then
		if ChaosReserves_debug then DEFAULT_CHAT_FRAME:AddMessage("Chatcommand token detected",1,1,0); end
		if (string.find(args, "add%s?")) then
			_, _, subcommand, altName = string.find(args, "(%w+)%s?(.*)")
			ChaosReserves_AddReserve(sender, altName)
		elseif (string.find(args, "remove%s?")) then
			_, _, subcommand, name = string.find(args, "(%w+)%s?(.*)")
			ChaosReserves_RemoveReserve(sender, name)
		elseif (args == "list") then
			ChaosReserves_PrintReserves()
		else
			ChaosReserves_WhisperChatCommandsHelp(sender)
		end
	elseif(command == "reserve") then
		ChaosReserves_Whisper(sender, "You are an idiot, "..sender.."! Use !"..ChaosReserves_SlashCommand.." "..args)
	end
end

function ChaosReserves_WhisperChatCommandsHelp(sender)
	ChaosReserves_Whisper(sender, "Use something like: "
	local prefix = "   /"..ChaosReserves_SlashCommand.." "
	ChaosReserves_Whisper(sender, prefix.."add [altname] - add yourself with an optional altname if you're saving buffs")
	ChaosReserves_Whisper(sender, prefix.."remove - remove yourself")
	-- if sender then
	-- remove others
	-- force afk check
	--end
	ChaosReserves_Whisper(sender, prefix.."help - show this help")
end

function ChaosReserves_LoginLogoutHandler(msg)
	if ChaosReserves_debug then DEFAULT_CHAT_FRAME:AddMessage("ChaosReserves_LoginLogoutHandler called with arguments: msg="..msg,1,1,0); end
	local player = ChaosReserves_findPlayerInOnlineOfflineMessage(msg)
	local status = ChaosReserves_findStatusInOnlineOfflineMessage(msg)
	if status == "online" or status == "offline" then -- short circuit abort if this is not an online/offline system message
		isGuildie = ChaosReserves_isPlayerInGuild(player)
		if isGuildie then
			if status == "online" then
				-- print reserves list and announce reserve manager
				ChaosReserves_PrintReserves()
				ChaosReserves_AnnounceReserveManager(player)
			elseif status == "offline" then
				-- notice player is offline
			end
		end
	end
end

function ChaosReserves_findPlayerInOnlineOfflineMessage(msg)
	local temp = msg
	string.gsub(temp, "|Hp[^|]*|h[^|]*|h", "|Hp[^|]*|h[^|]*|h")
	if ChaosReserves_debug then DEFAULT_CHAT_FRAME:AddMessage("Converted system msg to: "..temp,1,1,0); end
	local _, _, player = string.find(temp, "(%w+)")
	if player == "Hplayer" then _, _, player = string.find(temp, "Hplayer:(%w+)"); end -- workaround for hyperlinks in "[xxx] is now online." message...
	if ChaosReserves_debug then DEFAULT_CHAT_FRAME:AddMessage("Found in system message player="..tostring(player),1,1,0); end
	return player
end

function ChaosReserves_findStatusInOnlineOfflineMessage(msg)
	local _, _, status = string.find(msg, "(%w+).$")
	if ChaosReserves_debug then DEFAULT_CHAT_FRAME:AddMessage("Found in system message status="..tostring(status),1,1,0); end
	return status
end

function ChaosReserves_isPlayerInGuild(player)
	for key, _ in pairs(ChaosReserves_GuildRosterInfoCache) do
		if key == player then
			if ChaosReserves_debug then DEFAULT_CHAT_FRAME:AddMessage("Found player="..player.." in guild!",1,1,0); end
			return true
		end
	end
	if ChaosReserves_debug then DEFAULT_CHAT_FRAME:AddMessage("Didn't find player="..player.." in guild!",1,1,0); end
	return false
end

function ChaosReserves_AddReserve(sender, altName)
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
		ChaosReserves_PrintReserves()
	end
end

function ChaosReserves_RemoveReserve(sender, removeName)
	local idxToRemove = 1000
	for idx, reserve in ipairs(ChaosReserves_ReserveList) do
		if reserve["name"] == removeName then
			idxToRemove = idx
		end
	end
	tremove(ChaosReserves_ReserveList, idxToRemove)
	if removeName ~= "" then
		ChaosReserves_GuildMessage(removeName .. " was removed from reserves by " .. sender .. "!")
	else
		ChaosReserves_GuildMessage(sender .. " removed himself/herself from reserves!")
	end
	ChaosReserves_PrintReserves()
end

function ChaosReserves_PrintReserves()
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

function ChaosReserves_AnnounceReserveManager(playerToGreet)
	local myName = UnitName("player")
	if ChaosReserves_Leader == myName then
		--TODO ChaosReserves_Whisper(playerToGreet, "Hello "..playerToGreet.."! You're late to the raid but don't worry. Reserves are managed by "..ChaosReserves_Leader..". You can add yourself to reserves with !"..ChaosReserves_SlashCommand.." add");
	end
end

function ChaosReserves_getMainAndAltNameString(reserve)
	ret = reserve["name"]
	class = ChaosReserves_GuildRosterInfoCache[ret]["class"]
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
	end
end

function ChaosReserves_GuildMessage(msg)
	SendChatMessage(msg, "GUILD", nil, nil);
end

function ChaosReserves_Whisper(recipient, msg)
	SendChatMessage(msg, "WHISPER", nil, recipient)
end

function ChaosReserves_GetGameTime()
	local h,m = GetGameTime()
	local s = getCurrentTimeInUTC()
	if strlen(h) == 1 then h = "0"..h end
	if strlen(m) == 1 then m = "0"..m end
	if strlen(s) == 1 then s = "0"..s end
	return h..":"..m..":"..s
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