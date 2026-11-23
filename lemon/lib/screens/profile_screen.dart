import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../view_models/auth_view_model.dart';
import '../widgets/edit_profile_button.dart';
import '../widgets/favorite_genres.dart';
import '../widgets/movielog_app_bar.dart';
import '../widgets/movielog_button.dart';
import '../widgets/profile_header.dart';
import '../widgets/profile_stats.dart';

/// 마이페이지입니다. 닉네임·이메일은 GET me로 받은 AuthViewModel.member를 그대로 씁니다.
/// (사진·통계·장르는 기존 디자인 예시이며 v7 GET me 응답에는 없습니다.)
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('로그아웃할까요?'),
        content: const Text('이 기기에 저장된 로그인 정보를 지웁니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    // 화면 이동은 하지 않습니다. signedOut이 되면 Router가 /login으로 보냅니다.
    await context.read<AuthViewModel>().logout();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final auth = context.watch<AuthViewModel>();
    final member = auth.member;

    return Scaffold(
      appBar: MovieLogAppBar(
        title: '내 프로필',
        titleColor: colors.primary,
        centerTitle: false,
        actions: [
          TextButton(
            onPressed: auth.storageCleanupInProgress
                ? null
                : () => _logout(context),
            child: const Text('로그아웃'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (member != null)
                ProfileHeader(nickname: member.nickname, bio: member.email)
              else
                _MemberPlaceholder(
                  status: auth.memberStatus,
                  message: auth.memberMessage,
                  onRetry: () => auth.loadMember(force: true),
                ),
              const SizedBox(height: 24),
              Center(
                child: EditProfileButton(
                  // 내 정보를 받기 전에는 수정 화면에 채울 값이 없으므로 막습니다.
                  onPressed: member == null
                      ? null
                      : () => context.push('/my/profile/edit'),
                ),
              ),
              const SizedBox(height: 32),
              const ProfileStats(),
              const SizedBox(height: 24),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: colors.outlineVariant, width: 1.5),
                ),
                tileColor: colors.surfaceContainerLowest,
                title: Text(
                  '내가 등록한 평점',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                trailing: Icon(Icons.chevron_right, color: colors.primary),
                // 마이페이지 위에 자식 화면을 쌓아, 뒤로 가면 마이페이지로 돌아옵니다.
                onTap: () => context.push('/my/ratings'),
              ),
              const SizedBox(height: 32),
              const FavoriteGenres(),
              if (kDebugMode) ...[
                const SizedBox(height: 32),
                const _DebugTokenTools(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 내 정보를 불러오는 중이거나 실패했을 때 프로필 자리에 보여줍니다.
/// 네트워크 실패는 로그아웃하지 않고 여기서 다시 시도합니다.
class _MemberPlaceholder extends StatelessWidget {
  const _MemberPlaceholder({
    required this.status,
    required this.message,
    required this.onRetry,
  });

  final MemberLoadStatus status;
  final String? message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (status != MemberLoadStatus.error) {
      return const SizedBox(
        height: 180,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return SizedBox(
      height: 180,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(message ?? '내 정보를 불러오지 못했어요.'),
          const SizedBox(height: 12),
          MovieLogButton(label: '다시 시도', onPressed: onRetry),
        ],
      ),
    );
  }
}

/// Debug 빌드에서만 보이는 세션 만료 실습 도구입니다.
/// 저장된 토큰을 무효 값으로 바꿔, 다음 보호 요청에서 실제 서버의 AUTH401_3을 받게 합니다.
class _DebugTokenTools extends StatelessWidget {
  const _DebugTokenTools();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '개발용 (Debug 빌드 전용)',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 4),
          Text(
            '저장된 토큰을 무효 값으로 바꿉니다. 이후 내 정보 새로고침·평점 저장·앱 재시작에서 '
            '서버가 AUTH401_3을 돌려주면 로그인 화면으로 이동합니다.',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: () async {
                  final auth = context.read<AuthViewModel>();
                  final messenger = ScaffoldMessenger.of(context);
                  await auth.debugInvalidateStoredToken();
                  messenger
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      const SnackBar(
                        content: Text('저장된 토큰을 무효 값으로 바꿨어요. (개발용)'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                },
                child: const Text('토큰 무효화'),
              ),
              OutlinedButton(
                // 무효화 뒤 누르면 GET me가 401을 받아 세션이 정리됩니다.
                onPressed: () =>
                    context.read<AuthViewModel>().loadMember(force: true),
                child: const Text('내 정보 새로고침'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
