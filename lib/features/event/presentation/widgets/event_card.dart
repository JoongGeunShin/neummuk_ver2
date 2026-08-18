import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../../core/utils/context_ext.dart';
import '../../domain/entities/event_entity.dart';

class EventCard extends StatelessWidget {
  const EventCard({super.key, required this.event, this.onTap});

  final EventEntity event;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final imageH = context.hp(13);
    final cardW = context.wp(55);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: cardW,
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: c.outline),
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 이미지 영역 ──────────────────────────────
            Stack(
              children: [
                _EventImage(imageUrl: event.imageUrl, height: imageH),
                // D-day 배지
                if (event.daysLabel.isNotEmpty)
                  Positioned(
                    top: 8,
                    left: 10,
                    child: _DaysBadge(label: event.daysLabel, event: event),
                  ),
              ],
            ),

            // ── 텍스트 영역 ──────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.name,
                      style: TextStyle(
                        color: c.text,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        letterSpacing: -0.2,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (event.dateRangeLabel.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.calendar_today_rounded,
                              size: 10, color: c.textMuted),
                          const SizedBox(width: 3),
                          Text(
                            event.dateRangeLabel,
                            style: TextStyle(
                              color: c.textMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (event.addr != null && event.addr!.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(Icons.place_rounded,
                              size: 10, color: c.textMuted),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              _shortAddr(event.addr!),
                              style: TextStyle(
                                color: c.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (event.distanceFromUserM != null) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(Icons.near_me_rounded,
                              size: 10, color: c.primary),
                          const SizedBox(width: 3),
                          Text(
                            _distLabel(event.distanceFromUserM!),
                            style: TextStyle(
                              color: c.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _shortAddr(String addr) {
    final parts = addr.split(' ');
    return parts.take(3).join(' ');
  }

  String _distLabel(int meters) {
    if (meters < 1000) return '${meters}m';
    return '${(meters / 1000).toStringAsFixed(1)}km';
  }
}

// ── 이미지 (CachedNetworkImage + placeholder) ────────────────

class _EventImage extends StatelessWidget {
  const _EventImage({required this.imageUrl, required this.height});

  final String? imageUrl;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: imageUrl!,
        width: double.infinity,
        height: height,
        fit: BoxFit.cover,
        placeholder: (_, __) => _Placeholder(height: height),
        errorWidget: (_, __, ___) => _Placeholder(height: height),
      );
    }
    return _Placeholder(height: height);
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.height});
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c.primarySoft, c.secondarySoft],
        ),
      ),
      child: Icon(Icons.festival_rounded, size: 36, color: c.primary),
    );
  }
}

// ── D-day 배지 ────────────────────────────────────────────────

class _DaysBadge extends StatelessWidget {
  const _DaysBadge({required this.label, required this.event});

  final String label;
  final EventEntity event;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final Color bg;
    if (event.isOngoing) {
      bg = c.success;
    } else if (event.daysUntilStart == 0) {
      bg = c.secondary;
    } else {
      bg = c.primary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
