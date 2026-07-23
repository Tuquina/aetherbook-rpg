import { assertEquals, assertThrows } from "jsr:@std/assert@1";
import { NarratorParseError, parseNarratorJson } from "./narrator_json_parser.ts";

Deno.test("parses a clean JSON object", () => {
  const raw = `{"narration":"Hola",` +
    `"suggested_choices":[{"id":"a","label":"A"},{"id":"b","label":"B"}],` +
    `"proposed_state_deltas":[{"type":"exp","key":"exp","value":10,` +
    `"operation":"increment","reason":"porque sí"}],` +
    `"image_prompt":"algo","tone":"tenso",` +
    `"memory_facts":["prometió algo"],"node_status":"ready_to_exit"}`;
  const r = parseNarratorJson(raw);
  assertEquals(r.narration, "Hola");
  assertEquals(r.suggested_choices, [
    { id: "a", label: "A", intent: undefined, expected_check: undefined },
    { id: "b", label: "B", intent: undefined, expected_check: undefined },
  ]);
  assertEquals(r.proposed_state_deltas, [
    {
      type: "exp",
      key: "exp",
      value: 10,
      operation: "increment",
      reason: "porque sí",
    },
  ]);
  assertEquals(r.tone, "tenso");
  assertEquals(r.memory_facts, ["prometió algo"]);
  assertEquals(r.node_status, "ready_to_exit");
});

Deno.test("parses a choice's intent and expected_check", () => {
  const raw = '{"narration":"x","suggested_choices":[{"id":"c",' +
    '"label":"Investigar","intent":"investigate",' +
    '"expected_check":{"attribute":"agudeza","difficulty_id":"standard"}}]}';
  const r = parseNarratorJson(raw);
  assertEquals(r.suggested_choices, [
    {
      id: "c",
      label: "Investigar",
      intent: "investigate",
      expected_check: { attribute: "agudeza", difficulty_id: "standard" },
    },
  ]);
});

Deno.test("defaults a choice's id to its label when missing", () => {
  const raw = '{"narration":"x","suggested_choices":[{"label":"Solo label"}]}';
  const r = parseNarratorJson(raw);
  assertEquals(r.suggested_choices[0].id, "Solo label");
});

Deno.test("strips ```json fences", () => {
  const raw = '```json\n{"narration":"Con fence","suggested_choices":[]}\n```';
  const r = parseNarratorJson(raw);
  assertEquals(r.narration, "Con fence");
});

Deno.test("ignores surrounding prose and grabs the object", () => {
  const raw = 'Claro, aquí tienes: {"narration":"Limpio","suggested_choices":[]} ' +
    "¡espero que sirva!";
  const r = parseNarratorJson(raw);
  assertEquals(r.narration, "Limpio");
});

Deno.test("defaults missing optional fields", () => {
  const r = parseNarratorJson('{"narration":"x"}');
  assertEquals(r.suggested_choices, []);
  assertEquals(r.proposed_state_deltas, []);
  assertEquals(r.image_prompt, "");
  assertEquals(r.tone, "");
  assertEquals(r.memory_facts, []);
  assertEquals(r.node_status, "active");
});

Deno.test("drops malformed delta and choice entries but keeps valid ones", () => {
  const raw = '{"narration":"x","proposed_state_deltas":[' +
    '{"type":"flag","key":"k","value":true},' +
    '{"type":"flag"},' +
    '"not an object"' +
    '],"suggested_choices":[{"label":"ok"},{"id":"no-label"},"nope"]}';
  const r = parseNarratorJson(raw);
  assertEquals(r.proposed_state_deltas, [
    { type: "flag", key: "k", value: true, operation: undefined, reason: undefined },
  ]);
  assertEquals(r.suggested_choices, [
    { id: "ok", label: "ok", intent: undefined, expected_check: undefined },
  ]);
});

Deno.test("falls back to 'active' for an unrecognised node_status", () => {
  const r = parseNarratorJson('{"narration":"x","node_status":"nonsense"}');
  assertEquals(r.node_status, "active");
});

Deno.test("throws NarratorParseError on broken JSON", () => {
  assertThrows(
    () => parseNarratorJson('{"narration": "sin cerrar" '),
    NarratorParseError,
  );
});

Deno.test("throws NarratorParseError when narration is missing", () => {
  assertThrows(
    () => parseNarratorJson('{"suggested_choices":[]}'),
    NarratorParseError,
  );
});

Deno.test("throws NarratorParseError when the payload is not an object", () => {
  assertThrows(() => parseNarratorJson("[1,2,3]"), NarratorParseError);
});
