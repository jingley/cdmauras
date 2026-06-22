-------------------------------------------------------------------------------
--  Glow Alert 
--  Custom Glows on frames for certain conditions
-------------------------------------------------------------------------------
local _, ns = ...

local LCG = LibStub("LibCustomGlow-1.0")
local CustomGlow = {}
ns.CustomGlow = CustomGlow

local framePool = ns.Utils.GetFramePool(CustomGlow, "_framePool")

function CustomGlow:Initialize(option, source)
    self.cooldownID = source.cooldownID
    self.glowType = option.glowType
    self.glowColor = option.color
    self.placeholder = ns.AlertManager.GetPlaceholderFrame(source.cooldownID, source)
    self.spellID = ns.CDMUtils.GetSpellID(source)
    self.key = option.glowKey
    if not self.glowType then return end
    self.alphaFrame = framePool:Acquire()
    self.alphaFrame:ClearAllPoints()
    self.alphaFrame:SetAllPoints(self.placeholder)
    self.alphaFrame:SetParent(self.placeholder)
    self.alphaFrame:SetFrameStrata(self.placeholder:GetFrameStrata())
    self.alphaFrame:SetFrameLevel(self.placeholder:GetFrameLevel())
    self.alphaFrame:Show()

    if self.glowType == "proc" then
        self.proc_duration = option.proc_duration
        self.proc_startAnim = option.proc_startAnim
        self.proc_frameLevel = option.proc_frameLevel
    elseif self.glowType == "pixel" then
        self.pixel_number = option.pixel_number
        self.pixel_frequency = option.pixel_frequency
        self.pixel_length = option.pixel_length
        self.pixel_frameLevel = option.pixel_frameLevel
        self.pixel_thickness = option.pixel_thickness
        self.pixel_x = option.pixel_x
        self.pixel_y = option.pixel_y
        self.pixel_border = option.pixel_border
    end

    self:InitializeConditional(option)
end

function CustomGlow:NotifyConditionsActiveChanged()
    if self.isConditionsActive then
        self:Show()
    else
        self:Hide()
    end 
end

function CustomGlow:Show()
    if self.isGlowing or not self.isConditionsActive then return end
    local parent = self.alphaFrame
    if not parent then return end
    local color = self.glowColor or {0.95, 0.95, 0.32, 1}
    if self.glowType == "pixel" then
        LCG.PixelGlow_Start(parent, color, self.pixel_number, self.pixel_frequency, self.pixel_length, self.pixel_thickness, self.pixel_x, self.pixel_y, self.pixel_border, self.key, self.pixel_frameLevel or 8)
    elseif self.glowType == "proc" then
        LCG.ProcGlow_Start(parent, {
            color = color,
            duration = self.proc_duration,
            startAnim = self.proc_startAnim,
            frameLevel = self.proc_frameLevel,
            key = self.key
        })
    end
    self.isGlowing = true
end

function CustomGlow:Hide()
    if not self.isGlowing then return end
    local parent = self.alphaFrame
    if not parent then
        self.isGlowing = false
        return
    end
    if self.glowType == "pixel" then
        LCG.PixelGlow_Stop(parent, self.key)
    elseif self.glowType == "proc" then
        LCG.ProcGlow_Stop(parent, self.key)
    end
    self.isGlowing = false
end

function CustomGlow:Destroy()
    self:DestroyConditional()
    self:Hide()
    if self.alphaFrame then
        framePool:Release(self.alphaFrame)
    end
    self.glow = nil
    self.alphaFrame = nil
    self.cooldownID = nil
    self.glowColor = nil
    self.proc_duration = nil
    self.proc_startAnim = nil
    self.proc_frameLevel = nil
    self.pixel_number = nil
    self.pixel_frequency = nil
    self.pixel_length = nil
    self.pixel_frameLevel = nil
    self.pixel_thickness = nil
    self.pixel_x = nil
    self.pixel_y = nil
    self.pixel_border = nil
    self.placeholder = nil
    self.spellID = nil
    self.isActive = nil
    self.key = nil
end