-- name: [CS] Ball
-- description: boing boingboing boing
-- incompatible:
-- category: cs

if not _G.charSelectExists then return end

local E_MODEL_PLAYER_BALL = smlua_model_util_get_id("baller_geo")
local ballColor = "FF0000"

local CT_BALL = _G.charSelect.character_add("Ball", "Boing Boing boing boingg", "Squishy6094", ballColor, E_MODEL_PLAYER_BALL, CT_MARIO, nil, 0.7)
_G.charSelect.character_add_palette_preset(E_MODEL_PLAYER_BALL, {[SHIRT] = ballColor})
_G.charSelect.character_add_voice(E_MODEL_PLAYER_BALL, {nil})

local gBallStates = {}
for i = 0, MAX_PLAYERS - 1 do
    gBallStates[i] = {
        prevVelX = 0,
        prevVelY = 0,
        prevVelZ = 0,
    }
end

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

local ACT_BALL_AIR = allocate_mario_action(ACT_GROUP_AIRBORNE | ACT_FLAG_AIR)
local ACT_BALL_BOUNCE = allocate_mario_action(ACT_GROUP_STATIONARY)
local ACT_BALL_ROLL = allocate_mario_action(ACT_GROUP_MOVING)
local ACT_BALL_DEATH = allocate_mario_action(ACT_GROUP_CUTSCENE | ACT_FLAG_STATIONARY | ACT_FLAG_INTANGIBLE | ACT_FLAG_INVULNERABLE)

local function act_ball_air(m)
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
            
            m.vel.x = m.vel.x * 0.7
            m.vel.z = m.vel.z * 0.7

            if m.controller.buttonDown & A_BUTTON ~= 0 then
                m.vel.y = math.max(m.vel.y, 0) + math.sqrt(m.vel.x^2 + m.vel.z^2)
            end
        end
    end
end

local function act_ball_bounce(m)
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
        
    if m.vel.y < targetWithButton - 1 then
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
end

local deathExitFrame = 60
local function act_ball_death(m)
    djui_chat_message_create(tostring(m.actionTimer))
    if (m.actionTimer == deathExitFrame) then
        level_trigger_warp(m, WARP_OP_DEATH);
    end
    local squishCalc = -m.actionTimer*0.01
    obj_set_gfx_scale(m.marioObj, 1 - squishCalc, 1 + squishCalc, 1 - squishCalc)

    m.actionTimer = m.actionTimer + 1
    return false;
end

hook_mario_action(ACT_BALL_AIR, act_ball_air --[[INT_FAST_ATTACK_OR_SHELL]])
hook_mario_action(ACT_BALL_BOUNCE, act_ball_bounce, INT_GROUND_POUND)
hook_mario_action(ACT_BALL_ROLL, act_ball_roll --[[INT_PUNCH]])
hook_mario_action(ACT_BALL_DEATH, act_ball_death)

local ballActs = {
    [ACT_BALL_AIR] = true,
    [ACT_BALL_BOUNCE] = true,
    [ACT_BALL_ROLL] = true,
}

local forceBallActs = {
    [ACT_SPAWN_NO_SPIN_AIRBORNE] = true,
    [ACT_SPAWN_SPIN_AIRBORNE] = true,
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

    [ACT_DEATH_EXIT] = true,
    [ACT_SPECIAL_DEATH_EXIT] = true,
}

local function knockback_ball(m, attackerObj)
    local newFaceAngle = 0
    if attackerObj then
        newFaceAngle = atan2s(m.pos.z - attackerObj.oPosZ, m.pos.x - attackerObj.oPosX)
    else
        newFaceAngle = m.faceAngle.y + 0x8000
    end

    m.invincTimer = 30

    m.vel.x = sins(newFaceAngle)*50
    m.vel.z = coss(newFaceAngle)*50

    if m.action & ACT_FLAG_AIR then
        m.vel.y = 50
        return set_mario_action(m, ACT_BALL_AIR, 0)
    else
        return set_mario_action(m, ACT_BALL_ROLL, 0)
    end
end

local function ball_update(m)
    local e = gBallStates[m.playerIndex]
    if m.health < 0x100 then
        if m.pos.y == m.floorHeight and (m.action ~= ACT_BALL_DEATH and m.action ~= ACT_BUBBLED) then
            set_mario_action(m, ACT_BALL_DEATH, 0)
        end
        return
    end
    if not ballActs[m.action] and ((
        m.action & ACT_GROUP_AUTOMATIC == 0 and
        m.action & ACT_GROUP_CUTSCENE == 0 and
        m.action & ACT_FLAG_INTANGIBLE == 0 and
        m.action & ACT_FLAG_INVULNERABLE == 0
    ) or forceBallActs[m.action]) then
        if m.action & ACT_FLAG_AIR ~= 0 then
            m.vel.y = 30
            set_mario_action(m, ACT_BALL_AIR, 0)
        else
            set_mario_action(m, ACT_BALL_ROLL, 0)
        end
    end

    m.faceAngle.y = atan2s(m.vel.z, m.vel.x)
    m.forwardVel = math.sqrt(m.vel.x^2 + m.vel.z^2)
    if m.action ~= ACT_BALL_DEATH then
        local squishCalc = (m.action & ACT_FLAG_AIR ~= 0 and math.abs(m.vel.y*0.005) or -m.vel.y*0.01)
        obj_set_gfx_scale(m.marioObj, 1 - squishCalc, 1 + squishCalc, 1 - squishCalc)
    end
    set_mario_animation(m, CHAR_ANIM_IDLE_HEAD_RIGHT)

    m.vel.x = clamp(m.vel.x, -100, 100)
    m.vel.y = clamp(m.vel.y, -100, 100)
    m.vel.z = clamp(m.vel.z, -100, 100)

    m.vel.x = clamp_soft(m.vel.x, -1, 1, 0.1)
    m.vel.y = clamp_soft(m.vel.y, -1, 1, 0.1)
    m.vel.z = clamp_soft(m.vel.z, -1, 1, 0.1)

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

local function ball_allow_water(m, water)
    if water == false then
        m.vel.y = m.vel.y + 1
        return false
    end
end

local function ball_before_action(m, nextAct)
    if knockbackActs[nextAct] then
        return knockback_ball(m)
    end
end

local function ball_init(prevChar, currChar)
    if currChar == CT_BALL then
        local m = gMarioStates[0]
        if m.action & ACT_FLAG_AIR ~= 0 then
            m.vel.y = 30
            set_mario_action(m, ACT_BALL_AIR, 0)
        else
            set_mario_action(m, ACT_BALL_ROLL, 0)
        end
    end
end

_G.charSelect.character_hook_moveset(CT_BALL, HOOK_MARIO_UPDATE, ball_update)
_G.charSelect.character_hook_moveset(CT_BALL, HOOK_ON_PVP_ATTACK, ball_on_pvp)
_G.charSelect.character_hook_moveset(CT_BALL, HOOK_ALLOW_INTERACT, ball_allow_interact)
_G.charSelect.character_hook_moveset(CT_BALL, HOOK_BEFORE_SET_MARIO_ACTION, ball_before_action)
_G.charSelect.character_hook_moveset(CT_BALL, HOOK_ALLOW_FORCE_WATER_ACTION, ball_allow_water)
_G.charSelect.hook_on_character_change(ball_init)