import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Server origin from an incoming deep link (guest opens /join on another host).
final guestSessionServerProvider = StateProvider<String?>((ref) => null);
