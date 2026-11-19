import 'package:flutter/material.dart';
import 'package:mapzone_nav_speed_alert/mapzone_nav_speed_alert.dart';

/// The vehicle types the SDK offers, with their label and icon in this app.
enum VehicleKind {
  car(AlertVehicleType.car, 'Ô tô', Icons.directions_car),
  taxi(AlertVehicleType.taxi, 'Taxi', Icons.local_taxi),
  bus(AlertVehicleType.bus, 'Xe buýt', Icons.directions_bus),
  coach(AlertVehicleType.coach, 'Xe khách', Icons.airport_shuttle),
  truck(AlertVehicleType.truck, 'Xe tải', Icons.local_shipping),
  motorcycle(AlertVehicleType.motorcycle, 'Xe máy', Icons.two_wheeler);

  const VehicleKind(this.sdkType, this.label, this.icon);

  /// Sent as `AlertViewConfig.vehicleType`.
  final AlertVehicleType sdkType;
  final String label;
  final IconData icon;
}

/// The vehicle the engine is configured for: type + seats + gross weight.
@immutable
class VehicleProfile {
  const VehicleProfile({
    this.type = VehicleKind.car,
    this.seats = 5,
    this.weightTons = 1.5,
  });

  final VehicleKind type;
  final int seats;

  /// Gross weight in tonnes, the unit the service reads.
  final double weightTons;

  @override
  bool operator ==(Object other) =>
      other is VehicleProfile &&
      other.type == type &&
      other.seats == seats &&
      other.weightTons == weightTons;

  @override
  int get hashCode => Object.hash(type, seats, weightTons);
}
