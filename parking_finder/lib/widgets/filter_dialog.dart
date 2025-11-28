import 'package:flutter/material.dart';
import '../../constants/app_colors_new.dart';
import 'package:provider/provider.dart';
import '../../controllers/map_controller.dart';

class FilterDialog extends StatefulWidget {
  const FilterDialog({super.key});

  @override
  State<FilterDialog> createState() => _FilterDialogState();
}

class _FilterDialogState extends State<FilterDialog> {
  String _sortBy = 'distance';
  RangeValues _priceRange = const RangeValues(0, 50000);
  bool _openNow = true;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColorsNew.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Text(
        'Filter Pencarian',
        style: TextStyle(color: AppColorsNew.textPrimary),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSortBy(),
            const SizedBox(height: 24),
            _buildPriceRange(),
            const SizedBox(height: 24),
            _buildOpenNow(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Batal', style: TextStyle(color: AppColorsNew.textSecondary)),
        ),
        ElevatedButton(
          onPressed: () {
            final controller = context.read<MapController>();
            controller.applyPriceFilter(
              _priceRange.start.toInt(),
              _priceRange.end.toInt(),
            );
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColorsNew.accent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('Terapkan', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  Widget _buildSortBy() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Urutkan Berdasarkan',
          style: TextStyle(
            color: AppColorsNew.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: RadioListTile<String>(
                title: Text('Jarak', style: TextStyle(color: AppColorsNew.textSecondary)),
                value: 'distance',
                groupValue: _sortBy,
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _sortBy = value);
                  }
                },
                activeColor: AppColorsNew.accent,
              ),
            ),
            Expanded(
              child: RadioListTile<String>(
                title: Text('Harga', style: TextStyle(color: AppColorsNew.textSecondary)),
                value: 'price',
                groupValue: _sortBy,
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _sortBy = value);
                  }
                },
                activeColor: AppColorsNew.accent,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPriceRange() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Rentang Harga',
          style: TextStyle(
            color: AppColorsNew.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        RangeSlider(
          values: _priceRange,
          min: 0,
          max: 50000,
          divisions: 10,
          labels: RangeLabels(
            'Rp${(_priceRange.start / 1000).round()}k',
            'Rp${(_priceRange.end / 1000).round()}k',
          ),
          onChanged: (values) {
            setState(() => _priceRange = values);
          },
          activeColor: AppColorsNew.accent,
          inactiveColor: AppColorsNew.accent.withOpacity(0.3),
        ),
      ],
    );
  }

  Widget _buildOpenNow() {
    return SwitchListTile(
      title: Text(
        'Buka Sekarang',
        style: TextStyle(
          color: AppColorsNew.textPrimary,
          fontWeight: FontWeight.bold,
        ),
      ),
      value: _openNow,
      onChanged: (value) {
        setState(() => _openNow = value);
      },
      activeColor: AppColorsNew.accent,
    );
  }
}