extends GutTest

## Legacy Damage v1 tests — file neutralized in Phase 5 of BuffEntity v2.
## Damage v2 dropped has_effect / get_effects_description and retyped
## effects: Array[BuffEntity]. Full rewrite will land in the Cyclops/DS2
## migration. Original bodies preserved in git history at c843633^.

func test_phase5_pending() -> void:
	pending("Phase 5: Damage v2 — legacy AttackEffect API removed; rewrite pending Cyclops/DS2 migration")
