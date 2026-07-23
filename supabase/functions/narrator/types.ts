// TypeScript mirror of the narrator contract (CLAUDE.md §5). The engine
// resolves mechanics in Dart; this Edge Function only narrates a resolution
// that already happened. Nothing here decides success/failure — that comes
// in on the wire, already computed.

export type ActionOutcome = "failure" | "success" | "criticalSuccess";

export interface ActionResolution {
  outcome: ActionOutcome;
  attribute: number;
  modifiers: number;
  roll: number;
  difficulty: number;
  total: number;
  isNatural20: boolean;
  isNatural1: boolean;
}

export interface CharacterState {
  name: string;
  level: number;
  exp: number;
  attributes: Record<string, number>;
  resources: Record<string, number>;
  flags?: Record<string, boolean>;
}

export interface WorldContext {
  slug: string;
  name: string;
  tone: string;
  systemPrompt: string;
  imageStyleSuffix: string;
}

/** Body sent by the Dart client's HttpNarratorAdapter. */
export interface NarratorRequest {
  world: WorldContext;
  character: CharacterState;
  playerAction: string;
  /** `null` only for the opening/seed turn. */
  resolution: ActionResolution | null;
  /** Short-term memory: the last few turns, literal (CLAUDE.md §6). */
  recentTurns?: string[];
}

export interface StateDeltaWire {
  type: string;
  key: string;
  value: unknown;
}

/** The structured output contract (CLAUDE.md §5), wire format (snake_case). */
export interface NarratorResponse {
  narration: string;
  suggested_choices: string[];
  state_deltas: StateDeltaWire[];
  image_prompt: string;
  tone: string;
}

/** A single narrator provider (Gemini, Groq, …). One adapter per file. */
export interface NarratorAdapter {
  readonly name: string;
  narrate(request: NarratorRequest): Promise<NarratorResponse>;
}

/**
 * Raised by a provider adapter on any failure. `isRateLimit` lets the
 * FallbackNarratorAdapter decide whether to try the next provider in the
 * chain (CLAUDE.md §9: every adapter ships a rate-limit → fallback test).
 */
export class NarratorProviderError extends Error {
  constructor(
    message: string,
    readonly isRateLimit: boolean = false,
    override readonly cause?: unknown,
  ) {
    super(message);
    this.name = "NarratorProviderError";
  }
}
