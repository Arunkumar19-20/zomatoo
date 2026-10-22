package com.example.zomato.config;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

import javax.sql.DataSource;
import java.sql.Connection;

/**
 * Creates the partial unique indexes that make the drop invariants hold across app instances.
 *
 * Hibernate cannot declare partial indexes, and the SQL files in db/migration are only applied once Flyway is
 * wired into Spring Boot 4 (it needs spring-boot-starter-flyway). Until then this runner is what guarantees,
 * on every start and on PostgreSQL, that
 *  - a customer has at most one HELD/CONFIRMED reservation per drop, and
 *  - a customer has at most one WAITING/OFFERED waitlist entry per drop.
 * H2 (the default test database) has no partial indexes; there the service layer enforces both rules.
 */
@Component
@Order(Ordered.HIGHEST_PRECEDENCE)
public class DropSchemaInitializer implements ApplicationRunner {

    private static final Logger logger = LoggerFactory.getLogger(DropSchemaInitializer.class);

    private final JdbcTemplate jdbc;
    private final DataSource dataSource;

    public DropSchemaInitializer(JdbcTemplate jdbc, DataSource dataSource) {
        this.jdbc = jdbc;
        this.dataSource = dataSource;
    }

    @Override
    public void run(ApplicationArguments args) {
        if (!isPostgres()) {
            logger.info("Skipping partial unique indexes: not PostgreSQL");
            return;
        }
        ensure("idx_drop_res_active_unique",
                "CREATE UNIQUE INDEX IF NOT EXISTS idx_drop_res_active_unique ON drop_reservations (drop_id, customer_email) "
                        + "WHERE status IN ('HELD', 'CONFIRMED')");
        ensure("idx_drop_waitlist_active_unique",
                "CREATE UNIQUE INDEX IF NOT EXISTS idx_drop_waitlist_active_unique ON drop_waitlist (drop_id, lower(customer_email)) "
                        + "WHERE status IN ('WAITING', 'OFFERED')");
        ensure("idx_drop_waitlist_drop_status",
                "CREATE INDEX IF NOT EXISTS idx_drop_waitlist_drop_status ON drop_waitlist (drop_id, status, id)");
    }

    private void ensure(String name, String ddl) {
        try {
            jdbc.execute(ddl);
            logger.info("Index {} is in place", name);
        } catch (Exception e) {
            // Never block start-up, but this is loud on purpose: the invariant is only service-enforced without it.
            logger.error("Could not create index {}: {}", name, e.getMessage());
        }
    }

    private boolean isPostgres() {
        try (Connection c = dataSource.getConnection()) {
            return c.getMetaData().getDatabaseProductName().toLowerCase().contains("postgres");
        } catch (Exception e) {
            return false;
        }
    }
}
