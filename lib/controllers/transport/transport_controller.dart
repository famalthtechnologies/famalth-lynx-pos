import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';

class TransportController extends ChangeNotifier {
  bool loading = false;
  List<dynamic> vehicles = [];
  List<dynamic> drivers = [];
  List<dynamic> activeTrips = [];

  // ==========================================
  // VEHICLE MANAGEMENT
  // ==========================================
  Future<void> loadVehicles({String? status, String? search}) async {
    loading = true;
    notifyListeners();
    try {
      String query = '';
      final params = <String>[];
      if (status != null && status != 'ALL') params.add('status=$status');
      if (search != null && search.trim().isNotEmpty) params.add('search=${Uri.encodeComponent(search.trim())}');
      if (params.isNotEmpty) query = '?${params.join('&')}';

      final res = await ApiClient.get('${ApiEndpoints.transportVehicles}$query');
      if (res['success'] == true) {
        vehicles = res['data'] ?? [];
      }
    } catch (e) {
      debugPrint('Error loading vehicles: $e');
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> addVehicle({
    required String vehicleNumber,
    required String vehicleType,
    double capacityTonnage = 0.0,
    String capacityUnit = 'Tons',
    String? model,
    String? notes,
  }) async {
    loading = true;
    notifyListeners();
    try {
      final res = await ApiClient.post(ApiEndpoints.transportVehicles, {
        'vehicle_number': vehicleNumber,
        'vehicle_type': vehicleType,
        'capacity_tonnage': capacityTonnage,
        'capacity_unit': capacityUnit,
        'model': model,
        'notes': notes,
      });
      await loadVehicles();
      return res['success'] == true;
    } catch (e) {
      debugPrint('Error adding vehicle: $e');
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> updateVehicle(int id, Map<String, dynamic> data) async {
    try {
      final res = await ApiClient.put('${ApiEndpoints.transportVehicles}/$id', data);
      await loadVehicles();
      return res['success'] == true;
    } catch (e) {
      debugPrint('Error updating vehicle: $e');
      return false;
    }
  }

  Future<bool> deleteVehicle(int id) async {
    try {
      final res = await ApiClient.delete('${ApiEndpoints.transportVehicles}/$id');
      await loadVehicles();
      return res['success'] == true;
    } catch (e) {
      debugPrint('Error deleting vehicle: $e');
      return false;
    }
  }

  // ==========================================
  // DRIVER MANAGEMENT
  // ==========================================
  Future<void> loadDrivers({String? status, String? search}) async {
    loading = true;
    notifyListeners();
    try {
      String query = '';
      final params = <String>[];
      if (status != null && status != 'ALL') params.add('status=$status');
      if (search != null && search.trim().isNotEmpty) params.add('search=${Uri.encodeComponent(search.trim())}');
      if (params.isNotEmpty) query = '?${params.join('&')}';

      final res = await ApiClient.get('${ApiEndpoints.transportDrivers}$query');
      if (res['success'] == true) {
        drivers = res['data'] ?? [];
      }
    } catch (e) {
      debugPrint('Error loading drivers: $e');
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> addDriver({
    required String driverName,
    required String phone,
    String? licenseNumber,
    String? address,
  }) async {
    loading = true;
    notifyListeners();
    try {
      final res = await ApiClient.post(ApiEndpoints.transportDrivers, {
        'driver_name': driverName,
        'phone': phone,
        'license_number': licenseNumber,
        'address': address,
      });
      await loadDrivers();
      return res['success'] == true;
    } catch (e) {
      debugPrint('Error adding driver: $e');
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> updateDriver(int id, Map<String, dynamic> data) async {
    try {
      final res = await ApiClient.put('${ApiEndpoints.transportDrivers}/$id', data);
      await loadDrivers();
      return res['success'] == true;
    } catch (e) {
      debugPrint('Error updating driver: $e');
      return false;
    }
  }

  Future<bool> deleteDriver(int id) async {
    try {
      final res = await ApiClient.delete('${ApiEndpoints.transportDrivers}/$id');
      await loadDrivers();
      return res['success'] == true;
    } catch (e) {
      debugPrint('Error deleting driver: $e');
      return false;
    }
  }

  // ==========================================
  // TRIP ASSIGNMENT (MULTI-CHALLAN GROUPING)
  // ==========================================
  Future<Map<String, dynamic>?> assignTrip({
    required int vehicleId,
    required int driverId,
    required List<int> challanIds,
    String? eWayBillNo,
    String? destinationAddress,
  }) async {
    loading = true;
    notifyListeners();
    try {
      final res = await ApiClient.post(ApiEndpoints.transportAssignTrip, {
        'vehicle_id': vehicleId,
        'driver_id': driverId,
        'challan_ids': challanIds,
        'e_way_bill_no': eWayBillNo,
        'destination_address': destinationAddress,
      });
      await Future.wait([
        loadVehicles(),
        loadDrivers(),
        loadActiveTrips(),
      ]);
      if (res['success'] == true) {
        return res;
      }
      return null;
    } catch (e) {
      debugPrint('Error assigning trip: $e');
      return null;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  // ==========================================
  // DELIVERY VERIFICATION (OTP OR DRIVER SUBMIT)
  // ==========================================
  Future<Map<String, dynamic>> verifyDelivery({
    required int challanId,
    String? otp,
    String? remark,
    String? receiverName,
  }) async {
    loading = true;
    notifyListeners();
    try {
      final res = await ApiClient.post(ApiEndpoints.transportVerifyDelivery, {
        'challan_id': challanId,
        'otp': otp,
        'remark': remark,
        'receiver_name': receiverName,
      });
      await Future.wait([
        loadVehicles(),
        loadDrivers(),
        loadActiveTrips(),
      ]);
      return res;
    } catch (e) {
      debugPrint('Error verifying delivery: $e');
      return {'success': false, 'message': e.toString()};
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  // ==========================================
  // RELEASE TRIP
  // ==========================================
  Future<bool> releaseTrip({int? vehicleId, int? driverId, String? tripId}) async {
    try {
      final res = await ApiClient.post(ApiEndpoints.transportReleaseTrip, {
        'vehicle_id': vehicleId,
        'driver_id': driverId,
        'trip_id': tripId,
      });
      await Future.wait([
        loadVehicles(),
        loadDrivers(),
        loadActiveTrips(),
      ]);
      return res['success'] == true;
    } catch (e) {
      debugPrint('Error releasing trip: $e');
      return false;
    }
  }

  // ==========================================
  // ACTIVE TRIPS
  // ==========================================
  Future<void> loadActiveTrips() async {
    try {
      final res = await ApiClient.get(ApiEndpoints.transportActiveTrips);
      if (res['success'] == true) {
        activeTrips = res['data'] ?? [];
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading active trips: $e');
    }
  }
}
