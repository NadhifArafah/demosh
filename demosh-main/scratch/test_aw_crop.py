from PIL import Image
import numpy as np

AW_RAW = r"C:\Users\Attar Sanjaya\.gemini\antigravity\brain\08a206d0-f5c5-4e65-8bdd-4379be96d181\nikola_moving_jump_spritesheet_1782646295686.png"
img_aw = Image.open(AW_RAW).convert("RGBA")
aw_w, aw_h = img_aw.size
arr_aw = np.array(img_aw)

selected_aw_frames = [
    (0, 0, "stand_prep"),
    (1, 0, "run_lunge_prep"),
    (1, 1, "launch_push"),
    (0, 1, "rise_1"),
    (0, 2, "rise_2"),
    (0, 3, "rise_3"),
    (0, 4, "apex"),
    (1, 2, "fall"),
    (1, 3, "land"),
    (1, 4, "squat_recover")
]

# Custom Y bounds for each frame to isolate the single correct character
# (y1_offset, y2_offset) relative to row start
custom_y_bounds = {
    0: (0, 275),      # Row 0, Col 0: Top character only
    1: (0, 429),      # Row 1, Col 0: Bottom character only (top is empty)
    2: (0, 429),      # Row 1, Col 1: Bottom character only (top is empty)
    3: (0, 496),      # Row 0, Col 1: Character is at top (bottom empty)
    4: (0, 496),      # Row 0, Col 2: Character is at top (bottom empty)
    5: (0, 496),      # Row 0, Col 3: Character is at top (bottom empty)
    6: (0, 496),      # Row 0, Col 4: Character is at top (bottom empty)
    7: (0, 429),      # Row 1, Col 2: Character is at top (bottom empty)
    8: (207, 429),    # Row 1, Col 3: Bottom character only (crop top ghost)
    9: (0, 429)       # Row 1, Col 4: Bottom character only (top is empty)
}

print("Testing custom Y bounds cropping:")
for idx, (row, col, label) in enumerate(selected_aw_frames):
    if row == 0:
        cell_w = aw_w / 5
        x1 = int(col * cell_w)
        x2 = int((col + 1) * cell_w)
        row_y = 13
    else:
        cell_w = aw_w / 6
        x1 = int(col * cell_w)
        x2 = int((col + 1) * cell_w)
        row_y = 594
        
    y1_offset, y2_offset = custom_y_bounds[idx]
    y1 = row_y + y1_offset
    y2 = row_y + y2_offset
    
    cell = arr_aw[y1:y2+1, x1:x2]
    non_white = (cell[:, :, 0] < 250) | (cell[:, :, 1] < 250) | (cell[:, :, 2] < 250)
    active_y, active_x = np.where(non_white)
    
    if len(active_y) > 0:
        abs_min_y = y1 + active_y.min()
        abs_max_y = y1 + active_y.max()
        abs_min_x = x1 + active_x.min()
        abs_max_x = x1 + active_x.max()
        
        sw = abs_max_x - abs_min_x + 1
        sh = abs_max_y - abs_min_y + 1
        print(f"Frame {idx} ({label}): absolute_y=[{abs_min_y}, {abs_max_y}], size={sw}x{sh}")
    else:
        print(f"Frame {idx} ({label}): EMPTY")
