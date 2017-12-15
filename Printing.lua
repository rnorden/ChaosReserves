function ChaosReserves:PrintReservesConsole()
	for _, msg in ipairs(self:BuildReservesString()) do
		self:Print(msg)
	end
end

function ChaosReserves:PrintReserves()
	if self:ImTheLeader() then
		local timeDiff = time() - self.lastTimeReservesPrinted
		if timeDiff > 30 then
			self.LastTimeReservesPrinted = time()
			self:GuildMessageTable(self:BuildReservesString())
		end
	end
end

function ChaosReserves:BuildReservesString()
	local msgTable = { }
	local numberOfReserves = 0
	if self.reserveList then
		numberOfReserves = getn(self.reserveList)
	end
	local msgString = string.format("Current reserves (%d): ", numberOfReserves)
	if numberOfReserves > 0 then
		for idx, reserve in ipairs(self.reserveList) do
			tempMsgString = string.format("%s%s (%s) ", msgString, self:GetPrintName(reserve), reserve["timeAdded"])
			if idx < numberOfReserves then
				-- more reserves in the list, add separator
				tempMsgString = tempMsgString .. ", "
			end
			if (strlen(tempMsgString) > 255) then --prematurely send a message because there's a 255 char limit
				tinsert(msgTable, msgString)
				-- overwrite the existing msgString because it has been sent already
				msgString = string.format("%s (%s) ", self:GetPrintName(reserve), reserve["timeAdded"])
				if idx < numberOfReserves then
					-- more reserves in the list, add separator
					msgString = msgString .. ", "
				end
			else
				msgString = tempMsgString
			end
		end
	else
		msgString = msgString .. "None!"
	end
	tinsert(msgTable, msgString)
	return msgTable
end

function ChaosReserves:GetPrintName(reserve)
	ret = reserve["name"]
	local playerGuildInfo = self.GuildRosterInfoCache[ret]
	class = nil; if playerGuildInfo then class = playerGuildInfo["class"]; end
	ret = self:GetColoredString(self:GetClickableLink(ret, ret), ChaosReserves:GetColorCodeForClass(class))
	if reserve["altname"] ~= nil then
	 ret = ret .."/"..reserve["altname"]
	end
	return ret
end

function ChaosReserves:GetClickableLink(link, text)
	return "\124Hplayer:"..link.."\124h"..text.."\124h"
end

function ChaosReserves:GetColoredString(str, colorCode)
	return "\124cff"..tostring(colorCode)..tostring(str).."\124r"
end

function ChaosReserves:GetColorCodeForClass(class)
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

function ChaosReserves:DumpVariables()
	local longestKey = 0
	for key, value in pairs(ChaosReserves) do
		if strlen(key) > longestKey then
			longestKey = strlen(key)
		end
	end
	for key, value in pairs(ChaosReserves) do
		if type(value) == "string" or type(value) == "number" then
			self:Print(string.format("%s%s%s", key, string.rep("_",longestKey-strlen(key)+2), tostring(value)))
		end
	end
end