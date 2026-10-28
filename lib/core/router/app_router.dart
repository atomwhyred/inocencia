import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/presentation/admin_page.dart';
import '../../features/auth/application/session.dart';
import '../../features/auth/presentation/child_pin_page.dart';
import '../../features/auth/presentation/parent_pin_page.dart';
import '../../features/auth/presentation/profile_select_page.dart';
import '../../features/external_data/presentation/path_browser_page.dart';
import '../../features/home/presentation/home_page.dart';
import '../../features/library/presentation/books_page.dart';
import '../../features/library/presentation/reader_page.dart';
import '../../features/profiles/presentation/profile_edit_page.dart';
import '../../features/setup/presentation/setup_page.dart';
import '../../features/tutor/presentation/tutor_page.dart';
import '../di/providers.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // Avisa al router cuando cambian el administrador o la sesion.
  final refresh = ValueNotifier<int>(0);
  ref.listen(guardianProvider, (_, _) => refresh.value++);
  ref.listen(sessionProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final guardian = ref.read(guardianProvider);
      final session = ref.read(sessionProvider);
      final loc = state.matchedLocation;

      if (guardian.isLoading) return loc == '/splash' ? null : '/splash';
      // Primer arranque: sin administrador solo se puede crear uno.
      if (guardian.value == null) return loc == '/setup' ? null : '/setup';
      if (loc == '/setup' || loc == '/splash') return '/';

      if (loc.startsWith('/admin') && !session.parentUnlocked) return '/parent-pin';
      // Lo del nino (inicio, tutor y libros) exige haber elegido perfil.
      final childOnly = loc == '/home' || loc == '/tutor' || loc.startsWith('/books');
      if (childOnly && session.activeChildId == null) return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (_, _) => const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      GoRoute(path: '/setup', builder: (_, _) => const SetupPage()),
      GoRoute(path: '/', builder: (_, _) => const ProfileSelectPage()),
      GoRoute(path: '/parent-pin', builder: (_, _) => const ParentPinPage()),
      GoRoute(
        path: '/child-pin/:id',
        builder: (_, state) =>
            ChildPinPage(childId: int.parse(state.pathParameters['id']!)),
      ),
      GoRoute(path: '/home', builder: (_, _) => const HomePage()),
      GoRoute(path: '/tutor', builder: (_, _) => const TutorPage()),
      GoRoute(
        path: '/books',
        builder: (_, _) => const BooksPage(),
        routes: [
          GoRoute(
            path: ':book',
            builder: (_, state) => ReaderPage(
              bookId: state.pathParameters['book']!,
              page: int.tryParse(state.uri.queryParameters['page'] ?? ''),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/admin',
        builder: (_, _) => const AdminPage(),
        routes: [
          GoRoute(
            path: 'profile/new',
            builder: (_, _) => const ProfileEditPage(),
          ),
          GoRoute(
            path: 'profile/:id',
            builder: (_, state) =>
                ProfileEditPage(childId: int.parse(state.pathParameters['id']!)),
          ),
          GoRoute(
            path: 'browse',
            builder: (_, state) =>
                PathBrowserPage(request: state.extra! as BrowseRequest),
          ),
        ],
      ),
    ],
  );
});
