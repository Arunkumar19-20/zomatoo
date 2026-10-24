package com.example.zomato.search;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;

/**
 * The fixed flavor vocabulary owners pick from. A closed list keeps the data clean: nobody can invent
 * a tag, and every tag has query-side synonyms, dish-side keyword cues and prototype sentences.
 */
public enum Flavor {

    SWEET("Sweet",
            "sweet sugary sugar dessert candy honey syrupy sweets treat treats indulgent-sweet jaggery",
            "sugar:0.55 honey:0.8 syrup:0.7 caramel:0.8 chocolate:0.75 dessert:0.8 cake:0.75 brownie:0.8 ice cream:0.8 halwa:0.85 "
                    + "jalebi:0.9 kheer:0.85 gulab:0.9 mango:0.4 maple:0.8 jam:0.6 nutella:0.85 cookie:0.8 donut:0.8 pie:0.4 "
                    + "jaggery:0.85 condensed milk:0.7 fudge:0.8 custard:0.6 sundae:0.8 waffle:0.5 pancake:0.5 candied:0.8 glazed:0.6 "
                    + "kaju:0.7 laddu:0.85 rasgulla:0.9 barfi:0.85 lassi:0.4 milkshake:0.6 tiramisu:0.8 cheesecake:0.8 gelato:0.8",
            "a sweet dessert with sugar, honey or caramel",
            "sugary and sweet, a treat to finish a meal"),

    SPICY("Spicy",
            "spicy spice spiced hot fiery chili chilli peppery kick heat burning blazing zesty-hot masala-hot",
            "chili:0.85 chilli:0.85 jalapeno:0.85 habanero:0.95 sriracha:0.9 buffalo:0.7 spicy:0.9 hot sauce:0.85 cayenne:0.85 "
                    + "peri:0.8 harissa:0.9 schezwan:0.9 szechuan:0.85 vindaloo:0.95 gochujang:0.85 kimchi:0.6 wasabi:0.5 chipotle:0.75 "
                    + "pepper flakes:0.8 red pepper:0.5 diavola:0.8 arrabbiata:0.85 curry:0.45 tikka:0.4 pepper:0.3 fiery:0.9 "
                    + "masala:0.55 garam masala:0.7 red chilli powder:0.85 chilli powder:0.85 chili powder:0.85 black pepper:0.35 "
                    + "mustard seeds:0.3 curry leaves:0.3 ginger garlic paste:0.35 cloves:0.25 cinnamon:0.15 green chillies:0.8 "
                    + "sambal:0.9 jerk:0.85 piri piri:0.9 chaat:0.3 mirchi:0.9 pickle:0.3 tabasco:0.9 nashville:0.8",
            "a spicy hot dish with chili and heat that makes your mouth burn",
            "fiery and peppery with a strong kick of heat"),

    SOUR("Sour", "sour sourish acidic acid pickled",
            "sour:0.9 tamarind:0.55 sourdough:0.3 kimchi:0.4 kombucha:0.6 sauerkraut:0.8 amchur:0.5 kokum:0.6 pickled:0.5",
            "a sour dish with a sharp acidic taste from vinegar or tamarind",
            "sour and sharp, pickled and acidic"),

    SAVORY("Savory", "savory savoury umami salty meaty hearty-savory brothy",
            "umami:0.9 soy:0.6 mushroom:0.6 bacon:0.8 roasted:0.5 broth:0.6 garlic:0.4 parmesan:0.6 miso:0.8 anchovy:0.7 sausage:0.7 "
                    + "gravy:0.6 steak:0.7 beef:0.5 lamb:0.5 chicken:0.3 salami:0.7 ham:0.6 truffle:0.5 bone broth:0.8 tonkotsu:0.8 pate:0.6",
            "a savory umami dish, salty and meaty",
            "rich savory flavors from roasted meat, broth and mushrooms"),

    CREAMY("Creamy", "creamy cream buttery velvety cheesy smooth silky custardy milky",
            "cream:0.8 butter:0.6 cheese:0.7 mozzarella:0.7 bechamel:0.9 alfredo:0.95 mayo:0.6 coconut milk:0.8 avocado:0.6 custard:0.8 "
                    + "mascarpone:0.9 ricotta:0.8 paneer:0.5 korma:0.7 makhani:0.85 cheddar:0.7 fondue:0.9 carbonara:0.85 risotto:0.6 "
                    + "mornay:0.9 gelato:0.5 yogurt:0.4 cashew:0.3 bisque:0.8 chowder:0.8 mac and cheese:0.9 cheesecake:0.7",
            "a creamy dish with a smooth, rich, cheesy texture",
            "velvety, buttery and creamy"),

    CRUNCHY("Crunchy", "crunchy crispy crisp crackly crunch fried-crisp golden",
            "crispy:0.9 crunchy:0.95 fried:0.55 crumb:0.6 panko:0.85 tempura:0.85 nachos:0.7 chips:0.6 fries:0.6 nuts:0.35 "
                    + "pakora:0.8 samosa:0.7 bhaji:0.7 katsu:0.8 tortilla:0.4 crackers:0.7 croquette:0.8 churro:0.7 wings:0.6 "
                    + "popcorn:0.8 onion rings:0.85 crouton:0.7 tostada:0.7 papad:0.8 bhel:0.5 granola:0.6 brittle:0.8",
            "a crunchy, crispy fried dish with a crackling texture",
            "golden and crisp with a satisfying crunch"),

    TANGY("Tangy", "tangy tart zesty citrusy citrus lemony limey piquant bright",
            "lemon:0.7 lime:0.75 tangy:0.95 citrus:0.8 tamarind:0.8 chaat:0.7 vinegar:0.6 pickle:0.6 yuzu:0.9 ceviche:0.9 "
                    + "mango:0.35 pineapple:0.5 raita:0.4 kokum:0.6 tomatillo:0.7 salsa:0.6 chutney:0.7 vinaigrette:0.7 orange:0.4 "
                    + "sweet and sour:0.9 tom yum:0.8 amchur:0.7 pani puri:0.8 sumac:0.7",
            "a tangy, zesty dish with lemon, lime or tamarind",
            "bright, tart and citrusy"),

    SMOKY("Smoky", "smoky smoked grilled charred barbecue bbq tandoori flame",
            "smoked:0.95 smoky:0.95 grilled:0.6 charred:0.8 bbq:0.85 barbecue:0.85 tandoori:0.8 tandoor:0.8 chargrilled:0.8 "
                    + "wood-fired:0.8 wood fired:0.8 chipotle:0.6 paprika:0.4 brisket:0.7 kebab:0.6 tikka:0.5 pulled pork:0.7 "
                    + "mesquite:0.9 hickory:0.9 pecan wood:0.9 yakitori:0.7 roasted over:0.6 flame:0.6 bhuna:0.4",
            "a smoky grilled dish with charred, barbecue and tandoor flavor",
            "smoked over wood and kissed by the flame"),

    LIGHT("Light", "light lighter healthy lean low-calorie fresh-light airy clean not-heavy",
            "salad:0.8 steamed:0.7 broth:0.4 grilled fish:0.6 cucumber:0.5 greens:0.7 lettuce:0.7 light:0.9 healthy:0.85 quinoa:0.7 "
                    + "poke:0.7 sashimi:0.7 gazpacho:0.8 lean:0.7 avocado toast:0.5 veggie:0.5 raita:0.4 sprouts:0.6 tofu:0.5 "
                    + "wrap:0.3 smoothie:0.5 low-fat:0.85 fruit:0.5 yogurt bowl:0.6 lentil soup:0.5 clear soup:0.8 nigiri:0.6",
            "a light and healthy dish, low in calories, not heavy",
            "a light, clean meal with greens and lean protein"),

    RICH("Rich", "rich decadent heavy indulgent luxurious hearty-rich lavish buttery-rich",
            "truffle:0.8 foie gras:0.9 decadent:0.95 braised:0.6 ghee:0.6 chocolate:0.5 butter:0.45 cream:0.4 short rib:0.8 "
                    + "wagyu:0.85 lobster:0.7 marrow:0.9 ganache:0.9 molten:0.9 makhani:0.7 korma:0.6 duck confit:0.9 fondue:0.8 "
                    + "carbonara:0.6 indulgent:0.95 loaded:0.6 double:0.4 triple:0.5 layered:0.4 bacon:0.4 brisket:0.4 cheesecake:0.6",
            "a rich, decadent and indulgent dish, heavy and luxurious",
            "deeply rich and indulgent, a heavy treat"),

    COMFORT("Comfort", "comfort comforting cozy cosy warm warming hearty homely filling soul",
            "mac and cheese:0.9 mashed:0.7 stew:0.85 soup:0.6 pot pie:0.9 lasagna:0.85 biryani:0.5 dal:0.7 khichdi:0.9 noodles:0.4 "
                    + "pasta:0.4 burger:0.4 fries:0.3 grilled cheese:0.9 meatloaf:0.9 chowder:0.8 ramen:0.6 congee:0.85 shepherd:0.85 "
                    + "casserole:0.9 dumplings:0.5 curry rice:0.7 rajma:0.7 chole:0.5 hearty:0.8 comfort:0.95 cozy:0.9 porridge:0.8 "
                    + "pancake:0.4 waffle:0.4 pudding:0.6 kheer:0.5",
            "a comforting, warm and hearty dish that feels like home",
            "cozy comfort food, filling and warming on a cold or rainy day"),

    FRESH("Fresh", "fresh refreshing cool crisp-fresh herby herbal juicy",
            "fresh:0.9 salad:0.7 herbs:0.6 mint:0.7 basil:0.4 cucumber:0.7 lime:0.4 coconut water:0.8 watermelon:0.8 lemonade:0.8 "
                    + "mojito:0.8 cilantro:0.5 coriander:0.4 sprouts:0.5 citrus:0.5 iced:0.7 cold:0.4 smoothie:0.6 fruit:0.6 "
                    + "gazpacho:0.8 sorbet:0.7 raita:0.6 tabbouleh:0.9 caprese:0.8 poke:0.6 sashimi:0.5 lassi:0.4 spritz:0.7",
            "a fresh and refreshing dish with herbs, cucumber and citrus",
            "cool, juicy and refreshing");

    private final String label;
    private final Set<String> querySynonyms;
    private final Map<String, Double> cues;
    private final List<String> prototypes;

    Flavor(String label, String synonyms, String cueList, String... prototypes) {
        this.label = label;
        this.querySynonyms = Set.copyOf(java.util.Arrays.asList(synonyms.split("\\s+")));
        this.cues = parseCues(cueList);
        this.prototypes = List.of(prototypes);
    }

    private static Map<String, Double> parseCues(String list) {
        Map<String, Double> out = new LinkedHashMap<>();
        // entries are "<phrase>:<weight>" separated by whitespace; phrases may contain spaces, so split on the weights
        java.util.regex.Matcher m = java.util.regex.Pattern.compile("([a-z][a-z\\- ]*?):([0-9.]+)").matcher(list);
        while (m.find()) {
            out.put(m.group(1).trim(), Double.parseDouble(m.group(2)));
        }
        return out;
    }

    public String id() { return name().toLowerCase(Locale.ROOT); }
    public String label() { return label; }
    public Set<String> querySynonyms() { return querySynonyms; }
    /** keyword/phrase to weight: how strongly seeing it in a dish's text suggests this flavor */
    public Map<String, Double> cues() { return cues; }
    public List<String> prototypes() { return prototypes; }

    public static Flavor fromId(String id) {
        if (id == null) return null;
        String norm = id.trim().toLowerCase(Locale.ROOT);
        for (Flavor f : values()) {
            if (f.id().equals(norm)) return f;
        }
        return null;
    }

    public static List<String> ids() {
        List<String> out = new ArrayList<>();
        for (Flavor f : values()) out.add(f.id());
        return out;
    }
}
