create or replace function public.recalculate_queue(p_doctor_id int, p_date date) returns void language plpgsql security definer set search_path = public as $$
begin
  update public.queue_entries q set queue_position = null
   where q.doctor_id = p_doctor_id and q.queue_date = p_date and q.status not in ('waiting','in_consultation') and q.queue_position is not null;
  update public.queue_entries q set queue_position = r.rn
    from (select queue_id, row_number() over (order by case when status = 'in_consultation' then 0 else 1 end, queued_at, queue_id) rn from public.queue_entries
          where doctor_id = p_doctor_id and queue_date = p_date and status in ('waiting','in_consultation')) r
   where q.queue_id = r.queue_id and q.queue_position is distinct from r.rn;
end $$;

revoke all on function public.recalculate_queue(int, date) from public, anon, authenticated;

-- renumber today's queues so existing rows match the new rule
select public.recalculate_queue(doctor_id, queue_date) from (select distinct doctor_id, queue_date from public.queue_entries) s;