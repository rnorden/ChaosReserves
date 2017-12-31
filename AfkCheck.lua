ChaosReserves.expectedAfkReply = "I am here %s"
ChaosReserves.afkCheckWhisperMessage = "AFK CHECK: whisper me '"..ChaosReserves.expectedAfkReply.."' within %s seconds to stay on reserves."
ChaosReserves.playerKickEvent = "ChaosReservesKick"
ChaosReserves.scheduledDispatchAfkCheckEvent = "ChaosReservesDispatchAfkCheck"

function ChaosReserves:ScheduleDispatchAfkCheck()
	if not ChaosReserves.db.profile.scheduleAfkChecks then
		self:Print("You disabled AFK checks, not enabling them now.")
	else
		self:CancelScheduledEvent(self.scheduledDispatchAfkCheckEvent)
		self:ScheduleRepeatingEvent(self.scheduledDispatchAfkCheckEvent, function() self:DispatchAfkCheck() end, self.db.profile.scheduleAfkChecksInterval, self)
	end
end

function ChaosReserves:CancelDispatchAfkCheck()
	self:CancelScheduledEvent(self.scheduledDispatchAfkCheckEvent)
	self:Print("Cancelled periodic AFK checks!")
end

function ChaosReserves:DispatchAfkCheck()
	for i, reserve in ipairs(self.db.profile.reserveList) do
		self:DispatchSingleAfk(reserve)
	end
	self:RegisterEvent("CHAT_MSG_WHISPER")
end

function ChaosReserves:DispatchSingleAfk(reserve)
	reserve["afkCheckSalt"] = math.random(1,100)
	reserve["lastAfkCheck"] = time()
	self.db.profile.pendingAfkReplies[reserve["name"]] = reserve
	self:Whisper(reserve["name"], string.format(self.afkCheckWhisperMessage, reserve["afkCheckSalt"], self.db.profile.afkCheckTimeout))
	self:Debug(string.format("Scheduling event %s to kick %s in %s", self.playerKickEvent..reserve["name"], reserve["name"], self.db.profile.afkCheckTimeout))
	self:ScheduleEvent(self.playerKickEvent..reserve["name"], function() self:DoAfkKick(reserve) end, self.db.profile.afkCheckTimeout, self)
end

function ChaosReserves:DoAfkKick(reserve)
	if self.db.profile.pendingAfkReplies[reserve["name"]] and self:FindReserve(reserve["name"]) then
		local msg = string.format("%s didn't reply to an AFK check in time.", reserve["name"])
		if reserve["EP"] then
			msg = string.format("%s You lose %s EP :(", msg, reserve["EP"])
		end
		self:RemoveReserve(self.db.profile.leader, reserve["name"])
		self:GuildMessage(msg)
	end
end

function ChaosReserves:HandleIncomingAfkReply(sender, msg)
	self:Debug(string.format("Incoming reply to AFK check from %s", sender))
	reserve = self.db.profile.pendingAfkReplies[sender]
	if reserve then
		self:Debug(string.format("Found %s in pending replies", sender))
		endOfReplyTimespan = reserve["lastAfkCheck"] + self.db.profile.afkCheckTimeout
		replyInTime = time() <= endOfReplyTimespan
		self:Debug(string.format("%s replied within %s seconds? %s", sender, self.db.profile.afkCheckTimeout, tostring(replyInTime)))
		if replyInTime then
			if string.find(msg, string.format(self.expectedAfkReply, reserve["afkCheckSalt"])) then
				self:Debug(string.format("Reply matched the required string given to %s, removing from pending replies", sender))
				self.db.profile.pendingAfkReplies[sender] = nil -- remove from pending replies
				self:Debug("Cancelling event "..self.playerKickEvent..reserve["name"])
				self:CancelScheduledEvent(self.playerKickEvent..reserve["name"]) -- cancel kick event
				self:Whisper(sender, "+")
			end
		end
	end
	-- stop listening to whispers when there are no pending replies left
	if getn(self.db.profile.pendingAfkReplies) == 0 then
		self:UnregisterEvent("CHAT_MSG_WHISPER")
	end
end

function ChaosReserves:CHAT_MSG_WHISPER(msg, sender)
	if string.find(msg, "I am here") then
		self:HandleIncomingAfkReply(sender, msg)
	end
end