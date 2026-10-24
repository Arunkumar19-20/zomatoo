package com.example.zomato.search;

import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Arrays;
import java.util.List;

/** What the owner's add-dish form needs: the tag vocabulary, live suggestions, and a dish's current tags. */
@RestController
@RequestMapping("/menu-items")
public class MenuItemTagController {

    private final SearchIndexService index;

    public MenuItemTagController(SearchIndexService index) {
        this.index = index;
    }

    public record SuggestRequest(String name, String description, String ingredients, String categoryName) {}

    public record Suggestion(String tag, String label, double confidence, List<String> reasons) {}

    public record SuggestResponse(String mode, List<Suggestion> suggestions) {}

    public record FlavorInfo(String id, String label) {}

    public record TagInfo(String tag, String label, String source, double confidence) {}

    @GetMapping("/flavor-tags")
    public List<FlavorInfo> vocabulary() {
        return Arrays.stream(Flavor.values()).map(f -> new FlavorInfo(f.id(), f.label())).toList();
    }

    /** Called as the owner types the name, description and ingredients; nothing is saved. */
    @PreAuthorize("hasAnyRole('OWNER', 'ADMIN')")
    @PostMapping("/suggest-tags")
    public SuggestResponse suggest(@RequestBody SuggestRequest req) {
        List<Suggestion> out = index.autoTagger().suggest(req.name(), req.description(), req.ingredients(), req.categoryName()).stream()
                .map(s -> new Suggestion(s.flavor().id(), s.flavor().label(), s.confidence(), s.reasons())).toList();
        return new SuggestResponse(index.provider().isSemantic() ? "SEMANTIC" : "KEYWORD", out);
    }

    @GetMapping("/{id}/tags")
    public List<TagInfo> tags(@PathVariable int id) {
        return index.tagsOf(id).stream().map(t -> {
            Flavor f = Flavor.fromId(t.getTag());
            return new TagInfo(t.getTag(), f == null ? t.getTag() : f.label(), t.getSource(),
                    t.getConfidence() == null ? 1.0 : t.getConfidence());
        }).toList();
    }
}
