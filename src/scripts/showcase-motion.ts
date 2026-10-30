import Lenis from 'lenis';
import 'lenis/dist/lenis.css';
import { scroll, inView, frame, cancelFrame } from 'motion';

export function initShowcaseMotion(): void {
  const mq = matchMedia('(prefers-reduced-motion: reduce)');
  if (mq.matches) return;

  const root = document.documentElement;
  const main = document.querySelector<HTMLElement>('main.page');
  const svg = main?.querySelector<SVGSVGElement>(':scope > .traj-live');
  const path = svg?.querySelector('path');
  const craft = svg?.querySelector('circle');
  if (!main || !svg || !path || !craft) throw new Error('showcase-motion: main.page has no .traj-live path and craft');
  root.classList.add('js');

  const lenis = new Lenis({ autoRaf: false });
  const update = ({ timestamp }: { timestamp: number }) => lenis.raf(timestamp);
  frame.setup(update, true);

  let top = 0;
  let length = 0;
  let samples: { at: number; y: number }[] = [];
  let progress = 0;

  const lengthAt = (y: number) => {
    let lo = 0;
    let hi = samples.length - 1;
    if (samples[hi].y < y) return length;
    while (lo < hi) {
      const mid = (lo + hi) >> 1;
      if (samples[mid].y < y) lo = mid + 1;
      else hi = mid;
    }
    return samples[lo].at;
  };

  const draw = () => {
    if (!length) return;
    const at = Math.max(lengthAt(scrollY + innerHeight * 0.6 - top), progress * length);
    path.style.strokeDashoffset = String(1 - at / length);
    const tip = path.getPointAtLength(at);
    craft.setAttribute('cx', String(tip.x));
    craft.setAttribute('cy', String(tip.y));
  };

  const build = () => {
    const box = main.getBoundingClientRect();
    const sections = [...main.querySelectorAll<HTMLElement>(':scope > section')];
    if (!sections.length) return;
    const g = parseFloat(getComputedStyle(main).paddingLeft) / 2;
    const xs = [box.width - g, g];
    const y = (el: HTMLElement) => el.getBoundingClientRect().top - box.top;
    let side = 0;
    let d = `M ${xs[0]} ${y(sections[0])}`;
    for (const section of sections.slice(1)) {
      const at = y(section);
      const [a, b] = [xs[side], xs[1 - side]];
      d += ` L ${a} ${at} C ${a} ${at + 50} ${b} ${at + 50} ${b} ${at + 100}`;
      side = 1 - side;
    }
    d += ` L ${xs[side]} ${sections[sections.length - 1].getBoundingClientRect().bottom - box.top}`;
    svg.setAttribute('viewBox', `0 0 ${box.width} ${box.height}`);
    path.setAttribute('d', d);
    length = path.getTotalLength();
    samples = [];
    for (let at = 0; at < length; at += 16) samples.push({ at, y: path.getPointAtLength(at).y });
    samples.push({ at: length, y: path.getPointAtLength(length).y });
    top = box.top + scrollY;
    draw();
  };

  const resize = new ResizeObserver(build);
  resize.observe(main);

  const stopScroll = scroll((p: number) => {
    progress = p;
    draw();
  });

  const enters = [...document.querySelectorAll<HTMLElement>('.enter')];
  enters.forEach((el, i) => {
    el.style.transitionDelay = `${(i % 4) * 70}ms`;
  });
  const stopInView = inView(enters, (el) => {
    el.classList.add('in');
  }, { margin: '0px 0px -10% 0px' });

  const teardown = (event: MediaQueryListEvent) => {
    if (!event.matches) return;
    mq.removeEventListener('change', teardown);
    stopScroll();
    stopInView();
    cancelFrame(update);
    lenis.destroy();
    resize.disconnect();
    root.classList.remove('js');
  };
  mq.addEventListener('change', teardown);
}
