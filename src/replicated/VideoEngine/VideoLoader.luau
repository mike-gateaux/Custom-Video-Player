local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EncodingService = game:GetService("EncodingService")
local Players = game:GetService("Players")

local StreamVideoBuffers = ReplicatedStorage:WaitForChild("StreamVideoBuffers")
local LocalPlayer = Players.LocalPlayer

local VideoLoader = {}

function formatToMb(bytes: number)
	local decimalSpace = 2
	local mb = bytes / 1000 ^ 2
	local dSR = (10 ^ decimalSpace)

	return math.floor(mb * dSR) / dSR
end

function VideoLoader:loadVideo(
	videoId: string,
	streaming: { [number]: (number, number) -> boolean }?,
	trackUpdate: ((number, number) -> ())?
)
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
	local totalParts = #bufferFiles

	local frameBuffers = table.create(totalFrames)
	local pixelCount = width * height
	local paletteSize = maxColors * 4

	local function readBufferChunk(chunk: string)
		local compressedBuffer = buffer.fromstring(chunk)
		local masterBuffer = EncodingService:DecompressBuffer(compressedBuffer, Enum.CompressionAlgorithm.Zstd)
		local frameCount = buffer.len(masterBuffer) / frameByteSize
		local chunkBuffers = table.create(frameCount)

		for k = 1, frameCount do
			local frameStartOffset = (k - 1) * frameByteSize
			local colorsBuffer = buffer.create(pixelCount * 4)

			for p = 0, pixelCount - 1 do
				local indexByteOffset = frameStartOffset + paletteSize + p
				local colorIndex = buffer.readu8(masterBuffer, indexByteOffset)
				local paletteColorOffset = frameStartOffset + (colorIndex * 4)
				local r = buffer.readu8(masterBuffer, paletteColorOffset + 0)
				local g = buffer.readu8(masterBuffer, paletteColorOffset + 1)
				local b = buffer.readu8(masterBuffer, paletteColorOffset + 2)
				local a = buffer.readu8(masterBuffer, paletteColorOffset + 3)
				local rgbaOffset = p * 4

				buffer.writeu8(colorsBuffer, rgbaOffset + 0, r)
				buffer.writeu8(colorsBuffer, rgbaOffset + 1, g)
				buffer.writeu8(colorsBuffer, rgbaOffset + 2, b)
				buffer.writeu8(colorsBuffer, rgbaOffset + 3, a)
			end

			table.insert(chunkBuffers, colorsBuffer)
		end

		return chunkBuffers
	end

	local function applyChunks(min, max)
		local downloadedBytes = 0
		local loadedFramesCount = 0

		for key = min, max do
			local chunkFile = bufferFiles[key]
			local sliceIndex = 1
			local chunkString = ""

			while true do
				local sliceData = StreamVideoBuffers:InvokeServer("getVideoBuffer", videoId, chunkFile, sliceIndex)

				if not sliceData or #sliceData == 0 then
					break
				end

				downloadedBytes += buffer.len(buffer.fromstring(sliceData))
				chunkString ..= sliceData
				sliceIndex += 1

				if trackUpdate then
					trackUpdate(formatToMb(downloadedBytes), formatToMb(totalBytes))
				end

				task.wait()
			end

			local decodedChunk = readBufferChunk(chunkString)

			for key2, frameBuffer in ipairs(decodedChunk) do
				loadedFramesCount += 1
				frameBuffers[loadedFramesCount] = frameBuffer
			end
		end
	end

	if streaming then
		local ping = LocalPlayer:GetNetworkPing() * 1000
		local chunkCount = 1

		for totalChunks, condition in streaming do
			if condition(ping, totalChunks) then
				chunkCount = math.min(chunkCount, totalParts)
			end
		end

		applyChunks(1, chunkCount)
		task.spawn(applyChunks, chunkCount + 1, totalParts)
	else
		local bufferHash = ""
		local downloadedBytes = 0

		for key, bufferChunk in ipairs(bufferFiles) do
			local sliceIndex = 1

			while true do
				local sliceData = StreamVideoBuffers:InvokeServer("getVideoBuffer", videoId, bufferChunk, sliceIndex)

				if not sliceData or #sliceData == 0 then
					break
				end

				downloadedBytes += buffer.len(buffer.fromstring(sliceData))
				bufferHash ..= sliceData
				sliceIndex += 1

				if trackUpdate then
					trackUpdate(formatToMb(downloadedBytes), formatToMb(totalBytes))
				end

				task.wait()
			end
		end

		frameBuffers = readBufferChunk(bufferHash)
	end

	return metadata, frameBuffers
end

return VideoLoader
