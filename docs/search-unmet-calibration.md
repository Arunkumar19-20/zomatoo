# Unmet-demand calibration

threshold under test: 0.62

| group | query | relevant | bm25 | terms | unknown | full | best sim | verdict |
|---|---|---|---|---|---|---|---|---|
| in-catalog | pizza | 12 | 5 | 1 | 0 | 5 | 0.732 | served |
| in-catalog | biryani | 8 | 2 | 1 | 0 | 2 | 0.741 | served |
| in-catalog | ramen | 9 | 4 | 1 | 0 | 4 | 0.758 | served |
| in-catalog | paneer | 2 | 2 | 1 | 0 | 2 | 0.740 | served |
| in-catalog | tiramisu | 1 | 1 | 1 | 0 | 1 | 0.766 | served |
| in-catalog | wings | 3 | 3 | 1 | 0 | 3 | 0.646 | served |
| in-catalog | pad thai | 16 | 16 | 2 | 0 | 1 | 0.766 | served |
| in-catalog | dumplings | 5 | 2 | 1 | 0 | 2 | 0.724 | served |
| in-catalog | brownie | 3 | 3 | 1 | 0 | 3 | 0.761 | served |
| in-catalog | burger | 17 | 16 | 1 | 0 | 16 | 0.736 | served |
| in-catalog | noodle soup | 13 | 10 | 2 | 0 | 0 | 0.672 | UNMET no-dish-has-all-the-words |
| in-catalog | grilled chicken | 31 | 31 | 2 | 0 | 5 | 0.767 | served |
| in-catalog | curry | 9 | 9 | 1 | 0 | 9 | 0.680 | served |
| in-catalog | ice cream | 57 | 57 | 2 | 0 | 6 | 0.726 | served |
| in-catalog | tacos | 11 | 2 | 1 | 0 | 2 | 0.765 | served |
| out-of-catalog | korean italian fusion | 19 | 19 | 2 | 1 | 0 | 0.552 | UNMET word-on-no-menu |
| out-of-catalog | kimchi carbonara | 1 | 1 | 2 | 1 | 0 | 0.575 | UNMET word-on-no-menu |
| out-of-catalog | bulgogi pizza | 5 | 5 | 2 | 1 | 0 | 0.657 | UNMET word-on-no-menu |
| out-of-catalog | ethiopian injera | 0 | 0 | 2 | 2 | 0 | 0.526 | UNMET nothing-relevant |
| out-of-catalog | vegan sushi burrito | 6 | 1 | 2 | 0 | 0 | 0.672 | UNMET no-dish-has-all-the-words |
| out-of-catalog | gluten free ramen | 6 | 4 | 3 | 2 | 0 | 0.701 | UNMET word-on-no-menu |
| out-of-catalog | peruvian ceviche | 1 | 1 | 2 | 1 | 0 | 0.674 | UNMET word-on-no-menu |
| out-of-catalog | moroccan tagine | 0 | 0 | 2 | 2 | 0 | 0.597 | UNMET nothing-relevant |
| out-of-catalog | birria tacos | 4 | 2 | 2 | 0 | 1 | 0.790 | served |
| out-of-catalog | korean corn dogs | 4 | 4 | 3 | 2 | 0 | 0.608 | UNMET word-on-no-menu |
| out-of-catalog | dubai chocolate | 8 | 8 | 2 | 1 | 0 | 0.597 | UNMET word-on-no-menu |
| out-of-catalog | japanese souffle pancakes | 17 | 16 | 3 | 1 | 0 | 0.768 | UNMET word-on-no-menu |
| out-of-catalog | poke bowl | 17 | 17 | 2 | 0 | 1 | 0.678 | served |
| out-of-catalog | turkish kebab platter | 5 | 2 | 3 | 2 | 0 | 0.634 | UNMET word-on-no-menu |
| out-of-catalog | jollof rice | 18 | 18 | 2 | 1 | 0 | 0.527 | UNMET word-on-no-menu |
| eval-flavor | something sweet but also spicy | 81 | 60 | 3 | 0 | 1 | 0.665 | served |
| eval-flavor | sweet and spicy | 77 | 60 | 2 | 0 | 8 | 0.669 | served |
| eval-flavor | I want something creamy and comforting | 72 | 60 | 2 | 0 | 16 | 0.629 | served |
| eval-flavor | crunchy but tangy | 60 | 60 | 3 | 0 | 1 | 0.635 | served |
| eval-flavor | smoky and spicy | 44 | 44 | 2 | 0 | 5 | 0.648 | served |
| eval-flavor | light and fresh | 42 | 42 | 2 | 0 | 29 | 0.612 | served |
| eval-flavor | sweet but not too heavy | 82 | 60 | 5 | 1 | 0 | 0.562 | served |
| eval-flavor | crispy and savory snack | 78 | 60 | 3 | 0 | 4 | 0.691 | served |
| eval-flavor | spicy and tangy | 52 | 51 | 2 | 0 | 10 | 0.665 | served |
| eval-flavor | cheesy and crunchy | 73 | 60 | 2 | 0 | 8 | 0.585 | served |
| eval-flavor | fresh and tangy | 53 | 52 | 2 | 0 | 14 | 0.689 | served |
| eval-flavor | smoky sweet bbq | 62 | 60 | 3 | 0 | 3 | 0.716 | served |
| eval-flavor | creamy and a little spicy | 79 | 60 | 2 | 0 | 9 | 0.662 | served |
| eval-flavor | rich and creamy | 63 | 60 | 2 | 0 | 12 | 0.622 | served |
| eval-flavor | sweet and creamy | 80 | 60 | 2 | 0 | 19 | 0.646 | served |
| eval-flavor | something spicy | 46 | 36 | 1 | 0 | 36 | 0.695 | served |
| eval-flavor | a sweet treat | 52 | 52 | 2 | 0 | 48 | 0.633 | served |
| eval-flavor | crunchy | 30 | 30 | 1 | 0 | 30 | 0.623 | served |
| eval-flavor | something creamy | 52 | 51 | 1 | 0 | 51 | 0.650 | served |
| eval-flavor | tangy and zesty | 51 | 51 | 2 | 0 | 24 | 0.613 | served |
| eval-flavor | smoky grilled | 17 | 17 | 2 | 0 | 13 | 0.708 | served |
| eval-flavor | light healthy meal | 41 | 34 | 2 | 0 | 28 | 0.700 | served |
| eval-flavor | rich indulgent | 60 | 60 | 2 | 0 | 24 | 0.548 | served |
| eval-flavor | comfort food | 42 | 42 | 1 | 0 | 42 | 0.515 | served |
| eval-flavor | something refreshing | 24 | 24 | 1 | 0 | 24 | 0.580 | served |
| eval-flavor | spicy vegetarian | 22 | 17 | 1 | 0 | 17 | 0.695 | served |
| eval-flavor | vegetarian creamy comfort | 52 | 52 | 2 | 0 | 10 | 0.617 | served |
| eval-flavor | cold sweet dessert | 60 | 59 | 3 | 0 | 2 | 0.669 | served |
| eval-flavor | cold refreshing drink | 30 | 30 | 3 | 0 | 1 | 0.702 | served |
| eval-flavor | hot comforting soup | 67 | 60 | 3 | 0 | 1 | 0.694 | served |
| eval-flavor | dessert under 150 | 12 | 11 | 1 | 0 | 11 | 0.680 | served |
| eval-flavor | spicy under 300 | 23 | 17 | 1 | 0 | 17 | 0.695 | served |
| eval-flavor | mild creamy curry | 56 | 54 | 3 | 0 | 1 | 0.698 | served |
| eval-flavor | something warm and cozy for a rainy day | 47 | 47 | 4 | 0 | 2 | 0.561 | served |
| eval-flavor | late night snack | 23 | 20 | 3 | 0 | 0 | 0.638 | UNMET no-dish-has-all-the-words |
| eval-flavor | i want to eat something healthy | 31 | 31 | 1 | 0 | 31 | 0.650 | served |
| eval-flavor | a drink to cool down | 26 | 26 | 3 | 1 | 0 | 0.614 | served |
| eval-flavor | heavy indulgent meal | 60 | 60 | 2 | 0 | 32 | 0.619 | served |
| eval-flavor | fiery hot | 41 | 41 | 2 | 0 | 36 | 0.585 | served |
| eval-flavor | burning hot wings | 41 | 41 | 3 | 0 | 3 | 0.594 | served |
| eval-flavor | something to share with friends | 37 | 37 | 2 | 0 | 0 | 0.518 | UNMET no-dish-has-all-the-words |
| eval-flavor | street food chaat | 5 | 5 | 2 | 0 | 1 | 0.697 | served |
| eval-flavor | dessert | 51 | 48 | 1 | 0 | 48 | 0.747 | served |
| eval-flavor | something sugary to end the meal | 50 | 50 | 2 | 1 | 0 | 0.598 | served |
| eval-flavor | margherita pizza | 5 | 5 | 2 | 0 | 2 | 0.826 | served |
| eval-flavor | butter chicken | 25 | 25 | 2 | 0 | 2 | 0.742 | served |
| eval-flavor | ramen | 9 | 4 | 1 | 0 | 4 | 0.758 | served |
| eval-flavor | tacos | 11 | 2 | 1 | 0 | 2 | 0.765 | served |
| eval-flavor | biryani | 8 | 2 | 1 | 0 | 2 | 0.741 | served |
| eval-flavor | cheesecake | 9 | 1 | 1 | 0 | 1 | 0.797 | served |
| eval-flavor | tom yum | 2 | 2 | 2 | 0 | 1 | 0.646 | served |
| eval-flavor | pad thai | 16 | 16 | 2 | 0 | 1 | 0.766 | served |
| eval-flavor | margarita pizza | 5 | 5 | 2 | 0 | 2 | 0.647 | served |
| eval-flavor | brownies | 4 | 3 | 1 | 0 | 3 | 0.746 | served |

in-catalog best-sim min 0.646; out-of-catalog best-sim max 0.790
in-catalog wrongly unmet: 1/15; out-of-catalog wrongly served: 2/15
