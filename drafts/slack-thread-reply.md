Hey everyone,

I want to put a few things on public record.

On December 11, 2025, @mgoin opened <https://github.com/MekayelAnik/vllm-cpu/issues/3|issue #3> on my vllm-cpu GitHub repo saying: "I appreciate this great work from you to improve the UX of using CPUs with vLLM! Would you be open to collaborating with us in upstream vLLM?" The very next day in this Slack channel, the tone was: "I don't recognize the name of the owner and this seems like an obvious issue."

@Fadi Arafeh said "I'm particularly worried about him suggesting people use his wheels for Arm" — I suggested them on <https://github.com/vllm-project/vllm/issues/30065|issue #30065> where a user was asking for ARM64 wheels that vLLM hadn't released. On that same issue, Fadi praised my work — "Appreciate you creating them and helping other people, keep up the good work!" — gave me constructive feedback on a glibc issue (which I fixed), and even suggested: "I think it'd be a good idea to consider releasing official vLLM CPU wheels to vllm-cpu in the future." He recommended my package name for official use on GitHub, then expressed concern about it in Slack.

When I joined the Slack on December 18, my response was: "There won't be any issues if you wanna publish vllm-cpu as official wheels... you are welcome to do so."

*I offered collaboration from day one. I was treated as an obstacle from day one.*

Now, while I was negotiating the vllm-cpu PyPI transfer in good faith with @mgoin in DMs, the following was being discussed in this very thread:


@Nathan Weinberg asked about yanking my existing published packages. @mgoin agreed. Nathan confirmed it would need Owner permissions and would be "*potentially fairly disruptive to anyone currently using the package*" — but said "that may be worth it, for the long-term gain."

Let that sink in. I was accused of being a supply-chain risk for a miscommunication on my own repo. Meanwhile, yanking working packages with 17,000+ monthly downloads was being discussed as "worth it." That's not protecting the supply chain. That's creating supply-chain issues for your own benefit.

Meanwhile, when I raised work retention as a formal clause in our negotiation, @mgoin's response was: "PyPI releases are immutable" — using it to dismiss the concern entirely and close that point of discussion. And when @Nathan Weinberg suggested yanking my packages in this thread, @mgoin didn't mention that keeping existing wheels intact was one of my negotiation terms. He simply agreed to Nathan.

I was told my work was safe in private. It was being planned for removal in public. On the same day.

I've been maintaining vllm-cpu since December 2025 — 17,000+ monthly downloads across all vllm-cpu packages, every version from 0.8.5 through 0.19.0, built across all CPU ISA variants, on my own time and resources as a Masters student. I never claimed it was official. I never charged anyone. I deprecated my 4 variant packages and removed my personal donation links as goodwill.

I also want to note that my multi-ISA CPU dispatcher work — contributed via <https://github.com/dtrifiro/vllm/pull/9|dtrifiro/vllm PR #9> — was reimplemented without attribution in <https://github.com/vllm-project/vllm/pull/35466|PR #35466>. <https://github.com/vllm-project/vllm/pull/35346|PR #35346> contained my rebased commits, was closed, and #35466 appeared the next day with zero credit. The reimplementation happened on February 28. I raised this on <https://github.com/vllm-project/vllm/issues/38942|issue #38942> on April 3. I tagged @simon-mo, @WoosukKwon, and @youkaichao. Not a single maintainer has responded on the issue. It is still unresolved.

Given this, I will not be transferring ownership of the vllm-cpu PyPI repo. I will continue maintaining it independently. The CI/CD workflow will be re-enabled.

If anyone wants details on my negotiation with @mgoin, I am open to providing them. But I will not be negotiating terms with anyone further.

I remain open to contributing upstream. I'm a vLLM contributor — whether I get attribution for my previous work or not, that is a fact. But I will not hand over the keys to people who planned to remove my work while telling me it was safe.

*Note: For everyone's clarification — vllm-cpu is an unofficial PyPI package of vLLM's CPU variant, which pioneered the first public publication of vLLM wheels built for CPU on PyPI, including an automated CI/CD pipeline, open-sourced under the GPLv3 license at <https://github.com/MekayelAnik/vllm-cpu|MekayelAnik/vllm-cpu>. The first successful unification of different CPU ISAs (AVX2, AVX-512, VNNI, BF16, AMX) into a single wheel was done by Mekayel Anik, for the benefit of the community. It is in no way affiliated with or funded by the vLLM project or any of its sister concerns or any of the hardware vendors.*

Regards,
Mekayel
