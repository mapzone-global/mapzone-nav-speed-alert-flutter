/// Vehicle type passed to `NavSpeedAlert.configure`.
///
/// [value] is the alert service's own vehicle code, sent unchanged — the same
/// numbers as the native SDK 2.0.0 `AlertVehicleType` enum on Android and iOS.
/// It also picks the artwork of the vehicle-restricted sign.
///
/// The type must be enabled for your API key; otherwise sign-in and segment
/// requests report `AlertViewError.vehicleTypeNotAllowed` (`3003`).
///
/// Coming from 1.0.0? The numbers changed: see the README section *Migrating
/// from 1.0.0 to 2.0.0*. Do not feed an old stored number to [fromValue].
enum AlertVehicleType {
  /// Car (xe ô tô).
  car(1),

  /// Taxi (xe taxi).
  taxi(2),

  /// Bus (xe buýt).
  bus(3),

  /// Coach (xe khách).
  coach(4),

  /// Truck (xe tải).
  truck(5),

  /// Motorcycle (xe máy).
  motorcycle(7);

  const AlertVehicleType(this.value);

  /// Service vehicle code.
  final int value;

  /// The type for a service vehicle code, or `null` when the SDK does not
  /// offer it.
  static AlertVehicleType? fromValue(int value) {
    for (final type in AlertVehicleType.values) {
      if (type.value == value) return type;
    }
    return null;
  }
}
