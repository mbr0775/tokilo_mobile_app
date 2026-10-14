import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/painting.dart';
import 'package:tokilo/core/widgets/image_gallery_viewer.dart';
import 'fixture_image_client.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tokilo/core/theme/app_theme.dart';
import 'package:tokilo/core/widgets/tokilo_motion.dart';
import 'package:tokilo/features/auth/screens/login_screen.dart';
import 'package:tokilo/features/auth/screens/onboarding_screen.dart';
import 'package:tokilo/features/chat/screens/chat_screen.dart';
import 'package:tokilo/features/feed/screens/feed_screen.dart';
import 'package:tokilo/features/home/screens/home_screen.dart';
import 'package:tokilo/features/notifications/screens/notifications_screen.dart';
import 'package:tokilo/features/portal/screens/portal_screen.dart';
import 'package:tokilo/features/portfolio/screens/portfolio_screen.dart';
import 'package:tokilo/features/profile/screens/profile_screen.dart';
import 'package:tokilo/features/projects/screens/project_pricing_screen.dart';
import 'package:tokilo/navigation/bottom_nav_shell.dart';
import 'package:tokilo/admin/screens/admin_dashboard_screen.dart';
import 'package:tokilo/features/chat/screens/admin_conversations_screen.dart';
import 'package:tokilo/admin/constants/admin_constants.dart';

// Isolated fixtures only. No production Supabase HTTP request is sent.
const userId = '00000000-0000-0000-0000-000000000001';
const conversationId = '00000000-0000-0000-0000-000000000010';
const project = {
  'id': 'preview-project',
  'title': 'Connected products',
  'subtitle': 'Mobile application',
  'description': 'A design preview of connected digital experiences.',
  'created_at': '2026-10-13T09:00:00Z',
  'is_active': true,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  var failProjects = false;
  var emptyContent = false;
  var notificationRead = false;
  final requests = <http.Request>[];
  var projectRows = <Map<String, dynamic>>[project];
  var previewRows = <Map<String, dynamic>>[project];
  late FixtureImageClient imageClient;

  setUpAll(() async {
    // Load the same bundled font as the app; Ahem is not a visual QA font.
    final textFont = FontLoader('TokiloSans');
    for (final asset in [
      'roboto-regular.ttf',
      'roboto-medium.ttf',
      'roboto-bold.ttf',
    ]) {
      textFont.addFont(rootBundle.load('assets/fonts/$asset'));
    }
    await textFont.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawColor(const Color(0xFFE3F5AE), BlendMode.src);
    canvas.drawRect(
      const Rect.fromLTWH(10, 20, 100, 210),
      Paint()..color = const Color(0xFF122A30),
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(120, 250);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    final fallback = png!.buffer.asUint8List();
    image.dispose();
    picture.dispose();
    final images = <String, List<int>>{};
    // Optional local copies of public content make visual QA representative.
    // They never change the app's production content or contact a real API.
    final publicFixtures = Platform.environment['TOKILO_PUBLIC_FIXTURES'];
    if (publicFixtures != null) {
      final folder = Directory(publicFixtures);
      previewRows = List<Map<String, dynamic>>.from(
        jsonDecode(await File('${folder.path}/showcase.json').readAsString()),
      );
      for (final row in previewRows) {
        final url = row['image_url']?.toString();
        if (url != null) {
          images[url] = await File(
            '${folder.path}/${row['id']}.jpg',
          ).readAsBytes();
        }
      }
    }
    imageClient = FixtureImageClient(images, fallback);
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://mobile-design-test.supabase.co',
      anonKey: 'test-key',
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        localStorage: EmptyLocalStorage(),
        autoRefreshToken: false,
        detectSessionInUri: false,
      ),
      httpClient: MockClient((request) async {
        requests.add(request);
        expect(request.url.host, 'mobile-design-test.supabase.co');
        final path = request.url.path.split('/').last;
        if (path == 'project_showcase' && failProjects) {
          return http.Response(
            '{"message":"Offline preview"}',
            503,
            request: request,
          );
        }
        Object? data = [];
        if (path == 'tokilo_open_conversation') {
          data = [
            {'id': conversationId, 'client_id': userId},
          ];
        }
        if (request.method == 'GET' && !emptyContent) {
          data = switch (path) {
            'project_showcase' => projectRows,
            'conversations' => [
              {
                'id': conversationId,
                'client_id': userId,
                'is_read_client': true,
              },
            ],
            'messages' => [
              {
                'id': 'preview-message-1',
                'conversation_id': conversationId,
                'sender_id': 'support-test',
                'sender_role': 'admin',
                'sender_name': 'Tokilo',
                'content': 'Welcome! Tell us a little about your next project.',
                'created_at': '2026-10-13T09:00:00Z',
              },
              {
                'id': 'preview-message-2',
                'conversation_id': conversationId,
                'sender_id': userId,
                'sender_role': 'client',
                'content': 'I’d like to build a website and a mobile app.',
                'is_read': true,
                'created_at': '2026-10-13T09:01:00Z',
              },
            ],
            'service_pricing' => [
              {
                'id': 'preview-service',
                'title': 'Custom web application',
                'category': 'Software Development',
                'price_label': 'Request a quote',
                'duration_label': 'Scope based delivery',
                'features': ['Responsive interface', 'Backend integration'],
              },
            ],
            _ => [],
          };
        }
        if (path == 'tokilo_notification_feed')
          data = emptyContent
              ? []
              : [
                  {
                    'id': 'preview-update',
                    'title': 'Welcome to Tokilo',
                    'body': 'Your account updates will appear here.',
                    'is_read': notificationRead,
                    'unread_total': notificationRead ? 0 : 1,
                    'created_at': '2026-10-13T09:00:00Z',
                  },
                ];
        if (path == 'tokilo_read_notifications') {
          notificationRead = true;
          data = null;
        }
        return http.Response(
          jsonEncode(data),
          200,
          request: request,
          headers: {
            'content-type': 'application/json',
            'content-range': '0-0/${data is List ? data.length : 0}',
          },
        );
      }),
    );
    await Supabase.instance.client.auth.setInitialSession(
      jsonEncode({
        'access_token':
            '${base64UrlEncode(utf8.encode(jsonEncode({'alg': 'HS256', 'typ': 'JWT'})))}.${base64UrlEncode(utf8.encode(jsonEncode({'sub': userId, 'role': 'authenticated', 'exp': DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000})))}.test-signature',
        'refresh_token': 'test-refresh-token',
        'token_type': 'bearer',
        'expires_in': 3600,
        'user': {
          'id': userId,
          'aud': 'authenticated',
          'email': 'preview@example.test',
          'app_metadata': {},
          'user_metadata': {
            'full_name': 'Alex',
            'company_name': 'Preview studio',
          },
          'created_at': '2026-01-01T00:00:00Z',
        },
      }),
    );
  });
  tearDownAll(() async {
    debugNetworkImageHttpClientProvider = null;
    await Supabase.instance.dispose();
  });
  setUp(() {
    failProjects = false;
    projectRows = previewRows;
    emptyContent = false;
    notificationRead = false;
    requests.clear();
    final realtime = Supabase.instance.client.realtime;
    realtime.conn = _FixtureSocket(realtime);
    realtime.connState = SocketStates.open;
  });

  GoRouter routerFor(String path) => GoRouter(
    initialLocation: path,
    routes: [
      GoRoute(
        path: '/admin/dashboard',
        builder: (_, _) => const AdminDashboardScreen(),
      ),
      GoRoute(
        path: '/admin/messages',
        builder: (_, _) => const AdminConversationsScreen(),
      ),
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(
        path: '/chat',
        builder: (_, _) => const ChatScreen(conversationId: conversationId),
      ),
      GoRoute(
        path: '/notifications',
        builder: (_, _) => const NotificationsScreen(),
      ),
      GoRoute(path: '/portfolio', builder: (_, _) => const PortfolioScreen()),
      ShellRoute(
        builder: (_, _, child) => BottomNavShell(child: child),
        routes: [
          GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
          GoRoute(path: '/feed', builder: (_, _) => const FeedScreen()),
          GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen()),
          GoRoute(path: '/portal', builder: (_, _) => const PortalScreen()),
          GoRoute(
            path: '/marketplace',
            builder: (_, _) => const ProjectPricingScreen(),
          ),
        ],
      ),
    ],
  );

  Future<void> settle(WidgetTester tester) async {
    // Repeating decorative animation intentionally never pumpAndSettles.
    for (var i = 0; i < 12; i++) {
      await tester.runAsync(() async => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Future<void> render(
    WidgetTester tester,
    GoRouter router, {
    double width = 390,
    double height = 844,
    double scale = 1,
    GlobalKey? capture,
  }) async {
    debugNetworkImageHttpClientProvider = () => imageClient;
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 20);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.lightTheme,
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: RepaintBoundary(key: capture, child: child!),
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
    final output = Platform.environment['TOKILO_UI_CAPTURE'];
    if (output == null) return;
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory(output).create(recursive: true);
      await File('$output/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  for (final size in [(390.0, 844.0, 1.0), (360.0, 640.0, 1.4)]) {
    for (final path in [
      '/admin/dashboard',
      '/admin/messages',
      '/home',
      '/feed',
      '/profile',
      '/chat',
      '/onboarding',
      '/login',
      '/portal',
      '/marketplace',
      '/portfolio',
      '/notifications',
    ]) {
      testWidgets('$path renders at ${size.$1} with text scale ${size.$3}', (
        tester,
      ) async {
        final router = routerFor(path);
        addTearDown(router.dispose);
        final key = GlobalKey();
        await render(
          tester,
          router,
          width: size.$1,
          height: size.$2,
          scale: size.$3,
          capture: key,
        );
        if (path == '/chat') {
          expect(
            find.text('Chat Error'),
            findsNothing,
            reason: find
                .byType(Text)
                .evaluate()
                .map((e) => (e.widget as Text).data)
                .join(' | '),
          );
        }
        expect(tester.takeException(), isNull);
        await capture(
          tester,
          key,
          '${path.substring(1).replaceAll('/', '-')}-${size.$1.toInt()}',
        );
        final verticalScrolls = find
            .byType(Scrollable)
            .evaluate()
            .where(
              (element) =>
                  (element.widget as Scrollable).axisDirection ==
                  AxisDirection.down,
            );
        if (verticalScrolls.isNotEmpty) {
          await tester.drag(
            find.byWidget(verticalScrolls.first.widget),
            const Offset(0, -330),
          );
          await settle(tester);
          expect(tester.takeException(), isNull);
        }
        debugNetworkImageHttpClientProvider = null;
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(
          () => Supabase.instance.client.realtime.disconnect(),
        );
        await tester.pump();
      });
    }
  }

  testWidgets('navigation and connected support actions open real screens', (
    tester,
  ) async {
    final router = routerFor('/home');
    addTearDown(router.dispose);
    await render(tester, router);
    await tester.tap(find.byType(NavigationDestination).at(4));
    await settle(tester);
    expect(find.text('Your space.'), findsOneWidget);
    await tester.ensureVisible(find.text('Help & support'));
    await tester.tap(find.text('Help & support'));
    await settle(tester);
    expect(find.text('Tokilo Support'), findsOneWidget);
    expect(
      find.text('Welcome! Tell us a little about your next project.'),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Back'));
    await settle(tester);
    expect(find.byType(ProfileScreen), findsOneWidget);
    await tester.ensureVisible(find.text('Notifications'));
    await tester.tap(find.text('Notifications'));
    await settle(tester);
    expect(find.text('Welcome to Tokilo'), findsOneWidget);
    await tester.tap(find.text('Welcome to Tokilo'));
    await settle(tester);
    expect(
      requests.any((r) => r.url.path.endsWith('tokilo_read_notifications')),
      isTrue,
    );
    expect(tester.takeException(), isNull);
    debugNetworkImageHttpClientProvider = null;
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() => Supabase.instance.client.realtime.disconnect());
  });

  testWidgets(
    'admin support shortcut opens the inbox instead of a customer chat',
    (tester) async {
      final session = Supabase.instance.client.auth.currentSession!.toJson();
      final user = Map<String, dynamic>.from(session['user'] as Map);
      await Supabase.instance.client.auth.setInitialSession(
        jsonEncode({
          ...session,
          'user': {...user, 'email': AdminConstants.adminEmail},
        }),
      );
      final router = routerFor('/profile');
      addTearDown(router.dispose);
      await render(tester, router);
      await tester.ensureVisible(find.text('Help & support'));
      await tester.tap(find.text('Help & support'));
      await settle(tester);
      expect(find.byType(AdminConversationsScreen), findsOneWidget);
      expect(find.byType(ChatScreen), findsNothing);
      expect(
        requests.where(
          (r) => r.method == 'POST' && r.url.path.endsWith('conversations'),
        ),
        isEmpty,
      );
      expect(tester.takeException(), isNull);
      debugNetworkImageHttpClientProvider = null;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(
        () => Supabase.instance.client.realtime.disconnect(),
      );
      await Supabase.instance.client.auth.setInitialSession(
        jsonEncode(session),
      );
    },
  );

  testWidgets('keyboard leaves chat composer visible on a compact phone', (
    tester,
  ) async {
    final router = routerFor('/chat');
    addTearDown(router.dispose);
    await render(tester, router, width: 360, height: 640);
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Draft message');
    expect(
      tester.getBottomRight(find.byTooltip('Send message')).dy,
      lessThanOrEqualTo(380),
    );
    expect(tester.takeException(), isNull);
    debugNetworkImageHttpClientProvider = null;
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() => Supabase.instance.client.realtime.disconnect());
  });

  testWidgets('home distinguishes network errors from empty projects', (
    tester,
  ) async {
    failProjects = true;
    final router = routerFor('/home');
    addTearDown(router.dispose);
    await render(tester, router);
    await tester.drag(find.byType(ListView).first, const Offset(0, -750));
    await settle(tester);
    expect(
      find.text('Projects could not load. Pull down to retry.'),
      findsOneWidget,
    );
    failProjects = false;
    emptyContent = true;
    await tester.tap(find.byTooltip('Retry projects'));
    await settle(tester);
    await tester.scrollUntilVisible(
      find.text('New projects will appear here as they are published.'),
      -150,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.text('New projects will appear here as they are published.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    debugNetworkImageHttpClientProvider = null;
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() => Supabase.instance.client.realtime.disconnect());
  });

  testWidgets('feed filters, caption expansion and image gallery work', (
    tester,
  ) async {
    projectRows = [
      {
        ...project,
        'image_url': 'https://fixture.test/project.png',
        'description': 'A useful project update. ' * 12,
      },
    ];
    final router = routerFor('/feed');
    addTearDown(router.dispose);
    await render(tester, router);
    await tester.tap(find.text('News'));
    await settle(tester);
    expect(find.text('Nothing here yet'), findsOneWidget);
    await tester.tap(find.text('Projects'));
    await settle(tester);
    expect(find.text('Connected products'), findsOneWidget);
    await tester.ensureVisible(find.byTooltip('Open project image'));
    await tester.tap(find.byTooltip('Open project image'));
    await settle(tester);
    expect(find.byType(ImageGalleryViewer), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close_rounded));
    await settle(tester);
    expect(find.byType(ImageGalleryViewer), findsNothing);
    await tester.ensureVisible(find.text('Read more'));
    await tester.tap(find.text('Read more'));
    await settle(tester);
    expect(find.text('Show less'), findsOneWidget);
    await tester.ensureVisible(find.byTooltip('Message Tokilo'));
    await tester.tap(find.byTooltip('Message Tokilo'));
    await settle(tester);
    expect(find.byType(ChatScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
    debugNetworkImageHttpClientProvider = null;
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() => Supabase.instance.client.realtime.disconnect());
  });

  testWidgets('home showcase swipes between published projects', (
    tester,
  ) async {
    projectRows = [
      {...project, 'image_url': 'https://fixture.test/first.png'},
      {
        ...project,
        'id': 'second-project',
        'title': 'Second project',
        'image_url': 'https://fixture.test/second.png',
      },
    ];
    final router = routerFor('/home');
    addTearDown(router.dispose);
    await render(tester, router);
    await tester.ensureVisible(find.byType(PageView));
    await tester.drag(find.byType(PageView), const Offset(-330, 0));
    await settle(tester);
    expect(find.text('02 / 02'), findsOneWidget);
    expect(find.text('Second project'), findsOneWidget);
    expect(tester.takeException(), isNull);
    debugNetworkImageHttpClientProvider = null;
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() => Supabase.instance.client.realtime.disconnect());
  });

  testWidgets('admin menu can return to client home', (tester) async {
    final router = routerFor('/admin/dashboard');
    addTearDown(router.dispose);
    await render(tester, router, width: 360, height: 640, scale: 1.4);
    await tester.tap(find.byTooltip('Open workspace menu'));
    await settle(tester);
    expect(find.text('YOUR WORKSPACE'), findsOneWidget);
    await tester.tap(find.text('Client home'));
    await settle(tester);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
    debugNetworkImageHttpClientProvider = null;
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() => Supabase.instance.client.realtime.disconnect());
  });

  testWidgets('looping motion sleeps offscreen and honors reduced motion', (
    tester,
  ) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    double progress = -1;
    Widget page({bool reduced = false}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(800, 600),
          disableAnimations: reduced,
        ),
        child: Scaffold(
          body: ListView(
            controller: scroll,
            children: [
              ViewportMotion(
                loop: true,
                builder: (_, value) {
                  progress = value;
                  return const SizedBox(height: 160);
                },
              ),
              const SizedBox(height: 1200),
            ],
          ),
        ),
      ),
    );
    await tester.pumpWidget(page());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 600));
    expect(progress, greaterThan(0));
    scroll.jumpTo(250);
    await tester.pump();
    await tester.pump();
    final paused = progress;
    await tester.pump(const Duration(seconds: 2));
    expect(progress, paused);
    scroll.jumpTo(0);
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(progress, isNot(paused));
    await tester.pumpWidget(page(reduced: true));
    await tester.pump();
    await tester.pump();
    expect(progress, .5);
    await tester.pump(const Duration(seconds: 2));
    expect(progress, .5);
    debugNetworkImageHttpClientProvider = null;
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() => Supabase.instance.client.realtime.disconnect());
  });

  testWidgets('scroll reveals replay and reduced motion stops the scene', (
    tester,
  ) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    double progress = -1;
    Widget page({bool reduced = false}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(800, 600),
          disableAnimations: reduced,
        ),
        child: Scaffold(
          body: ListView(
            controller: scroll,
            children: [
              ViewportMotion(
                builder: (_, value) {
                  progress = value;
                  return const SizedBox(height: 160);
                },
              ),
              const SizedBox(height: 1200),
            ],
          ),
        ),
      ),
    );
    await tester.pumpWidget(page());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(progress, 1);
    scroll.jumpTo(250);
    await tester.pump();
    await tester.pump();
    expect(progress, 0);
    scroll.jumpTo(0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    expect(progress, inExclusiveRange(0, 1));
    await tester.pumpWidget(page(reduced: true));
    await tester.pump();
    expect(progress, 1);
    debugNetworkImageHttpClientProvider = null;
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() => Supabase.instance.client.realtime.disconnect());
  });
}

// A local in-memory Supabase socket: joins/leaves are acknowledged, no remote WS.
class _FixtureSocket implements WebSocketChannel {
  _FixtureSocket(RealtimeClient client) : sink = _FixtureSink(client);
  @override
  final WebSocketSink sink;
  @override
  Stream<dynamic> get stream => const Stream.empty();
  @override
  Future<void> get ready async {}
  @override
  String? get protocol => null;
  @override
  int? get closeCode => null;
  @override
  String? get closeReason => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FixtureSink implements WebSocketSink {
  _FixtureSink(this.client);
  final RealtimeClient client;
  @override
  void add(dynamic event) {
    final message = jsonDecode(event as String) as Map<String, dynamic>;
    final changes =
        (message['payload']?['config']?['postgres_changes'] as List?) ?? [];
    scheduleMicrotask(
      () => client.onConnMessage(
        jsonEncode({
          'topic': message['topic'],
          'ref': message['ref'],
          'join_ref': message['join_ref'],
          'event': 'phx_reply',
          'payload': {
            'status': 'ok',
            'response': {
              'postgres_changes': [
                for (var i = 0; i < changes.length; i++)
                  {...changes[i] as Map, 'id': i},
              ],
            },
          },
        }),
      ),
    );
  }

  @override
  Future<void> close([int? closeCode, String? closeReason]) async {}
  @override
  Future<void> get done async {}
  @override
  void addError(Object error, [StackTrace? stackTrace]) {}
  @override
  Future<void> addStream(Stream<dynamic> stream) async {
    await for (final event in stream) {
      add(event);
    }
  }
}
