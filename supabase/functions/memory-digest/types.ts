// Contract for the medium-term memory digest (CLAUDE.md §6, GDD §5.3): a
// ~150-word summary regenerated every few turns, kept separate from the
// narrator contract since this is plain-text summarization, not narration.

export interface DigestTurn {
  playerAction: string;
  narration: string;
}

export interface DigestRequest {
  /** The turns since the last digest (or since the start, for the first one). */
  turnsToSummarize: DigestTurn[];
  /** The previous digest text, to continue rather than restart the diary. */
  previousDigest?: string | null;
}

export interface DigestResponse {
  summary: string;
}
