import { readFileSync, appendFileSync } from "node:fs";
import { pathToFileURL } from "node:url";

const rules = JSON.parse(readFileSync(new URL("./routing-rules.json", import.meta.url), "utf8"));

function validateRules(activeRules) {
  for (const signal of ["greeting", "planExplicit", "inspect", "fix", "build", "complex", "noChange"]) {
    if (typeof activeRules?.signals?.[signal] !== "string") throw new Error(`Missing signal: ${signal}`);
    new RegExp(activeRules.signals[signal], "iu");
  }
  for (const key of ["prefix", "plan", "inspect", "fix", "build", "adaptive", "simpleTail", "complexTail"]) {
    if (typeof activeRules?.guidance?.[key] !== "string") throw new Error(`Missing guidance: ${key}`);
  }
  if (typeof activeRules?.complexity?.minLength !== "number") throw new Error("Missing complexity.minLength");
  if (typeof activeRules?.version !== "number") throw new Error("Missing rules version");
}

function countMatches(text, pattern) {
  return text.match(new RegExp(pattern, "giu"))?.length ?? 0;
}

export function classifyPayload(payload, activeRules = rules) {
  validateRules(activeRules);
  const prompt = typeof payload?.prompt === "string" ? payload.prompt.trim() : "";
  const permissionMode = typeof payload?.permission_mode === "string"
    ? payload.permission_mode.toLowerCase()
    : "";

  if (!prompt) return { route: "off", complex: false };
  if (permissionMode === "plan") return { route: "plan", complex: true };

  const signals = activeRules.signals;
  if (new RegExp(signals.greeting, "iu").test(prompt)) return { route: "off", complex: false };
  if (new RegExp(signals.planExplicit, "iu").test(prompt)) return { route: "plan", complex: true };

  const fixScore = countMatches(prompt, signals.fix);
  const buildScore = countMatches(prompt, signals.build);
  const inspectScore = countMatches(prompt, signals.inspect);
  const noChange = new RegExp(signals.noChange, "iu").test(prompt);
  const effectiveFix = noChange ? 0 : fixScore;
  const effectiveBuild = noChange ? 0 : buildScore;
  let route = "off";
  if (effectiveFix > 0 && effectiveBuild > 0) route = "adaptive";
  else if (effectiveFix > 0) route = "fix";
  else if (effectiveBuild > 0) route = "build";
  else if (inspectScore > 0) route = "inspect";

  const complex = route !== "off" && (
    prompt.length >= activeRules.complexity.minLength ||
    new RegExp(signals.complex, "iu").test(prompt)
  );
  return { route, complex };
}

export function createHookOutput(payload, activeRules = rules) {
  validateRules(activeRules);
  const classification = classifyPayload(payload, activeRules);
  if (classification.route === "off") return null;
  const guidance = activeRules.guidance;
  const tail = classification.complex ? guidance.complexTail : guidance.simpleTail;
  const marker = `[DSH route: ${classification.route}; rules v${activeRules.version}]`;
  const additionalContext = [
    marker,
    guidance.prefix,
    guidance[classification.route],
    tail,
  ].join(" ");
  return {
    hookSpecificOutput: {
      hookEventName: "UserPromptSubmit",
      additionalContext,
    },
  };
}

async function main() {
  try {
    let raw = "";
    for await (const chunk of process.stdin) raw += chunk;
    const output = createHookOutput(JSON.parse(raw));
    if (output) process.stdout.write(`${JSON.stringify(output)}\n`);
  } catch {
    // Fail open: malformed input or local configuration must never block Codex.
    if (process.env.DSH_DEBUG) {
      appendFileSync(process.env.DSH_DEBUG, `[router.mjs] ${new Date().toISOString()} hook failed\n`);
    }
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) await main();
