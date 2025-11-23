import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/payment_card.dart';
import '../../services/nfc_payment_service.dart';
import '../../widgets/custom_text_field.dart';

class ManualCardInputScreen extends StatefulWidget {
  const ManualCardInputScreen({Key? key}) : super(key: key);

  @override
  _ManualCardInputScreenState createState() => _ManualCardInputScreenState();
}

class _ManualCardInputScreenState extends State<ManualCardInputScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cardNumberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  final _cardholderNameController = TextEditingController();
  
  String? _cardType;
  bool _isLoading = false;
  bool _saveCard = true;

  @override
  void initState() {
    super.initState();
    _cardNumberController.addListener(_onCardNumberChanged);
  }

  @override
  void dispose() {
    _cardNumberController.removeListener(_onCardNumberChanged);
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _cardholderNameController.dispose();
    super.dispose();
  }

  void _onCardNumberChanged() {
    final cardNumber = _cardNumberController.text.replaceAll(RegExp(r'\s+'), '');
    if (cardNumber.length >= 4) {
      setState(() {
        _cardType = PaymentCard.detectCardType(cardNumber);
      });
    } else {
      setState(() {
        _cardType = null;
      });
    }
  }

  String? _validateCardNumber(String? value) {
    if (value == null || value.isEmpty) {
      return 'Nomor kartu wajib diisi';
    }
    final cardNumber = value.replaceAll(RegExp(r'\s+'), '');
    if (cardNumber.length < 13 || cardNumber.length > 19) {
      return 'Nomor kartu tidak valid';
    }
    if (!PaymentCard.isValidCardNumber(cardNumber)) {
      return 'Nomor kartu tidak valid';
    }
    return null;
  }

  String? _validateExpiry(String? value) {
    if (value == null || value.isEmpty) {
      return 'Tanggal kadaluarsa wajib diisi';
    }
    if (!RegExp(r'^(0[1-9]|1[0-2])\/([0-9]{2})$').hasMatch(value)) {
      return 'Format tanggal salah (MM/YY)';
    }
    
    final parts = value.split('/');
    final month = int.parse(parts[0]);
    final year = int.parse(parts[1]) + 2000;
    final now = DateTime.now();
    final currentYear = now.year;
    final currentMonth = now.month;
    
    if (year < currentYear || (year == currentYear && month < currentMonth)) {
      return 'Kartu sudah kadaluarsa';
    }
    return null;
  }

  String? _validateCVV(String? value) {
    if (value == null || value.isEmpty) {
      return 'CVV wajib diisi';
    }
    if (value.length < 3 || value.length > 4) {
      return 'CVV tidak valid';
    }
    if (!RegExp(r'^[0-9]+$').hasMatch(value)) {
      return 'CVV hanya boleh angka';
    }
    return null;
  }

  Future<void> _savePaymentCard() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final cardNumber = _cardNumberController.text.replaceAll(RegExp(r'\s+'), '');
      final expiry = _expiryController.text;
      final cvv = _cvvController.text;
      final cardholderName = _cardholderNameController.text;
      
      final expiryParts = expiry.split('/');
      final expiryMonth = int.parse(expiryParts[0]);
      final expiryYear = int.parse(expiryParts[1]) + 2000;

      final paymentCard = PaymentCard(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        cardType: _cardType ?? 'Unknown',
        encryptedCardNumber: PaymentCard.encryptCardNumber(cardNumber, 'parking_app_nfc_encryption_key_2024'),
        lastFourDigits: cardNumber.substring(cardNumber.length - 4),
        expiryDate: '${expiryMonth.toString().padLeft(2, '0')}/${expiryYear.toString().substring(2)}',
        cardHolderName: cardholderName,
        isNfcEnabled: false,
        isDefault: false,
        createdAt: DateTime.now(),
      );

      final nfcService = Provider.of<NFCPaymentService>(context, listen: false);
      await NFCPaymentService.savePaymentCard(paymentCard);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kartu berhasil disimpan'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan kartu: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildCardTypeIcon() {
    if (_cardType == null) return const SizedBox.shrink();
    
    String assetPath;
    switch (_cardType) {
      case 'Visa':
        assetPath = 'assets/icons/visa.png';
        break;
      case 'MasterCard':
        assetPath = 'assets/icons/mastercard.png';
        break;
      case 'Mandiri e-Money':
        assetPath = 'assets/icons/mandiri_emoney.png';
        break;
      case 'BCA Flazz':
        assetPath = 'assets/icons/bca_flazz.png';
        break;
      case 'BNI TapCash':
        assetPath = 'assets/icons/bni_tapcash.png';
        break;
      default:
        return Text(
          _cardType!,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        );
    }
    
    return Image.asset(
      assetPath,
      height: 24,
      width: 40,
      errorBuilder: (context, error, stackTrace) {
        return Text(
          _cardType!,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Tambah Kartu Manual'),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        titleTextStyle: const TextStyle(
          color: Colors.black87,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Card Preview
              Container(
                height: 200,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: _cardType != null && _cardType!.contains('e-Money') || 
                            _cardType != null && _cardType!.contains('Flazz') || 
                            _cardType != null && _cardType!.contains('TapCash')
                        ? [Colors.blue[700]!, Colors.blue[500]!]
                        : [Colors.purple[700]!, Colors.purple[500]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Kartu Debit/Kredit',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          _buildCardTypeIcon(),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _cardNumberController.text.isNotEmpty
                                ? _cardNumberController.text.replaceAllMapped(
                                    RegExp(r'.{1,4}'), (match) => '${match.group(0)} ')
                                : '**** **** **** ****',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Cardholder Name',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 10,
                                    ),
                                  ),
                                  Text(
                                    _cardholderNameController.text.isNotEmpty
                                        ? _cardholderNameController.text
                                        : 'NAMA PEMILIK',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Expires',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 10,
                                    ),
                                  ),
                                  Text(
                                    _expiryController.text.isNotEmpty
                                        ? _expiryController.text
                                        : 'MM/YY',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Card Number Field
              CustomTextField(
                controller: _cardNumberController,
                label: 'Nomor Kartu',
                hint: '1234 5678 9012 3456',
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(19),
                  _CardNumberInputFormatter(),
                ],
                validator: _validateCardNumber,
                prefixIcon: const Icon(Icons.credit_card),
                suffixIcon: _cardType != null ? _buildCardTypeIcon() : null,
              ),
              const SizedBox(height: 16),

              // Cardholder Name Field
              CustomTextField(
                controller: _cardholderNameController,
                label: 'Nama Pemilik Kartu',
                hint: 'JOHN DOE',
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Nama pemilik wajib diisi';
                  }
                  return null;
                },
                prefixIcon: const Icon(Icons.person),
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 16),

              // Expiry and CVV Row
              Row(
                children: [
                  Expanded(
                    child: CustomTextField(
                      controller: _expiryController,
                      label: 'Kadaluarsa',
                      hint: 'MM/YY',
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                        _ExpiryInputFormatter(),
                      ],
                      validator: _validateExpiry,
                      prefixIcon: const Icon(Icons.calendar_today),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: CustomTextField(
                      controller: _cvvController,
                      label: 'CVV',
                      hint: '123',
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                      ],
                      validator: _validateCVV,
                      prefixIcon: const Icon(Icons.lock),
                      obscureText: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Save Card Checkbox
              GestureDetector(
                onTap: () {
                  setState(() {
                    _saveCard = !_saveCard;
                  });
                },
                child: Row(
                  children: [
                    Checkbox(
                      value: _saveCard,
                      onChanged: (value) {
                        setState(() {
                          _saveCard = value ?? true;
                        });
                      },
                      activeColor: Colors.purple,
                    ),
                    const Expanded(
                      child: Text(
                        'Simpan kartu untuk pembayaran cepat',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Security Info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.security, color: Colors.blue[600], size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Informasi kartu Anda dienkripsi dan disimpan dengan aman',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue[800],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _savePaymentCard,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Simpan Kartu',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardNumberInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll(RegExp(r'\s+'), '');
    final formattedText = text.replaceAllMapped(
      RegExp(r'.{1,4}'),
      (match) => '${match.group(0)} ',
    ).trim();
    
    return newValue.copyWith(
      text: formattedText,
      selection: TextSelection.collapsed(offset: formattedText.length),
    );
  }
}

class _ExpiryInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    
    if (text.length <= 2) {
      return newValue.copyWith(text: text);
    } else if (text.length <= 4) {
      final formatted = '${text.substring(0, 2)}/${text.substring(2)}';
      return newValue.copyWith(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
    
    return oldValue;
  }
}