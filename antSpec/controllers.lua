local json = require("antSpec.json")
local utils = require("antSpec.utils")

local controllers = {}

function controllers.setController(controller)
	utils.validateArweaveId(controller)

	for _, c in ipairs(Controllers) do
		assert(c ~= controller, "Controller already exists")
	end

	table.insert(Controllers, controller)
	return json.encode(Controllers)
end

function controllers.removeController(controller)
	utils.validateArweaveId(controller)
	local controllerExists = false

	for i, v in ipairs(Controllers) do
		if v == controller then
			table.remove(Controllers, i)
			controllerExists = true
			break
		end
	end

	assert(controllerExists ~= nil, "Controller does not exist")
	return json.encode(Controllers)
end

function controllers.getControllers()
	return json.encode(Controllers)
end

return controllers
