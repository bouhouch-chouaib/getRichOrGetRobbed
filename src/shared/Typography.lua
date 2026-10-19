--!strict
-- Police commune à tous les textes du jeu, menus et panneaux dans le monde.
-- Montserrat Black est l'équivalent actuel du style Gotham Black de la référence.
local Typography = {}

Typography.Face = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy, Enum.FontStyle.Normal)

function Typography.StrokeSize(textSize: number): number
	-- Un contour plus fin pour les explications évite de boucher les petites lettres.
	return math.clamp(textSize / 12, 1, 3)
end

function Typography.Fit(label: TextLabel | TextButton, maximum: number, minimum: number?)
	if label:IsA("TextLabel") then
		label.FontFace = Typography.Face
	else
		label.FontFace = Typography.Face
	end
	-- Les paragraphes automatiques doivent grandir, pas rétrécir dans une hauteur nulle.
	if label.AutomaticSize ~= Enum.AutomaticSize.None then
		return
	end
	local found = label:FindFirstChildOfClass("UITextSizeConstraint")
	local limit = found or Instance.new("UITextSizeConstraint")
	limit.Parent = label
	limit.MaxTextSize = maximum
	limit.MinTextSize = math.min(minimum or 12, maximum)
	if label:IsA("TextLabel") then
		label.TextScaled = true
	else
		label.TextScaled = true
	end
end

return Typography
