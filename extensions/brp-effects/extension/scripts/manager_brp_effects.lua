--
-- BRP Effects
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
--	DMG: <dice/mod>[, <weapon name>]
--		Bonus dice and/or flat mod to matching Damage rolls (e.g.
--		"DMG: 1d4, Sword" or "DMG: 2"). Matches against the weapon's own
--		name only - unlike ATK, damage isn't derived from a skill total,
--		so there's no equivalent fallback to make.
--	INIT: <mod>
--		Flat bonus/penalty to Initiative. No name filter - initiative
--		isn't rolled "for" anything the way a skill/weapon roll is, so
--		there's nothing meaningful to filter by; every active INIT effect
--		on the actor just adds to the total.
--	ARMOR: <mod>
--		Flat damage reduction, floored at 0, applied to incoming damage
--		on whichever actor carries this effect (unlike the other four
--		keywords, this reads the TARGET's effect list, not the source's).
--		No name filter - BRP has no damage-type/resistance concept to
--		filter by (confirmed via direct source read), so this is a flat
--		"armor value" applied to everything. Stacks with, and applies
--		before, the optional Hit Locations rule's own per-location AP
--		subtraction.
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
-- ActionDamage.getRoll (manager_action_damage.lua) is a genuinely different
-- shape from the four above: no percentage/target number and no
-- ModifierStack.getStack() call anywhere in that file, just a flat dice
-- pool (rRoll.aDice) and flat mod (rRoll.nMod) built by summing
-- rAction.clauses. DMG adds directly to that dice pool/mod, the same way
-- CHECK/ATK's own dice-bonus path already works. Both PC and NPC damage-
-- roll scripts set rAction.label to the weapon's name (used here as the
-- filter), even though manager_action_damage.lua itself never reads that
-- field for anything.
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
-- CombatManager2.getEntryInitRecord (manager_combat2.lua) builds
-- tInit.nMod from DEX and hands off tInit.fnRollRandom (BRP's own
-- rollRandomInit: math.random(10) + tInit.nMod) to CoreRPG's generic
-- initiative pipeline (rollStandardEntryInit -> helperRollEntryInit ->
-- helperRollRandomInit), which writes the result straight to "initresult".
-- This never touches the FGU dice-roll pipeline at all (no rRoll.aDice,
-- no ActionsManager) - just a synchronous Lua computation - so INIT is a
-- flat rRoll.nMod-style addition with no dice concept. INIT also skips the
-- hand-rolled matching used above entirely: there's no per-roll name to
-- filter by, so the plain EffectManager.getBonusMod(rActor, "INIT") (no
-- tFilter) is safe here - the case-sensitivity bug above only bites once a
-- tFilter is involved.
--
-- ActionDamage.applyDamage (manager_action_damage.lua, called from
-- handleApplyDamage, its only call site) is where nTotal actually gets
-- subtracted from "wounds" - the first choke point in this whole extension
-- that runs on the TARGET's effects, not the source's. Wrapped the same
-- way as everything above: compute the reduction and adjust nTotal before
-- calling through to the original, so every downstream calculation inside
-- it (wounds, the optional Hit Locations AP subtraction, the displayed
-- total in the confirmation chat message) automatically reflects the
-- post-armor number with no further changes needed.
--

local _fnOrigSkillGetRoll, _fnOrigAbilityGetRoll, _fnOrigPowersGetRoll, _fnOrigAttackGetRoll, _fnOrigDamageGetRoll, _fnOrigGetEntryInitRecord, _fnOrigApplyDamage;

function onInit()
	_fnOrigSkillGetRoll = ActionSkill.getRoll;
	ActionSkill.getRoll = skillGetRoll;

	_fnOrigAbilityGetRoll = ActionAbility.getRoll;
	ActionAbility.getRoll = abilityGetRoll;

	_fnOrigPowersGetRoll = ActionPowers.getRoll;
	ActionPowers.getRoll = powersGetRoll;

	_fnOrigAttackGetRoll = ActionAttack.getRoll;
	ActionAttack.getRoll = attackGetRoll;

	_fnOrigDamageGetRoll = ActionDamage.getRoll;
	ActionDamage.getRoll = damageGetRoll;

	_fnOrigGetEntryInitRecord = CombatManager2.getEntryInitRecord;
	CombatManager2.getEntryInitRecord = getEntryInitRecord;

	_fnOrigApplyDamage = ActionDamage.applyDamage;
	ActionDamage.applyDamage = applyDamage;
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

function damageGetRoll(rActor, rAction)
	local rRoll = _fnOrigDamageGetRoll(rActor, rAction);
	applyDamageEffect(rActor, rRoll, rAction);
	return rRoll;
end

function getEntryInitRecord(nodeEntry)
	local tInit = _fnOrigGetEntryInitRecord(nodeEntry);
	if tInit then
		applyInitEffect(nodeEntry, tInit);
	end
	return tInit;
end

function applyDamage(sSourceNode, sTargetNode, bSecret, sDamage, nTotal, sRange, sLocationNode)
	nTotal = applyArmorEffect(sTargetNode, nTotal);
	return _fnOrigApplyDamage(sSourceNode, sTargetNode, bSecret, sDamage, nTotal, sRange, sLocationNode);
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

-- Unlike CHECK/ATK, tracks whether anything matched (bMatched) rather than
-- just checking nBonus ~= 0, since a purely dice-based DMG effect (e.g.
-- "DMG: 1d4, Sword", no flat mod) would otherwise leave nBonus at 0 and
-- skip the description suffix even though dice were added.
function applyDamageEffect(rActor, rRoll, rAction)
	local tNames = {};
	if (rAction.label or "") ~= "" then
		table.insert(tNames, normalizeEffectText(rAction.label));
	end

	local nBonus = 0;
	local bMatched = false;
	for _, tCompData in ipairs(EffectManager.getCompsDataByTag(rActor, "DMG")) do
		if matchesCheckFilter(tCompData.remainder, tNames) then
			bMatched = true;
			for _, vDie in ipairs(tCompData.dice) do
				table.insert(rRoll.aDice, vDie);
			end
			nBonus = nBonus + (tCompData.mod or 0);
		end
	end

	if bMatched then
		rRoll.nMod = (rRoll.nMod or 0) + nBonus;
		rRoll.sDesc = (rRoll.sDesc or "") .. string.format(" [DMG %+d]", nBonus);
	end
end

-- No name filter: initiative isn't rolled for anything, so the plain
-- getBonusMod (no tFilter) is safe here.
function applyInitEffect(nodeEntry, tInit)
	local rActor = ActorManager.resolveActor(nodeEntry);
	if not rActor then
		return;
	end

	local nBonus = EffectManager.getBonusMod(rActor, "INIT");
	if nBonus ~= 0 then
		tInit.nMod = (tInit.nMod or 0) + nBonus;
	end
end

-- Reads the TARGET's own ARMOR effects (not the source's, unlike every
-- other keyword above) and subtracts the total from incoming damage,
-- floored at 0 the same way the existing Hit Locations AP subtraction
-- already floors its own reduction just below this.
function applyArmorEffect(sTargetNode, nTotal)
	local rTarget = ActorManager.resolveActor(sTargetNode);
	if not rTarget then
		return nTotal;
	end

	local nReduction = EffectManager.getBonusMod(rTarget, "ARMOR");
	if nReduction ~= 0 then
		nTotal = nTotal - nReduction;
		if nTotal < 0 then
			nTotal = 0;
		end
	end
	return nTotal;
end
