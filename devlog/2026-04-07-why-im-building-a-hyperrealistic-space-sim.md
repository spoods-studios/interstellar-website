# Why I'm Building a Hyper-realistic Space Sim from Scratch

I've spent more hours than I'd like to admit in Kerbal Space Program. Plotting transfers, failing landings, and slowly building an intuition for orbital mechanics, I think. To be real I just watched Matt Lowne and Scott Manley videos and copied them until I figured out how to do it on my own. I have to admit that learning how to do efficient transfers, gravity assists, and hyper-efficient missions was fun and challenging. I learned a lot from it.

But I was a bit disappointed when I found out there was a gap. KSP simplifies — it has to. Patched conics instead of n-body gravity. Rails instead of persistent simulation. A solar system scaled down to make things manageable. And that's fine. KSP is a game first, and a brilliant one.

Then there's Orbiter. Orbiter doesn't simplify — it gives you the real solar system, real physics, real complexity. But it's a simulator first and a game a distant second.

I kept thinking: what if you didn't have to choose?

Then I found the KSP modding community. It's incredible — developers pouring in work that transforms the whole game. I got hooked on RSS/RO/RP-1 with Principia. It felt *real*. The gameplay loop had me running my own aerospace company on actual N-body physics — starting with tiny sounding rockets, researching better tech, sending the first guided rocket downrange, then the first two-stage sub-orbital hop, then the first orbit. The progression is earned. It takes real time and real effort, and that's exactly what makes it land. Then I found blackrack's volumetric clouds, Gamelinx's Parallax for ground scatter, and Sol, to me the most stunning visual overhaul KSP has. Together they make it breathtaking.

I've put thousands of hours into RP-1, probably more than base KSP. But it has rough edges. It crashes and stutters at random, even on a powerful machine. The screen fills with overlapping GUIs and telemetry from a dozen different mods. And the barrier to entry is steep — the tutorials are great, but the sheer volume of information turns people away. The ones who just want to bolt something ridiculous together and see if it'd survive a real launch. The ones who don't have time to grind contracts but still want that feeling of progression. The ones who want to build an understanding of engineering slowly, one concept at a time.

Those people are who I'm building for. I believe space and engineering should be open to everyone. I want to share both the knowledge and the plain joy of building something yourself, of feeling how vast our solar system and our universe really are. It's also why performance matters so much to me: I want it to run well, even on modest machines.

That's what I'm building. I don't have a name for it yet. But I'm calling the engine Interstellar Engine. It's being built from the ground up — no Unity, no Unreal, no shortcuts.

## Why from scratch?

Because the problems I want to solve don't fit inside someone else's engine.

Space is big. *Numerically* big. The distance from Earth to the Moon is about 384,400 kilometers. A 32-bit floating point number gives you roughly 7 digits of precision. That means at lunar distances, your physics calculations have meter-scale errors. At Jupiter? Kilometer-scale. The math just isn't accurate enough.

Existing engines weren't designed for this. They assume your world fits in a few square kilometers. My coordinate system uses 64-bit integers for storage, double-precision floats for physics, and single-precision floats only for rendering — with the camera origin shifting every frame to keep everything stable. It's more work. It's also the only way to get it right.

Gravity is the other reason. KSP uses patched conics: at any moment, only one body pulls on you. You switch between bodies at sphere-of-influence boundaries. It's a clever approximation, but it means you'll never see a Lagrange point. You can't simulate the three-body problem. The chaotic beauty of real orbital mechanics gets smoothed away.

I'm implementing n-body gravity with symplectic integrators — algorithms that conserve energy over long time spans rather than accumulating drift. 

## Why education matters to me

I didn't learn orbital mechanics in a classroom (well I eventually did, but my interest and intial knowledge came from KSP). I learned it by crashing into the Mun and wondering why my orbit kept changing when I thought I was going straight. Games taught me to ask questions that textbooks answered.

But games rarely close that loop. You develop intuition without vocabulary. You feel the physics without understanding the math. I want to build something that bridges that gap, where the real physics simply *is* the gameplay — you never have to pause for a lecture.

Imagine planning a mission and seeing the actual three-body dynamics at play. Imagine your spacecraft responding to the gravitational pull of every body in the system, not just the nearest one. Imagine a built-in knowledge base that explains *why* your orbit looks the way it does, connecting what you see to the equations behind it.

That's the educational platform I want to build — a game so accurate that the textbook emerges from playing it. I have always found learning by doing so much more effective than reading a boring textbook, taking tests. It encourages understanding, not memorizing terms, algorithms, and answers to pass a test. Real tests strip you of the resources you'd actually have available in the real world.

## Built from scratch, on purpose

No Unity, no Unreal — the engine is C++ and Vulkan, built from the ground up. That's far more work. It's also the only way to get the precision and control a simulation like this demands. The stack is deliberately boring everywhere it can be. I don't need a novel build system; I need a novel physics simulation.

And I hold all of it to one standard above everything else: it has to match reality. The physics gets checked against NASA's real measurements of where the planets actually are. If my Moon isn't where NASA says the Moon is, the code isn't done.

## Why solo, why now

I'm one person. That's a limitation and a freedom. I can't build everything at once, but I can build everything *right* and the way I want to. No compromises for a quarterly release schedule. No cutting corners on the physics because a producer needs a feature by Friday.

The roadmap is honest about this. Milestone 0.1 is rendering a triangle. That's it — the foundation has to be solid before anything else goes on top. After that comes the coordinate system, then basic orbits, then multi-body gravity. I understand the physics before I write the code. I validate the code against known data. Then I move on.

## What's next

Right now I'm in the infrastructure phase. The repo exists. The build system works.

The next milestone is Vulkan Bootstrap: a window, a triangle, no validation errors, clean shutdown. It's not exciting to look at. But it's the first brick.

If any of this resonates — the idea that games can teach real science, that accuracy and fun aren't mutually exclusive, that there's room for something between KSP and Orbiter — I'd love for you to follow along. The devlog will track everything: what I'm learning, what I'm building, what's working, and what spectacularly isn't.

This is day one. Let's see where it goes.
