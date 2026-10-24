# The ending reads the concluding turn's fact, judged

The pair `prompt-ending-h2-before` and `prompt-ending-h2-after`,
`mistralai/mistral-medium-3.1`, four repetitions a side, on the six-case ending
corpus (`test/fixtures/files/prompt_ending_corpus.yml`). The after side is the
ending's current baseline; `prompt-ending-after-2026-10-02` stays as history and
is byte for byte the request the before side sent.

**The change** (renderedstep/engine#69). On the ending's pass alone, *What just
happened* reads the concluding turn's `engine_fact` instead of its paragraph,
unless that turn was a move or has no fact; turn narration is untouched. Four
cases now carry the fact (`ending-take-the-ring`, `ending-look-at-the-ring`,
`ending-drop-the-ring`, `ending-take-the-writ-over-the-dead`); the move
(`ending-walk-into-the-cell`) and the other line (`ending-a-loose-line`) send
the same request on both sides. The ending's own instructions did not move
(`instructions_digest` `3c6036d8f8aa572a` both sides); the request identity did
(`v2:4e5e367c21bbf5dc` -> `v2:1913005814e96308`). The before side was a fresh
run at engine pin `9d59cb8`; the after side was built against the change.

**The verdict.** `rake eval:prompt_compare BEFORE=prompt-ending-h2-before
AFTER=prompt-ending-h2-after`: NOISE on every check. `commitments` 2.833 ->
2.250 is REAL (p=0.0286): the endings name fewer rooms, exits, items and
people. `words` 48 -> 50 and `output_tokens` 1111 -> 1156 NOISE;
`latency_median` 2.51s -> 3.05s INCONCLUSIVE.

**Read by hand.** `ending-take-the-ring` had one `item_not_held` flag (rep 2),
and three of its four endings re-narrate the lift: the fact's own "it is what to
narrate" now reaches the ending writer. `ending-look-at-the-ring` and
`ending-drop-the-ring` were clean and shorter; `ending-take-the-writ-over-the-dead`
was clean, `inscription_misquoted` included. Of the unchanged cases,
`ending-a-loose-line` had one `unrecorded_departure` flag on the after side and
none before, inside the spread the unchanged runs span.

**Cost.** The receipts total $0.1139: a one-repetition trial of the after side
$0.0146 (not kept), the after side $0.0453 and the before side $0.0540, counting
both the prelude prose calls and the scored ending calls.
