create or replace function public.public_queue_board()
returns table (
  doctor_id int,
  doctor_name text,
  specialization text,
  now_serving int,
  waiting_count bigint
)
language sql
stable
security definer
set search_path = public
as $$
  select
    d.doctor_id,
    d.name,
    d.specialization,
    (
      select q.queue_position
      from public.queue_entries q
      where q.doctor_id = d.doctor_id
        and q.queue_date = public.clinic_today()
        and q.status = 'in_consultation'
      order by q.queued_at nulls last, q.queue_id
      limit 1
    ) as now_serving,
    (
      select count(*)
      from public.queue_entries q
      where q.doctor_id = d.doctor_id
        and q.queue_date = public.clinic_today()
        and q.status = 'waiting'
    ) as waiting_count
  from public.doctors d
  order by d.name;
$$;

revoke all on function public.public_queue_board() from public;
grant execute on function public.public_queue_board() to anon, authenticated;
