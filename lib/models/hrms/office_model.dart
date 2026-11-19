class HrOffice {
  final int id;
  final int outletId;
  final String officeCode;
  final String officeName;
  final String address;
  final String city;
  final String state;
  final String pincode;
  final double latitude;
  final double longitude;
  final int radiusMeters;
  final bool isActive;
  final int employeeCount;

  HrOffice({
    required this.id,
    this.outletId = 1,
    required this.officeCode,
    required this.officeName,
    this.address = '',
    this.city = '',
    this.state = '',
    this.pincode = '',
    this.latitude = 0.0,
    this.longitude = 0.0,
    this.radiusMeters = 150,
    this.isActive = true,
    this.employeeCount = 0,
  });

  factory HrOffice.fromJson(Map<String, dynamic> json) {
    return HrOffice(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      outletId: json['outlet_id'] is int ? json['outlet_id'] : int.tryParse(json['outlet_id']?.toString() ?? '1') ?? 1,
      officeCode: json['office_code']?.toString() ?? '',
      officeName: json['office_name']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      state: json['state']?.toString() ?? '',
      pincode: json['pincode']?.toString() ?? '',
      latitude: double.tryParse(json['latitude']?.toString() ?? '0.0') ?? 0.0,
      longitude: double.tryParse(json['longitude']?.toString() ?? '0.0') ?? 0.0,
      radiusMeters: int.tryParse(json['radius_meters']?.toString() ?? '150') ?? 150,
      isActive: json['is_active'] != false,
      employeeCount: int.tryParse(json['employee_count']?.toString() ?? '0') ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'outlet_id': outletId,
    'office_code': officeCode,
    'office_name': officeName,
    'address': address,
    'city': city,
    'state': state,
    'pincode': pincode,
    'latitude': latitude,
    'longitude': longitude,
    'radius_meters': radiusMeters,
    'is_active': isActive,
  };
}
