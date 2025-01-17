.PHONY: test

test:
	zig test --dep reflectionutil --dep anyptr  \
	-Mentql=src/entql/entql.zig \
	-Mreflectionutil=src/util/reflection.zig \
	-Manyptr=src/util/anyptr.zig
