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

local _fnOrigSkillGetRoll, _fnOrigAbilityGetRoll, _fnOrigPowersGetRoll;

function onInit()
	_fnOrigSkillGetRoll = ActionSkill.getRoll;
	ActionSkill.getRoll = skillGetRoll;

	_fnOrigAbilityGetRoll = ActionAbility.getRoll;
	ActionAbility.getRoll = abilityGetRoll;

	_fnOrigPowersGetRoll = ActionPowers.getRoll;
	ActionPowers.getRoll = powersGetRoll;
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
