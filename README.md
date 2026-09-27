# JustChess

JustChess is a World of Warcraft: Forever addon for playing chess.

## Development

Local tests require Make, PUC Lua 5.1, Busted, and LuaBitOp. Busted and LuaBitOp must be installed for the same Lua interpreter.

Run all default checks:

```sh
make check
```

Run the complete perft corpus through a selected depth:

```sh
make perft DEPTH=4
```

Use weighted process-level sharding for a faster local correctness check:

```sh
make perft-parallel DEPTH=4
```

The worker count defaults to the available performance cores, capped at eight, and can be overridden with `JOBS`. `make perft-full` runs all depths in parallel. The sequential `perft` target remains useful for stable performance measurements.

The default test suite runs all 130 positions and 378 expectations through depth 3. Depth 4 covers 507 expectations; depths 5 and 6 are explicit long-running checks.

## Repository layout

- `JustChess.toc` — addon metadata and production load order.
- `src/Core/` — chess state, legal move generation, make/unmake, and game API.
- `src/UI/` — board interface and local-game controller (next milestone).
- `spec/` — unit tests, test-only FEN support, and the full perft corpus.
