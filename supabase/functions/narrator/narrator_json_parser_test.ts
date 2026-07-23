import { assertEquals, assertThrows } from "jsr:@std/assert@1";
import { NarratorParseError, parseNarratorJson } from "./narrator_json_parser.ts";

Deno.test("parses a clean JSON object", () => {
  const raw = `{"narration":"Hola","suggested_choices":["A","B"],` +
    `"state_deltas":[{"type":"exp","key":"exp","value":10}],` +
    `"image_prompt":"algo","tone":"tenso"}`;
  const r = parseNarratorJson(raw);
  assertEquals(r.narration, "Hola");
  assertEquals(r.suggested_choices, ["A", "B"]);
  assertEquals(r.state_deltas, [{ type: "exp", key: "exp", value: 10 }]);
  assertEquals(r.tone, "tenso");
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
  assertEquals(r.state_deltas, []);
  assertEquals(r.image_prompt, "");
  assertEquals(r.tone, "");
});

Deno.test("drops malformed delta entries but keeps valid ones", () => {
  const raw = '{"narration":"x","state_deltas":[' +
    '{"type":"flag","key":"k","value":true},' +
    '{"type":"flag"},' +
    '"not an object"' +
    "]}";
  const r = parseNarratorJson(raw);
  assertEquals(r.state_deltas, [{ type: "flag", key: "k", value: true }]);
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
