import 'package:flutter/material.dart';

/// Vehicle classes accepted by the alert service (`vehicleType` 1..9).
enum VehicleKind {
  car(1, 'Ô tô', Icons.directions_car),
  motorcycle(2, 'Xe máy', Icons.two_wheeler),
  truck(3, 'Xe tải', Icons.local_shipping),
  coach(4, 'Xe khách', Icons.airport_shuttle),
  bus(5, 'Xe buýt', Icons.directions_bus),
  taxi(6, 'Taxi', Icons.local_taxi),
  bicycle(7, 'Xe đạp', Icons.directions_bike),
  pedestrian(8, 'Đi bộ', Icons.directions_walk),
  emergency(9, 'Xe ưu tiên', Icons.emergency);

  const VehicleKind(this.code, this.label, this.icon);

  /// Code sent as `AlertViewConfig.vehicleType`.
  final int code;
  final String label;
  final IconData icon;
}

/// The vehicle the engine is configured for: type + seats + gross weight.
@immutable
class VehicleProfile {
  const VehicleProfile({
    this.type = VehicleKind.car,
    this.seats = 5,
    this.weightKg = 1500,
  });

  final VehicleKind type;
  final int seats;
  final int weightKg;

  @override
  bool operator ==(Object other) =>
      other is VehicleProfile &&
      other.type == type &&
      other.seats == seats &&
      other.weightKg == weightKg;

  @override
  int get hashCode => Object.hash(type, seats, weightKg);
}
