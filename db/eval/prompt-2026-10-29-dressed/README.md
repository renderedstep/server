# prompt-2026-10-29-dressed

The main prompt corpus, bought again at four repetitions on the shipped model.
The three hand-made worlds now dress their people. Odile Vance wears her office
coat and carries her spectacles, Isbet Marrow wears her surveyor's coat, and
Coraith Vell wears court black under an oilskin. Each is an item record, and
the clothes are no longer in the protagonists' appearance. The narrator
learns what the player is wearing from those records, under "The player is
wearing:". The NPCs keep their appearance lines exactly as before, because the
engine tells no prompt what an NPC wears.

No instruction to the narrator changed. Moved:
- the request identity: `v1:77f94a8426ff4d58` -> `v1:530de6fbea48faa7`;
- the prompt digest: `511524f8e7097191` -> `6d1ccb5937bdc56c`.

The instructions digest (`be4e1bf387f97e80`) and the corpus digest
(`dfd1756a8f1f91b8`) did not. The requests grew by about 1% in characters. It
replaces `prompt-2026-10-13-examine-plain`, which stays as history.

Bought at server `4a77e5c` on engine `8840009` (renderedstep/engine#88 merged).

## Verdict against the side before

`rake eval:prompt_compare BEFORE=prompt-2026-10-13-examine-plain AFTER=prompt-2026-10-29-dressed`

- **Every check reads NOISE.**
- `take_denied` 0.083 -> 0.000 reads INCONCLUSIVE.
- Reported figures that read REAL:
  - `commitments` 3.250 -> 3.506;
  - `output_tokens` 12784 -> 12926;
  - `latency_median` 1.49s -> 1.87s and `latency_p95` 2.09s -> 2.60s.
- `words` 95 -> 97 is NOISE.

The latency rise is a quarter, against requests about 1% longer. It reads as
the provider on the day, not the change, but it was not bought the same day as
the before side, so that is not proven.

```
  item_not_held              0.050 -> 0.056  WORSE     NOISE
  take_denied                0.083 -> 0.000  BETTER    INCONCLUSIVE
  every other check          unchanged       NOISE
  latency_median             1.49s -> 1.87s  WORSE     REAL (p=0.0286)
  latency_p95                2.09s -> 2.60s  WORSE     REAL (p=0.0286)
  output_tokens              12784 -> 12926  reported  REAL (p=0.0286)
  words                      95 -> 97        reported  NOISE
  commitments                3.250 -> 3.506  reported  REAL (p=0.0286)
```

## Read by hand

No check counts clothing, so the after side was read for it. The before side
kept no prose. Of 360 paragraphs:
- 74 mention a thing somebody wears (coat 31, gown 18, spectacles 17,
  oilskin 8, office coat 6, court black 1).
- None takes off, drops or puts on a worn thing that the line did not ask for.
- Two `take-apron-wearing` readings put the apron on over the office coat.
- One `examine-apron-carried` reading draws the apron "from your coat
  pocket", and one `take-index-plain` reading slips the index into the office
  coat. Both are flagged by the existing checks (`item_not_held`,
  `unrecorded_arrival`).

All 21 `item_not_held` readings are about the apron or the index, never a
worn thing. Their rate, 0.050 -> 0.056, is NOISE.

## Cost

- The bench accounted $0.2221 over 360 calls.
- The key's usage moved $0.2021 between the readings either side of the run.
  That second reading had not settled: the rest reached it during the ending
  run that followed. `receipts.json` has the readings.
- The key is shared, so key figures are an upper bound.
