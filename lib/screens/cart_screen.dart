import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/cart_state.dart';
import '../theme/app_theme.dart';
import '../widgets/primary_button.dart';
import '../widgets/citrus_header.dart';
import '../widgets/fade_in_wrapper.dart';
import '../widgets/shimmer_placeholder.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartState>();

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      body: Column(
        children: [
          // Citrus header at top with title
          const CitrusHeader(
            height: 150,
            title: "Your Cart",
            showBackButton: true,
          ),
          
          // Overlapping card body
          Expanded(
            child: Transform.translate(
              offset: const Offset(0, -16),
              child: Container(
                decoration: const BoxDecoration(
                  color: AppTheme.scaffoldBackground,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: cart.items.isEmpty 
                    ? _buildEmptyCart(context) 
                    : _buildCartContent(context, cart),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 1,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppTheme.primaryColor,
        unselectedItemColor: Colors.grey.shade400,
        backgroundColor: Colors.white,
        elevation: 10,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontSize: 12),
        onTap: (index) {
          if (index == 0) {
            Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
          } else if (index == 2) {
            _showProfileDialog(context);
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home_rounded),
            label: "Home",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart_outlined),
            activeIcon: Icon(Icons.shopping_cart_rounded),
            label: "Cart",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline_rounded),
            activeIcon: Icon(Icons.person_rounded),
            label: "Profile",
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCart(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.shopping_cart_outlined,
                size: 48,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "Your Cart is Empty",
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              "Add items from your favorite restaurants to satisfy your desires!",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade500,
                  ),
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              text: "Browse Food",
              width: 200,
              onPressed: () {
                Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartContent(BuildContext context, CartState cart) {
    return Column(
      children: [
        // Cart list items
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            itemCount: cart.items.length,
            itemBuilder: (context, index) {
              final item = cart.items[index];
              return FadeInWrapper(
                index: index,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                    border: Border.all(color: Colors.grey.shade100),
                  ),
                  child: Row(
                    children: [
                      // Item thumbnail
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          item.foodItem.imageUrl,
                          width: 76,
                          height: 76,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return const ShimmerPlaceholder(
                              width: 76,
                              height: 76,
                              borderRadius: 12,
                            );
                          },
                          errorBuilder: (context, error, stackTrace) => Container(
                            width: 76,
                            height: 76,
                            color: Colors.grey.shade100,
                            child: const Icon(Icons.broken_image, color: Colors.grey),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Title and price
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.foodItem.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: AppTheme.textDark,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.foodItem.description,
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 11,
                                height: 1.4,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "₹${item.totalPrice.toStringAsFixed(2)}",
                              style: const TextStyle(
                                color: AppTheme.textDark,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Stepper
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove, color: AppTheme.primaryColor, size: 16),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              onPressed: () {
                                cart.removeItem(item.foodItem);
                              },
                            ),
                            Text(
                              "${item.quantity}",
                              style: const TextStyle(
                                color: AppTheme.textDark,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add, color: AppTheme.primaryColor, size: 16),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              onPressed: () {
                                if (cart.activeRestaurant != null) {
                                  cart.addItem(item.foodItem, cart.activeRestaurant!);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // Summary details card pinned at bottom
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, -4),
              ),
            ],
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSummaryRow(context, "Subtotal", "₹${cart.subtotal.toStringAsFixed(2)}"),
              _buildSummaryRow(context, "Delivery Fee", "₹${cart.deliveryFee.toStringAsFixed(2)}"),
              _buildSummaryRow(context, "Service Fee", "₹${cart.serviceFee.toStringAsFixed(2)}"),
              const SizedBox(height: 8),
              const Divider(color: AppTheme.dividerColor),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Total",
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textDark,
                        ),
                  ),
                  Text(
                    "₹${cart.total.toStringAsFixed(2)}",
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Proceed to Checkout
              PrimaryButton(
                text: "Proceed to Checkout",
                onPressed: () {
                  Navigator.of(context).pushNamed('/checkout');
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(BuildContext context, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.w600),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textDark),
          ),
        ],
      ),
    );
  }

  void _showProfileDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Profile"),
        content: const Text("Alex Mercer\nalex.mercer@gmail.com"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }
}
