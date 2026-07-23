# title_art.gd
# Draws "PRIMORDIAL COUNTDOWN" as blocky pixel text via _draw().
# Each letter is defined as a grid of filled/empty cells.
extends Control

const CELL: int = 3 # pixel size of each cell
const GAP: int = 1  # gap between letters in cells
const LINE_GAP: int = 2 # gap between lines in cells

# 5-tall monospaced pixel font — each letter is a list of 5 row bitmasks.
# Width is encoded per-letter (most are 3-wide, some are 4 or 5).
const FONT: Dictionary = {
	"P": { "w": 3, "rows": [0b111, 0b101, 0b111, 0b100, 0b100] },
	"R": { "w": 3, "rows": [0b111, 0b101, 0b111, 0b110, 0b101] },
	"I": { "w": 3, "rows": [0b111, 0b010, 0b010, 0b010, 0b111] },
	"M": { "w": 5, "rows": [0b10001, 0b11011, 0b10101, 0b10001, 0b10001] },
	"O": { "w": 3, "rows": [0b111, 0b101, 0b101, 0b101, 0b111] },
	"D": { "w": 4, "rows": [0b1110, 0b1001, 0b1001, 0b1001, 0b1110] },
	"A": { "w": 3, "rows": [0b111, 0b101, 0b111, 0b101, 0b101] },
	"L": { "w": 3, "rows": [0b100, 0b100, 0b100, 0b100, 0b111] },
	"C": { "w": 3, "rows": [0b111, 0b100, 0b100, 0b100, 0b111] },
	"N": { "w": 4, "rows": [0b1001, 0b1101, 0b1011, 0b1001, 0b1001] },
	"U": { "w": 3, "rows": [0b101, 0b101, 0b101, 0b101, 0b111] },
	"T": { "w": 3, "rows": [0b111, 0b010, 0b010, 0b010, 0b010] },
	"W": { "w": 5, "rows": [0b10001, 0b10001, 0b10101, 0b11011, 0b10001] },
	" ": { "w": 2, "rows": [0b00, 0b00, 0b00, 0b00, 0b00] },
}

@export var text_line_1: String = "PRIMORDIAL"
@export var text_line_2: String = "COUNTDOWN"
@export var primary_color: Color = Color("4ecdc4")   # Teal
@export var shadow_color: Color = Color("1a1a2e")     # Dark navy


func _draw() -> void:
	var lines: Array[String] = [text_line_1, text_line_2]
	# Calculate total height for centering.
	var line_height: float = float(5 * CELL)
	var total_h: float = float(lines.size()) * line_height + float(lines.size() - 1) * float(LINE_GAP * CELL)
	var start_y: float = (size.y - total_h) / 2.0

	for li: int in range(lines.size()):
		var line_text: String = lines[li]
		var line_w: float = _measure_line(line_text)
		var start_x: float = (size.x - line_w) / 2.0
		var y_off: float = start_y + float(li) * (line_height + float(LINE_GAP * CELL))
		_draw_text_line(line_text, start_x, y_off)


func _draw_text_line(text: String, start_x: float, start_y: float) -> void:
	var cursor_x: float = start_x
	for i: int in range(text.length()):
		var ch: String = text[i]
		var upper: String = ch.to_upper()
		if not FONT.has(upper):
			cursor_x += float((3 + GAP) * CELL)
			continue
		var glyph: Dictionary = FONT[upper]
		var w: int = glyph["w"]
		var rows: Array = glyph["rows"]
		for row_i: int in range(rows.size()):
			var bits: int = rows[row_i]
			for col_i: int in range(w):
				if bits & (1 << (w - 1 - col_i)):
					var px: float = cursor_x + float(col_i * CELL)
					var py: float = start_y + float(row_i * CELL)
					# Shadow.
					draw_rect(Rect2(px + 1.0, py + 1.0, float(CELL), float(CELL)), shadow_color)
					# Main color.
					draw_rect(Rect2(px, py, float(CELL), float(CELL)), primary_color)
		cursor_x += float((w + GAP) * CELL)


func _measure_line(text: String) -> float:
	var total: float = 0.0
	for i: int in range(text.length()):
		var ch: String = text[i]
		var upper: String = ch.to_upper()
		if FONT.has(upper):
			var glyph: Dictionary = FONT[upper]
			var w: int = glyph["w"]
			total += float((w + GAP) * CELL)
		else:
			total += float((3 + GAP) * CELL)
	return total - float(GAP * CELL) # Remove trailing gap.
