class Item {
  final String id;
  final String itemName;
  final double costPrice;
  final double salePrice;
  final double qtyOnHand;
  final String? vendor;
  final String? category;
  final String? image;
  final String? unit;
  final String itemType; // 'motai' or 'length'
  final String? motai;
  final double? motaiDecimal;
  final List<dynamic>? lengthCombinations;
  final List<String>? lengthOptions;
  final bool hasMultipleLengths;
  final Map<String, double>? customerPrices;
  final bool? isBOM;
  final List<dynamic>? components;
  final String? createdAt;
  final String? updatedAt;
  final String? description;

  Item({
    required this.id,
    required this.itemName,
    required this.costPrice,
    this.salePrice = 0.0,
    this.qtyOnHand = 0.0,
    this.vendor,
    this.category,
    this.image,
    this.unit = 'Pcs',
    required this.itemType,
    this.motai,
    this.motaiDecimal,
    this.lengthCombinations,
    this.lengthOptions,
    this.hasMultipleLengths = false,
    this.customerPrices,
    this.isBOM = false,
    this.components,
    this.createdAt,
    this.updatedAt,
    this.description
  });

  // Helper function to safely parse double from dynamic value
  static double _safeParseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    if (value is num) {
      return value.toDouble();
    }
    return 0.0;
  }

  // Add a method to get customer-specific price
  double getCustomerPrice(String customerId) {
    if (customerPrices != null && customerPrices!.containsKey(customerId)) {
      return customerPrices![customerId]!;
    }
    // Fall back to regular sale price if no customer-specific price
    return salePrice > 0 ? salePrice : costPrice;
  }


  factory Item.fromMap(Map<dynamic, dynamic> data, String id) {
    // Parse length options from lengthCombinations
    List<String> lengthOptions = [];
    if (data['lengthCombinations'] != null && data['lengthCombinations'] is List) {
      final lengthsList = data['lengthCombinations'] as List;
      lengthOptions = lengthsList.map((length) {
        if (length is Map) {
          return length['length']?.toString() ?? '';
        } else if (length is String) {
          return length;
        }
        return '';
      }).where((length) => length.isNotEmpty).toList();
    }

    // Parse item type
    String itemType = 'motai'; // Default
    if (data['itemType'] != null) {
      itemType = data['itemType'].toString();
    } else {
      // Determine type from data
      if (data['motai'] != null && data['motai'].toString().isNotEmpty) {
        itemType = 'motai';
      } else if (data['lengthCombinations'] != null && (data['lengthCombinations'] as List).isNotEmpty) {
        itemType = 'motai_length';
      }
    }

    // Parse customer prices
    Map<String, double> customerPrices = {};
    if (data['customerPrices'] != null) {
      final prices = Map<String, dynamic>.from(data['customerPrices']);
      prices.forEach((key, value) {
        if (key != null) {
          customerPrices[key.toString()] = _safeParseDouble(value);
        }
      });
    }

    return Item(
      id: id,
      itemName: data['itemName']?.toString() ?? data['motai']?.toString() ?? '',
      costPrice: _safeParseDouble(data['costPrice'] ?? data['costPrice1kg']),
      salePrice: _safeParseDouble(data['salePrice'] ?? data['salePrice1kg']),
      qtyOnHand: _safeParseDouble(data['qtyOnHand']),
      vendor: data['vendor']?.toString(),
      category: data['category']?.toString(),
      image: data['image']?.toString(),
      unit: data['unit']?.toString() ?? 'Pcs',
      itemType: itemType,
      motai: data['motai']?.toString(),
      motaiDecimal: _safeParseDouble(data['motaiDecimal']),
      lengthCombinations: data['lengthCombinations'] != null ? List<dynamic>.from(data['lengthCombinations']) : null,
      lengthOptions: lengthOptions,
      hasMultipleLengths: (data['hasMultipleLengths'] ?? false) as bool,
      customerPrices: customerPrices.isNotEmpty ? customerPrices : null,
      isBOM: (data['isBOM'] ?? false) as bool,
      components: data['components'],
      createdAt: data['createdAt']?.toString(),
      updatedAt: data['updatedAt']?.toString(),
      description: data['description']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'itemName': itemName,
      'costPrice': costPrice,
      'salePrice': salePrice,
      'qtyOnHand': qtyOnHand,
      'vendor': vendor,
      'category': category,
      'image': image,
      'unit': unit,
      'itemType': itemType,
      'motai': motai,
      'motaiDecimal': motaiDecimal,
      'lengthCombinations': lengthCombinations,
      'lengthOptions': lengthOptions,
      'hasMultipleLengths': hasMultipleLengths,
      'customerPrices': customerPrices,
      'isBOM': isBOM,
      'components': components,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'description': description
    };
  }

  // Method to get length combinations as a list of maps
  List<Map<String, dynamic>>? getLengthCombinations() {
    if (lengthCombinations != null && lengthCombinations!.isNotEmpty) {
      return lengthCombinations!.map((item) {
        if (item is Map) {
          return {
            'length': item['length']?.toString() ?? '',
            'lengthDecimal': item['lengthDecimal']?.toString() ?? '',
            'id': item['id']?.toString(),
          };
        }
        return {'length': item.toString()};
      }).toList();
    }
    return null;
  }

  // Method to check if item has multiple lengths
  bool get hasMultipleLengthsOption =>
      (lengthCombinations != null && lengthCombinations!.isNotEmpty) ||
          (lengthOptions != null && lengthOptions!.isNotEmpty);

  // Method to get available lengths
  List<String> getAvailableLengths() {
    if (lengthOptions != null && lengthOptions!.isNotEmpty) {
      return lengthOptions!;
    } else if (lengthCombinations != null && lengthCombinations!.isNotEmpty) {
      return lengthCombinations!.map((item) {
        if (item is Map) {
          return item['length']?.toString() ?? '';
        }
        return item.toString();
      }).where((length) => length.isNotEmpty).toList();
    }
    return [];
  }
}

class LengthQuantityManager {
  final Map<String, double> _lengthQuantities = {};

  void setQuantity(String length, double quantity) {
    _lengthQuantities[length] = quantity;
  }

  double getQuantity(String length) {
    return _lengthQuantities[length] ?? 0.0;
  }

  void removeLength(String length) {
    _lengthQuantities.remove(length);
  }

  void clearAll() {
    _lengthQuantities.clear();
  }

  bool hasLength(String length) {
    return _lengthQuantities.containsKey(length);
  }

  Map<String, double> getAllQuantities() {
    return Map.from(_lengthQuantities);
  }

  double getTotalQuantity() {
    return _lengthQuantities.values.fold(0.0, (sum, quantity) => sum + quantity);
  }

  List<String> getSelectedLengths() {
    return _lengthQuantities.keys.toList();
  }
}