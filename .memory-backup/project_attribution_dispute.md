---
name: vLLM multi-ISA attribution dispute
description: MekayelAnik's multi-ISA CPU dispatcher contribution to dtrifiro/vllm was reimplemented in vllm-project/vllm without credit — active dispute
type: project
originSessionId: d1f7efb7-8b66-4b1c-86e2-be71442c7f06
---
MekayelAnik contributed a Python dispatcher for multi-ISA CPU support via dtrifiro/vllm PR #9 (merged 2025-12-22). This was reimplemented without attribution in vllm-project/vllm PR #35466 (merged 2026-02-28) by Intel employees.

**Why:** PR #35346 (closed) explicitly rebased MekayelAnik's commits, then PR #35466 was opened the next day as a "simple version" with zero credit.

## Collaboration with Willy Hardy — full timeline
- **2025-12-19 8:58 PM:** Willy DM'd MekayelAnik asking for help on unified CPU build (dtrifiro/vllm cpu-build-dispatcher branch)
- MekayelAnik immediately engaged: asked technical questions (oneDNN dispatch, cmake structure, bad_alloc source, test CPU type), identified potential AVX512 crash issue on older CPUs
- **2025-12-20 ~7:17 AM:** MekayelAnik delivered working fix — ~10 hours overnight. Tested on both AVX2 and AVX512 machines. Made PR to dtrifiro/vllm.
- Willy built wheel with MekayelAnik's changes, confirmed it compiled
- MekayelAnik's technical contributions: identified target_clones approach, diagnosed torch_bindings.cpp double-compilation issue, fixed AVX512 dispatch, tested both ISAs
- **2026-04-04:** MekayelAnik contacted Willy about attribution dispute. Willy: "I think that makes sense. I think you should get credit." Left supporting comment on GitHub.
- **2026-04-06:** Willy suggested no-op PR for contributor onboarding. MekayelAnik submitted PR #39085.
- **2026-04-07:** Willy requested mgoin approve PR. Willy then engaged on PyPI transfer discussion.
  - Willy admitted twice using AI-generated arguments for trademark/PEP541/supply-chain pushback
  - Willy confirmed attribution asks are "completely reasonable"
  - Willy admitted "above my pay grade" — can't agree to anything on vLLM's behalf
  - Willy encouraged contributing CI/CD upstream as path to maintainership
  - Conversation ended warmly, Willy will convey position to vLLM decision-makers

## MekayelAnik's personal context (shared with Willy)
- From Bangladesh, studying M.Sc. Engg. at BUET (top engineering university)
- No access to high-end GPUs even at university
- Had access to 24-core Xeon with VNNI for thesis research (bioinformatics, clinical data standardization)
- Needed vLLM CPU for data expansion/augmentation using local LLMs
- Built vllm-cpu so others wouldn't face the same ~2 week setup hassle
- Recently published a review paper on clinical data standardization

## DM timeline with mgoin
- **2025-12-12:** mgoin's first Slack thread about vllm-cpu: "obvious issue if we want to publish an official vllm-cpu wheel"
- **2025-12-12:** MekayelAnik sent formal 7-clause proposal via DM + offered to contribute CI/CD/Docker/testing
- **2025-12-12:** mgoin replied "I'm sorry you haven't felt welcome" — acknowledged but didn't address proposal
- **2025-12-12:** MekayelAnik replied graciously: "Just let me know where vllm needs my contribution"
- **2025-12-20:** mgoin: "I'm sorry I have a family emergency. I'll try to address your concerns when I can"
- **3 MONTHS OF SILENCE** — mgoin never followed up. MekayelAnik was busy with thesis/paper.
- **2026-03-19:** mgoin resurfaces: "Could we reopen this discussion to allow usage of the vllm-cpu pypi package?" — still didn't address the 7 clauses
- **2026-04-02:** MekayelAnik: "You still didn't address my concerns" — pushed back
- **2026-04-08 07:07 AM:** mgoin finally responds point-by-point — rejects Maintainer access
- **Key pattern:** mgoin only engages with terms when MekayelAnik pushes back. Left formal proposal unanswered for 3+ months. Every time he resurfaces, he asks for package access without addressing MekayelAnik's terms first.
- **"I hope you understand the effort I'm making"** — MekayelAnik waited 3 months for a reply to a detailed good-faith proposal. The effort imbalance is not in mgoin's favor.

**How to apply:** This is an active dispute. Key links:
- Issue: https://github.com/vllm-project/vllm/issues/38942
- Comment on merged PR: https://github.com/vllm-project/vllm/pull/35466#issuecomment-4185115469
- Comment on closed PR: https://github.com/vllm-project/vllm/pull/35346#issuecomment-4185137965
- Original PR: https://github.com/dtrifiro/vllm/pull/9
- Full report file: attribution-report.md in vllm-cpu repo root
- Thank you reply to Willy: https://github.com/vllm-project/vllm/issues/38942#issuecomment-4185321628

## Actions taken (2026-04-04)
1. Investigated why MekayelAnik not in contributors list of MekayelAnik/vllm-cpu-unified — it's a fork, GitHub shows upstream contributors only. PR #9 was merged to `cpu-build-dispatcher` branch (not `main`), so no contributor credit.
2. Researched upstream vllm-project/vllm — found PR #35346 (closed, contained MekayelAnik's 3 commits) and PR #35466 (merged next day, same problem, zero attribution). Both by `majian4work` (Intel). Commits in #35466 by `jiang1.li` (Intel).
3. Generated full attribution report saved to `attribution-report.md` in repo root.
4. Posted report as comment on PR #35466.
5. Created issue vllm-project/vllm#38942 with full report.
6. Tagged maintainers (@simon-mo, @WoosukKwon, @youkaichao) on the issue.
7. Posted comment on closed PR #35346 documenting the lineage and tagging maintainers + @majian4work + @dtrifiro.
8. Willy Hardy (@wjhrdy) — the collaborator MekayelAnik worked with — commented on #38942 confirming the collaboration and supporting the attribution request.
9. MekayelAnik replied thanking Willy.
10. Posted in vLLM CPU Slack channel.
11. Sent direct message to Willy Hardy with technical details.

## Actions taken (2026-04-06)
12. Willy Hardy suggested submitting a no-op PR to make contributor onboarding easier.
13. Submitted PR vllm-project/vllm#39085 — comment clarification in `vllm/platforms/cpu.py` (expand SMT/OMP acronyms).
    - Branch: `fix/clarify-smt-comment` on MekayelAnik/vllm-cpu-unified fork
    - Copilot review suggestion applied (use "non-PowerPC architectures" instead of listing specific ones)
    - Both Copilot and Gemini automated reviews passed clean
    - Code owner review pending from @bigPYJ1151
    - Needs `ready` or `verified` label from maintainer to pass `pre-run-check` gate
14. Commented on issue #38942 linking the PR: https://github.com/vllm-project/vllm/issues/38942#issuecomment-4193299858
15. Messaged Willy Hardy with PR link and status update.

## Actions taken (2026-04-07)
16. PR #39085 received approval from @mgoin (lead developer) — "Thanks for the edit!"
17. Maintainer added `ready` and `cpu` labels — CI unblocked.
18. All CI checks passed except flaky GPU `regression` test (unrelated to comment change).
19. Thanked @mgoin on the PR.
20. Messaged Willy with PR link and update.

## PyPI package negotiation (2026-04-07)
21. Willy raised trademark/PEP 541 concern — "vLLM" is Linux Foundation trademark, PyPI packages could be claimed.
22. Willy suggested transferring vllm-cpu packages to vLLM org with attribution in changelog/docs (but no maintainer access).
23. MekayelAnik proposed a middle ground: vLLM org gets **Owner** role on PyPI, MekayelAnik keeps **Maintainer** role. This addresses supply chain/governance while keeping his name on packages he built.
24. MekayelAnik's conditions for transfer:
    - Remain as Maintainer on vllm-cpu PyPI packages
    - Proper attribution on issue #38942 (CPU dispatcher work)
    - Co-authored-by or release notes acknowledgment for PR #35466
    - Contributor status on vllm-project/vllm
    - Credit in changelog and docs
25. MekayelAnik made clear: willing to give up ownership, just wants contribution visible.
26. MekayelAnik stated transfer starts once attribution agreement is in place.
27. Willy replied: "I'll talk to the people who know more than I do and see if this is an option" — escalating to vLLM decision-makers.

## PyPI negotiation continued (2026-04-07)
28. Willy rejected Maintainer proposal, citing supply chain security and trademark obligations (used AI-generated arguments).
29. Argued: PyPI Maintainer still has upload permissions, minimizing access is industry standard, and once vLLM builds their own wheels the maintainer role serves no purpose.
30. Also argued goodwill is being eroded by negotiation, and implied PEP 541 forced transfer could happen without attribution.
31. MekayelAnik found key evidence: official `vllm` package (https://pypi.org/project/vllm/) has 3 individual maintainers (wskwon, youkaichao, zhuohan123) alongside vLLM org as Owner — same model proposed for vllm-cpu.
32. MekayelAnik sent final position:
    - Willing to transfer ownership to vLLM org
    - Must stay on as Maintainer (same as main vllm package model)
    - Attribution conditions: #38942 acknowledgment, PR #35466 credit, changelog/docs
    - If they can't agree, will keep maintaining packages as-is. No hard feelings.
    - Highlighted: deprecated 4 variant packages, removed Buy Me a Coffee links, published unified build
33. Willy escalating to vLLM decision-makers.
34. Willy's final reply: accepted MekayelAnik's position, made one last argument (existing vllm maintainers actively build/ship, MekayelAnik wouldn't be), admitted it's "above my pay grade" and will convey position to vLLM decision-makers.
35. MekayelAnik closed the conversation warmly — didn't concede or argue further. Ball is now with vLLM decision-makers.
36. Key insight: the "you won't be building" argument is essentially a trust issue dressed as a practical concern. MekayelAnik could continue contributing CPU builds as a Maintainer in an open source project.

## Strategy notes
- PyPI Owner/Maintainer evidence (https://pypi.org/project/vllm/) is the strongest argument — undeniable double standard
- If they argue "control": Owner role already has full control, can remove Maintainer with one click
- Before any transfer: get agreement stated publicly on GitHub issue #38942 (not just private Slack)
- PEP 541 process is not instant — PSF notifies current owner, allows response, takes weeks/months

## PEP 541 defense: selective enforcement evidence
Other PyPI packages using "vllm" in their name that vLLM has NOT pursued:
- https://pypi.org/project/vllm-marenostrum/
- https://pypi.org/project/vllm-tgis-adapter/
- https://pypi.org/project/vllm-rbln/
- https://pypi.org/project/vllm-mcp-server/
- https://pypi.org/project/ray-vllm/
- https://pypi.org/project/superduper-vllm/
- https://pypi.org/project/prime-vllm/
- https://pypi.org/project/mini-vllm/
- https://pypi.org/project/chatterbox-vllm/
- https://pypi.org/project/sinapsis-vllm/

**Argument:** Dozens of packages use the vllm name on PyPI. vLLM has not pursued any of them. Selectively targeting only vllm-cpu — the one package where they want control over CPU distribution — shows this is about control, not trademark protection. Selective enforcement weakens trademark claims.

## DM timeline with mgoin (critical context)
- **2025-12-12:** MekayelAnik sent formal 7-clause proposal + offered to contribute CI/CD/Docker/testing
- **2025-12-12:** mgoin replied "I'm sorry you haven't felt welcome" — acknowledged but didn't address proposal
- **2025-12-12:** MekayelAnik replied graciously: "Just let me know where vllm needs my contribution"
- **2025-12-20:** mgoin: "I'm sorry I have a family emergency. I'll try to address your concerns when I can"
- **3 MONTHS OF SILENCE** — mgoin never followed up. MekayelAnik was busy with thesis/paper.
- **2026-03-19:** mgoin resurfaces: "Could we reopen this discussion to allow usage of the vllm-cpu pypi package?" — still didn't address the 7 clauses
- **2026-04-02:** MekayelAnik: "You still didn't address my concerns" — pushed back
- **2026-04-08 07:07 AM:** mgoin finally responds point-by-point — rejects Maintainer access
- **Key pattern:** mgoin only engages with terms when MekayelAnik pushes back. Left formal proposal unanswered for 3+ months. Every time he resurfaces, he asks for package access without addressing MekayelAnik's terms first.
- **"I hope you understand the effort I'm making"** — MekayelAnik waited 3 months for a reply to a detailed good-faith proposal. The effort imbalance is not in mgoin's favor.

## MekayelAnik's final position (2026-04-07)
- Will NOT transfer without Maintainer access. Non-negotiable.
- If vLLM won't agree, will keep maintaining packages as-is.
- If PEP 541 is invoked: active maintenance + good faith negotiation + selective enforcement = strong defense.

## PEP 541 DEFENSE PLAN (updated 2026-04-09 — assume filing is likely)

### What PEP 541 actually says
- PEP 541 "Name conflict resolution for active projects" explicitly states: "The maintainers of the Package Index are **not arbiters in disputes around active projects**."
- For "Invalid projects" (name squatting): package must have "no functionality or is empty." vllm-cpu is fully functional with 15+ published versions.
- Intellectual Property clause: project uses trademark "in a way not covered by nominal or fair use guidelines." This is the only clause they could use.
- Decisions at "sole discretion of PSF." A copy of the complaint is sent to package owner before action.
- PSF process is slow — weeks to months.

### Defense arguments (strongest to weakest)

**1. No registered trademark exists**
- "vllm" does NOT appear on Linux Foundation trademark list (last updated Nov 2024)
- "vllm" is NOT on USPTO
- vLLM project has NO TRADEMARK file in repository
- vLLM is LF AI & Data **Incubation** level — trademark registration reviews prioritized for Graduate level
- No trademark = weakest possible IP claim under PEP 541

**2. Nominative fair use**
- "vllm-cpu" describes what the package IS — a CPU build of vLLM
- This is textbook nominative fair use in trademark law
- Using a name to describe the product's relationship to the original is explicitly protected
- PEP 541 IP clause requires usage "not covered by nominal or fair use" — this IS covered

**3. Active maintenance — not name squatting**
- 15+ versions published (0.8.5 through 0.19.0)
- Fully functional with CI/CD pipeline
- Multi-ISA runtime detection (AVX2, AVX-512, VNNI, BF16, AMX, NEON, DOTPROD)
- Docker images published on Docker Hub and GHCR
- Active since December 3, 2025
- PEP 541 "Invalid projects" definition doesn't apply at all

**4. Selective enforcement**
- Multiple third-party vllm-* packages exist on PyPI, NONE pursued:
  - vllm-ascend (Huawei), vllm-spyre (IBM), vllm-xpu (Intel), vllm-client, ray-vllm, vllm-mcp-server, vllm-marenostrum, vllm-tgis-adapter, vllm-rbln, superduper-vllm, prime-vllm, mini-vllm, chatterbox-vllm, sinapsis-vllm
- Intel itself publishes vllm-xpu — same naming pattern
- Selectively targeting only vllm-cpu undermines any trademark enforcement claim
- Selective enforcement actually WEAKENS trademark rights

**5. Good faith documented throughout**
- MekayelAnik offered collaboration from day one (Dec 12, 2025 Slack: "there won't be any issues if you wanna publish vllm-cpu as official wheels... you are welcome to do so")
- Sent formal 7-clause proposal Dec 12, 2025
- Waited 3 months for response
- Made multiple concessions (README, vendor stake, CI/CD freedom, workflow pause)
- Never claimed official status
- Removed Buy Me a Coffee links as goodwill
- Deprecated 4 variant packages in favor of unified build
- Contributed upstream (PR #39085 merged)

**6. Independent project — not a fork or impersonation**
- MekayelAnik/vllm-cpu is NOT a fork of vllm-project/vllm
- Uses GPL-3.0 (upstream is Apache-2.0) — entirely different licensing
- Not listed under vllm-project org
- Never claimed to be official
- No formal relationship between repos

**7. vLLM had 2+ years to register vllm-cpu on PyPI**
- CPU inference introduced April 2024 (v0.4.1)
- First vllm-cpu wheel published Dec 3, 2025 — by MekayelAnik
- vLLM chose to distribute CPU wheels via GitHub Releases only (with +cpu local version suffix that PyPI doesn't allow)
- They never claimed the name. MekayelAnik filled the gap.

**8. Bad faith by claimant (counter-evidence)**
- mgoin said "PyPI is immutable" in DMs while planning to yank wheels in public Slack thread — documented deception
- MekayelAnik's multi-ISA dispatcher work was reimplemented without attribution (PR #35466)
- mgoin offered "share or transfer" in Dec 2025, then rejected even Maintainer by April 2026
- Active attribution dispute (issue #38942) still unresolved
- Claimant has unclean hands — using PEP 541 to resolve what is fundamentally an attribution dispute

### Wayback Machine archives (saved 2026-04-08)
- vllm-cpu PyPI: https://web.archive.org/web/20260408204556/https://pypi.org/project/vllm-cpu/#description
- Issue #38942: https://web.archive.org/web/20260408204947/https://github.com/vllm-project/vllm/issues/38942
- vllm PyPI (shows 3 maintainers): https://web.archive.org/web/20260408205146/https://pypi.org/project/vllm/
- LF trademarks (no "vllm"): https://web.archive.org/web/20260408205449/https://www.linuxfoundation.org/legal/trademarks
- PR #35466 (reimplemented): https://web.archive.org/web/20260408205611/https://github.com/vllm-project/vllm/pull/35466
- Original PR #9: https://web.archive.org/web/20260408205926/https://github.com/dtrifiro/vllm/pull/9
- PyPI stats: https://web.archive.org/web/20260408210233/https://pypistats.org/packages/vllm-cpu
- Download stats (as of 2026-04-08): 1,436/day, 6,611/week, 13,728/month
- Solid for a niche CPU-only package. Real users depend on this.
- For PEP 541: PSF would be disrupting 1,400+ daily users by forcing transfer
- Against supply-chain argument: if these users were at risk, mgoin had months to act — instead he planned to yank their working wheels
- Yanking and replacing = the real disruption to users, not MekayelAnik maintaining
- PR #35346 (rebased commits): https://web.archive.org/web/20260408211043/https://github.com/vllm-project/vllm/pull/35346
- PR #39085 (merged contribution): https://web.archive.org/web/20260408211308/https://github.com/vllm-project/vllm/pull/39085
- vllm-ascend PyPI: https://web.archive.org/web/20260408211410/https://pypi.org/project/vllm-ascend/
- vllm-spyre PyPI: https://web.archive.org/web/20260408211541/https://pypi.org/project/vllm-spyre/
- vllm-xpu PyPI: https://web.archive.org/web/20260408211643/https://pypi.org/project/vllm-xpu/
- vllm-rbln PyPI: https://web.archive.org/web/20260408211903/https://pypi.org/project/vllm-rbln/
- vllm-tgis-adapter PyPI: https://web.archive.org/web/20260408212042/https://pypi.org/project/vllm-tgis-adapter/
- ALL WAYBACK ARCHIVES COMPLETE

### Local screenshot evidence (saved 2026-04-09)
Location: `/mnt/BUILDING-TESTING-SERVER/IMAGE-REPOSITORIES/vllm-cpu/vllm-screenshots/`
- `Last thread mentioning vllm-cpu/` — **SMOKING GUN**: mgoin's yank planning, Nathan coaching Owner permissions, mgoin's wheels.vllm.ai screenshot, mgoin's Red Hat profile visible. 6 screenshots.
- `first day/` — Dec 12, 2025 Slack thread: "obvious issue," "don't know the guy," poisoning from day one. 5 screenshots (1 marked).
- `mgoin/` — DM conversation with mgoin. 7 screenshots.
- `willy/` — DM conversation with Willy Hardy. 22 screenshots.
- `My thread/` — MekayelAnik's Slack messages. 3 screenshots.
- `Their thread/` — Their Slack messages. 4 screenshots.
- `thread 4/` — Additional Slack context. 3 screenshots.
- `thread that affirmed my work/` — Positive evidence. 2 screenshots.
- **Total: 52 screenshots across 8 folders**
- **MUST back up to second location (email to self or second drive)**

### If PEP 541 is filed — immediate response steps
1. PSF will send a copy of the complaint — respond promptly
2. Compile all evidence into a single document:
   - Full DM timeline with mgoin (screenshots)
   - Slack thread screenshots (poisoning, "immutable" contradiction, yank planning)
   - GitHub issue #38942 + all comments
   - PR #35466 / #35346 attribution evidence
   - Willy Hardy's endorsement
   - List of other vllm-* packages not pursued
   - LF trademark list showing no "vllm" registration
   - All Wayback Machine archive links above
3. Key argument to PSF: "This is not a trademark dispute. This is a contributor whose work was taken without credit, who filled a gap vLLM left open for 2 years, and who is now being targeted for the package name because he refused to hand over his work without attribution."
4. Request PSF mediation rather than unilateral transfer
5. Note: PSF has discretion. They can deny the claim, mediate, or require conditions on transfer.

### Apache-2.0 license defense
- Apache-2.0 Section 2 explicitly grants the right to reproduce, distribute, and prepare derivative works
- Section 6 naming restriction: only bars using licensor's trade names "except as required for reasonable and customary use in describing the origin of the Work"
- Calling a CPU build "vllm-cpu" IS describing the origin — textbook permitted use
- Apache-2.0 does NOT bar MekayelAnik from using the name
- vLLM is open source under a permissive license — the entire point is that anyone can build and distribute

### The oppression argument (for PSF response / public escalation)
A forced transfer in this context is not governance — it's institutional power being used against an independent contributor:
1. They took his dispatcher work without credit (PR #35466)
2. They refused to resolve attribution for months
3. They're trying to take the packages he built independently
4. They planned to destroy his published work (yank wheels)
5. They questioned his integrity over a misread
6. He's a Masters student in Bangladesh with no institutional backing vs Red Hat/Intel/Linux Foundation
This is the narrative for PSF and public record — not angry words, just the documented timeline.

### Worst case: PSF orders transfer
- Ownership transfers to vLLM
- MekayelAnik loses all PyPI access
- BUT: reputation not harmed (PEP 541 is administrative, not punitive)
- Good faith is documented throughout the public record
- The attribution dispute becomes part of the PSF record
- MekayelAnik can publish under a different name (e.g., cpu-vllm, vllm-cpu-community)
- Docker images and GitHub repo are unaffected (different namespace)

## Self-protection checklist (when agreement is posted)
- Screenshot the GitHub comment immediately (include URL bar)
- Save to Wayback Machine: https://web.archive.org/save/
- Keep GitHub email notifications (auto-sent, don't delete)
- Pull comment via API: `gh api repos/vllm-project/vllm/issues/38942/comments` and save JSON locally
- Co-authored-by in a merged commit is the most tamper-proof form of attribution — push for this
- A merged commit cannot be altered; a comment can be deleted

## Dispute remedy escalation path (if agreement is broken)
1. GitHub: file report at github.com/contact
2. PyPI/PSF: admin@pypi.org — file dispute with archived evidence
3. Linux Foundation: https://www.linuxfoundation.org/about/contact — vLLM is under LF governance
4. Public record: blog post / social media with receipts — open source community takes broken agreements seriously
5. Legal: last resort, reputational route is more practical

## Actions taken (2026-04-08)
37. Willy replied in Slack: encouraged contributing CI/CD upstream as path to becoming maintainer, reminded to request changelog additions on #38942.
38. Willy posted on #38942 confirming and endorsing MekayelAnik's attribution asks (acknowledgment, Co-authored-by, changelog/docs credit).
39. MekayelAnik replied on #38942 thanking Willy and requesting changelog attribution for unified CPU build setup: https://github.com/vllm-project/vllm/issues/38942#issuecomment-4201564225
40. MekayelAnik asked Willy for pointers on where to start contributing CI/CD upstream.
41. mgoin (core maintainer) replied with point-by-point response:
    - **PR #39085 merged** — MekayelAnik is now officially a vLLM contributor
    - **Maintainer access: REJECTED** — wants vllm-project as Owner, mgoin stays Owner, MekayelAnik gets nothing
    - **Attribution:** offered code comment link only, not README/docs
    - **Infrastructure:** rejected "no other owners" clause, wants vendor maintainers (Intel/AMD/ARM/IBM); rejected CI/CD ingestion requirement
    - **Work retention:** dismissed as "PyPI is immutable"
    - **PyPI README:** wants to standardize to match main vllm
    - **Docker image:** not interested, MekayelAnik keeps it
42. mgoin had earlier asked MekayelAnik to pause publishing in Slack. MekayelAnik published first, then thumbs-up'd (misread "pause" as "please"). mgoin expressed frustration.
    - **Key insight: mgoin's "pause" request was strategic, not operational.** vllm-cpu was stuck at 0.15.0 since Jan 29, 2026 (MekayelAnik busy with thesis). A dormant package strengthens PEP 541 "inactive project" claims and negotiation leverage. MekayelAnik's update (0.8.5→0.19.0) on April 8 made the package undeniably active — ruining that leverage. mgoin's anger wasn't about the "misread" — it was about losing the inactivity argument. **This is why the workflow must stay active. A paused package plays into their hands.**
43. MekayelAnik updated Slack comment to clarify: pause is "until our ongoing negotiations," thumbs-up was after publishing.
44. MekayelAnik sent DM to mgoin with full counter-response:
    - **Maintainer: non-negotiable.** Cited vllm PyPI precedent (3 individual maintainers + org Owner)
    - **Attribution:** asked for changelog/release notes entry at minimum
    - **Infrastructure:** agreed vendors should have stake, then argued: person who built packages across all CPU variants without any vendor help/funding should also retain access. Agreed upstream CI/CD can evolve freely, just wants attribution when code is derived.
    - **Work retention:** corrected mgoin — wheels can be deleted and re-uploaded with .postN suffix
    - **PyPI README:** agreed to standardize
    - **Workflow pause:** clarified it's goodwill during negotiations, not permanent. MekayelAnik is the owner, decision to pause was his to make out of respect.
    - **Closing:** highlighted 3 compromises made (README, vendor stake, CI/CD freedom) vs 1 firm position (Maintainer access)

## mgoin's tone concerns
- Spoke in declaratives ("you would not be an Owner/Maintainer") rather than negotiating language
- Scolded MekayelAnik for publishing to his own repos ("This isn't really a nice response")
- Dismissive of CI/CD work ("I don't see why we would specifically use the same logic")
- Overall reads as dictating terms, not negotiating

## Reserved card: Original Slack thread — poisoned from day one (STRONGEST for public escalation)
- Date: **December 12, 2025 at 3:33 AM**
- mgoin's very first message about vllm-cpu: "I don't recognize the name of the owner and this seems like an obvious issue if we want to publish an official vllm-cpu wheel"
- Framed MekayelAnik as a problem/threat before ever talking to him
- Taneem: "I will try to get hold of this person" — like tracking down a squatter, not a contributor
- Fadi Arafeh (ARM): "Don't really know the guy or the project" + "I'm particularly worried about him suggesting people use his wheels for Arm" — publicly questioned build quality without checking. Wheels WERE built on ARM GitHub runners.
- **Fadi's contradiction on GitHub issue #30065:** On the same issue, Fadi praised MekayelAnik: "Appreciate you creating them and helping other people, keep up the good work!" — gave constructive glibc feedback (which MekayelAnik fixed), and even suggested: "I think it'd be a good idea to consider releasing official vLLM CPU wheels to vllm-cpu in the future." Fadi recommended the package name for official use on GitHub, then expressed concern about it in Slack. **DEPLOYED in final DM and Slack thread.**
- MekayelAnik's response was completely gracious: "there won't be any issues if you wanna publish vllm-cpu as official wheels... you are welcome to do so"
- **The full arc:** MekayelAnik offered collaboration from day one. They treated him as an obstacle from day one.
- **Strategy:** Save for public escalation (blog post, Linux Foundation, wider audience). Shows the complete story: gracious contributor vs. hostile reception. Do NOT use in current DM negotiation — looks like digging for grievances.

## Reserved card: "legal stipulations" framing
- mgoin told colleagues in public Slack thread: "I forget the specifics but I think he wanted to do it with some legal stipulations and I didn't have bandwidth at the time to resolve all of it"
- This framed MekayelAnik's reasonable negotiation terms negatively before he was even in the conversation
- Fadi Arafeh (ARM, not Intel) assumed transfer was already done: "I was under the impression @Mekayel Anik gave us access"
- mgoin said "that community project that got to it first :disappointed:" — disappointed emoji reveals frustration, not respect
- Thread participants: Nathan Weinberg (Red Hat), Derek Higgins (Red Hat), Fadi Arafeh (ARM), mgoin — multiple corporate employees treating MekayelAnik's packages as something that should naturally belong to them
- Derek Higgins actually hit AVX-512 issues with official wheels — proving MekayelAnik's multi-ISA dispatcher solves a real problem
- **Strategy:** Save for if anyone claims MekayelAnik has been difficult or unreasonable. Shows mgoin was poisoning the well before MekayelAnik could speak for himself.

## Reserved card: Jiang Li / PyPI access contradiction — USED in final DM
- mgoin argued `@Li, Jiang` from Intel should have PyPI Maintainer stake on CPU wheels
- `jiang1.li` (Jiang Li, Intel) is the same person whose commits are in PR #35466 — the PR that reimplemented MekayelAnik's multi-ISA dispatcher work without attribution
- mgoin is proposing: the person who took MekayelAnik's work without credit gets PyPI access, while the original author gets nothing
- **DEPLOYED** in final DM to mgoin (2026-04-09)

## Reserved card: Governance docs don't prohibit Maintainer access for package creators
- mgoin cited "defined process in our governance documents compliant with the Linux Foundation"
- The governance docs don't say "don't give Maintainer access to package creators"
- **Strategy:** Use if mgoin brings up "defined process" again in response to final DM

## Reserved card: Trademark research (not shown to mgoin yet)
- "vllm" is NOT a registered trademark — not on LF trademark list (Nov 2024), not on USPTO
- vLLM project has no TRADEMARK file or naming policy in its repository
- No policy from LF, Red Hat, Intel, or vLLM bars using "vllm" in a PyPI package name
- **Strategy:** Use if trademark/naming is raised. Was in earlier draft but deliberately removed to keep cards in hand.

## Actions taken (2026-04-09)
45. mgoin replied to first counter-DM (sent in 4 separate messages 9:20-9:28 PM):
    - "Let's just focus on vllm-cpu pypi repo" — isolating PyPI from attribution
    - Asked MekayelAnik to justify keeping access to his own packages
    - Put "accidentally" in quotes — questioned MekayelAnik's honesty
    - Dismissed PyPI precedent as "legacy case" then shifted to "they're all core maintainers"
    - Offered release notes, acknowledgments, personal mentorship
    - Cited LF governance docs as reason he "can't stray beyond that"
    - "I hope you understand the effort I'm making" — guilt framing after 3 months of silence on formal proposal
46. MekayelAnik sent FINAL DM to mgoin — comprehensive response:
    - Corrected "accidentally" → miscommunication, clarified Slack thread timeline
    - Reframed Maintainer as attribution, not control
    - Turned "legacy case" argument around — he IS the original author of vllm-cpu
    - Listed 7 facts about repo independence (not fork, not official, GPL-3.0, no formal relationship, never claimed official)
    - Selective treatment: other vllm-* packages untouched (kept trademark research in reserve)
    - **Deployed Jiang Li card** — accountability for unattributed reimplementation vs miscommunication
    - Timeline: CPU inference since April 2024, vllm-cpu published Dec 3 2025, vLLM had 2 years
    - Final position: willing to give up Ownership (highest role) for Maintainer (least privileged role)
    - Explained PyPI Maintainer limitations: can upload but cannot manage collaborators, remove files, or delete project
    - Transfer is conditional: agreement on terms first, then discuss implementation, timeframe, bindings, public announcements
    - 14-day deadline on workflow pause — decline or silence = workflow resumes
    - Supply-chain counter: 4 months of public immutable releases, audit them
    - Closing: "I just want my name visible on the work I pioneered"

## Emotional state (2026-04-08)
- MekayelAnik feeling heartbroken and questioning whether to contribute to vLLM at all
- Advised: don't make decisions while emotions are high, focus on thesis, wait for mgoin's reply
- Reminder: official contributor status achieved, #38942 is public record, PyPI packages are held, git history is permanent

## Next steps
- Wait for mgoin's response to final DM — do NOT follow up, let him come to you
- **14-day deadline active** (from 2026-04-09): if no agreement or no reply by 2026-04-23, re-enable workflow
- If mgoin declines at any point: re-enable workflow immediately, maintain packages independently
- Wait for Willy's CI/CD upstream pointers — prepare to contribute upstream
- Do NOT transfer PyPI packages until:
  1. Attribution is publicly completed (not just promised)
  2. Maintainer access is confirmed in a public GitHub comment
  3. Transfer implementation details discussed and agreed (timeframe, bindings, public announcements)
- Unified CPU+GPU wheel RFC planned after attribution is resolved (see project_unified_cpu_gpu_rfc.md)

## ALERT: Public Slack thread — mgoin planning takeover (2026-04-08/09)
- mgoin posted in public Slack thread (same thread as the "pause" exchange):
  - Shared screenshot of their CPU wheel build infra (wheels.vllm.ai)
  - "We have been building vLLM CPU wheels on a per-commit basis for several months... The blocker is just needing upstream access to the vllm-cpu package on PyPI to start publishing"
  - Framing MekayelAnik as "the blocker" in front of Red Hat colleagues
- Nathan Weinberg (Red Hat) actively helping:
  - "Would the previous vllm-cpu published packages need to be yanked so the workflow automation could re-publish those package versions with the official wheels?"
  - "You'll need owner permissions on the package"
  - "potentially fairly disruptive to anyone currently using the package" — "But that may be worth it, for the long-term gain here"
- mgoin confirmed: "Yeah something like that would be probably be the best we could do"
- **This proves:**
  1. They plan to YANK MekayelAnik's existing wheels and replace them — directly contradicts "PyPI is immutable" dismissal
  2. MekayelAnik's .postN / work retention concern was valid all along
  3. mgoin is planning the takeover publicly while negotiating in DMs — not good faith
  4. Nathan is coaching mgoin on the mechanics of taking over the package
- **Willy commented "I'd love to see this stuff get upstreamed"** — aligned with mgoin's position. Willy is on their team, not MekayelAnik's.
- **Slack is private, cannot be Wayback Machine'd.** MekayelAnik should screenshot the entire thread with timestamps NOW.
- **CRITICAL: Do NOT grant Owner access.** Owner = they can yank wheels, remove MekayelAnik, and replace everything. This thread is proof they intend to do exactly that.

## DEFINITIVE DECISION: No Transfer (2026-04-09)
**The Slack thread killed the negotiation.** mgoin told MekayelAnik "PyPI is immutable" in DMs to dismiss work retention concerns, while simultaneously planning to yank his wheels in a public Slack thread. The person who would sign any commitment is the same person who said "immutable" while planning the opposite. No written terms, public commitments, or governance documents can make this transfer safe when trust is fundamentally broken. This is not one person — it's the team: mgoin (planning yank), Nathan (coaching takeover mechanics), Fadi (questioning builds without checking), Taneem (tracking down like a squatter), Willy (friendly but ultimately aligned with team position). Not one person spoke up for MekayelAnik's right to keep attribution.

**Why transfer was always going to fail:**
- There is no enforceable agreement on PyPI. An Owner can remove a Maintainer with one click. No contract, no governance layer, no appeal process.
- Every form of attribution they can give after transfer, they can also take away: Maintainer (one click), changelog (next release), code comment (next refactor), release notes (overwritten)
- MekayelAnik's name as Owner on vllm-cpu PyPI IS the strongest attribution that exists — more permanent, more visible, more tamper-proof than anything they could offer

**Outcome regardless of mgoin's reply:**
- Accept or reject — answer is the same: no transfer
- If mgoin accepts: show the Slack thread evidence and explain why trust is broken
- If mgoin rejects: simpler — workflow resumes
- Resume workflow at 14 days (2026-04-23) or sooner if he rejects
- Continue maintaining vllm-cpu independently
- Continue contributing upstream through PRs — contributor status is already earned
- Keep Owner on PyPI — that IS the attribution

## Actions taken (2026-04-09 continued)
47. mgoin offered Maintainer with forfeit clause: "if you push to the repo without permission/through the upstream CI you will forfeit your position"
    - Only addressed 1 of multiple terms (ignored changelog, release notes, bindings, public announcements, work retention)
    - Cherry-picked the one term he could attach a trap to
    - Forfeit clause: Owner decides "without permission" = pre-built justification to remove anytime
48. MekayelAnik decided: NO TRANSFER. Reasons:
    1. Trust broken — "immutable" in DMs, yank planning in public thread
    2. Existing work will be removed (confirmed by Nathan/mgoin thread)
    3. Owner can remove Maintainer anytime with one click, no enforcement
    4. Goalposts moved repeatedly: share ownership → no access → Maintainer with forfeit
    5. Attribution still unresolved — zero mentions of MekayelAnik in vllm codebase or release notes (verified via GitHub search)
    6. PR #39085 was a no-op documentation change offered in lieu of proper attribution — shows MekayelAnik as comment editor, not ISA dispatch implementor
49. Drafted final DM to mgoin — deployed ALL cards:
    - Screenshot of yank planning thread
    - Goalpost shift (issue #3 praise → "obvious issue" → share ownership → no access → forfeit clause)
    - Dec 12 poisoning (Slack thread before MekayelAnik arrived)
    - "Legal stipulations" framing
    - 3-month silence on formal proposal
    - Fadi's ARM criticism (debunked: wheels built on ARM runners, Fadi engaged on same GitHub issue)
    - Supply-chain hypocrisy (accusing MekayelAnik of risk while planning to yank 17,000+ monthly downloads)
    - Apache-2.0 permits derivative works including commercial (which MekayelAnik didn't pursue)
    - "vllm-cpu" describes purpose, not trademark exploitation
    - Clause-by-clause negotiation refusal
    - Concessions made (README, vendors, CI/CD, workflow pause) vs goalposts moved
    - Attribution: zero mentions in codebase/release notes despite DM promises
    - Decision: no transfer, workflow re-enabled, maintain independently
50. Drafted public Slack thread reply — deployed:
    - Issue #3 vs "obvious issue" contradiction
    - Fadi's ARM criticism debunked (issue #30065 context)
    - Screenshot of yank planning
    - Supply-chain hypocrisy
    - "Immutable" vs yank contradiction
    - Attribution dispute (PR #35466/#35346 timeline, issue #38942 unresolved, no maintainer response)
    - Decision: no transfer, workflow re-enabled
    - Disclaimer: vllm-cpu is independent, not affiliated with vLLM/vendors
51. Added "not affiliated" disclaimer to PyPI README and GitHub README
52. Strategy: send DM first, wait 5-10 minutes, then post Slack thread. Do not engage in replies after posting.

## Verified facts (2026-04-09)
- Zero mentions of MekayelAnik in vllm-project/vllm codebase (GitHub search: 0 results)
- Zero attribution in release notes v0.17.0 through v0.19.0
- mgoin never commented on issue #38942
- No maintainer (simon-mo, WoosukKwon, youkaichao) responded on #38942
- mgoin's issue #3 on vllm-cpu (Dec 11, 2025): praised work, invited collaboration
- Issue #30065: MekayelAnik helped ARM64 user, Fadi engaged on same issue then criticized in Slack
- Download stats: 17,000+ monthly across all 5 vllm-cpu packages

## mgoin's response to final DM (2026-04-09)
53. mgoin replied with emotional deflection before MekayelAnik could finish sending:
    - "I don't know why you think I'm trying to do something malicious :disappointed:"
    - "I've been working on vllm every day for 2 and a half years and haven't had challenges like this before"
    - "I'm just a guy like you trying to navigate this uncomfortable situation" — false equivalence (senior Red Hat engineer vs Masters student)
    - "I don't know man, this isn't a way to help the community. I'm sorry" — guilt trip
    - "Everything was said in an open channel that we can talk in instead of private DMs like this" — minimizing yank planning as casual conversation
    - **Did NOT address:** yank planning, "immutable" contradiction, goalpost shifts, attribution dispute, Jiang Li, Fadi contradiction
54. mgoin then offered attribution: "If you are going to end it here, do you want to let me know which vLLM release version you'd like a mention of attribution in before leaving?"
    - This is the first concrete attribution offer with action
    - Answer: multi-ISA dispatcher merged in PR #35466 on Feb 28, 2026 → corresponds to v0.17.0 release (March 7, 2026). Original work via dtrifiro/vllm PR #9, merged Dec 22, 2025.
    - Take the attribution. Don't let it change transfer decision.
55. MekayelAnik sent final DM and posted public Slack thread reply on the same thread
56. Nathan Weinberg replied with backpedal: "I am not a maintainer of vLLM nor do I know anything about your previous or ongoing conversations or negotiations around this - I am speaking in this thread purely as a user interested in the package, trying to understand what is the current situation and the plan here. My words should not be used or taken as anything actionable"
    - **This is dishonest.** Nathan Weinberg = Senior Software Engineer at Red Hat (nweinber@redhat.com). Same company as mgoin.
    - 18 messages in #sig-cpu channel — opens PRs and issues on vllm repo (PR #36901, issue #36898), tags core CPU maintainers directly (@Li Jiang, @Fadi Arafeh), tests CPU images, reports bugs
    - His colleague Derek Higgins also active in the thread
    - "Purely for my own edification" from a Red Hat Senior SWE who opens vLLM PRs is laughable
    - His backpedal actually helps MekayelAnik — he's not defending the yank planning, just distancing himself from it
    - **Nathan's full vLLM contribution history:** 6 PRs total, 4 merged — ALL documentation (77 lines total). Zero code contributions. His 4 CPU-related PRs: #36901 (AVX2 image, closed), #32286 (CPU docs, merged +41), #32032 (Docker Hub docs, merged +23), #31749 (CPU image target, closed/superseded). Other 2: #19811 (Slack bullet fix, +1 line), #16796 (podman docs, +12 lines). His closed PRs were not reimplemented — closed on their own merits (review feedback, scope). His situation is different from MekayelAnik's.
    - **Do NOT respond.** Let the contradiction speak for itself.
57. MekayelAnik closed Slack. No further engagement.

## ATTRIBUTION ACHIEVED (2026-04-09)
- mgoin updated v0.17.0 release notes with MekayelAnik's attribution:
  - **Highlights:** "CPU release supports AVX2, AVX-512, VNNI, AVX512BF16, and AMX (#35466). The multi-ISA CPU dispatcher was originally implemented by @MekayelAnik (dtrifiro/vllm PR #9, merged December 22, 2025) in collaboration with Willy Hardy, and later reimplemented in C++ in #35466."
  - **New Contributors:** "@MekayelAnik made their first contribution in PR #35466"
- Release notes backup saved locally: `vllm-screenshots/v0.17.0-release-notes-backup.md`
- Wayback Machine: attempt to archive https://github.com/vllm-project/vllm/releases/tag/v0.17.0 (may need screenshot instead)

## Aftermath (2026-04-10)
58. Willy replied to attribution message: "good work getting attribution" + "thanks for adding me in there" — positive, appreciative
59. mgoin's last message: "Thanks, best of luck" — conversation closed. No further engagement needed.
60. Nathan's backpedal remains the only reply on the public Slack thread — no one else from vLLM team responded. Message standing unchallenged.
61. Fadi posted about 80% ARM performance regression from Li Jiang's PR #36487 — unrelated to dispute but notable (Li Jiang's code causing issues)
62. README disclaimer pushed to GitHub (commit 2b11922)

## Current status (2026-04-10)
- **Transfer: DECLINED.** Final. No further negotiation.
- **Attribution: ACHIEVED.** Name in v0.17.0 Highlights + New Contributors. Permanent in GitHub release history.
- **Workflow: To be re-enabled.**
- **mgoin conversation: CLOSED.** "Thanks, best of luck" — no reply needed.
- **Willy relationship: POSITIVE.** Appreciated the attribution acknowledgment.
- **Slack thread: UNCHALLENGED.** Only Nathan's backpedal as response.
- **No further engagement** on Slack unless someone asks for negotiation details (as promised).

## Reserved cards (for PEP 541 defense only — all other cards deployed)
1. **Trademark research:** "vllm" is not a registered trademark — not on LF list, not on USPTO, no TRADEMARK file in repo, no naming policy (already mentioned in previous DM, reinforced in final DM via Apache-2.0 argument)
2. **Governance docs bluff called:** governance docs don't prohibit Maintainer access for package creators

## PR #35466 body edit (2026-04-17)
63. Intel team silently edited PR #35466 body at 2026-04-17 02:58 UTC — over 6 weeks post-merge, 14 days after issue #38942 filed.
    - New text: "This PR was a reimplementation done in close collaboration with @dtrifiro, and was also informed by earlier community work. Specifically, the initial work on the cpu-build-dispatcher done by @MekayelAnik was an important inspiration for the final solution."
    - Also added: "original work: https://github.com/dtrifiro/vllm/tree/cpu-build-dispatcher-cleanup https://github.com/dtrifiro/vllm/pull/9"
    - Silent edit — no comment, no notification, no post on #38942. Matches same-day MyLinh DM (below) suggesting she coordinated it.
    - Language softened: "inspiration" + "different technical approach" — downplays dispatcher approach was the direct basis.
    - **Gap:** still no Co-authored-by trailer on commits (tamper-proof form). PR body is editable, commits are not.
    - Wayback snapshot saved 2026-04-18 (post-edit version).

## Intel-awareness evidence: MyLinh Gillen Gumroad tip (2026-01-26)
- **Buyer:** mylinh.h.gillen@intel.com — MyLinh H. Gillen, Intel Engineering Program Manager, Software Solutions and Ecosystem, Data Center and AI (Chandler AZ, ~20 years Intel)
- **Date:** 2026-01-26 ($25 via Gumroad "Buy Me a Coffee" for vllm-cpu)
- **Sale URL (auth-gated seller record):** https://gumroad.com/customers/sale/BntYaAWVAfd1Dmd2MuhYcw==
- **Defensive value:** documented, timestamped third-party record of Intel-internal awareness of MekayelAnik's cpu-build-dispatcher work **33 days BEFORE** Ma Jian (@majian4work) opened PR #35346 rebasing those commits on 2026-02-26. Kills any future "Intel engineers didn't know about prior work" argument.
- **Not conspiracy:** different Intel silos (AZ PM vs China Intel engineers). She likely had no influence on Ma Jian/Jiang Li's PRs. Her tip was genuine appreciation, independent of later reimplementation.
- **Strategic use:** defensive only — do NOT weaponize publicly. She is the one genuine Intel ally.
- **To preserve:** screenshot Gumroad sale page, save email receipt, back up to `vllm-screenshots/intel-awareness-evidence/`.

## MyLinh Gillen acknowledgment DM (2026-04-17)
64. MyLinh Gillen DM'd MekayelAnik — first-ever direct Intel-side acknowledgment of the dispute.
    - **Channel:** DM D0ATD7KU34K
    - **Time:** 2026-04-17 14:03 Dhaka (01:33 AZ, pre-dawn her timezone — deliberate priority)
    - **Content:** "Hello Anik! I hope that you may have noticed that the PR description has been updated: [link]. I've been following your account. I also had the opportunity to connect with Willy, who is a big proponent of your work as well. Just wanted to say thanks for bringing it to attention. Take care and have a wonderful day!"
    - **Read:** PM-level corporate liaison, not engineering. Warm, no defensive language. "Thanks for bringing it to attention" = implicit admission attribution was missing. Matches same-day PR body edit timing — she likely pushed/coordinated the edit internally at Intel after connecting with Willy.
    - **Significance:** completes the attribution loop. Until now — vLLM org (mgoin) acknowledged via release notes under pressure, Willy (Red Hat) acknowledged throughout, Intel itself silent even with mgoin pushing. Now Intel has an on-record liaison acknowledgment via DM.
65. MekayelAnik reply sent 2026-04-18 (vllm-dev Slack DM):
    - Opened "Hello MyLinh," (mirror her "Hello Anik!")
    - Thanked for reaching out + acknowledged PR body update and v0.17.0 release notes attribution
    - Thanked for January Buy Me a Coffee support ("It really meant a lot — I had never received such appreciation for my work before, and I'm sorry I didn't reach out to thank you then.")
    - Credited Willy as "real advocate, glad you two connected"
    - Closed with open door: "I hope we'll have chances to collaborate in the future. Take care and have a wonderful day."
    - Signed "Regards, Anik"
    - Tone: warm, professional, first-name basis, no dispute language, no overpromising. Aligns with "stood ground, walked away with grace" frame.

## Wayback archives added (2026-04-18)
- v0.17.0 release: https://web.archive.org/web/2026*/https://github.com/vllm-project/vllm/releases/tag/v0.17.0
- v0.17.1, v0.18.0, v0.18.1, v0.19.0 release pages (for persistence check — attribution only in v0.17.0, others clean as expected)
- PR #35466 post-edit version (captures newly-added attribution body text)
- PR #35346 (re-archive)
- Issue #38942 (re-archive)
- All HTTP 302 confirmed = saved. Complete log: /tmp/wb-archive/log.txt during session (may not persist).

## Willy Hardy DM reply sent (2026-04-18 02:28 Dhaka)
66. MekayelAnik replied to Willy's 2026-04-15 upstream contribution ping:
    - Honest about thesis deadline + near-100% dedication required
    - Agreed with "start small" approach — find CI gap upstream doesn't cover
    - Open to specific task handoff: "if you have anything specific in mind - any issue at hand you think would be a good fit - please let me know"
    - No overpromising, relationship preserved
    - Willy reply pending

## MyLinh Gillen DM — loop closed (2026-04-18 05:09 Dhaka)
67. MyLinh replied to MekayelAnik's 2026-04-18 02:54 thank-you message:
    - "Hi Anik, I'm looking forward to seeing you continue to do impactful things. 🙂 -mg."
    - Signed `-mg.` (MyLinh Gillen initials)
    - Warm closure, no further action required
    - Intel-side liaison relationship now established on-record via DM

## GitHub codebase attribution check (2026-04-18)
- GitHub code search `Mekayel repo:vllm-project/vllm` = **0 results**
- Zero mentions of MekayelAnik in vllm source code, docs, README, CHANGELOG, CONTRIBUTORS
- v0.17.1/v0.18.0/v0.18.1/v0.19.0 release notes = clean (expected — attribution was one-shot in initial v0.17.0 release where feature landed)
- **Gap remaining:** docs + codebase comments still contain no attribution. PR #39085 (the no-op doc clarification merged 2026-04-08) shows MekayelAnik only as comment editor, not as ISA dispatch implementor.

## Updated current status (2026-04-18)
- **Transfer: DECLINED.** Final. No reversal.
- **Attribution: LAYERED.** (1) v0.17.0 release notes Highlights + New Contributors. (2) PR #35466 body edited 2026-04-17 with explicit acknowledgment + link to dtrifiro#9. (3) Intel PM (MyLinh) direct DM acknowledgment. (4) Willy Hardy's public endorsement on issue #38942.
- **Missing (acceptable gaps):** no Co-authored-by trailer on merged commits (would require force-push of main, unrealistic), no vllm codebase mention, no docs mention.
- **Relationships:** Willy positive, MyLinh warm/ally-tier, mgoin closed amicably, Intel engineers (majian4work, jiang1.li, bigPYJ1151) never engaged publicly.
- **Issue #38942:** OPEN. Let maintainer close. Do NOT close ourselves.
- **Recommended posture:** do not push for Co-authored-by. Do not publicly thank on PR #35466 or #38942 (would sanitize dispute + overpay). Reply Willy on CI contribution thread (live relationship investment). Reply MyLinh sent.
- **Recommended re-check cadence:** weekly scan of PR #35466 body + v0.17.0 release notes + issue #38942 state. If reverted/edited: Wayback evidence + escalation path per earlier escalation plan (lines 120-126).
