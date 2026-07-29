--
-- BRP Check Effects
--
-- Stock Basic Roleplaying has zero EffectManager usage anywhere in its own
-- code (confirmed via direct source read) - the CoreRPG Effects list on
-- the Combat Tracker is present but nothing ever reads it. This wires up
-- the first piece: a CHECK effect keyword for the three roll types that
-- share an identical "roll under %" shape:
--
--	CHECK: <mod>[, <skill/characteristic/power name>]
--		Flat percentage bonus/penalty to matching checks. The name filter
--		is optional (comma-separated, e.g. "CHECK: 30, Spot"); omit it to
--		apply to every Skill, Characteristic, and Power check. Matches
--		case-insensitively against the check's own name (e.g. "Spot
--		Hidden", "Strength", "Telepathy").
--	ATK: <mod>[, <weapon or linked skill name>]
--		Flat percentage bonus/penalty to matching Attack rolls. Matches
--		against the weapon's own name (e.g. "Sword") and, as a fallback,
--		its linked skill's name (e.g. "Melee Weapons") - see the note on
--		weapon attack% below for why the fallback exists.
--
-- ActionSkill.getRoll, ActionAbility.getRoll, and ActionPowers.getRoll
-- (manager_action_skill.lua, manager_action_ability.lua,
-- manager_action_powers.lua) are near-identical: each builds rRoll.nTarget
-- from a precomputed total/base, then adds the modifier tray's flat stack
-- via ModifierStack.getStack() before returning. There is no mod-handler
-- stage for any of these three roll types (only result handlers are
-- registered), so the tray stack - and now the CHECK effect bonus - is
-- applied inline in getRoll() itself, matching the ruleset's own existing
-- pattern rather than introducing a new pipeline stage that doesn't
-- otherwise exist here.
--
-- Each roll type exposes an identifying field on rAction already (used for
-- chat text), reused here as the effect filter: rAction.label (skill name
-- or power name) and/or rAction.stat (characteristic name).
--
-- ActionAttack.getRoll (manager_action_attack.lua) has the same shape as
-- the three above, just named rRoll.nBase instead of rRoll.nTarget, so it
-- gets the same treatment as ATK.
--
-- Weapon attack% is a stale snapshot, not a live total: char_weapon.lua's
-- updateAttack() looks up the weapon's linked skill by name and copies
-- that skill's stored "total" DB field straight into the weapon's own
-- "attack" field - it never goes through a roll, so it never sees a CHECK
-- effect bonus on the underlying skill (that only applies inside
-- ActionSkill.getRoll at roll time). Since rAction only ever carries the
-- weapon's name (rAction.label), not its linked skill, ATK also looks up
-- the weapon's own "baseskill" DB field directly (both PC and NPC weapon
-- rows share the same .weaponlist datasource and field name) so a CHECK-
-- or ATK-tagged effect can still target attacks by their underlying skill
-- name even though the roll itself never touches that skill.
--
-- Matching is done by hand rather than via EffectManager.getBonusMod's own
-- tFilter option: CoreRPG's tag parser keeps a bracketed filter's brackets
-- literally in the parsed text (confirmed via direct source read of
-- parseEffectCompSimple - "[Spot]" parses to the remainder string "[Spot]",
-- brackets included) and the underlying Set-based match is a raw,
-- case-sensitive string comparison with no normalization anywhere in that
-- path. A GM typing a name in its natural case (or with brackets) would
-- silently never match. getCompsDataByTag() is called with no tFilter
-- (returns every active CHECK component, already respecting active state/
-- expiration/conditionals - the parts worth reusing) and each component's
-- own remainder tags are compared here with brackets stripped and case
-- folded on both sides.
--

local _fnOrigSkillGetRoll, _fnOrigAbilityGetRoll, _fnOrigPowersGetRoll, _fnOrigAttackGetRoll;

function onInit()
	_fnOrigSkillGetRoll = ActionSkill.getRoll;
	ActionSkill.getRoll = skillGetRoll;

	_fnOrigAbilityGetRoll = ActionAbility.getRoll;
	ActionAbility.getRoll = abilityGetRoll;

	_fnOrigPowersGetRoll = ActionPowers.getRoll;
	ActionPowers.getRoll = powersGetRoll;

	_fnOrigAttackGetRoll = ActionAttack.getRoll;
	ActionAttack.getRoll = attackGetRoll;
end

function skillGetRoll(rActor, rAction)
	local rRoll = _fnOrigSkillGetRoll(rActor, rAction);
	applyCheckEffect(rActor, rRoll, rAction);
	return rRoll;
end

function abilityGetRoll(rActor, rAction)
	local rRoll = _fnOrigAbilityGetRoll(rActor, rAction);
	applyCheckEffect(rActor, rRoll, rAction);
	return rRoll;
end

function powersGetRoll(rActor, rAction)
	local rRoll = _fnOrigPowersGetRoll(rActor, rAction);
	applyCheckEffect(rActor, rRoll, rAction);
	return rRoll;
end

function attackGetRoll(rActor, rAction)
	local rRoll = _fnOrigAttackGetRoll(rActor, rAction);
	applyAttackEffect(rActor, rRoll, rAction);
	return rRoll;
end

-- Strips brackets/parens (CoreRPG's tag parser keeps them literally in the
-- remainder text) and case-folds, so "[Spot]", "(Spot)", "Spot", and "spot"
-- all normalize identically for matching.
function normalizeEffectText(s)
	return StringManager.simplify((s or ""):gsub("[%[%]%(%)]", ""));
end

-- No name tags on the effect line at all = applies to every check.
-- Otherwise at least one tag must match one of the check's own names.
function matchesCheckFilter(tRemainder, tNames)
	if not tRemainder or #tRemainder == 0 then
		return true;
	end
	for _, sTag in ipairs(tRemainder) do
		local sNorm = normalizeEffectText(sTag);
		for _, sName in ipairs(tNames) do
			if sNorm == sName then
				return true;
			end
		end
	end
	return false;
end

function applyCheckEffect(rActor, rRoll, rAction)
	if not rRoll.nTarget then
		return;
	end

	local tNames = {};
	if (rAction.label or "") ~= "" then
		table.insert(tNames, normalizeEffectText(rAction.label));
	end
	if (rAction.stat or "") ~= "" then
		table.insert(tNames, normalizeEffectText(rAction.stat));
	end

	local nBonus = 0;
	for _, tCompData in ipairs(EffectManager.getCompsDataByTag(rActor, "CHECK")) do
		if matchesCheckFilter(tCompData.remainder, tNames) then
			nBonus = nBonus + (tCompData.mod or 0);
		end
	end

	if nBonus ~= 0 then
		rRoll.nTarget = rRoll.nTarget + nBonus;
		rRoll.sDesc = (rRoll.sDesc or "") .. string.format(" [CHECK %+d]", nBonus);
	end
end

-- Looks up a weapon by name in the actor's own .weaponlist and returns its
-- linked skill name (the "baseskill" field char_weapon.lua's updateAttack()
-- already reads to compute the weapon's static attack%). Empty string if
-- no weapon matches or the actor has no weapon list (e.g. an unusual actor
-- type) - callers treat that as "no fallback name available".
function findWeaponBaseSkill(rActor, sWeaponLabel)
	if (sWeaponLabel or "") == "" then
		return "";
	end
	local nodeActor = ActorManager.getCreatureNode(rActor);
	if not nodeActor then
		return "";
	end

	local sNormLabel = normalizeEffectText(sWeaponLabel);
	for _, nodeWeapon in ipairs(DB.getChildList(nodeActor, "weaponlist")) do
		if normalizeEffectText(DB.getValue(nodeWeapon, "name", "")) == sNormLabel then
			return DB.getValue(nodeWeapon, "baseskill", "");
		end
	end
	return "";
end

function applyAttackEffect(rActor, rRoll, rAction)
	if not rRoll.nBase then
		return;
	end

	local tNames = {};
	if (rAction.label or "") ~= "" then
		table.insert(tNames, normalizeEffectText(rAction.label));
	end
	local sBaseSkill = findWeaponBaseSkill(rActor, rAction.label);
	if (sBaseSkill or "") ~= "" then
		table.insert(tNames, normalizeEffectText(sBaseSkill));
	end

	local nBonus = 0;
	for _, tCompData in ipairs(EffectManager.getCompsDataByTag(rActor, "ATK")) do
		if matchesCheckFilter(tCompData.remainder, tNames) then
			nBonus = nBonus + (tCompData.mod or 0);
		end
	end

	if nBonus ~= 0 then
		rRoll.nBase = rRoll.nBase + nBonus;
		rRoll.sDesc = (rRoll.sDesc or "") .. string.format(" [ATK %+d]", nBonus);
	end
end
