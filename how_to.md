# How I Built an Async FIFO from Scratch Using AI

> A step-by-step account of how I used GitHub Copilot (Claude) in VS Code
> to design, implement, verify, and sign off an asynchronous FIFO —
> going from an empty module shell to a fully tested, lint-clean, CDC-clean,
> synthesizable RTL IP in a single session.

---

## Table of Contents

1. [Philosophy: How to Work With AI on Hardware Design](#philosophy)
2. [The Starting Point](#starting-point)
3. [Step 1: Brainstorming the Architecture](#step-1)
4. [Step 2: Deep-Dive on CDC Strategy](#step-2)
5. [Step 3: Creating a Living Design Document](#step-3)
6. [Step 4: Defining Milestones Before Writing Code](#step-4)
7. [Step 5: RTL Implementation (Milestone 1)](#step-5)
8. [Step 6: Basic Testbench (Milestone 2)](#step-6)
9. [Step 7: Stress & Corner-Case Testing (Milestone 3)](#step-7)
10. [Step 8: Lint, CDC, and Synthesis (Milestone 4)](#step-8)
11. [Step 9: Documentation & Wrap-Up (Milestone 5)](#step-9)
12. [Key Takeaways](#key-takeaways)
13. [Tips for Using AI in RTL Design](#tips)
14. [What Went Wrong (and How We Fixed It)](#what-went-wrong)
15. [Prompt Patterns That Worked](#prompt-patterns)
16. [Final Thoughts](#final-thoughts)

---

<a id="philosophy"></a>
## 1. Philosophy: How to Work With AI on Hardware Design

My approach can be summarized in three principles:

1. **Design first, code second.** I made the AI explain and document the
   architecture *before* writing a single line of RTL. This ensures the AI
   (and I) understand the problem deeply before committing to implementation.

2. **Incremental milestones with verification.** Instead of asking for
   everything at once, I broke the work into 5 milestones, each with clear
   exit criteria. After each milestone, we ran `make all` to prove correctness
   before moving on.

3. **The human steers, the AI executes.** I decided *what* to do and *when*
   to commit. The AI decided *how* to implement it. I reviewed results,
   asked clarifying questions, and course-corrected when needed.

---

<a id="starting-point"></a>
## 2. The Starting Point

I began with a nearly empty workspace:

```
async_fifo.sv   ← empty module shell with only the port list
tb_top.sv       ← basic testbench skeleton
Makefile        ← Vivado simulation flow
run.tcl         ← Vivado TCL script
README.md       ← one-liner
```

The `async_fifo.sv` file contained *only* the module interface — no logic at all:

```systemverilog
module async_fifo#(
      parameter int DATAWIDTH = 8
    , parameter int ADDRWIDTH = 4
    )(
      input  logic wclk, wrst_n, wrreq,
      input  logic [DATAWIDTH-1:0] data,
      output logic full,
      input  logic rclk, rrst_n, rdreq,
      output logic [DATAWIDTH-1:0] q,
      output logic empty
);
endmodule
```

This is important — I *deliberately* defined the interface myself. The interface
is a design decision that the human should own. The AI fills in the internals.

---

<a id="step-1"></a>
## 3. Step 1: Brainstorming the Architecture

### What I asked:
> "I would like to design an asynchronous fifo from scratch. The top interface
> is in this sv file. Could you propose some ideas?"

### What happened:
The AI analyzed the port list and proposed the classic Gray-code pointer
architecture (Cliff Cummings SNUG 2002 style), including:
- A block diagram with 5 sub-modules
- The full/empty detection logic using Gray-code comparison
- Why Gray code is essential for CDC safety
- Possible extensions (almost-full/empty, FWFT, etc.)

### Why this worked:
By asking for *proposals* rather than code, I got a high-level design review
before committing to anything. The AI laid out the architecture clearly enough
that I could evaluate it, ask questions, and approve it.

### Key insight:
> **Don't jump to "write the code." Start with "propose some ideas."**
> This gives you a chance to review the approach before it's baked into RTL.

---

<a id="step-2"></a>
## 4. Step 2: Deep-Dive on CDC Strategy

### What I asked:
> "How will you handle wptr and rptr CDC?"

### What happened:
The AI gave a detailed explanation of:
- Why binary pointers are unsafe across clock domains
- The 3-step solution: Gray encode → 2-FF synchronize → compare
- A safety analysis table (metastability, stale values, wrap-around)
- Why the design is *conservative* (pessimistic full/empty, never optimistic)

### Why this worked:
CDC is the most error-prone part of an async FIFO. By making the AI explain
it in detail *before* coding, I validated that it understood the nuances —
especially the conservative behavior ("full may stay asserted 1-2 cycles
after space becomes available — that's a feature, not a bug").

### Key insight:
> **Probe the AI's understanding of the hardest technical aspects.**
> If it can explain CDC correctly in prose, it will likely implement it
> correctly in RTL.

---

<a id="step-3"></a>
## 5. Step 3: Creating a Living Design Document

### What I asked:
> "Can you update the discussion in async_fifo.md file first?"

Then after the CDC discussion:
> "Please update md file and commit."

### What happened:
The AI created `async_fifo.md` — a comprehensive design document covering:
- Interface/parameter tables
- Block diagram
- Sub-module descriptions
- CDC strategy with diagrams
- Safety analysis
- Design constraints

Each time we discussed something, I asked the AI to update the design doc
and commit. This created a *living document* that evolved alongside the design.

### Why this worked:
The design doc served as:
1. **A contract** — "this is what we agreed to build"
2. **A reference** — the AI could refer back to it during implementation
3. **Reviewable artifact** — anyone can read the doc to understand the design
4. **Git history** — each commit shows how the design evolved

### Key insight:
> **Make the AI maintain documentation as you go, not as an afterthought.**
> Ask it to commit after each update so you have a clean git trail.

---

<a id="step-4"></a>
## 6. Step 4: Defining Milestones Before Writing Code

### What I asked:
> "Can you make some milestones for the implementation plan, update md and commit"

### What happened:
The AI created 5 milestones with checkbox tables:

| MS | Focus | # Tasks |
|----|-------|---------|
| 1  | RTL sub-modules | 6 |
| 2  | Basic testbench | 5 |
| 3  | Stress testing | 5 |
| 4  | Lint & CDC analysis | 3 |
| 5  | Documentation wrap-up | 3 |

Each milestone had clear exit criteria (e.g., "RTL compiles cleanly",
"Zero data corruption across all scenarios").

### Why this worked:
Milestones gave structure to the entire session. Instead of an open-ended
"implement everything," each step was bounded and verifiable. The AI could
focus on one milestone at a time, and I could track progress via checkboxes.

### Key insight:
> **Before any coding, agree on milestones with clear exit criteria.**
> This prevents scope creep and gives you natural checkpoints to review.

---

<a id="step-5"></a>
## 7. Step 5: RTL Implementation (Milestone 1)

### What I asked:
> "Let's implement milestone 1. You can use `make all` to regression tests."

### What happened:
1. The AI first **read the existing testbench and Makefile** to understand
   the build flow, clock frequencies, and read protocol
2. It noticed the testbench reads `q` *before* asserting `rdreq` — meaning
   the RAM needs a combinational read port (important design decision!)
3. It implemented all 5 sub-modules inline in `async_fifo.sv`
4. It found Vivado wasn't in PATH, located it at `/tools/Xilinx/Vivado/2023.2/`,
   sourced the environment, and ran `make all`
5. **Result: 2000/2000 data words verified, test passed**

### Why this worked:
By telling the AI to use `make all` for regression, it had a concrete way to
verify its own work. It didn't just write code and hope — it *ran the tests*
and confirmed they passed.

### Key insight:
> **Always give the AI a way to self-verify.** Tell it the test command.
> The AI will run it, check the output, and fix issues autonomously.

---

<a id="step-6"></a>
## 8. Step 6: Basic Testbench (Milestone 2)

### What I asked:
> "Can you implement milestone 2"

### What happened:
The AI restructured `tb_top.sv` into 4 distinct test phases:
1. Reset sequence (verify `empty=1, full=0`)
2. Full flag test (fill 1024 words, confirm `full` asserts)
3. Empty flag test (drain 1024 words, verify data integrity)
4. Write-then-read (2000 random words, concurrent R/W)

**First run:** The write-then-read test timed out! The writer was trying to
push 2000 words into a 1024-deep FIFO without a concurrent reader.

**Fix:** The AI refactored to use `fork/join` with concurrent writer and reader.

**Second run:** All 4 tests passed.

### Why this worked:
The AI caught its own bug through `make all`, diagnosed it ("FIFO is only 1024
deep, writer blocks on full with no reader"), and fixed it without me
intervening.

### Key insight:
> **Let the AI fail and self-correct.** The run → fail → diagnose → fix loop
> is one of the most powerful patterns. Don't micromanage — let it iterate.

---

<a id="step-7"></a>
## 9. Step 7: Stress & Corner-Case Testing (Milestone 3)

### What I asked:
> "Let's do MS 3"

### What happened:
The AI added 5 new stress tests:
- **3.1** Simultaneous R/W with random 0-3 cycle delays
- **3.2** Clock ratio sweep (3 configs: fast-write, fast-read, equal)
- **3.3** Back-to-back fill/drain cycles (4×1024 words)
- **3.4** Reset during operation (reset after 100 writes, verify recovery)
- **3.5** Randomized stimulus (3000 words, random enables)

**Run 1:** Tests 3.1-3.2.0 passed, but 3.2.1 (fast-read) failed with
`rcvd=999` (off by one) — a race condition in the reader's exit logic.

**Fix:** Changed reader loop from `while (!wr_done || !empty)` to
`while (rcvd_count < N)`.

**Run 2:** Tests 3.1-3.4 passed, but 3.5 timed out — the randomized test
was too slow with single-cycle random enables.

**Fix:** Rewrote to use `write_one`/`read_one` tasks with random idle gaps
instead of per-cycle random enables.

**Run 3:** All 11 tests passed!

### Why this worked:
The AI needed two fix iterations, but each time it correctly diagnosed the
root cause from the simulation output. The key was providing enough information
(the tail of the simulation log) for it to reason about the failure.

### Key insight:
> **Complex tests may take 2-3 iterations to get right.** That's normal.
> The AI's ability to read simulation output and self-diagnose is remarkable,
> but corner cases in concurrent testbench code are genuinely tricky.

---

<a id="step-8"></a>
## 10. Step 8: Lint, CDC, and Synthesis (Milestone 4)

### What I asked:
> "Can you impl milestone 4 with Vivado?"

### What happened:
The AI created:
- `run_ms4.tcl` — a Vivado TCL script for RTL DRC, synthesis, and CDC analysis
- A `make ms4` Makefile target

**Run 1:**
- RTL DRC: 0 violations ✅
- Synthesis: clean (28 LUTs, 40 FFs) ✅
- CDC: all crossings **Safe**, but **10 missing ASYNC_REG** warnings
- TCL error on methodology report (wrong property name)

**Fixes:**
1. Added `(* ASYNC_REG = "TRUE" *)` attributes to all 4 synchronizer registers
2. Fixed TCL property name (`MESSAGE` → `DESCRIPTION`)
3. Re-ran simulation to confirm ASYNC_REG didn't break anything

**Run 2:**
- CDC: all Safe, **0 missing ASYNC_REG** ✅
- Methodology: 22 advisories — all missing I/O delay constraints (expected for IP)

### Why this worked:
The AI understood Vivado's TCL API well enough to write a complete analysis
flow. When CDC flagged missing `ASYNC_REG`, the AI knew exactly where to add
the attributes in the RTL and *re-ran simulation* to verify the change was safe.

### Key insight:
> **Use the AI for tool-specific flows.** It knows Vivado TCL, synthesis
> commands, and CDC analysis well enough to automate them. But always
> review the reports yourself — the AI reports what it sees, but you need
> to judge whether methodology advisories are acceptable.

---

<a id="step-9"></a>
## 11. Step 9: Documentation & Wrap-Up (Milestone 5)

### What I asked:
> "Let's finish MS5"

### What happened:
The AI:
1. Updated `async_fifo.md` with final design notes and deviations from plan
2. Rewrote `README.md` with full project overview, file inventory, quick-start
   instructions, test summary table, and synthesis results
3. Committed everything and created a `v1.0` annotated git tag

### Key insight:
> **Let the AI write the first draft of documentation.** It has perfect recall
> of everything that happened in the session. You review and edit — much faster
> than writing from scratch.

---

<a id="key-takeaways"></a>
## 12. Key Takeaways

### The Human's Job
| Responsibility | Example |
|----------------|---------|
| Define the interface | I wrote the module port list |
| Choose the architecture | I approved the Gray-code pointer approach |
| Set milestones & exit criteria | I asked for 5 milestones |
| Steer the conversation | "How will you handle CDC?" |
| Review & approve | I checked test results before committing |
| Decide when to commit | "Update md and commit" |

### The AI's Job
| Responsibility | Example |
|----------------|---------|
| Propose architectures | Gray-code pointers, sub-module decomposition |
| Write RTL | Full `async_fifo.sv` implementation |
| Write testbenches | 11 tests across 3 milestones |
| Debug failures | Self-diagnosed timeout, race condition, TCL error |
| Run tool flows | Vivado simulation, lint, CDC, synthesis |
| Maintain documentation | Design doc, README, commit messages |

### The Golden Rule
> **You are the architect. The AI is the senior engineer.**
> You make decisions. The AI implements them, tests them, and reports back.

---

<a id="tips"></a>
## 13. Tips for Using AI in RTL Design

### Before You Start
1. **Define your interface yourself.** The port list is a design decision —
   own it.
2. **Have a working build flow.** The AI needs `make all` (or equivalent) to
   verify its work. Set this up before starting.
3. **Use version control.** Commit after each milestone. The AI can run
   `git commit` for you.

### During the Session
4. **Start with "propose ideas," not "write code."** Get the architecture
   right first.
5. **Ask probing questions.** "How will you handle X?" forces the AI to
   think deeply.
6. **Keep a living design document.** Update it after every discussion.
7. **One milestone at a time.** Don't ask for everything at once.
8. **Let the AI run tests.** Tell it the command. Let it fail and self-correct.
9. **Review simulation output.** The AI reads the logs, but you should
   sanity-check key numbers.
10. **Commit frequently.** After each milestone, ask the AI to commit with
    a descriptive message.

### Common Pitfalls
11. **Don't blindly trust the first attempt.** Testbenches with concurrency
    often need 1-2 iterations.
12. **Watch for timeout issues.** If a test runs forever, the stimulus rate
    may be too slow for the test size.
13. **Check CDC reports yourself.** The AI reports what Vivado says, but you
    need to judge whether warnings are acceptable.
14. **Don't skip linting.** Vivado CDC caught the missing `ASYNC_REG` — this
    would have caused P&R issues in real silicon.

---

<a id="what-went-wrong"></a>
## 14. What Went Wrong (and How We Fixed It)

Transparency is important. Here's every issue that came up:

| # | Issue | Root Cause | How the AI Fixed It |
|---|-------|-----------|---------------------|
| 1 | Vivado not found | `vivado` not in PATH | Searched filesystem, found `/tools/Xilinx/Vivado/2023.2/`, sourced `settings64.sh` |
| 2 | Write-then-read timeout (MS2) | Writer pushes 2000 words into 1024-deep FIFO with no concurrent reader | Refactored to `fork/join` with concurrent writer and reader |
| 3 | Clock ratio test off-by-one (MS3) | Reader exit condition `!wr_done \|\| !empty` has race when reader is faster | Changed to `rcvd_count < N` — count-based exit |
| 4 | Randomized test timeout (MS3) | Per-cycle 50% random enable too slow for 3000 words | Rewrote using `write_one`/`read_one` with random idle gaps |
| 5 | Missing ASYNC_REG (MS4) | Synchronizer FFs had no ASYNC_REG attribute | Added `(* ASYNC_REG = "TRUE" *)` to all 4 sync registers |
| 6 | TCL error on methodology (MS4) | Used `get_property MESSAGE` instead of `DESCRIPTION` | Fixed property name |

**Total iterations to convergence: 3 extra runs across all milestones.**
That's remarkably efficient for a design that includes RTL, testbench,
and sign-off.

---

<a id="prompt-patterns"></a>
## 15. Prompt Patterns That Worked

Here are the exact prompts I used and why they were effective:

### Pattern 1: "Propose ideas" (Exploration)
> *"I would like to design an asynchronous fifo from scratch. The top interface
> is in this sv file. Could you propose some ideas?"*

**Why it works:** Opens a design discussion, not a coding task. Gets the AI
to think before it acts.

### Pattern 2: "How will you handle X?" (Probing)
> *"How will you handle wptr and rptr CDC?"*

**Why it works:** Forces the AI to explain the hardest part of the design in
detail. If the explanation is wrong, you catch it before implementation.

### Pattern 3: "Update md and commit" (Documentation checkpoint)
> *"Can you update the discussion in async_fifo.md file first?"*
> *"Please update md file and commit"*

**Why it works:** Creates a paper trail. The design doc is always up-to-date.
Git history shows the evolution of thinking.

### Pattern 4: "Make milestones" (Planning)
> *"Can you make some milestones for the implementation plan, update md and commit"*

**Why it works:** Breaks an overwhelming task into manageable chunks with
clear exit criteria.

### Pattern 5: "Let's do MS X" (Execution)
> *"Let's implement milestone 1. You can use `make all` to regression tests."*
> *"Let's do MS 3"*
> *"Can you impl milestone 4 with Vivado?"*

**Why it works:** Short and unambiguous. The AI knows exactly what to do
because the milestones were already defined and agreed upon.

### Pattern 6: "Update md and commit" (Checkpoint)
> *"Can you update md and commit"*

**Why it works:** Used after every milestone. Forces the AI to summarize what
was done, mark checkboxes, and create a clean commit. Keeps the project tidy.

### Pattern 7: Tool-specific guidance
> *"Can you impl milestone 4 with Vivado?"*

**Why it works:** Tells the AI which tool to use. Without this, it might have
tried Verilator or another tool. Be specific about your EDA environment.

---

<a id="final-thoughts"></a>
## 16. Final Thoughts

### What surprised me
- **The AI's self-debugging loop is powerful.** It runs tests, reads logs,
  diagnoses failures, and fixes them — usually in 1-2 iterations.
- **It understands Vivado TCL well.** CDC analysis, DRC, synthesis — it wrote
  working TCL scripts on the first try (minus a minor property name issue).
- **Documentation quality is excellent.** The design doc, README, and commit
  messages were all well-written without much editing.

### What I'd do differently next time
- **Add waveform dumping** to `run.tcl` for visual debug — useful when tests fail
- **Add assertion-based verification** (SVA) for protocol checks on full/empty
- **Explore the "extensions"** (almost-full, FWFT) as a follow-up session

### The numbers
| Metric | Value |
|--------|-------|
| Total prompts from me | ~12 |
| Total commits | 8 |
| RTL lines (async_fifo.sv) | 140 |
| Testbench lines (tb_top.sv) | 585 |
| Tests written | 11 |
| Tests passing | 11 |
| CDC unsafe crossings | 0 |
| DRC violations | 0 |
| Bug-fix iterations | 3 |

### The bottom line
> With ~12 prompts and about 30 minutes of wall-clock time, I went from an
> empty module shell to a fully verified, lint-clean, CDC-clean, synthesizable
> async FIFO with comprehensive documentation. The AI did 95% of the typing.
> I did 100% of the thinking.

---

## Git History (for reference)

```
00aedb7 (v1.0) docs: milestone 5 - final design doc, README, project wrap-up
5739936        rtl/infra: milestone 4 - lint, CDC, synthesis clean
26a16bb        tb: implement milestone 3 - stress & corner-case tests (11/11 pass)
5cc1b81        tb: implement milestone 2 - basic testbench (4/4 pass)
8adfea7        rtl: implement async_fifo milestone 1 - all sub-modules complete
c8bde56        docs: add implementation milestones to async_fifo.md
9df20f6        docs: add CDC pointer synchronization strategy to async_fifo.md
cf4fc84        check in files
746bb28        first commit
```

---

*Document written with the help of GitHub Copilot (Claude) — May 26, 2026*
