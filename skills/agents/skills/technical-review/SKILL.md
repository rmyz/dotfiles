---
name: technical-review
description: Technical review of a diff — architecture, bad patterns, consistency with existing Kibana conventions and components, and Fowler code smells. Reports findings; never applies changes.
---

# Technical review

Review the diff. By default that means uncommitted changes plus the commits on this
branch against `upstream/main` (committed, staged, unstaged, and untracked); if the
invocation names a ref, branch, or PR, review that instead.

Focus on code architecture, bad patterns, consistency with existing conventions and
components in the surrounding Kibana code, and the Fowler code smells below. Match
each smell against the diff — name it and quote the hunk — as judgement-call
heuristics, not hard rules. Skip anything tooling already enforces (ESLint, type
checks, i18n checks).

- **Mysterious Name** — a function, variable, or type whose name doesn't reveal what
  it does or holds. → rename it; if no honest name comes, the design's murky.
- **Duplicated Code** — the same logic shape appears in more than one hunk or file.
  → extract the shared shape, call it from both.
- **Feature Envy** — a method that reaches into another object's data more than its
  own. → move the method onto the data it envies.
- **Data Clumps** — the same few fields or params keep travelling together. → bundle
  them into one type, pass that.
- **Primitive Obsession** — a primitive standing in for a domain concept that
  deserves its own type. → give the concept its own small type.
- **Repeated Switches** — the same `switch`/`if`-cascade on the same type recurs.
  → replace with polymorphism, or one map both sites share.
- **Shotgun Surgery** — one logical change forces scattered edits across many files.
  → gather what changes together into one module.
- **Divergent Change** — one file or module is edited for several unrelated reasons.
  → split so each module changes for one reason.
- **Speculative Generality** — abstraction, parameters, or hooks added for needs the
  task doesn't have. → delete it; inline back until a real need shows.
- **Message Chains** — long `a.b().c().d()` navigation the caller shouldn't depend
  on. → hide the walk behind one method on the first object.
- **Middle Man** — a class or function that mostly just delegates onward. → cut it,
  call the real target direct.
- **Refused Bequest** — a subclass or implementer that ignores most of what it
  inherits. → drop the inheritance, use composition.

Beyond the smells, flag these slop patterns aggressively:

- Defensive code on trusted internal paths: try/catch, existence checks, or
  fallbacks the surrounding code does not need. → delete; let internal invariants
  hold.
- Thin wrappers or identity abstractions that add indirection without buying
  clarity. → cut them, keep the direct flow.
- One-off booleans, nullable modes, or flags bolted onto an existing flow. → ask
  for the model change that makes the branch disappear.
- Feature-specific logic leaking into shared modules or the wrong layer. → move it
  behind the feature's own boundary.

Report each finding with severity, file, and a one-line suggested fix. Do not apply
changes. End with a short list of which findings you would act on and which you would
drop, and why.
