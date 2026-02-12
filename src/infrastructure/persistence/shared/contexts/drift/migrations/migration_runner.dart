import 'package:drift/drift.dart';
import 'package:infrastructure_persistence/shared/contexts/drift/drift_app_context.dart';
import 'package:infrastructure_persistence/shared/contexts/drift/drift_app_context.steps.dart';

import 'migration_v1_to_v2.dart';
import 'migration_v2_to_v3.dart';
import 'migration_v3_to_v4.dart';
import 'migration_v4_to_v5.dart';
import 'migration_v5_to_v6.dart';
import 'migration_v6_to_v7.dart';
import 'migration_v7_to_v8.dart';
import 'migration_v8_to_v9.dart';
import 'migration_v9_to_v10.dart';
import 'migration_v10_to_v11.dart';
import 'migration_v11_to_v12.dart';
import 'migration_v12_to_v13.dart';
import 'migration_v13_to_v14.dart';
import 'migration_v14_to_v15.dart';
import 'migration_v15_to_v16.dart';
import 'migration_v16_to_v17.dart';
import 'migration_v17_to_v18.dart';
import 'migration_v18_to_v19.dart';
import 'migration_v19_to_v20.dart';
import 'migration_v20_to_v21.dart';
import 'migration_v21_to_v22.dart';
import 'migration_v22_to_v23.dart';
import 'migration_v23_to_v24.dart';
import 'migration_v24_to_v25.dart';
import 'migration_v25_to_v26.dart';
import 'migration_v26_to_v27.dart';
import 'migration_v27_to_v28.dart';
import 'migration_v28_to_v29.dart';
import 'migration_v29_to_v30.dart';
import 'migration_v30_to_v31.dart';
import 'migration_v31_to_v32.dart';
import 'migration_v32_to_v33.dart';

/// Extension on AppDatabase to run all migration steps.
extension MigrationRunner on AppDatabase {
  /// Executes all migration steps from [from] version to [to] version.
  Future<void> runMigrationSteps(Migrator m, int from, int to) async {
    var stepsTarget = to;
    if (to > 33) {
      stepsTarget = 33;
    }

    if (from < 33) {
      await stepByStep(
        from1To2: (m, schema) => migrateV1ToV2(this, m, schema),
        from2To3: (m, schema) => migrateV2ToV3(this, m, schema),
        from3To4: (m, schema) => migrateV3ToV4(this, m, schema),
        from4To5: (m, schema) => migrateV4ToV5(this, m, schema),
        from5To6: (m, schema) => migrateV5ToV6(this, m, schema),
        from6To7: (m, schema) => migrateV6ToV7(this, m, schema),
        from7To8: (m, schema) => migrateV7ToV8(this, m, schema),
        from8To9: (m, schema) => migrateV8ToV9(this, m, schema),
        from9To10: (m, schema) => migrateV9ToV10(this, m, schema),
        from10To11: (m, schema) => migrateV10ToV11(this, m, schema),
        from11To12: (m, schema) => migrateV11ToV12(this, m, schema),
        from12To13: (m, schema) => migrateV12ToV13(this, m, schema),
        from13To14: (m, schema) => migrateV13ToV14(this, m, schema),
        from14To15: (m, schema) => migrateV14ToV15(this, m, schema),
        from15To16: (m, schema) => migrateV15ToV16(this, m, schema),
        from16To17: (m, schema) => migrateV16ToV17(this, m, schema),
        from17To18: (m, schema) => migrateV17ToV18(this, m, schema),
        from18To19: (m, schema) => migrateV18ToV19(this, m, schema),
        from19To20: (m, schema) => migrateV19ToV20(this, m, schema),
        from20To21: (m, schema) => migrateV20ToV21(this, m, schema),
        from21To22: (m, schema) => migrateV21ToV22(this, m, schema),
        from22To23: (m, schema) => migrateV22ToV23(this, m, schema),
        from23To24: (m, schema) => migrateV23ToV24(this, m, schema),
        from24To25: (m, schema) => migrateV24ToV25(this, m, schema),
        from25To26: (m, schema) => migrateV25ToV26(this, m, schema),
        from26To27: (m, schema) => migrateV26ToV27(this, m, schema),
        from27To28: (m, schema) => migrateV27ToV28(this, m, schema),
        from28To29: (m, schema) => migrateV28ToV29(this, m, schema),
        from29To30: (m, schema) => migrateV29ToV30(this, m, schema),
        from30To31: (m, schema) => migrateV30ToV31(this, m, schema),
        from31To32: (m, schema) => migrateV31ToV32(this, m, schema),
        from32To33: (m, schema) => migrateV32ToV33(this, m, schema),
      )(m, from, stepsTarget);
    }
  }
}
