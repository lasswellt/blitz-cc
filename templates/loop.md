Run `/blitz:next --loop`.

Rules for every tick:
- One tick = one row of work; commit with the `Task: <slug>/T-nnn` trailer and push before the marker line.
- Stop when the tick ends with `LOOP_DONE` or `LOOP_ESCALATE`; on `LOOP_DEFER` wait for the next interval.
- Never start a new plan from here: `/blitz:plan` is a human decision. Only work on plans already under `docs/plans/`.
- Never dispatch `/blitz:ship`; print its `Ready:` line and leave it to a human.
- If `.cc-sessions/STOP` exists, stop immediately.
