local options = {
    fallback = "",
    temp_file = "",
    extract_embedded_art = true
}

mp.options = require "mp.options"
mp.options.read_options(options)

local utils = require 'mp.utils'
local last_dir = ""
local legacy = mp.command_native_async == nil

if options.fallback == "" then
    options.fallback = mp.get_property("background", "#000000")
end

if options.temp_file == "" then
    options.temp_file = utils.join_path((package.config:sub(1,1) ~= "/") and os.getenv("TEMP") or "/tmp/", "mpv_audio_background.jpg")
end

function dominant_color(file)
    local args = {
        "convert", file,
        "-format", "%c",
        "-scale", "50x50!",
        "-sharpen", "5x5",
        "-colors", "5",
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
    else
        mp.set_property("background", options.fallback)
    end
end

mp.observe_property("vid", "number", function(_, vid)
    if vid == nil then return end
    if not is_audio_file() then return end
    local path = mp.get_property("stream-open-filename", "")
    local dir, filename = utils.split_path(path)
    if dir ~= last_dir then
        last_dir = dir
        coverart = mp.get_property("track-list/" .. tostring(vid) .. "/external-filename", "")
        if coverart ~= "" then
            dominant_color(coverart)
        elseif path ~= "" and options.extract_embedded_art then
            local ffmpeg = {
                "ffmpeg", "-y",
                "-loglevel", "8",
                "-i", path,
                "-vframes", "1",
                options.temp_file
            }
            if not legacy then
                mp.command_native({name = "subprocess", capture_stdout = false, playback_only = false, args = ffmpeg})
            else
                utils.subprocess({args = ffmpeg})
            end
            dominant_color(options.temp_file)
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
