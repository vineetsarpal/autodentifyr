import 'package:flutter/material.dart';
import 'package:autodentifyr/core/theme/app_palette.dart';

/// A circular control button that can display an icon, image, or text
class ControlButton extends StatelessWidget {
  const ControlButton({
    super.key,
    required this.content,
    required this.onPressed,
  });

  final dynamic content;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 24,
      backgroundColor: AppPalette.blackColor.withValues(alpha: 0.2),
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (content is IconData) {
      return IconButton(
        icon: Icon(content, color: AppPalette.whiteColor),
        onPressed: onPressed,
      );
    } else if (content.toString().contains('assets/')) {
      return IconButton(
        icon: Image.asset(
          content,
          width: 24,
          height: 24,
          color: AppPalette.whiteColor,
        ),
        onPressed: onPressed,
      );
    } else {
      return TextButton(
        onPressed: onPressed,
        child: Text(
          content,
          style: const TextStyle(color: AppPalette.whiteColor, fontSize: 12),
        ),
      );
    }
  }
}
