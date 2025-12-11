# MacWhisper

A powerful macOS subtitle editor built with Flutter that enables automatic transcription of video files using OpenAI's Whisper model.

![macOS](https://img.shields.io/badge/platform-macOS-blue)
![Flutter](https://img.shields.io/badge/Flutter-3.0+-02569B?logo=flutter)
![License](https://img.shields.io/badge/license-MIT-green)

## Features

### 🎬 Video Support
- Import local video files (drag & drop or file picker)
- Download videos from URLs using yt-dlp
- Built-in video player with full playback controls
- Fullscreen mode (double-click or fullscreen button)
- Keyboard shortcuts (Space: play/pause, Arrow keys: seek)

### 🎤 Automatic Transcription
- Powered by [Whisper.cpp](https://github.com/ggerganov/whisper.cpp) for fast, local transcription
- Multiple model sizes: tiny, base, small, medium, large
- Automatic model downloading from Hugging Face
- Real-time progress tracking

### ✏️ Subtitle Editing
- Edit subtitle text, start times, and end times
- Merge multiple subtitles into one
- Split subtitles in half
- Undo/Redo support
- Auto-sync: clicking a subtitle seeks the video, clicking the timeline highlights the subtitle

### 💾 Export Options
- SRT (SubRip)
- VTT (WebVTT)
- ASS (Advanced SSA)

## Screenshots

*Coming soon*

## Requirements

- macOS 10.15 or later
- ~2GB disk space (for Whisper models)

## Installation

### From Source

1. **Clone the repository**
   ```bash
   git clone https://github.com/your-username/mac-whisper.git
   cd mac-whisper
   ```

2. **Build Whisper.cpp** (required for transcription)
   ```bash
   git clone https://github.com/ggerganov/whisper.cpp.git
   cd whisper.cpp
   mkdir build && cd build
   cmake .. -DCMAKE_BUILD_TYPE=Release -DGGML_METAL=ON
   make -j$(sysctl -n hw.ncpu)
   cd ../..
   ```

3. **Copy binaries to the project**
   ```bash
   cp whisper.cpp/build/bin/whisper-cli macos/Runner/
   cp whisper.cpp/build/src/libwhisper.1.*.dylib macos/Runner/libwhisper.1.dylib
   cp whisper.cpp/build/ggml/src/libggml*.dylib macos/Runner/
   ```

4. **Fix library paths**
   ```bash
   cd macos/Runner
   install_name_tool -add_rpath @executable_path/. whisper-cli
   # Run similar commands for all dylibs (see build instructions)
   ```

5. **Run the app**
   ```bash
   flutter run -d macos
   ```

## Usage

1. **Import a video**: Drag & drop a video file onto the app, or use the file picker
2. **Select a model**: Choose a Whisper model size (larger = more accurate but slower)
3. **Transcribe**: Click "Transcribe" to generate subtitles
4. **Edit**: Modify subtitles as needed using the editor
5. **Export**: Export to SRT, VTT, or ASS format

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Space` | Play/Pause video |
| `←` | Seek backward 5 seconds |
| `→` | Seek forward 5 seconds |
| `Esc` | Exit fullscreen |
| `⌘Z` | Undo |
| `⌘⇧Z` | Redo |

## Project Structure

```
mac_whisper/
├── lib/
│   ├── main.dart              # App entry point
│   ├── pages/
│   │   ├── home_page.dart     # Main project list
│   │   └── subtitle_editor_page.dart  # Editor page
│   ├── models/
│   │   └── subtitle.dart      # Subtitle data model
│   ├── services/
│   │   ├── database_service.dart  # SQLite database
│   │   └── binary_service.dart    # Binary path management
│   └── widgets/
│       └── video_preview.dart # Video player widget
├── macos/
│   └── Runner/
│       ├── whisper-cli        # Whisper CLI binary
│       ├── yt-dlp             # YouTube downloader
│       └── *.dylib            # Whisper libraries
└── pubspec.yaml
```

## Dependencies

- **Flutter** - UI framework
- **video_player** - Video playback
- **sqflite** - Local SQLite database
- **file_picker** - File selection dialogs
- **desktop_drop** - Drag & drop support
- **path_provider** - App directory paths

## Bundled Tools

- **whisper-cli** - Whisper.cpp command-line interface for transcription
- **yt-dlp** - Video downloader for URL imports

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- [OpenAI Whisper](https://github.com/openai/whisper) - Speech recognition model
- [Whisper.cpp](https://github.com/ggerganov/whisper.cpp) - C++ port of Whisper
- [yt-dlp](https://github.com/yt-dlp/yt-dlp) - Video downloader

---

© 2025 The MacWhisper Team. All Rights Reserved.
