# Mailpit — emails, SMS and sign-in links

Open Mailpit at <http://localhost:8025> (shared stack; texts arrive as `SMS to <number>`). Take links from Mailpit, not the DB.

- API: `curl -s 'http://localhost:8025/api/v1/messages?limit=5'`, then `/api/v1/message/<ID>` for the body.
- Empty inbox → check `nest-shared-mailpit` and `nest-shared-notifications-consumer` are up.
