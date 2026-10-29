# The ending after the hand-made worlds were dressed

`mistralai/mistral-medium-3.1`, four repetitions, the six-case ending corpus
(`test/fixtures/files/prompt_ending_corpus.yml`). It is the ending's current
baseline and replaces `prompt-ending-h2-after`, which stays as history and is
this pair's before side.

**The change.** The protagonists' clothes became worn item records, and the
moment the ending is written from now says what the player is wearing. Moved:
- the request identity: `v2:1913005814e96308` -> `v2:a651817700ad3751`;
- the prompt digest: `c2882e7d3580f3dd` -> `70aae1b0f439c0a7`.

The ending's own instructions (`3c6036d8f8aa572a`) and the corpus digest
(`c9321a319b26f0c5`) did not. Bought at server `4a77e5c` on engine `8840009`.

**The verdict.** Every check and every reported figure reads NOISE:

```sh
rake eval:prompt_compare CORPUS=ending BEFORE=prompt-ending-h2-after AFTER=prompt-ending-dressed-after
```

- `commitments` 2.250 -> 2.333
- `words` 50 -> 52
- `output_tokens` 1156 -> 1130
- `latency_median` 3.05s -> 2.93s

**Read by hand.** No ending on either side mentions anything somebody wears.
The board flagged two readings, one `third_person_protagonist` in
`ending-walk-into-the-cell` and one `unrecorded_departure` in
`ending-a-loose-line`. Both rates are inside the spread the unchanged runs
already showed.

**Cost.** The bench accounted $0.0253 for the 24 scored ending calls, which
leaves out the prelude prose calls. The key's usage was not read apart from
the runs either side of it. Across the main run, this run and the speech run
that was stopped, the key moved $0.245678 in all, against the $0.2221 the
main run accounted.
