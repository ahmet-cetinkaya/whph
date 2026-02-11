#!/usr/bin/env bash
set -e

# WHPH - Migration Generation Script
# This script automates running drift make-migrations and generating a test template.

# 1. Run drift make-migrations
echo "🔨 Running drift_dev make-migrations..."
fvm flutter pub run drift_dev make-migrations

# 2. Generate schema helper files for testing
echo "🔨 Generating drift schema helper files..."
./scripts/generate_gen_files.sh

# 3. Detect the latest schema version
SCHEMAS_DIR="lib/infrastructure/persistence/shared/contexts/drift/schemas/app_database"
LATEST_VERSION=$(ls $SCHEMAS_DIR/drift_schema_v*.json | sed 's/.*_v\(.*\)\.json/\1/' | sort -n | tail -1)
PREVIOUS_VERSION=$((LATEST_VERSION - 1))

MIGRATION_TEST_FILE="../../../tests/unit_tests/infrastructure/persistence/shared/contexts/drift/app_database/migration_test.dart"

if [ ! -f "$MIGRATION_TEST_FILE" ]; then
    echo "⚠️  Migration test file not found at $MIGRATION_TEST_FILE. Skipping test template generation."
    exit 0
fi

# 4. Check if test for this version already exists
if grep -q "migration from v$PREVIOUS_VERSION to v$LATEST_VERSION" "$MIGRATION_TEST_FILE"; then
    echo "✅ Migration test for v$LATEST_VERSION already exists."
else
    echo "🔨 Adding migration test template for v$LATEST_VERSION to $MIGRATION_TEST_FILE..."

    # Template to insert
    # Improved template with proper escaping for sed
    TEMPLATE="    test('migration from v$PREVIOUS_VERSION to v$LATEST_VERSION', () async {\n      final schema$PREVIOUS_VERSION = await verifier.schemaAt($PREVIOUS_VERSION);\n      final db = TestAppDatabase(schema$PREVIOUS_VERSION.newConnection(), $LATEST_VERSION);\n\n      // TODO: Add setup data for v$PREVIOUS_VERSION\n\n      await verifier.migrateAndValidate(db, $LATEST_VERSION);\n\n      // TODO: Add verification logic for v$LATEST_VERSION\n\n      await db.close();\n    });"

    # Find where to insert: inside the 'specific migration scenarios' group
    GROUP_START=$(grep -n "group('specific migration scenarios'" "$MIGRATION_TEST_FILE" | cut -d: -f1)
    if [ -n "$GROUP_START" ]; then
        # Find the next "  });" starting from GROUP_START
        GROUP_END_OFFSET=$(tail -n +$GROUP_START "$MIGRATION_TEST_FILE" | grep -n "^  });" | head -1 | cut -d: -f1)
        INSERT_LINE=$((GROUP_START + GROUP_END_OFFSET - 1))

        # Use a temporary file to perform the insertion safely
        sed "${INSERT_LINE}i $TEMPLATE" "$MIGRATION_TEST_FILE" >"${MIGRATION_TEST_FILE}.tmp" && mv "${MIGRATION_TEST_FILE}.tmp" "$MIGRATION_TEST_FILE"
        echo "✅ Migration test template added for v$LATEST_VERSION."
    else
        echo "⚠️  Could not find 'specific migration scenarios' group in $MIGRATION_TEST_FILE. Appending to end of main instead."
        # Fallback: insert before the last } of main()
        LAST_BRACE=$(grep -n "^}" "$MIGRATION_TEST_FILE" | tail -1 | cut -d: -f1)
        sed "${LAST_BRACE}i $TEMPLATE" "$MIGRATION_TEST_FILE" >"${MIGRATION_TEST_FILE}.tmp" && mv "${MIGRATION_TEST_FILE}.tmp" "$MIGRATION_TEST_FILE"
    fi
fi

echo "✅ Migration automation completed!"
