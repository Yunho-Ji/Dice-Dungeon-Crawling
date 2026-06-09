# Enums.gd
# DDC 프로젝트에서 공통으로 사용되는 열거형 정의
extends Node

enum Rarity {
	COMMON,
	UNCOMMON,
	RARE,
	EPIC,
	LEGENDARY
}

const RARITY_COLORS = {
	Rarity.COMMON: Color(0.8, 0.8, 0.8),    # White/Gray
	Rarity.UNCOMMON: Color(0.1, 0.9, 0.1),  # Green
	Rarity.RARE: Color(0.1, 0.5, 1.0),      # Blue
	Rarity.EPIC: Color(0.6, 0.2, 0.9),      # Purple
	Rarity.LEGENDARY: Color(1.0, 0.6, 0.0)  # Gold/Orange
}

const RARITY_NAMES = {
	Rarity.COMMON: "Common",
	Rarity.UNCOMMON: "Uncommon",
	Rarity.RARE: "Rare",
	Rarity.EPIC: "Epic",
	Rarity.LEGENDARY: "Legendary"
}
