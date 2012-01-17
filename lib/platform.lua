
-- platform generalization
platform = {}

function platform.clean_path(p)
	return p:gsub('\\','/')
end

local shell = os.getenv("SHELL")
if shell and (shell:match("/bin/bash") or shell:match("/bin/sh")) then

	platform.type="posix";

	function platform.normalize_path(p)
		return p:gsub('\\','/')
	end

	function platform.mkdir(p)
		if not lk.exist(p) then
			os.execute("mkdir -p "..tmp_path)
		end
	end

else
	platform.type="windows";

	function platform.normalize_path(p)
		return p:gsub('/','\\')
	end

	function platform.mkdir(p)
		if not lk.exist(p) then
			os.execute("mkdir " .. platform.normalize_path(p) )
		end
	end

end


return platform
