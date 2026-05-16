import 'package:telephony/telephony.dart';

/// Carrier SMS and voice dial — requires physical device for full fidelity.
class TelephonyService {
  TelephonyService() : _telephony = Telephony.instance;

  final Telephony _telephony;

  Future<bool> sendSms({
    required String phone,
    required String message,
  }) async {
    try {
      await _telephony.sendSms(
        to: phone,
        message: message,
        isMultipart: message.length > 160,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> callNumber(String phone) async {
    await _telephony.dialPhoneNumber(phone);
  }
}
