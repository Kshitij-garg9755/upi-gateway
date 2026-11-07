# Deploy the UPI Gateway to Render

The CloudNova FastAPI service and this Laravel gateway are separate services. The CloudNova backend needs the gateway's public HTTPS URL; `127.0.0.1` and `localhost` only point to the same machine and will not work between Render services.

## Before deploying

1. Fork `https://github.com/mynkdev-21/upi-gateway` into your own GitHub account. Do not push changes to the original author's repository.
2. Copy these deployment files (`Dockerfile`, `.dockerignore`, `docker/`, `render.yaml`, `DEPLOY_RENDER.md`, and `package-lock.json`) into your fork, then push them to your fork's `main` branch.
3. In Render, create a PostgreSQL database first. Choose a plan with persistent data; Render's free database is temporary and expires. Keep the database in the same region as the web service.
4. Generate a Laravel application key from the gateway project directory:

   ```powershell
   php artisan key:generate --show
   ```

   Keep the generated `base64:...` value private.

## Create the Render service

1. In the Render dashboard choose **New + → Blueprint** and select your fork. If Blueprint is unavailable, create a **Web Service** from the fork and choose **Docker** runtime.
2. For a manual Web Service, set the Dockerfile path to `./Dockerfile` and health check path to `/up`.
3. Set these environment variables on the gateway service. In a Blueprint flow, Render prompts for values marked `sync: false`.

   | Variable | Value |
   | --- | --- |
   | `APP_KEY` | The private value from `php artisan key:generate --show` |
   | `APP_URL` | The gateway's final public URL, e.g. `https://your-gateway.onrender.com` |
   | `DB_CONNECTION` | `pgsql` |
   | `DB_URL` | The PostgreSQL **Internal Database URL** from the Render database page |

   The Blueprint sets production mode, database-backed sessions/cache, and the web port. Never enable `APP_DEBUG` in production.

4. Deploy the service. After it is live, open `https://YOUR-GATEWAY.onrender.com/up`; it should return HTTP 200. Then open the gateway home page and register your merchant account. Add your UPI account in the gateway dashboard and copy that account's API key and secret from **Dashboard → API & Webhooks**.

## Connect CloudNova to the live gateway

In the existing Render `cloudnova-api` service's **Environment** page, set:

| Variable | Value |
| --- | --- |
| `UPI_GATEWAY_URL` | Gateway public base URL, e.g. `https://your-gateway.onrender.com` (no `/api` suffix) |
| `UPI_GATEWAY_API_KEY` | Merchant API key from the gateway dashboard |
| `UPI_GATEWAY_API_SECRET` | Merchant API secret from the gateway dashboard |
| `UPI_GATEWAY_RETURN_URL` | `https://cloudnova-hosting.netlify.app/payment/return` |
| `UPI_GATEWAY_WEBHOOK_SECRET` | Optional; defaults to the merchant API secret in the current CloudNova backend |

Save the variables and redeploy `cloudnova-api`. From that service, verify that the Gateway API is reachable at `https://YOUR-GATEWAY.onrender.com/api/v1/accounts` using its API key and secret. Do not put gateway credentials in Vite/Netlify variables or browser code.

## Important operational notes

- This gateway only confirms a payment automatically when its configured provider can verify it. A generic UPI account uses manual UTR review; an administrator must verify submitted UTRs in the gateway dashboard.
- The gateway's scheduled `orders:check-pending` task is not run by the web container. If you use automatic provider polling, create a separate Render Cron Job from the same fork with command `php artisan orders:check-pending` and schedule `* * * * *` (this may require a paid Render plan).
- The Blueprint's free web service can sleep when idle, causing the first request to be slow. The free PostgreSQL option is temporary; use a persistent database plan for real payment records.
- Existing local SQLite users, merchant accounts, and UPI account settings are not copied to the hosted database. Re-register/configure the hosted gateway account after deployment. Never copy the local SQLite database into a public repository.
- This deployment does not make a payment provider integration active by itself. Configure only provider credentials that you are authorized to use and verify transactions with the provider/bank before treating them as paid.
