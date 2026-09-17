# Vehicle component geometry contract

`vehicle_component_geometry.v1.json` is the canonical, versioned geometry contract for the vehicle component picker. It contains a complete generic vehicle composition for the Top, Front, Rear, Left, and Right views, plus the primary selectable occurrence of every current canonical `VehicleComponentId`.

## Provenance and ownership

- **Created:** 2026-09-16
- **Author:** AutoDentifyr project team
- **Ownership:** Copyright © 2026 AutoDentifyr contributors. The paths are original project-authored generic vehicle geometry and are licensed with the repository under its applicable project license.
- **Source format:** Hand-authored JSON using SVG path-data commands; no source image, OEM drawing, vendor asset, tracing, or generated artwork was used.
- **Editable source:** `vehicle_component_geometry.v1.json` is the source of record. There is no generated binary counterpart.

## Contract rules

All paths use the normalized 1000 × 600 canvas declared in `coordinateSystem`. A renderer must apply one shared transform to painting, hit testing, focus bounds, and semantic bounds. `visualPath` paints the region; `hitPath` is independently authored and deliberately larger to create an accessible touch target. Never infer a hit region from SVG bounds, painting order, or a visual path.

`semanticsOrder` is stable within a view and is the required traversal order. The rendering layer owns labels and selection state; the geometry contract owns only stable canonical IDs, shapes, and ordering.

## Modification policy

Treat every release of this file as immutable once persisted assessment evidence or screenshots depend on it. Make an additive `vehicle_component_geometry.v<N>.json` for a materially changed path, canonical coverage change, coordinate-system change, or interaction-affecting hit region. Keep the old contract available until its consumers are retired. Update `CHECKSUMS.sha256` after any edited asset; it intentionally contains hashes of other files only and no asset embeds its own hash.
