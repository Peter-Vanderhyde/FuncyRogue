# map.fy — dungeon grid helpers + procedural generation
import "config.fy";

func inBounds(x, y) {
    if x < 0 or y < 0 { return false; }
    if x >= MAP_W or y >= MAP_H { return false; }
    return true;
}

func makeGrid(fill) {
    g = [];
    for y = 0, y < MAP_H, y += 1 {
        row = [];
        for x = 0, x < MAP_W, x += 1 { row.append(fill); }
        g.append(row);
    }
    return g;
}

func carveCell(grid, x, y, ch) { if inBounds(x, y) { grid[y][x] = ch; } }

func carveRoom(grid, rx, ry, rw, rh) {
    y2 = ry + rh - 1; x2 = rx + rw - 1;
    for y = ry, y <= y2, y += 1 {
        for x = rx, x <= x2, x += 1 { carveCell(grid, x, y, "."); }
    }
}

func carveHTunnel(grid, x1, x2, y) {
    a = x1; b = x2; if a > b { tmp = a; a = b; b = tmp; }
    for x = a, x <= b, x += 1 { carveCell(grid, x, y, "."); }
}

func carveVTunnel(grid, y1, y2, x) {
    a = y1; b = y2; if a > b { tmp = a; a = b; b = tmp; }
    for y = a, y <= b, y += 1 { carveCell(grid, x, y, "."); }
}

func rectsOverlap(r1, r2, pad) {
    x1 = r1["x"] - pad; y1 = r1["y"] - pad;
    w1 = r1["w"] + 2*pad; h1 = r1["h"] + 2*pad;
    x2 = r2["x"]; y2 = r2["y"]; w2 = r2["w"]; h2 = r2["h"];
    if x1 + w1 <= x2 { return false; }
    if x2 + w2 <= x1 { return false; }
    if y1 + h1 <= y2 { return false; }
    if y2 + h2 <= y1 { return false; }
    return true;
}

func centerOf(room) {
    cx = room["x"] + (room["w"] // 2);
    cy = room["y"] + (room["h"] // 2);
    return [cx, cy];
}

func getThemeForDepth(depth) {
    # Cycle through themes: Caves -> Catacombs -> Forge -> repeat
    theme_index = (depth - 1) % 3;
    if theme_index == 0 { return "caves"; }
    elif theme_index == 1 { return "catacombs"; }
    else { return "forge"; }
}

func generateMap(depth) {
    theme = getThemeForDepth(depth);
    
    # Declare all variables first
    ROOM_ATTEMPTS = 60;
    MIN_W = 4;  MAX_W = 10;
    MIN_H = 3;  MAX_H = 8;
    SEP_PAD = 1;
    
    # Theme-specific generation parameters
    if theme == "caves" {
        # Caves: cellular rooms (organic), lakes; slimes, bats; fewer doors
        ROOM_ATTEMPTS = 80;  # More room attempts for organic feel
        MIN_W = 3;  MAX_W = 12;  # More varied room sizes
        MIN_H = 2;  MAX_H = 10;
        SEP_PAD = 2;  # More spacing between rooms
    } elif theme == "catacombs" {
        # Catacombs: narrow rooms, long corridors; skeletons; more traps
        ROOM_ATTEMPTS = 40;  # Fewer, more focused rooms
        MIN_W = 3;  MAX_W = 8;   # Narrower rooms
        MIN_H = 2;  MAX_H = 6;
        SEP_PAD = 1;  # Tighter spacing
    } elif theme == "forge" {
        # Forge: lava pockets (fire damage), golems; weapon loot up
        ROOM_ATTEMPTS = 50;  # Medium room count
        MIN_W = 5;  MAX_W = 11;  # Larger rooms for forge feel
        MIN_H = 4;  MAX_H = 9;
        SEP_PAD = 1;  # Standard spacing
    }
    
    

    grid = makeGrid("#");
    rooms = [];
    
    # Declare room dimension variables at function level
    rw = 6;  # Default fallback values
    rh = 4;

    attempts = 0;
    while attempts < ROOM_ATTEMPTS {
        attempts = attempts + 1;

        # Ensure MIN values are always less than MAX values
        if MIN_W >= MAX_W { MIN_W = MAX_W - 1; }
        if MIN_H >= MAX_H { MIN_H = MAX_H - 1; }
        
                         # Safety check - ensure ranges are valid and set room dimensions
                 if MIN_W < MAX_W and MIN_H < MAX_H {
                     rw = randInt(MIN_W, MAX_W);
                     rh = randInt(MIN_H, MAX_H);
                 } else {
                     # If ranges are invalid, rw and rh keep their default values
                     continue;
                 }

        rx = randInt(1, MAP_W - rw - 2);
        ry = randInt(1, MAP_H - rh - 2);

        newr = { "x": rx, "y": ry, "w": rw, "h": rh };

        ok = true;
        for i = 0, i < length(rooms), i += 1 {
            if rectsOverlap(newr, rooms[i], SEP_PAD) { ok = false; break; }
        }
        if not ok { continue; }

        carveRoom(grid, rx, ry, rw, rh);
        rooms.append(newr);

        if length(rooms) > 1 {
            prev = rooms[length(rooms) - 2];
            c1 = centerOf(prev); c2 = centerOf(newr);
            if randInt(0, 1) == 0 {
                carveHTunnel(grid, c1[0], c2[0], c1[1]);
                carveVTunnel(grid, c1[1], c2[1], c2[0]);
            } else {
                carveVTunnel(grid, c1[1], c2[1], c1[0]);
                carveHTunnel(grid, c1[0], c2[0], c2[1]);
            }
        }
    }

    if length(rooms) == 0 {
        rw = 6; rh = 4; rx = (MAP_W - rw) // 2; ry = (MAP_H - rh) // 2;
        carveRoom(grid, rx, ry, rw, rh);
        rooms.append({ "x": rx, "y": ry, "w": rw, "h": rh });
    }

    start = centerOf(rooms[0]); px = start[0]; py = start[1];
    if not inBounds(px, py) { px = 1; py = 1; }

    last = rooms[length(rooms) - 1]; exy = centerOf(last);
    ex = exy[0]; ey = exy[1]; if not inBounds(ex, ey) { ex = MAP_W - 2; ey = MAP_H - 2; }
    carveCell(grid, ex, ey, ">");

    # Add theme-specific terrain features
    addThemeFeatures(grid, theme, rooms);
    
    theme = getThemeForDepth(depth);
    return { "grid": grid, "rooms": rooms, "exit": [ex, ey], "player_start": [px, py], "theme": theme };
}

# Add theme-specific terrain features
func addThemeFeatures(grid, theme, rooms) {
    if theme == "caves" {
        # Caves: Add some water/lake tiles
        for i = 0, i < 3, i += 1 {
            if length(rooms) > 0 {
                room_idx = randInt(0, length(rooms) - 1);
                room = rooms[room_idx];
                # Safety check: ensure room is large enough for terrain placement
                if room["w"] > 2 and room["h"] > 2 {
                    cx = room["x"] + randInt(1, room["w"] - 2);
                    cy = room["y"] + randInt(1, room["h"] - 2);
                    if inBounds(cx, cy) and grid[cy][cx] == "." {
                        grid[cy][cx] = "~";  # Water tile
                    }
                }
            }
        }
    } elif theme == "catacombs" {
        # Catacombs: Add some pillars/obstacles
        for i = 0, i < 4, i += 1 {
            if length(rooms) > 0 {
                room_idx = randInt(0, length(rooms) - 1);
                room = rooms[room_idx];
                # Safety check: ensure room is large enough for terrain placement
                if room["w"] > 2 and room["h"] > 2 {
                    cx = room["x"] + randInt(1, room["w"] - 2);
                    cy = room["y"] + randInt(1, room["h"] - 2);
                    if inBounds(cx, cy) and grid[cy][cx] == "." {
                        grid[cy][cx] = "|";  # Pillar
                    }
                }
            }
        }
    } elif theme == "forge" {
        # Forge: Add some lava pockets
        for i = 0, i < 2, i += 1 {
            if length(rooms) > 0 {
                room_idx = randInt(0, length(rooms) - 1);
                room = rooms[room_idx];
                # Safety check: ensure room is large enough for terrain placement
                if room["w"] > 2 and room["h"] > 2 {
                    cx = room["x"] + randInt(1, room["w"] - 2);
                    cy = room["y"] + randInt(1, room["h"] - 2);
                    if inBounds(cx, cy) and grid[cy][cx] == "." {
                        grid[cy][cx] = "~";  # Lava tile (red ~ symbol)
                    }
                }
            }
        }
    }
}
