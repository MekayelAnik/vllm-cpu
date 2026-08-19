---
name: Iterative build-fix-retry workflow
description: User expects autonomous fix-and-retry loops until builds pass clean, including subtle log issues
type: feedback
---

When a CI build is triggered, keep fixing and re-triggering until it passes completely. Don't stop at the first success — also check logs for subtle warnings or potential issues that didn't break the build but could cause problems later.

**Why:** The user wants a fully working pipeline with no hidden issues, not just a "green check".

**How to apply:** After each build completes (pass or fail):
1. Get full logs for all jobs
2. Fix any errors
3. Check for subtle warnings (version mismatches, deprecated features, wrong tags, etc.)
4. Push fixes and re-trigger
5. Repeat until clean
