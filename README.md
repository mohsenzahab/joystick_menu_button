# joystick_menu_button

A floating, joystick-style radial menu for touch-driven controls in Flutter.

## Features

- Reveal on long-press and drag to select options
- Fully customizable appearance via builder callbacks
- Programmatic control via `StickButtonMenuController`
- Smooth animations for stick return and menu appearance
- Configurable geometry, colors, and timing

## Getting Started

Add the package to your `pubspec.yaml`:

```yaml
dependencies:
  joystick_menu_button: ^0.1.0
```

## Usage

```dart
import 'package:joystick_menu_button/joystick_menu_button.dart';

class MyScreen extends StatefulWidget {
  @override
  State<MyScreen> createState() => _MyScreenState();
}

class _MyScreenState extends State<MyScreen> {
  final _menuController = StickButtonMenuController();

  void _onSelected(int? value, Offset dragDistance, double activation) {
    if (value != null) {
      debugPrint('Selected: $value');
    }
  }

  @override
  void dispose() {
    _menuController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StickButtonMenu<int>(
      controller: _menuController,
      onSelected: _onSelected,
      options: const [
        OptionItem(value: 0, child: Icon(Icons.replay_10)),
        OptionItem(value: 1, child: Icon(Icons.play_arrow)),
        OptionItem(value: 2, child: Icon(Icons.forward_10)),
        OptionItem(value: 3, child: Icon(Icons.volume_up)),
      ],
      child: Container(
        color: Colors.blue,
        child: const Center(child: Text('Long-press to reveal menu')),
      ),
    );
  }
}
```

## Programmatic Control

```dart
// Show the menu at a specific position
final controller = StickButtonMenuController();
controller.show(); // Centers in parent widget

// Hide the menu
controller.hide();

// Toggle visibility
controller.toggle();
```

## Customization

All visual aspects can be customized:

- `backgroundColor`, `buttonColor`, `buttonActiveColor`
- `optionColor`, `optionHoverColor`, `iconColor`
- `radius`, `buttonRatio`, `optionRatio`, `placeholderRatio`
- Custom builders: `backgroundBuilder`, `buttonBuilder`, `optionBuilder`

See the `example/` directory for a complete sample app.