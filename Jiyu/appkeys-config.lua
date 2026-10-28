-----------------------------------------------------------------------------------------------------------------------
--                                        Third-party applications keys sheet                                        --
-----------------------------------------------------------------------------------------------------------------------
-- This file provides table to build hotkeys helpers for third-party applications.
-- The key lists here are purely descriptive, have nothing to do with real application configs.


local L = require("Jiyu.locale").t

local appkeys = {}

appkeys["urxvt"] = {
	style = { column = 2, geometry = { width = 1200, height = 660 } },
	pack = {
		{
			{ "Control" }, "l", nil,
			{ description = L("Clear the screen"), group = L("Control")}
		},
		{
			{ "Control" }, "s", nil,
			{ description = L("Stops the output to the screen"), group = L("Control")}
		},
		{
			{ "Control" }, "q", nil,
			{ description = L("Allow output to the screen"), group = L("Control")}
		},
		{
			{ "Control" }, "c", nil,
			{ description = L("Terminate the command"), group = L("Control")}
		},
		{
			{ "Control" }, "z", nil,
			{ description = L("Suspend/stop the command"), group = L("Control")}
		},

		{
			{ "Control" }, "a", nil,
			{ description = L("Go to the start of the command line"), group = L("Editing")}
		},
		{
			{ "Control" }, "e", nil,
			{ description = L("Go to the end of the command line"), group = L("Editing")}
		},
		{
			{ "Control" }, "k", nil,
			{ description = L("Delete from cursor to the end of the command line"), group = L("Editing")}
		},
		{
			{ "Control" }, "u", nil,
			{ description = L("Delete from cursor to the start of the command line"), group = L("Editing")}
		},
		{
			{ "Control" }, "w", nil,
			{ description = L("Delete from cursor to start of word "), group = L("Editing")}
		},
		{
			{ "Control" }, "y", nil,
			{ description = L("Paste word or text"), group = L("Editing")}
		},
		{
			{ "Control" }, "xx", nil,
			{ description = L("Move between start of command line and cursor"), group = L("Editing")}
		},
		{
			{ "Alt" }, "b", nil,
			{ description = L("Move backward one word"), group = L("Editing")}
		},
		{
			{ "Alt" }, "f", nil,
			{ description = L("Move forward one word"), group = L("Editing")}
		},
		{
			{ "Alt" }, "d", nil,
			{ description = L("Delete to end of word starting at cursor"), group = L("Editing")}
		},
		{
			{ "Alt" }, "c", nil,
			{ description = L("Capitalize to end of word starting at cursor"), group = L("Editing")}
		},
		{
			{ "Alt" }, "u", nil,
			{ description = L("Make uppercase from cursor to end of word"), group = L("Editing")}
		},
		{
			{ "Alt" }, "l", nil,
			{ description = L("Make lowercase from cursor to end of word"), group = L("Editing")}
		},
		{
			{ "Alt" }, "t", nil,
			{ description = L("Swap current word with previous"), group = L("Editing")}
		},
		{
			{ "Control" }, "f", nil,
			{ description = L("Move forward one character"), group = L("Editing")}
		},
		{
			{ "Control" }, "b", nil,
			{ description = L("Move backward one character"), group = L("Editing")}
		},
		{
			{ "Control" }, "d", nil,
			{ description = L("Delete character under the cursor"), group = L("Editing")}
		},
		{
			{ "Control" }, "h", nil,
			{ description = L("Delete character before the cursor"), group = L("Editing")}
		},
		{
			{ "Control" }, "t", nil,
			{ description = L("Swap character under cursor with the previous one"), group = L("Editing")}
		},

		{
			{ "Control" }, "r", nil,
			{ description = L("Search the history backwards"), group = L("Recall")}
		},
		{
			{ "Control" }, "g", nil,
			{ description = L("Escape from history searching mode"), group = L("Recall")}
		},
		{
			{ "Control" }, "p", nil,
			{ description = L("Previous command in history"), group = L("Recall")}
		},
		{
			{ "Control" }, "n", nil,
			{ description = L("Next command in history"), group = L("Recall")}
		},
		{
			{ "Alt" }, ".", nil,
			{ description = L("Use the last word of the previous command"), group = L("Recall")}
		},

		{
			{}, "!!", nil,
			{ description = L("Run last command"), group = L("Bang")}
		},
		{
			{}, "!blah", nil,
			{ description = L("Run the most recent command that starts with 'blah'"), group = L("Bang")}
		},
		{
			{}, "!blah:p", nil,
			{ description = L("Print out the command that !blah would run"), group = L("Bang")}
		},
		{
			{}, "!$", nil,
			{ description = L("The last word of the previous command"), group = L("Bang")}
		},
		{
			{}, "!$:p", nil,
			{ description = L("Print out the word that !$ would substitute"), group = L("Bang")}
		},
		{
			{}, "!*", nil,
			{ description = L("The previous command except for the last word"), group = L("Bang")}
		},
		{
			{}, "!*:p", nil,
			{ description = L("Print out what !* would substitute"), group = L("Bang")}
		},
	}
}


appkeys["mpv"] = {
	style = { column = 3, geometry = { width = 1600, height = 720 } },
	pack = {
		{
			{}, "f", nil,
			{ description = L("Toggle fullscreen"), group = L("General")}
		},
		{
			{}, "s", nil,
			{ description = L("Take a screenshot"), group = L("General")}
		},
		{
			{ "Shift" }, "s", nil,
			{ description = L("Take a screenshot without subtitles"), group = L("General")}
		},
		{
			{}, "q", nil,
			{ description = L("Quit"), group = L("General")}
		},
		{
			{ "Shift" }, "q", nil,
			{ description = L("Quit saving current position"), group = L("General")}
		},
		{
			{}, "o", nil,
			{ description = L("Show progress"), group = L("General")}
		},
		{
			{ "Shift" }, "o", nil,
			{ description = L("Toggle show progress"), group = L("General")}
		},
		{
			{}, "F9", nil,
			{ description = L("Show the list of audio and subtitle"), group = L("General")}
		},
		{
			{"Shift"}, "a", nil,
			{ description = L("Cycle aspect ratio"), group = L("General")}
		},

		{
			{}, "F8", nil,
			{ description = L("Show the playlist"), group = L("Playlist")}
		},
		{
			{ "Shift" }, ",", nil,
			{ description = L("Forward in playlist"), group = L("Playlist")}
		},
		{
			{ "Shift" }, ".", nil,
			{ description = L("Backward in playlist"), group = L("Playlist")}
		},

		{
			{}, "Space", nil,
			{ description = L("Play/pause"), group = L("Playback")}
		},
		{
			{}, "[", nil,
			{ description = L("Decrease speed"), group = L("Playback")}
		},
		{
			{}, "]", nil,
			{ description = L("Increase speed"), group = L("Playback")}
		},
		{
			{}, "{", nil,
			{ description = L("Halve current speed"), group = L("Playback")}
		},
		{
			{}, "}", nil,
			{ description = L("Double current speed"), group = L("Playback")}
		},
		{
			{}, "l", nil,
			{ description = L("Set/clear A-B loop points"), group = L("Playback")}
		},
		{
			{ "Shift" }, "l", nil,
			{ description = L("Toggle infinite looping"), group = L("Playback")}
		},
		{
			{}, "Backspace", nil,
			{ description = L("Reset speed to normal"), group = L("Playback")}
		},

		{
			{}, "m", nil,
			{ description = L("Mute/unmute"), group = L("Audio")}
		},
		{
			{}, "9", nil,
			{ description = L("Decrease volume"), group = L("Audio")}
		},
		{
			{}, "0", nil,
			{ description = L("Increase volume"), group = L("Audio")}
		},
		{
			{ "Control" }, "-", nil,
			{ description = L("Decrease audio delay"), group = L("Audio")}
		},
		{
			{ "Control" }, "+", nil,
			{ description = L("Increase audio delay"), group = L("Audio")}
		},
		{
			{}, "#", nil,
			{ description = L("Cycle through audio tracks"), group = L("Audio")}
		},

		{
			{}, "PageUp", nil,
			{ description = L("Next chapter"), group = L("Navigation")}
		},
		{
			{}, "PageDn", nil,
			{ description = L("Previous chapter"), group = L("Navigation")}
		},
		{
			{}, ",", nil,
			{ description = L("Previous frame"), group = L("Navigation")}
		},
		{
			{}, ".", nil,
			{ description = L("Next frame"), group = L("Navigation")}
		},
		{
			{}, "Right", nil,
			{ description = L("Forward 5 seconds"), group = L("Navigation")}
		},
		{
			{}, "Left", nil,
			{ description = L("Backward 5 seconds"), group = L("Navigation")}
		},
		{
			{}, "Up", nil,
			{ description = L("Forward 60 seconds"), group = L("Navigation")}
		},
		{
			{}, "Down", nil,
			{ description = L("Backward 60 seconds"), group = L("Navigation")}
		},
		{
			{ "Control" }, "Left", nil,
			{ description = L("Seek to the previous subtitle"), group = L("Navigation")}
		},
		{
			{ "Control" }, "Right", nil,
			{ description = L("Seek to the next subtitle"), group = L("Navigation")}
		},
		{
			{ "Shift" }, "Backspace", nil,
			{ description = L("Undo  the  last  seek"), group = L("Navigation")}
		},
		{
			{ "Control", "Shift" }, "Backspace", nil,
			{ description = L("Mark the current position"), group = L("Navigation")}
		},

		{
			{}, "v", nil,
			{ description = L("Show/hide subtitles"), group = L("Subtitles")}
		},
		{
			{}, "j", nil,
			{ description = L("Next subtitle"), group = L("Subtitles")}
		},
		{
			{ "Shift" }, "j", nil,
			{ description = L("Previous subtitle"), group = L("Subtitles")}
		},
		{
			{}, "z", nil,
			{ description = L("Increase subtitle delay"), group = L("Subtitles")}
		},
		{
			{}, "x", nil,
			{ description = L("Decrease subtitle delay"), group = L("Subtitles")}
		},
		{
			{}, "r", nil,
			{ description = L("Move subtitles up"), group = L("Subtitles")}
		},
		{
			{}, "t", nil,
			{ description = L("Move subtitles down"), group = L("Subtitles")}
		},
		{
			{}, "u", nil,
			{ description = L("Style overrides on/off"), group = L("Subtitles")}
		},


		{
			{}, "1", nil,
			{ description = L("Decrease contrast"), group = L("Video")}
		},
		{
			{}, "2", nil,
			{ description = L("Increase contrast"), group = L("Video")}
		},
		{
			{}, "3", nil,
			{ description = L("Decrease brightness"), group = L("Video")}
		},
		{
			{}, "4", nil,
			{ description = L("Increase brightness"), group = L("Video")}
		},
		{
			{}, "5", nil,
			{ description = L("Decrease gamma"), group = L("Video")}
		},
		{
			{}, "6", nil,
			{ description = L("Increase gamma"), group = L("Video")}
		},
		{
			{}, "7", nil,
			{ description = L("Decrease saturation"), group = L("Video")}
		},
		{
			{}, "8", nil,
			{ description = L("Increase saturation"), group = L("Video")}
		},

		{
			{}, "w", nil,
			{ description = L("Decrease pan-and-scan range"), group = L("Zoom")}
		},
		{
			{}, "e", nil,
			{ description = L("Increase pan-and-scan range"), group = L("Zoom")}
		},
		{
			{ "Alt" }, "-", nil,
			{ description = L("Decrease zoom"), group = L("Zoom")}
		},
		{
			{ "Alt" }, "+", nil,
			{ description = L("Increase zoom"), group = L("Zoom")}
		},
		{
			{ "Alt" }, "Backspace", nil,
			{ description = L("Reset zoom"), group = L("Zoom")}
		},
		{
			{ "Alt" }, "Arrow", nil,
			{ description = L("Move the video rectangle"), group = L("Zoom")}
		},
	}
}


return appkeys