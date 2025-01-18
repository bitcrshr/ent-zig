.PHONY: test coverage

test:
	@zig build test -freference-trace

	
