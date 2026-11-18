import { MAX_TEXT_CODE_POINTS, buildPayload, codePointCount, sendReport, type SendState } from '../lib/feedback';

type View = { tone: 'busy' | 'ok' | 'bad'; title: string; detail: string };

const PROMPTS: Record<string, string> = {
  bug: 'What happened, and what did you expect?',
  suggestion: 'What would you change, and why?',
};

const SENDING: View = { tone: 'busy', title: 'Sending', detail: 'Hold on a moment.' };

const REFUSALS: Record<string, View> = {
  'empty text': { tone: 'bad', title: 'Not sent: the text is empty', detail: 'Write what happened, then send again.' },
  'text too long': {
    tone: 'bad',
    title: `Not sent: the text is over ${MAX_TEXT_CODE_POINTS} characters`,
    detail: 'Shorten it, then send again. Your text stays in the box.',
  },
};

function viewOf(result: SendState): View {
  switch (result.state) {
    case 'sent':
      return { tone: 'ok', title: 'Sent', detail: 'Thank you. It goes to the tracker. The form is clear for another report.' };
    case 'rejected':
      return {
        tone: 'bad',
        title: result.reason ? `Not sent: ${result.reason}` : 'Not sent: the tracker refused the report',
        detail: 'Your text stays in the box. Change it, then send again.',
      };
    case 'rate-limited':
      return {
        tone: 'bad',
        title: 'Not sent: too many reports for now',
        detail:
          result.minutes === null
            ? 'Try again later. Your text stays in the box.'
            : `Try again in ${result.minutes} minute${result.minutes === 1 ? '' : 's'}. Your text stays in the box.`,
      };
    case 'network-error':
      return {
        tone: 'bad',
        title: 'Not sent: no connection to the tracker',
        detail: 'Your text stays in the box. Try again, or use /bug in Discord.',
      };
  }
}

function part<T extends Element>(form: HTMLFormElement, selector: string): T {
  const el = form.querySelector<T>(selector);
  if (!el) throw new Error(`feedback form is missing ${selector}`);
  return el;
}

export function initFeedbackForm(form: HTMLFormElement): void {
  const endpoint = form.dataset.endpoint ?? '';
  const text = part<HTMLTextAreaElement>(form, 'textarea');
  const prompt = part<HTMLElement>(form, '[data-prompt]');
  const count = part<HTMLElement>(form, '[data-count]');
  const honeypot = part<HTMLInputElement>(form, 'input[tabindex="-1"]');
  const send = part<HTMLButtonElement>(form, 'button[type="submit"]');
  const status = part<HTMLElement>(form, '[role="status"]');
  const statusTitle = part<HTMLElement>(form, '[data-status-title]');
  const statusDetail = part<HTMLElement>(form, '[data-status-detail]');

  const kind = () => form.querySelector<HTMLInputElement>('input[name="kind"]:checked')?.value ?? 'bug';

  const syncCount = () => {
    const n = codePointCount(text.value);
    count.textContent = `${n} / ${MAX_TEXT_CODE_POINTS}`;
    count.toggleAttribute('data-over', n > MAX_TEXT_CODE_POINTS);
  };

  const syncPrompt = () => {
    prompt.textContent = PROMPTS[kind()] ?? PROMPTS.bug;
  };

  const show = (view: View) => {
    status.hidden = false;
    status.dataset.tone = view.tone;
    statusTitle.textContent = view.title;
    statusDetail.textContent = view.detail;
  };

  text.addEventListener('input', syncCount);
  form.addEventListener('change', syncPrompt);

  form.addEventListener('submit', async (event) => {
    event.preventDefault();
    if (send.disabled) return;
    const built = buildPayload(kind(), text.value, honeypot.value);
    if ('error' in built) {
      show(REFUSALS[built.error]);
      return;
    }
    send.disabled = true;
    show(SENDING);
    const result = await sendReport(endpoint, built.payload);
    send.disabled = false;
    if (result.state === 'sent') {
      form.reset();
      syncCount();
      syncPrompt();
    }
    show(viewOf(result));
  });

  syncCount();
  syncPrompt();
  form.hidden = false;
}
