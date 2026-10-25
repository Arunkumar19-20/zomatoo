package com.example.zomato.search;

import java.util.HashMap;
import java.util.Locale;
import java.util.Map;
import java.util.Optional;

/**
 * Words that point to a cuisine: the cuisine's name and the dishes it is known for. Two cuisines in one craving
 * ("kimchi carbonara" = Korean + Italian) is how a fusion is recognised, with no list of fusions to maintain.
 * Words that belong to several cuisines (curry, dumpling, noodle) are left out on purpose.
 */
public final class CuisineLexicon {

    private static final Map<String, String> WORD_TO_CUISINE = new HashMap<>();
    private static final Map<String, String> LABELS = new HashMap<>();

    private static void add(String id, String label, String words) {
        LABELS.put(id, label);
        for (String w : words.split("\\s+")) WORD_TO_CUISINE.put(Bm25Index.stem(w), id);
    }

    static {
        add("korean", "Korean", "korean korea kimchi bulgogi bibimbap gochujang tteokbokki kbbq japchae");
        add("italian", "Italian", "italian italy pizza pasta carbonara risotto lasagna lasagne tiramisu gnocchi ravioli bruschetta calzone "
                + "spaghetti fettuccine alfredo margherita pesto focaccia gelato penne");
        add("japanese", "Japanese", "japanese japan sushi ramen tempura teriyaki udon miso katsu takoyaki mochi matcha okonomiyaki sashimi yakitori");
        add("chinese", "Chinese", "chinese china wonton szechuan sichuan schezwan chowmein hakka");
        add("thai", "Thai", "thai thailand tomyum somtam");
        add("indian", "Indian", "indian india biryani tikka masala paneer naan tandoori dosa samosa vindaloo korma chaat idli paratha pakora");
        add("mexican", "Mexican", "mexican mexico taco burrito quesadilla nacho enchilada guacamole birria churro fajita tamale salsa");
        add("american", "American", "american burger brisket hotdog meatloaf");
        add("french", "French", "french france croissant crepe baguette brioche souffle ratatouille quiche macaron eclair");
        add("spanish", "Spanish", "spanish spain paella tapas jamon gazpacho");
        add("greek", "Greek", "greek greece gyro souvlaki tzatziki moussaka");
        add("turkish", "Turkish", "turkish kebab baklava doner lahmacun");
        add("middle-eastern", "Middle Eastern", "arabic lebanese shawarma falafel hummus mezze");
        add("vietnamese", "Vietnamese", "vietnamese vietnam pho banh");
        add("ethiopian", "Ethiopian", "ethiopian ethiopia injera");
        add("peruvian", "Peruvian", "peruvian peru ceviche");
        add("moroccan", "Moroccan", "moroccan morocco tagine couscous");
        add("german", "German", "german germany bratwurst schnitzel pretzel");
        add("caribbean", "Caribbean", "caribbean jamaican jerk");
        add("west-african", "West African", "nigerian ghanaian jollof");
        add("brazilian", "Brazilian", "brazilian brazil");
    }

    private CuisineLexicon() {}

    /** @param stemmedToken a token as produced by {@link Bm25Index#tokenize} */
    public static Optional<String> cuisineOf(String stemmedToken) {
        return Optional.ofNullable(WORD_TO_CUISINE.get(stemmedToken.toLowerCase(Locale.ROOT)));
    }

    public static String label(String cuisineId) {
        return LABELS.getOrDefault(cuisineId, cuisineId);
    }
}
