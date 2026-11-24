-- Imágenes de avisos subidas desde la galería (público de lectura; solo administración sube).
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('express-announcements', 'express-announcements', true, 5242880,
        array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update set public = true, file_size_limit = 5242880,
  allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp'];

drop policy if exists announcement_images_admin_upload on storage.objects;
create policy announcement_images_admin_upload on storage.objects for insert to authenticated
  with check (bucket_id = 'express-announcements'
              and (public.is_admin() or public.admin_zone_role_now() = 'operator'));
