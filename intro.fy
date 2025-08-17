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

# Simple title presentation animation
func simpleTitleReveal() {
    title = "FUNCY ROGUE";
    subtitle = "A Descent Into Procedural Madness";
    
    # Center the title horizontally
    title_spaces = "";
    for i = 0, i < (MAP_W - length(title)) // 2, i += 1 {
        title_spaces = title_spaces + " ";
    }
    
    subtitle_spaces = "";
    for i = 0, i < (MAP_W - length(subtitle)) // 2, i += 1 {
        subtitle_spaces = subtitle_spaces + " ";
    }
    
    # Start with empty screen
    clearScreen();
    
    # Add some empty lines to center vertically
    for i = 0, i < MAP_H // 3, i += 1 {
        print("");
    }
    
    # Reveal title character by character
    for i = 0, i < length(title), i += 1 {
        print("\e[H");  # Move cursor to top
        # Re-print empty lines
        for j = 0, j < MAP_H // 3, j += 1 {
            print("");
        }
        # Print title so far
        current_title = "";
        for k = 0, k <= i, k += 1 {
            current_title = current_title + title[k];
        }
        print(title_spaces + current_title);
        delayMs(150);
    }
    
    # Brief pause
    delayMs(300);
    
    # Reveal subtitle character by character
    for i = 0, i < length(subtitle), i += 1 {
        print("\e[H");  # Move cursor to top
        # Re-print empty lines
        for j = 0, j < MAP_H // 3, j += 1 {
            print("");
        }
        # Print full title
        print(title_spaces + title);
        # Print subtitle so far
        current_subtitle = "";
        for k = 0, k <= i, k += 1 {
            current_subtitle = current_subtitle + subtitle[k];
        }
        print(subtitle_spaces + current_subtitle);
        delayMs(100);
    }
    
    # Final pause to show the complete title
    delayMs(800);
}

# Simple intro sequence
func playIntro() {
    # Check if intro is enabled
    if not INTRO_ENABLED {
        # Skip intro - just clear screen and continue
        clearScreen();
        return;
    }
    
    # Phase 1: Simple title reveal
    clearScreen();
    simpleTitleReveal();
    
    # Add a few empty lines after the title
    print("\n\n");
    
    # Show "Press Enter to light your torch..." message
    press_enter_msg = "Press Enter to light your torch...";
    press_enter_x = (MAP_W - length(press_enter_msg)) // 2;
    press_enter_spaces = "";
    for i = 0, i < press_enter_x, i += 1 {
        press_enter_spaces = press_enter_spaces + " ";
    }
    print(press_enter_spaces + press_enter_msg);
    
    # Wait for user to press Enter
    input("");
    
    # Phase 2: Screen wipe down effect from top of terminal
    # Note: This will be handled by the game's mapWipeEffect when the game starts
    # Just clear the screen and continue
    clearScreen();
}