import 'package:flutter/material.dart';
import '../models/food_item.dart';
import '../theme/app_theme.dart';
import 'scale_tap.dart';

void showReviewsDialog(BuildContext context, Restaurant restaurant) {
  final List<Map<String, dynamic>> mockReviews = [
    {
      "name": "Rahul Sharma",
      "rating": 5.0,
      "comment": "Absolutely love the taste! Authentically flavored, portion sizes are great. Will definitely order again!",
      "time": "Today",
    },
    {
      "name": "Priya Patel",
      "rating": 4.0,
      "comment": "Delicious food. Packaging was excellent. Arrived hot and fresh.",
      "time": "Yesterday",
    },
    {
      "name": "Amit Kumar",
      "rating": 4.5,
      "comment": "Nice texture and perfectly spiced. Highly recommended for family dinners.",
      "time": "3 days ago",
    },
  ];

  showDialog(
    context: context,
    builder: (context) {
      return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 8,
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "User Reviews",
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          restaurant.name,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.star_rounded,
                          color: Colors.amber.shade700,
                          size: 18,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          restaurant.rating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, color: Color(0xFFEAEAEA)),
              const SizedBox(height: 16),
              
              // Reviews list
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: mockReviews.length,
                  separatorBuilder: (context, index) => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12.0),
                    child: Divider(height: 1, color: Color(0xFFEAEAEA)),
                  ),
                  itemBuilder: (context, index) {
                    final review = mockReviews[index];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              review["name"],
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppTheme.textDark,
                              ),
                            ),
                            Text(
                              review["time"],
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 11,
                                color: Colors.grey.shade400,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: List.generate(5, (starIndex) {
                            final ratingValue = review["rating"];
                            if (starIndex < ratingValue.floor()) {
                              return Icon(Icons.star_rounded, color: Colors.amber.shade700, size: 14);
                            } else if (starIndex < ratingValue && ratingValue % 1 != 0) {
                              return Icon(Icons.star_half_rounded, color: Colors.amber.shade700, size: 14);
                            } else {
                              return Icon(Icons.star_border_rounded, color: Colors.grey.shade300, size: 14);
                            }
                          }),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          review["comment"],
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13,
                            color: Colors.grey.shade700,
                            height: 1.4,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              
              // Close Button
              SizedBox(
                width: double.infinity,
                child: ScaleTap(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: const Text(
                      "Close",
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
