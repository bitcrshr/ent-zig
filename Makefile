.PHONY: test

test:
	@zig build test -freference-trace
