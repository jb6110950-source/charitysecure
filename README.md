# Charity Secure

Charity Secure is a browser-based records and payroll app. The site root opens the program at `contacts.html`. Sign-in is temporarily disabled; while local-only mode is active, changes and attached documents are saved only in the current browser, not shared through Supabase. Keep a private backup before using important records. Staff accounts and cloud synchronization require sign-in to be re-enabled.

## Set up the hosted app

You need a Supabase project and the existing Netlify site. Do not put the Supabase service-role key in this repository, `supabase-config.js`, or a browser.

1. In Supabase, open **SQL Editor**, run all of [`supabase/schema.sql`](./supabase/schema.sql), and wait for it to finish successfully.
2. In Supabase **Authentication > URL Configuration**, add the exact production URL for `contacts.html` to the allowed redirect URLs (for example, `https://your-site-name.netlify.app/contacts.html`). Add any preview URL you intend to use as well.
3. Create the first administrator in Supabase **Authentication > Users**. After the user is created, promote that account in the SQL Editor by replacing the example email below:

   ```sql
   update public.profiles
   set role = 'admin'
   where lower(email) = lower('admin@example.com');
   ```

   Confirm the query updated exactly one row. Newly created accounts default to the `staff` role.
4. In the Supabase project settings, copy the **Project URL** and the **publishable/anon public key** into `supabase-config.js`. These two values are intended to be public; never put the service-role key there.
5. In Netlify, set these environment variables for the site and its deploy contexts:
   - `SUPABASE_URL` - the same project URL.
   - `SUPABASE_ANON_KEY` - the same public anon/publishable key.
   - `SUPABASE_SERVICE_ROLE_KEY` - the Supabase secret/service-role key. Keep it only in Netlify's environment-variable settings.
6. Deploy the project root through the existing Netlify Git integration so Netlify also builds and deploys `netlify/functions/admin-users.mjs`. A manual drag-and-drop of static files does not deploy that function.
7. Open the production `contacts.html`, sign in as the administrator, then use **Manage users** to send an invitation. Invited staff set their own password from the email link and can only view Dayanim and recommendation information.

Before using real records, test an admin sign-in, an invitation and password setup, staff read-only access, and admin-created changes from a second browser/device. Keep a full backup before migrating existing browser-only data. Restoring an old backup replaces the current app data.

The site cannot be deployed or connected to Supabase until the project URL, public key, secret Netlify environment variables, and Netlify deployment access have been configured.

## Import a Dayanim spreadsheet

In **Dayanim List**, select **Import Dayanim List** and choose an `.xlsx`, `.xls`, or `.csv` file. Column headers are matched automatically, including `rabbi_name`, `phone_numbers`, `address_or_location`, and `title_and_affiliation`. Importing replaces the current list with the rows in the file; matching names keep their existing verification and warning flags. Back up the app before importing if you need to preserve the current list.

## Optional local AI letterhead reader

The optional vision AI runs on the user's own computer through Ollama. The cropped letterhead image is sent to `http://127.0.0.1:11434`; it is not sent to OpenAI or another cloud AI service. The AI is optional and is separate from the hosted database and document storage.

## Install Ollama on Windows

1. Install Ollama 0.7 or newer from https://ollama.com/download/windows and start the Ollama app.
2. Open PowerShell and download the free vision model:

	```powershell
	ollama pull qwen2.5vl:3b
	```

The model download is about 3.2 GB. Make sure you have enough disk space.

3. Keep Ollama running while using the app. The first read may take longer while the model loads.
4. In Add Contact, check **Use local AI (Ollama)**. Keep the model name `qwen2.5vl:3b`, unless you installed a different Ollama vision model.

The AI option is off by default. Without Ollama running or the model installed, the app falls back to its existing local OCR. No API key, billing account, or access code is required.

## If the app is hosted on Netlify

The app opened from its existing `file://` URL can connect to Ollama without changing its browser storage; Ollama allows file and loopback origins by default. This keeps existing contacts and documents in their current browser origin.

If you use the Netlify-hosted page, the browser connects from that site to Ollama on the same computer. Add only your exact site origin to Ollama's `OLLAMA_ORIGINS` user environment variable, for example `https://your-site-name.netlify.app`. Do not use `*`. On Windows, set the variable in **Edit environment variables for your account**, then quit and restart Ollama. The Netlify site itself remains static; there is no AI server function.

Ollama serves its local API on port `11434`. Only enable AI from a trusted site you control, because any allowed page can send requests to the local Ollama service.

## Outlook email page

The standalone `email.html` page signs in to the user's Microsoft account and sends plain-text email through Microsoft Graph. It supports personal Microsoft accounts and work/school accounts. The app uses delegated `User.Read` and `Mail.Send` permissions; it does not need or accept a client secret. The Application (client) ID is saved in the browser, and MSAL keeps its sign-in cache in session storage. Email contents are sent directly from the browser to Microsoft Graph and are not stored by this site.

### Microsoft app registration

1. In the Microsoft Entra admin center, create an app registration that allows **Accounts in any organizational directory and personal Microsoft accounts**.
2. Under **Authentication**, add a **Single-page application (SPA)** platform and register the exact URL of `email.html` as a redirect URI. For example, use `https://your-site-name.netlify.app/email.html` for the deployed site. Do not open the page using `file://`; use its HTTPS URL or serve the project on localhost.
3. Under **API permissions**, add the Microsoft Graph **delegated** permissions `User.Read` and `Mail.Send`. Grant user/admin consent as required by your Microsoft account or organization.
4. Copy the registration's **Application (client) ID** into the Outlook email page. Never put a client secret, password, or access token in the page or source code.

The page requires internet access to load Microsoft's MSAL browser library and to contact Microsoft sign-in and Graph endpoints. To test locally, serve the project root over HTTP (for example, `python -m http.server 8888`) and register `http://localhost:8888/email.html` as the SPA redirect URI.
