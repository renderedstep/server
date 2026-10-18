# The use pair, before: today's description of `use` on the corpus with the study

`Playthrough::Classifier::Cascade` in front of `mistralai/mistral-medium-3.1`,
System One answered by TypeSafe direct (`jev-1.13.0`), four repetitions, all 366
labelled lines at corpus digest `0be7d3a93c05f097`, request identity
`v2:ba3b467f3436519f`, two calls in flight. Every reading is kept.

This is the before side of `classifier-use-after-20261018`. It was bought at
server `c02800a`, with the engine extension built at renderedstep/engine main
`dc6efad3b9ae38526a0bcf8e5ccc65e1433e418a`. That commit has the throw
escalation, and both readers still describe `use` as consuming, burning,
offering and opening a barrier. The after side's engine differs from it only in
that description.

The corpus gained twelve lines at a new position, `study`: The Furnished
Rooms' clerk's study, the first position offered a search or an opening of a
fixed piece.

## What it reads

| | accuracy | strict | intent | refusal agreement | closed-set misses | out of set |
|---|---:|---:|---:|---:|---:|---:|
| median of four | 0.928 | 0.924 | 0.975 | 0.949 | 17 | 55 |

Escalated 95 to 98 lines a repetition.

**It reproduces the set before it.** On the 354 lines that
`classifier-cascade-throw-20261018` also scored, it reads 330 to 332 right a
repetition, against 329 to 332 in that set.

On the study's twelve lines it is right 32 of 48 times:

- **The three plain searches of the desk ("search the desk", "rummage through
  the desk drawers", "go through the clerk's desk") are 0/4.** Each one lands
  on `Open the desk`: the request offers the search, but neither reader is told
  that searching is `use`.
- "search the windowsill" is right 4/4, but only as the accepted look at the
  sill.
- "take the papers out of the desk" is 0/4. It lands on `take -> desk` three
  times and on the opening once.

## Spend

Booked from provider-reported charges on every settled call
(`receipts.json`): **$0.134635** for this set's 388 Mistral calls (the
escalations plus the warm-up), and **$0.041097** for a one-repetition trial
taken first on this tree and not kept (97 calls, 339/366), **$0.175732** in all.
The highest single charge was $0.0005968. The System One requests have no
receipt here and are in no figure above. The spend guard reserved $0.006 a call
under a $0.60 cap shared with the after side, with transport retries off.

```sh
rake eval:classifier_compare BEFORE=classifier-use-before-20261018 AFTER=classifier-use-after-20261018
```
