class KiotVietPartnerDelivery {
  final int? id;
  final String? code;
  final String? name;
  final String? address;
  final String? email;
  final String? contactName;
  final String? contactNumber;

  KiotVietPartnerDelivery({
    this.id,
    this.code,
    this.name,
    this.address,
    this.email,
    this.contactName,
    this.contactNumber,
  });

  factory KiotVietPartnerDelivery.fromJson(Map<String, dynamic> json) {
    return KiotVietPartnerDelivery(
      id: json['id'],
      code: json['code'],
      name: json['name'],
      address: json['address'],
      email: json['email'],
      contactName: json['contactName'],
      contactNumber: json['contactNumber'],
    );
  }
}
