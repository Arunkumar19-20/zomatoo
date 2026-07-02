// lib/models/models.dart
//
// Dart models mirroring the backend Java entities in
// com.example.zomato.entity.*. Field names/types match the entities found
// in the repo (Silviya-158/zomato-).

class Restaurant {
  final int? id;
  final String name;
  final String address;
  final int? locationId;
  final int? ownerId;
  final double? rating;
  final bool? isOpen;
  final String? openingHours;
  final int deliveryTime;

  Restaurant({
    this.id,
    required this.name,
    required this.address,
    this.locationId,
    this.ownerId,
    this.rating,
    this.isOpen,
    this.openingHours,
    this.deliveryTime = 0,
  });

  factory Restaurant.fromJson(Map<String, dynamic> j) => Restaurant(
        id: j['id'],
        name: j['name'] ?? '',
        address: j['address'] ?? '',
        locationId: j['locationId'],
        ownerId: j['ownerId'],
        rating: (j['rating'] as num?)?.toDouble(),
        isOpen: j['isOpen'],
        openingHours: j['openingHours'],
        deliveryTime: j['deliveryTime'] ?? 0,
      );

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'name': name,
        'address': address,
        'locationId': locationId,
        'ownerId': ownerId,
        'rating': rating,
        'isOpen': isOpen,
        'openingHours': openingHours,
        'deliveryTime': deliveryTime,
      };
}

class MenuCategory {
  final int? id;
  final String name;
  final int? displayOrder;

  MenuCategory({this.id, required this.name, this.displayOrder});

  factory MenuCategory.fromJson(Map<String, dynamic> j) => MenuCategory(
        id: j['id'],
        name: j['name'] ?? '',
        displayOrder: j['displayOrder'],
      );

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'name': name,
        'displayOrder': displayOrder,
      };
}

class MenuItem {
  final int? id;
  final String name;
  final String? description;
  final double price;
  final bool? isVeg;
  final bool? isAvailable;
  final String? imageUrl;

  MenuItem({
    this.id,
    required this.name,
    this.description,
    required this.price,
    this.isVeg,
    this.isAvailable,
    this.imageUrl,
  });

  factory MenuItem.fromJson(Map<String, dynamic> j) => MenuItem(
        id: j['id'],
        name: j['name'] ?? '',
        description: j['description'],
        price: (j['price'] as num?)?.toDouble() ?? 0,
        isVeg: j['isVeg'],
        isAvailable: j['isAvailable'],
        imageUrl: j['imageUrl'],
      );

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'name': name,
        'description': description,
        'price': price,
        'isVeg': isVeg,
        'isAvailable': isAvailable,
        'imageUrl': imageUrl,
      };
}

class CartModel {
  final int? id;
  final int? customerId;
  final int? restaurantId;
  final double? totalAmount;

  CartModel({this.id, this.customerId, this.restaurantId, this.totalAmount});

  factory CartModel.fromJson(Map<String, dynamic> j) => CartModel(
        id: j['id'],
        customerId: j['customerId'],
        restaurantId: j['restaurantId'],
        totalAmount: (j['totalAmount'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'customerId': customerId,
        'restaurantId': restaurantId,
        'totalAmount': totalAmount,
      };
}

class CartItemModel {
  final int? id;
  final int cartId;
  final int itemId;
  final double price;
  final int quantity;

  CartItemModel({
    this.id,
    required this.cartId,
    required this.itemId,
    required this.price,
    required this.quantity,
  });

  factory CartItemModel.fromJson(Map<String, dynamic> j) => CartItemModel(
        id: j['id'],
        cartId: j['cartId'] ?? 0,
        itemId: j['itemId'] ?? 0,
        price: (j['price'] as num?)?.toDouble() ?? 0,
        quantity: j['quantity'] ?? 0,
      );

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'cartId': cartId,
        'itemId': itemId,
        'price': price,
        'quantity': quantity,
      };
}

class OrderModel {
  final int? orderId;
  final double totalAmount;

  OrderModel({this.orderId, required this.totalAmount});

  factory OrderModel.fromJson(Map<String, dynamic> j) => OrderModel(
        orderId: j['orderId'],
        totalAmount: (j['totalAmount'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        if (orderId != null) 'orderId': orderId,
        'totalAmount': totalAmount,
      };
}

class Customer {
  final int? customerId;
  final String? name;
  final String? email;
  final String? address;
  final int? userId;

  Customer({this.customerId, this.name, this.email, this.address, this.userId});

  factory Customer.fromJson(Map<String, dynamic> j) => Customer(
        customerId: j['customerId'],
        name: j['name'],
        email: j['email'],
        address: j['address'],
        userId: j['userId'],
      );

  Map<String, dynamic> toJson() => {
        if (customerId != null) 'customerId': customerId,
        'name': name,
        'email': email,
        'address': address,
        'userId': userId,
      };
}

class AppUser {
  final int? userId;
  final String? name;
  final String? email;
  final String? role; // CUSTOMER, OWNER, DELIVERY

  AppUser({this.userId, this.name, this.email, this.role});

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        userId: j['userId'],
        name: j['name'],
        email: j['email'],
        role: j['role'],
      );
}

class Coupon {
  final int? couponId;
  final String code;
  final double discount;
  final String discountType;
  final DateTime? validFrom;
  final DateTime? validUntil;

  Coupon({
    this.couponId,
    required this.code,
    required this.discount,
    required this.discountType,
    this.validFrom,
    this.validUntil,
  });

  factory Coupon.fromJson(Map<String, dynamic> j) => Coupon(
        couponId: j['couponId'],
        code: j['code'] ?? '',
        discount: (j['discount'] as num?)?.toDouble() ?? 0,
        discountType: j['discountType'] ?? '',
        validFrom: j['validFrom'] != null ? DateTime.tryParse(j['validFrom']) : null,
        validUntil: j['validUntil'] != null ? DateTime.tryParse(j['validUntil']) : null,
      );

  Map<String, dynamic> toJson() => {
        if (couponId != null) 'couponId': couponId,
        'code': code,
        'discount': discount,
        'discountType': discountType,
        'validFrom': validFrom?.toIso8601String().split('T').first,
        'validUntil': validUntil?.toIso8601String().split('T').first,
      };
}

class LocationModel {
  final int? id;
  final double? latitude;
  final double? longitude;
  final String? address;
  final String? city;
  final String? state;
  final String? zipCode;

  LocationModel({
    this.id,
    this.latitude,
    this.longitude,
    this.address,
    this.city,
    this.state,
    this.zipCode,
  });

  factory LocationModel.fromJson(Map<String, dynamic> j) => LocationModel(
        id: j['id'],
        latitude: (j['latitude'] as num?)?.toDouble(),
        longitude: (j['longitude'] as num?)?.toDouble(),
        address: j['address'],
        city: j['city'],
        state: j['state'],
        zipCode: j['zipCode'],
      );

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'latitude': latitude,
        'longitude': longitude,
        'address': address,
        'city': city,
        'state': state,
        'zipCode': zipCode,
      };
}

class DeliveryPartner {
  final int? id;
  final String vehicleType;
  final String vehicleNumber;
  final bool isAvailable;
  final double rating;

  DeliveryPartner({
    this.id,
    required this.vehicleType,
    required this.vehicleNumber,
    this.isAvailable = true,
    this.rating = 0,
  });

  factory DeliveryPartner.fromJson(Map<String, dynamic> j) => DeliveryPartner(
        id: j['id'],
        vehicleType: j['vehicleType'] ?? '',
        vehicleNumber: j['vehicleNumber'] ?? '',
        isAvailable: j['isAvailable'] ?? true,
        rating: (j['rating'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'vehicleType': vehicleType,
        'vehicleNumber': vehicleNumber,
        'isAvailable': isAvailable,
        'rating': rating,
      };
}

class DeliveryModel {
  final int? id;
  final String? status;
  final String? trackingUrl;

  DeliveryModel({this.id, this.status, this.trackingUrl});

  factory DeliveryModel.fromJson(Map<String, dynamic> j) => DeliveryModel(
        id: j['id'],
        status: j['status'],
        trackingUrl: j['trackingUrl'],
      );
}

class DeliveryRating {
  final int? id;
  final int rating;
  final String? feedback;
  final int? deliveryPartnerId;
  final int? orderId;

  DeliveryRating({
    this.id,
    required this.rating,
    this.feedback,
    this.deliveryPartnerId,
    this.orderId,
  });

  factory DeliveryRating.fromJson(Map<String, dynamic> j) => DeliveryRating(
        id: j['id'],
        rating: j['rating'] ?? 0,
        feedback: j['feedback'],
        deliveryPartnerId: j['deliveryPartnerId'],
        orderId: j['orderId'],
      );

  Map<String, dynamic> toJson() => {
        'rating': rating,
        'feedback': feedback,
        'deliveryPartnerId': deliveryPartnerId,
        'orderId': orderId,
      };
}

class NotificationModel {
  final int? id;
  final String message;
  final String? type;
  final bool isRead;

  NotificationModel({this.id, required this.message, this.type, this.isRead = false});

  factory NotificationModel.fromJson(Map<String, dynamic> j) => NotificationModel(
        id: j['id'],
        message: j['message'] ?? '',
        type: j['type'],
        isRead: j['isRead'] ?? false,
      );

  Map<String, dynamic> toJson() => {
        'message': message,
        'type': type,
        'isRead': isRead,
      };
}
