-- name: [CS] Ball
-- description: boing boingboing boing
-- incompatible:
-- category: cs

if not _G.charSelectExists then return end

local E_MODEL_PLAYER_BALL = smlua_model_util_get_id("ball_player_geo")
local TEX_BALL_ICON = get_texture_info("player-ball-icon")
local ballColor = "FF0039"

local CT_BALL = _G.charSelect.character_add("Ball", "Boing Boing boing boingg", "Squishy6094", ballColor, E_MODEL_PLAYER_BALL, CT_MARIO, TEX_BALL_ICON, 0.7)
_G.charSelect.character_add_palette_preset(E_MODEL_PLAYER_BALL, {[CAP] = ballColor})
_G.charSelect.character_add_voice(E_MODEL_PLAYER_BALL, {nil})

local gBallStates = {}
for i = 0, MAX_PLAYERS - 1 do
    gBallStates[i] = {
        prevVelX = 0,
        prevVelY = 0,
        prevVelZ = 0,

        rotX = 0,
        rotZ = 0,
    }
end

local BALL_ANIM = 'ball_anim'
smlua_anim_util_register_animation(BALL_ANIM, 1, 0, 0, 0, 0, { 
    0x0000, 0x0000, 0x0000, 0x4000, 0x0000, 0x4000, 0x0000, 0xFFFF, 0x0000, 
    0x0000, 0xFFFF, 0x0000, 0x0000, 0xFFFF, 0x0000, 0x0000, 0xFFFF, 0x0000, 
    0x0000, 0x0000, 0x0000, 0xFFFF, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000, 
    0x0000, 0xFFFF, 0xFFFF, 0xFFFF, 0xFFFF, 0x0000, 0xFFFF, 0xFFFF, 0x0000, 
    0xFFFF, 0xFFFF, 0xFFFF, 0x0000, 0xFFFF, 0x0000, 0xFFFF, 0x0000, 0xFFFF, 
    0xFFFF, 0xFFFF, 0x0000, 0x0000, 0xFFFF, 0xFFFF, 0x0000, 0xFFFF, 0x0000, 
    0x0000, 0x0000, 0xFFFF, 0xFFFF, 0xFFFF, 0x0000, 0x0000, 0xFFFF, 0xFFFF, 
    

},{ 
    0x0001, 0x0000, 0x0001, 0x0001, 0x0001, 0x0002, 0x0001, 0x0003, 0x0001, 
    0x0004, 0x0001, 0x0005, 0x0001, 0x0006, 0x0001, 0x0007, 0x0001, 0x0008, 
    0x0001, 0x0009, 0x0001, 0x000A, 0x0001, 0x000B, 0x0001, 0x000C, 0x0001, 
    0x000D, 0x0001, 0x000E, 0x0001, 0x000F, 0x0001, 0x0010, 0x0001, 0x0011, 
    0x0001, 0x0012, 0x0001, 0x0013, 0x0001, 0x0014, 0x0001, 0x0015, 0x0001, 
    0x0016, 0x0001, 0x0017, 0x0001, 0x0018, 0x0001, 0x0019, 0x0001, 0x001A, 
    0x0001, 0x001B, 0x0001, 0x001C, 0x0001, 0x001D, 0x0001, 0x001E, 0x0001, 
    0x001F, 0x0001, 0x0020, 0x0001, 0x0021, 0x0001, 0x0022, 0x0001, 0x0023, 
    0x0001, 0x0024, 0x0001, 0x0025, 0x0001, 0x0026, 0x0001, 0x0027, 0x0001, 
    0x0028, 0x0001, 0x0029, 0x0001, 0x002A, 0x0001, 0x002B, 0x0001, 0x002C, 
    0x0001, 0x002D, 0x0001, 0x002E, 0x0001, 0x002F, 0x0001, 0x0030, 0x0001, 
    0x0031, 0x0001, 0x0032, 0x0001, 0x0033, 0x0001, 0x0034, 0x0001, 0x0035, 
    0x0001, 0x0036, 0x0001, 0x0037, 0x0001, 0x0038, 0x0001, 0x0039, 0x0001, 
    0x003A, 0x0001, 0x003B, 0x0001, 0x003C, 0x0001, 0x003D, 0x0001, 0x003E, 
});


local function get_mario_floor_steepness(m, angle)
    if angle == nil then angle = m.floorAngle end
    local floor = collision_find_surface_on_ray(m.pos.x, m.pos.y + 150, m.pos.z, 0, -300, 0).hitPos.y
    local floorInFront = collision_find_surface_on_ray(m.pos.x + sins(angle), m.pos.y + 150, m.pos.z + coss(angle), 0, -300, 0).hitPos.y
    local floorDif = floor - floorInFront 
    if floorDif > 20 or floorDif < -20 then floorDif = 0 end
    return floorDif
end

local function convert_s16(num)
    local min = -32768
    local max = 32767
    while (num < min) do
        num = max + (num - min)
    end
    while (num > max) do
        num = min + (num - max)
    end
    return num
end

local function clamp(num, min, max)
    return math.min(math.max(num, min), max)
end

local function clamp_soft(num, min, max, rate)
    if num < min then
        num = num + rate
        num = math.min(num, max)
    elseif num > max then
        num = num - rate
        num = math.max(num, min)
    end
    return num
end

local function get_mario_y_vel_from_floor(m)
    if m.pos.y == m.floorHeight then
        local velMag = math.sqrt(m.vel.x^2 + m.vel.y^2)
        local yVel = velMag*get_mario_floor_steepness(m)
        local velAngle = (velMag > 0 and atan2s(m.vel.z, m.vel.x) or m.faceAngle.y)
        return yVel * ((abs_angle_diff(velAngle, m.faceAngle.y) > 0x4000) and 1 or -1)
    else
        return m.vel.y
    end
end

local function cs_movesets_on()
    return _G.charSelect.get_options_status(_G.charSelect.optionTableRef.localMoveset) and not _G.charSelect.are_movesets_restricted()
end

local function interact_w_door(m)
    local wdoor = obj_get_nearest_object_with_behavior_id(m.marioObj, id_bhvDoorWarp)
    local door = obj_get_nearest_object_with_behavior_id(m.marioObj, id_bhvDoor)
    local sdoor = obj_get_nearest_object_with_behavior_id(m.marioObj, id_bhvStarDoor)

    if door ~= nil and dist_between_objects(m.marioObj, door) < 150 then
        interact_door(m, 0, door)
        --djui_chat_message_create("door.")
        if door.oAction == 0 then
            if (should_push_or_pull_door(m, door) & 1) ~= 0 then
                door.oInteractStatus = 0x00010000
            else
                door.oInteractStatus = 0x00020000
            end
        end
    elseif sdoor ~= nil and dist_between_objects(m.marioObj, sdoor) < 150 then
        interact_door(m, 0, sdoor)
        --djui_chat_message_create("star door.")
        if sdoor.oAction == 0 then
            if (should_push_or_pull_door(m, sdoor) & 1) ~= 0 then
                sdoor.oInteractStatus = 0x00010000
            else
                sdoor.oInteractStatus = 0x00020000
            end
        end
    elseif wdoor ~= nil and dist_between_objects(m.marioObj, wdoor) < 150 then
        interact_warp_door(m, 0, wdoor)
        set_mario_action(m, ACT_DECELERATING, 0)
        --djui_chat_message_create("warp door.")
        if wdoor.oAction == 0 then
            if (should_push_or_pull_door(m, wdoor) & 1) ~= 0 then
                wdoor.oInteractStatus = 0x00010000
            else
                wdoor.oInteractStatus = 0x00020000
            end
        end
    end
end

local ballSpeedCap = 100

local ACT_BALL_AIR = allocate_mario_action(ACT_GROUP_AIRBORNE | ACT_FLAG_AIR)
local ACT_BALL_WATER = allocate_mario_action(ACT_GROUP_SUBMERGED | ACT_FLAG_SWIMMING)
local ACT_BALL_BOUNCE = allocate_mario_action(ACT_GROUP_STATIONARY)
local ACT_BALL_ROLL = allocate_mario_action(ACT_GROUP_MOVING)
local ACT_BALL_DEATH = allocate_mario_action(ACT_GROUP_CUTSCENE | ACT_FLAG_STATIONARY | ACT_FLAG_INTANGIBLE | ACT_FLAG_INVULNERABLE)

local function act_ball_air(m)
    if m.playerIndex == 0 and not cs_movesets_on() then
        return set_mario_action(m, ACT_FREEFALL, 0)
    end

    m.vel.x = m.vel.x + sins(m.intendedYaw)*m.intendedMag/32
    m.vel.z = m.vel.z + coss(m.intendedYaw)*m.intendedMag/32

    local step = perform_air_step(m, AIR_STEP_NONE)
    if step == AIR_STEP_LANDED then
        if m.vel.y > -20 or m.controller.buttonDown & Z_TRIG ~= 0 then
            set_mario_action(m, ACT_BALL_ROLL, 0)
        else
            set_mario_action(m, ACT_BALL_BOUNCE, 0)
        end
    elseif step == AIR_STEP_HIT_WALL then
        local wall = m.wall
        if wall ~= nil then
            local nx, nz = wall.normal.x, wall.normal.z
            
            local vx, vz = m.vel.x, m.vel.z
            
            local dot = vx * nx + vz * nz
            
            m.vel.x = vx - 2 * dot * nx
            m.vel.z = vz - 2 * dot * nz

            if m.controller.buttonDown & A_BUTTON ~= 0 then
                m.vel.y = math.max(m.vel.y, 0) + math.sqrt(m.vel.x^2 + m.vel.z^2)
            end

            m.vel.x = m.vel.x * 0.7
            m.vel.z = m.vel.z * 0.7
        end
    end

    if m.waterLevel ~= nil and (m.pos.y + m.vel.y) < m.waterLevel - 140 then
        return set_mario_action(m, ACT_BALL_WATER, 0)
    end
end

local function act_ball_water(m)
    if m.playerIndex == 0 and not cs_movesets_on() then
        return set_mario_action(m, ACT_FREEFALL, 0)
    end

    m.vel.x = m.vel.x + sins(m.intendedYaw)*m.intendedMag/32
    m.vel.z = m.vel.z + coss(m.intendedYaw)*m.intendedMag/32

    local step = perform_water_step(m)
    if step == WATER_STEP_HIT_FLOOR then
        m.vel.y = math.abs(m.vel.y)
    elseif step == WATER_STEP_HIT_WALL then
        local wall = m.wall
        if wall ~= nil then
            local nx, nz = wall.normal.x, wall.normal.z
            
            local vx, vz = m.vel.x, m.vel.z
            
            local dot = vx * nx + vz * nz
            
            m.vel.x = vx - 2 * dot * nx
            m.vel.z = vz - 2 * dot * nz
            
            m.vel.x = m.vel.x * 0.9
            m.vel.z = m.vel.z * 0.9

            if m.controller.buttonDown & A_BUTTON ~= 0 then
                m.vel.y = math.max(m.vel.y, 0) + math.sqrt(m.vel.x^2 + m.vel.z^2)
            end
        end
    end

    if m.controller.buttonDown & Z_TRIG ~= 0 then
        m.vel.y = m.vel.y - 1
    elseif m.controller.buttonDown & A_BUTTON ~= 0 then
        m.vel.y = m.vel.y + 3
    else
        m.vel.y = m.vel.y + 2
    end

    m.vel.x = clamp(m.vel.x, -40, 40)
    m.vel.y = clamp(m.vel.y, -40, 40)
    m.vel.z = clamp(m.vel.z, -40, 40)
    
    if (m.pos.y + m.vel.y) >= m.waterLevel - 140 then
        m.pos.y = m.waterLevel - m.vel.y
        m.vel.y = m.vel.y
        set_mario_action(m, ACT_BALL_AIR, 0)
    end

    apply_water_current(m, {x = m.vel.x*0.25, y = m.vel.y*0.25, z = m.vel.z*0.25})
end

local function act_ball_bounce(m)
    if m.playerIndex == 0 and not cs_movesets_on() then
        return set_mario_action(m, ACT_FREEFALL, 0)
    end

    local e = gBallStates[m.playerIndex]
    if m.actionTimer == 0 then
        e.prevVelX = m.vel.x
        e.prevVelY = m.vel.y
        e.prevVelZ = m.vel.z
    end

    m.vel.x = e.prevVelX*0.1
    m.vel.z = e.prevVelZ*0.1

    perform_ground_step(m)

    local targetWithButton = math.abs(e.prevVelY)*0.9
    if m.controller.buttonDown & A_BUTTON ~= 0 then
        targetWithButton = math.abs(e.prevVelY)*1.1
    end
    
    if m.vel.y < targetWithButton - 5 then
        m.vel.y = m.vel.y + (targetWithButton - m.vel.y)*0.5
    else
        local floor = m.floor
        if floor ~= nil then
            local nx, ny, nz = floor.normal.x, floor.normal.y, floor.normal.z
            local push = ny < 0.99 and math.abs(e.prevVelY) * 1 or 0
            m.vel.x = e.prevVelX*0.6 + nx * push
            m.vel.z = e.prevVelZ*0.6 + nz * push
        end

        set_mario_action(m, ACT_BALL_AIR, 0)
    end

    m.actionTimer = m.actionTimer + 1
end

local function act_ball_roll(m)
    if m.playerIndex == 0 and not cs_movesets_on() then
        return set_mario_action(m, ACT_FREEFALL, 0)
    end

    local e = gBallStates[m.playerIndex]
    local step = perform_ground_step(m)
    if step == GROUND_STEP_LEFT_GROUND then
        set_mario_action(m, ACT_BALL_AIR, 0)
    elseif step == GROUND_STEP_HIT_WALL then
        local wall = m.wall
        if wall ~= nil then
            local nx, nz = wall.normal.x, wall.normal.z
            
            local vx, vz = m.vel.x, m.vel.z
            
            local dot = vx * nx + vz * nz
            
            m.vel.x = vx - 2 * dot * nx
            m.vel.z = vz - 2 * dot * nz
            
            m.vel.x = m.vel.x * 0.7
            m.vel.z = m.vel.z * 0.7
        end
    end

    local yVelFloor = get_mario_y_vel_from_floor(m)
    if m.actionTimer > 0 and ((e.yVelStore > 0 and yVelFloor <= 0 and e.yVelStore + yVelFloor > 10) or m.pos.y ~= m.floorHeight) then
        m.vel.y = e.yVelStore
        e.yVelStore = yVelFloor
        return set_mario_action(m, ACT_BALL_AIR, 0)
    else
        e.yVelStore = yVelFloor
    end

    m.vel.x = m.vel.x + sins(m.intendedYaw) * m.intendedMag / 32 * 1.1
    m.vel.y = m.vel.y * 0.9
    m.vel.z = m.vel.z + coss(m.intendedYaw) * m.intendedMag / 32 * 1.1

    local floor = m.floor
    if floor ~= nil then
        local nx, ny, nz = floor.normal.x, floor.normal.y, floor.normal.z
        local push = ny < 0.99 and 4 or 0
        m.vel.x = m.vel.x + nx * push
        m.vel.z = m.vel.z + nz * push
    end

    if m.controller.buttonDown & A_BUTTON ~= 0 and math.sqrt(m.vel.x^2 + m.vel.z^2)*0.5 > 20 then
        m.vel.y = -math.sqrt(m.vel.x^2 + m.vel.z^2)*0.7
        m.vel.x = m.vel.x * 0.7
        m.vel.z = m.vel.z * 0.7
        set_mario_action(m, ACT_BALL_BOUNCE, 0)
    end

    interact_w_door(m)
end

local deathExitFrame = 60
local function act_ball_death(m)
    if (m.actionTimer == deathExitFrame) then
        level_trigger_warp(m, WARP_OP_DEATH);
    end
    local squishCalc = -m.actionTimer*0.01
    obj_set_gfx_scale(m.marioObj, 1 - squishCalc, 1 + squishCalc, 1 - squishCalc)

    m.actionTimer = m.actionTimer + 1
    return false;
end

hook_mario_action(ACT_BALL_AIR, act_ball_air --[[INT_FAST_ATTACK_OR_SHELL]])
hook_mario_action(ACT_BALL_WATER, act_ball_water)
hook_mario_action(ACT_BALL_BOUNCE, act_ball_bounce, INT_GROUND_POUND)
hook_mario_action(ACT_BALL_ROLL, act_ball_roll --[[INT_PUNCH]])
hook_mario_action(ACT_BALL_DEATH, act_ball_death)

local ballActs = {
    [ACT_BALL_AIR] = true,
    [ACT_BALL_BOUNCE] = true,
    [ACT_BALL_ROLL] = true,

    -- Allowed Vanilla Actions
    [ACT_DISAPPEARED] = true,
    [ACT_CREDITS_CUTSCENE] = true,
    [ACT_DEATH_EXIT_LAND] = true,
    [ACT_SQUISHED] = true,
    [ACT_IN_CANNON] = true,
    [ACT_SHOT_FROM_CANNON] = true,
    [ACT_TELEPORT_FADE_OUT] = true,
    [ACT_TELEPORT_FADE_IN] = true,
    [ACT_PULLING_DOOR] = true,
    [ACT_PUSHING_DOOR] = true,
    [ACT_DECELERATING] = true,
    [ACT_DROWNING] = true,
    [ACT_AIR_THROW] = true,
}

local forceBallActs = {
    [ACT_SPAWN_NO_SPIN_AIRBORNE] = true,
    [ACT_SPAWN_SPIN_AIRBORNE] = true,
    [ACT_FALL_AFTER_STAR_GRAB] = true,
    [ACT_WALKING] = true,
    [ACT_WATER_PLUNGE] = true,
}

local knockbackActs = {
    [ACT_BACKWARD_AIR_KB] = true,
    [ACT_BACKWARD_GROUND_KB] = true,
    [ACT_HARD_BACKWARD_AIR_KB] = true,
    [ACT_HARD_BACKWARD_GROUND_KB] = true,
    [ACT_SOFT_BACKWARD_GROUND_KB] = true,
    [ACT_FORWARD_AIR_KB] = true,
    [ACT_FORWARD_GROUND_KB] = true,
    [ACT_HARD_FORWARD_AIR_KB] = true,
    [ACT_HARD_FORWARD_GROUND_KB] = true,
    [ACT_SOFT_FORWARD_GROUND_KB] = true,
    [ACT_THROWN_FORWARD] = true,
    [ACT_THROWN_BACKWARD] = true,

    [ACT_DEATH_EXIT] = true,
    [ACT_SPECIAL_DEATH_EXIT] = true,
    [ACT_DEATH_EXIT_LAND] = true,
    [ACT_EXIT_AIRBORNE] = true,
}

local function force_to_ball_state(m)
    if m.action & ACT_GROUP_AIRBORNE ~= 0 then
        return set_mario_action(m, ACT_BALL_AIR, 0)
    elseif m.action & ACT_GROUP_SUBMERGED ~= 0 then
        return set_mario_action(m, ACT_BALL_WATER, 0)
    else
        return set_mario_action(m, ACT_BALL_ROLL, 0)
    end
end

local function knockback_ball(m, attackerObj)
    local newFaceAngle = 0
    if attackerObj then
        newFaceAngle = atan2s(m.pos.z - attackerObj.oPosZ, m.pos.x - attackerObj.oPosX)
    else
        newFaceAngle = m.faceAngle.y + 0x8000
    end

    m.invincTimer = 30

    m.vel.x = sins(newFaceAngle)*50
    m.vel.y = 50
    m.vel.z = coss(newFaceAngle)*50

    return force_to_ball_state(m)
end

---@param m MarioState
local function ball_update(m)
    local e = gBallStates[m.playerIndex]
    if m.health < 0x100 then
        if m.pos.y == m.floorHeight and (m.action ~= ACT_BALL_DEATH and m.action ~= ACT_BUBBLED) then
            set_mario_action(m, ACT_BALL_DEATH, 0)
        end
        return
    end
    if (not ballActs[m.action] and ((
        m.action & ACT_GROUP_AUTOMATIC == 0 and
        m.action & ACT_GROUP_CUTSCENE == 0 and
        m.action & ACT_FLAG_INTANGIBLE == 0 and
        m.action & ACT_FLAG_INVULNERABLE == 0
    )) or forceBallActs[m.action]) then
        force_to_ball_state(m)
    end

    m.faceAngle.y = atan2s(m.vel.z, m.vel.x)
    m.forwardVel = math.sqrt(m.vel.x^2 + m.vel.z^2)
    if m.action ~= ACT_BALL_DEATH then
        local squishCalc = (m.action & ACT_FLAG_AIR ~= 0 and math.abs(m.vel.y*0.005) or -m.vel.y*0.01)
        obj_set_gfx_scale(m.marioObj, 1 - squishCalc, 1 + squishCalc, 1 - squishCalc)
    end

    smlua_anim_util_set_animation(m.marioObj, BALL_ANIM)

    m.vel.x = clamp(m.vel.x, -ballSpeedCap, ballSpeedCap)
    m.vel.y = clamp(m.vel.y, -ballSpeedCap, ballSpeedCap)
    m.vel.z = clamp(m.vel.z, -ballSpeedCap, ballSpeedCap)

    m.vel.x = clamp_soft(m.vel.x, -1, 1, 0.1)
    m.vel.y = clamp_soft(m.vel.y, -1, 1, 0.1)
    m.vel.z = clamp_soft(m.vel.z, -1, 1, 0.1)

    -- Rolling Anim
    e.rotX = e.rotX + m.forwardVel*0x60
    m.marioObj.header.gfx.pos.y = m.pos.y + 50
    m.marioObj.header.gfx.angle.x = e.rotX
    --m.marioObj.header.gfx.angle.z = 0x4000

    -- Local Update
    if m.playerIndex == 0 then
        -- No painting warps during eye frames (for knocking out ball)
        if m.invincTimer > 0 and m.floor ~= nil and (m.floor.type == SURFACE_WARP or (m.floor.type >= SURFACE_PAINTING_WARP_D3 and m.floor.type <= SURFACE_PAINTING_WARP_FC) or (m.floor.type >= SURFACE_INSTANT_WARP_1B and m.floor.type <= SURFACE_INSTANT_WARP_1E)) then
            m.floor.type = SURFACE_DEFAULT
        end
    end
end

local function ball_on_pvp(a, v, int)
    if _G.charSelect.character_get_current_number(v.playerIndex) == CT_BALL then
        v.vel.y = math.max(30, v.vel.y)
        return knockback_ball(v, a.marioObj)
    end
end

local function ball_allow_interact(m, o, type)
    if type == INTERACT_POLE then
        return false
    end
end

local function ball_before_action(m, nextAct)
    if knockbackActs[nextAct] then
        gBallStates[m.playerIndex].prevVelY = m.vel.y
        if m.action == ACT_THROWN_FORWARD then
            m.faceAngle.y = convert_s16(m.faceAngle.y + 0x8000)
        end
        return knockback_ball(m)
    elseif (not ballActs[nextAct] and ((
        nextAct & ACT_GROUP_AUTOMATIC == 0 and
        nextAct & ACT_GROUP_CUTSCENE == 0 and
        nextAct & ACT_FLAG_INTANGIBLE == 0 and
        nextAct & ACT_FLAG_INVULNERABLE == 0
    )) or forceBallActs[nextAct]) then
        return force_to_ball_state(m)
    end
end

local function ball_init(prevChar, currChar)
    if not cs_movesets_on() then
        return
    end
    local m = gMarioStates[0]
    if currChar == CT_BALL then
        force_to_ball_state(m)
    end
end

-- BOWSER INTERACTION CODE
-- Thank you SwagSkeleton95
local function hit_effect_bowser(o, target)
    if target.oAction ~= 19 and target.oAction ~= 4 and target.oAction ~= 12 and target.oAction ~= 1 then
        target.oMoveFlags = 0
        target.oFaceAngleYaw = obj_angle_to_object(target, o)
        target.oMoveAngleYaw = obj_angle_to_object(target, o)
        target.oSubAction = 0
        target.oAction = 1
        target.oVelY = 25
        target.oForwardVel = -45
    end
end


local function ball_on_interact(m, obj, interactType, interactBool)
    local e = gBallStates[m.playerIndex]
    if e.prevVelY ~= nil and e.prevVelY < -14.0 then
        --if obj_has_behavior_id(obj, id_bhvBowser) ~= 0 then -- Seems to break
        --    hit_effect_bowser(m.marioObj, obj)
        --    m.health = m.health + (4 << 8)
        if obj_has_behavior_id(obj, id_bhvBowserBodyAnchor) ~= 0 then
            hit_effect_bowser(m.marioObj, obj.parentObj)
            m.hurtCounter = 0
        end
    end
end

_G.charSelect.character_hook_moveset(CT_BALL, HOOK_MARIO_UPDATE, ball_update)
_G.charSelect.character_hook_moveset(CT_BALL, HOOK_ON_PVP_ATTACK, ball_on_pvp)
_G.charSelect.character_hook_moveset(CT_BALL, HOOK_ALLOW_INTERACT, ball_allow_interact)
_G.charSelect.character_hook_moveset(CT_BALL, HOOK_BEFORE_SET_MARIO_ACTION, ball_before_action)
_G.charSelect.character_hook_moveset(CT_BALL, HOOK_ON_INTERACT, ball_on_interact)
_G.charSelect.character_hook_moveset(CT_BALL, HOOK_ON_LEVEL_INIT, ball_init)
_G.charSelect.hook_on_character_change(ball_init)