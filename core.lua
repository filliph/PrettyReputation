local ADDON_NAME = ...;
local Addon = LibStub("AceAddon-3.0"):NewAddon(select(2, ...), ADDON_NAME, "AceConsole-3.0", "AceEvent-3.0");

local GetFactionInfoByID = GetFactionInfoByID
local GetFriendshipReputation = C_GossipInfo.GetFriendshipReputation
local IsMajorFaction = C_Reputation.IsMajorFaction
local GetMajorFactionData = C_MajorFactions.GetMajorFactionData
local HasMaximumRenown = C_MajorFactions.HasMaximumRenown
local IsFactionParagon = C_Reputation.IsFactionParagon

local reputationColors = FACTION_BAR_COLORS

local private = {}
local factions = {}
local COLORS = {
    NAME = '|cffbbbbff',
    BAR_FULL = '|cff00ff00',
    BAR_EMPTY = '|cff666666',
    BAR_EDGE = '|cff00ffff',
    POSITIVE = '|cff00ff00',
    NEGATIVE = '|cffff0000'
}

local AddonDB_Defaults = {
    profile = {
        Reputation = {
            pattern = "[name] ([c_standing]): [c_change]/[c_session] ([currentPercent]) [bar]",
            barChar = "||",
            barLength = 20,
            showParagonCount = true
        }
    }
}

local function SetupFactions()
    for i=1, GetNumFactions() do
        local name, _, _, _, _, earnedValue, _, _, _, _, _, isWatched, _, factionId = GetFactionInfo(i)
        if (name) then
            if (factionId) and not factions[name] then
                factions[name] = { Id = factionId, Session = 0}
            end
        end
    end
end

local SEX = UnitSex("player")
local function GetFactionLabel(standingId)
	if standingId == "paragon" then
		return "Paragon"
	end
	if (standingId == "renown") then
		return "Renown"
	end
	return GetText("FACTION_STANDING_LABEL" .. standingId, SEX)
end

local function GetRepInfo(factionId)
    local name, standingId, bottomValue, topValue, barValue
    local showParagonCount = Addon.db.profile.Reputation.showParagonCount
    if (factionId and factionId ~= 0) then
        name, _, standingId, bottomValue, topValue, barValue = GetFactionInfoByID(factionId)

        if (IsMajorFaction(factionId)) then
			local data = GetMajorFactionData(factionId)
			local isCapped = HasMaximumRenown(factionId)
            if data then
                local current = isCapped and data.renownLevelThreshold or data.renownReputationEarned or 0
                local standingText = (RENOWN_LEVEL_LABEL .. data.renownLevel)
                if not isCapped then 
                    return name, current, data.renownLevelThreshold, reputationColors[10], standingText, bottomValue, topValue          
                end
    
                local currentValue, threshold, _, hasRewardPending = C_Reputation.GetFactionParagonInfo(factionId);
                local paragonLevel = (currentValue - (currentValue % threshold))/threshold
                if showParagonCount then
                    standingText = standingText .. " (" .. paragonLevel+1 .. ")"
                end
                if hasRewardPending then
                    standingText = standingText .. " |A:ParagonReputation_Bag:0:0|a" 
                end
                return name, mod(currentValue, threshold), threshold, reputationColors[10], standingText, bottomValue, topValue
            else
                return name, 0, 0, reputationColors[10], RENOWN_LEVEL_LABEL, bottomValue, topValue
            end 
		end

		if (standingId == nil) then
			return name, "0", "0", "|cFFFF0000", "??? - " .. (factionId .. "?"), "0", "0"
		end

		if (IsFactionParagon(factionId)) then
			local color = reputationColors[9]
			local currentValue, threshold, _, hasRewardPending = C_Reputation.GetFactionParagonInfo(factionId);
			local paragonLevel = (currentValue - (currentValue % threshold))/threshold
			local standingText = ""
			if showParagonCount then
				standingText = GetFactionLabel("paragon") .. " " .. paragonLevel+1
			else 
				standingText = GetFactionLabel("paragon") 
			end
			if hasRewardPending then
				if standingText then 
					standingText = standingText .. " |A:ParagonReputation_Bag:0:0|a" 
				else
					standingText = GetFactionLabel("paragon") .. " |A:ParagonReputation_Bag:0:0|a" 
				end
			end
			return name, mod(currentValue, threshold), threshold, color, standingText, bottomValue, topValue
		end

		local friendInfo = GetFriendshipReputation(factionId)
		if (friendInfo.friendshipFactionID and friendInfo.friendshipFactionID ~= 0) then
			local standingText = friendInfo.reaction
			local color = reputationColors[standingId] or reputationColors[5]
			local maximun, current = 1, 1
			if (friendInfo.nextThreshold) then
				maximun, current = friendInfo.nextThreshold - friendInfo.reactionThreshold, friendInfo.standing - friendInfo.reactionThreshold
			end
			return name, current, maximun, color, standingText, bottomValue, topValue
		end

        local current = barValue - bottomValue
        local maximun = topValue - bottomValue
        local color = reputationColors[standingId] or reputationColors[5]
        local standingText = GetFactionLabel(standingId)
        return name, current, maximun, color, standingText, bottomValue, topValue
	end
end

local function ConstructMessage(name, standingText, standingColor, negative, change, current, maximum, bottom, top, session)
    local message = Addon.db.profile.Reputation.pattern

    local message_name = COLORS.NAME .. name .. "|r"
    local message_standing = standingText
    local message_c_standing = standingColor .. message_standing .. "|r"
    local message_change =  (negative and "-" or "+") .. change
    local message_c_change = (negative and COLORS.NEGATIVE or COLORS.POSITIVE) .. change .. "|r"
    local message_session = ((session > 0) and "+" or "-") .. session
    local message_c_session = ((session > 0) and COLORS.POSITIVE or COLORS.NEGATIVE) .. session .. "|r"
    local message_current = current
    local message_next = maximum
    local message_bottom = bottom
    local message_top = top
    local message_toGo = (negative and ("-" .. current) or (maximum - current))
    local message_changePercent = format("%.1f%%%%", (change/maximum*100))
    local message_currentPercent = format("%.1f%%%%", (current/maximum*100))

    local barChar = Addon.db.profile.Reputation.barChar
    local barLen = Addon.db.profile.Reputation.barLength
    local bar = string.rep(barChar, barLen)
    local percentBar = math.floor((current/maximum*100) / (100/barLen))
    local percentBarText =  COLORS.BAR_FULL .. string.sub(bar, 0, percentBar * 2) .. "|r" .. COLORS.BAR_EMPTY .. string.sub(bar, percentBar * 2 + 1) .. "|r"
    local message_bar = COLORS.BAR_EDGE .. "[|r" .. percentBarText .. COLORS.BAR_EDGE .. "]|r"  

    message = string.gsub(message, "%[name%]", message_name)
    message = string.gsub(message, "%[standing%]", message_standing)
    message = string.gsub(message, "%[c_standing%]", message_c_standing)
    message = string.gsub(message, "%[change%]", message_change)
    message = string.gsub(message, "%[c_change%]", message_c_change)
    message = string.gsub(message, "%[session%]", message_session)
    message = string.gsub(message, "%[c_session%]", message_c_session)
    message = string.gsub(message, "%[current%]", message_current)
    message = string.gsub(message, "%[next%]", message_next)
    message = string.gsub(message, "%[bottom%]", message_bottom)
    message = string.gsub(message, "%[top%]", message_top)
    message = string.gsub(message, "%[toGo%]", message_toGo)
    message = string.gsub(message, "%[changePercent%]", message_changePercent)
    message = string.gsub(message, "%[currentPercent%]", message_currentPercent)
    message = string.gsub(message, "%[bar%]", message_bar)

    return message
end

local fsInc = FACTION_STANDING_INCREASED:gsub("%%d", "([0-9]+)"):gsub("%%s", "(.*)")
local fsInc2 = FACTION_STANDING_INCREASED_ACH_BONUS:gsub("%%d", "([0-9]+)"):gsub("%%s", "(.*)"):gsub(" %(%+.*%)" ,"")
local fsInc3 = FACTION_STANDING_INCREASED_GENERIC:gsub("%%s", "(.*)"):gsub(" %(%+.*%)" ,"")
local fsDec = FACTION_STANDING_DECREASED:gsub("%%d", "([0-9]+)"):gsub("%%s", "(.*)")
function private.ReputationChanged(eventName, msg)
    msg = msg:gsub(" %(%+.*%)" ,"")
    local faction, value, neg, updated = msg:match(fsInc)
    if not faction then
        faction, value, neg, updated = msg:match(fsInc2)
        if not faction then
            faction = msg:match(fsInc3)
            if not faction then
                faction, value = msg:match(fsDec)
                if not faction then return end
                neg = true
            end
        end
    end
    if tonumber(faction) then faction, value = value, tonumber(faction) else value = tonumber(value) end

    if not factions[factions] then
        SetupFactions()
    end

    if factions[faction] then
        local factionId = factions[faction].Id
        local session = factions[faction] and (factions[faction].Session + (value * ((neg and -1 or 1)))) or 0
        factions[faction].Session = session
        local name, current, maximum, color, standingText, bottom, top = GetRepInfo(factionId)
        if name then
            local standingColor = ("|cff%.2x%.2x%.2x"):format(color.r*255, color.g*255, color.b*255)
            print(ConstructMessage(name, standingText, standingColor, neg, value, current, maximum, bottom, top, session ))
        end
    end
end

function Addon:OnInitialize()
    SetupFactions()
end

function Addon:OnEnable()
	Addon:RegisterEvent("CHAT_MSG_COMBAT_FACTION_CHANGE", private.ReputationChanged)
    Addon.db = LibStub("AceDB-3.0"):New(ADDON_NAME .. "DB", AddonDB_Defaults, true) -- set true to prefer 'Default' profile as default
end
