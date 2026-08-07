create table if not exists public.product_reviews (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete cascade,
  order_item_id uuid references public.order_items(id) on delete set null,
  rating integer not null check (rating between 1 and 5),
  title text,
  comment text,
  images jsonb not null default '[]'::jsonb check (jsonb_typeof(images) = 'array'),
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected', 'hidden')),
  verified_purchase boolean not null default false,
  helpful_count integer not null default 0 check (helpful_count >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint product_reviews_profile_id_product_id_unique unique (profile_id, product_id),
  constraint product_reviews_profile_id_order_item_id_unique unique (profile_id, order_item_id)
);

create table if not exists public.seller_reviews (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  seller_profile_id uuid not null references public.seller_profiles(id) on delete cascade,
  rating integer not null check (rating between 1 and 5),
  title text,
  comment text,
  verified_purchase boolean not null default false,
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected', 'hidden')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint seller_reviews_profile_id_seller_profile_id_unique unique (profile_id, seller_profile_id)
);

create table if not exists public.coupons (
  id uuid primary key default gen_random_uuid(),
  code text not null,
  name text not null,
  description text,
  discount_type text not null check (discount_type in ('percentage', 'fixed_amount')),
  discount_value numeric(12,2) not null check (discount_value > 0),
  minimum_order_amount numeric(12,2) not null default 0 check (minimum_order_amount >= 0),
  maximum_discount_amount numeric(12,2) check (maximum_discount_amount is null or maximum_discount_amount >= 0),
  usage_limit integer check (usage_limit is null or usage_limit >= 1),
  per_user_limit integer not null default 1 check (per_user_limit >= 1),
  used_count integer not null default 0 check (used_count >= 0),
  starts_at timestamptz,
  expires_at timestamptz,
  status text not null default 'draft' check (status in ('draft', 'active', 'paused', 'expired', 'archived')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint coupons_code_unique unique (code),
  constraint coupons_percentage_value_check check (
    discount_type <> 'percentage' or discount_value <= 100
  ),
  constraint coupons_date_range_check check (
    starts_at is null or expires_at is null or expires_at > starts_at
  ),
  constraint coupons_usage_count_check check (
    usage_limit is null or used_count <= usage_limit
  )
);

create table if not exists public.coupon_redemptions (
  id uuid primary key default gen_random_uuid(),
  coupon_id uuid not null references public.coupons(id) on delete restrict,
  profile_id uuid not null references public.profiles(id) on delete restrict,
  order_id uuid references public.orders(id) on delete set null,
  discount_amount numeric(12,2) not null check (discount_amount >= 0),
  currency text not null default 'PKR' check (currency in ('PKR', 'USD')),
  redeemed_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  constraint coupon_redemptions_coupon_id_order_id_unique unique (coupon_id, order_id)
);

create table if not exists public.notification_templates (
  id uuid primary key default gen_random_uuid(),
  key text not null,
  type text not null check (type in ('order_update', 'otp', 'promotion', 'seller_event', 'system')),
  title_template text not null,
  body_template text not null,
  data_schema jsonb not null default '{}'::jsonb check (jsonb_typeof(data_schema) = 'object'),
  status text not null default 'active' check (status in ('active', 'inactive', 'archived')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint notification_templates_key_unique unique (key)
);

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  template_id uuid references public.notification_templates(id) on delete set null,
  type text not null,
  title text not null,
  body text not null,
  data jsonb not null default '{}'::jsonb check (jsonb_typeof(data) = 'object'),
  read_at timestamptz,
  created_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table if not exists public.rfqs (
  id uuid primary key default gen_random_uuid(),
  buyer_profile_id uuid not null references public.profiles(id) on delete cascade,
  seller_profile_id uuid references public.seller_profiles(id) on delete set null,
  business_profile_id uuid references public.business_profiles(id) on delete set null,
  product_id uuid references public.products(id) on delete set null,
  product_variant_id uuid references public.product_variants(id) on delete set null,
  quantity integer not null check (quantity >= 1),
  target_price numeric(12,2) check (target_price is null or target_price >= 0),
  currency text not null default 'PKR' check (currency in ('PKR', 'USD')),
  message text,
  status text not null default 'open' check (status in ('open', 'quoted', 'accepted', 'rejected', 'expired', 'cancelled', 'closed')),
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table if not exists public.quotes (
  id uuid primary key default gen_random_uuid(),
  rfq_id uuid not null references public.rfqs(id) on delete cascade,
  seller_profile_id uuid not null references public.seller_profiles(id) on delete cascade,
  unit_price numeric(12,2) not null check (unit_price >= 0),
  total_price numeric(12,2) not null,
  currency text not null default 'PKR' check (currency in ('PKR', 'USD')),
  minimum_order_quantity integer not null default 1 check (minimum_order_quantity >= 1),
  lead_time_days integer check (lead_time_days is null or lead_time_days >= 0),
  status text not null default 'sent' check (status in ('draft', 'sent', 'accepted', 'rejected', 'expired', 'withdrawn')),
  valid_until timestamptz,
  message text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint quotes_rfq_id_seller_profile_id_unique unique (rfq_id, seller_profile_id),
  constraint quotes_total_price_check check (total_price >= unit_price * minimum_order_quantity)
);

create table if not exists public.conversations (
  id uuid primary key default gen_random_uuid(),
  subject text,
  conversation_type text not null default 'buyer_seller' check (conversation_type in ('buyer_seller', 'support', 'rfq', 'order')),
  order_id uuid references public.orders(id) on delete set null,
  rfq_id uuid references public.rfqs(id) on delete set null,
  last_message_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table if not exists public.conversation_participants (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  role text not null default 'member' check (role in ('member', 'buyer', 'seller', 'support', 'admin')),
  last_read_at timestamptz,
  joined_at timestamptz not null default now(),
  left_at timestamptz,
  created_at timestamptz not null default now(),
  constraint conversation_participants_conversation_id_profile_id_unique unique (conversation_id, profile_id)
);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  sender_profile_id uuid not null references public.profiles(id) on delete cascade,
  message_type text not null default 'text' check (message_type in ('text', 'image', 'file', 'system')),
  text text,
  attachment_path text,
  is_read boolean not null default false,
  created_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint messages_content_check check (
    text is not null or attachment_path is not null or message_type = 'system'
  )
);

create table if not exists public.support_tickets (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  order_id uuid references public.orders(id) on delete set null,
  subject text not null check (char_length(trim(subject)) >= 3),
  description text not null check (char_length(trim(description)) >= 10),
  category text not null default 'general' check (category in ('general', 'order', 'payment', 'shipping', 'return', 'product', 'seller', 'technical')),
  priority text not null default 'normal' check (priority in ('low', 'normal', 'high', 'urgent')),
  status text not null default 'open' check (status in ('open', 'pending', 'resolved', 'closed')),
  assigned_to uuid references public.profiles(id) on delete set null,
  closed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table if not exists public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  table_name text not null,
  record_id uuid,
  action text not null check (action in ('insert', 'update', 'delete', 'restore', 'login', 'logout', 'export', 'import')),
  performed_by uuid references public.profiles(id) on delete set null,
  old_values jsonb check (old_values is null or jsonb_typeof(old_values) = 'object'),
  new_values jsonb check (new_values is null or jsonb_typeof(new_values) = 'object'),
  ip_address inet,
  user_agent text,
  created_at timestamptz not null default now()
);

create or replace function public.is_conversation_participant(
  target_conversation_id uuid,
  target_profile_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.conversation_participants cp
    where cp.conversation_id = target_conversation_id
      and cp.profile_id = target_profile_id
      and cp.left_at is null
  );
$$;

comment on table public.product_reviews is 'Buyer reviews for marketplace products.';
comment on column public.product_reviews.id is 'Primary key for the product review.';
comment on column public.product_reviews.profile_id is 'Profile that wrote the review.';
comment on column public.product_reviews.product_id is 'Reviewed product.';
comment on column public.product_reviews.order_item_id is 'Order item proving purchase when available.';
comment on column public.product_reviews.rating is 'Rating from one to five.';
comment on column public.product_reviews.title is 'Optional review headline.';
comment on column public.product_reviews.comment is 'Optional detailed review text.';
comment on column public.product_reviews.images is 'JSON array of review image storage paths and metadata.';
comment on column public.product_reviews.status is 'Moderation status for the product review.';
comment on column public.product_reviews.verified_purchase is 'Whether the review is linked to a verified purchase.';
comment on column public.product_reviews.helpful_count is 'Cached count of helpful votes.';
comment on column public.product_reviews.created_at is 'Timestamp when the product review was created.';
comment on column public.product_reviews.updated_at is 'Timestamp when the product review was last updated.';
comment on column public.product_reviews.deleted_at is 'Soft delete timestamp. Null means active row.';

comment on table public.seller_reviews is 'Buyer reviews for seller storefronts.';
comment on column public.seller_reviews.id is 'Primary key for the seller review.';
comment on column public.seller_reviews.profile_id is 'Profile that wrote the seller review.';
comment on column public.seller_reviews.seller_profile_id is 'Seller profile being reviewed.';
comment on column public.seller_reviews.rating is 'Rating from one to five.';
comment on column public.seller_reviews.title is 'Optional review headline.';
comment on column public.seller_reviews.comment is 'Optional detailed review text.';
comment on column public.seller_reviews.verified_purchase is 'Whether the review is linked to a verified purchase.';
comment on column public.seller_reviews.status is 'Moderation status for the seller review.';
comment on column public.seller_reviews.created_at is 'Timestamp when the seller review was created.';
comment on column public.seller_reviews.updated_at is 'Timestamp when the seller review was last updated.';
comment on column public.seller_reviews.deleted_at is 'Soft delete timestamp. Null means active row.';

comment on table public.coupons is 'Marketplace coupon definitions for discounts and promotions.';
comment on column public.coupons.id is 'Primary key for the coupon.';
comment on column public.coupons.code is 'Unique redeemable coupon code.';
comment on column public.coupons.name is 'Internal or display coupon name.';
comment on column public.coupons.description is 'Optional coupon description.';
comment on column public.coupons.discount_type is 'Discount calculation type: percentage or fixed amount.';
comment on column public.coupons.discount_value is 'Percentage or fixed discount value.';
comment on column public.coupons.minimum_order_amount is 'Minimum order amount required for redemption.';
comment on column public.coupons.maximum_discount_amount is 'Maximum discount cap for percentage coupons.';
comment on column public.coupons.usage_limit is 'Optional total redemption limit.';
comment on column public.coupons.per_user_limit is 'Maximum redemptions allowed per profile.';
comment on column public.coupons.used_count is 'Cached total redemption count.';
comment on column public.coupons.starts_at is 'Optional coupon start time.';
comment on column public.coupons.expires_at is 'Optional coupon expiry time.';
comment on column public.coupons.status is 'Coupon lifecycle status.';
comment on column public.coupons.created_at is 'Timestamp when the coupon was created.';
comment on column public.coupons.updated_at is 'Timestamp when the coupon was last updated.';
comment on column public.coupons.deleted_at is 'Soft delete timestamp. Null means active row.';

comment on table public.coupon_redemptions is 'Immutable coupon redemption records for orders.';
comment on column public.coupon_redemptions.id is 'Primary key for the coupon redemption.';
comment on column public.coupon_redemptions.coupon_id is 'Coupon that was redeemed.';
comment on column public.coupon_redemptions.profile_id is 'Profile that redeemed the coupon.';
comment on column public.coupon_redemptions.order_id is 'Order that used the coupon when available.';
comment on column public.coupon_redemptions.discount_amount is 'Discount amount applied.';
comment on column public.coupon_redemptions.currency is 'Currency for the discount amount.';
comment on column public.coupon_redemptions.redeemed_at is 'Timestamp when the coupon was redeemed.';
comment on column public.coupon_redemptions.created_at is 'Timestamp when the redemption row was created.';

comment on table public.notification_templates is 'Reusable notification templates for order, OTP, promotion, seller, and system events.';
comment on column public.notification_templates.id is 'Primary key for the notification template.';
comment on column public.notification_templates.key is 'Unique system key for selecting the template.';
comment on column public.notification_templates.type is 'Template category.';
comment on column public.notification_templates.title_template is 'Title template with application-level interpolation.';
comment on column public.notification_templates.body_template is 'Body template with application-level interpolation.';
comment on column public.notification_templates.data_schema is 'Optional JSON schema metadata for expected notification data.';
comment on column public.notification_templates.status is 'Template lifecycle status.';
comment on column public.notification_templates.created_at is 'Timestamp when the template was created.';
comment on column public.notification_templates.updated_at is 'Timestamp when the template was last updated.';
comment on column public.notification_templates.deleted_at is 'Soft delete timestamp. Null means active row.';

comment on table public.notifications is 'Per-profile notification inbox.';
comment on column public.notifications.id is 'Primary key for the notification.';
comment on column public.notifications.profile_id is 'Profile receiving the notification.';
comment on column public.notifications.template_id is 'Template used to create this notification when available.';
comment on column public.notifications.type is 'Notification type or event key.';
comment on column public.notifications.title is 'Rendered notification title.';
comment on column public.notifications.body is 'Rendered notification body.';
comment on column public.notifications.data is 'Structured notification payload.';
comment on column public.notifications.read_at is 'Timestamp when the user read the notification.';
comment on column public.notifications.created_at is 'Timestamp when the notification was created.';
comment on column public.notifications.deleted_at is 'Soft delete timestamp. Null means active row.';

comment on table public.rfqs is 'Wholesale request-for-quotation records from buyers to sellers.';
comment on column public.rfqs.id is 'Primary key for the RFQ.';
comment on column public.rfqs.buyer_profile_id is 'Buyer profile that created the RFQ.';
comment on column public.rfqs.seller_profile_id is 'Target seller profile when the RFQ is seller-specific.';
comment on column public.rfqs.business_profile_id is 'Buyer business profile for B2B verification context.';
comment on column public.rfqs.product_id is 'Product requested when the RFQ is product-specific.';
comment on column public.rfqs.product_variant_id is 'Variant requested when the RFQ is SKU-specific.';
comment on column public.rfqs.quantity is 'Requested quantity.';
comment on column public.rfqs.target_price is 'Optional buyer target unit price.';
comment on column public.rfqs.currency is 'Currency for target and quote pricing.';
comment on column public.rfqs.message is 'Buyer message or requirements.';
comment on column public.rfqs.status is 'RFQ lifecycle status.';
comment on column public.rfqs.expires_at is 'Optional RFQ expiry time.';
comment on column public.rfqs.created_at is 'Timestamp when the RFQ was created.';
comment on column public.rfqs.updated_at is 'Timestamp when the RFQ was last updated.';
comment on column public.rfqs.deleted_at is 'Soft delete timestamp. Null means active row.';

comment on table public.quotes is 'Seller quotes responding to RFQs.';
comment on column public.quotes.id is 'Primary key for the quote.';
comment on column public.quotes.rfq_id is 'RFQ being quoted.';
comment on column public.quotes.seller_profile_id is 'Seller profile that sent the quote.';
comment on column public.quotes.unit_price is 'Quoted unit price.';
comment on column public.quotes.total_price is 'Quoted total price.';
comment on column public.quotes.currency is 'Currency for quote pricing.';
comment on column public.quotes.minimum_order_quantity is 'Minimum order quantity required by the seller.';
comment on column public.quotes.lead_time_days is 'Estimated lead time in days.';
comment on column public.quotes.status is 'Quote lifecycle status.';
comment on column public.quotes.valid_until is 'Timestamp until which the quote remains valid.';
comment on column public.quotes.message is 'Optional seller quote message.';
comment on column public.quotes.created_at is 'Timestamp when the quote was created.';
comment on column public.quotes.updated_at is 'Timestamp when the quote was last updated.';
comment on column public.quotes.deleted_at is 'Soft delete timestamp. Null means active row.';

comment on table public.conversations is 'Chat thread metadata for buyers, sellers, support, orders, and RFQs.';
comment on column public.conversations.id is 'Primary key for the conversation.';
comment on column public.conversations.subject is 'Optional conversation subject.';
comment on column public.conversations.conversation_type is 'Conversation category.';
comment on column public.conversations.order_id is 'Related order when applicable.';
comment on column public.conversations.rfq_id is 'Related RFQ when applicable.';
comment on column public.conversations.last_message_at is 'Timestamp of the latest message for sorting.';
comment on column public.conversations.created_at is 'Timestamp when the conversation was created.';
comment on column public.conversations.updated_at is 'Timestamp when the conversation was last updated.';
comment on column public.conversations.deleted_at is 'Soft delete timestamp. Null means active row.';

comment on table public.conversation_participants is 'Many-to-many membership between conversations and profiles.';
comment on column public.conversation_participants.id is 'Primary key for the participant row.';
comment on column public.conversation_participants.conversation_id is 'Conversation the profile participates in.';
comment on column public.conversation_participants.profile_id is 'Participant profile.';
comment on column public.conversation_participants.role is 'Participant role inside the conversation.';
comment on column public.conversation_participants.last_read_at is 'Timestamp through which the participant has read messages.';
comment on column public.conversation_participants.joined_at is 'Timestamp when the profile joined the conversation.';
comment on column public.conversation_participants.left_at is 'Timestamp when the profile left the conversation.';
comment on column public.conversation_participants.created_at is 'Timestamp when the participant row was created.';

comment on table public.messages is 'Messages sent inside conversations.';
comment on column public.messages.id is 'Primary key for the message.';
comment on column public.messages.conversation_id is 'Conversation that owns the message.';
comment on column public.messages.sender_profile_id is 'Profile that sent the message.';
comment on column public.messages.message_type is 'Message content type.';
comment on column public.messages.text is 'Text message body when applicable.';
comment on column public.messages.attachment_path is 'Storage object path for image or file attachments.';
comment on column public.messages.is_read is 'Legacy quick-read marker; per-participant read state is tracked separately.';
comment on column public.messages.created_at is 'Timestamp when the message was created.';
comment on column public.messages.deleted_at is 'Soft delete timestamp. Null means active row.';

comment on table public.support_tickets is 'Customer support tickets linked to profiles and optionally orders.';
comment on column public.support_tickets.id is 'Primary key for the support ticket.';
comment on column public.support_tickets.profile_id is 'Profile that opened the ticket.';
comment on column public.support_tickets.order_id is 'Related order when applicable.';
comment on column public.support_tickets.subject is 'Short support ticket subject.';
comment on column public.support_tickets.description is 'Detailed support request.';
comment on column public.support_tickets.category is 'Support ticket category.';
comment on column public.support_tickets.priority is 'Support ticket priority.';
comment on column public.support_tickets.status is 'Support ticket lifecycle status.';
comment on column public.support_tickets.assigned_to is 'Support or admin profile assigned to the ticket.';
comment on column public.support_tickets.closed_at is 'Timestamp when the ticket was closed.';
comment on column public.support_tickets.created_at is 'Timestamp when the ticket was created.';
comment on column public.support_tickets.updated_at is 'Timestamp when the ticket was last updated.';
comment on column public.support_tickets.deleted_at is 'Soft delete timestamp. Null means active row.';

comment on table public.audit_logs is 'Immutable audit trail for sensitive application and data changes.';
comment on column public.audit_logs.id is 'Primary key for the audit log entry.';
comment on column public.audit_logs.table_name is 'Table or subsystem affected by the action.';
comment on column public.audit_logs.record_id is 'Record identifier affected by the action when available.';
comment on column public.audit_logs.action is 'Action performed.';
comment on column public.audit_logs.performed_by is 'Profile that performed the action when available.';
comment on column public.audit_logs.old_values is 'Previous row values for update or delete audit events.';
comment on column public.audit_logs.new_values is 'New row values for insert or update audit events.';
comment on column public.audit_logs.ip_address is 'Client IP address captured by trusted application code.';
comment on column public.audit_logs.user_agent is 'Client user agent captured by trusted application code.';
comment on column public.audit_logs.created_at is 'Timestamp when the audit log entry was created.';

comment on function public.is_conversation_participant(uuid, uuid) is 'Safely checks active conversation membership for RLS policies without recursive policy evaluation.';

create index if not exists product_reviews_profile_id_idx on public.product_reviews (profile_id) where deleted_at is null;
create index if not exists product_reviews_product_id_status_idx on public.product_reviews (product_id, status) where deleted_at is null;
create index if not exists product_reviews_order_item_id_idx on public.product_reviews (order_item_id) where order_item_id is not null and deleted_at is null;
create index if not exists product_reviews_rating_idx on public.product_reviews (rating) where deleted_at is null;

create index if not exists seller_reviews_profile_id_idx on public.seller_reviews (profile_id) where deleted_at is null;
create index if not exists seller_reviews_seller_profile_id_status_idx on public.seller_reviews (seller_profile_id, status) where deleted_at is null;
create index if not exists seller_reviews_rating_idx on public.seller_reviews (rating) where deleted_at is null;

create index if not exists coupons_code_idx on public.coupons (upper(code)) where deleted_at is null;
create index if not exists coupons_status_expires_at_idx on public.coupons (status, expires_at) where deleted_at is null;

create index if not exists coupon_redemptions_coupon_id_idx on public.coupon_redemptions (coupon_id);
create index if not exists coupon_redemptions_profile_id_idx on public.coupon_redemptions (profile_id);
create index if not exists coupon_redemptions_profile_coupon_idx on public.coupon_redemptions (profile_id, coupon_id);
create index if not exists coupon_redemptions_order_id_idx on public.coupon_redemptions (order_id) where order_id is not null;

create index if not exists notification_templates_key_idx on public.notification_templates (key) where deleted_at is null;
create index if not exists notification_templates_type_status_idx on public.notification_templates (type, status) where deleted_at is null;

create index if not exists notifications_profile_id_created_at_idx on public.notifications (profile_id, created_at desc) where deleted_at is null;
create index if not exists notifications_profile_id_read_at_idx on public.notifications (profile_id, read_at) where deleted_at is null;
create index if not exists notifications_type_idx on public.notifications (type) where deleted_at is null;

create index if not exists rfqs_buyer_profile_id_idx on public.rfqs (buyer_profile_id) where deleted_at is null;
create index if not exists rfqs_seller_profile_id_idx on public.rfqs (seller_profile_id) where seller_profile_id is not null and deleted_at is null;
create index if not exists rfqs_business_profile_id_idx on public.rfqs (business_profile_id) where business_profile_id is not null and deleted_at is null;
create index if not exists rfqs_product_id_idx on public.rfqs (product_id) where product_id is not null and deleted_at is null;
create index if not exists rfqs_status_expires_at_idx on public.rfqs (status, expires_at) where deleted_at is null;

create index if not exists quotes_rfq_id_idx on public.quotes (rfq_id) where deleted_at is null;
create index if not exists quotes_seller_profile_id_idx on public.quotes (seller_profile_id) where deleted_at is null;
create index if not exists quotes_status_valid_until_idx on public.quotes (status, valid_until) where deleted_at is null;

create index if not exists conversations_type_last_message_idx on public.conversations (conversation_type, last_message_at desc) where deleted_at is null;
create index if not exists conversations_order_id_idx on public.conversations (order_id) where order_id is not null and deleted_at is null;
create index if not exists conversations_rfq_id_idx on public.conversations (rfq_id) where rfq_id is not null and deleted_at is null;

create index if not exists conversation_participants_conversation_id_idx on public.conversation_participants (conversation_id);
create index if not exists conversation_participants_profile_id_idx on public.conversation_participants (profile_id) where left_at is null;

create index if not exists messages_conversation_created_at_idx on public.messages (conversation_id, created_at desc) where deleted_at is null;
create index if not exists messages_sender_profile_id_idx on public.messages (sender_profile_id) where deleted_at is null;

create index if not exists support_tickets_profile_id_idx on public.support_tickets (profile_id) where deleted_at is null;
create index if not exists support_tickets_order_id_idx on public.support_tickets (order_id) where order_id is not null and deleted_at is null;
create index if not exists support_tickets_assigned_to_idx on public.support_tickets (assigned_to) where assigned_to is not null and deleted_at is null;
create index if not exists support_tickets_status_priority_idx on public.support_tickets (status, priority) where deleted_at is null;

create index if not exists audit_logs_table_record_idx on public.audit_logs (table_name, record_id);
create index if not exists audit_logs_performed_by_idx on public.audit_logs (performed_by) where performed_by is not null;
create index if not exists audit_logs_created_at_idx on public.audit_logs (created_at desc);

drop trigger if exists product_reviews_set_updated_at on public.product_reviews;
create trigger product_reviews_set_updated_at
before update on public.product_reviews
for each row execute function public.set_updated_at();

drop trigger if exists seller_reviews_set_updated_at on public.seller_reviews;
create trigger seller_reviews_set_updated_at
before update on public.seller_reviews
for each row execute function public.set_updated_at();

drop trigger if exists coupons_set_updated_at on public.coupons;
create trigger coupons_set_updated_at
before update on public.coupons
for each row execute function public.set_updated_at();

drop trigger if exists notification_templates_set_updated_at on public.notification_templates;
create trigger notification_templates_set_updated_at
before update on public.notification_templates
for each row execute function public.set_updated_at();

drop trigger if exists rfqs_set_updated_at on public.rfqs;
create trigger rfqs_set_updated_at
before update on public.rfqs
for each row execute function public.set_updated_at();

drop trigger if exists quotes_set_updated_at on public.quotes;
create trigger quotes_set_updated_at
before update on public.quotes
for each row execute function public.set_updated_at();

drop trigger if exists conversations_set_updated_at on public.conversations;
create trigger conversations_set_updated_at
before update on public.conversations
for each row execute function public.set_updated_at();

drop trigger if exists support_tickets_set_updated_at on public.support_tickets;
create trigger support_tickets_set_updated_at
before update on public.support_tickets
for each row execute function public.set_updated_at();

alter table public.product_reviews enable row level security;
alter table public.seller_reviews enable row level security;
alter table public.coupons enable row level security;
alter table public.coupon_redemptions enable row level security;
alter table public.notification_templates enable row level security;
alter table public.notifications enable row level security;
alter table public.rfqs enable row level security;
alter table public.quotes enable row level security;
alter table public.conversations enable row level security;
alter table public.conversation_participants enable row level security;
alter table public.messages enable row level security;
alter table public.support_tickets enable row level security;
alter table public.audit_logs enable row level security;

drop policy if exists product_reviews_public_select_approved on public.product_reviews;
create policy product_reviews_public_select_approved
on public.product_reviews
for select
to anon, authenticated
using (status = 'approved' and deleted_at is null);

drop policy if exists product_reviews_owner_all on public.product_reviews;
create policy product_reviews_owner_all
on public.product_reviews
for all
to authenticated
using (profile_id = public.current_profile_id() or public.has_role('admin'))
with check (profile_id = public.current_profile_id() or public.has_role('admin'));

drop policy if exists seller_reviews_public_select_approved on public.seller_reviews;
create policy seller_reviews_public_select_approved
on public.seller_reviews
for select
to anon, authenticated
using (status = 'approved' and deleted_at is null);

drop policy if exists seller_reviews_owner_all on public.seller_reviews;
create policy seller_reviews_owner_all
on public.seller_reviews
for all
to authenticated
using (profile_id = public.current_profile_id() or public.has_role('admin'))
with check (profile_id = public.current_profile_id() or public.has_role('admin'));

drop policy if exists coupons_public_select_active on public.coupons;
create policy coupons_public_select_active
on public.coupons
for select
to anon, authenticated
using (
  status = 'active'
  and deleted_at is null
  and (starts_at is null or starts_at <= now())
  and (expires_at is null or expires_at > now())
);

drop policy if exists coupons_admin_all on public.coupons;
create policy coupons_admin_all
on public.coupons
for all
to authenticated
using (public.has_role('admin'))
with check (public.has_role('admin'));

drop policy if exists coupon_redemptions_owner_select on public.coupon_redemptions;
create policy coupon_redemptions_owner_select
on public.coupon_redemptions
for select
to authenticated
using (profile_id = public.current_profile_id() or public.has_role('admin'));

drop policy if exists coupon_redemptions_owner_insert on public.coupon_redemptions;
create policy coupon_redemptions_owner_insert
on public.coupon_redemptions
for insert
to authenticated
with check (profile_id = public.current_profile_id() or public.has_role('admin'));

drop policy if exists coupon_redemptions_admin_update_delete on public.coupon_redemptions;
create policy coupon_redemptions_admin_update_delete
on public.coupon_redemptions
for all
to authenticated
using (public.has_role('admin'))
with check (public.has_role('admin'));

drop policy if exists notification_templates_admin_all on public.notification_templates;
create policy notification_templates_admin_all
on public.notification_templates
for all
to authenticated
using (public.has_role('admin'))
with check (public.has_role('admin'));

drop policy if exists notifications_owner_all on public.notifications;
create policy notifications_owner_all
on public.notifications
for all
to authenticated
using (profile_id = public.current_profile_id() or public.has_role('admin'))
with check (profile_id = public.current_profile_id() or public.has_role('admin'));

drop policy if exists rfqs_owner_and_seller_select on public.rfqs;
create policy rfqs_owner_and_seller_select
on public.rfqs
for select
to authenticated
using (
  public.has_role('admin')
  or buyer_profile_id = public.current_profile_id()
  or exists (
    select 1
    from public.seller_profiles sp
    where sp.id = rfqs.seller_profile_id
      and sp.profile_id = public.current_profile_id()
      and sp.deleted_at is null
  )
);

drop policy if exists rfqs_buyer_insert on public.rfqs;
create policy rfqs_buyer_insert
on public.rfqs
for insert
to authenticated
with check (buyer_profile_id = public.current_profile_id() or public.has_role('admin'));

drop policy if exists rfqs_buyer_update_delete on public.rfqs;
create policy rfqs_buyer_update_delete
on public.rfqs
for all
to authenticated
using (buyer_profile_id = public.current_profile_id() or public.has_role('admin'))
with check (buyer_profile_id = public.current_profile_id() or public.has_role('admin'));

drop policy if exists quotes_owner_select on public.quotes;
create policy quotes_owner_select
on public.quotes
for select
to authenticated
using (
  public.has_role('admin')
  or exists (
    select 1
    from public.rfqs r
    where r.id = quotes.rfq_id
      and r.buyer_profile_id = public.current_profile_id()
      and r.deleted_at is null
  )
  or exists (
    select 1
    from public.seller_profiles sp
    where sp.id = quotes.seller_profile_id
      and sp.profile_id = public.current_profile_id()
      and sp.deleted_at is null
  )
);

drop policy if exists quotes_seller_insert on public.quotes;
create policy quotes_seller_insert
on public.quotes
for insert
to authenticated
with check (
  public.has_role('admin')
  or exists (
    select 1
    from public.seller_profiles sp
    where sp.id = seller_profile_id
      and sp.profile_id = public.current_profile_id()
      and sp.deleted_at is null
  )
);

drop policy if exists quotes_seller_update_delete on public.quotes;
create policy quotes_seller_update_delete
on public.quotes
for all
to authenticated
using (
  public.has_role('admin')
  or exists (
    select 1
    from public.seller_profiles sp
    where sp.id = quotes.seller_profile_id
      and sp.profile_id = public.current_profile_id()
      and sp.deleted_at is null
  )
)
with check (
  public.has_role('admin')
  or exists (
    select 1
    from public.seller_profiles sp
    where sp.id = seller_profile_id
      and sp.profile_id = public.current_profile_id()
      and sp.deleted_at is null
  )
);

drop policy if exists conversations_participant_select on public.conversations;
create policy conversations_participant_select
on public.conversations
for select
to authenticated
using (
  public.has_role('admin')
  or public.is_conversation_participant(conversations.id, public.current_profile_id())
);

drop policy if exists conversations_admin_all on public.conversations;
create policy conversations_admin_all
on public.conversations
for all
to authenticated
using (public.has_role('admin'))
with check (public.has_role('admin'));

drop policy if exists conversation_participants_member_select on public.conversation_participants;
create policy conversation_participants_member_select
on public.conversation_participants
for select
to authenticated
using (
  public.has_role('admin')
  or profile_id = public.current_profile_id()
  or public.is_conversation_participant(conversation_participants.conversation_id, public.current_profile_id())
);

drop policy if exists conversation_participants_admin_all on public.conversation_participants;
create policy conversation_participants_admin_all
on public.conversation_participants
for all
to authenticated
using (public.has_role('admin'))
with check (public.has_role('admin'));

drop policy if exists messages_participant_select on public.messages;
create policy messages_participant_select
on public.messages
for select
to authenticated
using (
  public.has_role('admin')
  or public.is_conversation_participant(messages.conversation_id, public.current_profile_id())
);

drop policy if exists messages_participant_insert on public.messages;
create policy messages_participant_insert
on public.messages
for insert
to authenticated
with check (
  public.has_role('admin')
  or (
    sender_profile_id = public.current_profile_id()
    and public.is_conversation_participant(conversation_id, public.current_profile_id())
  )
);

drop policy if exists messages_admin_update_delete on public.messages;
create policy messages_admin_update_delete
on public.messages
for all
to authenticated
using (public.has_role('admin'))
with check (public.has_role('admin'));

drop policy if exists support_tickets_owner_select on public.support_tickets;
create policy support_tickets_owner_select
on public.support_tickets
for select
to authenticated
using (
  public.has_role('admin')
  or profile_id = public.current_profile_id()
  or assigned_to = public.current_profile_id()
);

drop policy if exists support_tickets_owner_insert on public.support_tickets;
create policy support_tickets_owner_insert
on public.support_tickets
for insert
to authenticated
with check (profile_id = public.current_profile_id() or public.has_role('admin'));

drop policy if exists support_tickets_owner_update on public.support_tickets;
create policy support_tickets_owner_update
on public.support_tickets
for update
to authenticated
using (
  public.has_role('admin')
  or profile_id = public.current_profile_id()
  or assigned_to = public.current_profile_id()
)
with check (
  public.has_role('admin')
  or profile_id = public.current_profile_id()
  or assigned_to = public.current_profile_id()
);

drop policy if exists support_tickets_admin_delete on public.support_tickets;
create policy support_tickets_admin_delete
on public.support_tickets
for delete
to authenticated
using (public.has_role('admin'));

drop policy if exists audit_logs_admin_select on public.audit_logs;
create policy audit_logs_admin_select
on public.audit_logs
for select
to authenticated
using (public.has_role('admin'));

drop policy if exists audit_logs_admin_insert on public.audit_logs;
create policy audit_logs_admin_insert
on public.audit_logs
for insert
to authenticated
with check (public.has_role('admin'));
