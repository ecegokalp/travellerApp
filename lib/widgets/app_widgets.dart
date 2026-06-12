import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Shared brand colors, matching the login page's teal accent.
const kBrandPrimary = Color(0xFF0D9488);
const kBrandLight = Color(0xFF2DD4BF);
const kBrandGradient = LinearGradient(colors: [kBrandPrimary, kBrandLight]);

/// Consistent custom header used across the app in place of a default
/// Material [AppBar]: transparent background, centered Playfair Display
/// title, and an automatic back button when the route can be popped.
class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool centerTitle;

  const AppHeader({super.key, required this.title, this.actions, this.centerTitle = true});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1F2937);

    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: centerTitle,
      automaticallyImplyLeading: false,
      leading: Navigator.canPop(context)
          ? IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 20),
              onPressed: () => Navigator.pop(context),
            )
          : null,
      title: Text(
        title,
        style: GoogleFonts.playfairDisplay(fontSize: 20, fontWeight: FontWeight.w800, color: textColor),
      ),
      actions: actions,
    );
  }
}

/// Standardized content card: theme-aware background with a soft border
/// and shadow, matching the app's most polished existing card style.
class SectionCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;

  const SectionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.borderRadius = 20,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: margin,
      padding: padding,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE8E4DC), width: 0.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(isDark ? 20 : 5), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: child,
    );
  }
}

/// Primary call-to-action button with the brand's teal gradient, matching
/// the login page's gradient button.
class GradientButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;

  const GradientButton({super.key, required this.label, this.onPressed, this.loading = false, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        gradient: kBrandGradient,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: kBrandPrimary.withAlpha(60), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                  ],
                  Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                ],
              ),
      ),
    );
  }
}
