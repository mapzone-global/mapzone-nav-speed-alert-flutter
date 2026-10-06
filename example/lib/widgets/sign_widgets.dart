import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:mapzone_nav_speed_alert/mapzone_nav_speed_alert.dart';
import 'package:provider/provider.dart';

import '../state/alert_controller.dart';

Color speedStatusColor(SpeedStatus status) => switch (status) {
  SpeedStatus.safe => const Color(0xFF2E7D32),
  SpeedStatus.approaching => const Color(0xFFEF6C00),
  SpeedStatus.speeding => const Color(0xFFC62828),
};

String speedStatusLabel(SpeedStatus status) => switch (status) {
  SpeedStatus.safe => 'Trong giới hạn',
  SpeedStatus.approaching => 'Sắp tới giới hạn',
  SpeedStatus.speeding => 'Vượt tốc độ!',
};

/// Speed-limit / next / camera / toll column, top-left. Disappears when the
/// engine has nothing to show; a muted camera or toll category shows up as an
/// absent tile because the engine gates the sign on the same mute mask.
class SignOverlay extends StatelessWidget {
  const SignOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.select<AlertController, SignsEvent?>((p) => p.signs);
    if (s == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SignTile(image: s.current, size: 76),
        SignTile(image: s.next, distanceMeters: s.nextDistMeters, size: 50),
        SignTile(image: s.camera, distanceMeters: s.cameraDistMeters, size: 50),
        SignTile(image: s.toll, distanceMeters: s.tollDistMeters, size: 50),
      ],
    );
  }
}

/// Restriction signs (no stopping, closed road, vehicle ban, built-up area,
/// turn restriction), a row along the top-right under the speed chip.
class RestrictionRow extends StatelessWidget {
  const RestrictionRow({super.key});

  @override
  Widget build(BuildContext context) {
    final r = context.select<AlertController, RestrictionEvent?>(
      (p) => p.restrictions,
    );
    if (r == null) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      children: [
        SignTile(image: r.stop, distanceMeters: r.stopDistMeters, size: 44),
        SignTile(image: r.closed, distanceMeters: r.closedDistMeters, size: 44),
        SignTile(
          image: r.vehicle,
          distanceMeters: r.vehicleDistMeters,
          size: 44,
        ),
        SignTile(image: r.bua, distanceMeters: r.buaDistMeters, size: 44),
        SignTile(image: r.turn, distanceMeters: r.turnDistMeters, size: 44),
      ],
    );
  }
}

/// One sign on a white disc with its distance underneath. `0 m` means "on it"
/// and shows no distance pill.
class SignTile extends StatelessWidget {
  const SignTile({
    super.key,
    required this.image,
    required this.size,
    this.distanceMeters,
  });

  final Uint8List? image;
  final int? distanceMeters;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (image == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.92),
              shape: BoxShape.circle,
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 6),
              ],
            ),
            child: SizedBox(
              width: size,
              height: size,
              // Signs are re-rendered every tick; keep the old frame until the
              // new one decodes so they do not flicker.
              child: Image.memory(image!, gaplessPlayback: true),
            ),
          ),
          if (distanceMeters != null && distanceMeters! > 0)
            Container(
              margin: const EdgeInsets.only(top: 2),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                formatDistance(distanceMeters!),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

String formatDistance(int m) =>
    m >= 1000 ? '${(m / 1000).toStringAsFixed(1)} km' : '$m m';

/// Current speed + speed-limit status, top-right.
class SpeedChip extends StatelessWidget {
  const SpeedChip({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AlertController>(
      builder: (context, p, _) {
        final status = p.signs?.speedStatus ?? SpeedStatus.safe;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: speedStatusColor(status),
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${p.speedKmh.toStringAsFixed(0)} km/h',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                speedStatusLabel(status),
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ],
          ),
        );
      },
    );
  }
}
