
AddCSLuaFile()

SWEP.HoldType = "ar2"

if CLIENT then

   SWEP.PrintName = "Tagger"
   SWEP.Slot = 6

   SWEP.ViewModelFOV  = 54
   SWEP.ViewModelFlip = false

   SWEP.EquipMenuData = {
      type = "item_weapon",
      desc = [[Suspect someone as a traitor?
Tag them with this gun to keep an eye on them!

Make sure to hit them!
   ]]
   };


   SWEP.Icon = "vgui/ttt/icon_cust_tagger.png"
end

SWEP.Base = "weapon_tttbase"
SWEP.Primary.Recoil	= 10
SWEP.Primary.Damage = 1
SWEP.Primary.Delay = 1.0
SWEP.Primary.Cone = 0.01
SWEP.Primary.ClipSize = 2
SWEP.Primary.Automatic = false
SWEP.Primary.DefaultClip = 2
SWEP.Primary.ClipMax = 2

SWEP.Kind = WEAPON_EQUIP
SWEP.CanBuy = {ROLE_DETECTIVE} -- only traitors can buy
SWEP.LimitedStock = true -- only buyable once
SWEP.WeaponID = AMMO_TAGGER

-- if I run out of ammo types, this weapon is one I could move to a custom ammo
-- handling strategy, because you never need to pick up ammo for it
SWEP.Primary.Ammo = "AR2AltFire"

SWEP.UseHands			= true
SWEP.ViewModel = "models/weapons/c_pistol.mdl"
SWEP.WorldModel   = "models/weapons/w_pistol.mdl"

SWEP.Primary.Sound = Sound( "weapons/pistol/pistol_fire3.wav" )

SWEP.Tracer = "AR2Tracer"
// Don't want people IDing the body at all, so we just create a "ghost" corspe


if CLIENT then
   local targets = {}
   local indicator   = surface.GetTextureID("effects/select_ring")
local c4warn      = surface.GetTextureID("vgui/ttt/icon_c4warn")
local sample_scan = surface.GetTextureID("vgui/ttt/sample_scan")
local det_beacon  = surface.GetTextureID("vgui/ttt/det_beacon")
local function DrawTarget(tgt, size, offset, no_shrink)
   local scrpos = tgt:GetPos():ToScreen() -- sweet
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

   hook.Add("HUDPaint", "TaggerRadar", function()
      surface.SetDrawColor(255, 255, 0, 50)
      surface.SetTextColor(255, 255, 0, 50)
       surface.SetTexture(surface.GetTextureID("effects/select_ring"))
      LocalPlayer().targets = LocalPlayer().targets or {}
      for k,v in pairs(LocalPlayer().targets) do
        
         if not IsValid(v) or not IsValid(LocalPlayer()) then continue end
         if not v:Alive() or not LocalPlayer():Alive() then continue end
         DrawTarget(v,24,0)
      end


   end)

local function ResetTargetStuff()
  for k, ply in ipairs(player.GetAll()) do
    ply.targets = {}
  end
end
hook.Add( "TTTEndRound", "ResetTargetStuff", ResetTargetStuff )


local function ResetTargetStuff2()
  for k, ply in ipairs(player.GetAll()) do
   if !ply:IsSpec() then continue end
    ply.targets = {}
  end
end
hook.Add( "Think", "ResetTargetStuff2", ResetTargetStuff2 )

end

function Attach(att, path, dmginfo)
   local ent = path.Entity
   if not IsValid(ent) then return end
   if not ent:IsPlayer() then return end

if CLIENT then
   local tgt2 = {}

   tgt2.tgt = {}
   tgt2.tgt.nick = ent:Nick()
   tgt2.plr = ent
   table.Add(att.targets,tgt2)
end

end

function SWEP:ShootFlare()
   local cone = self.Primary.Cone
   local bullet = {}
   bullet.Num       = 1
   bullet.Src       = self.Owner:GetShootPos()
   bullet.Dir       = self.Owner:GetAimVector()
   bullet.Spread    = Vector( cone, cone, 0 )
   bullet.Tracer    = 1
   bullet.Force     = 2
   bullet.Damage    = 1
   bullet.TracerName = self.Tracer
   bullet.Callback = Attach

   self.Owner:FireBullets( bullet )
end
if CLIENT then
hook.Add("PlayerSpawn", "RadarStuff", function(ply)
   ply.targets = {}

end)

hook.Add("PlayerDeath", "RadarStuff", function(ply)
   ply.targets = {}

end)
end

function SWEP:PrimaryAttack()
   self:SetNextPrimaryFire( CurTime() + self.Primary.Delay )

   if not self:CanPrimaryAttack() then return end

   self:EmitSound( self.Primary.Sound )

   self:SendWeaponAnim( ACT_VM_PRIMARYATTACK )

   self:ShootFlare()

   self:TakePrimaryAmmo( 1 )

   if IsValid(self.Owner) then
      self.Owner:SetAnimation( PLAYER_ATTACK1 )

      self.Owner:ViewPunch( Angle( math.Rand(-0.2,-0.1) * self.Primary.Recoil, math.Rand(-0.1,0.1) *self.Primary.Recoil, 0 ) )
   end

   if ( (game.SinglePlayer() && SERVER) || CLIENT ) then
      self:SetNetworkedFloat( "LastShootTime", CurTime() )
   end
end

function SWEP:SecondaryAttack()
end

SWEP.PrimaryAnim = ACT_VM_PRIMARYATTACK_SILENCED
SWEP.ReloadAnim = ACT_VM_RELOAD_SILENCED

function SWEP:Deploy()
   self:SendWeaponAnim(ACT_VM_DRAW_SILENCED)
   return true
end
