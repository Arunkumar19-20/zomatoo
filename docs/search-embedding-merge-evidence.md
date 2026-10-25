# Why phrases are not merged by embedding: wording similarity (bge-small)

| pair | cosine | should merge |
|---|---|---|
| birria tacos / birria taco | 0.980 | yes |
| birria tacos / cheesy birria tacos | 0.883 | yes |
| birria tacos / taco birria | 0.971 | yes |
| paneer tikka / tikka paneer | 0.990 | yes |
| margherita pizza / pizza margherita | 0.990 | yes |
| chicken biryani / biryani chicken | 0.980 | yes |
| chocolate lava cake / lava cake chocolate | 0.956 | yes |
| mushroom risotto / risotto with mushrooms | 0.953 | yes |
| french fries / potato chips | 0.727 | yes |
| kathi roll / kebab wrap | 0.623 | yes |
| iced coffee / cold coffee | 0.857 | yes |
| fried chicken sandwich / crispy chicken burger | 0.760 | yes |
| cheese pull pizza / stretchy cheese pizza | 0.789 | yes |
| soda / fizzy drink | 0.814 | yes |
| prawn curry / shrimp curry | 0.773 | yes |
| ice lolly / popsicle | 0.598 | yes |
| birria tacos / fish tacos | 0.708 | no |
| paneer tikka / paneer butter masala | 0.687 | no |
| chicken biryani / chicken burger | 0.691 | no |
| chocolate lava cake / chocolate milkshake | 0.700 | no |
| mushroom risotto / mushroom soup | 0.816 | no |
| cold coffee / hot coffee | 0.798 | no |
| veg burger / chicken burger | 0.797 | no |
| ethiopian injera / ethiopian coffee | 0.744 | no |
| fried chicken sandwich / grilled chicken sandwich | 0.814 | no |
| prawn curry / chicken curry | 0.687 | no |
| french fries / french toast | 0.719 | no |
| iced coffee / iced tea | 0.826 | no |
| cheese pizza / cheese sandwich | 0.818 | no |
| soda / soup | 0.568 | no |

least similar rewording 0.598; most similar different dish 0.826
