--!strict
-- Stub so Rojo syncs. Replace with loleris/ProfileStore before shipping.
local ProfileStore = {}
function ProfileStore.SetConstant(_name: string, _value: number) end
function ProfileStore.GetProfileStore(_name: string, template: any)
	local store = {}
	function store:StartSessionAsync(_key: string, _opts: any)
		local profile = {
			Data = table.clone(template),
			OnSessionEnd = Instance.new("BindableEvent").Event,
		}
		function profile:Reconcile() end
		function profile:EndSession() end
		function profile:Save() end
		function profile:IsActive()
			return true
		end
		return profile
	end
	return store
end
return ProfileStore
