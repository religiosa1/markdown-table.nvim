.PHONY: test docs

test:
	nvim -l ./tests/busted.lua tests

# Generate doc/markdown-table.txt locally via the panvimdoc workflow (needs act + docker).
# act runs the container as root, so --bind leaves root-owned files; chown them back
# via the same (already-pulled) image so no sudo prompt is needed.
docs:
	act push -j docs -W .github/workflows/panvimdoc.yml \
		-P ubuntu-latest=catthehacker/ubuntu:act-latest \
		--bind
	docker run --rm -v "$(PWD)/doc:/doc" catthehacker/ubuntu:act-latest \
		chown -R $$(id -u):$$(id -g) /doc
