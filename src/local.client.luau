local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")

local VideoEngine = require(ReplicatedStorage.ReplicatedCodebase.VideoEngine)

local ping = game:GetService("Players").LocalPlayer:GetNetworkPing() * 1000
local selectedVideoOption = ping < 50 and "high" or ping < 100 and "medium" or "low"
local video = ("WC22_Intro.%s"):format(selectedVideoOption)

local VideoRenderer = Players.LocalPlayer.PlayerGui:WaitForChild("VideoRenderer")

StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, false)
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)

VideoRenderer.Background.Visible = true

task.wait(2.5)

VideoRenderer.Status.Visible = true

TweenService:Create(
	VideoRenderer.Status.Icon,
	TweenInfo.new(0.4 * 10, Enum.EasingStyle.Sine, Enum.EasingDirection.In, -1, true),
	{ ImageTransparency = 1 }
):Play()

function format(loaded, max)
	VideoRenderer.Status.Loaded.Text = ("Downloading %s%s%* MB • %* MB"):format(video, (" "):rep(5), loaded, max)
end

VideoEngine:render({
	postFunction = function()
		task.wait(1)

		VideoRenderer.Status.Visible = false

		task.wait(1.5)
	end,
	renderedImage = VideoRenderer.Splash,
	player = { VideoEngine.loader:loadVideo(video, format) },
	audio = script.Parent.WC22_Intro,
})
