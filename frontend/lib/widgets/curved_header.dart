library;

import 'package:flutter/material.dart';

/// Modern curved header with personalized greeting & current location badge
class CurvedHeader extends StatelessWidget {
  final String greeting;
  final String currentLocation;
  final Widget? leading;
  final Widget? trailing;
  final Widget? bottomChild;
  final VoidCallback? onRefreshLocation;

  const CurvedHeader({
    super.key,
    this.greeting = 'Hi Mathavan 👋',
    this.currentLocation = 'Fetching current location...',
    this.leading,
    this.trailing,
    this.bottomChild,
    this.onRefreshLocation,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0F3A78),
            Color(0xFF1565C0),
            Color(0xFF1E88E5),
          ],
        ),
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1565C0).withValues(alpha: 0.22),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // App Logo / Custom Leading
                  leading ??
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.5),
                            width: 1.8,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/logo/app_logo.png',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: Colors.white.withValues(alpha: 0.2),
                              child: const Icon(
                                Icons.bolt_rounded,
                                color: Color(0xFFFFD54F),
                                size: 28,
                              ),
                            ),
                          ),
                        ),
                      ),
                  const SizedBox(width: 14),

                  // Greeting & Current Location
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          greeting,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 21,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 3),
                        InkWell(
                          onTap: onRefreshLocation,
                          borderRadius: BorderRadius.circular(8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.near_me_rounded,
                                size: 13,
                                color: Color(0xFFFFD54F), // Amber location icon
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  currentLocation,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (trailing != null) trailing!,
                ],
              ),
              if (bottomChild != null) ...[
                const SizedBox(height: 16),
                bottomChild!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
