import 'package:flutter/material.dart';
import 'package:joystick_menu_button/joystick_menu_button.dart';

enum VideoAction {
  next(Icons.fast_forward_rounded),
  lock(Icons.lock),
  save(Icons.save),
  test(Icons.text_snippet),
  previous(Icons.fast_rewind_rounded);

  const VideoAction(this.icon);
  final IconData icon;
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Joystick Menu Button Demo',
      home: VideoPlayerScreen(),
    );
  }
}

class VideoPlayerScreen extends StatefulWidget {
  const VideoPlayerScreen({super.key});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  final _menuController = StickButtonMenuController();
  bool _paused = false;

  @override
  void dispose() {
    _menuController.dispose();
    super.dispose();
  }

  void _onSelected(VideoAction? action, Offset drag, double act) {
    if (action == null) return;
    switch (action) {
      case VideoAction.next:
        break;
      case VideoAction.previous:
        break;
      case VideoAction.lock:
        break;
      case VideoAction.save:
        break;
      case VideoAction.test:
        break;
    }
    debugPrint('Activated: $action act: $act');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: StickButtonMenu<VideoAction>(
        controller: _menuController,
        onSelected: _onSelected,
        buttonRatio: 0.25,
        buttonBuilder: (context, size, color, isActive, activation, index) {
          final action = index != -1 ? VideoAction.values[index] : null;
          Widget? child;
          switch (action) {
            case VideoAction.next:
              child = Stack(
                children: [
                  Center(child: Icon(action!.icon)),
                  Positioned.fill(
                    child: CircularProgressIndicator(value: activation),
                  ),
                ],
              );
              break;
            case VideoAction.previous:
              child = Stack(
                children: [
                  Center(child: Icon(action!.icon)),
                  Positioned.fill(
                    child: CircularProgressIndicator(value: activation),
                  ),
                ],
              );
              break;
            case null:
            case VideoAction.lock:
            case VideoAction.save:
            case VideoAction.test:
          }

          return Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: child,
          );
        },
        radius: 200,
        options: VideoAction.values.map((e) {
          return OptionItem(value: e, child: Icon(e.icon));
        }).toList(),
        child: Center(
          child: GestureDetector(
            onTap: () {
              setState(() => _paused = !_paused);
              _paused ? _menuController.show() : _menuController.hide();
            },
            child: const Text(
              'Long-press to reveal menu',
              style: TextStyle(color: Colors.white54),
            ),
          ),
        ),
      ),
    );
  }
}