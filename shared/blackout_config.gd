class_name BlackoutConfig
extends RefCounted

## Centralized configuration for the BLACKOUT mechanic.

## Default duration of the active Blackout in seconds (configurable).
const DEFAULT_BLACKOUT_DURATION_SEC: float = 60.0

## Default activation countdown in seconds before Blackout activates.
const DEFAULT_COUNTDOWN_DURATION_SEC: float = 3.0

## Maximum number of Blackout activations allowed per match.
const MAX_BLACKOUT_ACTIVATIONS: int = 1
