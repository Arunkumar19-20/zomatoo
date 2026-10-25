package com.example.zomato.search;

import com.example.zomato.search.PhraseMiner.Kind;
import com.example.zomato.search.PhraseMiner.Phrase;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;

class PhraseMinerTest {

    @Test
    void differentWordingsOfAKoreanItalianFusionAreOnePhrase() {
        String key = "fusion:italian+korean";
        for (String q : new String[]{"korean italian fusion", "kimchi carbonara", "bulgogi pizza", "korean style carbonara", "italian korean fusion pasta",
                "gochujang pizza", "Korean x Italian fusion"}) {
            Phrase p = PhraseMiner.mine(q.toLowerCase(), "");
            assertNotNull(p, q);
            assertEquals(key, p.key(), q);
            assertEquals(Kind.FUSION, p.kind());
        }
        assertEquals("Italian × Korean fusion", PhraseMiner.mine("kimchi carbonara", "").label());
    }

    @Test
    void oneCuisineIsNotAFusion() {
        assertEquals(Kind.DISH, PhraseMiner.mine("pizza and pasta", "").kind());
        assertEquals(Kind.DISH, PhraseMiner.mine("margherita pizza", "").kind());
    }

    @Test
    void pluralsAndWordOrderMeetInOneDishKey() {
        assertEquals(PhraseMiner.mine("birria tacos", "").key(), PhraseMiner.mine("taco birria", "").key());
        assertEquals("dish:birria+taco", PhraseMiner.mine("birria tacos", "").key());
    }

    @Test
    void flavorOnlyCravingsBecomeFlavorPhrases() {
        Phrase p = PhraseMiner.mine("something sweet spicy", "spicy,sweet");
        assertEquals(Kind.FLAVOR, p.kind());
        assertEquals("flavor:spicy+sweet", p.key());
        assertEquals("Spicy + Sweet", p.label());
    }

    @Test
    void moodsAndOccasionsNeverBecomePhrases() {
        assertNull(PhraseMiner.mine("late night snack", ""));
        assertNull(PhraseMiner.mine("something to share with friends", ""));
        assertNull(PhraseMiner.mine("", ""));
        assertNull(PhraseMiner.mine("something good", ""));
    }

    @Test
    void moodWordsAreDroppedWhenFoodIsNamed() {
        assertEquals(PhraseMiner.mine("noodles", "").key(), PhraseMiner.mine("late night noodles", "").key());
    }

    @Test
    void flavorWordsAreDroppedFromADishPhrase() {
        assertEquals(PhraseMiner.mine("noodles", "").key(), PhraseMiner.mine("spicy noodles", "spicy").key());
    }

    @Test
    void spellingVariantsAreTheSameDemand() {
        assertEquals(PhraseMiner.mine("prawn curry", "").key(), PhraseMiner.mine("shrimp curry", "").key());
        assertEquals(PhraseMiner.mine("chocolate donut", "").key(), PhraseMiner.mine("chocolate doughnuts", "").key());
        assertEquals(PhraseMiner.mine("szechuan noodles", "").key(), PhraseMiner.mine("schezwan noodle", "").key());
        assertEquals(PhraseMiner.mine("chicken biryani", "").key(), PhraseMiner.mine("chicken biriyani", "").key());
    }
}
