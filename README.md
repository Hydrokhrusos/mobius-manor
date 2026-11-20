# Möbius Manor

*a house that does not add up*

A small first-person sandbox set in a non-euclidean house, built in **Godot 4.7** (Forward+, Jolt physics).
Everything — rooms, furniture, textures and sounds — is generated procedurally from GDScript; there are no imported assets.

**Play:** run `build/MobiusManor.exe` (a single self-contained file).

## The house

| Room | What's wrong with it |
|---|---|
| The Foyer | The front door opens into the middle of a hall. The painting is a window into the attic — sideways. |
| The Long Hallway | Its window looks down into the Great Hall from seven metres up. |
| The Bedroom | The wardrobe is bigger on the inside. Much bigger. |
| The Great Hall | A free-standing door frame: the front shows a sunny greenhouse, the back shows the foyer. Walk around it. |
| The Repeating Room | The east door leads in through the west door. You can see yourself. |
| The Endless Stairwell | The top landing is the bottom landing. Keep climbing and count the floors. |
| The Attic | Fall through the trapdoor and get spat out of the painting downstairs. |
| The Greenhouse | It is always noon in here. |

Find the 8 rubber ducks hidden around the house.

## Controls

| Key | Action | Key | Action |
|---|---|---|---|
| WASD | move | Mouse | look |
| Shift | sprint | Space | jump |
| Ctrl | crouch | LMB | grab / drop |
| RMB | throw | Wheel | hold distance |
| E | use / squeeze | R | rotate held object |
| C | paint | X | delete |
| 1–9 | spawn crate, ball, beach ball, duck, domino, chair, cube, pin, lamp | 0 | clear spawned |
| G | cycle gravity (normal / moon / zero) | T | slow motion |
| F | flashlight | V | fly / noclip |
| H | help | F11 | fullscreen |
| Esc | pause menu (sensitivity, portal quality, quit) | F3 | FPS counter |

## How the portals work

* Each portal is a rectangle; a pool of `SubViewport`s renders the view through the portals you can see,
  handed out best-first by screen coverage, up to three levels deep (portals seen through portals seen
  through portals). Portal surfaces sample that view in screen space, and a portal seen by several
  cameras gets one view per camera. Views fade with distance the same way at every level, so stepping
  through a portal never changes what you see.
* Instead of an oblique near plane, every material's shader discards fragments behind the *exit* portal.
  Each portal camera encodes its slot id in cull-mask bits 8–19 (`CAMERA_VISIBLE_LAYERS`), and the clip
  planes live in a small global float texture (`shaders/portal_common.gdshaderinc`).
* Portal views are rendered in linear HDR and tonemapped once by the main camera, so colours match exactly.
* The player and physics props teleport when they cross a portal plane; held objects keep being held
  through portals. Props and the player's own body half-way through a doorway get a copy on the other
  side, cut at the portal plane. Looping sounds and the flashlight also carry through portals.

## Project layout

```
scripts/main.gd            boot: input map, environment, world, player, portals, HUD
scripts/world.gd           procedural level builder (all rooms, portals, toys)
scripts/portal.gd          a single portal
scripts/portal_manager.gd  portal rendering, teleporting, raycasts through portals
scripts/player.gd          first-person controller, grabbing, spawning
scripts/props.gd/prop.gd   physics toys
scripts/hud.gd             title screen, prompts, pause menu
scripts/sfx.gd             synthesised sound effects and music box
scripts/tour.gd            debug screenshot tour / automated checks (`-- --tour --shots=<dir>`;
                           `--only=seam` / `--only=walkseam` compare the frames either side of each teleport)
shaders/                   procedural world shader, portal, glass, water
```

To edit: open `project.godot` in Godot 4.7. To rebuild the exe:
`Godot --headless --path . --export-release "Windows Desktop" build/MobiusManor.exe`
