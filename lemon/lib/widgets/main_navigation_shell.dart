import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../view_models/auth_view_model.dart';

/// 홈·영화·마이 탭을 감싸는 화면입니다.
///
/// 탭을 바꿔도 이 State는 유지되므로, 어느 탭으로 들어오든 내 정보(GET me)를 여기서 한 번만 부릅니다.
/// 로그아웃하면 Shell이 사라지고, 다시 로그인하면 새로 만들어져 다시 부릅니다.
class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  StatefulNavigationShell get navigationShell => widget.navigationShell;

  @override
  void initState() {
    super.initState();
    // 첫 build 도중 notifyListeners()가 불리지 않도록 프레임이 끝난 뒤 호출합니다.
    // 앱 재시작이면 restoreSession()이 이미 member를 채웠으므로 요청하지 않습니다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AuthViewModel>().loadMember();
    });
  }

  void _onDestinationSelected(int index) {
    navigationShell.goBranch(
      index,
      // 이미 선택된 탭을 다시 누르면 그 탭의 첫 화면으로 돌아갑니다.
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    // 로그인 이후 탭 화면에서는 시스템 뒤로 가기로 로그인 화면에
    // 돌아가거나 앱이 닫히지 않도록 막습니다. 다른 탭에서는 홈 탭으로 이동합니다.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && navigationShell.currentIndex != 0) {
          navigationShell.goBranch(0);
        }
      },
      child: Scaffold(
        body: navigationShell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: _onDestinationSelected,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: '홈',
            ),
            NavigationDestination(
              icon: Icon(Icons.movie_outlined),
              selectedIcon: Icon(Icons.movie),
              label: '영화',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: '마이',
            ),
          ],
        ),
      ),
    );
  }
}
