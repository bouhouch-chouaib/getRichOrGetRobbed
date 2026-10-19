--!strict
local Config = require(script.Parent.Config)
local BaseExpansion = {}
export type State = { floors: number, credits: number }
local function integer(raw: any, maximum: number): number
	return if type(raw) == "number" and raw == raw then math.clamp(math.floor(raw), 0, maximum) else 0
end
function BaseExpansion.Restore(raw: unknown): State
	if type(raw) ~= "table" then
		return { floors = 0, credits = 0 }
	end
	local saved = raw :: { [string]: any }
	return { floors = integer(saved.floors, #Config.Worlds), credits = integer(saved.credits, 1000000) }
end
function BaseExpansion.Limit(tier: number): number
	return math.clamp(math.floor(tier), 1, #Config.Worlds)
end
function BaseExpansion.Price(floors: number): number?
	return Config.BaseFloors.Prices[floors + 1]
end
function BaseExpansion.Redeem(state: State, tier: number): number
	local added = math.min(state.credits, math.max(0, BaseExpansion.Limit(tier) - state.floors))
	state.credits -= added
	state.floors += added
	return added
end
function BaseExpansion.Buy(state: State, tier: number, money: number): number?
	if state.floors >= BaseExpansion.Limit(tier) then
		return nil
	end
	if state.credits > 0 then
		BaseExpansion.Redeem(state, tier)
		return money
	end
	local price = BaseExpansion.Price(state.floors)
	if not price or money < price then
		return nil
	end
	state.floors += 1
	return money - price
end
function BaseExpansion.Capacity(rebirths: number, floors: number): number
	return Config.GetIncomeSlots(rebirths) + floors * Config.BaseFloors.SlotsPerFloor
end
return BaseExpansion
