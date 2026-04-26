local addonName, addon = ...
addon = addon or {}
_G[addonName] = addon

addon.name = addonName
addon.Bags = addon.Bags or {}
addon.Bags.functions = addon.Bags.functions or {}
addon.Bags.variables = addon.Bags.variables or {}
addon.functions = addon.functions or {}

function addon.Bags.IsEnabled()
	return addon.db and addon.db.enableBagsModule == true
end

function addon.Bags.functions.Enable()
	if addon.InitializeSavedVariables then
		addon.InitializeSavedVariables()
	end
	if addon.Bags.functions.EnableMain then
		addon.Bags.functions.EnableMain()
	end
	if addon.Bags.functions.EnableBank then
		addon.Bags.functions.EnableBank()
	end
end

function addon.Bags.functions.Disable()
	if addon.Bags.functions.HideFrame then
		addon.Bags.functions.HideFrame()
	end
	if addon.Bags.functions.HideBankFrame then
		addon.Bags.functions.HideBankFrame()
	end
end

addon.DB = addon.DB or {}
addon.DB.frame = addon.DB.frame or {}
addon.DB.settings = addon.DB.settings or {}
addon.DB.moneyTracker = addon.DB.moneyTracker or {}
addon.DB.warbandGold = addon.DB.warbandGold or 0
addon.savedVariablesLoaded = addon.savedVariablesLoaded or false
addon.savedVariablesAreNew = addon.savedVariablesAreNew or false

local CATEGORY_MODE_DEFAULTS = {
	customCategories = {},
	customGroups = {},
	hiddenBuiltInCategories = {},
	nextCustomCategoryID = 0,
	nextCustomGroupID = 0,
	nextCustomCategoryNodeID = 0,
	nextCustomCategorySortOrder = 0,
	presetVersionApplied = 0,
}

local INTEGRATED_DEFAULTS_VERSION = 1

local defaultSettings = {
	manualVisible = false,
	showCategories = true,
	compactCategoryLayout = true,
	compactCategoryGap = 8,
	combineFreeSlots = true,
	combineUnstackableItems = true,
	outerPadding = 10,
	headerPadding = 0,
	outsideHeaderPadding = 0,
	outsideFooterPadding = 10,
	insideHorizontalPadding = 10,
	insideTopPadding = 10,
	insideBottomPadding = 0,
	itemScale = 100,
	maxColumns = 10,
	showGold = true,
	showCurrencies = true,
	showFooterSlotSummary = false,
	footerSummaryPadding = 0,
	skinPreset = "default",
	iconShape = "default",
	frameBackground = "parchment",
	frameBackgroundOpacity = 100,
	showWatchedCurrencies = true,
	showTrackedCurrencyCharacterBreakdown = false,
	trackedCurrencyTooltipTotalPosition = "top",
	trackedCurrencyTooltipNameColorMode = "class",
	trackedCurrencyTooltipCountColorMode = "default",
	activeCategoryMode = "basic",
	modeOnboardingComplete = false,
	categoryModes = {
		basic = CATEGORY_MODE_DEFAULTS,
		advanced = CATEGORY_MODE_DEFAULTS,
	},
	collapsedSections = {},
	trackedCurrencyIDs = {},
	textAppearance = {
		font = "standard",
		size = 15,
		overlaySize = 15,
		outline = "OUTLINE",
	},
}

local TEXT_FONT_OPTIONS = {
	{
		value = "standard",
		labelKey = "settingsTextFontStandard",
		getFontPath = function()
			return STANDARD_TEXT_FONT
		end,
	},
	{
		value = "arial",
		labelKey = "settingsTextFontArial",
		fontPath = "Fonts\\ARIALN.TTF",
	},
	{
		value = "morpheus",
		labelKey = "settingsTextFontMorpheus",
		fontPath = "Fonts\\MORPHEUS.ttf",
	},
}

local TEXT_FONT_OPTION_LOOKUP = {}
for _, option in ipairs(TEXT_FONT_OPTIONS) do
	TEXT_FONT_OPTION_LOOKUP[option.value] = option
end

local TEXT_OUTLINE_OPTIONS = {
	{
		value = "NONE",
		labelKey = "settingsTextOutlineNone",
		flags = "",
	},
	{
		value = "OUTLINE",
		labelKey = "settingsTextOutlineRegular",
		flags = "OUTLINE",
	},
	{
		value = "THICKOUTLINE",
		labelKey = "settingsTextOutlineThick",
		flags = "THICKOUTLINE",
	},
}

local TEXT_OUTLINE_OPTION_LOOKUP = {}
for _, option in ipairs(TEXT_OUTLINE_OPTIONS) do
	TEXT_OUTLINE_OPTION_LOOKUP[option.value] = option
end

local TRACKED_CURRENCY_TOOLTIP_TOTAL_POSITION_OPTIONS = {
	{
		value = "top",
		labelKey = "settingsTrackedCurrencyTooltipTotalTop",
	},
	{
		value = "bottom",
		labelKey = "settingsTrackedCurrencyTooltipTotalBottom",
	},
}

local TRACKED_CURRENCY_TOOLTIP_TOTAL_POSITION_LOOKUP = {}
for _, option in ipairs(TRACKED_CURRENCY_TOOLTIP_TOTAL_POSITION_OPTIONS) do
	TRACKED_CURRENCY_TOOLTIP_TOTAL_POSITION_LOOKUP[option.value] = option
end

local TRACKED_CURRENCY_TOOLTIP_COLOR_MODE_OPTIONS = {
	{
		value = "default",
		labelKey = "settingsTrackedCurrencyTooltipColorDefault",
	},
	{
		value = "class",
		labelKey = "settingsTrackedCurrencyTooltipColorClass",
	},
}

local TRACKED_CURRENCY_TOOLTIP_COLOR_MODE_LOOKUP = {}
for _, option in ipairs(TRACKED_CURRENCY_TOOLTIP_COLOR_MODE_OPTIONS) do
	TRACKED_CURRENCY_TOOLTIP_COLOR_MODE_LOOKUP[option.value] = option
end

local settingsDefaultsCache = {
	table = nil,
}

local textAppearanceDefaultsCache = {
	table = nil,
}

local resolvedTextAppearanceCache = {
	appearance = nil,
	font = nil,
	outline = nil,
	size = nil,
	overlaySize = nil,
}

local TRACKED_CURRENCY_DATA_REQUEST_THROTTLE = 5
local trackedCurrencyDataRequestState = addon.Bags.variables.trackedCurrencyDataRequestState or {}
addon.Bags.variables.trackedCurrencyDataRequestState = trackedCurrencyDataRequestState

local function applyDefaults(target, defaults)
	for key, value in pairs(defaults) do
		if type(value) == "table" then
			if type(target[key]) ~= "table" then
				target[key] = {}
			end
			applyDefaults(target[key], value)
		elseif target[key] == nil then
			target[key] = value
		end
	end
end

local function ensureSettingsDefaults(settings)
	if settingsDefaultsCache.table ~= settings then
		applyDefaults(settings, defaultSettings)
		settingsDefaultsCache.table = settings
		textAppearanceDefaultsCache.table = nil
		resolvedTextAppearanceCache.appearance = nil
	end

	return settings
end

local function ensureTextAppearanceDefaults(appearance)
	if textAppearanceDefaultsCache.table ~= appearance then
		applyDefaults(appearance, defaultSettings.textAppearance)
		textAppearanceDefaultsCache.table = appearance
		resolvedTextAppearanceCache.appearance = nil
	end

	return appearance
end

local function applyIntegratedDefaults(settings)
	local version = tonumber(settings.integratedDefaultsVersion) or 0
	if version >= INTEGRATED_DEFAULTS_VERSION then
		return false
	end

	settings.compactCategoryLayout = true
	settings.compactCategoryGap = 8
	settings.combineUnstackableItems = true
	settings.showFooterSlotSummary = false
	settings.skinPreset = "default"
	settings.iconShape = "default"
	settings.frameBackground = "parchment"
	settings.frameBackgroundOpacity = 100

	settings.textAppearance = settings.textAppearance or {}
	settings.textAppearance.font = settings.textAppearance.font or defaultSettings.textAppearance.font
	settings.textAppearance.size = 15
	settings.textAppearance.overlaySize = 15
	settings.textAppearance.outline = settings.textAppearance.outline or defaultSettings.textAppearance.outline

	settings.overlayElements = settings.overlayElements or {}
	settings.overlayElements.upgradeTrack = settings.overlayElements.upgradeTrack or {}
	settings.overlayElements.upgradeTrack.enabled = false

	settings.integratedDefaultsVersion = INTEGRATED_DEFAULTS_VERSION
	settingsDefaultsCache.table = nil
	textAppearanceDefaultsCache.table = nil
	resolvedTextAppearanceCache.appearance = nil
	return true
end

local function ensureMoneyTracker()
	addon.DB = addon.DB or {}
	addon.DB.moneyTracker = addon.DB.moneyTracker or {}
	return addon.DB.moneyTracker
end

local function getCurrentCharacterGUID()
	if type(UnitGUID) ~= "function" then
		return nil
	end

	return UnitGUID("player")
end

function addon.GetSettings()
	if addon.savedVariablesLoaded then
		addon.DB = _G.EnhanceQoLBagsDB or addon.DB or {}
	end

	addon.DB = addon.DB or {}
	addon.DB.frame = addon.DB.frame or {}
	addon.DB.settings = addon.DB.settings or {}
	addon.DB.moneyTracker = addon.DB.moneyTracker or {}
	addon.DB.warbandGold = tonumber(addon.DB.warbandGold) or 0
	return ensureSettingsDefaults(addon.DB.settings)
end

function addon.GetActiveCategoryMode()
	local settings = addon.GetSettings()
	local mode = tostring(settings.activeCategoryMode or defaultSettings.activeCategoryMode)
	if mode ~= "advanced" then
		mode = "basic"
	end
	settings.activeCategoryMode = mode
	return mode
end

function addon.SetActiveCategoryMode(mode)
	mode = tostring(mode or "")
	if mode ~= "advanced" then
		mode = "basic"
	end

	local settings = addon.GetSettings()
	if mode == "basic" and addon.EnsureBasicPresetSeeded then
		addon.EnsureBasicPresetSeeded()
	end
	if mode == "basic" and addon.ApplyBasicOverlayDefaultsIfUnconfigured then
		addon.ApplyBasicOverlayDefaultsIfUnconfigured()
	end
	if settings.activeCategoryMode == mode then
		return false
	end

	settings.activeCategoryMode = mode
	if addon.MarkCategoryModeStateDirty then
		addon.MarkCategoryModeStateDirty()
	end
	return true
end

function addon.IsCategoryModeOnboardingComplete()
	local settings = addon.GetSettings()
	settings.modeOnboardingComplete = settings.modeOnboardingComplete == true
	return settings.modeOnboardingComplete
end

function addon.SetCategoryModeOnboardingComplete(isComplete)
	local settings = addon.GetSettings()
	local normalized = isComplete == true
	if settings.modeOnboardingComplete == normalized then
		return false
	end

	settings.modeOnboardingComplete = normalized
	return true
end

function addon.InitializeSavedVariables()
	local hadSavedVariables = type(_G.EnhanceQoLBagsDB) == "table"
	addon.savedVariablesAreNew = not hadSavedVariables
	addon.DB = _G.EnhanceQoLBagsDB or addon.DB or {}
	_G.EnhanceQoLBagsDB = addon.DB
	addon.DB.frame = addon.DB.frame or {}
	addon.DB.settings = addon.DB.settings or {}
	addon.DB.moneyTracker = addon.DB.moneyTracker or {}
	addon.DB.warbandGold = tonumber(addon.DB.warbandGold) or 0
	ensureSettingsDefaults(addon.DB.settings)
	applyIntegratedDefaults(addon.DB.settings)
	if addon.InitializeCategoryModeSettings then
		addon.InitializeCategoryModeSettings(addon.savedVariablesAreNew)
	end
	addon.savedVariablesLoaded = true
	return addon.DB
end

function addon.GetCurrentCharacterGUID()
	return getCurrentCharacterGUID()
end

function addon.UpdateTrackedCharacterMoney()
	if not addon.savedVariablesLoaded then
		return nil
	end

	local characterGUID = getCurrentCharacterGUID()
	if not characterGUID then
		return nil
	end

	local tracker = ensureMoneyTracker()
	local _, classToken = UnitClass("player")
	tracker[characterGUID] = {
		name = UnitName("player"),
		realm = GetRealmName(),
		class = classToken,
		money = GetMoney() or 0,
		lastSeen = time and time() or 0,
	}

	return tracker[characterGUID]
end

function addon.UpdateWarbandGold()
	if not addon.savedVariablesLoaded then
		return nil
	end

	addon.DB = addon.DB or {}

	local warbandGold = addon.DB.warbandGold or 0
	if C_Bank and C_Bank.FetchDepositedMoney and Enum and Enum.BankType and Enum.BankType.Account then
		warbandGold = C_Bank.FetchDepositedMoney(Enum.BankType.Account) or warbandGold
	end

	addon.DB.warbandGold = tonumber(warbandGold) or 0
	return addon.DB.warbandGold
end

function addon.GetWarbandGold()
	addon.DB = addon.DB or {}
	return tonumber(addon.DB.warbandGold) or 0
end

function addon.GetTrackedCharacterGoldEntries()
	local tracker = ensureMoneyTracker()
	local currentGUID = getCurrentCharacterGUID()
	local entries = {}

	for guid, info in pairs(tracker) do
		if type(info) == "table" and tonumber(info.money) ~= nil then
			entries[#entries + 1] = {
				guid = guid,
				name = info.name,
				realm = info.realm,
				class = info.class,
				money = tonumber(info.money) or 0,
				lastSeen = tonumber(info.lastSeen) or 0,
				isCurrent = guid == currentGUID,
			}
		end
	end

	table.sort(entries, function(left, right)
		if left.isCurrent ~= right.isCurrent then
			return left.isCurrent
		end
		if left.money ~= right.money then
			return left.money > right.money
		end

		local leftKey = string.format("%s:%s", tostring(left.name or ""), tostring(left.realm or ""))
		local rightKey = string.format("%s:%s", tostring(right.name or ""), tostring(right.realm or ""))
		return leftKey < rightKey
	end)

	return entries
end

function addon.RemoveTrackedCharacterGoldEntry(characterGUID)
	if not characterGUID or characterGUID == getCurrentCharacterGUID() then
		return false
	end

	local tracker = ensureMoneyTracker()
	if tracker[characterGUID] == nil then
		return false
	end

	tracker[characterGUID] = nil
	return true
end

local function copySequentialList(values)
	local copy = {}
	for index, value in ipairs(values or {}) do
		copy[index] = value
	end
	return copy
end

local function normalizeTrackedCurrencyIDs(currencyIDs)
	local normalized = {}
	local seen = {}

	for _, currencyID in ipairs(currencyIDs or {}) do
		currencyID = tonumber(currencyID)
		if currencyID and currencyID > 0 and not seen[currencyID] then
			seen[currencyID] = true
			normalized[#normalized + 1] = currencyID
		end
	end

	return normalized
end

local function areSequentialListsEqual(left, right)
	if #left ~= #right then
		return false
	end

	for index = 1, #left do
		if left[index] ~= right[index] then
			return false
		end
	end

	return true
end

local function normalizeTrackedCurrencyTooltipTotalPosition(value)
	value = tostring(value or defaultSettings.trackedCurrencyTooltipTotalPosition or "")
	if TRACKED_CURRENCY_TOOLTIP_TOTAL_POSITION_LOOKUP[value] then
		return value
	end
	return defaultSettings.trackedCurrencyTooltipTotalPosition
end

local function normalizeTrackedCurrencyTooltipColorMode(value, fallback)
	value = tostring(value or fallback or "")
	if TRACKED_CURRENCY_TOOLTIP_COLOR_MODE_LOOKUP[value] then
		return value
	end
	return fallback or defaultSettings.trackedCurrencyTooltipCountColorMode or "default"
end

function addon.GetTrackedCurrencyTrackingInfo(currencyID)
	currencyID = tonumber(currencyID)
	if not currencyID or currencyID <= 0 or not C_CurrencyInfo then
		return nil
	end

	if type(C_CurrencyInfo.GetCurrencyInfo) == "function" then
		local info = C_CurrencyInfo.GetCurrencyInfo(currencyID)
		if info and info.name then
			return {
				currencyID = currencyID,
				name = info.name,
				description = info.description,
				iconFileID = info.iconFileID or info.icon,
				quality = info.quality,
				quantity = tonumber(info.quantity) or 0,
			}
		end
	end

	if type(C_CurrencyInfo.GetBasicCurrencyInfo) == "function" then
		local info = C_CurrencyInfo.GetBasicCurrencyInfo(currencyID)
		if info and info.name then
			return {
				currencyID = currencyID,
				name = info.name,
				description = info.description,
				iconFileID = info.iconFileID or info.icon,
				quality = info.quality,
				quantity = tonumber(info.actualAmount or info.displayAmount) or 0,
			}
		end
	end

	return nil
end

function addon.GetTrackedCurrencyIDs()
	local settings = addon.GetSettings()
	local normalized = normalizeTrackedCurrencyIDs(settings.trackedCurrencyIDs)
	if not areSequentialListsEqual(settings.trackedCurrencyIDs or {}, normalized) then
		settings.trackedCurrencyIDs = copySequentialList(normalized)
	end

	return copySequentialList(normalized)
end

function addon.SetTrackedCurrencyIDs(currencyIDs)
	local settings = addon.GetSettings()
	local normalized = normalizeTrackedCurrencyIDs(currencyIDs)
	if areSequentialListsEqual(settings.trackedCurrencyIDs or {}, normalized) then
		return false
	end

	settings.trackedCurrencyIDs = copySequentialList(normalized)
	return true
end

function addon.GetTrackedCurrencyEntries()
	local entries = {}
	for index, currencyID in ipairs(addon.GetTrackedCurrencyIDs()) do
		local info = addon.GetTrackedCurrencyTrackingInfo(currencyID) or {}
		entries[#entries + 1] = {
			index = index,
			currencyID = currencyID,
			name = info.name or string.format("ID %d", currencyID),
			description = info.description,
			iconFileID = info.iconFileID,
			quality = info.quality,
			quantity = tonumber(info.quantity) or 0,
		}
	end
	return entries
end

function addon.AddTrackedCurrencyID(currencyID)
	local info = addon.GetTrackedCurrencyTrackingInfo(currencyID)
	if not info then
		return false, "invalid"
	end

	local ids = addon.GetTrackedCurrencyIDs()
	for _, existingCurrencyID in ipairs(ids) do
		if existingCurrencyID == info.currencyID then
			return false, "duplicate", info
		end
	end

	ids[#ids + 1] = info.currencyID
	addon.SetTrackedCurrencyIDs(ids)
	return true, nil, info
end

function addon.RemoveTrackedCurrencyID(currencyID)
	currencyID = tonumber(currencyID)
	if not currencyID or currencyID <= 0 then
		return false
	end

	local ids = addon.GetTrackedCurrencyIDs()
	for index, existingCurrencyID in ipairs(ids) do
		if existingCurrencyID == currencyID then
			table.remove(ids, index)
			addon.SetTrackedCurrencyIDs(ids)
			return true
		end
	end

	return false
end

function addon.MoveTrackedCurrencyIndex(index, delta)
	index = tonumber(index)
	delta = tonumber(delta)
	if not index or not delta or delta == 0 then
		return false
	end

	local ids = addon.GetTrackedCurrencyIDs()
	local targetIndex = index + delta
	if index < 1 or index > #ids or targetIndex < 1 or targetIndex > #ids then
		return false
	end

	ids[index], ids[targetIndex] = ids[targetIndex], ids[index]
	addon.SetTrackedCurrencyIDs(ids)
	return true
end

function addon.GetShowTrackedCurrencyCharacterBreakdown()
	local settings = addon.GetSettings()
	return settings.showTrackedCurrencyCharacterBreakdown == true
end

function addon.SetShowTrackedCurrencyCharacterBreakdown(enabled)
	local settings = addon.GetSettings()
	enabled = not not enabled
	if settings.showTrackedCurrencyCharacterBreakdown == enabled then
		return false
	end

	settings.showTrackedCurrencyCharacterBreakdown = enabled
	return true
end

function addon.GetTrackedCurrencyTooltipTotalPosition()
	local settings = addon.GetSettings()
	settings.trackedCurrencyTooltipTotalPosition = normalizeTrackedCurrencyTooltipTotalPosition(settings.trackedCurrencyTooltipTotalPosition)
	return settings.trackedCurrencyTooltipTotalPosition
end

function addon.SetTrackedCurrencyTooltipTotalPosition(value)
	local settings = addon.GetSettings()
	local normalizedValue = normalizeTrackedCurrencyTooltipTotalPosition(value)
	if settings.trackedCurrencyTooltipTotalPosition == normalizedValue then
		return false
	end

	settings.trackedCurrencyTooltipTotalPosition = normalizedValue
	return true
end

function addon.GetTrackedCurrencyTooltipTotalPositionOptions()
	local options = {}
	for _, option in ipairs(TRACKED_CURRENCY_TOOLTIP_TOTAL_POSITION_OPTIONS) do
		options[#options + 1] = {
			value = option.value,
			label = (addon.L and addon.L[option.labelKey]) or option.labelKey or option.value,
		}
	end
	return options
end

function addon.GetTrackedCurrencyTooltipNameColorMode()
	local settings = addon.GetSettings()
	settings.trackedCurrencyTooltipNameColorMode = normalizeTrackedCurrencyTooltipColorMode(settings.trackedCurrencyTooltipNameColorMode, defaultSettings.trackedCurrencyTooltipNameColorMode)
	return settings.trackedCurrencyTooltipNameColorMode
end

function addon.SetTrackedCurrencyTooltipNameColorMode(value)
	local settings = addon.GetSettings()
	local normalizedValue = normalizeTrackedCurrencyTooltipColorMode(value, defaultSettings.trackedCurrencyTooltipNameColorMode)
	if settings.trackedCurrencyTooltipNameColorMode == normalizedValue then
		return false
	end

	settings.trackedCurrencyTooltipNameColorMode = normalizedValue
	return true
end

function addon.GetTrackedCurrencyTooltipCountColorMode()
	local settings = addon.GetSettings()
	settings.trackedCurrencyTooltipCountColorMode = normalizeTrackedCurrencyTooltipColorMode(settings.trackedCurrencyTooltipCountColorMode, defaultSettings.trackedCurrencyTooltipCountColorMode)
	return settings.trackedCurrencyTooltipCountColorMode
end

function addon.SetTrackedCurrencyTooltipCountColorMode(value)
	local settings = addon.GetSettings()
	local normalizedValue = normalizeTrackedCurrencyTooltipColorMode(value, defaultSettings.trackedCurrencyTooltipCountColorMode)
	if settings.trackedCurrencyTooltipCountColorMode == normalizedValue then
		return false
	end

	settings.trackedCurrencyTooltipCountColorMode = normalizedValue
	return true
end

function addon.GetTrackedCurrencyTooltipColorModeOptions()
	local options = {}
	for _, option in ipairs(TRACKED_CURRENCY_TOOLTIP_COLOR_MODE_OPTIONS) do
		options[#options + 1] = {
			value = option.value,
			label = (addon.L and addon.L[option.labelKey]) or option.labelKey or option.value,
		}
	end
	return options
end

function addon.RequestTrackedCurrencyCharacterData(force)
	if not C_CurrencyInfo or type(C_CurrencyInfo.RequestCurrencyDataForAccountCharacters) ~= "function" then
		return false
	end

	if not force and not addon.GetShowTrackedCurrencyCharacterBreakdown() then
		return false
	end

	local now = type(GetTime) == "function" and GetTime() or 0
	local lastRequestTime = tonumber(trackedCurrencyDataRequestState.lastRequestTime) or 0
	if not force and now > 0 and (now - lastRequestTime) < TRACKED_CURRENCY_DATA_REQUEST_THROTTLE then
		return false
	end

	trackedCurrencyDataRequestState.lastRequestTime = now
	C_CurrencyInfo.RequestCurrencyDataForAccountCharacters()
	return true
end

local function getCurrentTrackedCurrencyCharacterEntry(currencyID)
	if not currencyID or not C_CurrencyInfo or type(C_CurrencyInfo.GetCurrencyInfo) ~= "function" then
		return nil
	end

	local currentGUID = getCurrentCharacterGUID()
	if not currentGUID then
		return nil
	end

	local info = C_CurrencyInfo.GetCurrencyInfo(currencyID)
	if not info or not info.name then
		return nil
	end

	local _, classToken = UnitClass("player")
	return {
		characterGUID = currentGUID,
		characterName = UnitName("player") or UNKNOWN,
		fullCharacterName = (GetUnitName and GetUnitName("player", true)) or UnitName("player") or UNKNOWN,
		currencyID = currencyID,
		quantity = tonumber(info.quantity) or 0,
		class = classToken,
		isCurrent = true,
	}
end

local function getTrackedCurrencyCharacterClassToken(characterGUID)
	if not characterGUID then
		return nil
	end

	local currentGUID = getCurrentCharacterGUID()
	if currentGUID and characterGUID == currentGUID then
		local _, classToken = UnitClass("player")
		if classToken and classToken ~= "" then
			return classToken
		end
	end

	local tracker = ensureMoneyTracker()
	local trackedEntry = tracker and tracker[characterGUID]
	if trackedEntry and trackedEntry.class and trackedEntry.class ~= "" then
		return trackedEntry.class
	end

	if type(GetPlayerInfoByGUID) == "function" then
		local _, classFile = GetPlayerInfoByGUID(characterGUID)
		if classFile and classFile ~= "" then
			return classFile
		end
	end

	return nil
end

function addon.GetTrackedCurrencyCharacterEntries(currencyID)
	currencyID = tonumber(currencyID)
	if not currencyID or currencyID <= 0 then
		return {}, false, false
	end

	if not addon.GetShowTrackedCurrencyCharacterBreakdown() then
		return {}, false, false
	end

	if not C_CurrencyInfo
		or type(C_CurrencyInfo.FetchCurrencyDataFromAccountCharacters) ~= "function"
		or type(C_CurrencyInfo.IsAccountCharacterCurrencyDataReady) ~= "function"
	then
		return {}, false, false
	end

	local isTransferable = type(C_CurrencyInfo.IsAccountTransferableCurrency) == "function"
		and C_CurrencyInfo.IsAccountTransferableCurrency(currencyID)
	if not isTransferable then
		return {}, true, false
	end

	local isReady = C_CurrencyInfo.IsAccountCharacterCurrencyDataReady()
	if not isReady then
		return {}, false, true
	end

	local currentGUID = getCurrentCharacterGUID()
	local entries = {}
	local seen = {}
	local rosterEntries = C_CurrencyInfo.FetchCurrencyDataFromAccountCharacters(currencyID)
	for _, entry in ipairs(rosterEntries or {}) do
		local characterGUID = entry.characterGUID
		if characterGUID and not seen[characterGUID] then
			seen[characterGUID] = true
			entries[#entries + 1] = {
				characterGUID = characterGUID,
				characterName = entry.characterName,
				fullCharacterName = entry.fullCharacterName,
				currencyID = entry.currencyID,
				quantity = tonumber(entry.quantity) or 0,
				class = getTrackedCurrencyCharacterClassToken(characterGUID),
				isCurrent = characterGUID == currentGUID,
			}
		end
	end

	local currentEntry = getCurrentTrackedCurrencyCharacterEntry(currencyID)
	if currentEntry and not seen[currentEntry.characterGUID] then
		entries[#entries + 1] = currentEntry
	end

	table.sort(entries, function(left, right)
		if left.isCurrent ~= right.isCurrent then
			return left.isCurrent
		end
		if left.quantity ~= right.quantity then
			return left.quantity > right.quantity
		end

		local leftKey = tostring(left.fullCharacterName or left.characterName or "")
		local rightKey = tostring(right.fullCharacterName or right.characterName or "")
		return leftKey < rightKey
	end)

	return entries, true, true
end

local function clampPaddingValue(padding, defaultValue)
	padding = math.floor((tonumber(padding) or defaultValue or 0) + 0.5)
	if padding < 0 then
		padding = 0
	elseif padding > 24 then
		padding = 24
	end

	return padding
end

local function clampItemScaleValue(scale, defaultValue)
	scale = tonumber(scale) or defaultValue or 100
	scale = math.floor(((scale / 5) + 0.5)) * 5
	if scale < 80 then
		scale = 80
	elseif scale > 160 then
		scale = 160
	end

	return scale
end

local function clampMaxColumnsValue(value, defaultValue)
	value = math.floor((tonumber(value) or defaultValue or 10) + 0.5)
	if value < 4 then
		value = 4
	elseif value > 24 then
		value = 24
	end

	return value
end

local function normalizeBooleanSetting(value, defaultValue)
	if value == nil then
		return not not defaultValue
	end

	return not not value
end

function addon.GetOutsideHeaderPadding()
	local settings = addon.GetSettings()
	settings.outsideHeaderPadding = clampPaddingValue(settings.outsideHeaderPadding, defaultSettings.outsideHeaderPadding)
	return settings.outsideHeaderPadding
end

function addon.SetOutsideHeaderPadding(padding)
	local settings = addon.GetSettings()
	local clampedPadding = clampPaddingValue(padding, defaultSettings.outsideHeaderPadding)
	if settings.outsideHeaderPadding == clampedPadding then
		return false
	end

	settings.outsideHeaderPadding = clampedPadding
	return true
end

function addon.GetOutsideFooterPadding()
	local settings = addon.GetSettings()
	local fallback = math.max(
		tonumber(settings.outsideFooterPadding) or 0,
		tonumber(settings.footerSummaryPadding) or 0,
		tonumber(settings.outerPadding) or defaultSettings.outsideFooterPadding
	)
	settings.outsideFooterPadding = clampPaddingValue(settings.outsideFooterPadding, fallback)
	return settings.outsideFooterPadding
end

function addon.SetOutsideFooterPadding(padding)
	local settings = addon.GetSettings()
	local clampedPadding = clampPaddingValue(padding, defaultSettings.outsideFooterPadding)
	if settings.outsideFooterPadding == clampedPadding then
		return false
	end

	settings.outsideFooterPadding = clampedPadding
	return true
end

function addon.GetInsideHorizontalPadding()
	local settings = addon.GetSettings()
	local fallback = tonumber(settings.outerPadding) or defaultSettings.insideHorizontalPadding
	settings.insideHorizontalPadding = clampPaddingValue(settings.insideHorizontalPadding, fallback)
	return settings.insideHorizontalPadding
end

function addon.SetInsideHorizontalPadding(padding)
	local settings = addon.GetSettings()
	local clampedPadding = clampPaddingValue(padding, defaultSettings.insideHorizontalPadding)
	if settings.insideHorizontalPadding == clampedPadding then
		return false
	end

	settings.insideHorizontalPadding = clampedPadding
	return true
end

function addon.GetInsideTopPadding()
	local settings = addon.GetSettings()
	local fallback = (tonumber(settings.outerPadding) or defaultSettings.insideHorizontalPadding) + (tonumber(settings.headerPadding) or defaultSettings.headerPadding)
	settings.insideTopPadding = clampPaddingValue(settings.insideTopPadding, fallback)
	return settings.insideTopPadding
end

function addon.SetInsideTopPadding(padding)
	local settings = addon.GetSettings()
	local clampedPadding = clampPaddingValue(padding, defaultSettings.insideTopPadding)
	if settings.insideTopPadding == clampedPadding then
		return false
	end

	settings.insideTopPadding = clampedPadding
	return true
end

function addon.GetInsideBottomPadding()
	local settings = addon.GetSettings()
	settings.insideBottomPadding = clampPaddingValue(settings.insideBottomPadding, defaultSettings.insideBottomPadding)
	return settings.insideBottomPadding
end

function addon.SetInsideBottomPadding(padding)
	local settings = addon.GetSettings()
	local clampedPadding = clampPaddingValue(padding, defaultSettings.insideBottomPadding)
	if settings.insideBottomPadding == clampedPadding then
		return false
	end

	settings.insideBottomPadding = clampedPadding
	return true
end

function addon.GetOuterPadding()
	return addon.GetInsideHorizontalPadding()
end

function addon.SetOuterPadding(padding)
	return addon.SetInsideHorizontalPadding(padding)
end

function addon.GetHeaderPadding()
	return addon.GetInsideTopPadding()
end

function addon.SetHeaderPadding(padding)
	return addon.SetInsideTopPadding(padding)
end

function addon.GetFooterSummaryPadding()
	return addon.GetOutsideFooterPadding()
end

function addon.SetFooterSummaryPadding(padding)
	return addon.SetOutsideFooterPadding(padding)
end

function addon.GetItemScale()
	local settings = addon.GetSettings()
	settings.itemScale = clampItemScaleValue(settings.itemScale, defaultSettings.itemScale)
	return settings.itemScale
end

function addon.SetItemScale(scale)
	local settings = addon.GetSettings()
	local clampedScale = clampItemScaleValue(scale, defaultSettings.itemScale)
	if settings.itemScale == clampedScale then
		return false
	end

	settings.itemScale = clampedScale
	return true
end

function addon.GetMaxColumns()
	local settings = addon.GetSettings()
	settings.maxColumns = clampMaxColumnsValue(settings.maxColumns, defaultSettings.maxColumns)
	return settings.maxColumns
end

function addon.SetMaxColumns(value)
	local settings = addon.GetSettings()
	local clampedValue = clampMaxColumnsValue(value, defaultSettings.maxColumns)
	if settings.maxColumns == clampedValue then
		return false
	end

	settings.maxColumns = clampedValue
	return true
end

function addon.GetCompactCategoryLayout()
	local settings = addon.GetSettings()
	settings.compactCategoryLayout = normalizeBooleanSetting(settings.compactCategoryLayout, defaultSettings.compactCategoryLayout)
	return settings.compactCategoryLayout
end

function addon.SetCompactCategoryLayout(enabled)
	local settings = addon.GetSettings()
	enabled = normalizeBooleanSetting(enabled, defaultSettings.compactCategoryLayout)
	if settings.compactCategoryLayout == enabled then
		return false
	end

	settings.compactCategoryLayout = enabled
	return true
end

function addon.GetCompactCategoryGap()
	local settings = addon.GetSettings()
	settings.compactCategoryGap = clampPaddingValue(settings.compactCategoryGap, defaultSettings.compactCategoryGap)
	return settings.compactCategoryGap
end

function addon.SetCompactCategoryGap(value)
	local settings = addon.GetSettings()
	local clampedValue = clampPaddingValue(value, defaultSettings.compactCategoryGap)
	if settings.compactCategoryGap == clampedValue then
		return false
	end

	settings.compactCategoryGap = clampedValue
	return true
end

function addon.GetTextAppearance()
	local settings = addon.GetSettings()
	settings.textAppearance = settings.textAppearance or {}
	return ensureTextAppearanceDefaults(settings.textAppearance)
end

function addon.GetTextFontOptions()
	local options = {}
	for _, option in ipairs(TEXT_FONT_OPTIONS) do
		options[#options + 1] = {
			value = option.value,
			label = (addon.L and addon.L[option.labelKey]) or option.labelKey or option.value,
		}
	end
	return options
end

function addon.GetTextOutlineOptions()
	local options = {}
	for _, option in ipairs(TEXT_OUTLINE_OPTIONS) do
		options[#options + 1] = {
			value = option.value,
			label = (addon.L and addon.L[option.labelKey]) or option.labelKey or option.value,
		}
	end
	return options
end

function addon.GetTextFontPath(fontID)
	local option = TEXT_FONT_OPTION_LOOKUP[fontID] or TEXT_FONT_OPTION_LOOKUP[defaultSettings.textAppearance.font]
	if not option then
		return STANDARD_TEXT_FONT
	end

	if option.getFontPath then
		return option.getFontPath() or STANDARD_TEXT_FONT
	end

	return option.fontPath or STANDARD_TEXT_FONT
end

function addon.GetTextOutlineFlags(outlineID)
	local option = TEXT_OUTLINE_OPTION_LOOKUP[outlineID] or TEXT_OUTLINE_OPTION_LOOKUP[defaultSettings.textAppearance.outline]
	return option and option.flags or "OUTLINE"
end

function addon.GetResolvedTextAppearance()
	local appearance = addon.GetTextAppearance()
	local fontID = appearance.font or defaultSettings.textAppearance.font
	local outlineID = appearance.outline or defaultSettings.textAppearance.outline
	local size = math.floor((tonumber(appearance.size) or defaultSettings.textAppearance.size) + 0.5)
	local overlaySize = math.floor((tonumber(appearance.overlaySize) or size) + 0.5)

	if resolvedTextAppearanceCache.appearance ~= appearance
		or resolvedTextAppearanceCache.font ~= fontID
		or resolvedTextAppearanceCache.outline ~= outlineID
		or resolvedTextAppearanceCache.size ~= size
		or resolvedTextAppearanceCache.overlaySize ~= overlaySize
	then
		resolvedTextAppearanceCache.appearance = appearance
		resolvedTextAppearanceCache.font = fontID
		resolvedTextAppearanceCache.outline = outlineID
		resolvedTextAppearanceCache.size = size
		resolvedTextAppearanceCache.overlaySize = overlaySize
		resolvedTextAppearanceCache.fontPath = addon.GetTextFontPath(fontID)
		resolvedTextAppearanceCache.outlineFlags = addon.GetTextOutlineFlags(outlineID)
	end

	return resolvedTextAppearanceCache
end

function addon.SetTextAppearanceFont(fontID)
	if not TEXT_FONT_OPTION_LOOKUP[fontID] then
		return false
	end

	local appearance = addon.GetTextAppearance()
	appearance.font = fontID
	return true
end

function addon.SetTextAppearanceSize(size)
	size = math.floor((tonumber(size) or defaultSettings.textAppearance.size) + 0.5)
	if size < 8 then
		size = 8
	elseif size > 24 then
		size = 24
	end

	local appearance = addon.GetTextAppearance()
	appearance.size = size
	return true
end

function addon.GetTextAppearanceOverlaySize()
	local appearance = addon.GetTextAppearance()
	local overlaySize = math.floor((tonumber(appearance.overlaySize) or tonumber(appearance.size) or defaultSettings.textAppearance.size) + 0.5)
	if overlaySize < 8 then
		overlaySize = 8
	elseif overlaySize > 24 then
		overlaySize = 24
	end

	if tonumber(appearance.overlaySize) ~= overlaySize then
		appearance.overlaySize = overlaySize
	end

	return overlaySize
end

function addon.SetTextAppearanceOverlaySize(size)
	size = math.floor((tonumber(size) or defaultSettings.textAppearance.size) + 0.5)
	if size < 8 then
		size = 8
	elseif size > 24 then
		size = 24
	end

	local appearance = addon.GetTextAppearance()
	if tonumber(appearance.overlaySize) == size then
		return false
	end

	appearance.overlaySize = size
	return true
end

function addon.SetTextAppearanceOutline(outlineID)
	if not TEXT_OUTLINE_OPTION_LOOKUP[outlineID] then
		return false
	end

	local appearance = addon.GetTextAppearance()
	appearance.outline = outlineID
	return true
end

function addon.ApplyConfiguredFont(fontString, size)
	if not fontString or not fontString.SetFont then
		return
	end

	local appearance = addon.GetResolvedTextAppearance()
	local fontSize = math.floor((tonumber(size) or appearance.size or defaultSettings.textAppearance.size) + 0.5)
	if fontSize < 6 then
		fontSize = 6
	end

	fontString:SetFont(appearance.fontPath or STANDARD_TEXT_FONT, fontSize, appearance.outlineFlags or "OUTLINE")
end

local initFrame = addon.Bags.variables.initFrame or CreateFrame("Frame")
addon.Bags.variables.initFrame = initFrame
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:RegisterEvent("PLAYER_MONEY")
initFrame:RegisterEvent("ACCOUNT_MONEY")
initFrame:SetScript("OnEvent", function(_, event, loadedAddonName)
	if event == "ADDON_LOADED" then
		if loadedAddonName ~= addonName then
			return
		end

		if addon.Bags.IsEnabled and addon.Bags.IsEnabled() then
			addon.InitializeSavedVariables()
		end

		local state = addon.Bags.variables and addon.Bags.variables.state
		if state then
			state.manualVisible = addon.DB and addon.DB.settings and addon.DB.settings.manualVisible
		end

		initFrame:UnregisterEvent("ADDON_LOADED")
	elseif event == "PLAYER_LOGIN" then
		if addon.Bags.IsEnabled and addon.Bags.IsEnabled() then
			if addon.Bags.functions and addon.Bags.functions.Enable then
				addon.Bags.functions.Enable()
			end
			addon.UpdateWarbandGold()
			addon.UpdateTrackedCharacterMoney()
			addon.RequestTrackedCurrencyCharacterData(false)
		end
		if addon.Bags.IsEnabled and addon.Bags.IsEnabled() and addon.ShouldShowCategoryModeOnboarding and addon.ShouldShowCategoryModeOnboarding() and addon.OpenCategoryModeOnboarding then
			addon.OpenCategoryModeOnboarding()
		end
		initFrame:UnregisterEvent("PLAYER_LOGIN")
	elseif event == "PLAYER_MONEY" then
		if addon.Bags.IsEnabled and addon.Bags.IsEnabled() then
			addon.UpdateTrackedCharacterMoney()
		end
	elseif event == "ACCOUNT_MONEY" then
		if addon.Bags.IsEnabled and addon.Bags.IsEnabled() then
			addon.UpdateWarbandGold()
		end
	end
end)

addon.L = addon.L or {}
addon.metadata = addon.metadata or {
	title = "Bags",
	description = "Standalone custom bag window and item grid for Retail.",
	slashCommands = {
		"/bags",
		"/bagstest",
	},
}
