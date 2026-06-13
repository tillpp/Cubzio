const std = @import("std");

const main = @import("main");
const User = main.server.User;

pub const description = "reload assets";
pub const usage =
	\\/reload
;

const Args = union(enum) {
	@"/reload": struct {},
};

const ArgParser = main.argparse.Parser(Args, .{.commandName = "/reload"});

pub fn execute(args: []const u8, source: *User) void {
	var errorMessage: main.List(u8) = .empty;
	defer errorMessage.deinit(main.stackAllocator);

	_ = args;
	_ = source;
	
	main.server.restart.store(true, .release);
	main.server.running.store(false, .release);	
}
