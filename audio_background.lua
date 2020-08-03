local options = {
    fallback = ""
}

mp.options = require "mp.options"
mp.options.read_options(options)

if options.fallback == "" then
    options.fallback = mp.get_property("background", "#000000")
end

local utils = require 'mp.utils'
local last_dir = ""
local legacy = mp.command_native_async == nil

mp.observe_property("vid", "number", function(_, vid)
    if vid == nil then return end
    if not is_audio_file() then return end
    local dir, filename = utils.split_path(mp.get_property("stream-open-filename", ""))
    if dir ~= last_dir then
        last_dir = dir
        coverart = mp.get_property("track-list/" .. tostring(vid) .. "/external-filename", "")
        if coverart ~= "" then
            local args = {
                "convert",
                coverart,
                "-format",
                "%c",
                "-colors",
                "5",
                "histogram:info:-"
            }
            if not legacy then
                colors = mp.command_native({name = "subprocess", capture_stdout = true, playback_only = false, args = args})
            else
                colors = utils.subprocess({args = args})
            end
            local best = {score=0}
            for score, color in string.gmatch(colors.stdout, "(%d+):.-(#......)") do
                score_n = tonumber(score)
                if score_n > best.score then
                    best = {score=score_n, color=color}
                end
            end
            if best.score > 0 then
                mp.set_property("background", best.color)
            end
        else
            mp.set_property("background", options.fallback)
        end
    end
end)

-- https://github.com/CogentRedTester/mpv-coverart/blob/master/coverart.lua
function is_audio_file()
    if mp.get_property("track-list/0/type") == "audio" then
        return true
    elseif mp.get_property("track-list/0/albumart") == "yes" then
        return true
    end
    return false
end
