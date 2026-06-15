# theme_colors.gd
# Semantic color palette for GDScript usage. Fixed component state StyleBox
# resources belong in global/theme/main_theme.tres instead — this file only
# holds dynamic gameplay-state colours (price deltas, condition labels, etc.).
class_name ThemeColors
extends RefCounted

const PROFIT_GREEN := Color(0.4, 1.0, 0.5)
const LOSS_RED := Color(1.0, 0.4, 0.4)
const WARNING_YELLOW := Color(0.95, 0.75, 0.3)
const ACCENT_GOLD := Color(0.92, 0.72, 0.18, 1)
const UNKNOWN_GRAY := Color(0.55, 0.58, 0.63, 1)
const DISABLED_GRAY := Color(0.45, 0.48, 0.53, 1)
const TEXT_SECONDARY := Color(0.7, 0.7, 0.7, 1)
const TEXT_HINT := Color(0.6, 0.6, 0.6, 1)
