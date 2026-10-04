-- SchoolSphere: one account belongs to one school. Provision accounts with a service-role tool.
-- Never place a service-role key in the Flutter application.
create extension if not exists pgcrypto;
create table public.schools (id text primary key default gen_random_uuid()::text, name text not null);
create table public.school_members (
  user_id uuid primary key references auth.users(id) on delete cascade,
  school_id text not null references public.schools(id), name text not null,
  role text not null check (role in ('student','parent','teacher','principal','administrator')),
  classes text[] not null default '{}', children text[] not null default '{}'
);
create table public.school_records (
  id text primary key, school_id text not null references public.schools(id),
  kind text not null check (kind in ('settings','class','student','staff','attendance','staffAttendance','exam','attempt','mark','homework','submission','notice','fee','leave','book','borrow','transport','admission','resource','schedule','message','question')),
  class_id text, student_id text, owner_id text, data jsonb not null check (jsonb_typeof(data)='object'),
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create index record_scope on public.school_records(school_id,kind,class_id,student_id);
create unique index attendance_day on public.school_records(school_id,kind,student_id,(data->>'date')) where kind='attendance';
create unique index attempt_once on public.school_records(school_id,student_id,(data->>'exam')) where kind='attempt';
create unique index class_unique on public.school_records(school_id,class_id) where kind='class';
create unique index student_roll on public.school_records(school_id,class_id,(data->>'roll')) where kind='student';
create table public.exam_keys (
  exam_id text primary key references public.school_records(id) on delete cascade,
  school_id text not null references public.schools(id), answers jsonb not null
);
create table public.exam_results (
  attempt_id text primary key references public.school_records(id) on delete cascade,
  school_id text not null references public.schools(id), objective_score integer not null,
  score integer not null, maximum integer not null, written_scores jsonb not null default '{}',
  feedback text not null default '', published boolean not null default false
);
create table public.device_tokens (
  user_id uuid not null references public.school_members(user_id) on delete cascade,
  token text not null, primary key(user_id,token)
);
create table public.audit_events (
  id bigint generated always as identity primary key, school_id text not null,
  actor uuid, record_id text, action text not null, created_at timestamptz not null default now()
);

create function public.my_member() returns public.school_members language sql stable security definer set search_path=public
as $$ select * from public.school_members where user_id=auth.uid() $$;
create function public.manages_school() returns boolean language sql stable security definer set search_path=public
as $$ select coalesce((public.my_member()).role in ('principal','administrator'),false) $$;
create function public.teaches_class(c text) returns boolean language sql stable security definer set search_path=public
as $$ select public.manages_school() or ((public.my_member()).role='teacher' and c=any((public.my_member()).classes)) $$;
create function public.owns_student(s text) returns boolean language sql stable security definer set search_path=public
as $$ select ((public.my_member()).role='student' and s=auth.uid()::text) or ((public.my_member()).role='parent' and s=any((public.my_member()).children)) $$;
create function public.class_visible(c text) returns boolean language sql stable security definer set search_path=public
as $$ select c is null or public.teaches_class(c) or exists (
  select 1 from public.school_records r where r.kind='student' and r.school_id=(public.my_member()).school_id and r.class_id=c and public.owns_student(r.student_id)
) $$;
create function public.record_visible(r public.school_records) returns boolean language plpgsql stable security definer set search_path=public as $$
declare m public.school_members:=public.my_member();
begin
  if m.user_id is null or r.school_id<>m.school_id then return false; end if;
  if r.kind='message' then return r.data->'recipients' ? auth.uid()::text; end if;
  if r.kind='question' then return public.teaches_class(r.class_id); end if;
  if public.manages_school() then return true; end if;
  if r.kind in ('settings','book','staff') then return true; end if;
  if r.kind='admission' then return false; end if;
  if r.kind='staffAttendance' then return r.owner_id=auth.uid()::text; end if;
  if m.role='teacher' then
    if r.kind='leave' then return r.owner_id=auth.uid()::text; end if;
    if r.kind in ('fee','borrow') then return false; end if;
    return r.class_id is null or public.teaches_class(r.class_id);
  end if;
  if r.kind='student' then return public.owns_student(r.student_id); end if;
  if r.kind in ('attendance','attempt','submission','fee','borrow','leave') then return public.owns_student(r.student_id); end if;
  if r.kind='mark' then return public.owns_student(r.student_id) and coalesce((r.data->>'published')::boolean,false); end if;
  if r.kind='exam' and not coalesce((r.data->>'published')::boolean,false) then return false; end if;
  return public.class_visible(r.class_id);
end $$;

alter table public.schools enable row level security;
alter table public.school_members enable row level security;
alter table public.school_records enable row level security;
alter table public.exam_keys enable row level security;
alter table public.exam_results enable row level security;
alter table public.device_tokens enable row level security;
alter table public.audit_events enable row level security;
create policy school_read on public.schools for select to authenticated using(id=(public.my_member()).school_id);
create policy profile_read on public.school_members for select to authenticated using(user_id=auth.uid());
create policy records_read on public.school_records for select to authenticated using(public.record_visible(school_records));
-- Triggers below further validate payloads and permitted transitions.
create function public.record_writable(r public.school_records) returns boolean language plpgsql stable security definer set search_path=public as $$
declare m public.school_members:=public.my_member();
begin
  if m.user_id is null or r.school_id<>m.school_id or r.kind in ('attempt','exam','borrow') then return false; end if;
  if r.kind='message' then return r.owner_id=auth.uid()::text; end if;
  if public.manages_school() then return true; end if;
  if r.kind='staffAttendance' then return m.role='teacher' and r.owner_id=auth.uid()::text; end if;
  if m.role='teacher' and r.kind in ('attendance','mark','homework','notice','resource','submission','question') then return public.teaches_class(r.class_id); end if;
  if r.kind='submission' then return m.role='student' and r.student_id=auth.uid()::text and public.class_visible(r.class_id); end if;
  if r.kind='leave' then return r.owner_id=auth.uid()::text and (m.role='teacher' or (m.role='parent' and public.owns_student(r.student_id))); end if;
  return false;
end $$;
create policy records_insert on public.school_records for insert to authenticated with check(public.record_writable(school_records));
create policy records_update on public.school_records for update to authenticated using(public.record_writable(school_records)) with check(public.record_writable(school_records));
create policy results_read on public.exam_results for select to authenticated using (
  school_id=(public.my_member()).school_id and exists(select 1 from public.school_records a where a.id=attempt_id and (public.teaches_class(a.class_id) or (published and public.owns_student(a.student_id))))
);
create policy tokens_read on public.device_tokens for select to authenticated using(user_id=auth.uid());
create policy tokens_insert on public.device_tokens for insert to authenticated with check(user_id=auth.uid());
create policy tokens_delete on public.device_tokens for delete to authenticated using(user_id=auth.uid());
create policy tokens_update on public.device_tokens for update to authenticated using(user_id=auth.uid()) with check(user_id=auth.uid());
create policy audit_read on public.audit_events for select to authenticated using(school_id=(public.my_member()).school_id and public.manages_school());

create function public.contact_directory() returns jsonb language sql stable security definer set search_path=public as $$
select coalesce(jsonb_agg(jsonb_build_object('id',u.user_id,'name',u.name,'role',u.role)),'[]'::jsonb)
from public.school_members u where u.school_id=(public.my_member()).school_id and u.user_id<>auth.uid() and (
  public.manages_school() or (public.my_member()).role='teacher' and (
    u.role in ('principal','administrator') or u.classes && (public.my_member()).classes or exists (
      select 1 from public.school_records s where s.kind='student' and s.school_id=u.school_id and s.student_id=any(u.children) and public.teaches_class(s.class_id)
    )
  ) or u.role in ('principal','administrator') or u.role='teacher' and exists (
    select 1 from public.school_records s where s.kind='student' and s.school_id=u.school_id and public.owns_student(s.student_id) and s.class_id=any(u.classes)
  )
) $$;

create function public.validate_school_record() returns trigger language plpgsql security definer set search_path=public as $$
declare m public.school_members:=public.my_member(); related public.school_records; recipient text;
begin
  if tg_op='UPDATE' and (new.school_id,new.kind,new.class_id,new.student_id) is distinct from (old.school_id,old.kind,old.class_id,old.student_id) then raise exception 'Record scope cannot change'; end if;
  if current_setting('schoolsphere.internal',true)='yes' then new.updated_at=now(); return new; end if;
  if auth.uid() is null then new.updated_at=now(); return new; end if;
  if new.school_id<>m.school_id then raise exception 'School access denied'; end if;
  if new.kind in ('exam','attempt','borrow') then raise exception 'Use the authorized workflow'; end if;
  if new.class_id is not null and new.kind<>'class' and not exists(select 1 from public.school_records c where c.kind='class' and c.school_id=new.school_id and c.class_id=new.class_id) then raise exception 'Unknown class'; end if;
  if new.kind='attendance' then
    if new.data->>'status' not in ('Present','Absent','Late','Excused') or (new.data->>'date')::date>current_date then raise exception 'Invalid attendance'; end if;
    if not exists(select 1 from public.school_records s where s.kind='student' and s.student_id=new.student_id and s.class_id=new.class_id and s.school_id=new.school_id) then raise exception 'Student is not in this class'; end if;
  end if;
  if new.kind='mark' then
    if (new.data->>'max')::numeric<=0 or (new.data->>'score')::numeric<0 or (new.data->>'score')::numeric>(new.data->>'max')::numeric then raise exception 'Invalid marks'; end if;
  end if;
  if new.kind='fee' then
    if (new.data->>'amount')::numeric<=0 or (new.data->>'paid')::numeric<0 or (new.data->>'paid')::numeric>(new.data->>'amount')::numeric then raise exception 'Invalid fee balance'; end if;
  end if;
  if new.kind='staffAttendance' and not public.manages_school() then
    if tg_op='INSERT' then new.data=new.data||jsonb_build_object('in',now(),'date',current_date);new.data=new.data-'out';
    else
      if old.data ? 'out' or (new.data-'out')<>(old.data-'out') then raise exception 'Attendance cannot be rewritten'; end if;
      new.data=new.data||jsonb_build_object('out',now());
    end if;
  end if;
  if new.kind='leave' then
    if (new.data->>'to')::date<(new.data->>'from')::date then raise exception 'Invalid leave range'; end if;
    if tg_op='INSERT' and new.data->>'status'<>'Pending' then raise exception 'Leave must start pending'; end if;
    if tg_op='UPDATE' then
      if not public.manages_school() or old.data->>'status'<>'Pending' or old.owner_id=auth.uid()::text then raise exception 'Approval denied'; end if;
      if new.data->>'status' not in ('Approved','Declined') or (new.data-'status'-'reviewer')<>(old.data-'status'-'reviewer') then raise exception 'Only the decision can change'; end if;
      new.data=new.data||jsonb_build_object('reviewer',m.name);
    end if;
  end if;
  if new.kind='submission' then
    select * into related from public.school_records where id=new.data->>'homework' and kind='homework' and school_id=new.school_id;
    if related.id is null or related.class_id<>new.class_id then raise exception 'Assignment unavailable'; end if;
    if m.role='student' then
      if tg_op='UPDATE' and old.data ? 'score' then raise exception 'Reviewed work is locked'; end if;
      if new.data ? 'score' or new.data ? 'feedback' or new.data ? 'max' then raise exception 'Students cannot grade work'; end if;
      new.data=new.data||jsonb_build_object('sent',now(),'status',case when current_date>(related.data->>'due')::date then 'Submitted late' else 'Submitted' end);
    else
      if tg_op<>'UPDATE' or not public.teaches_class(new.class_id) or (new.data-'score'-'max'-'feedback'-'status')<>(old.data-'score'-'max'-'feedback'-'status') then raise exception 'Only review fields may change'; end if;
      if (new.data->>'score')::numeric<0 or (new.data->>'score')::numeric>(related.data->>'points')::numeric then raise exception 'Invalid homework marks'; end if;
      new.data=new.data||jsonb_build_object('max',related.data->'points','status','Reviewed');
    end if;
  end if;
  if new.kind='message' then
    if tg_op='UPDATE' or jsonb_array_length(new.data->'recipients')<>2 or not (new.data->'recipients' ? auth.uid()::text) then raise exception 'Invalid conversation'; end if;
    select value into recipient from jsonb_array_elements_text(new.data->'recipients') where value<>auth.uid()::text;
    if not exists(select 1 from jsonb_array_elements(public.contact_directory()) c where c->>'id'=recipient) then raise exception 'Recipient is not an authorized contact'; end if;
    new.data=new.data||jsonb_build_object('sender',m.name,'sent',now());
  end if;
  new.updated_at=now(); return new;
end $$;
create trigger validate_record before insert or update on public.school_records for each row execute function public.validate_school_record();
create function public.audit_record() returns trigger language plpgsql security definer set search_path=public as $$
begin insert into public.audit_events(school_id,actor,record_id,action) values(new.school_id,auth.uid(),new.id,tg_op||':'||new.kind); return new; end $$;
create trigger audit_record after insert or update on public.school_records for each row execute function public.audit_record();

create function public.sync_staff_assignment() returns trigger language plpgsql security definer set search_path=public as $$
begin
  if new.kind='staff' and new.data ? 'classes' and (auth.uid() is null or public.manages_school()) then
    if exists(select 1 from jsonb_array_elements_text(new.data->'classes') c where not exists(select 1 from public.school_records r where r.kind='class' and r.school_id=new.school_id and r.class_id=c)) then raise exception 'Unknown assigned class'; end if;
    update public.school_members set classes=array(select jsonb_array_elements_text(new.data->'classes')) where user_id::text=new.id and school_id=new.school_id and role='teacher';
  end if;
  return new;
end $$;
create trigger sync_staff after insert or update on public.school_records for each row execute function public.sync_staff_assignment();

-- Results and answer keys are separate from student-readable attempt payloads.
create function public.record_json(r public.school_records) returns jsonb language plpgsql stable security definer set search_path=public as $$
declare result public.exam_results; payload jsonb:=r.data;
begin
  if not public.record_visible(r) then raise exception 'Access denied'; end if;
  if r.kind='attempt' then
    select * into result from public.exam_results where attempt_id=r.id;
    if result.attempt_id is not null and (result.published or public.teaches_class(r.class_id)) then
      payload=payload||jsonb_build_object('score',result.score,'max',result.maximum,'writtenScores',result.written_scores,'feedback',result.feedback,'published',result.published);
    end if;
  end if;
  return to_jsonb(r)||jsonb_build_object('data',payload);
end $$;
create function public.load_school_records() returns jsonb language sql stable security definer set search_path=public as $$
  select coalesce(jsonb_agg(public.record_json(r) order by r.created_at),'[]'::jsonb) from public.school_records r where public.record_visible(r)
$$;

create function public.create_exam(exam_record jsonb,answer_keys jsonb,save_bank boolean default false) returns void language plpgsql security definer set search_path=public as $$
declare m public.school_members:=public.my_member(); q jsonb; seen text[]:='{}'; points integer; minutes integer; answer integer;
begin
  if m.user_id is null or exam_record->>'school_id'<>m.school_id or not public.teaches_class(exam_record->>'class_id') then raise exception 'Not permitted'; end if;
  minutes=(exam_record->'data'->>'minutes')::integer;
  if minutes<1 or minutes>180 or length(trim(exam_record->'data'->>'title'))=0 or jsonb_array_length(exam_record->'data'->'questions') not between 1 and 30 then raise exception 'Invalid assessment'; end if;
  if exam_record->>'kind'<>'exam' or exam_record->>'owner_id'<>auth.uid()::text then raise exception 'Invalid exam owner'; end if;
  for q in select value from jsonb_array_elements(exam_record->'data'->'questions') loop
    points=(q->>'points')::integer;
    if q->>'id'=any(seen) or q->>'id' is null or length(trim(q->>'prompt'))=0 or points<1 or points>100 then raise exception 'Invalid question'; end if;
    seen=array_append(seen,q->>'id');
    if q->>'type'='mcq' then
      answer=(answer_keys->>(q->>'id'))::integer;
      if answer is null or answer<0 or answer>=jsonb_array_length(q->'options') or jsonb_array_length(q->'options') not between 2 and 6 then raise exception 'Invalid answer key'; end if;
    elsif q->>'type'<>'written' then raise exception 'Invalid question type'; end if;
    if q ? 'correct' or q ? 'answer' then raise exception 'Keep answer keys separate'; end if;
  end loop;
  perform set_config('schoolsphere.internal','yes',true);
  insert into public.school_records(id,school_id,kind,class_id,owner_id,data) values(exam_record->>'id',m.school_id,'exam',exam_record->>'class_id',auth.uid()::text,exam_record->'data');
  insert into public.exam_keys(exam_id,school_id,answers) values(exam_record->>'id',m.school_id,answer_keys);
  if save_bank then
    for q in select value from jsonb_array_elements(exam_record->'data'->'questions') loop
      insert into public.school_records(id,school_id,kind,class_id,owner_id,data) values(
        'bank-'||(exam_record->>'id')||'-'||(q->>'id'),m.school_id,'question',exam_record->>'class_id',auth.uid()::text,
        q||jsonb_build_object('subject',exam_record->'data'->>'subject','correct',answer_keys->(q->>'id')));
    end loop;
  end if;
  perform set_config('schoolsphere.internal','no',true);
end $$;

create function public.exam_action(action_name text,exam_id text,submitted_answers jsonb default '{}') returns jsonb language plpgsql security definer set search_path=public as $$
declare m public.school_members:=public.my_member(); e public.school_records; a public.school_records; keys jsonb; answers jsonb; q jsonb; maximum integer:=0; score integer:=0; written jsonb:='{}'; aid text; expired boolean;
begin
  if m.role<>'student' or m.user_id is null then raise exception 'Student access required'; end if;
  select * into e from public.school_records where id=exam_id and kind='exam' and school_id=m.school_id for update;
  if e.id is null or not public.class_visible(e.class_id) or not coalesce((e.data->>'published')::boolean,false) then raise exception 'Test unavailable'; end if;
  aid='attempt-'||exam_id||'-'||auth.uid()::text;
  select * into a from public.school_records where id=aid for update;
  perform set_config('schoolsphere.internal','yes',true);
  if action_name='start' and a.id is null then
    insert into public.school_records(id,school_id,kind,class_id,student_id,owner_id,data) values(aid,m.school_id,'attempt',e.class_id,auth.uid()::text,auth.uid()::text,
      jsonb_build_object('exam',e.id,'title',e.data->>'title','subject',e.data->>'subject','status','In progress','started',now(),'deadline',now()+make_interval(mins=>(e.data->>'minutes')::integer),'answers','{}'::jsonb,'published',false)) returning * into a;
  elsif action_name in ('save','submit') then
    if a.id is null then raise exception 'Begin the test first'; end if;
    if a.data->>'status'='In progress' then
      expired=now()>=(a.data->>'deadline')::timestamptz;
      answers=case when expired then a.data->'answers' else submitted_answers end;
      if jsonb_typeof(answers)<>'object' then raise exception 'Answers must be an object'; end if;
      if action_name='save' and not expired then
        update public.school_records set data=data||jsonb_build_object('answers',answers) where id=aid returning * into a;
      else
        select k.answers into keys from public.exam_keys k where k.exam_id=e.id;
        for q in select value from jsonb_array_elements(e.data->'questions') loop
          maximum=maximum+(q->>'points')::integer;
          if q->>'type'='written' then written=written||jsonb_build_object(q->>'id',null);
          elsif answers->(q->>'id')=keys->(q->>'id') then score=score+(q->>'points')::integer; end if;
        end loop;
        insert into public.exam_results(attempt_id,school_id,objective_score,score,maximum,written_scores) values(aid,m.school_id,score,score,maximum,written);
        update public.school_records set data=data||jsonb_build_object('answers',answers,'submitted',now(),'status',case when written='{}'::jsonb then 'Graded' else 'Awaiting review' end) where id=aid returning * into a;
      end if;
    end if;
  elsif action_name<>'start' then raise exception 'Unknown test action'; end if;
  perform set_config('schoolsphere.internal','no',true);
  return public.record_json(a);
end $$;

create function public.review_attempt(attempt_id text,written_marks jsonb,teacher_feedback text,publish_result boolean) returns jsonb language plpgsql security definer set search_path=public as $$
declare a public.school_records; e public.school_records; result public.exam_results; q jsonb; score integer; total integer:=0;
begin
  select * into a from public.school_records where id=attempt_id and kind='attempt' and school_id=(public.my_member()).school_id for update;
  if a.id is null or not public.teaches_class(a.class_id) or a.data->>'status'='In progress' then raise exception 'Review not permitted'; end if;
  select * into e from public.school_records where id=a.data->>'exam';
  select * into result from public.exam_results where exam_results.attempt_id=a.id for update;
  for q in select value from jsonb_array_elements(e.data->'questions') where value->>'type'='written' loop
    if jsonb_typeof(written_marks->(q->>'id'))<>'number' then raise exception 'Every written answer needs a mark'; end if;
    score=(written_marks->>(q->>'id'))::integer;
    if (written_marks->>(q->>'id'))::numeric<>score or score<0 or score>(q->>'points')::integer then raise exception 'Mark exceeds question maximum'; end if;
    total=total+score;
  end loop;
  update public.exam_results set score=objective_score+total,written_scores=written_marks,feedback=teacher_feedback,published=publish_result where exam_results.attempt_id=a.id;
  perform set_config('schoolsphere.internal','yes',true);
  update public.school_records set data=data||jsonb_build_object('status','Graded','published',publish_result) where id=a.id returning * into a;
  perform set_config('schoolsphere.internal','no',true);
  return public.record_json(a);
end $$;

create function public.borrow_book(book_id text) returns jsonb language plpgsql security definer set search_path=public as $$
declare m public.school_members:=public.my_member(); b public.school_records; a public.school_records; group_id text; count integer;
begin
  if m.role<>'student' or m.user_id is null then raise exception 'Student access required'; end if;
  select * into b from public.school_records where id=book_id and kind='book' and school_id=m.school_id for update;
  if b.id is null then raise exception 'Book unavailable'; end if;
  if exists(select 1 from public.school_records l where l.kind='borrow' and l.school_id=m.school_id and l.student_id=auth.uid()::text and l.data->>'book'=book_id and l.data->>'status'='Borrowed') then raise exception 'You already have this book'; end if;
  select count(*) into count from public.school_records l where l.kind='borrow' and l.school_id=m.school_id and l.data->>'book'=book_id and l.data->>'status'='Borrowed';
  if count>=(b.data->>'copies')::integer then raise exception 'All copies are on loan'; end if;
  select class_id into group_id from public.school_records s where s.kind='student' and s.school_id=m.school_id and s.student_id=auth.uid()::text;
  perform set_config('schoolsphere.internal','yes',true);
  insert into public.school_records(id,school_id,kind,class_id,student_id,owner_id,data) values(gen_random_uuid()::text,m.school_id,'borrow',group_id,auth.uid()::text,auth.uid()::text,jsonb_build_object('book',b.id,'title',b.data->>'title','status','Borrowed','due',current_date+14)) returning * into a;
  perform set_config('schoolsphere.internal','no',true);return public.record_json(a);
end $$;
create function public.return_book(loan_id text) returns jsonb language plpgsql security definer set search_path=public as $$
declare a public.school_records;
begin
  select * into a from public.school_records where id=loan_id and kind='borrow' and school_id=(public.my_member()).school_id for update;
  if a.id is null or not (public.manages_school() or ((public.my_member()).role='student' and a.student_id=auth.uid()::text)) then raise exception 'Return not permitted'; end if;
  perform set_config('schoolsphere.internal','yes',true);
  update public.school_records set data=data||jsonb_build_object('status','Returned','returned',current_date) where id=a.id returning * into a;
  perform set_config('schoolsphere.internal','no',true);return public.record_json(a);
end $$;

-- Private resource files; each object belongs to a school and an authenticated owner.
insert into storage.buckets(id,name,public) values('school-files','school-files',false) on conflict(id) do nothing;
create policy school_file_read on storage.objects for select to authenticated using(bucket_id='school-files' and (storage.foldername(name))[1]=(public.my_member()).school_id and (owner_id=auth.uid()::text or public.manages_school()));
create policy school_file_insert on storage.objects for insert to authenticated with check(bucket_id='school-files' and (storage.foldername(name))[1]=(public.my_member()).school_id and (storage.foldername(name))[2]=auth.uid()::text);

revoke all on public.exam_keys from anon,authenticated;
revoke all on public.exam_results from anon,authenticated;
grant select on public.exam_results to authenticated;
revoke all on public.school_members from anon,authenticated;
grant select on public.school_members to authenticated;
revoke all on public.school_records from anon,authenticated;
grant select,insert,update on public.school_records to authenticated;
revoke all on public.audit_events from anon,authenticated;
grant select on public.audit_events to authenticated;
revoke execute on all functions in schema public from public,anon;
grant execute on function public.my_member(), public.manages_school(), public.teaches_class(text), public.owns_student(text), public.class_visible(text), public.record_visible(public.school_records), public.record_writable(public.school_records), public.load_school_records(), public.contact_directory(), public.create_exam(jsonb,jsonb,boolean), public.exam_action(text,text,jsonb), public.review_attempt(text,jsonb,text,boolean), public.borrow_book(text), public.return_book(text) to authenticated;
