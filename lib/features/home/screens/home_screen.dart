import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../admin/navigation/admin_router.dart';
import '../../../core/widgets/studio_ui.dart';
import '../../../core/widgets/tokilo_motion.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _supabase = Supabase.instance.client;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];
  @override
  void initState() {
    super.initState();
    _loadShowcase();
  }

  Future<void> _loadShowcase() async {
    setState(() {
      _loading = true;
      _error = null;
      _workIndex = 0;
    });
    try {
      final data = await _supabase
          .from('project_showcase')
          .select()
          .eq('is_active', true)
          .order('sort_order')
          .limit(8);
      if (mounted) {
        setState(() {
          _items = List<Map<String, dynamic>>.from(data);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Projects could not load. Pull down to retry.';
        });
      }
    }
  }

  final PageController _workPager = PageController(
    viewportFraction: .92,
    keepPage: false,
  );
  int _workIndex = 0;
  @override
  void dispose() {
    _workPager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fullName =
        _supabase.auth.currentUser?.userMetadata?['full_name']
            ?.toString()
            .trim() ??
        '';
    final firstName = fullName.isEmpty
        ? 'there'
        : fullName.split(RegExp(r'\s+')).first;
    return Scaffold(
      backgroundColor: StudioColors.paper,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadShowcase,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 14, 0),
                child: StudioHeader(showAdmin: true),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 20),
                child: ScrollReveal(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'HELLO, ${firstName.toUpperCase()}',
                              style: const TextStyle(
                                color: StudioColors.muted,
                                fontSize: 10,
                                letterSpacing: 1.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const _StudioArtStamp(),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text.rich(
                        TextSpan(
                          children: [
                            const TextSpan(text: 'Your next idea,\n'),
                            TextSpan(
                              text: 'made real.',
                              style: TextStyle(
                                backgroundColor: StudioColors.lime.withValues(
                                  alpha: .75,
                                ),
                              ),
                            ),
                          ],
                        ),
                        style: const TextStyle(
                          color: StudioColors.ink,
                          fontSize: 35,
                          height: 1.1,
                          letterSpacing: -1.4,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Web, mobile and AI. Built around your business.',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: StudioColors.muted,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () => context.go('/portal'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: StudioColors.ink,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(0, 48),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              shape: const StadiumBorder(),
                            ),
                            label: const Text('Start a project'),
                            icon: const Icon(
                              Icons.north_east_rounded,
                              size: 17,
                            ),
                          ),
                          TextButton(
                            onPressed: () => context.push('/portfolio'),
                            style: TextButton.styleFrom(
                              foregroundColor: StudioColors.ink,
                            ),
                            child: const Text(
                              'Explore our work',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: StudioSectionTitle(
                  title: 'Selected work',
                  action: 'View all',
                  onTap: () => context.push('/portfolio'),
                ),
              ),
              const SizedBox(height: 8),
              if (_loading)
                const SizedBox(
                  height: 200,
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else if (_error != null)
                _HomeNotice(
                  icon: Icons.cloud_off_outlined,
                  text: _error!,
                  onRetry: _loadShowcase,
                )
              else if (_items.isEmpty)
                const _HomeNotice(
                  icon: Icons.work_outline_rounded,
                  text: 'New projects will appear here as they are published.',
                )
              else ...[
                SizedBox(
                  height:
                      282 +
                      (MediaQuery.textScalerOf(context).scale(1) - 1) * 110,
                  child: PageView.builder(
                    controller: _workPager,
                    onPageChanged: (index) =>
                        setState(() => _workIndex = index),
                    itemCount: _items.length,
                    itemBuilder: (context, index) => Padding(
                      padding: const EdgeInsets.only(left: 12, right: 4),
                      child: _WorkCard(item: _items[index]),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                  child: Row(
                    children: [
                      for (var i = 0; i < _items.length; i++)
                        AnimatedContainer(
                          duration: MediaQuery.disableAnimationsOf(context)
                              ? Duration.zero
                              : const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(right: 5),
                          width: i == _workIndex ? 20 : 5,
                          height: 4,
                          decoration: BoxDecoration(
                            color: i == _workIndex
                                ? StudioColors.ink
                                : StudioColors.line,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      const Spacer(),
                      Text(
                        '${(_workIndex + 1).toString().padLeft(2, '0')} / ${_items.length.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: StudioColors.muted,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 26),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    _QuickLink(
                      icon: Icons.assignment_outlined,
                      label: 'Requests',
                      onTap: () => context.go('/portal'),
                    ),
                    const SizedBox(width: 10),
                    _QuickLink(
                      icon: Icons.chat_bubble_outline_rounded,
                      label: 'Messages',
                      onTap: () => context.push(
                        isAdminUser() ? '/admin/messages' : '/chat',
                      ),
                    ),
                    const SizedBox(width: 10),
                    _QuickLink(
                      icon: Icons.payments_outlined,
                      label: 'Pricing',
                      onTap: () => context.go('/marketplace'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: StudioSectionTitle(title: 'What are you building?'),
              ),
              const SizedBox(height: 8),
              for (final service in const [
                (
                  Icons.language_rounded,
                  'Web experiences',
                  'Websites, platforms and ecommerce',
                ),
                (
                  Icons.phone_iphone_rounded,
                  'Mobile products',
                  'Connected apps for Android and iOS',
                ),
                (
                  Icons.hub_outlined,
                  'Intelligent systems',
                  'AI, automation and business software',
                ),
              ])
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _ServiceLink(
                    icon: service.$1,
                    title: service.$2,
                    subtitle: service.$3,
                    onTap: () => context.go('/portal'),
                  ),
                ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _StudioInvitation(
                  onTap: () =>
                      context.push(isAdminUser() ? '/admin/messages' : '/chat'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudioArtStamp extends StatelessWidget {
  const _StudioArtStamp();
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      width: 56,
      height: 38,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: ViewportMotion(
          loop: true,
          builder: (_, value) => Transform.scale(
            scale: 1.2,
            child: Transform.translate(
              offset: Offset(value * 4 - 2, 0),
              child: Image.asset(
                'assets/images/tokilo-studio.webp',
                fit: BoxFit.cover,
                alignment: Alignment.centerRight,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _WorkCard extends StatelessWidget {
  const _WorkCard({required this.item});
  final Map<String, dynamic> item;
  @override
  Widget build(BuildContext context) {
    final title = item['title']?.toString() ?? 'Project';
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/portfolio'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StudioProjectMedia(
              title: title,
              url: item['image_url']?.toString(),
              category: item['subtitle']?.toString(),
              height: 184,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: StudioColors.ink,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -.4,
                              height: 1.2,
                            ),
                          ),
                          if (item['subtitle']?.toString().isNotEmpty ??
                              false) ...[
                            const SizedBox(height: 5),
                            Text(
                              item['subtitle'].toString(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: StudioColors.muted,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: StudioColors.lime,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.north_east_rounded,
                        size: 18,
                        color: StudioColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickLink extends StatelessWidget {
  const _QuickLink({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 3),
          child: Column(
            children: [
              Icon(icon, color: StudioColors.ink, size: 23),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: StudioColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ServiceLink extends StatelessWidget {
  const _ServiceLink({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: StudioColors.line)),
        ),
        child: Row(
          children: [
            Icon(icon, color: StudioColors.ink, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: StudioColors.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: StudioColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.north_east_rounded,
              size: 18,
              color: StudioColors.muted,
            ),
          ],
        ),
      ),
    ),
  );
}

class _HomeNotice extends StatelessWidget {
  const _HomeNotice({required this.icon, required this.text, this.onRetry});
  final IconData icon;
  final String text;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 24),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
    ),
    child: Row(
      children: [
        Icon(icon, color: StudioColors.muted),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 13, color: StudioColors.muted),
          ),
        ),
        if (onRetry != null)
          IconButton(
            tooltip: 'Retry projects',
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
          ),
      ],
    ),
  );
}

class _StudioInvitation extends StatelessWidget {
  const _StudioInvitation({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(24),
    child: Material(
      color: StudioColors.ink,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 128,
              width: double.infinity,
              child: ExcludeSemantics(
                child: ViewportMotion(
                  loop: true,
                  builder: (_, value) => Transform.scale(
                    scale: 1.06,
                    child: Transform.translate(
                      offset: Offset(value * 8 - 4, 0),
                      child: Image.asset(
                        'assets/images/tokilo-studio.webp',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Have something in mind?',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            letterSpacing: -.4,
                          ),
                        ),
                        SizedBox(height: 5),
                        Text(
                          'Let’s talk about your next product.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFFB7C4C2),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: StudioColors.lime,
                    size: 23,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
