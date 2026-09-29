import 'package:flutter/material.dart';

class MovieLogAppBar extends StatelessWidget implements PreferredSizeWidget {
  const MovieLogAppBar({
    super.key,
    required this.title,
    this.titleColor,
    this.leading,
  });

  final String title;
  final Color? titleColor;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leading: leading,
      title: Text(
        title,
        style: titleColor == null
            ? null
            : TextStyle(color: titleColor, fontWeight: FontWeight.bold),
      ),
      centerTitle: true,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
