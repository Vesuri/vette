# Rename queue

⚠⚠ **THIS IS A QUEUE, NOT A LOG.** An applied rename is **DELETED** from this file in the same
commit that applies it; `disasm/symbols.csv` then carries the name and its evidence, and whatever
the old name *cost* goes in the doc that was wrong. No DONE entries, no history, no process prose.

**Append to this file the moment a function, table or global contradicts its name** — or has none
and you are about to reason about it. Do not rename piecemeal; `disasm/symbols.csv` is the source of
truth and `ghidra_scripts/ApplyNames.java` applies it.

⭐ **On a binary-only project the names are your map**, and every wrong name taxes every later
reasoning step. **Apply the queue as part of the work, not when asked** — renaming is cheap right up
to the moment hand-written code references the name, and never again.

⭐⭐ And a rename is a re-read of the SENTENCES, not just of the identifier: a name that was wrong
made prose around it read plausibly, and that prose is still there and still false. Re-read each hit
in context and fix the claim, not the token.

| Segment | Addr | Current name | Actual behaviour | Suggested name |
|---|---|---|---|---|
| | | | | |

*(empty — nothing disassembled yet)*
