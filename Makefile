test:
	nvim --headless -u tests/minimal_init.lua \
		-c "PlenaryBustedDirectory tests/ {minimal_init='tests/minimal_init.lua'}"

# Compile-check every fenced code example in notes/ (the docs' unit tests).
check-examples:
	python scripts/check_examples.py

# Also execute full programs and diff their output against ```text fences.
check-examples-run:
	python scripts/check_examples.py --run

check: test check-examples

.PHONY: test check-examples check-examples-run check
