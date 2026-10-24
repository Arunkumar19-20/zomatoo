package com.example.zomato.search;

import com.example.zomato.entity.MenuCategory;
import com.example.zomato.entity.MenuItem;
import com.example.zomato.entity.MenuItemEmbedding;
import com.example.zomato.entity.MenuItemTag;
import com.example.zomato.entity.Restaurant;
import com.example.zomato.repository.MenuItemEmbeddingRepository;
import com.example.zomato.repository.MenuItemRepository;
import com.example.zomato.repository.MenuItemTagRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.event.EventListener;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.ArrayList;
import java.util.Collection;
import java.util.EnumMap;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Owns the in-memory search state (dish documents, BM25, vectors) and keeps it in step with the database:
 * a dish saved, edited, toggled or deleted is searchable (or gone) immediately. Tags and vectors are persisted so a
 * restart only re-embeds dishes whose text changed.
 */
@Service
public class SearchIndexService {

    private static final Logger log = LoggerFactory.getLogger(SearchIndexService.class);
    static final Set<String> TEMPS = Set.of("HOT", "COLD", "ROOM");

    private final MenuItemRepository items;
    private final MenuItemTagRepository tagRepo;
    private final MenuItemEmbeddingRepository embeddingRepo;
    private final EmbeddingProvider provider;
    private final AutoTagger autoTagger;

    private final Map<Integer, DishDoc> docs = new ConcurrentHashMap<>();
    private final Bm25Index bm25 = new Bm25Index();
    private final FlatVectorIndex vectors = new FlatVectorIndex();
    private volatile boolean loaded;

    @jakarta.persistence.PersistenceContext
    private jakarta.persistence.EntityManager em;

    public SearchIndexService(MenuItemRepository items, MenuItemTagRepository tagRepo, MenuItemEmbeddingRepository embeddingRepo,
                              EmbeddingProvider provider, AutoTagger autoTagger) {
        this.items = items;
        this.tagRepo = tagRepo;
        this.embeddingRepo = embeddingRepo;
        this.provider = provider;
        this.autoTagger = autoTagger;
    }

    // ------------------------------------------------------------------ lifecycle

    @EventListener(ApplicationReadyEvent.class)
    public void onReady() {
        try {
            rebuildAll();
        } catch (RuntimeException e) {
            log.error("Dish search index could not be built at start-up: {}", e.getMessage(), e);
        }
    }

    public void ensureLoaded() {
        if (!loaded) {
            synchronized (this) {
                if (!loaded) rebuildAll();
            }
        }
    }

    @Transactional
    public synchronized int rebuildAll() {
        docs.clear();
        bm25.clear();
        vectors.clear();
        int n = 0;
        for (MenuItem item : items.findAll()) {
            ensureTags(item);
            refresh(item);
            n++;
        }
        loaded = true;
        log.info("Dish search index built: {} dishes, {} vectors ({} mode)", n, vectors.size(), provider.isSemantic() ? "semantic" : "keyword");
        return n;
    }

    // ------------------------------------------------------------------ writes

    /**
     * Call after a dish is saved. {@code ownerTags}, when given, replace the owner's tags; otherwise the dish keeps
     * any owner tags it has and gets automatic suggestions only if it has none.
     */
    @Transactional
    public void onSaved(MenuItem item, List<String> ownerTags) {
        if (item.getId() == null) return;
        if (ownerTags != null) {
            tagRepo.deleteByItemId(item.getId());
            for (String t : ownerTags) tagRepo.save(new MenuItemTag(item.getId(), t, MenuItemTag.OWNER, 1.0f));
        } else {
            // text may have changed: refresh the automatic suggestions, never touch what an owner confirmed
            if (tagRepo.findByItemId(item.getId()).stream().noneMatch(MenuItemTag::isOwner)) {
                tagRepo.deleteByItemIdAndSource(item.getId(), MenuItemTag.AUTO);
            }
            ensureTags(item);
        }
        refresh(item);
    }

    /** Availability or price changed: cheap refresh, the vector is reused because the text is unchanged. */
    @Transactional
    public void onChanged(MenuItem item) {
        if (item.getId() != null) refresh(item);
    }

    @Transactional
    public void onDeleted(int itemId) {
        tagRepo.deleteByItemId(itemId);
        embeddingRepo.findById(itemId).ifPresent(embeddingRepo::delete);
        docs.remove(itemId);
        bm25.remove(itemId);
        vectors.remove(itemId);
    }

    /** Validates what an owner sent. Throws 400 with a message the form can show. */
    public static List<String> validateOwnerInput(MenuItem item) {
        if (item.getSpiceLevel() != null && (item.getSpiceLevel() < 0 || item.getSpiceLevel() > 4)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "spiceLevel must be between 0 and 4");
        }
        if (item.getServingTemp() != null && !item.getServingTemp().isBlank()) {
            String t = item.getServingTemp().trim().toUpperCase(Locale.ROOT);
            if (!TEMPS.contains(t)) throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "servingTemp must be HOT, COLD or ROOM");
            item.setServingTemp(t);
        }
        List<String> raw = item.getFlavorTags();
        if (raw == null) return null;
        Set<String> clean = new LinkedHashSet<>();
        for (String r : raw) {
            Flavor f = Flavor.fromId(r);
            if (f == null) {
                throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                        "Unknown flavor tag \"" + r + "\". Choose from: " + String.join(", ", Flavor.ids()));
            }
            clean.add(f.id());
        }
        if (clean.size() < 2) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Pick at least 2 flavor tags so customers can find this dish");
        }
        return new ArrayList<>(clean);
    }

    // ------------------------------------------------------------------ reads

    public Collection<DishDoc> allDocs() { return docs.values(); }
    public Optional<DishDoc> doc(int id) { return Optional.ofNullable(docs.get(id)); }
    public Bm25Index bm25() { return bm25; }
    public FlatVectorIndex vectors() { return vectors; }
    public EmbeddingProvider provider() { return provider; }
    public AutoTagger autoTagger() { return autoTagger; }
    public int size() { return docs.size(); }

    @Transactional(readOnly = true)
    public List<MenuItemTag> tagsOf(int itemId) { return tagRepo.findByItemId(itemId); }

    // ------------------------------------------------------------------ internals

    private void ensureTags(MenuItem item) {
        if (item.getId() == null || !tagRepo.findByItemId(item.getId()).isEmpty()) return;
        String category = item.getCategory() == null ? null : item.getCategory().getName();
        for (TagSuggestion s : autoTagger.suggest(item.getName(), item.getDescription(), item.getIngredients(), category)) {
            tagRepo.save(new MenuItemTag(item.getId(), s.flavor().id(), MenuItemTag.AUTO, (float) s.confidence()));
        }
    }

    /**
     * A dish posted by the app arrives with a stub category (just its id). Within a web request the persistence
     * context is shared (open-in-view), so a plain findById would hand back that same stub; refresh it from the
     * database so its restaurant, cuisine and section are real. Otherwise the dish would be indexed without them.
     */
    private MenuItem reloaded(MenuItem saved) {
        try {
            if (em.contains(saved)) {
                em.refresh(saved);
                return saved;
            }
        } catch (RuntimeException e) {
            log.debug("Could not refresh dish {}: {}", saved.getId(), e.toString());
        }
        return items.findById(saved.getId()).orElse(saved);
    }

    private void refresh(MenuItem saved) {
        MenuItem item = reloaded(saved);
        List<MenuItemTag> tagRows = tagRepo.findByItemId(item.getId());
        Map<Flavor, Double> tags = new EnumMap<>(Flavor.class);
        Map<Flavor, Boolean> owner = new EnumMap<>(Flavor.class);
        for (MenuItemTag t : tagRows) {
            Flavor f = Flavor.fromId(t.getTag());
            if (f == null) continue;
            tags.put(f, t.isOwner() ? 1.0 : (t.getConfidence() == null ? 0.6 : t.getConfidence().doubleValue()));
            owner.put(f, t.isOwner());
        }

        MenuCategory category = item.getCategory();
        Restaurant restaurant = category == null ? null : category.getRestaurant();
        DishDoc doc = new DishDoc(
                item.getId(), item.getName(), item.getDescription(), item.getIngredients(),
                category == null ? null : category.getName(), item.getMood(), item.getSpiceLevel(), item.getServingTemp(),
                Boolean.TRUE.equals(item.getIsVeg()), !Boolean.FALSE.equals(item.getIsAvailable()),
                item.getPrice() == null ? 0f : item.getPrice(), item.getImageUrl(),
                restaurant == null ? 0 : restaurant.getId(), restaurant == null ? null : restaurant.getName(),
                restaurant == null ? null : restaurant.getCuisine(),
                restaurant == null || !Boolean.FALSE.equals(restaurant.getOpen()),
                Map.copyOf(tags), Map.copyOf(owner));
        docs.put(doc.itemId(), doc);
        bm25.upsert(doc.itemId(), weightedText(doc));
        if (provider.isSemantic()) {
            try {
                vectors.put(doc.itemId(), vectorFor(doc));
            } catch (RuntimeException e) {
                log.warn("Could not embed dish {}: {}", doc.itemId(), e.getMessage());
            }
        }
    }

    private float[] vectorFor(DishDoc doc) {
        String text = doc.embeddingText();
        String hash = sha256(text);
        Optional<MenuItemEmbedding> stored = embeddingRepo.findById(doc.itemId());
        if (stored.isPresent() && stored.get().getTextHash().equals(hash)
                && stored.get().getModelVersion().equals(provider.modelVersion())) {
            return stored.get().vector();
        }
        float[] v = provider.embedDocument(text);
        embeddingRepo.save(new MenuItemEmbedding(doc.itemId(), v, provider.modelVersion(), hash));
        return v;
    }

    /** Field weights: the name matters most, then flavor tags and ingredients. */
    static Map<String, Integer> weightedText(DishDoc d) {
        Map<String, Integer> w = new LinkedHashMap<>();
        w.put(d.name(), 3);
        StringBuilder tagText = new StringBuilder();
        d.tags().keySet().forEach(f -> tagText.append(f.id()).append(' ').append(String.join(" ", f.querySynonyms())).append(' '));
        w.put(tagText.toString(), 2);
        if (d.ingredients() != null) w.put(d.ingredients(), 2);
        if (d.description() != null) w.put(d.description(), 1);
        if (d.category() != null) w.put(d.category(), 1);
        if (d.cuisine() != null) w.put(d.cuisine(), 1);
        if (d.mood() != null) w.put(d.mood(), 1);
        return w;
    }

    static String sha256(String s) {
        try {
            byte[] h = MessageDigest.getInstance("SHA-256").digest(s.getBytes(StandardCharsets.UTF_8));
            StringBuilder sb = new StringBuilder();
            for (byte b : h) sb.append(String.format("%02x", b));
            return sb.toString();
        } catch (java.security.NoSuchAlgorithmException e) {
            throw new IllegalStateException(e);
        }
    }
}
