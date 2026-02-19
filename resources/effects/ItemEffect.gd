extends Resource
class_name ItemEffect

# Base class for all item effects.
# This class follows the Strategy Pattern.

## Applies the effect to the target character.
## Must be overridden by child classes.
func apply(target: Character):
	printerr("ItemEffect: apply() must be implemented by child class.")

## Removes the effect from the target character.
## Must be overridden by child classes.
func remove(target: Character):
	printerr("ItemEffect: remove() must be implemented by child class.")

## Optional: Returns a description of the effect for UI tooltips.
func get_description() -> String:
	return "Unknown Effect"
