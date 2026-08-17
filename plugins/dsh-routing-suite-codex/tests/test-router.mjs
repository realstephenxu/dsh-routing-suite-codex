import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { classifyPayload, createHookOutput } from "../hooks/router.mjs";

const here = dirname(fileURLToPath(import.meta.url));
const cases = JSON.parse(readFileSync(resolve(here, "router-cases.json"), "utf8"));

for (const testCase of cases) {
  const actual = classifyPayload(testCase.payload).route;
  assert.equal(actual, testCase.route, testCase.name);
  const output = createHookOutput(testCase.payload);
  if (testCase.route === "off") {
    assert.equal(output, null, `${testCase.name}: off must emit no context`);
  } else {
    assert.equal(output.hookSpecificOutput.hookEventName, "UserPromptSubmit", `${testCase.name}: event name`);
    assert.match(output.hookSpecificOutput.additionalContext, new RegExp(`\\[DSH route: ${testCase.route}(?:;|\\])`), `${testCase.name}: route marker`);
    assert.match(output.hookSpecificOutput.additionalContext, /DSH-CODEX-ROUTER-V1/, `${testCase.name}: router identity`);
    assert.match(output.hookSpecificOutput.additionalContext, /rules v2/, `${testCase.name}: rules version marker`);
  }
}

const modelA = classifyPayload({ prompt: "修复测试", model: "codex-one" });
const modelB = classifyPayload({ prompt: "修复测试", model: "codex-two" });
assert.deepEqual(modelA, modelB, "classification must not depend on model slug");

// Stress corpus: multi-scenario x multi-difficulty deterministic gate (Node side).
const stress = JSON.parse(readFileSync(resolve(here, "stress-cases.json"), "utf8"));
let stressCount = 0;
for (const testCase of stress) {
  const actual = classifyPayload(testCase.payload ?? { prompt: testCase.prompt, permission_mode: testCase.permission_mode, model: testCase.model });
  assert.equal(actual.route, testCase.route, `${testCase.id}: route`);
  assert.equal(actual.complex, testCase.complex, `${testCase.id}: complex`);
  const output = createHookOutput(testCase.payload ?? { prompt: testCase.prompt, permission_mode: testCase.permission_mode, model: testCase.model });
  if (testCase.route === "off") {
    assert.equal(output, null, `${testCase.id}: off must emit no context`);
  } else {
    assert.match(output.hookSpecificOutput.additionalContext, /DSH-CODEX-ROUTER-V1/, `${testCase.id}: identity`);
    assert.match(output.hookSpecificOutput.additionalContext, /rules v2/, `${testCase.id}: rules version`);
  }
  stressCount++;
}
console.log(`Node router tests passed: ${cases.length} base + ${stressCount} stress cases`);
