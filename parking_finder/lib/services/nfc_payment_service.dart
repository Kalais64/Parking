import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';
import 'package:ndef/ndef.dart' as ndef;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/payment_card.dart';

class NFCPaymentService {
  static const String _storageKey = 'payment_cards';
  static const String _encryptionKey = 'parking_app_nfc_encryption_key_2024';
  
  // Check if NFC is available on the device
  static Future<bool> isNFCAvailable() async {
    try {
      return await NfcManager.instance.isAvailable();
    } catch (e) {
      print('NFC availability check error: $e');
      return false;
    }
  }

  // Start NFC scanning for payment cards
  static Future<Map<String, dynamic>?> scanNFCCard() async {
    try {
      // Check if NFC is available
      if (!await isNFCAvailable()) {
        throw Exception('NFC is not available on this device');
      }

      // Start NFC session
      NFCTag? tag = await FlutterNfcKit.poll(timeout: Duration(seconds: 30));
      
      if (tag == null) {
        throw Exception('No NFC tag detected');
      }

      Map<String, dynamic> cardData = {};
      
      // Read different types of NFC cards
      if (tag.ndefAvailable ?? false) {
        // Read NDEF records
        var ndefRecords = await FlutterNfcKit.readNDEFRecords(cached: false);
        for (var record in ndefRecords) {
          if (record is ndef.TextRecord) {
            cardData['text'] = record.text;
          } else if (record is ndef.UriRecord) {
            cardData['uri'] = record.uri;
          }
        }
      }

      // Get card UID
      cardData['uid'] = tag.id;
      
      // Detect card type based on tag properties
      cardData['cardType'] = _detectCardType(tag);
      
      // Try to read additional card data
      if (tag.standard == 'ISO 14443-4 (Type A)') {
        // This is likely a payment card
        cardData['isPaymentCard'] = true;
        
        // For e-Money cards (common in Indonesia)
        if (tag.atqa != null && tag.atqa!.startsWith('0x')) {
          cardData['cardType'] = 'e-Money';
        }
      }

      await FlutterNfcKit.finish();
      
      return cardData;
    } on PlatformException catch (e) {
      await FlutterNfcKit.finish();
      throw Exception('NFC Platform Error: ${e.message}');
    } catch (e) {
      await FlutterNfcKit.finish();
      throw Exception('NFC Error: $e');
    }
  }

  // Detect card type based on NFC tag properties
  static String _detectCardType(NFCTag tag) {
    if (tag.standard == 'ISO 14443-4 (Type A)') {
      // Check for specific card types
      if (tag.atqa != null) {
        String atqa = tag.atqa!;
        if (atqa.contains('4400')) {
          return 'Mandiri e-Money';
        } else if (atqa.contains('0400')) {
          return 'BCA Flazz';
        } else if (atqa.contains('0800')) {
          return 'BNI TapCash';
        }
      }
      return 'e-Money';
    } else if (tag.standard == 'ISO 14443-3 (Type A)') {
      return 'MIFARE Classic';
    } else if (tag.standard == 'ISO 14443-3 (Type B)') {
      return 'ISO 14443 Type B';
    } else if (tag.standard == 'FeliCa') {
      return 'FeliCa';
    } else {
      return 'Unknown NFC Card';
    }
  }

  // Create payment card from NFC scan data
  static Future<PaymentCard> createCardFromNFC(Map<String, dynamic> nfcData) async {
    try {
      String cardNumber = '';
      String cardType = nfcData['cardType'] ?? 'e-Money';
      String cardUID = nfcData['uid'] ?? '';
      
      // Try to extract card number from NFC data
      if (nfcData.containsKey('text')) {
        String text = nfcData['text'];
        // Look for card number pattern (16 digits)
        RegExp cardNumberPattern = RegExp(r'\d{13,19}');
        Match? match = cardNumberPattern.firstMatch(text);
        if (match != null) {
          cardNumber = match.group(0)!;
        }
      }

      // If no card number found, generate a placeholder
      if (cardNumber.isEmpty) {
        cardNumber = _generatePlaceholderCardNumber(cardType);
      }

      // Validate card number
      if (!PaymentCard.isValidCardNumber(cardNumber)) {
        throw Exception('Invalid card number detected');
      }

      // Encrypt card number
      String encryptedCardNumber = PaymentCard.encryptCardNumber(cardNumber, _encryptionKey);
      String lastFourDigits = cardNumber.substring(cardNumber.length - 4);

      return PaymentCard(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        cardType: cardType,
        encryptedCardNumber: encryptedCardNumber,
        lastFourDigits: lastFourDigits,
        cardUID: cardUID,
        isNfcEnabled: true,
        createdAt: DateTime.now(),
      );
    } catch (e) {
      throw Exception('Failed to create card from NFC data: $e');
    }
  }

  // Generate placeholder card number for testing/demo
  static String _generatePlaceholderCardNumber(String cardType) {
    switch (cardType.toLowerCase()) {
      case 'mandiri e-money':
        return '8800111122223333';
      case 'bca flazz':
        return '8800222233334444';
      case 'bni tapcash':
        return '8800333344445555';
      default:
        return '8800444455556666';
    }
  }

  // Save payment card to local storage
  static Future<void> savePaymentCard(PaymentCard card) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> cardsJson = prefs.getStringList(_storageKey) ?? [];
      
      // Remove any existing card with same UID
      cardsJson.removeWhere((cardJson) {
        final existingCard = PaymentCard.fromJson(jsonDecode(cardJson));
        return existingCard.cardUID == card.cardUID;
      });
      
      cardsJson.add(jsonEncode(card.toJson()));
      await prefs.setStringList(_storageKey, cardsJson);
    } catch (e) {
      throw Exception('Failed to save payment card: $e');
    }
  }

  // Get all saved payment cards
  static Future<List<PaymentCard>> getSavedCards() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> cardsJson = prefs.getStringList(_storageKey) ?? [];
      
      return cardsJson.map((cardJson) {
        return PaymentCard.fromJson(jsonDecode(cardJson));
      }).toList();
    } catch (e) {
      throw Exception('Failed to load payment cards: $e');
    }
  }

  // Delete payment card
  static Future<void> deletePaymentCard(String cardId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> cardsJson = prefs.getStringList(_storageKey) ?? [];
      
      cardsJson.removeWhere((cardJson) {
        final card = PaymentCard.fromJson(jsonDecode(cardJson));
        return card.id == cardId;
      });
      
      await prefs.setStringList(_storageKey, cardsJson);
    } catch (e) {
      throw Exception('Failed to delete payment card: $e');
    }
  }

  // Set default payment card
  static Future<void> setDefaultCard(String cardId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> cardsJson = prefs.getStringList(_storageKey) ?? [];
      
      List<PaymentCard> cards = cardsJson.map((cardJson) {
        return PaymentCard.fromJson(jsonDecode(cardJson));
      }).toList();
      
      // Reset all cards to non-default
      for (int i = 0; i < cards.length; i++) {
        cards[i] = cards[i].copyWith(isDefault: false);
      }
      
      // Set the specified card as default
      for (int i = 0; i < cards.length; i++) {
        if (cards[i].id == cardId) {
          cards[i] = cards[i].copyWith(isDefault: true);
          break;
        }
      }
      
      // Save back to storage
      List<String> updatedCardsJson = cards.map((card) {
        return jsonEncode(card.toJson());
      }).toList();
      
      await prefs.setStringList(_storageKey, updatedCardsJson);
    } catch (e) {
      throw Exception('Failed to set default card: $e');
    }
  }

  // Get default payment card
  static Future<PaymentCard?> getDefaultCard() async {
    try {
      final cards = await getSavedCards();
      return cards.firstWhere(
        (card) => card.isDefault,
        orElse: () => cards.isNotEmpty ? cards.first : throw Exception('No cards found'),
      );
    } catch (e) {
      return null;
    }
  }

  // Simulate NFC payment
  static Future<bool> simulateNFCPayment(String parkingId, double amount) async {
    try {
      final defaultCard = await getDefaultCard();
      if (defaultCard == null) {
        throw Exception('No default payment card found');
      }

      // Simulate payment processing
      await Future.delayed(Duration(seconds: 2));
      
      // Update last used timestamp
      defaultCard.copyWith(lastUsed: DateTime.now());
      await savePaymentCard(defaultCard);
      
      return true;
    } catch (e) {
      throw Exception('Payment failed: $e');
    }
  }
}