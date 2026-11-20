#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

echo "== Gate script: submit waits for a valid email and the age box =="
node --input-type=module -e '
import assert from "node:assert/strict";
import { pathToFileURL } from "node:url";
const { initNewsletterForm } = await import(pathToFileURL(process.argv[1]).href);
assert.equal(typeof initNewsletterForm, "function", "newsletter-form.ts exports no initNewsletterForm");

const node = (props) => {
  const listeners = [];
  return Object.assign({ listeners, addEventListener: (type, l) => listeners.push([type, l]), removeEventListener() {} }, props);
};
const form = node({});
const email = node({ type: "email", name: "email", value: "" });
Object.defineProperty(email, "validity", { get: () => ({ valid: /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email.value) }) });
email.checkValidity = () => email.validity.valid;
const box = node({ type: "checkbox", checked: false });
const button = node({ type: "submit", disabled: false });
form.querySelector = (selector) =>
  selector.includes("email") ? email : selector.includes("checkbox") ? box : selector.includes("submit") || selector.includes("button") ? button : null;

const fire = (el, ...types) => {
  for (const type of types) {
    const event = { type, target: el, currentTarget: el, preventDefault() {} };
    for (const [t, l] of [...el.listeners, ...form.listeners]) if (t === type) l(event);
  }
};
const typeEmail = (value) => { email.value = value; fire(email, "input"); };
const tick = (checked) => { box.checked = checked; fire(box, "input", "change"); };

initNewsletterForm(form);
assert.equal(button.disabled, true, "submit is enabled after init with an empty form");
typeEmail("pilot@example.com");
assert.equal(button.disabled, true, "submit is enabled with only a valid email");
typeEmail("");
tick(true);
assert.equal(button.disabled, true, "submit is enabled with only the age box ticked");
typeEmail("pilot@example.com");
assert.equal(button.disabled, false, "submit stays disabled with a valid email and the box ticked");
tick(false);
assert.equal(button.disabled, true, "submit stays enabled after the box is unticked");
console.log("newsletter-form OK");
' "$PWD/src/scripts/newsletter-form.ts"
