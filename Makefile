.PHONY: test coverage act

test:
	@zig build test -freference-trace

coverage:
	zig build cov

act:
	gh act push --secret-file gh_secrets --var-file act_vars	
