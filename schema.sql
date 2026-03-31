-- ============================================================
-- TQS RFC MANAGER — Schema Supabase v1.0
-- Proyecto: zhfmhaqwmkooxxufnncp (tqs-rfc-manager)
-- Region: West US (North California)
-- ============================================================

-- 1. PERFILES DE USUARIO
CREATE TABLE public.profiles (
  id          UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email       TEXT NOT NULL,
  nombre      TEXT NOT NULL,
  rol         TEXT NOT NULL DEFAULT 'fte' CHECK (rol IN ('admin','tqs_leader','fte')),
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- 2. SISTEMAS SAP
CREATE TABLE public.sistemas (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre      TEXT NOT NULL,
  area_num    INTEGER,
  owner_id    UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  color       TEXT DEFAULT '#10B981',
  activo      BOOLEAN DEFAULT TRUE,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- 3. RFCs
CREATE TABLE public.rfcs (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket        TEXT NOT NULL,
  fecha         DATE NOT NULL,
  sistema_id    UUID REFERENCES public.sistemas(id) ON DELETE SET NULL,
  sistema_name  TEXT NOT NULL,
  sid           TEXT,
  descripcion   TEXT,
  status        TEXT DEFAULT 'Aprobado',
  hora_inicio   TEXT,
  hora_fin      TEXT,
  promotor      TEXT,
  observaciones TEXT,
  owner_id      UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  tipo          TEXT DEFAULT 'RFC',
  ambiente      TEXT,
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  updated_at    TIMESTAMPTZ DEFAULT NOW()
);

-- 4. TRIGGER updated_at
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER rfcs_updated_at
  BEFORE UPDATE ON public.rfcs
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- 5. TRIGGER auto-perfil al registrarse
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, email, nombre, rol)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'nombre', split_part(NEW.email,'@',1)),
    COALESCE(NEW.raw_user_meta_data->>'rol', 'fte')
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- 6. ROW LEVEL SECURITY
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sistemas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rfcs     ENABLE ROW LEVEL SECURITY;

-- Profiles: todos leen, cada quien edita el suyo
CREATE POLICY "profiles_read_all"   ON public.profiles FOR SELECT USING (true);
CREATE POLICY "profiles_update_own" ON public.profiles FOR UPDATE USING (auth.uid() = id);

-- Sistemas: todos leen, owner y admin escriben
CREATE POLICY "sistemas_read_all"   ON public.sistemas FOR SELECT USING (true);
CREATE POLICY "sistemas_insert_own" ON public.sistemas FOR INSERT WITH CHECK (auth.uid() = owner_id);
CREATE POLICY "sistemas_update_own" ON public.sistemas FOR UPDATE
  USING (auth.uid() = owner_id OR (SELECT rol FROM public.profiles WHERE id = auth.uid()) = 'admin');
CREATE POLICY "sistemas_delete_own" ON public.sistemas FOR DELETE
  USING (auth.uid() = owner_id OR (SELECT rol FROM public.profiles WHERE id = auth.uid()) = 'admin');

-- RFCs: todos leen, tqs_leader y admin insertan, owner y admin editan/borran
CREATE POLICY "rfcs_read_all"   ON public.rfcs FOR SELECT USING (true);
CREATE POLICY "rfcs_insert_own" ON public.rfcs FOR INSERT
  WITH CHECK (auth.uid() = owner_id AND (SELECT rol FROM public.profiles WHERE id = auth.uid()) IN ('tqs_leader','admin'));
CREATE POLICY "rfcs_update_own" ON public.rfcs FOR UPDATE
  USING (auth.uid() = owner_id OR (SELECT rol FROM public.profiles WHERE id = auth.uid()) = 'admin');
CREATE POLICY "rfcs_delete_own" ON public.rfcs FOR DELETE
  USING (auth.uid() = owner_id OR (SELECT rol FROM public.profiles WHERE id = auth.uid()) = 'admin');

-- 7. INDICES
CREATE INDEX idx_rfcs_owner     ON public.rfcs(owner_id);
CREATE INDEX idx_rfcs_fecha     ON public.rfcs(fecha);
CREATE INDEX idx_rfcs_ticket    ON public.rfcs(ticket);
CREATE INDEX idx_sistemas_owner ON public.sistemas(owner_id);
