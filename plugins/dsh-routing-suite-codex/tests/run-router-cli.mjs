import { classifyPayload } from "../hooks/router.mjs";

let raw = "";
for await (const chunk of process.stdin) raw += chunk;
const payload = JSON.parse(raw);
const classification = classifyPayload(payload);
process.stdout.write(JSON.stringify({ route: classification.route, complex: classification.complex }));
