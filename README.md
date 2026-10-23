# Umbix · Fase 1 — Guía para ponerla en línea

Esta guía es para hacerlo **sin saber programar**. Son 8 pasos y toma como 30 a 45 minutos. Todo lo que usamos tiene plan gratis.

## Qué hay en esta carpeta

| Archivo | Para qué sirve |
|---|---|
| `index.html` | La app completa. |
| `config.js` | Donde pegas las 2 claves de tu servidor (paso 4). |
| `supabase/schema.sql` | Crea la base de datos y sus reglas de seguridad (paso 2). |
| `privacidad.html`, `terminos.html`, `soporte.html`, `legal.css` | Aviso de privacidad, términos de uso y soporte. Las tiendas de apps los piden. |
| `icon.svg` | El ícono de Umbix. |

Si abres `index.html` sin claves, Umbix funciona en **modo demostración**, igual que el prototipo.

---

## Paso 1 · Crear tu servidor en Supabase

1. Entra a **supabase.com** y crea una cuenta (puedes usar tu cuenta de GitHub o tu correo).
2. Toca **New project**.
3. Ponle de nombre `umbix`.
4. En **Database Password** toca *Generate a password* y **guárdala en un lugar seguro**. No la vas a necesitar para la app, pero sí para recuperar el proyecto.
5. En **Region** elige una de Estados Unidos (quedan más cerca de México).
6. Toca **Create new project** y espera 1 o 2 minutos.

## Paso 2 · Crear la base de datos

1. En el menú de la izquierda entra a **SQL Editor**.
2. Toca **New query**.
3. Abre el archivo `supabase/schema.sql` con el Bloc de notas (o TextEdit en Mac), selecciona **todo** (Ctrl+A / Cmd+A), cópialo y pégalo en Supabase.
4. Toca **Run**. Debe decir **Success. No rows returned**.

> Si algún día te mando una versión nueva de `schema.sql`, repites este paso. Se puede ejecutar varias veces sin borrar nada.

## Paso 3 · Ajustar el inicio de sesión

1. En el menú entra a **Authentication → Sign In / Providers → Email**.
2. Para la beta, **apaga "Confirm email"** y guarda.
   - ¿Por qué? El servicio de correo que trae Supabase solo manda **2 correos por hora**. Con la confirmación apagada, la gente entra en cuanto crea su cuenta.
   - Cuando tengas más usuarios, conecta un servicio de correo (por ejemplo Brevo o Resend, que tienen plan gratis) en **Authentication → Emails → SMTP Settings** y vuelve a encender la confirmación.

## Paso 4 · Copiar tus claves en `config.js`

1. En Supabase entra a **Project Settings → API Keys** (o toca el botón **Connect** arriba).
2. Copia la **Project URL** (se ve como `https://abcdefgh.supabase.co`).
3. Copia la **Publishable key** (empieza con `sb_publishable_`). Si ves una clave llamada **anon public**, también sirve.
4. Abre `config.js` con el Bloc de notas y pega cada una entre las comillas:

```js
window.UMBIX_CONFIG = {
  supabaseUrl: 'https://abcdefgh.supabase.co',
  supabaseAnonKey: 'sb_publishable_xxxxxxxxxxxxxxxx'
};
```

5. Guarda el archivo.

> ⚠️ **Nunca** pegues la clave **secret** ni la **service_role**. Esas dan control total de tu base de datos.
> La clave pública sí se puede ver en internet: la seguridad la ponen las reglas que creó `schema.sql`.

## Paso 5 · Subir la app a GitHub

1. Entra a **github.com** y crea una cuenta.
2. Arriba a la derecha toca **+ → New repository**.
3. En **Repository name** escribe `umbix`. Déjalo en **Public** y toca **Create repository**.
4. En la página que aparece toca el enlace **uploading an existing file**.
5. Arrastra **todos** los archivos de esta carpeta, incluida la carpeta `supabase`.
6. Abajo toca **Commit changes**.

## Paso 6 · Publicarla en internet (GitHub Pages)

1. En tu repositorio entra a **Settings → Pages**.
2. En **Source** elige **Deploy from a branch**.
3. En **Branch** elige **main** y **/ (root)**, y toca **Save**.
4. Espera 1 o 2 minutos y recarga la página. Arriba aparecerá tu dirección, algo como:
   `https://TU-USUARIO.github.io/umbix/`

## Paso 7 · Decirle a Supabase cuál es tu dirección

1. En Supabase entra a **Authentication → URL Configuration**.
2. En **Site URL** pega tu dirección de GitHub Pages.
3. En **Redirect URLs** toca **Add URL** y pega la misma dirección.
4. Guarda. Esto hace que los enlaces de "olvidé mi contraseña" regresen a tu app.

## Paso 8 · Probar y volverte administrador

1. Abre tu dirección, toca **Crear cuenta** y regístrate.
2. Abre la misma dirección en tu celular (o en otro navegador) y crea una segunda cuenta.
3. Agrégate como amigo, mándate mensajes, crea un servidor e invita a tu otra cuenta.
4. Para ver los **reportes** de la comunidad y tener tus insignias de creador:
   - En Supabase entra a **SQL Editor → New query** y pega esto, cambiando `tu_usuario` por tu nombre de usuario de Umbix:

     ```sql
     update profiles
        set is_admin = true,
            badges = '{fundador,dev,early,beta,supporter,artista,bug}'
      where username = 'tu_usuario';
     ```
   - Toca **Run**. Debe decir **Success. 1 row affected**.
   - Recarga Umbix. En **Ajustes** verás **Administración → Moderación**.

---

## Antes de invitar gente

- **Textos legales:** abre `privacidad.html`, `terminos.html` y `soporte.html` y cambia todo lo que está entre corchetes, como `[TU CORREO DE CONTACTO]`. Puedes editarlos directo en GitHub con el ícono del lápiz. Son borradores: **pide a un abogado en México que los revise** antes de publicar en las tiendas.
- **Correo de soporte:** crea un correo solo para Umbix (por ejemplo `soporte.umbix@gmail.com`) y úsalo en esos textos.
- **Plan gratis de Supabase:** incluye 500 MB de base de datos, 1 GB para fotos y 5 GB de transferencia al mes. **Si nadie usa la app durante una semana, el proyecto se pausa** y tienes que reactivarlo desde el panel. El plan Pro cuesta 25 dólares al mes y no se pausa: es buen primer gasto con el dinero de Patreon.

## Cómo actualizar Umbix

Cuando te mande una versión nueva:

1. En tu repositorio de GitHub abre el archivo que cambió (normalmente `index.html`).
2. Bórralo con el ícono de basura y vuelve a subir el nuevo con **Add file → Upload files**.
3. Si también cambió `schema.sql`, repite el **paso 2**.
4. **No reemplaces `config.js`**, porque ahí están tus claves.

## Qué funciona en esta Fase 1

- Cuentas reales: registro, inicio de sesión, recuperar contraseña, cambiar correo y contraseña, borrar cuenta.
- Perfiles con todo lo que diseñamos: foto, banner, efectos, estilos de nombre, bio, insignias, niveles.
- Amigos y solicitudes, mensajes directos en tiempo real, rachas.
- Servidores con invitaciones, canales de texto y de anuncios, roles, AutoMod, modo lento, expulsar y banear.
- Reacciones, respuestas, encuestas, `/dado` y `/moneda`.
- Seguridad: reportar mensajes y personas, bloquear, filtro de palabras, límite anti-spam y panel de moderación.
- Los 6 idiomas y todos los estilos de animación.

## Lo que llega en la Fase 2

Canales de voz y compartir pantalla, clips de video, momentos, muro de firmas, conexión real con Spotify, apps instalables para celular y computadora, notificaciones y verificación en dos pasos. Mientras tanto, en la versión con cuentas esas opciones aparecen como "Llega en la Fase 2" o no se muestran, y siguen funcionando en la demo.

## Problemas comunes

- **"No pudimos conectar con el servidor":** revisa que las claves de `config.js` estén bien copiadas, sin espacios de más.
- **Al registrarme no pasa nada o dice que revise mi correo:** apaga "Confirm email" (paso 3) o conecta un servicio de correo.
- **La app dice "Algo salió mal" al entrar:** probablemente no se ejecutó `schema.sql` completo. Repite el paso 2.
- **Supabase dice que mi proyecto está pausado:** entra al panel y toca **Restore project**.
