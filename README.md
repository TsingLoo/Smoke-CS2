# Replicate the Smoke Grenade in Counter-Strike 2 - Final Project

Using Unity 2022.3.62f3, URP 14.0.12

## Showcase

- Environment Collision

  ![Environment Collision](./imgs/Unity_fZfXEI1LSo.gif)

- Physics Interaction

![Physics Interaction](./imgs/PotPlayerMini64_8lXx9hqM2K.gif)

- Dynamic lighting & shadow

  ![Dynamic Lighting](./imgs/PotPlayerMini64_I8TSCuyy1G.gif)

- Pipeline Integration (Transparent & Post processing friendly)

  ![Pipeline Integration](./imgs/Unity_HMVeBNmfhG.gif)

## Feature

- **High Performance & Compatibility:** No scene voxelization or pre-computation required
- **Environment Collision:** Smoke automatically fills spaces and adapts to geometry without leaking
- **Dynamic Lighting:** Reacts to directional scene lighting and casts realistic shadows
- **Physics Interaction:** Supports projectile penetration and dispersal, similar to *Counter-Strike 2*
- **Fully Customizable:** Extensive parameter controls exposed directly via the Inspector
- **Pipeline Integration:** Optimized rendering order ensures compatibility with transparency and post-processing effects



# Proposal


![](./imgs/chrome_DuYKX3Tll0.gif)

## Design Overview:

This project will implement a procedural responsive volume smoke system, replicating the behavior seen in *Counter-Strike 2*. The system will create dynamic, volumetric smoke that realistically fills spaces, interacts with the environment, and renders with high visual fidelity.

The implementation will be primarily based on the techniques demonstrated by [Acerola in "I Tried Recreating Counter Strike 2's Smoke Grenades"](https://www.youtube.com/watch?v=ryB8hT5TMSg).

## Core Features:
The implementation will include the following features:
1. Vision Block: The smoke volume will be dense enough to block player vision.
2. Space Filling: The smoke will originate from a point and expand to fill the available volume, conforming to level geometry.
3. Dynamic Interaction: The smoke will react to game events:
	- Bullets: Passing bullets will create temporary, see-through holes.
	- Explosions: Explosive grenades will create a temporary pressure wave that pushes the smoke away.

4. High-Fidelity Visuals: The smoke will be rendered with real-time lighting, self-shadowing, and detailed noise to create a realistic, non-uniform cloud [20:56], [21:15].

5. Physical Dynamics: The smoke will exhibit physically-guided behavior, such as a slow downward drift over time

## The Plan
The system is broken into three main components: static scene processing, real-time simulation, and real-time rendering.

### Scene Voxelization (Milestone 1)

The static level geometry will be backed into a 3D voxel grid. It will output a 3D texture or compute buffer where each cell stores a binary value (e.g., `1` for solid, `0` for empty space). This grid defines the boundaries for the smoke simulation.

### Smoke Simulation & Rendering Ⅰ (Milestone 2)

 A **"Limited Flood Fill"** algorithm will be used to handle the smoke's expansion and dynamics. When a grenade detonates, its origin voxel is "seeded" with a maximum energy value. In each simulation step, "energy" propagates to adjacent, empty (non-static) voxels. The new voxel's energy is set to `max(neighbor_energy) - 1`. 

A ray will be marched from the camera through the scene. At each step, the shader will sample the smoke density from the simulation grid. Density is integrated according to **Beer's Law** to calculate light absorption.  To calculate lighting, a second, cheaper ray march is performed from the current sample point towards the sun (light source). This determines how much light reaches that point, creating self-shadowing.

### Smoke Rendering Ⅱ & Interaction (Final Submission)

Some 3D noise is sampled during the ray march. The noise is combined with the energy value from the flood fill. Density will fall off near the "edge" (where energy is low), using the noise to create detailed, wispy edges. A list of active holes (position, direction, timer) is maintained on the CPU and sent to the GPU. An easing function expands the hole and then slowly shrinks it. If the sample point is inside a hole's SDF, density is set to 0.
