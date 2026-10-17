# The cascade's kept set at today's corpus

`Playthrough::Classifier::Cascade` in front of `mistralai/mistral-medium-3.1`,
System One answered by TypeSafe direct (`jev-1.13.0`, the pin in
`SystemOneAgent`), four repetitions, all 354 labelled lines at corpus digest
`363cb513da08c640`, request identity `v2:ba3b467f3436519f`. Every reading is
kept, as every cascade set's are. It replaces
`classifier-cascade-state-20260927`, which stays as history at the 343-line
digest `027013dd5a020328` it was bought at.

Re-bought so a reader measured on today's corpus has a cascade row on the same
lines to be judged against. The previous kept set predates the eight `throw`
lines and the three reported-intent lines, so any comparison against it carried
the different-corpora warning. Nothing about the request was changed for this
run: it is the code at the tree that bought it, with the Rust engine built at
its pinned commit.

## What the corpus change did on its own

Against `classifier-cascade-state-20260927` (different corpora and, since the
`throw` enum landed, a different schema request identity):

```
  strict_accuracy      0.936 -> 0.916  WORSE    REAL (p=0.0286)
  accuracy             0.936 -> 0.915  WORSE    REAL (p=0.0286)
  intent_accuracy      0.974 -> 0.955  WORSE    REAL (p=0.0286)
  refusal_agreement    0.954 -> 0.947  WORSE    REAL (p=0.0286)
  closed_set_misses    13 -> 14        WORSE    NOISE
```

**The drop is the added lines, not the cascade.** On the 343 lines both sets
scored, accuracy is 0.933..0.939 before and 0.930..0.933 now: **NOISE**
(p=0.0857, the same rank test over the per-repetition accuracies of those
lines alone). The 11 added lines come back 4 or 5 right a repetition:

- the three reported-intent lines (`two-sets-talk-*`) are right 4/4;
- the six throws at a person or a place (`throw-daybook-*`,
  `throw-slate-brace`, `throw-stamp-hallway`) are right 0/4. System One
  composes them as `attack` or `drop` with neither flag firing, so they never
  reach Mistral. The cascade asks no `throw` question, so on these lines it
  cannot be right without escalating;
- `throw-the-switch` escalates and is right 4/4; `throw-the-bolt` 2/4.

Against the kept Mistral-alone row `classifier-2026-09-27` (the same schema
request; that corpus lacks the three reported-intent lines): accuracy 0.937 ->
0.915, strict accuracy 0.936 -> 0.916 and intent accuracy 0.982 -> 0.955,
WORSE, REAL; refusal agreement and misses NOISE; `out_of_set` 62 -> 57 BETTER,
REAL. **On today's corpus the cascade reads behind the model call alone.** The six
throw lines it never escalates are 24 wrong readings of 1,416, 1.7 of the 2.2
points; the Mistral-alone set keeps no rows, so the rest cannot be read off
it line by line. Whether the cascade should
learn to escalate a throw is a design question, not something this set settles.

It escalates 87-90 lines a repetition (354 over four), the same rate as the
set it replaces.

## Spend

Booked from provider-reported charges on every settled call
(`receipts.json`): **$0.118335** for this set's 354 escalations, plus
**$0.038288** for a one-repetition trial taken first and not kept, **$0.156623**
in all. No call was unsettled. The bench's own estimate, which prices every line
as a Mistral call at 372 tokens in, was $0.267 for the four repetitions; the
escalations are about a quarter of the lines, at a mean of 619 tokens in each
and at most $0.0005944. The TypeSafe requests have no receipt here and are in no
figure above.

The spend guard was `doc/evidence/seed-world-arcs-rebuy/run.rb`'s, unchanged in
substance: a ledger under a $0.40 cap shared by the trial and the run, a
reservation of $0.006 a call (ten times the highest charge settled for this
request shape on 2026-09-27, $0.0005244), and transport retries off.

```sh
rake eval:classifier_compare BEFORE=classifier-cascade-state-20260927 AFTER=classifier-cascade-state-20261017
rake eval:classifier_compare BEFORE=classifier-2026-09-27 AFTER=classifier-cascade-state-20261017
```
