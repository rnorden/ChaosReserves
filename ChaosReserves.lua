-- global variables
ChaosReserves_debug = false
ChaosReserves_SlashCommand = "/reserves"
ChaosReserves_Disabled = true

-- list of current reserves
ChaosReserves_ReserveList = {}


function ChaosReserves_Init(f)
	f:RegisterEvent("CHAT_MSG_ADDON");
	f:RegisterEvent("CHAT_MSG_GUILD"); -- messages in guild chat
	f:RegisterEvent("CHAT_MSG_SYSTEM"); -- online/offline system messages
	f:SetScript("OnEvent", function()
		ChaosReserves_EventHandlers(event)
	end
	)
	SLASH_CHAOSRESERVES1 = ChaosReserves_SlashCommand;
	SlashCmdList["CHAOSRESERVES"] = function(args) ChaosReserves_SlashHandler(args); end;
	DEFAULT_CHAT_FRAME:AddMessage("ChaosReserves loaded. Have fun raiding!",1,1,0);
end

-- Event handling
function ChaosReserves_EventHandlers(event)
	if ChaosReserves_Disabled then return end
	if event then
		if ChaosReserves_debug then DEFAULT_CHAT_FRAME:AddMessage("Event: "..tostring(event),1,1,0); end
	end
	if event == "CHAT_MSG_GUILD" then
		ChaosReserves_ChatCommandHandler(arg2, arg1);
	elseif event == "CHAT_MSG_SYSTEM" then
		ChaosReserves_LoginLogoutHandler(arg2, arg1);	
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
	end
end

-- Handle the chat commands prefixed with !reserves
function ChaosReserves_ChatCommandHandler(sender, msg)
	if ChaosReserves_debug then DEFAULT_CHAT_FRAME:AddMessage("ChaosReserves_ChatCommandHandler called",1,1,0); end
	local _, _,command, args = string.find(msg, "(%w+)%s?(.*)");
	if(command) then
		command = strlower(command);
	else
		command = "";
	end
	if(command == "reserves") then
		if ChaosReserves_debug then DEFAULT_CHAT_FRAME:AddMessage("Chatcommand token detected",1,1,0); end
		if (string.find(args, "add%s?")) then
			_, _, subcommand, altName = string.find(args, "(%w+)%s?(.*)")
			ChaosReserves_AddReserve(sender, altName)
		elseif (string.find(args, "remove%s?")) then
			_, _, subcommand, name = string.find(args, "(%w+)%s?(.*)")
			ChaosReserves_RemoveReserve(sender, name)
		elseif (args == "list") then
			ChaosReserves_PrintReserves()
		end
	end
end

function ChaosReserves_LoginLogoutHandler(sender, msg)

end

function ChaosReserves_AddReserve(sender, altName)
	local exists = false
	for idx, reserve in ipairs(ChaosReserves_ReserveList) do
		if reserve["name"] == sender then
			ChaosReserves_GuildMessage(sender .. " is already on reserves, you idiot!")
			exists = true
		end
	end
	
	if not exists then 
		local reserve = {}
		reserve["name"] = sender
		reserve["datetime"] = getCurrentTimeInUTC()
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
	if ChaosReserves_debug then DEFAULT_CHAT_FRAME:AddMessage("ChaosReserves_PrintReserves called",1,1,0); end
	numberOfReserves = getn(ChaosReserves_ReserveList)
	msgString = "Current reserves (" .. numberOfReserves .. "): "
	if numberOfReserves > 0 then
		for idx, reserve in ipairs(ChaosReserves_ReserveList) do
			msgString = msgString .. getMainAndAltNameString(reserve) .. " (" .. reserve["datetime"] .. ")"
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

function getMainAndAltNameString(reserve)
	ret = reserve["name"]
	if reserve["altname"] ~= nil then
	 ret = ret .."/"..reserve["altname"]
	end
	return ret
end

function ChaosReserves_GuildMessage(msg)
	SendChatMessage(msg, "GUILD", nil, nil);
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
	
	if strlen(h) == 1 then h = "0"..h end
	if strlen(n) == 1 then n = "0"..n end
	if strlen(s) == 1 then s = "0"..s end
	--return y.."-"..m.."-"..d.." "..h..":"..n..":"..s
	return h..":"..n..":"..s
end