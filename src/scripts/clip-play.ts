export interface ClipPlayEnv {
  IntersectionObserver: typeof IntersectionObserver;
  matchMedia: (query: string) => MediaQueryList;
  saveData?: boolean;
}

const MAX_PLAYING = 2;

export function setupClipPlay(
  videos: HTMLVideoElement[],
  { IntersectionObserver: Observer, matchMedia: match, saveData = false }: ClipPlayEnv,
): void {
  const mq = match('(prefers-reduced-motion: reduce)');
  const near = new Set<HTMLVideoElement>();
  const playing = new Set<HTMLVideoElement>();

  const sync = () => {
    for (const v of playing) {
      if (mq.matches || !near.has(v)) {
        playing.delete(v);
        v.pause();
      }
    }
    if (mq.matches || saveData) return;
    for (const v of near) {
      if (playing.size >= MAX_PLAYING) break;
      if (playing.has(v)) continue;
      playing.add(v);
      v.play().catch(() => {
        if (v.paused) playing.delete(v);
      });
    }
  };

  const observer = new Observer((entries) => {
    for (const entry of entries) {
      const v = entry.target as HTMLVideoElement;
      if (entry.isIntersecting) near.add(v);
      else near.delete(v);
    }
    sync();
  }, { rootMargin: '200px' });
  for (const v of videos) observer.observe(v);
  mq.addEventListener('change', sync);
}
