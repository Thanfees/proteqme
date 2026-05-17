import 'package:flutter/material.dart';

/// Consistent brand surface for all screens.
///
/// Wraps content in the ProteqMe purple→pink gradient background with optional
/// glow blobs, plus a styled AppBar.  Use this instead of bare Scaffold so the
/// whole app looks like one product.
class BrandScaffold extends StatelessWidget {
  const BrandScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.floatingActionButton,
    this.showGlow = true,
    this.contentPadding = const EdgeInsets.fromLTRB(20, 16, 20, 24),
    this.scroll = true,
    this.leading,
  });

  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final bool showGlow;
  final EdgeInsets contentPadding;
  final bool scroll;
  final Widget? leading;

  static const _bgGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF14071F), Color(0xFF0E0618), Color(0xFF06030D)],
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: Color(0xFFFFE7F2),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: leading,
        actions: actions,
        iconTheme: const IconThemeData(color: Color(0xFFD9C5E9)),
      ),
      floatingActionButton: floatingActionButton,
      body: Container(
        decoration: const BoxDecoration(gradient: _bgGradient),
        child: Stack(
          children: [
            if (showGlow) ...const [
              Positioned(
                top: -140,
                right: -120,
                child: _GlowBlob(size: 280, color: Color(0x44FF4A94)),
              ),
              Positioned(
                bottom: -180,
                left: -130,
                child: _GlowBlob(size: 340, color: Color(0x332D68FF)),
              ),
            ],
            SafeArea(
              child: scroll
                  ? SingleChildScrollView(
                      padding: contentPadding,
                      child: body,
                    )
                  : Padding(padding: contentPadding, child: body),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  const _GlowBlob({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        width: size,
        height: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [color, color.withValues(alpha: 0)],
            ),
          ),
        ),
      ),
    );
  }
}

/// Glass-style card used across screens for grouped content.
class BrandCard extends StatelessWidget {
  const BrandCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderColor = const Color(0x44FF63A4),
    this.margin,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color borderColor;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: double.infinity,
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xD6221232), Color(0xD6171128)],
        ),
      ),
      padding: padding,
      child: child,
    );
    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: card,
      ),
    );
  }
}

/// A section header used inside the brand scaffold body.
class BrandSectionHeader extends StatelessWidget {
  const BrandSectionHeader({super.key, required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 18, 2, 8),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: const Color(0xFFFF6AA7)),
            const SizedBox(width: 6),
          ],
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Color(0xFFB59BC9),
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Pretty icon + title + subtitle tile shown inside a BrandCard.
class BrandTile extends StatelessWidget {
  const BrandTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.accent = const Color(0xFFFF6AA7),
    this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: accent.withValues(alpha: 0.4)),
                ),
                child: Icon(icon, color: accent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFFFE7F2),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.3,
                        color: Color(0xFFB59BC9),
                      ),
                    ),
                  ],
                ),
              ),
              trailing ??
                  const Icon(
                    Icons.chevron_right,
                    color: Color(0xFF8A7A9B),
                    size: 20,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
