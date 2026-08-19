Michael,

Before I respond to your offer, I need to address something.

*Your first message to me (December 11, 2025):*
You opened <https://github.com/MekayelAnik/vllm-cpu/issues/3|issue #3> on my vllm-cpu GitHub repo saying: "I appreciate this great work from you to improve the UX of using CPUs with vLLM! Would you be open to collaborating with us in upstream vLLM?"

The very next day in the Slack channel, the tone was: "I don't recognize the name of the owner and this seems like an obvious issue if we want to publish an official vllm-cpu wheel."

In DMs, you said: "Could we share or transfer ownership if you aren't interested in joining upstream efforts?"

I had expressed my interest openly. I have contributed upstream — <https://github.com/vllm-project/vllm/pull/39085|PR #39085> is merged, I've offered to work on CI/CD and Docker, I asked for pointers, I joined SIG-CPU. Your own condition was met. Yet you went from praising my work and inviting collaboration, to treating me as an obstacle, to offering to share ownership, to rejecting even Maintainer access, to now offering Maintainer with a forfeit clause. The goalposts have moved every single time.

*But that's not why I'm writing this.*

When I raised work retention concerns in our negotiation, you dismissed them with: "PyPI releases are immutable."

Here is what you said in the public Slack thread on the same day:

[screenshot]

@Nathan Weinberg asked: "Would the previous vllm-cpu published packages need to be yanked so the workflow automation could re-publish those package versions with the official wheels?"

You replied: "Yeah something like that would be probably be the best we could do."

Nathan then said: "You'll need owner permissions on the package... *potentially fairly disruptive to anyone currently using the package*. But that may be worth it, for the long-term gain here."

Let that sink in. You accused me of being a supply-chain risk for a miscommunication on my own repo. Meanwhile, your colleague is openly saying that yanking working packages from a repo which now houses the unified CPU build of all 5 CPU variants — with 17,000+ monthly downloads across all 5 vllm-cpu packages — would be *potentially fairly disruptive* — and your team's response is "that may be worth it." You're willing to cause the exact supply-chain disruption you accused me of risking, except you'd be doing it deliberately to real users who depend on these packages today. That's not protecting the supply chain. That's creating supply-chain issues for your own benefit.

You told me my wheels were safe because PyPI is immutable. At the same time, you were planning with your colleague how to yank them after getting Owner access. That is not a misunderstanding. That is saying one thing in a private negotiation and planning the opposite in public.

*I also want to put on record how this started.*

On December 12, 2025 at 3:33 AM, before you ever spoke to me directly, you wrote in the Slack channel: "I don't recognize the name of the owner and this seems like an obvious issue." @Fadi Arafeh said "I'm particularly worried about him suggesting people use his wheels for Arm" — I suggested them on <https://github.com/vllm-project/vllm/issues/30065|issue #30065> where a user was asking for ARM64 wheels that vLLM hadn't released. On that same issue, Fadi praised my work — "Appreciate you creating them and helping other people, keep up the good work!" — gave me constructive feedback on a glibc issue (which I fixed), and even suggested: "I think it'd be a good idea to consider releasing official vLLM CPU wheels to vllm-cpu in the future." He recommended my package name for official use on GitHub, then expressed concern about it in Slack.

When I joined the Slack on December 18, my response was: "There won't be any issues if you wanna publish vllm-cpu as official wheels... you are welcome to do so."

*I offered collaboration from day one. I was treated as an obstacle from day one.*

When I sent you a formal 7-clause proposal on December 12, 2025, you acknowledged it but didn't address it. You had a family emergency on December 20 — I understand that. But you never followed up. Three months of silence. When you resurfaced on March 19, 2026, you still didn't address my proposal — you just asked again for access to the package. I had to push back on April 2 before you finally engaged with my terms. And when you did engage, you told your colleagues my negotiation terms were "legal stipulations" you didn't have bandwidth for — framing me as difficult before I could speak for myself.

*On your current offer:*

Your offer addresses only one of my terms — Maintainer access — while ignoring every other clause: changelog/release notes acknowledgment, binding commitments, public announcements, implementation timeline, and work retention. You cherry-picked the one term you could attach a forfeit clause to and skipped everything that would have protected my contribution.

You've also consistently insisted on negotiating one clause at a time — "Let's just focus on the vllm-cpu pypi repo for now," "I think all the other items are addressable separately." Negotiating each clause separately is not something I can do — it allows terms to be agreed in isolation and then walked back when the next clause comes up. I raised all my terms together for a reason. You addressed one, ignored the rest, and attached a forfeit clause to the one you did address.

On top of that, you're offering Maintainer with a condition that if I "push without permission" I forfeit my position. Who decides what counts as "without permission"? The Owner — which would be you. This gives you a pre-built justification to remove me whenever you choose. And an Owner can remove a Maintainer with one click regardless of any agreement. There is no enforcement mechanism on PyPI.

I haven't moved my goalposts once throughout this entire negotiation — in fact, I made concessions: agreeing to align the PyPI README, agreeing that vendors should have stake, agreeing that upstream CI/CD should evolve freely, pausing my own workflow as goodwill. You, on the other hand, have moved yours several times — from praising my work and inviting collaboration, to sharing ownership, to no access at all, to Maintainer with a forfeit clause. I noticed each time but didn't call it out, out of courtesy, respect, and good faith. But that good faith no longer exists.

Given what I've seen in the Slack thread, I cannot trust that any agreement would be honored. You said "immutable" while planning to yank. The person who would sign a commitment is the same person who contradicted it publicly on the same day.

I am taking time out of my government funded research with hard deadlines to negotiate in good faith, only to discover the other side — whether one person or a team — was not doing the same. I don't have the luxury of going back and forth indefinitely. I have to make a decision, and I've made it.

*Why I will not transfer:*

1. *Trust is broken.* You said "PyPI is immutable" in our negotiation while planning to yank my wheels in a public thread. I cannot trust any commitment from someone — or a team — who contradicted themselves on the same day.
2. *My work will be removed.* The Slack thread confirms the plan is to yank my existing wheels and replace them. Everything I built will be erased.
3. *You can remove me anytime.* An Owner can remove a Maintainer with one click. No enforcement mechanism exists on PyPI. The forfeit clause is just a formalized version of what you can already do unilaterally.
4. *You moved the goalposts on your own terms.* When you invited me via <https://github.com/MekayelAnik/vllm-cpu/issues/3|issue #3>, you said "Would you be open to collaborating with us in upstream vLLM?" In DMs you said "Could we share or transfer ownership if you aren't interested in joining upstream efforts?" I did contribute upstream — my multi-ISA CPU dispatcher work via <https://github.com/dtrifiro/vllm/pull/9|dtrifiro/vllm PR #9> was merged on December 22, 2025, and later reimplemented in <https://github.com/vllm-project/vllm/pull/35466|PR #35466> without my attribution. <https://github.com/vllm-project/vllm/pull/39085|PR #39085> — a no-op documentation change offered in lieu of proper attribution for my ISA work — was merged, making me an official contributor on paper. Which in no way covers the gravity of my work — it shows me as a comment editor, not the person who implemented the core CPU ISA dispatch function. Your own condition was met either way. Instead of sharing ownership as offered, you rejected even Maintainer access.
5. *My work was taken without attribution and it is still unresolved.* My multi-ISA CPU dispatcher was reimplemented by Jiang Li in <https://github.com/vllm-project/vllm/pull/35466|PR #35466> without credit. The reimplementation happened on February 28. <https://github.com/vllm-project/vllm/issues/38942|Issue #38942> was filed on April 3. Not a single maintainer has responded on it. You told me in DMs you'd add a code comment link and update release notes — none of that has been done. There is zero mention of my name anywhere in the vllm-project/vllm codebase or release notes. This doesn't need negotiation — it deserves the attention of the vLLM team and core maintainers, for the sake of the project's reputation and the Linux Foundation's own standards. And your latest reply avoided the topic entirely, only addressing Maintainer access with a forfeit clause. The multi-ISA CPU dispatch problem remained unsolved until I built the Python dispatcher. My work was merged on December 22, 2025. On February 26, 2026, <https://github.com/vllm-project/vllm/pull/35346|PR #35346> was opened upstream containing my rebased commits — then closed. The very next day, <https://github.com/vllm-project/vllm/pull/35466|PR #35466> was opened as a "simple version" reimplementing the same work in C++ and merged on February 28 — without a single line of attribution.

*My decision:*

I will not be transferring ownership of the vllm-cpu PyPI repo. I will be continuing to maintain it independently.

This is not about control. I built these packages from scratch — across every CPU variant, without any vendor funding, on my own time as a Masters student. I filled a gap that vLLM left open for over two years. I never claimed they were official. I never charged anyone. I deprecated my 4 variant packages and removed my personal donation links as goodwill. The full attribution dispute remains documented and unresolved on <https://github.com/vllm-project/vllm/issues/38942|issue #38942>.

vLLM is published under the Apache-2.0 license, which explicitly grants the right to reproduce, distribute, and prepare derivative works — even for commercial purposes, which I didn't pursue. "vllm-cpu" as a PyPI package name describes what the package is — a CPU build of vLLM. That is not using the vLLM name to benefit from it — it is describing the purpose of the work, which is textbook permitted use.

I remain open to contributing upstream. I'm a vLLM contributor — whether I get attribution for my previous work or not, that is a fact. And I plan to keep submitting PRs. But I will not hand over the keys to people who planned to destroy my work while telling me it was safe.

The CI/CD workflow will be re-enabled.

Regards,
    Mekayel
