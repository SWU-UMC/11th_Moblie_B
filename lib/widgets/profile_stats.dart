import 'package:flutter/material.dart';

import 'stat_item.dart';

class ProfileStats extends StatelessWidget {
  const ProfileStats({super.key});

  static const _items = [
    StatItem(label: '본 영화', value: '342'),
    StatItem(label: '평점', value: '4.2'),
    StatItem(label: '즐겨찾기', value: '58'),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < _items.length; i++)
          Expanded(
            child: Container(
              margin: EdgeInsets.only(right: i == _items.length - 1 ? 0 : 12),
              child: _items[i],
            ),
          ),
      ],
    );
  }
}
