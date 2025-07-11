// dart format width=80
// GENERATED CODE, DO NOT EDIT BY HAND.
// ignore_for_file: type=lint
import 'package:drift/drift.dart';
import 'package:drift/internal/migrations.dart';
import 'schema_v1.dart' as v1;
import 'schema_v2.dart' as v2;
import 'schema_v3.dart' as v3;
import 'schema_v4.dart' as v4;
import 'schema_v5.dart' as v5;
import 'schema_v6.dart' as v6;
import 'schema_v7.dart' as v7;
import 'schema_v8.dart' as v8;
import 'schema_v9.dart' as v9;
import 'schema_v10.dart' as v10;
import 'schema_v11.dart' as v11;
import 'schema_v12.dart' as v12;
import 'schema_v13.dart' as v13;
import 'schema_v14.dart' as v14;
import 'schema_v15.dart' as v15;
import 'schema_v16.dart' as v16;
import 'schema_v17.dart' as v17;
import 'schema_v18.dart' as v18;
import 'schema_v19.dart' as v19;
import 'schema_v20.dart' as v20;
import 'schema_v21.dart' as v21;

class GeneratedHelper implements SchemaInstantiationHelper {
  @override
  GeneratedDatabase databaseForVersion(QueryExecutor db, int version) {
    switch (version) {
      case 1:
        return v1.DatabaseAtV1(db);
      case 2:
        return v2.DatabaseAtV2(db);
      case 3:
        return v3.DatabaseAtV3(db);
      case 4:
        return v4.DatabaseAtV4(db);
      case 5:
        return v5.DatabaseAtV5(db);
      case 6:
        return v6.DatabaseAtV6(db);
      case 7:
        return v7.DatabaseAtV7(db);
      case 8:
        return v8.DatabaseAtV8(db);
      case 9:
        return v9.DatabaseAtV9(db);
      case 10:
        return v10.DatabaseAtV10(db);
      case 11:
        return v11.DatabaseAtV11(db);
      case 12:
        return v12.DatabaseAtV12(db);
      case 13:
        return v13.DatabaseAtV13(db);
      case 14:
        return v14.DatabaseAtV14(db);
      case 15:
        return v15.DatabaseAtV15(db);
      case 16:
        return v16.DatabaseAtV16(db);
      case 17:
        return v17.DatabaseAtV17(db);
      case 18:
        return v18.DatabaseAtV18(db);
      case 19:
        return v19.DatabaseAtV19(db);
      case 20:
        return v20.DatabaseAtV20(db);
      case 21:
        return v21.DatabaseAtV21(db);
      default:
        throw MissingSchemaException(version, versions);
    }
  }

  static const versions = const [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21];
}
