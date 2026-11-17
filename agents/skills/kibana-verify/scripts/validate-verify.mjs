#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";

const VERDICTS = ["pass", "fail", "partial", "blocked"];
const STATUSES = ["pass", "fail", "blocked"];
const APP_VIA = ["ui", "api", "es", "log"];
const VIA = [...APP_VIA, "test"];
const VISUAL = /\.(png|jpe?g|webm)$/i;

const args = process.argv.slice(2);
const planAt = args.indexOf("--plan");
const planFile = planAt === -1 ? null : args.splice(planAt, 2)[1];
const resultFile = path.resolve(args[0] ?? "verify.json");
const dir = path.dirname(resultFile);

const text = (v) => typeof v === "string" && v.trim().length > 0;

function planCriteria(file) {
  const lines = fs.readFileSync(file, "utf8").split("\n");
  const start = lines.findIndex((l) => /^#+\s*acceptance criteria/i.test(l));
  if (start === -1) return null;
  const rest = lines.slice(start + 1);
  const end = rest.findIndex((l) => /^#+\s/.test(l));
  return (end === -1 ? rest : rest.slice(0, end)).filter((l) => /^(?:[-*]|\d+[.)])\s+\S/.test(l));
}

function expectedVerdict(criteria) {
  if (criteria.some((c) => c.status === "fail")) return "fail";
  if (criteria.every((c) => c.status === "pass")) return "pass";
  if (criteria.every((c) => c.status !== "pass")) return "blocked";
  return "partial";
}

function checkEvidence(check, where, errors) {
  if (check.status === "blocked") return;
  const files = Array.isArray(check.files) ? check.files : [];
  if (!text(check.response) && files.length === 0) {
    errors.push(`${where}: a ${check.status} check needs evidence: \`response\` (quoted body, output or log lines) or \`files\``);
  }
  for (const [i, f] of files.entries()) {
    if (!text(f?.file) || !text(f?.caption)) errors.push(`${where}.files[${i}]: needs \`file\` and \`caption\``);
    else if (!fs.existsSync(path.join(dir, f.file))) errors.push(`${where}.files[${i}]: ${f.file} does not exist next to the result file`);
  }
  if (check.via === "ui" && !files.some((f) => VISUAL.test(f?.file ?? ""))) {
    errors.push(`${where}: a ui check needs a screenshot or recording in \`files\``);
  }
}

function validate(r) {
  const errors = [];
  if (!VERDICTS.includes(r.verdict)) errors.push(`\`verdict\` must be one of ${VERDICTS.join("|")}`);
  if (!text(r.summary)) errors.push("`summary` must be a non-empty string");

  const checks = Array.isArray(r.checks) ? r.checks : [];
  const criteria = Array.isArray(r.criteria) ? r.criteria : [];
  if (checks.length === 0) errors.push("`checks` must be a non-empty array");
  if (criteria.length === 0) errors.push("`criteria` must be a non-empty array");

  const byId = new Map();
  for (const [i, c] of checks.entries()) {
    const where = `checks[${i}]`;
    if (!text(c.id) || byId.has(c.id)) errors.push(`${where}.id must be a unique non-empty string`);
    byId.set(c.id, c);
    if (!text(c.title)) errors.push(`${where}.title missing`);
    if (!STATUSES.includes(c.status)) errors.push(`${where}.status must be one of ${STATUSES.join("|")}`);
    if (!VIA.includes(c.via)) errors.push(`${where}.via must be one of ${VIA.join("|")}`);
    if (!text(c.details)) errors.push(`${where}.details missing: what you did and what you saw`);
    checkEvidence(c, where, errors);
  }

  for (const [i, c] of criteria.entries()) {
    const where = `criteria[${i}]`;
    if (c.id !== `AC${i + 1}`) errors.push(`${where}.id must be AC${i + 1}`);
    if (!text(c.text)) errors.push(`${where}.text missing`);
    if (!STATUSES.includes(c.status)) errors.push(`${where}.status must be one of ${STATUSES.join("|")}`);
    const refs = Array.isArray(c.checks) ? c.checks : [];
    const missing = refs.filter((id) => !byId.has(id));
    if (missing.length) errors.push(`${where}.checks names unknown check(s): ${missing.join(", ")}`);
    if (c.status !== "pass") continue;
    if (refs.length === 0) errors.push(`${where}: a pass criterion needs at least one check`);
    const notPassing = refs.filter((id) => byId.get(id) && byId.get(id).status !== "pass");
    if (notPassing.length) errors.push(`${where}: marked pass, but check(s) ${notPassing.join(", ")} did not pass`);
  }

  if (VERDICTS.includes(r.verdict) && criteria.length) {
    const expected = expectedVerdict(criteria);
    if (r.verdict !== expected) errors.push(`\`verdict\` must be "${expected}" for these criterion statuses (got "${r.verdict}")`);
  }
  if (r.verdict === "pass") {
    const failing = checks.filter((c) => c.status !== "pass");
    if (failing.length) errors.push(`verdict is "pass" but check(s) ${failing.map((c) => c.id).join(", ")} did not pass`);
    if (!checks.some((c) => c.status === "pass" && APP_VIA.includes(c.via))) {
      errors.push("verdict is \"pass\" but no passing check went through the running app (via ui|api|es|log); tests alone do not prove behavior");
    }
  }
  for (const key of ["setup", "notCovered"]) {
    if (r[key] !== undefined && !(Array.isArray(r[key]) && r[key].every(text))) errors.push(`\`${key}\` must be an array of non-empty strings`);
  }

  if (planFile) {
    const planned = planCriteria(planFile);
    if (!planned) errors.push(`${planFile} has no "Acceptance criteria" section with top-level list items`);
    else if (planned.length !== criteria.length) errors.push(`the plan lists ${planned.length} acceptance criteria, the result lists ${criteria.length}`);
  }
  return errors;
}

let result;
try {
  result = JSON.parse(fs.readFileSync(resultFile, "utf8"));
} catch (e) {
  console.log(`- ${resultFile} is missing or not valid JSON: ${e.message}`);
  process.exit(1);
}

const errors = validate(result);
if (errors.length === 0) {
  console.log("OK");
  process.exit(0);
}
for (const e of errors) console.log(`- ${e}`);
process.exit(1);
