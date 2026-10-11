local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EncodingService = game:GetService("EncodingService")

local StreamVideoBuffers = ReplicatedStorage:WaitForChild("StreamVideoBuffers")

local VideoLoader = {}

function formatToMb(bytes: number)
	local decimalSpace = 2
	local mb = bytes / 1000 ^ 2
	local dSR = (10 ^ decimalSpace)

	return math.floor(mb * dSR) / dSR
end

function VideoLoader:loadVideo(videoId: string, trackUpdate)
	local metadata = StreamVideoBuffers:InvokeServer("getVideoMetadata", videoId)

	if not metadata then
		error(("failed to fetch %s"):format(videoId))
	end

	local totalFrames = metadata.totalFrames
	local frameByteSize = metadata.frameByteSize
	local bufferFiles = metadata.parts
	local width = metadata.width
	local height = metadata.height
	local totalBytes = metadata.totalSize
	local maxColors = metadata.colors or 256

	local compressedBufferString = ""
	local downloadedBytes = 0

	for _, chunkFile in ipairs(bufferFiles) do
		local sliceIndex = 1

		while true do
			local sliceData = StreamVideoBuffers:InvokeServer("getVideoBuffer", videoId, chunkFile, sliceIndex)

			if not sliceData or #sliceData == 0 then
				break
			end

			downloadedBytes += buffer.len(buffer.fromstring(sliceData))
			compressedBufferString ..= sliceData
			sliceIndex += 1

			if trackUpdate then
				trackUpdate(formatToMb(downloadedBytes), formatToMb(totalBytes))
			end

			task.wait()
		end
	end

	local compressedBuffer = buffer.fromstring(compressedBufferString)
	local masterBuffer = EncodingService:DecompressBuffer(compressedBuffer, Enum.CompressionAlgorithm.Zstd)
	local frameBuffers = table.create(totalFrames)

	local pixelCount = width * height
	local paletteSize = maxColors * 4

	for k = 1, totalFrames do
		local frameStartOffset = (k - 1) * frameByteSize
		local rgbaBuf = buffer.create(pixelCount * 4)

		for p = 0, pixelCount - 1 do
			local indexByteOffset = frameStartOffset + paletteSize + p
			local colorIndex = buffer.readu8(masterBuffer, indexByteOffset)
			local paletteColorOffset = frameStartOffset + (colorIndex * 4)
			local r = buffer.readu8(masterBuffer, paletteColorOffset + 0)
			local g = buffer.readu8(masterBuffer, paletteColorOffset + 1)
			local b = buffer.readu8(masterBuffer, paletteColorOffset + 2)
			local a = buffer.readu8(masterBuffer, paletteColorOffset + 3)
			local rgbaOffset = p * 4

			buffer.writeu8(rgbaBuf, rgbaOffset + 0, r)
			buffer.writeu8(rgbaBuf, rgbaOffset + 1, g)
			buffer.writeu8(rgbaBuf, rgbaOffset + 2, b)
			buffer.writeu8(rgbaBuf, rgbaOffset + 3, a)
		end

		frameBuffers[k] = rgbaBuf

		task.wait()
	end

	return metadata, frameBuffers
end

return VideoLoader
