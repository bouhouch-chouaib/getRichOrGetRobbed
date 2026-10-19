--!strict
-- Règles du premier œuf : une attribution et une prime par profil, délais UTC non renouvelables.
local Config = require(script.Parent.Config)
local Eggs = require(script.Parent.EggIncubation)
local StarterJourney = {}

export type State = {
	eligible: boolean,
	eggId: string?,
	bonusPaid: boolean,
	protectionUntil: number,
	protectionWaived: boolean,
}

function StarterJourney.Restore(raw: unknown, isNew: boolean): State
	local state: State =
		{ eligible = isNew, eggId = nil, bonusPaid = false, protectionUntil = 0, protectionWaived = false }
	if type(raw) ~= "table" then
		return state
	end
	local saved = raw :: { [string]: any }
	state.eligible = saved.eligible == true
	state.eggId = if type(saved.eggId) == "string" and #saved.eggId <= 100 then saved.eggId else nil
	state.bonusPaid = saved.bonusPaid == true
	state.protectionWaived = saved.protectionWaived == true
	local deadline = saved.protectionUntil
	if type(deadline) == "number" and deadline == deadline and deadline < math.huge then
		state.protectionUntil = math.max(0, math.floor(deadline))
	end
	return state
end

function StarterJourney.Grant(state: State, time: number, id: string): Eggs.Egg?
	if not state.eligible or state.eggId then
		return nil
	end
	local egg = Eggs.Create(Config.Newcomer.PetId, 1, time, id)
	if not egg then
		return nil
	end
	state.eggId = id
	state.protectionUntil = if state.protectionWaived then 0 else time + Config.Newcomer.ProtectionSeconds
	return egg
end

function StarterJourney.Hatched(state: State, eggId: string): number
	if not state.eligible or state.eggId ~= eggId or state.bonusPaid then
		return 0
	end
	state.bonusPaid = true
	return Config.Newcomer.BonusMoney
end

function StarterJourney.IsProtected(state: State, time: number): boolean
	return state.eligible and not state.protectionWaived and state.eggId ~= nil and state.protectionUntil > time
end

function StarterJourney.EndProtection(state: State)
	state.protectionWaived = true
	state.protectionUntil = 0
end

return StarterJourney
