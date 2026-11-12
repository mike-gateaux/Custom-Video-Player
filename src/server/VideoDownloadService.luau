local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StreamVideoBuffers = ReplicatedStorage:WaitForChild("StreamVideoBuffers")

local serverCache = {}
local repoInfo = {
	me = "mike-gateaux",
	repo = "streamed-videos",
	defaultFileSize = 1024 ^ 2,
}

StreamVideoBuffers.OnServerInvoke = function(_, action, videoId, filename, sliceIndex)
	local baseUrl = ("https://%s.github.io/%s/videos/%s/"):format(repoInfo.me, repoInfo.repo, videoId)

	if action == "getVideoMetadata" then
		if serverCache[videoId] and serverCache[videoId].metadata then
			return serverCache[videoId].metadata
		end

		local success, response = pcall(function()
			return HttpService:GetAsync(baseUrl .. "metadata.json")
		end)

		if not success then
			print(response)
			return
		end

		if not serverCache[videoId] then
			serverCache[videoId] = {}
		end

		local metadata = HttpService:JSONDecode(response)
		serverCache[videoId].metadata = metadata

		return metadata
	elseif action == "getVideoBuffer" then
		if not serverCache[videoId] then
			serverCache[videoId] = {}
		end

		if not serverCache[videoId].parts then
			serverCache[videoId].parts = {}
		end

		if not serverCache[videoId].parts[filename] then
			local success, response = pcall(function()
				return HttpService:GetAsync(baseUrl .. filename)
			end)

			if not success then
				return
			end

			serverCache[videoId].parts[filename] = response
		end

		local fullData = serverCache[videoId].parts[filename]
		local totalLen = #fullData
		local startByte = (sliceIndex - 1) * repoInfo.defaultFileSize + 1
		local endByte = math.min(startByte + repoInfo.defaultFileSize - 1, totalLen)

		return startByte <= totalLen and string.sub(fullData, startByte, endByte) or nil
	end

	return
end

return {}
