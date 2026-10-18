# The use pair, after: both readers describe `use` as searching, opening or breaking a part off

The same arm, transport, corpus and repetitions as
`classifier-use-before-20261018`: Jev 1.13 (TypeSafe direct) in front of
`mistralai/mistral-medium-3.1`, four repetitions of all 366 lines at
`0be7d3a93c05f097`, two calls in flight. Request identity
`v2:189a5ddbb7f67a32`. Every reading is kept.

It was bought at server `aa16f42`, with the engine at renderedstep/engine#64's
head `53da492ea87b69fee34472724612d975beb03fc7`. That commit differs from the
before side's engine only in the text both readers are given:

- The model call's instructions (`data/playthrough/classifier.yml`) now say
  `use` covers "search or open something that is fixed here, or break a part
  off it", and the token rule now covers searching, opening and breaking a part
  off.
- System One's `use` criterion and target premise
  (`data/playthrough/classifier/request.yml`) say the same.

## Verdicts

Against the before side (`rake eval:classifier_compare`, exact rank test, four
a side):

```
  strict_accuracy      0.924 -> 0.928  BETTER   NOISE
  accuracy             0.928 -> 0.926  WORSE    NOISE
  intent_accuracy      0.975 -> 0.966  WORSE    REAL (p=0.0286)
  refusal_agreement    0.949 -> 0.945  WORSE    NOISE
  closed_set_misses    17 -> 14        BETTER   REAL (p=0.0286)
  out_of_set           55 -> 58        WORSE    REAL (p=0.0286)
```

**Split by line, it does what it was for and costs something elsewhere.**

- **The study's twelve lines are right 44/48, against 32/48 before.** The three
  plain searches of the desk go from 0/4 to 4/4 each. "search the windowsill"
  is still 4/4, now as the labelled `use -> nothing`. "take the papers out of
  the desk" is still 0/4, and now lands on the desk's opening or search instead
  of `take -> desk`.
- **The other 354 lines are right 1315 times against 1325 before.** Accuracy
  on them alone is NOISE (p=0.2), but intent accuracy on them is WORSE, REAL
  (0.975 -> 0.966, p=0.0286). Three lines account for most of it. Each now
  reads as `use` where it read right before:
  - "get up and close your door": 4/4 -> 0/4, now `use -> nothing`
  - "I am going to inventory that closet myself": 4/4 -> 1/4, now
    `use -> nothing`
  - "stamp", a bare noun: 4/4 -> 0/4, now the daybook's offer or
    `use -> nothing`

  A few others moved by a reading each, either way.

Each of the three regressions was composed by System One without escalating
(`typed_model`), as were the three searches it got right. Both the gain and the
loss come from System One's widened criterion, not from the model call's
instructions.

Escalated 95 to 99 lines a repetition, the same as the before side.

## Spend

Booked from provider-reported charges on every settled call
(`receipts.json`): **$0.142570** for 389 Mistral calls. The highest single
charge was $0.0006064. With the before side and its trial, the pair cost
**$0.318302**. OpenRouter credit readings bracketing all three runs, read from
inside the bench process: 65.633283225 -> 65.953312145, $0.320029. That is the
receipts plus another $0.0017 on a shared account. Receipts are the figure of
record. The System One requests have no receipt here.
