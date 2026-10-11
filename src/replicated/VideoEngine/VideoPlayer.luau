local AssetService = game:GetService("AssetService")
local RunService = game:GetService("RunService")

local VideoPlayer = {}
local VideoFunctions = {}

VideoFunctions.__index = VideoFunctions

type videoProperties = {
	imageLabel: ImageLabel,
	metadata: any,
	frameBuffers: { buffer },
	resolution: Vector2,
	totalFrames: number,
	fps: number,
	duration: number,
	editableImage: EditableImage,
	isPlaying: boolean,
	currentTime: number,
	connection: RBXScriptConnection?,
}

type videoMethods = {
	play: (self: videoInstance, audioInstance: Sound?, loop: boolean, removeCache: boolean) -> (),
	stop: (self: videoInstance) -> (),
	destroy: (self: videoInstance) -> (),
}

type videoInstance = videoProperties & videoMethods

type self = {
	editableImage: EditableImage,
}

function VideoPlayer:create(imageLabel: ImageLabel, metadata: { [string]: any }, frameBuffers: { buffer })
	local newPlayer = setmetatable({}, VideoFunctions)

	newPlayer.imageLabel = imageLabel
	newPlayer.metadata = metadata
	newPlayer.frameBuffers = frameBuffers
	newPlayer.resolution = Vector2.new(metadata.width, metadata.height)
	newPlayer.totalFrames = metadata.totalFrames
	newPlayer.fps = metadata.fps
	newPlayer.duration = metadata.duration
	newPlayer.editableImage = AssetService:CreateEditableImage({ Size = newPlayer.resolution })
	newPlayer.imageLabel.ImageContent = Content.fromObject(newPlayer.editableImage)
	newPlayer.isPlaying = false
	newPlayer.currentTime = 0
	newPlayer.connection = nil

	return newPlayer
end

function VideoFunctions.play(self: videoInstance, audioInstance: Sound?, loop: boolean, removeCache: boolean)
	if self.isPlaying then
		return
	end

	self.isPlaying = true
	self.currentTime = 0

	if audioInstance then
		audioInstance:Play()
	end

	local frameInterval = 1 / self.fps
	local accumulatedTime = 0

	self.connection = RunService.RenderStepped:Connect(function(deltaTime)
		if not self.isPlaying then
			return
		end

		accumulatedTime += deltaTime

		if accumulatedTime >= frameInterval then
			accumulatedTime -= frameInterval
			self.currentTime += frameInterval

			local frameIndex = math.clamp(math.floor(self.currentTime * self.fps) + 1, 1, self.totalFrames)
			local frameBuffer = self.frameBuffers[frameIndex]

			if frameBuffer then
				self.editableImage:WritePixelsBuffer(Vector2.zero, self.resolution, frameBuffer)
			end

			if self.currentTime >= self.duration then
				self:stop()

				if loop then
					self:play(audioInstance, loop, removeCache)
				elseif removeCache then
					self:destroy()
				end
			end
		end
	end)
end

function VideoFunctions:stop()
	self.isPlaying = false

	if self.connection then
		self.connection:Disconnect()
		self.connection = nil
	end
end

function VideoFunctions:destroy()
	self:stop()

	if self.editableImage then
		self.editableImage:Destroy()
	end

	table.clear(self.frameBuffers)
end

return VideoPlayer
