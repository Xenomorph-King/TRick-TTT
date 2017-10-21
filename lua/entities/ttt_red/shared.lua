-- c4 explosive

local math = math

if SERVER then
   AddCSLuaFile("shared.lua")
end

if CLIENT then
   -- this entity can be DNA-sampled so we need some display info
   ENT.Icon = "vgui/ttt/icon_c4"
   ENT.PrintName = "R.E.D"

   local GetPTranslation = LANG.GetParamTranslation
   local hint_params = {usekey = Key("+use", "USE")}

   ENT.TargetIDHint = {
      name = "R.E.D",
   };
end


ENT.Type = "anim"
ENT.Model = Model("models/weapons/w_slam.mdl")

ENT.CanHavePrints = true
ENT.CanUseKey = true
ENT.Avoidable = true

AccessorFunc(ENT,"thrower","Thrower")

AccessorFuncDT(ENT, "explode_time", "ExplodeTime")
AccessorFuncDT(ENT, "armed", "Armed")

ENT.Beep = 0
ENT.DetectiveNearRadius = 300
ENT.SafeWires = nil

function ENT:SetupDataTables()
   self:DTVar("Int", 0, "explode_time")
   self:DTVar("Bool", 0, "armed")
end

function ENT:Initialize()
   self:SetModel(self.Model)

   if SERVER then
      self:PhysicsInit(SOLID_VPHYSICS)
   end
   self:SetMoveType(MOVETYPE_VPHYSICS)
   self:SetSolid(SOLID_BBOX)
   self:SetCollisionGroup(COLLISION_GROUP_WEAPON)

   if SERVER then
      self:SetUseType(SIMPLE_USE)
   end
   self:SetHealth(1)
   self:SetArmed(false)
   if not self:GetThrower() then self:SetThrower(nil) end
   self.Exploding = false
   timer.Simple(1.5, function()
      self:SetArmed(true)
      if SERVER then
         self:SendWarn(true)
      end
      self:EmitSound(Sound("buttons/button17.wav"))
   end)

end


   -- traditional equipment destruction effects
   function ENT:OnTakeDamage(dmginfo)


      self:TakePhysicsDamage(dmginfo)

      self:SetHealth(self:Health() - dmginfo:GetDamage())

      local att = dmginfo:GetAttacker()
      if IsPlayer(att) then
        DamageLog(Format("%s exploded a R.E.D",
                     att:Nick(), dmginfo:GetDamage()))
      end

      if self:Health() < 0 then

      
        self:EmitSound(Sound("buttons/button4.wav"))

        self:Explode(dmginfo:GetAttacker())


      end
   end



function ENT:WeldToGround(state)
   if self.IsOnWall then return end

   if state then
      -- getgroundentity does not work for non-players
      -- so sweep ent downward to find what we're lying on
      local ignore = player.GetAll()
      table.insert(ignore, self)

      local tr = util.TraceEntity({start=self:GetPos(), endpos=self:GetPos() - Vector(0,0,16), filter=ignore, mask=MASK_SOLID}, self)

      -- Start by increasing weight/making uncarryable
      local phys = self:GetPhysicsObject()
      if IsValid(phys) then
         -- Could just use a pickup flag for this. However, then it's easier to
         -- push it around.
         self.OrigMass = phys:GetMass()
         phys:SetMass(150)
      end

      if tr.Hit and (IsValid(tr.Entity) or tr.HitWorld) then
         -- "Attach" to a brush if possible
         if IsValid(phys) and tr.HitWorld then
            phys:EnableMotion(false)
         end

         -- Else weld to objects we cannot pick up
         local entphys = tr.Entity:GetPhysicsObject()
         if IsValid(entphys) and entphys:GetMass() > CARRY_WEIGHT_LIMIT then
            constraint.Weld(self, tr.Entity, 0, 0, 0, true)
         end

         -- Worst case, we are still uncarryable
      end
   else
      constraint.RemoveConstraints(self, "Weld")
      local phys = self:GetPhysicsObject()
      if IsValid(phys) then
         phys:EnableMotion(true)
         phys:SetMass(self.OrigMass or 10)
      end
   end
end

function ENT:SphereDamage(dmgowner, center, radius)
   -- It seems intuitive to use FindInSphere here, but that will find all ents
   -- in the radius, whereas there exist only ~16 players. Hence it is more
   -- efficient to cycle through all those players and do a Lua-side distance
   -- check.

   local r = radius ^ 2 -- square so we can compare with dotproduct directly


   -- pre-declare to avoid realloc
   local d = 0.0
   local diff = nil
   local dmg = 0
   for _, ent in pairs(player.GetAll()) do
      if IsValid(ent) and ent:Team() == TEAM_TERROR then

         -- dot of the difference with itself is distance squared
         diff = center - ent:GetPos()
         d = diff:DotProduct(diff)

         if d < r then
            -- deadly up to a certain range, then a quick falloff within 100 units
            d = math.max(0, math.sqrt(d) - 490)
            dmg = -0.01 * (d^2) + 125

            local dmginfo = DamageInfo()
            dmginfo:SetDamage(dmg)
            dmginfo:SetAttacker(dmgowner)
            dmginfo:SetInflictor(self)
            dmginfo:SetDamageType(DMG_BLAST)
            dmginfo:SetDamageForce(center - ent:GetPos())
            dmginfo:SetDamagePosition(ent:GetPos())

            ent:TakeDamageInfo(dmginfo)
         end
      end
   end
end

local c4boom = Sound("c4.explode")
function ENT:Explode(ply)
   if not IsValid(self) or self.Exploding then return end
   
   self.Exploding = true
   
   local pos = self:GetPos()
   local radius = 200
   local damage = 500
   
   util.BlastDamage( self, ply, pos, radius, damage )
   local effect = EffectData()
      effect:SetStart(pos)
      effect:SetOrigin(pos)
      effect:SetScale(radius)
      effect:SetRadius(radius)
      effect:SetMagnitude(damage)
   util.Effect("Explosion", effect, true, true)
   
   sound.Play( c4boom, self:GetPos(), 60, 150 )
   if SERVER then
      self:SendWarn(false)
   end
   self:Remove()
end


if SERVER then
   -- Inform traitors about us
   function ENT:SendWarn(armed)
      //net.Start("TTT_C4Warn")
        // net.WriteUInt(self:EntIndex(), 16)
       //  net.WriteBit(armed)
        // net.WriteVector(self:GetPos())
       //  net.WriteFloat(-1)
    //  net.Send(GetTraitorFilter(true))
   end

   function ENT:OnRemove()
      self:SendWarn(false)
   end

   function ENT:Disarm(ply)
      local owner = self:GetOwner()

      SCORE:HandleC4Disarm(ply, owner, true)


      self:SetArmed(false)
      self:WeldToGround(false)
      //self:SendWarn(false)

   end

 
end

if CLIENT then



   function ENT:GetTimerPos()
      local att = self:GetAttachment(self:LookupAttachment("controlpanel0_ur"))
      if att then
         return att
      else
         local ang = self:GetAngles()
         ang:RotateAroundAxis(self:GetUp(), 180)
         local pos = (self:GetPos() - self:GetForward() * 2 +
                      self:GetUp() * 0.8 - self:GetRight() * 1.5)
         return { Pos = pos, Ang = ang }
      end
   end

   local strtime = util.SimpleTime
   local max = math.max
   function ENT:Draw()
      self:DrawModel()

      if self:GetArmed() then
         local angpos_ur = self:GetTimerPos()
         if angpos_ur then
            cam.Start3D2D(angpos_ur.Pos, angpos_ur.Ang, 0.1)
            draw.DrawText("ARMED", "C4ModelTimer", -1, 1, COLOR_RED, TEXT_ALIGN_RIGHT)
            cam.End3D2D()
         end
      end
   end
end


if CLIENT then
   local redwarn      = Material("vgui/ttt/icon_arc_redwarn.png")
   local function DrawTarget(tgt, size, offset, no_shrink)
      local pos = tgt:GetPos() 
      local scrpos = pos:ToScreen() -- sweet
      local sz = (IsOffScreen(scrpos) and (not no_shrink)) and size/2 or size

      scrpos.x = math.Clamp(scrpos.x, sz, ScrW() - sz)
      scrpos.y = math.Clamp(scrpos.y, sz, ScrH() - sz)
      
      if IsOffScreen(scrpos) then return end

      surface.DrawTexturedRect(scrpos.x - sz, scrpos.y - sz, sz * 2, sz * 2)

      -- Drawing full size?
      if sz == size then
         local text = math.ceil(LocalPlayer():GetPos():Distance(tgt:GetPos()))
         local w, h = surface.GetTextSize(text)

         -- Show range to target
         surface.SetTextPos(scrpos.x - w/2, scrpos.y + (offset * sz) - h/2)
         surface.DrawText(text)

         if tgt.t then
            -- Show time
            text = util.SimpleTime(tgt.t - CurTime(), "%02i:%02i")
            w, h = surface.GetTextSize(text)

            surface.SetTextPos(scrpos.x - w / 2, scrpos.y + sz / 2)
            surface.DrawText(text)
         elseif tgt.nick then
            -- Show nickname
            text = tgt.nick
            w, h = surface.GetTextSize(text)

            surface.SetTextPos(scrpos.x - w / 2, scrpos.y + sz / 2)
            surface.DrawText(text)
         end
      end
   end

   hook.Add("HUDPaint", "RED_Radar1", function()
      surface.SetDrawColor(255, 0, 0, 255)
      surface.SetTextColor(255, 255, 255, 50)
      surface.SetMaterial(redwarn)
      for k,v in pairs(ents.FindByClass("ttt_red")) do
         if not IsValid(v) or not IsValid(LocalPlayer()) then continue end
         if not (LocalPlayer():IsActiveTraitor() && not LocalPlayer():IsSpec()) then continue end
         DrawTarget(v,24,0,true)
      end


   end)
end