# Borrowed checklist items, with their licences

Some review questions in `SKILL.md` are adapted from two openly licensed agent
skills. Nothing here is installed or vendored: the items below are rewritten
for this game's records and commands, and each says where it came from and
what changed. Only MIT and Apache-2.0 sources are adapted.

## From Scouten2/LevelDesignSkill (MIT)

Source: https://github.com/Scouten2/LevelDesignSkill, `skills/level-design/SKILL.md`
and `skills/level-design/scripts/graph_check.py`.

- **"Count, don't eyeball; verify, don't assert."** The original's core rule:
  never claim a level is solvable, reachable or of a given difficulty without a
  script result or an explicitly labelled hand trace. *Adapted as* the rule
  that evidence is a doctor finding, a sweep assertion, a fight-simulator
  result or a lab score, and anything else is a labelled hand trace.
- **Lock-and-key graph checks** — reachability, key before its door, dead ends,
  loops. *Adapted as* the layout lens's questions, answered by this repo's own
  doctor and sweeps over records rather than by the original's script.
- **"A dead end must pay"** and **"prefer circuits and shortcuts back to
  safety"** (the original's rhythm-and-loops rule). *Adapted as* the layout
  lens's dead-end and more-than-one-way questions.
- **"Alternate tension and release."** *Adapted as* the pacing lens, with the
  release built into the layout because the engine may only add a threat.

Licence notice, as the source carries it:

```text
MIT License

Copyright (c) 2026 Scouten2

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## From Youtouch/Game-Design-Skills (Apache-2.0)

Source: https://github.com/Youtouch/Game-Design-Skills,
`skills/puzzle-design/SKILL.md` and `skills/quest-design/SKILL.md`.

- **Check soft-locks** (puzzle-design): can the player consume, move or
  trigger something that makes the goal unreachable? *Adapted as* the layout
  lens's key-before-its-lock question and the fairness lens's "obvious
  beforehand".
- **Map dependencies, working backwards from the goal**, and look for
  bottlenecks and dead ends (puzzle-design, after Gilbert). *Adapted as* the
  critical-path question.
- **Locate the key inference; check its evidence is perceivable and available
  before it is needed** (puzzle-design). *Adapted as* the goal-and-legibility
  lens's "more than one way to learn where the next beat is".
- **Check objective clarity: at each step the player can find what to do next,
  why and where** (quest-design). *Adapted as* the goal-and-legibility lens,
  answered by the doctor's P1 and P2.
- **A consequence the player never perceives does not make the choice
  meaningful** (quest-design). *Adapted as* "what is the player deciding, and
  can they see what they need to decide it?"
- **List failure states: is failure signalled, and does it lead somewhere?**
  (quest-design). *Adapted as* the fairness lens's "where does the player see
  it coming, in the engine's own words?"

Changes: the items are paraphrased and re-pointed at this repository's
records, doctor and sweep scripts; the original procedures and output formats
are not reproduced. Licence notice:

```text
Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```

The full licence text is in the source repository's `LICENSE` file.
