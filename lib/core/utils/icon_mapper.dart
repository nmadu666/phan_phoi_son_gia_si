import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// Maps a KiotViet icon string (like "fas fa-shopping-basket") to a FontAwesome IconData.
IconData getIconFromKiotVietString(String? iconString) {
  if (iconString == null || iconString.isEmpty) {
    return FontAwesomeIcons.store; // Default icon
  }

  // Extracts the core icon name, e.g., "shopping-basket" from "fas fa-shopping-basket"
  final iconName = iconString.split(' ').last.replaceAll('fa-', '');

  switch (iconName) {
    // Map common KiotViet icons to their FontAwesome counterparts
    case 'shopping-basket':
      return FontAwesomeIcons.basketShopping;
    case 'desktop':
      return FontAwesomeIcons.desktop;
    case 'mobile-alt':
      return FontAwesomeIcons.mobileScreenButton;
    case 'handshake':
      return FontAwesomeIcons.handshake;
    case 'globe':
      return FontAwesomeIcons.globe;
    case 'store':
      return FontAwesomeIcons.store;
    case 'shopping-cart':
      return FontAwesomeIcons.cartShopping;

    // Add more mappings here as you discover other icons from the API

    default:
      return FontAwesomeIcons.circleQuestion; // Icon for unmapped strings
  }
}
