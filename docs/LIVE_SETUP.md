# Live school setup

The local demonstration is ready without accounts or keys. This guide connects the code to an independently provisioned school backend. Never place a Supabase service-role key or Firebase service-account private key in the Flutter application.

## Supabase

1. Create a Supabase project and apply `supabase/migrations/001_school.sql` using the SQL editor or Supabase CLI migrations.
2. Create email/password accounts through trusted server-side provisioning or the Supabase dashboard. Disable open registration for this school application.
3. Insert a row into `schools`. Insert each account into `school_members` using its actual Auth user UUID, the school id, name, role, assigned class codes and linked child UUIDs. Users cannot change these permissions themselves.
4. Create a `settings` record and `class` records for the school. A leadership account can subsequently maintain directories, classes, timetables, fees and other content from the application.
5. A live student's roster record **must use the Auth user UUID as both its record id and student_id**. Parent membership `children` contains those UUIDs. Use trusted provisioning for login-linked student records; the phone's Add student and admissions actions create roster entries only and do not create Auth accounts. The examples below show this contract.
6. A login-linked teacher's staff record uses their Auth UUID as its id. Updating that record's assigned classes through leadership also updates their membership permissions. Refresh or sign in again for the app to fetch the updated profile.
7. Run with public backend configuration:

```sh
flutter run --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLIC_PUBLISHABLE_KEY
```

The name `SUPABASE_ANON_KEY` is retained as the build configuration name; the value can be the project's public publishable key. Supply both values together. The app should never contain a service-role key.

A provisioning example, replacing every placeholder:

```sql
insert into schools(id,name) values('YOUR_SCHOOL_ID','Your School');
insert into school_members(user_id,school_id,name,role,classes,children)
values('ACTUAL_AUTH_UUID','YOUR_SCHOOL_ID','School Principal','principal','{}','{}');
insert into school_records(id,school_id,kind,data)
values('YOUR_SCHOOL_ID-settings','YOUR_SCHOOL_ID','settings',
  '{"name":"Your School","city":"Ahmedabad","year":"2026–27","term":"Term 1"}');
-- Create the class first (through the app or trusted SQL).
insert into school_records(id,school_id,kind,class_id,student_id,data)
values('STUDENT_AUTH_UUID','YOUR_SCHOOL_ID','student','10-A','STUDENT_AUTH_UUID',
  '{"name":"Student Name","roll":"01","parent":"Guardian Name"}');
```

Profiles are intentionally service-provisioned. There is no public role signup or role selection in live mode. The app supports one school membership per account.

## Database behaviour

- Tenant and role permissions are enforced by row policies and validation triggers.
- Parent permissions follow explicitly linked children.
- Teacher permissions follow assigned classes.
- Exam answer keys and question-bank answers are not readable by students/parents.
- Objective marks are calculated server-side. Unpublished exam results are stored separately and omitted from student/parent queries.
- Test deadlines and one-attempt constraints are authoritative on the server.
- Staff check-in times are server-generated.
- Library borrowing uses a locked catalog row to prevent oversubscribing copies.
- Leave decisions cannot be made by the requesting user.
- Mutations create audit records.
- Uploaded object storage is private; basic owner/leadership storage policies are included. The app currently uses text submissions and resource links, not file upload screens.

Live records refresh on pull-to-refresh. Background realtime subscriptions and live offline reconciliation are not implemented. The locally persistent demonstration is separate from live storage.

## Firebase notifications

1. Register Android package `com.ingrowwth.schoolsphere` and the equivalent iOS bundle in Firebase.
2. Use FlutterFire configuration to supply platform settings. Add the required Android Google Services configuration/plugin and iOS GoogleService-Info plist and capabilities. For iOS, configure the APNs key in Firebase.
3. Deploy `supabase/functions/send-notification` and supply `FCM_SERVICE_ACCOUNT_JSON` as a **server secret**. Keep Supabase's server secrets on the server.
4. Build with `--dart-define=ENABLE_PUSH=true` in addition to the Supabase values.
5. Sign in on a physical phone and use School & account → Enable notifications. This registers the phone's current token. Token registration should be refreshed when device tokens change; full token-refresh and notification deep-link lifecycle work is a remaining production integration task.
6. Test attendance, published marks and announcements using authorized staff accounts. The server derives recipients from school membership. Lock-screen notifications contain general prompts rather than marks or other personal school information.

The push integration has not been deployed or tested against Firebase here. A failed push does not undo a successful record save. For production, add delivery retry/idempotency, token lifecycle cleanup, monitoring and rate limits appropriate to the school.

## Publishing

The supplied APK uses development signing for review. Configure a private release keystore, signing properties and Play Console details before store distribution. An iOS archive requires Xcode, provisioning profiles and an Apple developer account. Online payments, SMS, live GPS and biometric attendance require separate integrations.
