# Why I'm Building a Hyperrealistic Space Sim from Scratch

I've spent more hours than I'd like to admit in Kerbal Space Program. Plotting transfers, failing landings, and slowly building an intuition for orbital mechanics, I think. To be real I just watched Matt Lowne and Scott Manley videos and copied them until I figured out how to do it on my own. I have to admit that learning how do efficient transfers, gravity assists, and hyper-efficient missions was fun, challenging and I learned a lot. 

But I was a bit disappointed when I found out there was a gap. KSP simplifies — it has to. Patched conics instead of n-body gravity. Rails instead of persistent simulation. A solar system scaled down to make things manageable. And that's fine. KSP is a game first, and a brilliant one.

Then there's Orbiter. Orbiter doesn't simplify. It gives you the real solar system, real physics, real complexity. But it's a simulator first and a game... distant second. 

I kept thinking: what if you didn't have to choose?

What if there was something with the fun of KSP and the accuracy of Orbiter, with an educational layer that didn't just let you play with physics but actually *taught* you what was happening and why?

That's what I'm building. I don't have a name for it yet. But I'm calling the engine Interstellar Engine, and it's being built from the ground up — no Unity, no Unreal, no shortcuts.

## Why from scratch?

Because the problems I want to solve don't fit inside someone else's engine.

Space is big. *Numerically* big. The distance from Earth to the Moon is about 384,400 kilometers. A 32-bit floating point number gives you roughly 7 digits of precision. That means at lunar distances, your physics calculations have meter-scale errors. At Jupiter? Kilometer-scale. The math just isn't accurate enough. 

Existing engines weren't designed for this. They assume your world fits in a few square kilometers. My coordinate system uses 64-bit integers for storage, double-precision floats for physics, and single-precision floats only for rendering — with the camera origin shifting every frame to keep everything stable. It's more work. It's also the only way to get it right.

Gravity is the other reason. KSP uses patched conics — the idea that at any moment, only one body is pulling on you, and you switch between them at sphere-of-influence boundaries. It's a clever approximation, but it means you'll never see a Lagrange point. You can't simulate the three-body problem. The chaotic beauty of real orbital mechanics gets smoothed away.

I'm implementing n-body gravity with symplectic integrators — algorithms that conserve energy over long time spans rather than accumulating drift. Leapfrog for fast cases, Yoshida for when precision matters. Every formula in the codebase has to be understood, not copy-pasted. If I can't explain it, it doesn't go in until I can explain it to a 4-year-old. 

## Why education matters to me

I didn't learn orbital mechanics in a classroom. I learned it by crashing into the Mun and wondering why my orbit kept changing when I thought I was going straight. Games taught me to ask questions that textbooks answered.

But games rarely close that loop. You develop intuition without vocabulary. You feel the physics without understanding the math. I want to build something that bridges that gap — not by pausing the game and showing you a lecture, but by making the real physics *be* the gameplay.

Imagine planning a mission and seeing the actual three-body dynamics at play. Imagine your spacecraft responding to the gravitational pull of every body in the system, not just the nearest one. Imagine a built-in knowledge base that explains *why* your orbit looks the way it does, connecting what you see to the equations behind it.

That's the educational platform I want to build. Not a textbook with a game strapped on — a game so accurate that the textbook emerges from playing it. I have always found learning by doing, so much more effective then reading a boring textbook, taking tests. It encourages actual learning and understanding concepts, rather then memorizing terms, algorithms and answers so you can pass a test where you are stripped of all the resources you would realistically always have available to you in the real world.

## What this actually looks like technically

The engine is C++20 with Vulkan 1.3. I chose Vulkan because I need explicit control over the rendering pipeline — atmospheric scattering, multiple depth buffers for different scales, the kind of rendering that needs you to think about every draw call. The ECS is EnTT. Physics runs in double precision. Rendering happens in single precision with per-frame origin shifting.

I'm building this on Windows with MSVC, using CMake and vcpkg. The stack is deliberately boring where it can be — I don't need a novel build system. I need a novel physics simulation.

There's a rule I've set for myself: the Three-Review Gate. Any physics, math, or science system needs to be independently verified by three qualified reviewers before it's considered done. Not peer review as a formality — real verification against real reference data. My integrator will be tested against JPL ephemeris data. If my Moon isn't where NASA says the Moon is, the code isn't done.

## Why solo, why now

I'm one person. That's a limitation and a freedom. I can't build everything at once, but I can build everything *right*. No compromises for a quarterly release schedule. No cutting corners on the physics because a producer needs a feature by Friday.

The roadmap is honest about this. Milestone 0.1 is rendering a triangle. Not a planet, not an orbit — a triangle. Because the foundation has to be solid before anything else goes on top. After that comes the coordinate system, then basic orbits, then multi-body gravity. Each milestone follows a cycle: study, implement, validate, review, lock. I learn the physics before I write the code. I validate the code against known data. I get it reviewed. Then I move on.

I've never seen other games do this, every. Because it'll take years. I'm fine with that.

## What's next

Right now I'm in the infrastructure phase. The repo exists. The build system works. The documentation vault is set up. 

The next milestone is Vulkan Bootstrap: a window, a triangle, no validation errors, clean shutdown. It's not exciting to look at. But it's the first brick.

If any of this resonates — the idea that games can teach real science, that accuracy and fun aren't mutually exclusive, that there's room for something between KSP and Orbiter — I'd love for you to follow along. The devlog will track everything: what I'm learning, what I'm building, what's working, and what spectacularly isn't.

This is day one. Let's see where it goes.
