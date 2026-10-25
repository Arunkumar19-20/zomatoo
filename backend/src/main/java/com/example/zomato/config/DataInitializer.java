package com.example.zomato.config;

import com.example.zomato.entity.*;
import com.example.zomato.repository.*;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.CommandLineRunner;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

@Component
public class DataInitializer implements CommandLineRunner {

    private static final Logger logger = LoggerFactory.getLogger(DataInitializer.class);

    private final UserRepository userRepository;
    private final CustomerRepository customerRepository;
    private final RestaurantOwnerRepository restaurantOwnerRepository;
    private final LocationRepository locationRepository;
    private final RestaurantRepository restaurantRepository;
    private final MenuCategoryRepository menuCategoryRepository;
    private final MenuItemRepository menuItemRepository;
    private final DropRepository dropRepository;
    private final PasswordEncoder passwordEncoder;
    private final org.springframework.jdbc.core.JdbcTemplate jdbcTemplate;
    private final org.springframework.core.env.Environment environment;

    public DataInitializer(UserRepository userRepository,
                           CustomerRepository customerRepository,
                           RestaurantOwnerRepository restaurantOwnerRepository,
                           LocationRepository locationRepository,
                           RestaurantRepository restaurantRepository,
                           MenuCategoryRepository menuCategoryRepository,
                           MenuItemRepository menuItemRepository,
                           DropRepository dropRepository,
                           PasswordEncoder passwordEncoder,
                           org.springframework.jdbc.core.JdbcTemplate jdbcTemplate,
                           org.springframework.core.env.Environment environment) {
        this.environment = environment;
        this.userRepository = userRepository;
        this.customerRepository = customerRepository;
        this.restaurantOwnerRepository = restaurantOwnerRepository;
        this.locationRepository = locationRepository;
        this.restaurantRepository = restaurantRepository;
        this.menuCategoryRepository = menuCategoryRepository;
        this.menuItemRepository = menuItemRepository;
        this.dropRepository = dropRepository;
        this.passwordEncoder = passwordEncoder;
        this.jdbcTemplate = jdbcTemplate;
    }

    @Override
    @Transactional
    public void run(String... args) {
        logger.info("[DEV] Initializing seed data...");

        // 1. Admin account
        if (userRepository.findByEmail("admin@cravey.com").isEmpty()) {
            User admin = new User("Admin", "admin@cravey.com", "ADMIN");
            admin.setPassword(passwordEncoder.encode("Password123!"));
            admin.setEmailVerified(true);
            userRepository.save(admin);
            logger.info("[DEV] Seeded admin user: admin@cravey.com / Password123!");
        }

        // 2. Restaurant Owner account
        RestaurantOwner owner = null;
        if (userRepository.findByEmail("owner@cravey.com").isEmpty()) {
            User ownerUser = new User("Restaurant Owner", "owner@cravey.com", "OWNER");
            ownerUser.setPassword(passwordEncoder.encode("Password123!"));
            ownerUser.setEmailVerified(true);
            userRepository.save(ownerUser);

            owner = new RestaurantOwner("Restaurant Owner", "owner@cravey.com", "+1-555-0199");
            owner = restaurantOwnerRepository.save(owner);
            logger.info("[DEV] Seeded owner user: owner@cravey.com / Password123!");
        } else {
            owner = restaurantOwnerRepository.findAll().stream()
                    .filter(o -> "owner@cravey.com".equalsIgnoreCase(o.getEmail()))
                    .findFirst()
                    .orElseGet(() -> restaurantOwnerRepository.save(new RestaurantOwner("Restaurant Owner", "owner@cravey.com", "+1-555-0199")));
        }

        // 3. Customer account
        if (userRepository.findByEmail("customer@cravey.com").isEmpty()) {
            User customerUser = new User("Customer", "customer@cravey.com", "CUSTOMER");
            customerUser.setPassword(passwordEncoder.encode("Password123!"));
            customerUser.setEmailVerified(true);
            User savedCustomer = userRepository.save(customerUser);

            Customer customer = new Customer();
            customer.setName("Customer");
            customer.setEmail("customer@cravey.com");
            customer.setAddress("123 Foodie Lane, Gourmet City");
            customer.setUserId(savedCustomer.getUserId());
            customerRepository.save(customer);
            logger.info("[DEV] Seeded customer user: customer@cravey.com / Password123!");
        }

        // 3b. The people the app's "Quick Demo Sign-In" signs in as, so the demo button works against a fresh database
        if (environment.acceptsProfiles(org.springframework.core.env.Profiles.of("demo", "dev"))) {
            seedClientDemoAccounts();
        }

        // 4. Sample Restaurant & Menu Items
        if (restaurantRepository.count() == 0) {
            Location location = new Location(37.7749f, -122.4194f, "123 Cravey Way", "San Francisco", "CA", "94103");
            Location savedLocation = locationRepository.save(location);

            Restaurant restaurant = new Restaurant(
                    "Cravey Kitchen",
                    "123 Cravey Way, San Francisco",
                    savedLocation,
                    owner,
                    4.8f,
                    true,
                    "10:00 AM - 11:00 PM",
                    25
            );
            restaurant.setImageUrl("https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=500&auto=format&fit=crop&q=60");
            restaurant.setCuisine("Italian, American, Comfort Food");
            restaurant.setDiscount("20% OFF up to $10");
            Restaurant savedRestaurant = restaurantRepository.save(restaurant);

            MenuCategory popularCategory = new MenuCategory("Popular", 1, savedRestaurant);
            MenuCategory savedCat1 = menuCategoryRepository.save(popularCategory);

            MenuCategory mainsCategory = new MenuCategory("Mains", 2, savedRestaurant);
            MenuCategory savedCat2 = menuCategoryRepository.save(mainsCategory);

            MenuItem item1 = new MenuItem(
                    "Margherita Pizza",
                    "San Marzano tomatoes, fresh mozzarella, sweet basil, extra virgin olive oil",
                    14.99f,
                    true,
                    true,
                    "https://images.unsplash.com/photo-1574071318508-1cdbab80d002?w=400&auto=format&fit=crop&q=60",
                    savedCat1
            );
            menuItemRepository.save(item1);

            MenuItem item2 = new MenuItem(
                    "Truffle Mushroom Burger",
                    "Gourmet patty, black truffle aioli, sauteed portobello, sharp aged cheddar",
                    16.50f,
                    false,
                    true,
                    "https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=400&auto=format&fit=crop&q=60",
                    savedCat1
            );
            menuItemRepository.save(item2);

            MenuItem item3 = new MenuItem(
                    "Pasta Primavera",
                    "Al dente fettuccine, crisp asparagus, sun-dried tomatoes, light garlic cream",
                    13.25f,
                    true,
                    true,
                    "https://images.unsplash.com/photo-1551183053-bf91a1d81141?w=400&auto=format&fit=crop&q=60",
                    savedCat2
            );
            menuItemRepository.save(item3);

            MenuItem item4 = new MenuItem(
                    "Crispy Buffalo Wings",
                    "Double-fried wings coated in spicy house buffalo sauce with blue cheese dip",
                    11.99f,
                    false,
                    true,
                    "https://images.unsplash.com/photo-1567620832903-9fc6debc209f?w=400&auto=format&fit=crop&q=60",
                    savedCat2
            );
            menuItemRepository.save(item4);

            logger.info("[DEV] Seeded restaurant '{}' with 2 categories and 4 menu items.", savedRestaurant.getName());
        }

        // 4. Batch Drops
        if (dropRepository.count() == 0) {
            java.time.LocalDateTime now = java.time.LocalDateTime.now();

            Restaurant seededRest = restaurantRepository.findAll().stream().findFirst().orElse(null);
            Integer restId = seededRest != null ? seededRest.getId() : null;

            Drop drop1 = new Drop();
            drop1.setTitle("Wagyu & Truffle Brioche Sando");
            drop1.setDescription("A5 Miyazaki Wagyu, house black truffle butter, toasted brioche, and caramelized onion reduction.");
            drop1.setImageUrl("https://images.unsplash.com/photo-1550547660-d9450f859349?w=600&auto=format&fit=crop&q=80");
            drop1.setPrice(24.50);
            drop1.setRestaurantId(restId);
            drop1.setStartsAt(now.minusMinutes(20));
            drop1.setEndsAt(now.plusHours(2));
            drop1.setTotalSlots(25);
            drop1.setReservedSlots(5);
            dropRepository.save(drop1);

            Drop drop2 = new Drop();
            drop2.setTitle("Midnight Smoked Brisket Bao");
            drop2.setDescription("14-hour pecan wood smoked prime brisket, pickled daikon, hoisin glaze, steamed lotus buns.");
            drop2.setImageUrl("https://images.unsplash.com/photo-1563245372-f21724e3856d?w=600&auto=format&fit=crop&q=80");
            drop2.setPrice(18.00);
            drop2.setRestaurantId(restId);
            drop2.setStartsAt(now.plusHours(1).plusMinutes(30));
            drop2.setEndsAt(now.plusHours(4));
            drop2.setTotalSlots(15);
            drop2.setReservedSlots(0);
            dropRepository.save(drop2);

            Drop drop3 = new Drop();
            drop3.setTitle("Hokkaido Uni Butter Cacio e Pepe");
            drop3.setDescription("Fresh handmade tonnarelli, whipped sea urchin butter, 24-month pecorino, toasted Sarawak pepper.");
            drop3.setImageUrl("https://images.unsplash.com/photo-1621996346565-e3d5d6281014?w=600&auto=format&fit=crop&q=80");
            drop3.setPrice(28.00);
            drop3.setRestaurantId(restId);
            drop3.setStartsAt(now.minusMinutes(5));
            drop3.setEndsAt(now.plusMinutes(45));
            drop3.setTotalSlots(10);
            drop3.setReservedSlots(8);
            dropRepository.save(drop3);

            logger.info("[DEV] Seeded 3 curated batch drops (2 Live, 1 Upcoming).");
        }
    }

    /**
     * The demo button in the app signs in with a token it makes itself for these emails (see SessionProvider.defaultEmailForRole), so an account has to
     * exist for each or checkout answers "User not found". They get no usable password: nobody can log in as them with a form, only the demo button.
     * Created only in the demo and dev profiles, never in production.
     */
    private void seedClientDemoAccounts() {
        String[][] people = {
                {"Aarav Sharma", "aarav.sharma@gmail.com", "CUSTOMER"},
                {"Arun Kumar", "arunkumar2006.d@gmail.com", "OWNER"},
                {"Rahul Singh", "rahul.singh@gmail.com", "DELIVERY"},
                {"Admin One", "admin1@zomato.com", "ADMIN"},
        };
        for (String[] p : people) {
            if (userRepository.findByEmail(p[1]).isPresent()) continue;
            User u = new User(p[0], p[1], p[2]);
            u.setPassword(passwordEncoder.encode(java.util.UUID.randomUUID().toString()));
            u.setEmailVerified(true);
            User saved = userRepository.save(u);
            if ("CUSTOMER".equals(p[2])) {
                // the app may already have made a bare customer for this email (adding to the cart creates one on the spot); a second row would make
                // every lookup by email fail, so reuse it and just attach the account
                var existing = customerRepository.findAll().stream().filter(c -> p[1].equalsIgnoreCase(c.getEmail())).toList();
                if (existing.isEmpty()) {
                    Customer c = new Customer();
                    c.setName(p[0]);
                    c.setEmail(p[1]);
                    c.setAddress("123 Foodie Lane, Gourmet City");
                    c.setUserId(saved.getUserId());
                    customerRepository.save(c);
                } else {
                    for (Customer c : existing) {
                        if (c.getUserId() == null) c.setUserId(saved.getUserId());
                        if (c.getName() == null || c.getName().equalsIgnoreCase("CUSTOMER")) c.setName(p[0]);
                        customerRepository.save(c);
                    }
                }
            } else if ("OWNER".equals(p[2])) {
                if (restaurantOwnerRepository.findByEmailIgnoreCase(p[1]).isEmpty()) {
                    restaurantOwnerRepository.save(new RestaurantOwner(p[0], p[1], "+1-555-0100"));
                }
            }
            logger.info("[DEV] Seeded demo-button account {} ({}), no password", p[1], p[2]);
        }
    }
}
