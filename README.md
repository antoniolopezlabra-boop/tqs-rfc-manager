# TQS RFC Manager

Sistema de control de RFCs SAP para el equipo de operaciones de EAS Consulting.

## Stack

- **Frontend:** HTML + JS (single file) → GitHub Pages
- **Backend:** Supabase (Postgres + Auth + RLS)
- **Región DB:** West US (North California)
- **Project ID:** `zhfmhaqwmkooxxufnncp`

## Roles

| Rol | Permisos |
|-----|----------|
| `admin` | Lectura y escritura total, gestión de usuarios |
| `tqs_leader` | Escribe sus propios RFCs, lee todos |
| `fte` | Solo lectura — todos los sistemas |

## Estructura del Repositorio

```
tqs-rfc-manager/
├── index.html          # Portal principal (single-file app)
├── schema.sql          # Schema completo de Supabase
└── README.md
```

## Sistemas y Áreas MPP

| Sistema | Área MPP |
|---------|----------|
| FDE & FR | 14 |
| SOLMAN | 24 |
| DYNATRACE | 25 |
| CPROC | 26 |
| SCM & EWM | 29 |
| Data Staging | 30 |
| Cloud Connector | 31 |

## Flujo de Actualización

1. TQS registra RFCs en el portal
2. Portal → Supabase (sync automático)
3. Botón CSV → descarga para MS Project (formato MPP)
4. Macro VBA en MS Project aplica los cambios

## URL de producción

`https://antoniolopezlabra-boop.github.io/tqs-rfc-manager`

---
*EAS Consulting — Querétaro, México*
