// Orchestrates the provider chain (CLAUDE.md §4, §9): tries each adapter in
// order and falls through to the next on ANY provider failure — rate limit,
// timeout, broken JSON twice, malformed response. Free tiers are a design
// constraint (CLAUDE.md §2.7), not an SLA, so graceful degradation across
// providers matters more than which specific error triggered it.

import type { NarratorAdapter, NarratorRequest, NarratorResponse } from "./types.ts";
import { NarratorProviderError } from "./types.ts";

export class AllNarratorProvidersFailedError extends Error {
  constructor(readonly attempts: { provider: string; error: unknown }[]) {
    super(
      `All narrator providers failed: ` +
        attempts.map((a) => `${a.provider} (${a.error})`).join("; "),
    );
    this.name = "AllNarratorProvidersFailedError";
  }
}

export class FallbackNarratorAdapter implements NarratorAdapter {
  readonly name = "fallback";

  constructor(private readonly chain: NarratorAdapter[]) {
    if (chain.length === 0) {
      throw new Error("FallbackNarratorAdapter needs at least one provider");
    }
  }

  async narrate(request: NarratorRequest): Promise<NarratorResponse> {
    const attempts: { provider: string; error: unknown }[] = [];

    for (const provider of this.chain) {
      try {
        return await provider.narrate(request);
      } catch (e) {
        attempts.push({ provider: provider.name, error: e });
        // Any provider failure (rate limit, broken JSON, network) falls
        // through to the next link in the chain.
        continue;
      }
    }

    throw new AllNarratorProvidersFailedError(attempts);
  }
}

export { NarratorProviderError };
