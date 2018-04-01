Spellgarden = CreateFrame("Frame",nil,UIParent)

local npCastbars = {}
local npCastbarsByUnit = {}
local MAX_NAMEPLATE_CASTBARS = 7

Spellgarden:RegisterEvent("PLAYER_LOGIN")
Spellgarden:SetScript("OnEvent",function(self)
    local player = Spellgarden:SpawnCastBar("player",200,25)
    --player.spellText:SetAlpha(0.2)
    player.spellText:Hide()
    player.timeText:Hide()
    player:SetPoint("BOTTOMRIGHT",MultiBarBottomLeftButton12,"TOPRIGHT",-4, 48)
    CastingBarFrame:UnregisterAllEvents()
    SpellgardenPlayer = player

    local target = Spellgarden:SpawnCastBar("target",200,25)
    target:RegisterEvent("PLAYER_TARGET_CHANGED")
    Spellgarden:AddMore(target)
    -- target:SetPoint("CENTER",UIParent,"CENTER",200,-120)
    target:SetPoint("CENTER",UIParent,"CENTER",200,-190)
    -- target:SetPoint("CENTER",UIParent,"CENTER",400,0)
    SpellgardenTarget = target
    CastingBarFrame:UnregisterAllEvents()

    local focus = Spellgarden:SpawnCastBar("focus",200,25)
    Spellgarden:AddMore(focus)
    if oUF_Focus then focus:SetPoint("TOPRIGHT",oUF_Focus,"BOTTOMRIGHT", 0,-5)
    else focus:SetPoint("CENTER",UIParent,"CENTER", 0,300) end


    -- local npheader = Spellgarden:CreateNameplateCastbars()
    -- npheader:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
end)

local TimerOnUpdate = function(self,time)
    local beforeEnd = self.endTime - GetTime()
    local val
    if self.inverted then val = self.startTime + beforeEnd
    else val = self.endTime - beforeEnd end
    self.bar:SetValue(val)
    self.timeText:SetFormattedText("%.1f",beforeEnd)
    if beforeEnd <= 0 then self:Hide() end
end

local defaultCastColor = { 0.6, 0, 1 }
local defaultChannelColor = {200/255,50/255,95/255 }
local coloredSpells = {}

function Spellgarden.UNIT_SPELLCAST_START(self,event,unit,spell)
    if unit ~= self.unit then return end
    local name, subText, text, texture, startTime, endTime, isTradeSkill, castID, notInterruptible = UnitCastingInfo(unit)
    self.inverted = false
    self:UpdateCastingInfo(name,texture,startTime,endTime,castID, notInterruptible)
end
Spellgarden.UNIT_SPELLCAST_DELAYED = Spellgarden.UNIT_SPELLCAST_START
function Spellgarden.UNIT_SPELLCAST_CHANNEL_START(self,event,unit,spell)
    if unit ~= self.unit then return end
    local name, subText, text, texture, startTime, endTime, isTradeSkill, castID, notInterruptible = UnitChannelInfo(unit)
    self.inverted = true
    self:UpdateCastingInfo(name,texture,startTime,endTime,castID)
end
Spellgarden.UNIT_SPELLCAST_CHANNEL_UPDATE = Spellgarden.UNIT_SPELLCAST_CHANNEL_START


function Spellgarden.UNIT_SPELLCAST_STOP(self, event, unit, spell)
    if unit ~= self.unit then return end
    self:Hide()
end
function Spellgarden.UNIT_SPELLCAST_FAILED(self, event, unit, spell, _,castID)
    if unit ~= self.unit then return end
    if self.castID == castID then Spellgarden.UNIT_SPELLCAST_STOP(self, event, unit, spell) end
end
Spellgarden.UNIT_SPELLCAST_INTERRUPTED = Spellgarden.UNIT_SPELLCAST_STOP
Spellgarden.UNIT_SPELLCAST_CHANNEL_STOP = Spellgarden.UNIT_SPELLCAST_STOP


function Spellgarden.UNIT_SPELLCAST_INTERRUPTIBLE(self,event,unit)
    if unit ~= self.unit then return end
    self.shield:Hide()
end
function Spellgarden.UNIT_SPELLCAST_NOT_INTERRUPTIBLE(self,event,unit)
    if unit ~= self.unit then return end
    self.shield:Show()
end


function Spellgarden.PLAYER_TARGET_CHANGED(self,event)
    if UnitCastingInfo("target") then return Spellgarden.UNIT_SPELLCAST_START(self,event,"target") end
    if UnitChannelInfo("target") then return Spellgarden.UNIT_SPELLCAST_CHANNEL_START(self,event,"target") end
    Spellgarden.UNIT_SPELLCAST_STOP(self,event,"target")
end


local UpdateCastingInfo = function(self,name,texture,startTime,endTime,castID, notInterruptible)
        if not startTime then return end
        self.castID = castID
        self.startTime = startTime / 1000
        self.endTime = endTime / 1000
        self.bar:SetMinMaxValues(self.startTime,self.endTime)
        self.icon:SetTexture(texture)
        self.spellText:SetText(name)
        if self.unit ~= "player" and Spellgarden.badSpells[name] then
            if self.shine:IsPlaying() then self.shine:Stop() end
            self.shine:Play()
        end
        local color = coloredSpells[name] or (self.inverted and defaultChannelColor or defaultCastColor)
        self.bar:SetColor(unpack(color))
        self:Show()

        if self.shield then
            if notInterruptible then
                self.shield:Show()
            else
                self.shield:Hide()
            end
        end
    end
function Spellgarden.SpawnCastBar(self,unit,width,height)
    local f = CreateFrame("Frame",nil,UIParent)
    f.unit = unit

    -- if unit == "player" then
        -- self:MakeDoubleCastbar(f,width,height)
    -- else
        self:FillFrame(f,width,height)
    -- end

    f:Hide()
    f:RegisterEvent("UNIT_SPELLCAST_START")
    f:RegisterEvent("UNIT_SPELLCAST_DELAYED")
    f:RegisterEvent("UNIT_SPELLCAST_STOP")
    f:RegisterEvent("UNIT_SPELLCAST_FAILED")
    f:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
    f:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
    f:RegisterEvent("UNIT_SPELLCAST_CHANNEL_UPDATE")
    f:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
    f:SetScript("OnEvent", function(self, event, ...)
        return Spellgarden[event](self, event, ...)
    end)
    f.UpdateCastingInfo = UpdateCastingInfo

    return f
end

Spellgarden.AddMore = function(self, f)
    f:RegisterEvent("UNIT_SPELLCAST_NOT_INTERRUPTIBLE")
    f:RegisterEvent("UNIT_SPELLCAST_INTERRUPTIBLE")
    local height = f:GetHeight()
    local shield = f.icon:GetParent():CreateTexture(nil,"ARTWORK",nil,2)
    shield:SetTexture([[Interface\AchievementFrame\UI-Achievement-IconFrame]])
    shield:SetTexCoord(0,0.5625,0,0.5625)
    shield:SetWidth(height*1.8)
    shield:SetHeight(height*1.8)
    shield:SetPoint("CENTER",f.icon,"CENTER",0,0)
    shield:Hide()
    f.shield = shield

    local at = f.icon:GetParent():CreateTexture(nil,"OVERLAY")
    at:SetTexture([[Interface\SpellActivationOverlay\IconAlert]])
    at:SetTexCoord(0.00781250,0.50781250,0.27734375,0.52734375)
    at:SetWidth(height*1.8)
    at:SetHeight(height*1.8)
    at:SetPoint("CENTER",f.icon,"CENTER",0,0)
    at:SetAlpha(0)

    local sag = at:CreateAnimationGroup()
    local sa1 = sag:CreateAnimation("Alpha")
    sa1:SetToAlpha(1)
    sa1:SetDuration(0.3)
    sa1:SetOrder(1)
    local sa2 = sag:CreateAnimation("Alpha")
    sa2:SetToAlpha(0)
    sa2:SetDuration(0.5)
    sa2:SetSmoothing("OUT")
    sa2:SetOrder(2)

    f.shine = sag
end

Spellgarden.FillFrame = function(self, f,width,height)
    local backdrop = {
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", tile = true, tileSize = 0,
        insets = {left = -2, right = -2, top = -2, bottom = -2},
    }

    f:SetWidth(width)
    f:SetHeight(height)

    f:SetBackdrop(backdrop)
	f:SetBackdropColor(0, 0, 0, 0.7)

    local ic = CreateFrame("Frame",nil,f)
    ic:SetPoint("TOPLEFT",f,"TOPLEFT", 0, 0)
    ic:SetWidth(height)
    ic:SetHeight(height)
    local ict = ic:CreateTexture(nil,"ARTWORK",nil,0)
    ict:SetTexCoord(.07, .93, .07, .93)
    ict:SetAllPoints(ic)
    f.icon = ict

    f.stacktext = ic:CreateFontString(nil, "OVERLAY");
    -- f.stacktext:SetFont("Fonts\\FRIZQT___CYR.TTF",10,"OUTLINE")
    f.stacktext:SetHeight(ic:GetHeight())
    f.stacktext:SetJustifyH("RIGHT")
    f.stacktext:SetVertexColor(1,1,1)
    f.stacktext:SetPoint("RIGHT", ic, "RIGHT",1,-5)

    f.bar = CreateFrame("StatusBar",nil,f)
    f.bar:SetFrameStrata("MEDIUM")
    f.bar:SetStatusBarTexture("Interface\\AddOns\\NugRunning\\statusbar")
    f.bar:GetStatusBarTexture():SetDrawLayer("ARTWORK")
    f.bar:SetHeight(height)
    f.bar:SetWidth(width - height - 1)
    f.bar:SetPoint("TOPRIGHT",f,"TOPRIGHT",0,0)

    local m = 0.5
    f.bar.SetColor = function(self, r,g,b)
        self:SetStatusBarColor(r,g,b)
        self.bg:SetVertexColor(r*m,g*m,b*m)
    end

    f.bar.bg = f.bar:CreateTexture(nil, "BORDER")
	f.bar.bg:SetAllPoints(f.bar)
	f.bar.bg:SetTexture("Interface\\AddOns\\NugRunning\\statusbar")

    f.timeText = f.bar:CreateFontString();
    f.timeText:SetFont("Fonts\\FRIZQT___CYR.TTF",8)
    f.timeText:SetJustifyH("RIGHT")
    f.timeText:SetVertexColor(1,1,1)
    f.timeText:SetPoint("TOPRIGHT", f.bar, "TOPRIGHT",-6,0)
    f.timeText:SetPoint("BOTTOMLEFT", f.bar, "BOTTOMLEFT",0,0)

    f.spellText = f.bar:CreateFontString();
    f.spellText:SetFont("Fonts\\FRIZQT___CYR.TTF",height/2)
    f.spellText:SetWidth(width/4*3 -12)
    f.spellText:SetHeight(height/2+1)
    f.spellText:SetJustifyH("CENTER")
    f.spellText:SetVertexColor(1,1,1)
    f.spellText:SetPoint("LEFT", f.bar, "LEFT",6,0)
    f.spellText:SetAlpha(0.5)


    f:SetScript("OnUpdate",TimerOnUpdate)

    return f
end


Spellgarden.MakeDoubleCastbar = function(self, f,width,height)
    local backdrop = {
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", tile = true, tileSize = 0,
        insets = {left = -2, right = -2, top = -2, bottom = -2},
    }

    f:SetWidth(width)
    f:SetHeight(height)

    f:SetBackdrop(backdrop)
    f:SetBackdropColor(0, 0, 0, 0.7)

    local ic = CreateFrame("Frame",nil,f)
    -- ic:SetPoint("TOPLEFT",f,"TOPLEFT", 0, 0)
    ic:SetPoint("CENTER",f,"CENTER", 0, 0)
    ic:SetWidth(height)
    ic:SetHeight(height)
    local ict = ic:CreateTexture(nil,"ARTWORK",nil,0)
    ict:SetTexCoord(.07, .93, .07, .93)
    ict:SetAllPoints(ic)
    f.icon = ict

    f.stacktext = ic:CreateFontString(nil, "OVERLAY");
    f.stacktext:SetFont("Fonts\\FRIZQT____CYR.TTF",10,"OUTLINE")
    f.stacktext:SetHeight(ic:GetHeight())
    f.stacktext:SetJustifyH("RIGHT")
    f.stacktext:SetVertexColor(1,1,1)
    f.stacktext:SetPoint("RIGHT", ic, "RIGHT",1,-5)


    f.bar = CreateFrame("Frame",nil,f)
    f.bar:SetFrameStrata("MEDIUM")

    local left = CreateFrame("StatusBar",nil,f.bar)
    left:SetStatusBarTexture("Interface\\AddOns\\NugRunning\\statusbar")
    left:GetStatusBarTexture():SetDrawLayer("ARTWORK")
    left:SetHeight(height)
    left:SetWidth((width - height)/2 - 2)
    left:SetPoint("TOPLEFT", f.bar, "TOPLEFT",0,0)
    local leftbg = left:CreateTexture(nil, "BORDER")
    leftbg:SetAllPoints(left)
    leftbg:SetTexture("Interface\\AddOns\\NugRunning\\statusbar")
    left.bg = leftbg

    local right = CreateFrame("StatusBar",nil,f.bar)
    right:SetStatusBarTexture("Interface\\AddOns\\NugRunning\\statusbar")
    right:GetStatusBarTexture():SetDrawLayer("ARTWORK")
    right:SetHeight(height)
    right:SetWidth((width - height)/2 - 2)
    right:SetPoint("TOPRIGHT", f.bar, "TOPRIGHT",0,0)
    local rightbg = right:CreateTexture(nil, "BORDER")
    rightbg:SetAllPoints(right)
    rightbg:SetTexture("Interface\\AddOns\\NugRunning\\statusbar")
    right.bg = rightbg

    f.bar.left = left
    f.bar.right = right

    f.bar.SetMinMaxValues = function(self, min, max)
        self.min = min
        self.max = max
        self.left:SetMinMaxValues(min,max)
        self.right:SetMinMaxValues(min,max)
    end
    f.bar:SetMinMaxValues(0,100)

    f.bar.SetValue = function(self,v)
        self.left:SetValue(v)
        self.right:SetValue(self.max-v+self.min)
    end

    f.bar.SetStatusBarColor = function(self, ...)
        self.left:SetStatusBarColor(...)
        self.right:SetStatusBarColor(...)
    end

    local m = 0.5
    f.bar.SetColor = function(self, r,g,b)
        self.right:SetStatusBarColor(r,g,b)
        self.right.bg:SetVertexColor(r*m,g*m,b*m)
        self.left:SetStatusBarColor(r*m,g*m,b*m)
        self.left.bg:SetVertexColor(r,g,b)
    end

    -- f.bar:SetPoint("TOPRIGHT",f,"TOPRIGHT",0,0)
    f.bar:SetAllPoints(f)

    -- f.bar.bg = f.bar:CreateTexture(nil, "BORDER")
    -- f.bar.bg:SetAllPoints(f.bar)
    -- f.bar.bg:SetTexture("Interface\\AddOns\\NugRunning\\statusbar")

    f.timeText = f.bar:CreateFontString();
    f.timeText:SetFont("Fonts\\FRIZQT___CYR.TTF",8)
    f.timeText:SetJustifyH("RIGHT")
    f.timeText:SetVertexColor(1,1,1)
    f.timeText:SetPoint("TOPRIGHT", f.bar, "TOPRIGHT",-6,0)
    f.timeText:SetPoint("BOTTOMLEFT", f.bar, "BOTTOMLEFT",0,0)

    f.spellText = f.bar:CreateFontString();
    f.spellText:SetFont("Fonts\\FRIZQT___CYR.TTF",height/2)
    f.spellText:SetWidth(width/4*3 -12)
    f.spellText:SetHeight(height/2+1)
    f.spellText:SetJustifyH("CENTER")
    f.spellText:SetVertexColor(1,1,1)
    f.spellText:SetPoint("LEFT", f.bar, "LEFT",6,0)
    f.spellText:SetAlpha(0.5)


    f:SetScript("OnUpdate",TimerOnUpdate)

    return f
end


local function FindFreeCastbar()
    for i=1, MAX_NAMEPLATE_CASTBARS do 
        local bar = npCastbars[i]
        if not bar:IsShown() then
            return  bar
        end
    end
end

function Spellgarden:CreateNameplateCastbars()
    local npCastbarsHeader = CreateFrame("Frame", nil, UIParent)
    npCastbarsHeader:Hide()
    npCastbarsHeader:RegisterEvent("UNIT_SPELLCAST_START")
    npCastbarsHeader:RegisterEvent("UNIT_SPELLCAST_DELAYED")
    npCastbarsHeader:RegisterEvent("UNIT_SPELLCAST_STOP")
    npCastbarsHeader:RegisterEvent("UNIT_SPELLCAST_FAILED")
    npCastbarsHeader:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
    npCastbarsHeader:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
    npCastbarsHeader:RegisterEvent("UNIT_SPELLCAST_CHANNEL_UPDATE")
    npCastbarsHeader:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")

    -- npCastbarsHeader:RegisterEvent("NAME_PLATE_CREATED")
    -- npCastbarsHeader:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    npCastbarsHeader:RegisterEvent("NAME_PLATE_UNIT_REMOVED")

    npCastbarsHeader:SetScript("OnEvent", function(self, event, unit, ...)
        if not unit:match("nameplate") then return end
        if UnitIsUnit(unit, "player") then return end
        if event == "NAME_PLATE_UNIT_REMOVED" then
            if npCastbarsByUnit[unit] then
                npCastbarsByUnit[unit]:Hide()
            end
        elseif event == "UNIT_SPELLCAST_START" and not npCastbarsByUnit[unit] then
            local castbar = FindFreeCastbar()
            if castbar then
                castbar.unit = unit
                npCastbarsByUnit[unit] = castbar
                return Spellgarden[event](castbar, event, unit, ...)
            end
        else
            local castbar = npCastbarsByUnit[unit]
            if castbar then
                return Spellgarden[event](castbar, event, unit, ...)
            end
        end
    end)

    for i=1, MAX_NAMEPLATE_CASTBARS do 
        local f = CreateFrame("Frame", nil, npCastbarsHeader)
        self:FillFrame(f,200,20)
        self:AddMore(f)

        f:SetScript("OnHide", function(self)
            if self.unit then
                npCastbarsByUnit[self.unit] = nil
                self.unit = nil
            end
        end)

        f:SetPoint("TOPLEFT", npCastbarsHeader, "CENTER", 0, 0 + i*30)

        f:Hide()
        f.UpdateCastingInfo = UpdateCastingInfo
        table.insert(npCastbars, f)
    end

    return npCastbarsHeader
end