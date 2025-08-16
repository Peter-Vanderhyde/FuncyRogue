# intro.fy — Matrix-style intro sequence with pulsing title
import "config.fy";

# Simple delay function
func delayMs(ms) {
    start = time();
    while time() - start < ms { }
}

# Clear screen
func clearScreen() {
    print("\e[H\e[J\n");
}

# Matrix rain effect - falling characters
func matrixRain() {
    # Create random falling characters
    for frame = 0, frame < 20, frame += 1 {
        rain_frame = "";
        
        # Add some empty lines at top
        for i = 0, i < 5, i += 1 {
            rain_frame = rain_frame + "\n";
        }
        
        # Create random falling characters
        for line = 0, line < MAP_H - 10, line += 1 {
            rain_line = "";
            for col = 0, col < MAP_W, col += 1 {
                # Random chance to show a character
                if randInt(0, 99) < 15 {
                    # Random matrix character
                    chars = ["0", "1", "#", ".", "*", "+", "=", "-", "|", "/"];
                    rain_line = rain_line + chars[randInt(0, length(chars) - 1)];
                } else {
                    rain_line = rain_line + " ";
                }
            }
            rain_frame = rain_frame + rain_line + "\n";
        }
        
        print("\e[H" + rain_frame);
        delayMs(100);
    }
}

# Glitch title effect
func glitchTitle() {
    title = "FUNCY ROGUE";
    subtitle = "A Descent Into Procedural Madness";
    
    # Position the title where the spiral box will start (smallest size)
    # Spiral starts at radius 1, so width = 1*4 + 20 = 24, height = 6
    box_width = 24;
    box_height = 6;
    
    # Center the title within the starting box size
    title_spaces = "";
    for i = 0, i < (box_width - length(title)) // 2, i += 1 {
        title_spaces = title_spaces + " ";
    }
    
    subtitle_spaces = "";
    for i = 0, i < (box_width - length(subtitle)) // 2, i += 1 {
        subtitle_spaces = subtitle_spaces + " ";
    }
    
    # Glitch effect - random characters and flickering
    for glitch_step = 0, glitch_step < 12, glitch_step += 1 {
        frame = "";
        
        # Add empty lines to center vertically (same as spiral) + 2 more lines down
        for i = 0, i < MAP_H // 3 + 3, i += 1 {
            frame = frame + "\n";
        }
        
        # Add left margin to match spiral positioning
        frame = frame + "  ";
        
        # Glitch the main title
        if glitch_step < 8 {
            # Random glitch characters
            glitch_title = "";
            for i = 0, i < length(title), i += 1 {
                if randInt(0, 100) < 30 {
                    # Random glitch character
                    glitch_chars = ["@", "#", "$", "%", "&", "*", "!", "?", "~", "^"];
                    glitch_title = glitch_title + glitch_chars[randInt(0, length(glitch_chars) - 1)];
                } else {
                    glitch_title = glitch_title + title[i];
                }
            }
            frame = frame + title_spaces + glitch_title + "\n\n";
        } else {
            # Final clean title
            frame = frame + title_spaces + title + "\n\n";
        }
        
        # Subtitle appears after main title settles
        if glitch_step >= 8 {
            frame = frame + subtitle_spaces + subtitle + "\n";
        }
        
        print("\e[H" + frame);
        delayMs(150);
    }
}

# Spiral reveal effect
func spiralReveal() {
    # Create a spiral pattern that reveals the title
    spiral_chars = ["╔", "═", "╗", "║", "╝", "═", "╚", "║"];
    spiral_idx = 0;
    
    for radius = 1, radius <= 8, radius += 1 {
        spiral_frame = "";
        
        # Add empty lines to center
        for i = 0, i < MAP_H // 3, i += 1 {
            spiral_frame = spiral_frame + "\n";
        }
        
        # Create spiral border - smaller, more reasonable size
        width = radius * 4 + 20;  # Start at 24, grow to 52
        height = 6;  # Fixed height for title + subtitle
        
        # Top border
        spiral_frame = spiral_frame + "  ";
        for i = 0, i < width, i += 1 {
            spiral_frame = spiral_frame + "=";
        }
        spiral_frame = spiral_frame + "\n";
        
        # Middle section with title and subtitle
        for line = 0, line < height, line += 1 {
            spiral_frame = spiral_frame + "  |";
            if line == 2 {
                # Center the main title
                title = "FUNCY ROGUE";
                title_spaces = "";
                for i = 0, i < (width - length(title)) // 2, i += 1 {
                    title_spaces = title_spaces + " ";
                }
                spiral_frame = spiral_frame + title_spaces + title;
                # Fill remaining space
                for i = 0, i < width - length(title) - length(title_spaces), i += 1 {
                    spiral_frame = spiral_frame + " ";
                }
            } elif line == 3 {
                # Center the subtitle
                subtitle = "A Descent Into Procedural Madness";
                subtitle_spaces = "";
                for i = 0, i < (width - length(subtitle)) // 2, i += 1 {
                    subtitle_spaces = subtitle_spaces + " ";
                }
                spiral_frame = spiral_frame + subtitle_spaces + subtitle;
                # Fill remaining space
                for i = 0, i < width - length(subtitle) - length(subtitle_spaces), i += 1 {
                    spiral_frame = spiral_frame + " ";
                }
            } else {
                # Empty lines
                for i = 0, i < width, i += 1 {
                    spiral_frame = spiral_frame + " ";
                }
            }
            spiral_frame = spiral_frame + "|\n";
        }
        
        # Bottom border
        spiral_frame = spiral_frame + "  ";
        for i = 0, i < width, i += 1 {
            spiral_frame = spiral_frame + "=";
        }
        
        clearScreen();
        print(spiral_frame);
        delayMs(150);
    }
}

# Simple intro sequence
func playIntro() {
    # Check if intro is enabled
    if not INTRO_ENABLED {
        # Skip intro - just clear screen and continue
        clearScreen();
        return;
    }
    
    # Phase 1: Spiral reveal
    clearScreen();
    spiralReveal();
    
    # Add a few empty lines after the title
    print("\n\n");
    
    # Show "Press Enter to light your torch..." message
    press_enter_msg = "Press Enter to light your torch...";
    press_enter_x = (MAP_W - length(press_enter_msg)) // 3;
    press_enter_spaces = "";
    for i = 0, i < press_enter_x, i += 1 {
        press_enter_spaces = press_enter_spaces + " ";
    }
    print(press_enter_spaces + press_enter_msg);
    
    # Wait for user to press Enter
    input("");
    
    # Phase 2: Screen wipe down effect from top of terminal
    # Move cursor to top of terminal
    print("\e[H");
    
    # Build one full-width blank line
    blank = "";
    for i = 0, i < MAP_W, i += 1 {
        blank = blank + " ";
    }
    
    # Print enough rows to "wipe" downward from top (similar to descending effect)
    total = MAP_H + 1;   # a little extra for effect
    for n = 0, n < total, n += 1 {
        print(blank);
        delayMs(50);
    }
    
    # Pause after wipe
    delayMs(800);
    
    # Final clear and start the game
    clearScreen();
}