import 'package:flutter/material.dart';

class MovieLogAppBar extends StatelessWidget implements PreferredSizeWidget {
  const MovieLogAppBar({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return AppBar(title: Text(title), centerTitle: true);
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
