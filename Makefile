.PHONY: test test-js test-lua test-all clean help

help:
	@echo "ConsoleLog Test Suite"
	@echo "===================="
	@echo "Available targets:"
	@echo "  make test-js    - Run JavaScript tests"
	@echo "  make test-lua   - Run Lua tests"
	@echo "  make test-all   - Run all tests"
	@echo "  make test       - Alias for test-all"
	@echo "  make clean      - Clean test artifacts"
	@echo "  make help       - Show this help"

test: test-all

test-all: test-lua
	@echo "All tests completed!"

test-lua:
	@echo "Running Lua tests..."
	@./tests/run_lua_tests.sh

clean:
	@echo "Cleaning test artifacts..."
	@rm -f /tmp/test_*.js
	@rm -f /tmp/test_output.txt
	@echo "Clean complete!"