import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ── Constants ─────────────────────────────────────────────────────────────────
import '../constants/hub_colors.dart';

// ── Components ────────────────────────────────────────────────────────────────
import '../components/hub_hero_banner.dart';
import '../components/hub_stats_strip.dart';
import '../components/hub_section_header.dart';
import '../components/hub_core_layers.dart';
import '../components/hub_services_marketplace.dart';
import '../components/hub_tools_section.dart';
import '../components/hub_pricing_section.dart';
import '../components/hub_why_tokilo.dart';
import '../components/hub_cta_banner.dart';

// ══════════════════════════════════════════════════════════════════════════════
// SCREEN
// ══════════════════════════════════════════════════════════════════════════════
class TokiloHubScreen extends StatefulWidget {
  const TokiloHubScreen({super.key});

  @override
  State<TokiloHubScreen> createState() => _TokiloHubScreenState();
}

class _TokiloHubScreenState extends State<TokiloHubScreen>
    with SingleTickerProviderStateMixin {
  // ── Hero entrance animation ───────────────────────────────────────────────
  late AnimationController _heroCtrl;
  late Animation<double>   _heroFade;
  late Animation<Offset>   _heroSlide;

  @override
  void initState() {
    super.initState();

    // Light status-bar icons over the dark hero gradient
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    _heroCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _heroFade = CurvedAnimation(
      parent: _heroCtrl,
      curve: Curves.easeOut,
    );
    _heroSlide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _heroCtrl, curve: Curves.easeOutCubic));

    _heroCtrl.forward();
  }

  @override
  void dispose() {
    // Restore dark status-bar icons when leaving the screen
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));
    _heroCtrl.dispose();
    super.dispose();
  }

  // ── Handlers ─────────────────────────────────────────────────────────────
  void _onUpgradeTap() {
    // TODO: navigate to upgrade / subscription flow
  }

  void _onGetStarted() {
    // TODO: navigate to sign-up or onboarding
  }

  void _onContactUs() {
    // TODO: open WhatsApp / contact sheet
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HubColors.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── 1. HERO ─────────────────────────────────────────────────────
          HubSliverAppBar(
            fadeAnim:      _heroFade,
            slideAnim:     _heroSlide,
            onUpgradeTap:  _onUpgradeTap,
          ),

          // ── 2. BODY ─────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Stats strip
                const SizedBox(height: 24),
                const HubStatsStrip(),

                // Core layers
                const SizedBox(height: 32),
                const HubSectionHeader(
                  title: 'What We Offer',
                  sub: 'Four powerful layers in one platform',
                ),
                const SizedBox(height: 14),
                const HubCoreLayersGrid(),

                // Service marketplace
                const SizedBox(height: 32),
                const HubSectionHeader(
                  title: 'Service Marketplace',
                  sub: 'Book IT & digital services directly',
                ),
                const SizedBox(height: 14),
                const HubServicesMarketplace(),

                // Business tools
                const SizedBox(height: 32),
                const HubSectionHeader(
                  title: 'Business Tools',
                  sub: 'Free & Pro tools for your operations',
                ),
                const SizedBox(height: 14),
                const HubToolsSection(),

                // Pricing
                const SizedBox(height: 32),
                const HubSectionHeader(
                  title: 'Subscription Plans',
                  sub: 'Start free, scale with Pro',
                ),
                const SizedBox(height: 14),
                const HubPricingSection(),

                // Why Tokilo
                const SizedBox(height: 32),
                const HubWhyTokilo(),

                // CTA banner
                const SizedBox(height: 32),
                HubCtaBanner(
                  onGetStarted: _onGetStarted,
                  onContactUs:  _onContactUs,
                ),

                const SizedBox(height: 48),
              ],
            ),
          ),
        ],
      ),
    );
  }
}