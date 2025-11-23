const std = @import("std");

const main = @import("main");
const utils = main.utils;

const c = @cImport({
	@cInclude("miniaudio.h");
	@cDefine("STB_VORBIS_HEADER_ONLY", "");
	@cInclude("stb/stb_vorbis.h");
});

const handleError = @import("audio.zig").handleError;

var playbackData:main.utils.CircularBufferQueue(f32) = undefined;
const channels = 1;

fn record(_:?*anyopaque,_:?*anyopaque,input:?*const anyopaque,frameCount:u32)callconv(.c) void{
	if(main.game.world)|world|{
		// for (0..frameCount) |i| {
		// playbackData.pushBack(@as([*]const f32, @ptrCast(@alignCast(input)))[i]);
		// }
		//std.debug.print("here {d}\n", .{frameCount*channels});
		main.network.protocols.proximityChat.send(world.conn, @as([*]const u8, @ptrCast(@alignCast(input)))[0..frameCount*channels*@sizeOf(f32)]);
	}

}
var lastValue  :f32 =  0;
fn play(
	maDevice: ?*anyopaque,
	output: ?*anyopaque,
	input: ?*const anyopaque,
	frameCount: u32,
) callconv(.c) void {
	_ = input;
	_ = maDevice;
	const valuesPerBuffer = frameCount*channels; // Stereo
	const buffer = @as([*]f32, @ptrCast(@alignCast(output)))[0..valuesPerBuffer];
	@memset(buffer, 0);
	for(0..valuesPerBuffer)|i|{
		if(playbackData.popFront())|d|{
			buffer[i] = d;
			lastValue = d;
		}else {
			buffer[i] = lastValue;
		}
	}
}
pub fn pushPlaybackData(distanceSquared:f32,msg:[]const f32)void{
	var volume = 16.0/std.math.sqrt(distanceSquared);	
	if(volume>1)
		volume = 1;
	for(0..msg.len)|index|{
		playbackData.pushBack(msg[index]*volume);
	}
}

var recordDevice:c.ma_device = .{};
var playbackDevice:c.ma_device = .{};

pub fn init()void{
	playbackData = main.utils.CircularBufferQueue(f32).init(main.globalAllocator, 32);
	//set up for recording
	var deviceConfig:c.ma_device_config = .{};
	deviceConfig = c.ma_device_config_init(c.ma_device_type_capture);
	deviceConfig.capture.format   = c.ma_format_f32;
	deviceConfig.capture.channels = 1;
	deviceConfig.sampleRate = 44100;
	deviceConfig.dataCallback = record;

	var result:c.ma_result = c.ma_device_init(null, &deviceConfig, &recordDevice);
	errdefer c.ma_device_uninit(&recordDevice);
	handleError(result) catch return;

	//set up playback
	deviceConfig = c.ma_device_config_init(c.ma_device_type_playback);
	deviceConfig.playback.format   = c.ma_format_f32;
	deviceConfig.playback.channels = 1;
	deviceConfig.sampleRate = 44100;
	deviceConfig.dataCallback = play;

	result = c.ma_device_init(null, &deviceConfig, &playbackDevice);
	errdefer c.ma_device_uninit(&playbackDevice);
	handleError(result) catch return;	

	//start playing
	result = c.ma_device_start(&playbackDevice);
	handleError(result) catch return;
	
}
pub fn deinit()void{
	playbackData.deinit();
	_ = c.ma_device_uninit(&recordDevice);	
	_ = c.ma_device_stop(&playbackDevice);	
	c.ma_device_uninit(&playbackDevice);
}
var isRecording:bool = false;
pub fn activateRecording(_: main.Window.Key.Modifiers) void {
	isRecording =! isRecording;
	if(isRecording){
		std.debug.print("recording..\n", .{});

		const result = c.ma_device_start(&recordDevice);
		errdefer c.ma_device_uninit(&recordDevice);
		handleError(result) catch return;
	}else{
		_ = c.ma_device_stop(&recordDevice);
		std.debug.print("stopped recording..\n", .{});
	}
}
pub fn deactivateRecording(_: main.Window.Key.Modifiers) void {
}