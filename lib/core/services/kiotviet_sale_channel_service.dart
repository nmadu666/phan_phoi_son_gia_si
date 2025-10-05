import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:phan_phoi_son_gia_si/core/models/kiotviet_sale_channel.dart';

class KiotVietSaleChannelService {
  final FirebaseFirestore _firestore;

  KiotVietSaleChannelService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<List<KiotVietSaleChannel>> getSaleChannels() async {
    try {
      final querySnapshot = await _firestore
          .collection('kiotviet_sale_channels')
          .where('isActive', isEqualTo: true)
          .get();
      final channels = querySnapshot.docs
          .map((doc) => KiotVietSaleChannel.fromFirestore(doc))
          .toList();
      return channels;
    } catch (e) {
      print('An unexpected error occurred while fetching sale channels: $e');
      return [];
    }
  }
}
