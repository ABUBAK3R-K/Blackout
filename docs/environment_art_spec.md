# BLACKOUT — 2D Environment & Technical Art Specification

> **Document Version:** 1.0  
> **Lead / Owner:** Member 7 — Fatima (2D Environment & Technical Artist)  
> **Branch:** `member-7/environment-art`  
> **Engine:** Godot Engine 4.3 (GL Compatibility)  
> **Target Viewport:** 1280 × 720 (Stretch mode: `canvas_items`)  

---

## 1. Executive Summary & Scope

This specification establishes the visual and architectural standards for all 2D environment art, lighting setups, interactive station props, character sprite sheets, and visual effects in **BLACKOUT**. 

As Member 7, the objective is to deliver high-tension, atmospheric visual presentation that directly supports the core game loop:
1. **Normal Facility Phase:** Crisp, clinical, well-lit scientific laboratory.
2. **Blackout Phase:** Oppressive, claustrophobic darkness punctuated by flashing red emergency sirens and narrow player flashlight beams.
3. **Investigation & Evidence Phase:** Legible visual crime scenes and manipulated props.
4. **Meltdown Climax:** Escalating reactor heat distortion, sirens, steam, and warning hazards.

---

## 2. Technical Engine Standards

### 2.1 Grid & Resolution
- **Base Grid Unit:** 32 × 32 pixels per tile.
- **Player Sprite Standard:** 32 × 48 pixels (occupies 1 × 1.5 grid cells).
- **Interactive Station Standard:** 64 × 64 pixels (2 × 2 grid cells) or 64 × 32 pixels.
- **Reference Viewport:** 1280 × 720 px.
- **Texture Filtering:** `Nearest` (pixel art precision) or `Linear` with crisp edge mipmaps.

### 2.2 Collision Layers & Physics Masks
To ensure clean integration with Member 3 (Client Engine / Player Controller):

| Layer Index | Layer Name | Description |
|---|---|---|
| **Layer 1** | `World / Obstacles` | Static solid walls, perimeter bulkheads, solid consoles. |
| **Layer 2** | `Players` | Player character collision capsules (radius: 12px, height: 28px). |
| **Layer 3** | `Stations / Interactables` | Triggers for task mini-games and sabotage interactions. |
| **Layer 4** | `Vision Occluders` | `LightOccluder2D` geometry for dynamic shadow-casting. |
| **Layer 5** | `Evidence Markers` | Inspection area boundaries for post-blackout investigation. |

### 2.3 Render Sorting (Y-Sort & Z-Index)
- **Z-Index -1 / 0:** Floor tiles, corridor carpeting, painted hazard stripes.
- **Z-Index 1 (Y-Sort Enabled):** Characters, interactive stations, chairs, desks, computer terminals.
- **Z-Index 2:** Wall tops, ceiling overhangs, doorway arches (players walk underneath).
- **Z-Index 5:** Particle effects (sparks, steam, smoke).
- **Z-Index 10:** `CanvasModulate` (Darkness / Global lighting layer).
- **Z-Index 100+:** HUD, mini-game modals, voting screens (Member 5).

---

## 3. 9-Room Spatial Layout & Dimensions

The facility layout comprises 9 distinct functional rooms connected by 4-tile-wide (128px) corridors and airlock blast doors.

```
       [ Storage ] ---------- [ Server Room ] ---------- [ MedBay ]
            |                        |                       |
            |                        |                       |
   [ Generator Room ] ------- [ Cafeteria (Spawn) ] --- [ Executive Office ]
            |                        |                       |
            |                        |                       |
    [ Security Room ] ------- [ Laboratory ] ---------- [ ORION Core ]
```

### Detailed Room Specifications

| # | Room ID | Display Name | Size (Tiles) | Dimensions (px) | Gameplay Purpose & Key Props |
|---|---|---|---|---|---|
| 1 | `cafeteria` | **Cafeteria** | 28 × 20 | 896 × 640 | Central spawn hub, 4 dining tables, central emergency meeting console, vending machines. |
| 2 | `security_room` | **Security Room** | 16 × 14 | 512 × 448 | Surveillance desk with 4 monitor screens, Security Relay recovery unit, scrambled camera evidence marker. |
| 3 | `laboratory` | **Laboratory** | 20 × 16 | 640 × 512 | Chemical fume hoods, centrifuges, specimen lockers, research desks. |
| 4 | `server_room` | **Server Room** | 18 × 16 | 576 × 512 | Server tower aisles, blinking LED panels, Data Transfer terminal, cable flooring. |
| 5 | `storage` | **Storage** | 20 × 16 | 640 × 512 | Metal crates, fuel canisters, pallet jacks, maintenance lockers (hiding spots). |
| 6 | `generator_room` | **Generator Room** | 22 × 18 | 704 × 576 | Main high-voltage power generator, transformer coils, severed cable sabotage prop, backup battery bank. |
| 7 | `executive_office`| **Executive Office** | 16 × 14 | 512 × 448 | Mahogany desk, leather chair, bookshelf, locked safe / classified file cabinet prop. |
| 8 | `medbay` | **Medical Bay** | 18 × 16 | 576 × 512 | 3 examination beds, vital monitor displays, medicine dispensers, biometric scanner. |
| 9 | `orion_core` | **ORION Core** | 26 × 26 | 832 × 832 | Central pulsing reactor core, containment magnetic ring, 3 Meltdown stabilization terminals. |

---

## 4. Dual-State Lighting Architecture

BLACKOUT features two distinct atmospheric lighting states toggled server-authoritatively.

### 4.1 Normal Facility State
- **Ambient Illumination:** `CanvasModulate` set to `#d8e2ec` (90% brightness, soft neutral-cool facility tone).
- **Room Lights:** Ceiling fluorescent panels using `PointLight2D` with soft falloff textures.
  - Energy: `1.0`
  - Color: `#fff8e7` (warm white)
  - Range / Attenuation: `256px` radius, `1.5` attenuation factor.
- **Terminal Glows:** Small accent lights on screens (Cyan `#00e5ff`, Amber `#ffb300`).

### 4.2 Emergency Blackout State
- **Ambient Illumination:** `CanvasModulate` dropped to `#080b12` (extreme darkness, ~8% ambient visibility).
- **Emergency Sirens:**
  - Placed in corridor intersections and key room centers.
  - Strobe animation: Energy oscillating between `0.2` and `2.0` at `1.2 Hz`.
  - Color: `#ff1a35` (vivid emergency crimson).
  - Shadows enabled on `LightOccluder2D` walls to create sweeping alarm shadows.
- **Player Flashlight (Vision Cone):**
  - Attached to each player node.
  - Forward 70° spotlight beam (range: `240px`) + subtle radial personal glow (`48px`).
  - Color: `#f0f4ff` with smooth edge falloff.

---

## 5. Station & Interactive Prop Visual States

Every station has 4 distinct visual representation states to ensure instant legibility:

```
[ INTACT / IDLE ]  --->  [ SABOTAGED / DAMAGED ]
       |                         |
       v                         v
[ ACTIVE / USING ] <---  [ BEING REPAIRED ]
       |                         |
       +-------> [ RESTORED ] <--+
```

| State | Visual Characteristics | VFX / Lighting Cue |
|---|---|---|
| **Intact / Operational** | Green status LED (`#00e676`), normal UI screen display, clean casing. | Constant subtle green glow (Energy `0.3`). |
| **Sabotaged / Damaged** | Red warning LED (`#ff1744`), cracked glass/open panel, sparking wires. | Intermittent electrical spark burst + red pulse. |
| **Being Interacted / Repaired**| Yellow/amber progress LED (`#ffd600`), highlighted outline shader. | Active golden highlight border (2px). |
| **Restored / Completed** | Reboot sequence animation, green confirmation flash, sound cue anchor. | Single bright green flash expanding ring. |

### Station Visual Mapping (to Server Configuration)

| Station ID | Location | Normal Prop Art | Sabotaged / Damaged Clue Art |
|---|---|---|---|
| `repair_power` | `generator_room` | Main electrical distribution panel. | Open breaker door with dangling cut wire. |
| `stabilize_orion` | `orion_core` | ORION reactor stabilization console. | Overheating console with smoking vents. |
| `server_calibration` | `server_room` | Central server rack maintenance terminal. | Glitching monitor with red error prompt. |
| `security_repair` | `security_room` | Camera matrix routing box. | Severed coax cables hanging loose. |
| `medical_supply_check` | `medbay` | Pharmacy cabinet & biometric locker. | Unlocked medicine safe with ajar doors. |
| `data_transfer` | `server_room` | High-speed data uplink terminal. | Unauthorized thumbdrive / download prompt. |
| `door_repair` | `cafeteria` / corridors | Pneumatic airlock door mechanism. | Jammed hydraulic piston with hydraulic fluid leak. |
| `coolant_system` | `orion_core` | Coolant valve pressure manifold. | Hissing vapor valve with frosty floor puddle. |
| `laboratory_org` | `laboratory` | Chemical sample sorting centrifuge. | Misaligned sample racks and chemical stain. |
| `backup_power` | `storage` | Diesel/battery auxiliary generator unit. | Tripped red emergency cutoff switch. |

---

## 6. Discoverable Evidence Visual Markers (Post-Blackout)

When Blackout ends and the match enters `POST_BLACKOUT_INVESTIGATION`, evidence spots generate physical markers on the map corresponding to `shared/evidence_config.gd`:

1. **`CLASSIFIED_FILES_MISSING` (`executive_office`):**
   - Ransacked file cabinet, open bottom drawer with empty folders and scattered papers on carpet.
2. **`ORION_CORE_DATA_EXTRACTED` (`orion_core`):**
   - Terminal screen showing "EXTERNAL TRANSFER COMPLETE — 100%" with flashing amber warning.
3. **`ORION_CONTAINMENT_DISABLED` (`orion_core`):**
   - Disengaged magnetic containment arm retracted into floor, warning hazard stripes exposed.
4. **`GENERATOR_SABOTAGED` (`generator_room`):**
   - Heavy 3-phase trunk cable severed with burnt black scorch marks on concrete floor.
5. **`SECURITY_TAMPERED` (`security_room`):**
   - Security camera console displaying scrambled monochrome TV static across feeds 1, 2, and 4.

---

## 7. 2D Player Character Sprite Standards

### 7.1 Palette Assignments (8 Players)
Players are assigned one of 8 distinct suit colors:
1. `#e53935` — **Crimson Red**
2. `#1e88e5` — **Cobalt Blue**
3. `#43a047` — **Emerald Green**
4. `#fdd835` — **Vivid Yellow**
5. `#fb8c00` — **Safety Orange**
6. `#8e24aa` — **Deep Purple**
7. `#00acc1` — **Electric Cyan**
8. `#eceff1` — **Arctic White**

### 7.2 Animation State Machine
- **Idle (4 directions):** 2 frames (subtle vertical 1px breathing bob, 1.0 fps).
- **Walk (4 directions):** 4 frames (smooth stride with footstep contact points, 8.0 fps).
- **Interact / Use:** 2 frames (arms extended toward station console).
- **Sabotage:** 2 frames (covert glance and tool usage).
- **Ghost (Eliminated):** 2 frames (translucent 50% alpha, floating hover animation).

---

## 8. Visual Effects (VFX) Catalog

### 8.1 Particle Systems (`GPUParticles2D`)
- **`vfx_electrical_sparks`:** High-speed, gravity-affected yellow-orange sparks with 0.3s lifetime and bounce.
- **`vfx_coolant_steam`:** Soft white-cyan expanding steam puffs rising with upward drift and fade-out.
- **`vfx_alarm_strobe`:** Radial red light flare expanding from sirens during blackout.

### 8.2 Custom Shaders
- **`meltdown_distortion.gdshader`:** Screen-reading shader applied to `ColorRect` over the ORION Core chamber. Distorts pixels using sinusoidal UV ripple and scales intensity with the 5-minute Meltdown countdown timer.
- **`vision_vignette.gdshader`:** Smooth black radial darkening around screen edges to enhance claustrophobic atmosphere during Blackout.
- **`interactable_outline.gdshader`:** 1px golden outline rendered around prop sprites when player is within interaction distance.

---

## 9. Delivery Milestones & File Roadmap

- [x] Phase 1: Directory initialization & technical art specification (`docs/environment_art_spec.md`).
- [x] Phase 2: Base lighting texture assets (`flashlight_mask.png`, `radial_light_cookie.png`, `vignette_mask.png`), `facility_lighting_controller.tscn`, `player_flashlight.tscn`, `vignette_overlay.tscn`, and automated test suite (`tests/test_facility_lighting_controller.gd`).
- [ ] Phase 3: Modular 32×32 tileset resources & room prop sprites (`assets/sprites/environment/`).
- [ ] Phase 4: Full 9-room master facility map scene (`scenes/environment/facility_map.tscn`).
- [ ] Phase 5: Station visual states & evidence marker props (`assets/sprites/stations/`).
- [ ] Phase 6: Player character sprite sheets (8 colors, 4 directions) & animation controller.
- [ ] Phase 7: VFX particle presets & Meltdown heat distortion shader (`assets/vfx/`).
