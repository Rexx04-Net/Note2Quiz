import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import 'dashboard_screen.dart';
import 'login_screen.dart';

class LobbyScreen extends StatefulWidget {
  final String? userEmail;
  const LobbyScreen({super.key, this.userEmail});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> with TickerProviderStateMixin {
  // --- CAROUSEL SCROLLING LOGIC ---
  final ScrollController _scrollController = ScrollController();
  Timer? _scrollTimer;
  bool _isScrollingForward = true;

  // --- ENTRANCE ANIMATIONS ---
  late AnimationController _heroController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _heroController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _heroController, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.03),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _heroController, curve: Curves.easeOutCubic),
    );
    _heroController.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startAutoScroll());
  }

  void _startAutoScroll() {
    const double scrollSpeed = 0.8;
    const Duration tickDuration = Duration(milliseconds: 32);
    _scrollTimer = Timer.periodic(tickDuration, (timer) {
      if (!_scrollController.hasClients) return;
      double maxScroll = _scrollController.position.maxScrollExtent;
      double currentScroll = _scrollController.offset;
      if (_isScrollingForward) {
        if (currentScroll >= maxScroll) {
          _isScrollingForward = false;
        } else {
          _scrollController.jumpTo(currentScroll + scrollSpeed);
        }
      } else {
        if (currentScroll <= 0) {
          _isScrollingForward = true;
        } else {
          _scrollController.jumpTo(currentScroll - scrollSpeed);
        }
      }
    });
  }

  @override
  void dispose() {
    _heroController.dispose();
    _scrollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _enterAppDirectly() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DashboardScreen(email: widget.userEmail ?? "Guest"),
      ),
    );
  }

  void _goToLogin() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: colors.background,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // =========================================================
            // 1. TOP NAVIGATION BAR (Brand Logo + Minimalist Navigation)
            // =========================================================
            _buildClaudeNavBar(context),

            Divider(height: 1, thickness: 1, color: colors.border),

            // =========================================================
            // 2. HERO SECTION (Editorial Headline + 3D Logo Showcase)
            // =========================================================
            FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: _buildClaudeHero(context),
              ),
            ),

            // =========================================================
            // 3. PLATFORM CAPABILITIES TICKER (Replaces old static strip)
            // =========================================================
            _buildPlatformCapabilitiesBar(context),

            const SizedBox(height: 90),

            // =========================================================
            // 4. "What Can You Do with Note2Quiz?" (6-Card Grid)
            // =========================================================
            _buildUseCasesSection(context),

            const SizedBox(height: 90),

            // =========================================================
            // 5. FEATURE DISCOVERY CAROUSEL
            // =========================================================
            _buildFeaturesCarousel(context),

            const SizedBox(height: 100),

            // =========================================================
            // 6. MULTI-COLUMN EDITORIAL FOOTER (Claude Footer Style)
            // =========================================================
            _buildClaudeFooter(context),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Top Navigation Bar
  // ---------------------------------------------------------------------------
  Widget _buildClaudeNavBar(BuildContext context) {
    final colors = context.appColors;
    final isDark = context.isDarkMode;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
      color: colors.background,
      child: Row(
        children: [
          // 3D App Logo + Brand Name
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0062FE).withOpacity(0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: Image.asset(
                    'assets/images/app_logo.png',
                    width: 34,
                    height: 34,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: "Note2",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                      ),
                    ),
                    TextSpan(
                      text: "Quiz",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: const Color(0xFF0062FE),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const Spacer(),

          // Navigation Links
          if (MediaQuery.of(context).size.width > 860) ...[
            _navLink("Document to Quiz"),
            const SizedBox(width: 26),
            _navLink("Mistakes Bank"),
            const SizedBox(width: 26),
            _navLink("Spaced Recall"),
            const SizedBox(width: 26),
            _navLink("Study Roadmaps"),
            const SizedBox(width: 26),
            _navLink("Multiplayer Arena"),
            const SizedBox(width: 32),
          ],

          // Login Button
          if (widget.userEmail == null)
            TextButton(
              onPressed: _goToLogin,
              style: TextButton.styleFrom(
                foregroundColor: colors.mutedText,
                textStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14.5),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              child: const Text("Log In"),
            ),

          const SizedBox(width: 12),

          // Primary Launch Workspace Button
          FilledButton(
            onPressed: _enterAppDirectly,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0062FE),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 3,
              shadowColor: const Color(0x660062FE),
            ),
            child: const Text(
              "Launch Workspace",
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _navLink(String label) {
    final colors = context.appColors;
    return InkWell(
      onTap: () {},
      hoverColor: Colors.transparent,
      child: Text(
        label,
        style: TextStyle(
          color: colors.mutedText,
          fontSize: 14.5,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Hero Section
  // ---------------------------------------------------------------------------
  Widget _buildClaudeHero(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 960;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 60 : 28,
        vertical: isDesktop ? 70 : 40,
      ),
      child: isDesktop
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(flex: 6, child: _buildHeroTextContent(context)),
                const SizedBox(width: 48),
                Expanded(flex: 5, child: _buildClaudeHeroVisual(context)),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeroTextContent(context),
                const SizedBox(height: 48),
                Center(child: _buildClaudeHeroVisual(context)),
              ],
            ),
    );
  }

  Widget _buildHeroTextContent(BuildContext context) {
    final colors = context.appColors;
    final isDark = context.isDarkMode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Subtle Pill Tag
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFF0062FE).withOpacity(0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF0062FE).withOpacity(0.25)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF0062FE),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                "Next-Gen AI Retrieval & Retention",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF0062FE),
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Editorial Headline
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: "Build your mastery\non the ",
                style: GoogleFonts.newsreader(
                  fontSize: 54,
                  fontWeight: FontWeight.w600,
                  height: 1.12,
                  letterSpacing: -1.4,
                  color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                ),
              ),
              TextSpan(
                text: "Note2Quiz",
                style: GoogleFonts.newsreader(
                  fontSize: 54,
                  fontWeight: FontWeight.w700,
                  height: 1.12,
                  letterSpacing: -1.4,
                  color: const Color(0xFF0062FE),
                ),
              ),
              TextSpan(
                text: " Platform",
                style: GoogleFonts.newsreader(
                  fontSize: 54,
                  fontWeight: FontWeight.w600,
                  height: 1.12,
                  letterSpacing: -1.4,
                  color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Subtitle
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Text(
            "Transform your documents, slide decks, syllabi, and transcripts into active retrieval quizzes, adaptive weakness drills, and automated spaced revision schedules.",
            style: TextStyle(
              fontSize: 16.5,
              height: 1.6,
              color: colors.mutedText,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
        const SizedBox(height: 36),

        // Dual Action Buttons
        Wrap(
          spacing: 16,
          runSpacing: 14,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton(
              onPressed: _enterAppDirectly,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0062FE),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 4,
                shadowColor: const Color(0x660062FE),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Start studying free",
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, size: 18),
                ],
              ),
            ),

            OutlinedButton(
              onPressed: _enterAppDirectly,
              style: OutlinedButton.styleFrom(
                foregroundColor: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                side: BorderSide(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1),
                  width: 1.0,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text(
                "See study methodology",
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 3D Official Logo Showcase in Hero Visual
  // ---------------------------------------------------------------------------
  Widget _buildClaudeHeroVisual(BuildContext context) {
    return Center(
      child: Container(
        height: 380,
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 480),
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // Ambient Radiant Logo Blue Glow
            Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF0062FE).withOpacity(0.35),
                    const Color(0xFF0062FE).withOpacity(0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),

            // Centerpiece: Official 3D Note2Quiz Logo
            Container(
              width: 210,
              height: 210,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(44),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0062FE).withOpacity(0.45),
                    blurRadius: 40,
                    offset: const Offset(0, 16),
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.55),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(44),
                child: Image.asset(
                  'assets/images/app_logo.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),

            // Floating Chip 1: Top-Right
            Positioned(
              top: 16,
              right: 8,
              child: _buildFloatingHeroBadge(
                context,
                icon: Icons.auto_awesome_rounded,
                iconColor: const Color(0xFF38BDF8),
                label: "Instant Doc-to-Quiz",
                sublabel: "PDF, PPTX & OCR",
              ),
            ),

            // Floating Chip 2: Bottom-Left
            Positioned(
              bottom: 24,
              left: 4,
              child: _buildFloatingHeroBadge(
                context,
                icon: Icons.psychology_rounded,
                iconColor: const Color(0xFF0062FE),
                label: "Mistakes Bank",
                sublabel: "Misconception tracking",
              ),
            ),

            // Floating Chip 3: Bottom-Right
            Positioned(
              bottom: 40,
              right: -4,
              child: _buildFloatingHeroBadge(
                context,
                icon: Icons.schedule_send_rounded,
                iconColor: const Color(0xFF10B981),
                label: "Spaced Repetition",
                sublabel: "Gmail & Teams automation",
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingHeroBadge(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String label,
    required String sublabel,
  }) {
    final colors = context.appColors;
    final isDark = context.isDarkMode;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF101522).withOpacity(0.92) : Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                ),
              ),
              Text(
                sublabel,
                style: TextStyle(
                  fontSize: 11,
                  color: colors.mutedText,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3. Platform Capabilities & Live Highlights Ticker (Replaces old static strip)
  // ---------------------------------------------------------------------------
  Widget _buildPlatformCapabilitiesBar(BuildContext context) {
    final isDark = context.isDarkMode;
    final borderColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0C101B) : const Color(0xFFF8FAFC),
        border: Border(
          top: BorderSide(color: borderColor, width: 1),
          bottom: BorderSide(color: borderColor, width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 28,
            runSpacing: 14,
            children: [
              _buildCapabilityPill(
                context,
                icon: Icons.auto_awesome_rounded,
                title: "Multi-Modal Ingestion",
                subtitle: "PDF, PPTX, OCR slides, YouTube",
              ),
              _buildCapabilityDivider(borderColor),
              _buildCapabilityPill(
                context,
                icon: Icons.psychology_rounded,
                title: "Centralized Mistakes Bank",
                subtitle: "Diagnostic misconception analysis",
              ),
              _buildCapabilityDivider(borderColor),
              _buildCapabilityPill(
                context,
                icon: Icons.schedule_rounded,
                title: "Ebbinghaus SM-2 Engine",
                subtitle: "Automated retention intervals",
              ),
              _buildCapabilityDivider(borderColor),
              _buildCapabilityPill(
                context,
                icon: Icons.mark_email_read_rounded,
                title: "Dual-Channel Automation",
                subtitle: "Gmail & MS Teams review triggers",
              ),
              _buildCapabilityDivider(borderColor),
              _buildCapabilityPill(
                context,
                icon: Icons.military_tech_rounded,
                title: "Real-Time Arena",
                subtitle: "6-pin synchronized quiz duels",
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCapabilityPill(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final colors = context.appColors;
    final isDark = context.isDarkMode;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFF0062FE).withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: const Color(0xFF0062FE).withOpacity(0.25),
              width: 1,
            ),
          ),
          child: Icon(icon, size: 18, color: const Color(0xFF0062FE)),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                letterSpacing: -0.2,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11.5,
                color: colors.mutedText,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCapabilityDivider(Color color) {
    return Container(
      width: 1,
      height: 24,
      color: color,
    );
  }

  // ---------------------------------------------------------------------------
  // 4. "What Can You Do with Note2Quiz?" (6-Card Grid with Clear Explanations)
  // ---------------------------------------------------------------------------
  Widget _buildUseCasesSection(BuildContext context) {
    final colors = context.appColors;
    final isDark = context.isDarkMode;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Centered Main Heading matching Screenshot 4
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: "What Can You Do with ",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 38,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.9,
                        color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                      ),
                    ),
                    TextSpan(
                      text: "Note2Quiz?",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 38,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.9,
                        color: const Color(0xFF0062FE),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Subtitle
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Text(
                  "Transform your learning experience with our powerful AI-driven features designed to make studying more effective and engaging.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.55,
                    color: colors.mutedText,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              const SizedBox(height: 48),

              // 6-Card Responsive Grid (3x2 on desktop, 2x3 on tablet, 1x6 on mobile)
              LayoutBuilder(
                builder: (context, constraints) {
                  final double width = constraints.maxWidth;
                  int crossAxisCount = 3;
                  if (width < 720) {
                    crossAxisCount = 1;
                  } else if (width < 1060) {
                    crossAxisCount = 2;
                  }
                  final double spacing = 24;
                  final double cardWidth = (width - (crossAxisCount - 1) * spacing) / crossAxisCount;

                  return Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    alignment: WrapAlignment.center,
                    children: [
                      _buildSixGridCard(
                        icon: Icons.smart_toy_rounded,
                        title: "AI-Powered Quiz Generation",
                        description: "Transform your documents into interactive quizzes using advanced AI. Supports PDF, DOCX, PPTX, JPG, and PNG formats with smart content analysis.",
                        width: cardWidth,
                      ),
                      _buildSixGridCard(
                        icon: Icons.psychology_rounded,
                        title: "Centralized Mistakes Bank",
                        description: "Never repeat the same error twice. Every wrong answer is automatically cataloged with error frequency analysis and step-by-step misconception diagnostics.",
                        width: cardWidth,
                      ),
                      _buildSixGridCard(
                        icon: Icons.school_rounded,
                        title: "Adaptive Weakness Drills",
                        description: "Engage with adaptive quizzes that adjust to your learning style and track your progress in real-time for optimal knowledge retention.",
                        width: cardWidth,
                      ),
                      _buildSixGridCard(
                        icon: Icons.schedule_rounded,
                        title: "Automated Spaced Recall",
                        description: "Effortless long-term memory retention. Receive timely review reminders and bite-sized quiz links automatically delivered directly to your Gmail and Microsoft Teams.",
                        width: cardWidth,
                      ),
                      _buildSixGridCard(
                        icon: Icons.calendar_month_rounded,
                        title: "AI Study Roadmaps & Timetable",
                        description: "Plan your entire semester with ease. Extract exam dates and class schedules via timetable OCR, and generate structured weekly milestones with real-time tracking.",
                        width: cardWidth,
                      ),
                      _buildSixGridCard(
                        icon: Icons.groups_rounded,
                        title: "Real-Time Multiplayer Arena",
                        description: "Compete with peers in live synchronized quiz showdowns. Enter via 6-digit room codes, battle with streak multipliers, and climb the leaderboards.",
                        width: cardWidth,
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSixGridCard({
    required IconData icon,
    required String title,
    required String description,
    required double width,
  }) {
    final colors = context.appColors;
    final isDark = context.isDarkMode;

    return Container(
      width: width,
      constraints: const BoxConstraints(minHeight: 250),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          // Rounded icon container with soft Logo Blue tint matching Screenshot 4
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFF0062FE).withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFF0062FE).withOpacity(0.25),
                width: 1.0,
              ),
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: 26,
              color: const Color(0xFF0062FE),
            ),
          ),
          const SizedBox(height: 22),

          // Header
          Text(
            title,
            style: TextStyle(
              fontSize: 18.5,
              fontWeight: FontWeight.w700,
              color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 12),

          // Clear Explanation
          Text(
            description,
            style: TextStyle(
              fontSize: 14.5,
              height: 1.55,
              color: colors.mutedText,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Features Discovery Carousel
  // ---------------------------------------------------------------------------
  Widget _buildFeaturesCarousel(BuildContext context) {
    final isDark = context.isDarkMode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          "Core Learning Tools",
          style: GoogleFonts.newsreader(
            fontSize: 32,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.5,
            color: isDark ? const Color(0xFFFAF9F5) : const Color(0xFF141413),
          ),
        ),
        const SizedBox(height: 28),

        SizedBox(
          height: 260,
          child: ListView(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              const SizedBox(width: 32),
              _buildCleanToolCard("Smart Briefing Summaries", "Distill 60-page PDF slides into executive takeaways.", "📄"),
              _buildCleanToolCard("Interactive Flashcards", "3D card flip active recall with self-assessment grading.", "🗂️"),
              _buildCleanToolCard("Knowledge Mind Maps", "Generate interactive visual concept graphs automatically.", "🕸️"),
              _buildCleanToolCard("Audio Lecture Overviews", "Synthesize academic podcast-style audio summaries.", "🎙️"),
              _buildCleanToolCard("Timetable Schedule Scanner", "Extract weekly classes from images directly to .ICS.", "📅"),
              _buildCleanToolCard("Synchronized Quiz Battles", "Host live multiplayer classroom quiz battles.", "🏆"),
              const SizedBox(width: 32),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCleanToolCard(String title, String desc, String iconEmoji) {
    final colors = context.appColors;
    final isDark = context.isDarkMode;

    return Container(
      width: 280,
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF2E2E2A) : const Color(0xFFE5E3DC),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(iconEmoji, style: const TextStyle(fontSize: 32)),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark ? const Color(0xFFFAF9F5) : const Color(0xFF141413),
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            desc,
            style: TextStyle(fontSize: 13.5, height: 1.45, color: colors.mutedText),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Multi-Column Editorial Footer (Claude Exact Style)
  // ---------------------------------------------------------------------------
  Widget _buildClaudeFooter(BuildContext context) {
    final colors = context.appColors;
    final isDark = context.isDarkMode;
    final borderColor = isDark ? const Color(0xFF262622) : const Color(0xFFE5E3DC);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF10100F) : const Color(0xFFF3F1EB),
        border: Border(top: BorderSide(color: borderColor, width: 1.0)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 56),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Column 1: Logo & Mission
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0062FE).withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.asset(
                              'assets/images/app_logo.png',
                              width: 24,
                              height: 24,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: "Note2",
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.4,
                                  color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                                ),
                              ),
                              TextSpan(
                                text: "Quiz",
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.4,
                                  color: const Color(0xFF0062FE),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      "Active recall and intelligent spaced revision platform for university students.",
                      style: TextStyle(fontSize: 13.5, color: colors.mutedText, height: 1.5),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      "© 2026 NOTE2QUIZ CORP.",
                      style: TextStyle(fontSize: 11, letterSpacing: 1.2, color: colors.subtleText),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 32),

              // Column 2: Products
              Expanded(
                flex: 2,
                child: _footerColumn(
                  "Products",
                  ["AI Quiz Studio", "Mistakes Bank", "Spaced Automation", "Active Roadmaps", "Timetable Scanner"],
                ),
              ),

              // Column 3: Architecture
              Expanded(
                flex: 2,
                child: _footerColumn(
                  "Architecture",
                  ["Google Gemini Flash", "Ebbinghaus SM-2", "Power Automate", "Microsoft Teams", "Google SMTP Relay"],
                ),
              ),

              // Column 4: Academic
              Expanded(
                flex: 2,
                child: _footerColumn(
                  "Academic",
                  ["Research Paper", "Pedagogical Theory", "Testing Effect", "Evaluation Results", "Documentation"],
                ),
              ),
            ],
          ),

          const SizedBox(height: 48),
          Divider(color: borderColor, height: 1),
          const SizedBox(height: 24),

          // Bottom copyright and language
          Row(
            children: [
              Text(
                "Final Year Project 2 (FYP2) · Universiti Tunku Abdul Rahman",
                style: TextStyle(fontSize: 12, color: colors.subtleText),
              ),
              const Spacer(),
              Text(
                "English (UK)",
                style: TextStyle(fontSize: 12, color: colors.mutedText, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _footerColumn(String heading, List<String> links) {
    final colors = context.appColors;
    final isDark = context.isDarkMode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          heading,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isDark ? const Color(0xFFFAF9F5) : const Color(0xFF141413),
            letterSpacing: 0.1,
          ),
        ),
        const SizedBox(height: 14),
        ...links.map(
          (link) => Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: InkWell(
              onTap: _enterAppDirectly,
              child: Text(
                link,
                style: TextStyle(fontSize: 13, color: colors.mutedText),
              ),
            ),
          ),
        ),
      ],
    );
  }

}