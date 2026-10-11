local cachedPlayers = {}

local VideoEngine = {
	loader = require(script.VideoLoader),
	player = require(script.VideoPlayer),
}

type renderInfo = {
	player: (() -> (), ImageLabel, string?, Sound?, () -> ()?) -> (),
	renderedImage: ImageLabel,
	video: string?,
	spawn: boolean?,
	preFunction: () -> ()?,
	postFunction: () -> ()?,
	audio: Sound?,
}

function renderFunction(loadedPlayer, renderedImage, video, audio, postFunction)
	local metadata
	local frameBuffers

	local cachedPlayer = loadedPlayer or cachedPlayers[video]

	if cachedPlayer then
		metadata = cachedPlayer[1]
		frameBuffers = cachedPlayer[2]
	else
		metadata, frameBuffers = VideoEngine.loader:loadVideo(video)
		cachedPlayers[video] = { metadata, frameBuffers }
	end

	local player = VideoEngine.player:create(renderedImage, metadata, frameBuffers)

	task.wait()

	if postFunction then
		postFunction()
	end

	player:play(audio)
end

function VideoEngine:render(renderInfo: renderInfo)
	if renderInfo.preFunction then
		task.spawn(renderInfo.preFunction)
	end

	if renderInfo.spawn then
		task.spawn(
			renderInfo.player,
			renderFunction,
			renderInfo.renderedImage,
			renderInfo.video,
			renderInfo.audio,
			renderInfo.postFunction
		)

		return
	end

	renderFunction(
		renderInfo.player,
		renderInfo.renderedImage,
		renderInfo.video,
		renderInfo.audio,
		renderInfo.postFunction
	)
end

return VideoEngine
