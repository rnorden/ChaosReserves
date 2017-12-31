---------------------------------
-- Communication globals       --
---------------------------------

ChaosReserves.addonMsgPrefix = "CHAOSRESERVES_"
ChaosReserves.topic_Leader = "LEADER"
ChaosReserves.topic_Leader_Request = "REQUEST"
ChaosReserves.topic_Reservelist = "RESERVELIST"
ChaosReserves.topic_Reservelist_Request = "REQUEST"
ChaosReserves.serializationDelimiter = "§"
ChaosReserves.reserveListSerializationDelimiter = "#"
ChaosReserves.whisperBuffer = { }
ChaosReserves.lastWhisperTime = 0
ChaosReserves.periodicWhisperEvent = "ChaosReservesPeriodicWhisper"

---------------------------------
-- Communication Events        --
---------------------------------

---------------------------------
-- Communication functionality --
---------------------------------

function ChaosReserves:AddonMessage(topic, msg)
	SendAddonMessage(self.addonMsgPrefix..topic, msg, "GUILD")
end

function ChaosReserves:GuildMessage(msg)
	assert(msg, "Message may not be nil")
	SendChatMessage(msg, "GUILD");
end

-- interface that will buffer whispers
function ChaosReserves:Whisper(pRecipient, pMsg)
	tinsert(ChaosReserves.whisperBuffer, { recipient = pRecipient, msg = pMsg })
end

function ChaosReserves:ProcessWhisperBuffer()
	if time()-self.lastWhisperTime >= 5 then
		if getn(self.whisperBuffer) > 0 then
			local i = 0
			repeat
				local data = tremove(self.whisperBuffer, 1);
				self:WhisperInternal(data.recipient, data.msg)
				i = i+1
			until i == 5 or getn(self.whisperBuffer) == 0
		end
	end
end

-- internal method that will send messages
function ChaosReserves:WhisperInternal(recipient, msg)
	if UnitLevel("player") > 10 then
		SendChatMessage(msg, "WHISPER", nil, recipient)
		self.lastWhisperTime = time()
	else
		self:GuildMessage("@"..recipient..": "..msg)
	end
end

function ChaosReserves:GuildMessageTable(msgTable)
	for _, msg in ipairs(msgTable) do
		assert(msg, "Message may not be nil")
		SendChatMessage(msg, "GUILD");
	end
end

function ChaosReserves:WhisperOfficersOnly(sender)
	if sender == UnitName("player") then
		self:Print("You need to be of rank Lieutenant or higher to do this!")
	else
		if UnitLevel("player") < 10 then
			self:Print(sender.." needs to be of rank Lieutenant or higher to do this!")
		else
			self:Whisper(sender, "You need to be of rank Lieutenant or higher to do this!")
		end
	end
end

function ChaosReserves:WhisperChatCommandsHelp(sender)
	commonCommandHelpTexts = {
		"add [altname] - add yourself with an optional altname if you're saving buffs",
		"list - list the current reserve list",
		"remove - remove yourself",
		"help - show this help",
	}
	officerCommandHelpTexts = {
		"remove [name] - remove [name] from reserves",
		"raid [raidname] - set the raid to enable zone checks",
		--"force check - force an afk check",
		"leader - after sending this you will be the leader",
		"ep[add/remove] [name] [EP] - add/remove [EP] from [name]",
		"ep[add/remove]all [EP] - add/remove [EP] from everyone on the list",
	}
	local prefix = "   "..self.chatCommandPrefix..self.slashCommand1.." "
	if sender == UnitName("player") then
		self:Print("Use something like: ")
		for txt in commonCommandHelpTexts do
			self:Print(prefix..commonCommandHelpTexts[txt])
		end
		if self:IsOfficer(sender) then
			for txt in officerCommandHelpTexts do
				self:Print(prefix..officerCommandHelpTexts[txt])
			end
		end
	else
		self:Whisper(sender, "Use something like: ")
		for txt in commonCommandHelpTexts do
			self:Whisper(sender, prefix..commonCommandHelpTexts[txt])
		end
		if self:IsOfficer(sender) then
			for txt in officerCommandHelpTexts do
				self:Whisper(sender, prefix..officerCommandHelpTexts[txt])
			end
		end
	end
end

function ChaosReserves:ChatAddonMessageHandler(prefix, message, channel, sender)
	-- is this message for me?
	local prefix = string.sub(arg1,1,strlen(self.addonMsgPrefix))
	local topic = string.sub(arg1,strlen(self.addonMsgPrefix)+1)
	if  (prefix == self.addonMsgPrefix and 
		-- do I sneak into the sync or am I legimitately an officer?
		(self.sneakSync or self:IsOfficer(UnitName("player")))) then
		self:LevelDebug(2,"Received addon msg on topic ("..topic.."): "..string.sub(message,1,100))
		if (topic == self.topic_Reservelist) then
			if (message == self.topic_Reservelist_Request) then
				self:SendReserveList(sender)
			else
				self:ProcessIncomingReserveList(sender, message)
			end
		elseif (topic == self.topic_Leader) then
			if message == self.topic_Leader_Request then
				self:LevelDebug(2,"Received leader request")
				self:SendLeader(sender)
			else
				self:LevelDebug(2,"Received leader message: "..string.sub(message,1,100))
				self:SetLeader(sender, message)			
			end
		end
	end
end

function ChaosReserves:RequestReserveList()
	self:AddonMessage(self.topic_Reservelist, self.topic_Reservelist_Request)
end

function ChaosReserves:RequestLeader()
	self:AddonMessage(self.topic_Leader, self.topic_Leader_Request)
end

function ChaosReserves:SendLeader()
	if not self.leader then return; end -- dont reply with empty leader
	if sender ~= UnitName("player") then -- dont answer your own request
		self:AddonMessage(self.topic_Leader, self.leader)
	end
end

function ChaosReserves:ProcessIncomingLeader(sender, leader)
	if sender ~= UnitName("player") then -- dont handle your own response
		self:SetLeader(sender, leader)
	end
end

function ChaosReserves:SendReserveList(sender)
	if not self.db.profile.reserveList or getn(self.db.profile.reserveList) == 0 then return; end -- dont reply with empty reserve list
	if sender ~= UnitName("player") then -- dont answer your own request
		self:LevelDebug(2,"Incoming reserve list request...")
		self:AddonMessage(self.topic_Reservelist, self:SerializeReserveList(self.db.profile.reserveList_Update_Timestamp, self.db.profile.reserveList))
		self:LevelDebug(2,"Finished sending my reserve list!")
	end
end

function ChaosReserves:ProcessIncomingReserveList(sender, serializedReserveList)
	if sender ~= UnitName("player") then -- dont handle your own response
		self:Debug(2,"Incoming reserve list: "..serializedReserveList)
		local timestamp, reserveList = self:DeserializeReserveList(serializedReserveList)
		if (tonumber(timestamp) > tonumber(self.db.profile.reserveList_Update_Timestamp)) then -- the incoming reserveList is newer than what I have
			self.db.profile.reserveList_Update_Timestamp = tonumber(timestamp)
			self.db.profile.reserveList = reserveList
			self:Print("Updated reserve list with "..sender.."'s!")
		end
	end
end

function ChaosReserves:SerializeReserveList(timestamp, reserveList)
	timeStampMap = {}
	timeStampMap["timestamp"] = timestamp
	serializedReserveList = self:SerializeMap(timeStampMap) .. self.reserveListSerializationDelimiter
	if not reserveList then reserveList = { } end
	for _, reserve in ipairs(reserveList) do
		serializedReserveList = serializedReserveList .. self:SerializeMap(reserve) .. self.reserveListSerializationDelimiter
	end
	return serializedReserveList
end

function ChaosReserves:DeserializeReserveList(serialize)
	reservelist = {}
	self:Debug("Trying to split by "..self.reserveListSerializationDelimiter.." : "..serialize)
	splitResultList = self:Strsplit(serialize, self.reserveListSerializationDelimiter)
	local timeStampKeyValuePair = self:DeserializeMap(splitResultList[1])
	local timestamp = timeStampKeyValuePair["timestamp"]
	for i=2, getn(splitResultList) do
		reserve = ChaosReserves:DeserializeMap(splitResultList[i])
		tinsert(reservelist, reserve)
	end
	return timestamp, reservelist
end

function ChaosReserves:SerializeMap(map)
	serialize = ""
	for key, value in pairs(map) do
		serialize = serialize .. key .. "=" .. value .. self.serializationDelimiter
	end
	return serialize
end

function ChaosReserves:DeserializeMap(serialize)
	deserializedMap = {}
	self:Debug("Trying to split by "..self.serializationDelimiter.." : "..serialize)
	splitResult = self:Strsplit(serialize, self.serializationDelimiter)
	for i=1, getn(splitResult) do
		keyValuePair = splitResult[i]
		self:Debug("Trying to split by ".."=".." : "..keyValuePair)
		keyValueSplit = self:Strsplit(keyValuePair.."=", "=") --ugly hack, but it doesnt work without the concatenated "="
		deserializedMap[keyValueSplit[1]] = keyValueSplit[2]
	end
	return deserializedMap
end

function ChaosReserves:Strsplit(pString, pPattern)
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