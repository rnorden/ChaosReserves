
function ChaosReserves:AllReservesEP(sender, ep, negative)
	if not self:EPAddPreCheck(sender) then return end
	if negative then ep = ep * -1 end
	for _, reserve in ipairs(self.db.profile.reserveList) do
		if not self:AddReserveEP_Internal(sender, reserve["name"], ep) then
			self:Print("There was an error while adding EP to %s!", reserve["name"])
		end
	end
	self:Print(string.format("Finished adding %s EP.", ep))
end

function ChaosReserves:ReservesEP(sender, reserveName, ep, negative)
	if not self:EPAddPreCheck(sender) then return end
	if negative then ep = ep * -1 end
	if self:AddReserveEP_Internal(sender, reserveName, ep) then
		self:Print(string.format("Added %s reserve EP to %s!", ep, reserveName))
	else
		self:Print(string.format("Couldn't add EP to %s. Not on reserves?", reserveName))
	end
end

function ChaosReserves:AddReserveEP_Internal(sender, reserveName, ep)
	local reserve
	if self.db.profile.reserveList and getn(self.db.profile.reserveList) > 0 then
		idx, _ = self:FindReserve(reserveName)
		reserve = self.db.profile.reserveList[idx]
		if reserve then
			reserve["EP"] = (reserve["EP"] or 0) + ep
			if reserve["EP"] == 0 then
				reserve["EP"] = nil
			end
			return true
		else
			self:Debug("Couldn't find a reserve with name")
		end
	else
		self:Debug("Reserves are nil or empty")
	end
	return false
end

function ChaosReserves:EPAddPreCheck(sender)
	return self:IsOfficer(sender) and self:ImTheLeader()
end