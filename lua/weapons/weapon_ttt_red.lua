
-- traitor equipment: c4 bomb

AddCSLuaFile()

SWEP.HoldType			= "slam"

if CLIENT then
   SWEP.PrintName			= "R.E.D"
   SWEP.Slot				= 6

   SWEP.EquipMenuData = {
      type  = "item_weapon",
      name  = "REMOTE EXPLOSIVE DEVICE",
      desc  = [[The R.E.D is very similar
to a tripmine. You place it, you explode it.

Left click to place, Right click to detonate.
]]
   };

   SWEP.Icon = "vgui/ttt/icon_cust_red.png"
   SWEP.IconLetter = "I"
end

SWEP.Base = "weapon_tttbase"

SWEP.Kind = WEAPON_EQUIP
SWEP.CanBuy = {ROLE_TRAITOR} -- only traitors can buy
SWEP.WeaponID = AMMO_RED

SWEP.UseHands			= true
SWEP.ViewModelFlip		= false
SWEP.ViewModelFOV		= 54
SWEP.ViewModel  = "models/weapons/c_slam.mdl"
SWEP.WorldModel = "models/weapons/w_slam.mdl"

SWEP.DrawCrosshair      = false
SWEP.ViewModelFlip      = false
SWEP.Primary.ClipSize       = -1
SWEP.Primary.DefaultClip    = -1
SWEP.Primary.Automatic      = true
SWEP.Primary.Ammo       = "none"
SWEP.Primary.Delay = 5.0

SWEP.Secondary.ClipSize     = -1
SWEP.Secondary.DefaultClip  = -1
SWEP.Secondary.Automatic    = true
SWEP.Secondary.Ammo     = "none"
SWEP.Secondary.Delay = 1.0
SWEP.Bomb = nil
SWEP.NoSights = true

local throwsound = Sound( "Weapon_SLAM.SatchelThrow" )

function SWEP:PrimaryAttack()
   self:SetNextPrimaryFire( CurTime() + self.Primary.Delay )
   self:Stick()
end

function SWEP:SecondaryAttack()
   self:SetNextSecondaryFire( CurTime() + self.Secondary.Delay )

   if self.Bomb == nil or !self.Bomb:GetArmed() then self.Owner:EmitSound(Sound("buttons/button8.wav")) self:SetNextSecondaryFire( CurTime() + self.Secondary.Delay ) return end
   self.Owner:EmitSound(Sound("buttons/button9.wav"))
   self.Bomb:Explode(self.Owner)
   self:SendWeaponAnim( ACT_SLAM_DETONATOR_DETONATE )
   timer.Simple(0.2, function()
      self:Remove()
   end)
end

function SWEP:Deploy()
   self.Weapon:SendWeaponAnim(ACT_SLAM_TRIPMINE_DRAW)
   return true
end


local sticksound = Sound( "weapons/slam/mine_mode.wav" )

function SWEP:Stick()
   if SERVER then
      local ply = self.Owner
      if not IsValid(ply) then return end
       if self.Planted then return end
       
       local ignore = {ply, self.Weapon}
       local spos = ply:GetShootPos()
       local epos = spos + ply:GetAimVector() * 120
       local tr = util.TraceLine({start=spos, endpos=epos, filter=ignore, mask=MASK_SOLID})
       if tr.HitWorld then
         local red = ents.Create("ttt_red")
         if IsValid(red) then
            red:PointAtEntity(ply)
            
            local tr_ent = util.TraceEntity({start=spos, endpos=epos, filter=ignore, mask=MASK_SOLID}, red)
            if tr_ent.HitWorld then
               self.Weapon:SendWeaponAnim(ACT_SLAM_TRIPMINE_ATTACH)
               timer.Create( "anim", 0.2, 1, function() self:SendWeaponAnim( ACT_SLAM_DETONATOR_DRAW ) end )
               timer.Simple(0.1, function()
                  if not IsValid(self) then return end
               
                  local ang = tr_ent.HitNormal:Angle()
                  ang:RotateAroundAxis(ang:Right(), -90)

                  red:SetPos(tr_ent.HitPos + tr_ent.HitNormal * 2)
                  red:SetAngles(ang)
                  red:SetThrower(ply)
                  red:Spawn()
                  self.Bomb = red
                  
                  red.fingerprints = { ply }
                  
                  local phys = red:GetPhysicsObject()
                  if IsValid(phys) then
                     phys:EnableMotion(false)
                  end
                  
                  self:EmitSound(sticksound)
                  
                  red.IsOnWall = true

                  self.Planted = true
                  self.FOV = 10
               end)
            end
         end
         
         ply:SetAnimation( PLAYER_ATTACK1 )
       end
   end
end


function SWEP:Reload()
   return false
end

function SWEP:OnRemove()
   if CLIENT and IsValid(self.Owner) and self.Owner == LocalPlayer() and self.Owner:Alive() then
      RunConsoleCommand("lastinv")
   end
end
