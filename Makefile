.DEFAULT_GOAL := help

DEPTH ?= 3
JOBS ?= $(shell cores=$$(sysctl -n hw.perflevel0.physicalcpu 2>/dev/null || getconf _NPROCESSORS_ONLN 2>/dev/null || echo 1); if [ "$$cores" -gt 8 ]; then echo 8; else echo "$$cores"; fi)
SHARD ?= 1
START ?= 1
LUA_PATH := ./?.lua;./?/init.lua

.PHONY: help test perft perft-parallel perft-full lint format format-check check

help:
	@echo "Targets: check test perft perft-parallel perft-full lint format format-check"

test:
	busted --lpath="$(LUA_PATH)" spec

perft:
	JUSTCHESS_PERFT_DEPTH=$(DEPTH) JUSTCHESS_PERFT_SHARD=$(SHARD) JUSTCHESS_PERFT_SHARDS=$(if $(SHARDS),$(SHARDS),1) busted --lpath="$(LUA_PATH)" spec/perft_spec.lua

perft-parallel:
	@jobs="$(JOBS)"; start="$(START)"; total="$(if $(SHARDS),$(SHARDS),$(JOBS))"; \
	for value in "$$jobs" "$$start" "$$total"; do \
		case "$$value" in ''|*[!0-9]*) echo "JOBS, START, and SHARDS must be positive integers" >&2; exit 2;; esac; \
	done; \
	if [ "$$jobs" -lt 1 ] || [ "$$start" -lt 1 ] || [ "$$total" -lt 1 ]; then \
		echo "JOBS, START, and SHARDS must be positive integers" >&2; exit 2; \
	fi; \
	if [ $$((start + jobs - 1)) -gt "$$total" ]; then \
		echo "the requested JOBS and START must fit within SHARDS" >&2; exit 2; \
	fi; \
	tmp=$$(mktemp -d "$${TMPDIR:-/tmp}/just-chess-perft.XXXXXX") || exit 1; \
	pids=""; \
	trap 'rm -rf "$$tmp"' 0; \
	trap 'kill $$pids 2>/dev/null; exit 130' 1 2 3 15; \
	last=$$((start + jobs - 1)); \
	echo "Running perft depth $(DEPTH), shards $$start-$$last of $$total"; \
	shard="$$start"; \
	while [ "$$shard" -le "$$last" ]; do \
		JUSTCHESS_PERFT_DEPTH=$(DEPTH) JUSTCHESS_PERFT_SHARD="$$shard" JUSTCHESS_PERFT_SHARDS="$$total" busted --lpath="$(LUA_PATH)" spec/perft_spec.lua >"$$tmp/$$shard.log" 2>&1 & \
		pids="$$pids $$!"; \
		shard=$$((shard + 1)); \
	done; \
	status=0; shard="$$start"; \
	for pid in $$pids; do \
		wait "$$pid" || status=1; \
		printf '\nShard %s/%s\n' "$$shard" "$$total"; \
		cat "$$tmp/$$shard.log"; \
		shard=$$((shard + 1)); \
	done; \
	exit "$$status"

# Full perft test is distributed across the available cores.
perft-full:
	$(MAKE) perft-parallel DEPTH=6

lint:
	selene src spec/support

format:
	stylua src spec

format-check:
	stylua --check src spec

check: format-check lint test
