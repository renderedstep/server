# The cascade that escalates a throw

`Playthrough::Classifier::Cascade` in front of `mistralai/mistral-medium-3.1`,
System One answered by TypeSafe direct (`jev-1.13.0`, the pin in
`SystemOneAgent`), four repetitions, all 354 labelled lines at corpus digest
`363cb513da08c640`, request identity `v2:ba3b467f3436519f`, two calls in
flight. Every reading is kept, as every cascade set's are. It replaces
`classifier-cascade-state-20261017` as the cascade's before side.

## What changed

The engine, and nothing a model reads. At
renderedstep/engine `32e9c11afefb2a2976381e3430f427c13117a013`, `cascade::compose`
sends a line on to the model call when any word of it is a throw verb
(`cascade::THROW_VERBS`, read by `cascade::thrown`), beside the two flags.
System One is asked no throw, and before this it read every throw at a person or
a way out as the nearest blow or drop with neither flag firing. The six such
lines in the corpus were 0/4 in the set this one replaces.

**Both requests are byte-identical to the set before.** Neither `request_identity`
nor any other digest records that: the System One request is in no digest
(EVALUATION.md, *Two things a cascade set cannot tell you*), and the rule is not
a request at all. It was established offline before any call: every request the
engine builds for all 354 lines, System One's and the model call's, was built at
the previous pin (`5290b86`) and at this one, and all 354 pairs were equal. The
engines between the two pins also moved the narrator's facts and the attempts a
room offers, but no corpus position has a part to break, so no classifier
request changed. The offline floor (`offline.json`) is byte-identical to the
previous set's as well.

## Verdicts

Against `classifier-cascade-state-20261017`, the set this one replaces (same
arm, transport, corpus and request):

```
  strict_accuracy      0.916 -> 0.937  BETTER   REAL (p=0.0286)
  accuracy             0.915 -> 0.935  BETTER   REAL (p=0.0286)
  intent_accuracy      0.955 -> 0.975  BETTER   REAL (p=0.0286)
  refusal_agreement    0.947 -> 0.952  BETTER   REAL (p=0.0286)
  closed_set_misses    14 -> 14  WORSE    NOISE (inside the 2.000 the unchanged runs already spanned)
  out_of_set           57 -> 55  BETTER   NOISE (inside the 2.000 the unchanged runs already spanned)
```

Against the kept Mistral-alone row `classifier-2026-09-27` (the same schema
request; its corpus lacks the three reported-intent lines, and it was taken one
call at a time): **NOISE** on strict accuracy (0.936 -> 0.937), accuracy (0.937
-> 0.935), intent accuracy (0.982 -> 0.975), refusal agreement (0.948 -> 0.952)
and misses (15 -> 14); `out_of_set` 62 -> 55 BETTER, REAL. The cascade no longer
reads behind the model call alone.

**Split by line.** The eight lines with a throw verb are right 32/32, against
6/32 before: the six real throws 24/24 (0/24 before), `throw-the-switch` 4/4,
and `throw-the-bolt` 4/4 (2/4 before, when it escalated only on the presence
flag). On the 346 lines with no throw verb, whose composition the rule cannot
reach, accuracy is 0.931..0.934 before and 0.928..0.936 now: **NOISE** (exact
rank test over the per-repetition accuracies of those lines, p=1.0). Seven of
those lines changed their count of right repetitions, four down and three up.
No throw verb is in any of them, so the rule cannot reach them, and the verdict
puts them inside the run-to-run spread.

Escalations: 95-98 a repetition, against 87-90 before; the difference is the
throw lines.

## Spend

Booked from provider-reported charges on every settled call
(`receipts.json`): **$0.130444** for this set's 385 escalations, plus
**$0.043075** for a one-repetition trial taken first and not kept (331/354, all
eight throw lines right), **$0.173519** in all. No call was unsettled; the
highest single charge was $0.0005968. The bench's own estimate, which prices
every line as a model call at 372 tokens in, was $0.267 for the four repetitions
and $0.067 for the trial.

OpenRouter credit readings bracketing both runs, read from inside the bench
process: 65.459763305 -> 65.612214905, $0.152452, below the receipts as on
earlier sets (settlement lag on the last calls; the account is shared).
Receipts are the figure of record. The System One requests, one per line per
repetition plus warm-ups, have no receipt here and are in no figure above, as
with every earlier cascade set.

The spend guard was the previous set's, unchanged in substance: a ledger under
a $0.40 cap shared by the trial and the run, a reservation of $0.006 a call
(ten times the highest charge settled for this request shape), and transport
retries off.

```sh
rake eval:classifier_compare BEFORE=classifier-cascade-state-20261017 AFTER=classifier-cascade-throw-20261018
rake eval:classifier_compare BEFORE=classifier-2026-09-27 AFTER=classifier-cascade-throw-20261018
```
