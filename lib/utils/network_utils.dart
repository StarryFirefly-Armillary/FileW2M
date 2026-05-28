import 'dart:io';

class NetworkUtils {
  static Future<String> getLocalIpAddress() async {
    try {
      // Get all network interfaces
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );

      // Find the first non-loopback interface
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (!addr.isLoopback && addr.address != '127.0.0.1') {
            return addr.address;
          }
        }
      }

      // Fallback: try to get IP by connecting to a remote address
      try {
        final socket = await Socket.connect('8.8.8.8', 80);
        final ip = socket.address.address;
        await socket.close();
        return ip;
      } catch (_) {}
    } catch (e) {
      print('Error getting IP address: $e');
    }

    return '未知';
  }

  static Future<List<String>> getAllIpAddresses() async {
    final List<String> addresses = [];

    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );

      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (!addr.isLoopback) {
            addresses.add(addr.address);
          }
        }
      }
    } catch (e) {
      print('Error getting IP addresses: $e');
    }

    return addresses;
  }
}
