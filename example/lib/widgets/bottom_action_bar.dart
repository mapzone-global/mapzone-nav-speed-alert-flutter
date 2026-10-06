import 'package:flutter/material.dart';

/// The bar at the bottom of the map, which morphs rather than stacking two
/// widgets: a Start pill while idle, a route/engine status card with a Stop
/// button while running.
class BottomActionBar extends StatelessWidget {
  const BottomActionBar({
    super.key,
    required this.running,
    required this.busy,
    required this.hasDestination,
    required this.statusLine,
    required this.engineReady,
    required this.engineStatus,
    required this.onStart,
    required this.onStop,
  });

  /// Navigation (and the route alert) is active.
  final bool running;

  /// A route is being built — Start is disabled so it cannot be double-fired.
  final bool busy;

  /// The alert runs along a route, so Start needs a destination.
  final bool hasDestination;

  final String statusLine;
  final bool engineReady;
  final String engineStatus;
  final VoidCallback onStart;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    if (!running) return _startButton(context);
    return _statusCard(context);
  }

  Widget _startButton(BuildContext context) {
    return SizedBox(
      height: 56,
      child: FilledButton.icon(
        onPressed: busy || !hasDestination ? null : onStart,
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          elevation: 6,
        ),
        icon: busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.play_arrow),
        label: Text(
          busy
              ? 'Đang tạo tuyến…'
              : hasDestination
              ? 'Bắt đầu navigation'
              : 'Chọn điểm đến để bắt đầu',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _statusCard(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    statusLine,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: engineReady
                              ? const Color(0xFF2E7D32)
                              : const Color(0xFFEF6C00),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          engineStatus,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: onStop,
              tooltip: 'Kết thúc',
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFFC62828),
                foregroundColor: Colors.white,
                fixedSize: const Size(44, 44),
              ),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ),
    );
  }
}
