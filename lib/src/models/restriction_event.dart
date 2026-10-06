import 'dart:typed_data';

import 'map_read.dart';

/// Road-restriction signs for one GPS tick, from
/// `NavSpeedAlert.onRestriction`.
///
/// The four restriction slots are independent: one stretch of road may be in
/// a built-up area, closed to your vehicle type and no-stopping at once. A
/// distance of `0` means the vehicle is currently on that stretch; an empty
/// slot has a `null` image.
class RestrictionEvent {
  /// Creates an event.
  const RestrictionEvent({
    required this.stop,
    required this.stopDistMeters,
    required this.closed,
    required this.closedDistMeters,
    required this.vehicle,
    required this.vehicleDistMeters,
    required this.bua,
    required this.buaDistMeters,
    required this.inBua,
    required this.turn,
    required this.turnDistMeters,
  });

  /// Decodes the platform-channel payload.
  factory RestrictionEvent.fromMap(Map<Object?, Object?> m) => RestrictionEvent(
    stop: m.bytes('stop'),
    stopDistMeters: m.integer('stopDistMeters'),
    closed: m.bytes('closed'),
    closedDistMeters: m.integer('closedDistMeters'),
    vehicle: m.bytes('vehicle'),
    vehicleDistMeters: m.integer('vehicleDistMeters'),
    bua: m.bytes('bua'),
    buaDistMeters: m.integer('buaDistMeters'),
    inBua: m.flag('inBua'),
    turn: m.bytes('turn'),
    turnDistMeters: m.integer('turnDistMeters'),
  );

  /// No-parking / no-stopping sign.
  final Uint8List? stop;

  /// Distance to [stop] in metres.
  final int stopDistMeters;

  /// Road-closed sign.
  final Uint8List? closed;

  /// Distance to [closed] in metres.
  final int closedDistMeters;

  /// Sign for a road closed to the configured vehicle type.
  final Uint8List? vehicle;

  /// Distance to [vehicle] in metres.
  final int vehicleDistMeters;

  /// Built-up-area sign: shown for the whole time inside the area, and an
  /// end-of-area sign for a few seconds after leaving it.
  final Uint8List? bua;

  /// Distance to [bua] in metres (`0` while inside).
  final int buaDistMeters;

  /// Whether the vehicle is currently inside a built-up area.
  final bool inBua;

  /// Turn-restriction sign (banned or mandatory manoeuvres).
  final Uint8List? turn;

  /// Distance to [turn] in metres.
  final int turnDistMeters;
}
