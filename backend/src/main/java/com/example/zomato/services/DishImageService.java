package com.example.zomato.services;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.UUID;
import java.util.regex.Pattern;

/**
 * Dish photos uploaded by restaurant owners. Files are kept on disk under {@code uploads.dir}/dishes with a random name and served from /uploads/dishes/...
 * What arrives is checked for what it really is (the first bytes), not for what the file claims to be: only JPEG, PNG and WebP, at most 2 MB.
 * The name never comes from the client, so a file can neither overwrite another nor escape the folder.
 */
@Service
public class DishImageService {

    public static final long MAX_BYTES = 2L * 1024 * 1024;
    public static final String URL_PREFIX = "/uploads/dishes/";
    private static final Pattern OURS = Pattern.compile("[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\\.(jpg|png|webp)");

    private final Path root;

    public DishImageService(@Value("${uploads.dir:uploads}") String dir) {
        this.root = Path.of(dir).toAbsolutePath().normalize();
    }

    /** The folder that holds everything uploaded (its dishes/ subfolder holds the photos). */
    public Path root() { return root; }

    /** Saves a photo and returns the path to store on the dish, like /uploads/dishes/0b1c...-....jpg. */
    public String store(byte[] data) {
        if (data == null || data.length == 0) throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "No image was sent.");
        if (data.length > MAX_BYTES) throw new ResponseStatusException(HttpStatus.PAYLOAD_TOO_LARGE, "The photo is larger than 2 MB.");
        String ext = extensionOf(data);
        if (ext == null) throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Only JPEG, PNG or WebP photos are accepted.");
        String name = UUID.randomUUID() + "." + ext;
        try {
            Path dir = root.resolve("dishes");
            Files.createDirectories(dir);
            Files.write(dir.resolve(name), data);
        } catch (IOException e) {
            throw new ResponseStatusException(HttpStatus.INTERNAL_SERVER_ERROR, "The photo could not be saved.");
        }
        return URL_PREFIX + name;
    }

    /** Removes a stored photo if the path is one of ours; anything else (a link to another site, an empty value) is left alone. */
    public void deleteIfOurs(String imageUrl) {
        if (imageUrl == null || !imageUrl.startsWith(URL_PREFIX)) return;
        String name = imageUrl.substring(URL_PREFIX.length());
        if (!OURS.matcher(name).matches()) return;   // also rules out any path trickery
        try {
            Files.deleteIfExists(root.resolve("dishes").resolve(name));
        } catch (IOException ignored) {
            // a photo that cannot be deleted is not worth failing the request over
        }
    }

    /** jpg, png or webp from the leading bytes; null for anything else. */
    static String extensionOf(byte[] d) {
        if (d.length >= 3 && (d[0] & 0xFF) == 0xFF && (d[1] & 0xFF) == 0xD8 && (d[2] & 0xFF) == 0xFF) return "jpg";
        if (d.length >= 8 && (d[0] & 0xFF) == 0x89 && d[1] == 'P' && d[2] == 'N' && d[3] == 'G' && d[4] == 0x0D && d[5] == 0x0A && d[6] == 0x1A && d[7] == 0x0A) return "png";
        if (d.length >= 12 && d[0] == 'R' && d[1] == 'I' && d[2] == 'F' && d[3] == 'F' && d[8] == 'W' && d[9] == 'E' && d[10] == 'B' && d[11] == 'P') return "webp";
        return null;
    }
}
