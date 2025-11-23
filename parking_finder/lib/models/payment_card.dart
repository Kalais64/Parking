import 'package:encrypt/encrypt.dart';

class PaymentCard {
  final String id;
  final String cardType; // 'e-Money', 'Bank', 'CreditCard'
  final String encryptedCardNumber;
  final String lastFourDigits;
  final String? expiryDate;
  final String? cardHolderName;
  final String? cardUID; // NFC UID for contactless cards
  final bool isNfcEnabled;
  final bool isDefault;
  final DateTime createdAt;
  final DateTime? lastUsed;

  PaymentCard({
    required this.id,
    required this.cardType,
    required this.encryptedCardNumber,
    required this.lastFourDigits,
    this.expiryDate,
    this.cardHolderName,
    this.cardUID,
    this.isNfcEnabled = false,
    this.isDefault = false,
    required this.createdAt,
    this.lastUsed,
  });

  // Encrypt card number for secure storage
  static String encryptCardNumber(String cardNumber, String key) {
    final keyBytes = Key.fromUtf8(key.padRight(32).substring(0, 32));
    final iv = IV.fromLength(16);
    final encrypter = Encrypter(AES(keyBytes));
    final encrypted = encrypter.encrypt(cardNumber, iv: iv);
    return encrypted.base64;
  }

  // Decrypt card number (use only when needed for payment)
  static String decryptCardNumber(String encryptedCardNumber, String key) {
    try {
      final keyBytes = Key.fromUtf8(key.padRight(32).substring(0, 32));
      final iv = IV.fromLength(16);
      final encrypter = Encrypter(AES(keyBytes));
      final decrypted = encrypter.decrypt64(encryptedCardNumber, iv: iv);
      return decrypted;
    } catch (e) {
      throw Exception('Failed to decrypt card number');
    }
  }

  // Mask card number for display
  static String maskCardNumber(String cardNumber) {
    if (cardNumber.length < 4) return '****';
    return '**** **** **** ${cardNumber.substring(cardNumber.length - 4)}';
  }

  // Validate card number using Luhn algorithm
  static bool isValidCardNumber(String cardNumber) {
    if (cardNumber.isEmpty || cardNumber.length < 13 || cardNumber.length > 19) {
      return false;
    }

    // Remove spaces and non-digit characters
    final cleanNumber = cardNumber.replaceAll(RegExp(r'[^0-9]'), '');
    
    // Luhn algorithm
    int sum = 0;
    bool isEven = false;
    
    for (int i = cleanNumber.length - 1; i >= 0; i--) {
      int digit = int.parse(cleanNumber[i]);
      
      if (isEven) {
        digit *= 2;
        if (digit > 9) {
          digit -= 9;
        }
      }
      
      sum += digit;
      isEven = !isEven;
    }
    
    return sum % 10 == 0;
  }

  // Detect card type from number
  static String detectCardType(String cardNumber) {
    final cleanNumber = cardNumber.replaceAll(RegExp(r'[^0-9]'), '');
    
    if (cleanNumber.startsWith('4')) {
      return 'Visa';
    } else if (cleanNumber.startsWith('5')) {
      return 'MasterCard';
    } else if (cleanNumber.startsWith('6')) {
      return 'Discover';
    } else if (cleanNumber.startsWith('3')) {
      return 'American Express';
    } else if (cleanNumber.startsWith('35')) {
      return 'JCB';
    } else if (RegExp(r'^8[0-9]{3,}').hasMatch(cleanNumber)) {
      return 'e-Money';
    } else {
      return 'Unknown';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'cardType': cardType,
      'encryptedCardNumber': encryptedCardNumber,
      'lastFourDigits': lastFourDigits,
      'expiryDate': expiryDate,
      'cardHolderName': cardHolderName,
      'cardUID': cardUID,
      'isNfcEnabled': isNfcEnabled,
      'isDefault': isDefault,
      'createdAt': createdAt.toIso8601String(),
      'lastUsed': lastUsed?.toIso8601String(),
    };
  }

  factory PaymentCard.fromJson(Map<String, dynamic> json) {
    return PaymentCard(
      id: json['id'],
      cardType: json['cardType'],
      encryptedCardNumber: json['encryptedCardNumber'],
      lastFourDigits: json['lastFourDigits'],
      expiryDate: json['expiryDate'],
      cardHolderName: json['cardHolderName'],
      cardUID: json['cardUID'],
      isNfcEnabled: json['isNfcEnabled'] ?? false,
      isDefault: json['isDefault'] ?? false,
      createdAt: DateTime.parse(json['createdAt']),
      lastUsed: json['lastUsed'] != null ? DateTime.parse(json['lastUsed']) : null,
    );
  }

  PaymentCard copyWith({
    String? id,
    String? cardType,
    String? encryptedCardNumber,
    String? lastFourDigits,
    String? expiryDate,
    String? cardHolderName,
    String? cardUID,
    bool? isNfcEnabled,
    bool? isDefault,
    DateTime? createdAt,
    DateTime? lastUsed,
  }) {
    return PaymentCard(
      id: id ?? this.id,
      cardType: cardType ?? this.cardType,
      encryptedCardNumber: encryptedCardNumber ?? this.encryptedCardNumber,
      lastFourDigits: lastFourDigits ?? this.lastFourDigits,
      expiryDate: expiryDate ?? this.expiryDate,
      cardHolderName: cardHolderName ?? this.cardHolderName,
      cardUID: cardUID ?? this.cardUID,
      isNfcEnabled: isNfcEnabled ?? this.isNfcEnabled,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      lastUsed: lastUsed ?? this.lastUsed,
    );
  }
}