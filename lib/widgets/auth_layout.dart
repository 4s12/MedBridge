import 'package:flutter/material.dart';

import '../theme.dart';

/// Breakpoint (logical pixels) above which the split desktop layout is used.
const double kAuthWideBreakpoint = 900;

/// Responsive shell for the authentication screens (Login / Register).
///
/// * Wide screens (web / desktop / tablets in landscape): a branded gradient
///   panel on the left and the form inside an elevated card on the right.
/// * Narrow screens (phones): the form is shown in a single centred column.
///
/// [builder] receives `isWide` so the caller can hide elements that the
/// brand panel already shows (e.g. the logo header).
class AuthLayout extends StatelessWidget {
  final Widget Function(BuildContext context, bool isWide) builder;

  /// Max width of the form on wide screens.
  final double formMaxWidth;

  /// Optional app bar used only on narrow screens.
  final PreferredSizeWidget? mobileAppBar;

  const AuthLayout({
    super.key,
    required this.builder,
    this.formMaxWidth = 440,
    this.mobileAppBar,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= kAuthWideBreakpoint;
        if (!isWide) {
          return Scaffold(
            appBar: mobileAppBar,
            body: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: formMaxWidth),
                    child: builder(context, false),
                  ),
                ),
              ),
            ),
          );
        }

        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Scaffold(
          body: Row(
            children: [
              // ─── Brand panel ───
              Expanded(
                flex: 5,
                child: _BrandPanel(compact: constraints.maxWidth < 1150),
              ),
              // ─── Form panel ───
              Expanded(
                flex: 6,
                child: Container(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 40, vertical: 40),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: formMaxWidth),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(36, 36, 36, 28),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1A1A26)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.06)
                                  : kPrimary.withValues(alpha: 0.08),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black
                                    .withValues(alpha: isDark ? 0.4 : 0.07),
                                blurRadius: 40,
                                offset: const Offset(0, 16),
                              ),
                            ],
                          ),
                          child: builder(context, true),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Left-hand gradient panel with logo, tagline and feature highlights.
class _BrandPanel extends StatelessWidget {
  final bool compact;
  const _BrandPanel({required this.compact});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF12A0AB), kPrimary, Color(0xFF064349)],
          stops: [0.0, 0.45, 1.0],
        ),
      ),
      child: Stack(
        children: [
          // Decorative soft circles
          Positioned(
            top: -120,
            right: -80,
            child: _circle(320, 0.08),
          ),
          Positioned(
            bottom: -140,
            left: -100,
            child: _circle(380, 0.06),
          ),
          Positioned(
            top: 180,
            left: -40,
            child: _circle(120, 0.05),
          ),
          // Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                    horizontal: compact ? 40 : 64, vertical: 40),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.25)),
                            ),
                            child: const Icon(Icons.local_hospital,
                                color: Colors.white, size: 32),
                          ),
                          const SizedBox(width: 14),
                          const Text(
                            'MedBridge',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 48),
                      Text(
                        'Bridging Care.\nConnecting Lives.',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: compact ? 34 : 42,
                          height: 1.15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Book appointments, manage prescriptions and keep '
                        'your medical records in one secure place.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 16,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 40),
                      const _Feature(
                        icon: Icons.calendar_month_outlined,
                        title: 'Easy appointments',
                        subtitle: 'Pick a doctor, date and slot in seconds',
                      ),
                      const _Feature(
                        icon: Icons.folder_shared_outlined,
                        title: 'Digital records',
                        subtitle: 'Diagnoses and prescriptions, always handy',
                      ),
                      const _Feature(
                        icon: Icons.notifications_active_outlined,
                        title: 'Real-time updates',
                        subtitle: 'Get notified when doctors respond',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _circle(double size, double alpha) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: alpha),
        ),
      );
}

class _Feature extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _Feature(
      {required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
