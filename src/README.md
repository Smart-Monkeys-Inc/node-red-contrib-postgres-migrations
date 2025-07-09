# `node-red-contrib-postgres-migrations`

A Node-RED node to execute PostgreSQL database migrations directly from a JavaScript array.

## Overview

This Node-RED custom node provides a flexible way to manage PostgreSQL database schemas within your Node-RED flows. Instead of relying on external migration files, it allows you to define your database migrations as an array of JavaScript objects containing raw SQL `up` scripts.

It handles:

- Connecting to your PostgreSQL database.
- Creating a dedicated `_nodered_migrations` table to track executed migrations.
- Applying new, unapplied migrations in order.
- Reporting on success or failure.

## Features

- **In-Memory Migrations:** Define your migrations directly within Node-RED `Function` nodes or other data sources as a JavaScript array.
- **Raw SQL Support:** Execute arbitrary raw SQL commands for schema changes (`CREATE TABLE`, `ALTER TABLE`, `CREATE INDEX`, etc.).
- **Automatic Tracking:** Automatically tracks applied migrations in your database using a `_nodered_migrations` table.
- **Configurable Connection:** Easily configure PostgreSQL connection details (host, port, user, password, database) via the node's properties.
- **Error Handling:** Provides clear error feedback in Node-RED's debug sidebar and status.

## Usage

Once installed, the "Postgres Migrations" node will appear in the "storage" category of your Node-RED palette.

### 1. Configure the Node

Drag the "Postgres Migrations" node onto your flow. Double-click it to open its properties panel:

- **Name (optional):** A friendly name for the node in your flow.
- **Host:** The hostname or IP address of your PostgreSQL server (e.g., `localhost`, `192.168.1.100`).
- **Port:** The port number for your PostgreSQL server (default: `5432`).
- **User:** The username to connect to the database.
- **Password:** The password for the specified user.
- **Database:** The name of the database to connect to.

### 2. Prepare `msg.migrations`

The node expects an input message with a `msg.migrations` property. This property must be an **array of migration objects**. Each migration object needs:

- `name` (string): A unique identifier for the migration. It's highly recommended to use a timestamp-based format (e.g., `YYYYMMDDHHmmss_description`) to ensure correct ordering.
- `up` (string): The raw SQL string to apply this migration.

#### Example `msg.migrations` array (e.g., from a Function node):

```javascript
msg.migrations = [
  {
    name: "20250709100000_create_devices_table",
    up: `
      CREATE TABLE devices (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        name TEXT NOT NULL,
        location TEXT,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
      );
    `,
  },
  {
    name: "20250709100100_create_readings_table",
    up: `
      CREATE TABLE readings (
        id BIGSERIAL PRIMARY KEY,
        device_id UUID NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
        value NUMERIC NOT NULL,
        recorded_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
      );
      CREATE INDEX idx_readings_device_time ON readings (device_id, recorded_at DESC);
    `,
  },
  {
    name: "20250709100200_alter_devices_add_firmware",
    up: "ALTER TABLE devices ADD COLUMN firmware_version VARCHAR(50);",
  },
];

return msg;
```

## Node Inputs

<dl class="message-properties">
  <dt>msg.migrations <span class="property-type">array</span></dt>
  <dd>An array of migration objects, each with <code>name</code> and <code>up</code> string properties containing raw SQL.</dd>
</dl>

## Node Outputs

<dl class="message-properties">
  <dt>msg.payload <span class="property-type">object</span></dt>
  <dd>
    On successful completion, the <code>msg.payload</code> will contain an object with a summary of the migration run:
    <ul>
      <li><code>summary</code> (string): A human-readable summary of applied and skipped migrations.</li>
      <li><code>applied</code> (array): An array of names of migrations that were successfully applied during this run.</li>
      <li><code>skipped</code> (number): The count of migrations that were already applied and thus skipped.</li>
    </ul>
  </dd>
</dl>

## How it Works

1.  **Connection:** Upon receiving a message, the node establishes a temporary connection to the PostgreSQL database using the provided configuration.
2.  **Migration Tracking Table:** It checks for the existence of a table named `_nodered_migrations`. If it doesn't exist, it creates it with `name`, `batch`, and `migration_time` columns. This table stores the names of all migrations that have been successfully run.
3.  **Identify Pending Migrations:** It queries `_nodered_migrations` to get a list of already applied migrations. It then compares this list with the `msg.migrations` array to identify which migrations are pending.
4.  **Execute Migrations:** For each pending migration in the `msg.migrations` array (ordered by their appearance in the array), it executes the `up` SQL script using `knex.raw()`.
5.  **Record Migration:** After successful execution of an `up` script, the migration's `name` is inserted into the `_nodered_migrations` table, along with a `batch` number and timestamp.
6.  **Cleanup:** The database connection is closed after processing all migrations or on error.
7.  **Status and Output:** The node's status indicates progress and final outcome. A success message with details is sent to `msg.payload` on completion. Errors are caught and sent to Node-RED's error handling.

## Dependencies

This node relies on:

- `knex`
- `pg` (PostgreSQL driver)

These dependencies are automatically installed when you install the Node-RED package.

## License

This project is licensed under the MIT License. See the `LICENSE` file for details.
