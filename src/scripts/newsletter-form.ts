function part<T extends Element>(form: HTMLFormElement, selector: string): T {
  const el = form.querySelector<T>(selector);
  if (!el) throw new Error(`newsletter form is missing ${selector}`);
  return el;
}

export function initNewsletterForm(form: HTMLFormElement): void {
  const email = part<HTMLInputElement>(form, 'input[type="email"]');
  const age = part<HTMLInputElement>(form, 'input[type="checkbox"]');
  const submit = part<HTMLButtonElement>(form, 'button[type="submit"]');

  const sync = () => {
    submit.disabled = !(email.validity.valid && email.value !== '' && age.checked);
  };

  form.addEventListener('input', sync);
  form.addEventListener('change', sync);
  sync();
}
