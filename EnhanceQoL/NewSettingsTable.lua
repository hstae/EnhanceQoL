local addonName, addon = ...

addon.variables.NewVersionTableEQOL = {

	-- Root category id from Settings/MainCategory.lua
	["EQOL_UI"] = true,

	-- Legacy/alias (can stay harmlessly)
	["EQOL_INTERFACE"] = true,

	-- Expandable section id in Settings/ClassBuffReminder.lua
	["EQOL_VisibilityFrames"] = true,

	-- Feature setting keys
	["EQOL_ClassBuffReminder"] = true,
	["EQOL_classBuffReminderEnabled"] = true,
	["EQOL_CastbarsAndCooldowns"] = true,
	["EQOL_xpBarEnabled"] = true,
	["EQOL_unitframeSettingMinimap_visibility"] = true,
}
