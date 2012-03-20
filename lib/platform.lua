
-- platform generalization
platform = {}

function platform.clean_path(p)
	return p:gsub('\\','/')
end


local windowsos = os.getenv("OS")

if windowsos and windowsos:match("[Ww]indows") then

	platform.type="windows";

	function platform.normalize_path(p)
		return p:gsub('/','\\')
	end

	function platform.mkdir(p)
		if not lk.exist(p) then
			os.execute("mkdir " .. platform.normalize_path(p) )
		end
	end
else
	platform.type="posix";

	function platform.normalize_path(p)
		return p:gsub('\\','/')
	end

	function platform.mkdir(p)
		if not lk.exist(p) then
			os.execute("mkdir -p "..p)
		end
	end


end

function platform.is_absolute(p)

	if platform.type=="windows" then
		return (p:match('^[/\\]')) or (p:match("^[A-Za-z]:"))
	else
		return string.match(p, '^/')
	end

end



return platform
