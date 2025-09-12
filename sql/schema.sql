-- schema.sql (PostgreSQL)
-- Family-Tenant Architecture™ minimal starter schema + RLS
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "citext";

CREATE TABLE tenants (
  tenant_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  plan TEXT NOT NULL DEFAULT 'free',
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE users (
  user_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  tenant_id UUID REFERENCES tenants(tenant_id) ON DELETE CASCADE,
  email CITEXT NOT NULL,
  display_name TEXT NOT NULL,
  role TEXT NOT NULL DEFAULT 'staff',
  UNIQUE (tenant_id, email)
);

CREATE TABLE properties (
  property_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  tenant_id UUID REFERENCES tenants(tenant_id) ON DELETE CASCADE,
  code TEXT NOT NULL,
  name TEXT NOT NULL,
  UNIQUE (tenant_id, code)
);

CREATE TABLE rooms (
  room_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  tenant_id UUID REFERENCES tenants(tenant_id) ON DELETE CASCADE,
  property_id UUID REFERENCES properties(property_id) ON DELETE CASCADE,
  room_no TEXT NOT NULL,
  room_type TEXT NOT NULL DEFAULT 'STD'
);

CREATE TABLE tasks (
  task_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  tenant_id UUID REFERENCES tenants(tenant_id) ON DELETE CASCADE,
  property_id UUID REFERENCES properties(property_id) ON DELETE CASCADE,
  room_id UUID REFERENCES rooms(room_id) ON DELETE SET NULL,
  type TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending',
  assignee_user_id UUID REFERENCES users(user_id) ON DELETE SET NULL,
  minutes_estimated INT DEFAULT 30,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- เปิด Row-Level Security
ALTER TABLE tenants ENABLE ROW LEVEL SECURITY;
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE properties ENABLE ROW LEVEL SECURITY;
ALTER TABLE rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;
