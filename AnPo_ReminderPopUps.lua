include( "InstanceManager" );
include( "AnPo_User_Settings" );

local TECH_ACTIVE_KEY = "AnPo_TECH_ACTIVE_STATUS"
local CIVIC_ACTIVE_KEY = "AnPo_CIVIC_ACTIVE_STATUS"

local IsButtonAdded = false

local techStop = nil;
local techRemind = true
local previousTech = nil

local civicStop = nil;
local civicRemind = true
local previousCivic = nil

local currentTurn = -1
local cachedTurn = -1
local cachedExtraTechBoost = 0
local cachedExtraCivicBoost = 0

local civilizationName = nil

local techRemindTitle       :string = Locale.Lookup("LOC_ANPO_TECH_TITLE")
local techRemindDesc        :string = Locale.Lookup("LOC_ANPO_TECH_DESC")
local techRemindTree        :string = Locale.Lookup("LOC_ANPO_TECH_OPEN_TREE")
local civicRemindTitle      :string = Locale.Lookup("LOC_ANPO_CIVIC_TITLE")
local civicRemindDesc       :string = Locale.Lookup("LOC_ANPO_CIVIC_DESC")
local civicRemindTree       :string = Locale.Lookup("LOC_ANPO_CIVIC_OPEN_TREE")
local remindIgnore          :string = Locale.Lookup("LOC_ANPO_IGNORE")
local remindMute            :string = Locale.Lookup("LOC_ANPO_MUTE")

-- Check if the modifier's owner requirement set is met.
local function IsOwnerRequirementSetMet(modifierObjId:number)
    -- Check if owner requirements are met.
    if modifierObjId ~= nil and modifierObjId ~= 0 then
        local ownerRequirementSetId = GameEffects.GetModifierOwnerRequirementSet(modifierObjId);
        if ownerRequirementSetId then
            return GameEffects.GetRequirementSetState(ownerRequirementSetId) == "Met";
        end
    end
    return true;
end

local function queryExtraBoost(playerID, isTech)
    
    if playerID ~= Game.GetLocalPlayer() then return; end
    if currentTurn == cachedTurn then
        if isTech then
            return cachedExtraTechBoost
        else
            return cachedExtraCivicBoost
        end
    end
    
    cachedTurn = currentTurn
    local tech_ratio = 0;
    local civic_ratio = 0;

    for _, modifierObjID in ipairs(GameEffects.GetModifiers()) do
        local isActive = GameEffects.GetModifierActive(modifierObjID);
        local ownerObjID = GameEffects.GetModifierOwner(modifierObjID);
        if isActive and IsOwnerRequirementSetMet(modifierObjID) and (GameEffects.GetObjectsPlayerId(ownerObjID) == playerID) then
            local modifierDef = GameEffects.GetModifierDefinition(modifierObjID);
            local modifierType = GameInfo.Modifiers[modifierDef.Id].ModifierType;
            if modifierType then
                local modifierTypeRow = GameInfo.DynamicModifiers[modifierType];
                if modifierTypeRow then
                    if modifierTypeRow.EffectType == 'EFFECT_ADJUST_TECHNOLOGY_BOOST' then
                        tech_ratio = tech_ratio + modifierDef.Arguments.Amount;
                    end
                    if modifierTypeRow.EffectType == 'EFFECT_ADJUST_CIVIC_BOOST' then
                        civic_ratio = civic_ratio + modifierDef.Arguments.Amount;
                    end
                    -- print(modifierObjID, modifierType, modifierTypeRow.EffectType)
                    -- for k, v in pairs(modifierDef.Arguments) do
                    --     print(k, v)
                    -- end
                end
            end
        end
    end

    cached_extra_techboost = tech_ratio;
    cached_extra_civicboost = civic_ratio;
    if isTech then
        return cached_extra_techboost;
    else
        return cached_extra_civicboost;
    end
end

local function checkTech()
    local pPlayer = Players[Game.GetLocalPlayer()];
	if (pPlayer == nil) then
		return false;
	end

	local currentTech = pPlayer:GetTechs():GetResearchingTech();
	if (currentTech < 3) then
		return false;
	end

	if (pPlayer:GetTechs():HasBoostBeenTriggered(pPlayer:GetTechs():GetResearchingTech())) then
		return false;
	end

	if (previousTech ~= nil and previousTech == currentTech and techRemind == false) then
		return false;
	end

	previousTech = currentTech;
	techRemind = true;
	local cost = pPlayer:GetTechs():GetResearchCost(pPlayer:GetTechs():GetResearchingTech());
	local progress = pPlayer:GetTechs():GetResearchProgress(pPlayer:GetTechs():GetResearchingTech());
    local boostValueTech = 0;

    if (progress >= cost) then
        return false;
    end

	for row in GameInfo.Boosts() do
		if (row.TechnologyType == GameInfo.Technologies[currentTech].TechnologyType) then
			boostValueTech = row.Boost;
			break
		end
	end
    boostValueTech = boostValueTech + queryExtraBoost(Game.GetLocalPlayer(), true);
	if ((progress + math.floor(math.max(cost * boostValueTech / 100 - 0.5, 0))) < cost) then
		return false;
	end

    return true;
end

local function checkCivic()
    local pPlayer = Players[Game.GetLocalPlayer()];
	if (pPlayer == nil) then
		return false;
	end

	local currentCivic = pPlayer:GetCulture():GetProgressingCivic();
	if (currentCivic < 1) then
		return false;
	end

	if (pPlayer:GetCulture():HasBoostBeenTriggered(pPlayer:GetCulture():GetProgressingCivic())) then
		return false;
	end

	if (previousCivic ~= nil and previousCivic == currentCivic and civicRemind == false) then
		return false;
	end

	previousCivic = currentCivic;
	civicRemind = true;
    local cost = pPlayer:GetCulture():GetCultureCost(pPlayer:GetCulture():GetProgressingCivic());
	local progress = pPlayer:GetCulture():GetCulturalProgress(pPlayer:GetCulture():GetProgressingCivic());
    local boostValueCivic = 0;

    if (progress >= cost) then
        return false;
    end

	for row in GameInfo.Boosts() do
		if (row.CivicType == GameInfo.Civics[currentCivic].CivicType) then
			boostValueCivic = row.Boost;
			break
		end
	end
    boostValueCivic = boostValueCivic + queryExtraBoost(Game.GetLocalPlayer(), false);
	if ((progress + math.floor(math.max(cost * boostValueCivic / 100. - 0.5 , 0))) < cost) then
		return false;
	end
    return true;
end

local function OnShowTechReminder()
    Controls.ReminderTitle:SetText(techRemindTitle);
    Controls.ReminderText:SetText(techRemindDesc);

    Controls.OpenTree:SetText(techRemindTree);
    Controls.OpenTree:RegisterCallback(Mouse.eLClick, function()
        LuaEvents.ResearchChooser_RaiseTechTree()
        Controls.TechNCivicReminderCTN:SetHide(true)
    end);

    Controls.OKButton:SetText(remindIgnore);
    Controls.OKButton:RegisterCallback(Mouse.eLClick, function()
        Controls.TechNCivicReminderCTN:SetHide(true)
    end);

    Controls.MuteButton:SetText(remindMute);
    Controls.MuteButton:RegisterCallback(Mouse.eLClick, function()
        techRemind = false
        Controls.TechNCivicReminderCTN:SetHide(true)
    end);
    Controls.TechNCivicReminderCTN:SetHide(false);
end

local function OnShowCivicReminder()
    Controls.ReminderTitle:SetText(civicRemindTitle);
    Controls.ReminderText:SetText(civicRemindDesc);

    Controls.OpenTree:SetText(civicRemindTree);
    Controls.OpenTree:RegisterCallback(Mouse.eLClick, function()
        LuaEvents.CivicsChooser_RaiseCivicsTree()
        Controls.TechNCivicReminderCTN:SetHide(true)
    end);

    Controls.OKButton:SetText(remindIgnore);
    Controls.OKButton:RegisterCallback(Mouse.eLClick, function()
        Controls.TechNCivicReminderCTN:SetHide(true)
    end);

    Controls.MuteButton:SetText(remindMute);
    Controls.MuteButton:RegisterCallback(Mouse.eLClick, function()
        civicRemind = false
        Controls.TechNCivicReminderCTN:SetHide(true)
    end);
    Controls.TechNCivicReminderCTN:SetHide(false);
end

local function OnShowBothReminders()
    Controls.ReminderTitle:SetText(techRemindTitle);
    Controls.ReminderText:SetText(techRemindDesc);

    Controls.OpenTree:SetText(techRemindTree);
    Controls.OpenTree:RegisterCallback(Mouse.eLClick, function()
        LuaEvents.ResearchChooser_RaiseTechTree()
        Controls.TechNCivicReminderCTN:SetHide(true)
        OnShowCivicReminder()
    end);

    Controls.OKButton:SetText(remindIgnore);
    Controls.OKButton:RegisterCallback(Mouse.eLClick, function()
        Controls.TechNCivicReminderCTN:SetHide(true)
        OnShowCivicReminder()
    end);

    Controls.MuteButton:SetText(remindMute);
    Controls.MuteButton:RegisterCallback(Mouse.eLClick, function()
        techRemind = false
        Controls.TechNCivicReminderCTN:SetHide(true)
        OnShowCivicReminder()
    end);
    Controls.TechNCivicReminderCTN:SetHide(false);
end


local function changeTechTexture()
    if (techStop) then
        Controls.AnPoTechButton:SetTexture("AnPo_techGreyArtboard.dds")
    else
        Controls.AnPoTechButton:SetTexture("AnPo_techLongArtboard.dds")
    end

end

local function changeCivicTexture()
    if (civicStop) then
        Controls.AnPoCivicButton:SetTexture("AnPo_civicGreyArtboard.dds")
    else
        Controls.AnPoCivicButton:SetTexture("AnPo_civicLongArtboard.dds")
    end

end

local function changeTooltip(isCivic)
    local status: string;

    if (isCivic) then
        if (not civicStop) then
            status = "LOC_ANPO_ON"
        else
            status = "LOC_ANPO_OFF"
        end
        Controls.AnPoCivicButton:SetToolTipString(Locale.Lookup("LOC_ANPO_CIVIC_BUTTON_TT", Locale.Lookup(status)));
    else
        if (not techStop) then
            status = "LOC_ANPO_ON"
        else
            status = "LOC_ANPO_OFF"
        end
        Controls.AnPoTechButton:SetToolTipString(Locale.Lookup("LOC_ANPO_TECH_BUTTON_TT", Locale.Lookup(status)));
    end
end

local function onClickTech()

    techStop = not techStop;
    local playerConfig = PlayerConfigurations[Game.GetLocalPlayer()];
    if playerConfig then
        playerConfig:SetValue(TECH_ACTIVE_KEY, techStop);
    end

    changeTooltip(false);
    changeTechTexture();
end

local function onClickCivic()

    civicStop = not civicStop;
    local playerConfig = PlayerConfigurations[Game.GetLocalPlayer()];
    if playerConfig then
        playerConfig:SetValue(CIVIC_ACTIVE_KEY, civicStop);
    end

    changeTooltip(true);
    changeCivicTexture();
end



local function OnEnterGame()
    local playerConfig = PlayerConfigurations[Game.GetLocalPlayer()];
    local techConfigs;
    local civicConfigs;
    if playerConfig then
        techConfigs = playerConfig:GetValue(TECH_ACTIVE_KEY);
        civicConfigs = playerConfig:GetValue(CIVIC_ACTIVE_KEY);
    end

    if techConfigs then
        techStop = techConfigs;
    else
        techStop = user_techStop;
    end

    if civicConfigs then
        civicStop = civicConfigs;
    else
        civicStop = user_civicStop;
    end
    

    Controls.TechNCivicReminderCTN:SetHide(true);
    Controls.TechNCivicReminderCTN:ChangeParent(ContextPtr:LookUpControl("/InGame/WorldViewControls"));
    Controls.OpenTree:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
    Controls.OKButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
    Controls.MuteButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);

    if not IsButtonAdded then
        local tPanRight = ContextPtr:LookUpControl("/InGame/TopPanel/RightContents");
		if tPanRight ~= nil then
			Controls.AnPoTechButton:ChangeParent(tPanRight);
			tPanRight:AddChildAtIndex(Controls.AnPoTechButton, 3);
            Controls.AnPoCivicButton:ChangeParent(tPanRight);
			tPanRight:AddChildAtIndex(Controls.AnPoCivicButton, 3);
			tPanRight:CalculateSize();
			tPanRight:ReprocessAnchoring();
			IsButtonAdded = true;
		end
        
        changeTechTexture()
        changeCivicTexture()
        changeTooltip(true)
        changeTooltip(false)
		Controls.AnPoTechButton:RegisterCallback(Mouse.eLClick, onClickTech);
        Controls.AnPoCivicButton:RegisterCallback(Mouse.eLClick, onClickCivic);
    end
end


function AnPo_CheckTechNCiciv(...)
    local args = {...};

	if args[1] > 0 then
		return;
	end

    if (techStop == true and civicStop == true) then
        return;
    end
    
    if ((not civilizationName) and (not techStop)) then
        civilizationName = PlayerConfigurations[Game.GetLocalPlayer()]:GetCivilizationTypeName()
        if (civilizationName == "CIVILIZATION_BABYLON_STK") then
            techStop = true;
        end
    end

    local isTechChangable = false;
    local isCivicChangable = false;
    if (techStop == false) then
        isTechChangable = checkTech();
    end
    if (civicStop == false) then
        isCivicChangable = checkCivic();
    end

    if (isTechChangable == true and isCivicChangable == true) then
        OnShowBothReminders();
    elseif(isTechChangable == true) then
        OnShowTechReminder();
    elseif(isCivicChangable == true) then
        OnShowCivicReminder();
    end
end


function Initialize()
    print("====================================");
	print("Civic&Tech Change Reminder: initialization");
	print("====================================");

    Events.PlayerTurnActivated.Add(AnPo_CheckTechNCiciv);
    Events.LoadGameViewStateDone.Add(OnEnterGame);
end

Initialize();
